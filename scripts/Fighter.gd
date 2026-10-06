class_name Fighter
extends CharacterBody2D

## Fighter Entity & FSM for Retro Fighter.
## Implements a 13-state deterministic FSM, punch/kick attacks, dedicated blocking,
## damage mitigation, spatial separation, and hit receiving.

const Hitbox = preload("res://scripts/Hitbox.gd")
const Hurtbox = preload("res://scripts/Hurtbox.gd")

signal health_changed(new_health: int, max_health: int)
signal state_changed(old_state: State, new_state: State)
signal hit_received(damage: int, blocked: bool)
signal knocked_down
signal died

enum State {
	IDLE,
	WALK_FORWARD,
	WALK_BACKWARD,
	JUMP_SQUAT,
	JUMPING,
	CROUCHING,
	ATTACK_PUNCH,
	ATTACK_KICK,
	BLOCKING,
	BLOCK_STUN,
	HIT_STUN,
	KNOCKDOWN,
	DEAD
}

# Movement & Physics Constants (60 Hz physics rate)
const MAX_HEALTH: int = 100
const WALK_FORWARD_SPEED: float = 100.0
const WALK_BACKWARD_SPEED: float = 80.0
const JUMP_VELOCITY: float = -420.0
const GRAVITY: float = 980.0
const JUMP_SQUAT_TICKS: int = 3

# Frame Data Presets (60 Hz ticks)
const PUNCH_TOTAL_TICKS: int = 12
const PUNCH_STARTUP_TICKS: int = 4
const PUNCH_ACTIVE_TICKS: int = 3
const PUNCH_RECOVERY_TICKS: int = 5
const PUNCH_DAMAGE: int = 8
const PUNCH_HIT_STUN_TICKS: int = 12
const PUNCH_BLOCK_STUN_TICKS: int = 6
const PUNCH_KNOCKBACK: float = 40.0

const KICK_TOTAL_TICKS: int = 19
const KICK_STARTUP_TICKS: int = 7
const KICK_ACTIVE_TICKS: int = 4
const KICK_RECOVERY_TICKS: int = 8
const KICK_DAMAGE: int = 14
const KICK_HIT_STUN_TICKS: int = 18
const KICK_BLOCK_STUN_TICKS: int = 8
const KICK_KNOCKBACK: float = 80.0

# Boundary Clamping
const STAGE_MIN_X: float = 16.0
const STAGE_MAX_X: float = 584.0
const VIEWPORT_MARGIN_X: float = 16.0

# Visual Styling
const PALETTES: Dictionary = {
	1: {
		"gi": Color("ffffff"),
		"accent": Color("b81414"),
		"skin": Color("fcd8a8"),
		"hair": Color("2b1d0c"),
		"belt": Color("1a1a1a"),
	},
	2: {
		"gi": Color("243356"),
		"accent": Color("e6a117"),
		"skin": Color("fcd8a8"),
		"hair": Color("1a1a1a"),
		"belt": Color("1a1a1a"),
	}
}

const LIMB_NODES: Array[String] = [
	"BackArm", "BackLeg", "TorsoGi", "Belt", "BeltKnot",
	"Head", "Hair", "Headband", "Ties", "LeadLeg", "LeadArm", "Glove"
]

const STATE_ANIMATIONS: Dictionary = {
	State.IDLE: "idle",
	State.WALK_FORWARD: "walk",
	State.WALK_BACKWARD: "walk_backward",
	State.JUMP_SQUAT: "jump_squat",
	State.JUMPING: "jump",
	State.CROUCHING: "crouch",
	State.ATTACK_PUNCH: "punch",
	State.ATTACK_KICK: "kick",
	State.BLOCKING: "block",
	State.BLOCK_STUN: "block_stun",
	State.HIT_STUN: "hit",
	State.KNOCKDOWN: "knockdown",
	State.DEAD: "dead",
}

@export var player_id: int = 1
@export var is_cpu: bool = false
@export var max_health: int = MAX_HEALTH
var health: int = MAX_HEALTH
var state: State = State.IDLE
var facing: int = 1
var is_dummy: bool = false
var inputs_frozen: bool = false
var inputs_enabled: bool:
	get:
		return not inputs_frozen
	set(val):
		inputs_frozen = not val

# Virtual CPU Inputs
var input_dir: float = 0.0
var input_punch: bool = false
var input_kick: bool = false
var input_block: bool = false

var opponent: CharacterBody2D = null
var camera: Camera2D = null

# Timers & Counters (in ticks)
var state_ticks: int = 0
var jump_squat_timer: int = 0
var jump_dir_x: float = 0.0
var attack_tick: int = 0
var stun_ticks_remaining: int = 0
var knockdown_timer: int = 0
var is_crouch_blocking: bool = false

# Node references
@onready var pushbox_shape: CollisionShape2D = $PushboxShape if has_node("PushboxShape") else null
@onready var hurtbox: Hurtbox = $Hurtbox if has_node("Hurtbox") else null
@onready var hitbox: Hitbox = $Hitbox if has_node("Hitbox") else null
@onready var visual: Node2D = $Visual if has_node("Visual") else null
@onready var torso_gi: Polygon2D = $Visual/TorsoGi if has_node("Visual/TorsoGi") else null
@onready var head_poly: Polygon2D = $Visual/Head if has_node("Visual/Head") else null
@onready var animation_player: AnimationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

func _init() -> void:
	# Default CharacterBody2D configuration
	collision_layer = Hitbox.MASK_FIGHTERBODY
	collision_mask = Hitbox.MASK_WORLDFLOOR | Hitbox.MASK_FIGHTERBODY | Hitbox.MASK_STAGEWALL

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		_init_nodes()
		if hitbox != null:
			hitbox.deactivate()

func _ready() -> void:
	_init_nodes()
	setup(player_id)
	_find_opponent_and_camera()

func _init_nodes() -> void:
	if pushbox_shape == null and has_node("PushboxShape"):
		pushbox_shape = $PushboxShape
	if hurtbox == null and has_node("Hurtbox"):
		hurtbox = $Hurtbox
	if hitbox == null and has_node("Hitbox"):
		hitbox = $Hitbox
	if visual == null and has_node("Visual"):
		visual = $Visual
	if torso_gi == null and has_node("Visual/TorsoGi"):
		torso_gi = $Visual/TorsoGi
	if head_poly == null and has_node("Visual/Head"):
		head_poly = $Visual/Head
	if animation_player == null and has_node("AnimationPlayer"):
		animation_player = $AnimationPlayer
	if animation_player != null and not animation_player.has_animation_library(""):
		_setup_animations()

## Configures the fighter for Player 1 or Player 2.
## P1: Hurtbox Layer 4, Hitbox Layer 5 (mask 6), white gi / crimson accents.
## P2: Hurtbox Layer 6, Hitbox Layer 7 (mask 4), navy gi / gold accents.
func setup(p_player_id: int) -> void:
	player_id = p_player_id
	_init_nodes()

	collision_layer = Hitbox.MASK_FIGHTERBODY
	collision_mask = Hitbox.MASK_WORLDFLOOR | Hitbox.MASK_FIGHTERBODY | Hitbox.MASK_STAGEWALL

	if hurtbox != null:
		hurtbox.setup(player_id)
		hurtbox.fighter = self

	if hitbox != null:
		hitbox.setup(player_id)
		hitbox.attacker = self
		hitbox.deactivate()

	if player_id == 1:
		facing = 1
	elif player_id == 2:
		facing = -1

	apply_palette(player_id)
	set_facing(facing)

	if state == State.IDLE:
		_play_animation("idle")

func _unhandled_input(event: InputEvent) -> void:
	if player_id == 2 and event.is_action_pressed("toggle_p2_dummy"):
		toggle_dummy()

func toggle_dummy() -> void:
	is_dummy = not is_dummy

func _physics_process(delta: float) -> void:
	state_ticks += 1

	# Automatically face opponent while in ground neutral / non-committal states
	if state in [State.IDLE, State.WALK_FORWARD, State.WALK_BACKWARD, State.CROUCHING, State.BLOCKING]:
		update_facing()

	match state:
		State.IDLE:
			_process_idle(delta)
		State.WALK_FORWARD:
			_process_walk_forward(delta)
		State.WALK_BACKWARD:
			_process_walk_backward(delta)
		State.JUMP_SQUAT:
			_process_jump_squat(delta)
		State.JUMPING:
			_process_jumping(delta)
		State.CROUCHING:
			_process_crouching(delta)
		State.ATTACK_PUNCH:
			_process_attack_punch(delta)
		State.ATTACK_KICK:
			_process_attack_kick(delta)
		State.BLOCKING:
			_process_blocking(delta)
		State.BLOCK_STUN:
			_process_block_stun(delta)
		State.HIT_STUN:
			_process_hit_stun(delta)
		State.KNOCKDOWN:
			_process_knockdown(delta)
		State.DEAD:
			_process_dead(delta)

	move_and_slide()
	_apply_clamping()

# ---------------------------------------------------------
# FSM State Processing Functions
# ---------------------------------------------------------

func _process_idle(_delta: float) -> void:
	velocity.x = 0.0

	if _check_attack_inputs():
		return

	if is_action_pressed("block"):
		change_state(State.BLOCKING)
		return

	if is_action_just_pressed("up"):
		jump_dir_x = 0.0
		change_state(State.JUMP_SQUAT)
		return

	if is_action_pressed("down"):
		change_state(State.CROUCHING)
		return

	var move_dir: float = _get_horizontal_input()
	if move_dir != 0.0:
		if (move_dir > 0 and facing == 1) or (move_dir < 0 and facing == -1):
			change_state(State.WALK_FORWARD)
		else:
			change_state(State.WALK_BACKWARD)

func _process_walk_forward(_delta: float) -> void:
	if _check_attack_inputs():
		return

	if is_action_pressed("block"):
		change_state(State.BLOCKING)
		return

	if is_action_just_pressed("up"):
		jump_dir_x = float(facing) * WALK_FORWARD_SPEED
		change_state(State.JUMP_SQUAT)
		return

	if is_action_pressed("down"):
		change_state(State.CROUCHING)
		return

	var move_dir: float = _get_horizontal_input()
	if (move_dir > 0 and facing == -1) or (move_dir < 0 and facing == 1):
		change_state(State.WALK_BACKWARD)
	elif is_action_just_released("left") or is_action_just_released("right"):
		change_state(State.IDLE)
	else:
		velocity.x = float(facing) * WALK_FORWARD_SPEED

func _process_walk_backward(_delta: float) -> void:
	if _check_attack_inputs():
		return

	if is_action_pressed("block"):
		change_state(State.BLOCKING)
		return

	if is_action_just_pressed("up"):
		jump_dir_x = -float(facing) * WALK_BACKWARD_SPEED
		change_state(State.JUMP_SQUAT)
		return

	if is_action_pressed("down"):
		change_state(State.CROUCHING)
		return

	var move_dir: float = _get_horizontal_input()
	if (move_dir > 0 and facing == 1) or (move_dir < 0 and facing == -1):
		change_state(State.WALK_FORWARD)
	elif is_action_just_released("left") or is_action_just_released("right"):
		change_state(State.IDLE)
	else:
		velocity.x = -float(facing) * WALK_BACKWARD_SPEED

func _check_attack_inputs() -> bool:
	if is_action_just_pressed("punch"):
		change_state(State.ATTACK_PUNCH)
		return true
	if is_action_just_pressed("kick"):
		change_state(State.ATTACK_KICK)
		return true
	return false

func _process_jump_squat(_delta: float) -> void:
	velocity = Vector2.ZERO
	jump_squat_timer += 1
	if jump_squat_timer >= JUMP_SQUAT_TICKS:
		change_state(State.JUMPING)

func _process_jumping(delta: float) -> void:
	velocity.y += GRAVITY * delta
	if velocity.y >= 0.0:
		if animation_player != null and animation_player.has_animation("fall") and animation_player.current_animation != "fall":
			_play_animation("fall")
	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = 0.0
		velocity.x = 0.0
		jump_dir_x = 0.0
		change_state(State.IDLE)

func _process_crouching(_delta: float) -> void:
	velocity.x = 0.0

	if is_action_pressed("block"):
		change_state(State.BLOCKING)
		return

	if not is_action_pressed("down"):
		change_state(State.IDLE)

func _process_blocking(_delta: float) -> void:
	velocity.x = 0.0

	if not is_action_pressed("block") and not is_dummy:
		if is_action_pressed("down"):
			change_state(State.CROUCHING)
		else:
			change_state(State.IDLE)
		return

	if is_action_pressed("down") or is_crouch_blocking or is_dummy:
		is_crouch_blocking = true
		if hurtbox != null:
			hurtbox.set_crouching(true)
		_set_visual_crouch(true)
	else:
		is_crouch_blocking = false
		if hurtbox != null:
			hurtbox.set_crouching(false)
		_set_visual_crouch(false)

func _process_attack_punch(_delta: float) -> void:
	velocity.x = 0.0
	attack_tick += 1

	# Startup: ticks 1..4 (inactive)
	# Active: ticks 5..7 (active)
	# Recovery: ticks 8..12 (inactive)
	if attack_tick == PUNCH_STARTUP_TICKS + 1:
		if hitbox != null:
			hitbox.activate()
			for area in hitbox.get_overlapping_areas():
				hitbox.trigger_hit(area)
	elif attack_tick == PUNCH_STARTUP_TICKS + PUNCH_ACTIVE_TICKS + 1:
		if hitbox != null:
			hitbox.deactivate()
	elif attack_tick > PUNCH_TOTAL_TICKS:
		if hitbox != null:
			hitbox.deactivate()
		change_state(State.IDLE)

func _process_attack_kick(_delta: float) -> void:
	velocity.x = 0.0
	attack_tick += 1

	# Startup: ticks 1..7 (inactive)
	# Active: ticks 8..11 (active)
	# Recovery: ticks 12..19 (inactive)
	if attack_tick == KICK_STARTUP_TICKS + 1:
		if hitbox != null:
			hitbox.activate()
			for area in hitbox.get_overlapping_areas():
				hitbox.trigger_hit(area)
	elif attack_tick == KICK_STARTUP_TICKS + KICK_ACTIVE_TICKS + 1:
		if hitbox != null:
			hitbox.deactivate()
	elif attack_tick > KICK_TOTAL_TICKS:
		if hitbox != null:
			hitbox.deactivate()
		change_state(State.IDLE)

func _process_block_stun(_delta: float) -> void:
	velocity.x = 0.0
	stun_ticks_remaining -= 1
	if stun_ticks_remaining <= 0:
		if is_action_pressed("block") or is_dummy:
			change_state(State.BLOCKING)
		elif is_action_pressed("down"):
			change_state(State.CROUCHING)
		else:
			change_state(State.IDLE)

func _process_hit_stun(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	stun_ticks_remaining -= 1
	if stun_ticks_remaining <= 0:
		velocity.x = 0.0
		if is_on_floor():
			change_state(State.IDLE)
		else:
			change_state(State.JUMPING)

func _process_knockdown(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.y = 0.0

	knockdown_timer += 1
	if knockdown_timer >= 10:
		change_state(State.DEAD)

func _process_dead(_delta: float) -> void:
	velocity = Vector2.ZERO

# ---------------------------------------------------------
# FSM State Transition Management
# ---------------------------------------------------------

func change_state(new_state: State) -> void:
	if state == new_state:
		return
	var old_state = state
	state = new_state
	state_ticks = 0

	# Cleanup prior state
	if old_state in [State.ATTACK_PUNCH, State.ATTACK_KICK]:
		if hitbox != null:
			hitbox.deactivate()

	_apply_neutral_reset()

	# Enter new state
	match new_state:
		State.IDLE:
			velocity.x = 0.0
			is_crouch_blocking = false
			if hurtbox != null:
				hurtbox.set_crouching(false)
			_set_visual_crouch(false)
			_play_animation("idle")
		State.WALK_FORWARD:
			velocity.x = float(facing) * WALK_FORWARD_SPEED
			_play_animation("walk")
		State.WALK_BACKWARD:
			velocity.x = -float(facing) * WALK_BACKWARD_SPEED
			_play_animation("walk_backward")
		State.CROUCHING:
			velocity.x = 0.0
			if hurtbox != null:
				hurtbox.set_crouching(true)
			_set_visual_crouch(true)
			_play_animation("crouch")
		State.BLOCKING:
			velocity.x = 0.0
			if is_action_pressed("down") or is_crouch_blocking:
				is_crouch_blocking = true
				if hurtbox != null:
					hurtbox.set_crouching(true)
				_set_visual_crouch(true)
				_play_animation("crouch_block" if (animation_player != null and animation_player.has_animation("crouch_block")) else "block")
			else:
				is_crouch_blocking = false
				if hurtbox != null:
					hurtbox.set_crouching(false)
				_set_visual_crouch(false)
				_play_animation("block")
		State.JUMP_SQUAT:
			velocity = Vector2.ZERO
			jump_squat_timer = 0
			_play_animation("jump_squat")
		State.JUMPING:
			velocity.y = JUMP_VELOCITY
			velocity.x = jump_dir_x
			if hurtbox != null:
				hurtbox.set_crouching(false)
			_set_visual_crouch(false)
			_play_animation("jump")
		State.ATTACK_PUNCH:
			velocity.x = 0.0
			attack_tick = 0
			if hitbox != null:
				hitbox.configure_punch(facing, self)
				hitbox.deactivate()
			_play_animation("punch")
		State.ATTACK_KICK:
			velocity.x = 0.0
			attack_tick = 0
			if hitbox != null:
				hitbox.configure_kick(facing, self)
				hitbox.deactivate()
			_play_animation("kick")
		State.BLOCK_STUN:
			var is_crouched: bool = is_crouch_blocking or (hurtbox != null and hurtbox.is_crouching)
			_play_animation("crouch_block_stun" if (is_crouched and animation_player != null and animation_player.has_animation("crouch_block_stun")) else "block_stun")
		State.HIT_STUN:
			_play_animation("hit")
		State.KNOCKDOWN:
			velocity.x = 0.0
			knockdown_timer = 0
			if hitbox != null:
				hitbox.deactivate()
			_play_animation("knockdown")
			knocked_down.emit()
		State.DEAD:
			velocity = Vector2.ZERO
			if hitbox != null:
				hitbox.deactivate()
			_play_animation("dead")
			died.emit()

	state_changed.emit(old_state, new_state)

# ---------------------------------------------------------
# Combat & Hit Receiving Contract
# ---------------------------------------------------------

func receive_hit(
	p_damage: int,
	p_hit_stun_ticks: int,
	p_block_stun_ticks: int,
	p_knockback_x: float,
	p_is_low: bool,
	p_attacker: CharacterBody2D = null
) -> void:
	if state == State.DEAD or state == State.KNOCKDOWN:
		return

	var is_blocking: bool = false
	var blocked_as_crouch: bool = false

	if is_dummy:
		is_blocking = true
		blocked_as_crouch = true
	elif state != State.JUMPING and (state == State.BLOCKING or is_action_pressed("block")):
		is_blocking = true
		blocked_as_crouch = (state == State.CROUCHING or is_crouch_blocking or is_action_pressed("down"))

	var block_successful: bool = false
	if is_blocking:
		if p_is_low:
			block_successful = blocked_as_crouch
		else:
			block_successful = true

	var actual_damage: int = p_damage
	if block_successful:
		actual_damage = int(floor(float(p_damage) * 0.2))
		health = max(0, health - actual_damage)
		health_changed.emit(health, max_health)
		hit_received.emit(actual_damage, true)

		if health <= 0:
			change_state(State.KNOCKDOWN)
		else:
			stun_ticks_remaining = p_block_stun_ticks
			velocity.x = 0.0
			if hurtbox != null:
				hurtbox.set_crouching(blocked_as_crouch)
			_set_visual_crouch(blocked_as_crouch)
			change_state(State.BLOCK_STUN)
	else:
		actual_damage = p_damage
		health = max(0, health - actual_damage)
		health_changed.emit(health, max_health)
		hit_received.emit(actual_damage, false)

		if health <= 0:
			change_state(State.KNOCKDOWN)
		else:
			stun_ticks_remaining = p_hit_stun_ticks
			var knockback_dir: float = 0.0
			if p_attacker != null:
				knockback_dir = 1.0 if p_attacker.global_position.x <= global_position.x else -1.0
			else:
				knockback_dir = -float(facing)
			velocity.x = knockback_dir * p_knockback_x
			change_state(State.HIT_STUN)

# ---------------------------------------------------------
# Lifecycle & Round Reset Contract
# ---------------------------------------------------------

func reset_round(start_x: float = 0.0) -> void:
	reset_fighter(start_x)

func reset_fighter(start_x: float = 0.0) -> void:
	health = max_health
	health_changed.emit(health, max_health)
	velocity = Vector2.ZERO

	if start_x != 0.0:
		global_position.x = start_x
	elif player_id == 1:
		global_position.x = 200.0
	elif player_id == 2:
		global_position.x = 400.0

	if hurtbox != null:
		hurtbox.set_crouching(false)
		hurtbox.is_invulnerable = false

	if hitbox != null:
		hitbox.deactivate()
		hitbox.reset_hit()

	_set_visual_crouch(false)

	if player_id == 1:
		facing = 1
	elif player_id == 2:
		facing = -1
	set_facing(facing)

	inputs_frozen = false
	input_dir = 0.0
	input_punch = false
	input_kick = false
	input_block = false
	change_state(State.IDLE)
	# NOTE: is_dummy persists across round reset per AC-10

# ---------------------------------------------------------
# Spatial Clamping & Facing Helpers
# ---------------------------------------------------------

func update_facing() -> void:
	if opponent != null:
		if opponent.global_position.x > global_position.x:
			set_facing(1)
		elif opponent.global_position.x < global_position.x:
			set_facing(-1)

func set_facing(new_facing: int) -> void:
	facing = new_facing
	if visual != null:
		visual.scale.x = float(facing)

func _apply_clamping() -> void:
	var min_x: float = STAGE_MIN_X
	var max_x: float = STAGE_MAX_X

	if camera == null:
		_find_opponent_and_camera()

	if camera != null:
		if camera.has_method("get_view_bounds"):
			var bounds: Rect2 = camera.get_view_bounds()
			min_x = max(min_x, bounds.position.x + VIEWPORT_MARGIN_X)
			max_x = min(max_x, bounds.position.x + bounds.size.x - VIEWPORT_MARGIN_X)
		elif camera is Camera2D:
			var cam_pos = camera.global_position
			var half_w = 384.0 * 0.5
			min_x = max(min_x, cam_pos.x - half_w + VIEWPORT_MARGIN_X)
			max_x = min(max_x, cam_pos.x + half_w - VIEWPORT_MARGIN_X)

	global_position.x = clamp(global_position.x, min_x, max_x)

# ---------------------------------------------------------
# Input & Visual Helpers
# ---------------------------------------------------------

func get_action_name(action: String) -> String:
	return "p%d_%s" % [player_id, action]

func is_action_pressed(action: String) -> bool:
	if inputs_frozen:
		return false
	if is_dummy and player_id == 2:
		return false
	if is_cpu:
		match action:
			"block":
				return input_block
			"left":
				return input_dir < 0.0
			"right":
				return input_dir > 0.0
			_:
				return false
	return Input.is_action_pressed(get_action_name(action))

func is_action_just_pressed(action: String) -> bool:
	if inputs_frozen:
		return false
	if is_dummy and player_id == 2:
		return false
	if is_cpu:
		match action:
			"punch":
				return input_punch
			"kick":
				return input_kick
			_:
				return false
	return Input.is_action_just_pressed(get_action_name(action))

func is_action_just_released(action: String) -> bool:
	if inputs_frozen:
		return false
	if is_dummy and player_id == 2:
		return false
	if is_cpu:
		match action:
			"left", "right":
				return is_zero_approx(input_dir)
			_:
				return false
	return Input.is_action_just_released(get_action_name(action))

func _get_horizontal_input() -> float:
	if is_cpu:
		if inputs_frozen or (is_dummy and player_id == 2):
			return 0.0
		return clampf(input_dir, -1.0, 1.0)
	var left_pressed: bool = is_action_pressed("left")
	var right_pressed: bool = is_action_pressed("right")
	if left_pressed and not right_pressed:
		return -1.0
	elif right_pressed and not left_pressed:
		return 1.0
	return 0.0

func set_gi_color(color: Color) -> void:
	if torso_gi != null:
		torso_gi.color = color

func apply_palette(p_player_id: int = -1) -> void:
	var pid: int = player_id if p_player_id <= 0 else p_player_id
	if not PALETTES.has(pid):
		return
	var palette: Dictionary = PALETTES[pid]

	var node_torso: Polygon2D = get_node_or_null("Visual/TorsoGi") as Polygon2D
	if node_torso != null and palette.has("gi"):
		node_torso.color = palette["gi"]

	var node_lead_leg: Polygon2D = get_node_or_null("Visual/LeadLeg") as Polygon2D
	if node_lead_leg != null and palette.has("gi"):
		node_lead_leg.color = palette["gi"]

	var node_back_leg: Polygon2D = get_node_or_null("Visual/BackLeg") as Polygon2D
	if node_back_leg != null and palette.has("gi"):
		node_back_leg.color = palette["gi"]

	var node_headband: Polygon2D = get_node_or_null("Visual/Headband") as Polygon2D
	if node_headband != null and palette.has("accent"):
		node_headband.color = palette["accent"]

	var node_ties: Polygon2D = get_node_or_null("Visual/Ties") as Polygon2D
	if node_ties != null and palette.has("accent"):
		node_ties.color = palette["accent"]

	var node_glove: Polygon2D = get_node_or_null("Visual/Glove") as Polygon2D
	if node_glove != null and palette.has("accent"):
		node_glove.color = palette["accent"]

	var node_head: Polygon2D = get_node_or_null("Visual/Head") as Polygon2D
	if node_head != null and palette.has("skin"):
		node_head.color = palette["skin"]

	var node_lead_arm: Polygon2D = get_node_or_null("Visual/LeadArm") as Polygon2D
	if node_lead_arm != null and palette.has("skin"):
		node_lead_arm.color = palette["skin"]

	var node_back_arm: Polygon2D = get_node_or_null("Visual/BackArm") as Polygon2D
	if node_back_arm != null and palette.has("skin"):
		node_back_arm.color = palette["skin"]

	var node_hair: Polygon2D = get_node_or_null("Visual/Hair") as Polygon2D
	if node_hair != null and palette.has("hair"):
		node_hair.color = palette["hair"]

	var node_belt: Polygon2D = get_node_or_null("Visual/Belt") as Polygon2D
	if node_belt != null and palette.has("belt"):
		node_belt.color = palette["belt"]

	var node_belt_knot: Polygon2D = get_node_or_null("Visual/BeltKnot") as Polygon2D
	if node_belt_knot != null and palette.has("belt"):
		node_belt_knot.color = palette["belt"]

func _set_visual_crouch(crouch: bool) -> void:
	if visual != null:
		visual.position = Vector2.ZERO
	if animation_player != null:
		if state == State.BLOCKING:
			var target_anim = "crouch_block" if (crouch and animation_player.has_animation("crouch_block")) else "block"
			if animation_player.current_animation != target_anim:
				_play_animation(target_anim)
		elif state == State.BLOCK_STUN:
			var target_anim = "crouch_block_stun" if (crouch and animation_player.has_animation("crouch_block_stun")) else "block_stun"
			if animation_player.current_animation != target_anim:
				_play_animation(target_anim)

func _find_opponent_and_camera() -> void:
	if opponent == null and get_parent() != null:
		for child in get_parent().get_children():
			if child != self and child is Fighter:
				opponent = child
				break
	if camera == null:
		if get_viewport() != null:
			camera = get_viewport().get_camera_2d()
		if camera == null and get_parent() != null:
			for child in get_parent().get_children():
				if child is Camera2D:
					camera = child
					break

# ---------------------------------------------------------
# Animation Synchronization & Neutral Reset
# ---------------------------------------------------------

func _apply_neutral_reset() -> void:
	if animation_player != null and animation_player.has_animation("RESET"):
		animation_player.play("RESET")
		animation_player.advance(0)
	_reset_limb_transforms()

func _reset_limb_transforms() -> void:
	if visual == null:
		return
	for limb_name in LIMB_NODES:
		var limb: Node2D = visual.get_node_or_null(limb_name) as Node2D
		if limb != null:
			limb.position = Vector2.ZERO
			limb.rotation = 0.0

func _play_animation(anim_name: String) -> void:
	if animation_player != null and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)

func _setup_animations() -> void:
	if animation_player == null:
		return
	if not animation_player.has_animation_library(""):
		var lib: AnimationLibrary = create_animation_library()
		animation_player.add_animation_library("", lib)

static func _add_track(anim: Animation, limb: String, property: String, keys: Array) -> void:
	assert(limb in LIMB_NODES, "Track isolation violation: limb node '%s' is not in LIMB_NODES" % limb)
	var track_idx: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(track_idx, "Visual/%s:%s" % [limb, property])
	anim.track_set_interpolation_type(track_idx, Animation.INTERPOLATION_LINEAR)
	for key in keys:
		anim.track_insert_key(track_idx, key[0], key[1])

static func create_animation_library() -> AnimationLibrary:
	var lib: AnimationLibrary = AnimationLibrary.new()

	# RESET: Neutral Rest Pose for all 12 limb nodes
	var anim_reset: Animation = Animation.new()
	anim_reset.length = 0.001
	for limb in LIMB_NODES:
		_add_track(anim_reset, limb, "position", [[0.0, Vector2.ZERO]])
		_add_track(anim_reset, limb, "rotation", [[0.0, 0.0]])
	lib.add_animation("RESET", anim_reset)

	# idle: rhythmic breathing loop, subtle 2px torso bob, optional tie flutter (24 ticks = 0.4s)
	var anim_idle: Animation = Animation.new()
	anim_idle.length = 24.0 / 60.0
	anim_idle.loop_mode = Animation.LOOP_LINEAR
	var upper_limbs: Array[String] = [
		"TorsoGi", "Belt", "BeltKnot", "Head", "Hair", "Headband", "Ties",
		"LeadArm", "Glove", "BackArm"
	]
	for limb in upper_limbs:
		_add_track(anim_idle, limb, "position", [
			[0.0, Vector2.ZERO],
			[12.0 / 60.0, Vector2(0.0, 2.0)],
			[24.0 / 60.0, Vector2.ZERO]
		])
	_add_track(anim_idle, "Ties", "rotation", [
		[0.0, 0.0],
		[6.0 / 60.0, 0.08],
		[18.0 / 60.0, -0.08],
		[24.0 / 60.0, 0.0]
	])
	lib.add_animation("idle", anim_idle)

	# walk: forward stepping stride swinging LeadLeg and BackLeg (16 ticks = 0.266667s)
	var anim_walk: Animation = Animation.new()
	anim_walk.length = 16.0 / 60.0
	anim_walk.loop_mode = Animation.LOOP_LINEAR
	_add_track(anim_walk, "LeadLeg", "position", [
		[0.0, Vector2.ZERO],
		[4.0 / 60.0, Vector2(4.0, -2.0)],
		[8.0 / 60.0, Vector2.ZERO],
		[12.0 / 60.0, Vector2(-4.0, 0.0)],
		[16.0 / 60.0, Vector2.ZERO]
	])
	_add_track(anim_walk, "BackLeg", "position", [
		[0.0, Vector2.ZERO],
		[4.0 / 60.0, Vector2(-4.0, 0.0)],
		[8.0 / 60.0, Vector2.ZERO],
		[12.0 / 60.0, Vector2(4.0, -2.0)],
		[16.0 / 60.0, Vector2.ZERO]
	])
	_add_track(anim_walk, "LeadArm", "position", [
		[0.0, Vector2.ZERO],
		[4.0 / 60.0, Vector2(-2.0, 0.0)],
		[8.0 / 60.0, Vector2.ZERO],
		[12.0 / 60.0, Vector2(2.0, 0.0)],
		[16.0 / 60.0, Vector2.ZERO]
	])
	_add_track(anim_walk, "Glove", "position", [
		[0.0, Vector2.ZERO],
		[4.0 / 60.0, Vector2(-2.0, 0.0)],
		[8.0 / 60.0, Vector2.ZERO],
		[12.0 / 60.0, Vector2(2.0, 0.0)],
		[16.0 / 60.0, Vector2.ZERO]
	])
	_add_track(anim_walk, "BackArm", "position", [
		[0.0, Vector2.ZERO],
		[4.0 / 60.0, Vector2(2.0, 0.0)],
		[8.0 / 60.0, Vector2.ZERO],
		[12.0 / 60.0, Vector2(-2.0, 0.0)],
		[16.0 / 60.0, Vector2.ZERO]
	])
	lib.add_animation("walk", anim_walk)

	# walk_backward: backward stepping stride swinging LeadLeg and BackLeg (16 ticks = 0.266667s)
	var anim_walk_back: Animation = Animation.new()
	anim_walk_back.length = 16.0 / 60.0
	anim_walk_back.loop_mode = Animation.LOOP_LINEAR
	_add_track(anim_walk_back, "LeadLeg", "position", [
		[0.0, Vector2.ZERO],
		[4.0 / 60.0, Vector2(-4.0, 0.0)],
		[8.0 / 60.0, Vector2.ZERO],
		[12.0 / 60.0, Vector2(4.0, -2.0)],
		[16.0 / 60.0, Vector2.ZERO]
	])
	_add_track(anim_walk_back, "BackLeg", "position", [
		[0.0, Vector2.ZERO],
		[4.0 / 60.0, Vector2(4.0, -2.0)],
		[8.0 / 60.0, Vector2.ZERO],
		[12.0 / 60.0, Vector2(-4.0, 0.0)],
		[16.0 / 60.0, Vector2.ZERO]
	])
	_add_track(anim_walk_back, "LeadArm", "position", [
		[0.0, Vector2.ZERO],
		[4.0 / 60.0, Vector2(2.0, 0.0)],
		[8.0 / 60.0, Vector2.ZERO],
		[12.0 / 60.0, Vector2(-2.0, 0.0)],
		[16.0 / 60.0, Vector2.ZERO]
	])
	_add_track(anim_walk_back, "Glove", "position", [
		[0.0, Vector2.ZERO],
		[4.0 / 60.0, Vector2(2.0, 0.0)],
		[8.0 / 60.0, Vector2.ZERO],
		[12.0 / 60.0, Vector2(-2.0, 0.0)],
		[16.0 / 60.0, Vector2.ZERO]
	])
	_add_track(anim_walk_back, "BackArm", "position", [
		[0.0, Vector2.ZERO],
		[4.0 / 60.0, Vector2(-2.0, 0.0)],
		[8.0 / 60.0, Vector2.ZERO],
		[12.0 / 60.0, Vector2(2.0, 0.0)],
		[16.0 / 60.0, Vector2.ZERO]
	])
	lib.add_animation("walk_backward", anim_walk_back)

	# crouch: held low guard pose, visual height <= 32 px to match crouch hurtbox
	var anim_crouch: Animation = Animation.new()
	anim_crouch.length = 1.0 / 60.0
	var crouch_shifts: Dictionary = {
		"Head": Vector2(0.0, 22.0),
		"Hair": Vector2(0.0, 22.0),
		"Headband": Vector2(0.0, 22.0),
		"Ties": Vector2(0.0, 22.0),
		"TorsoGi": Vector2(0.0, 22.0),
		"Belt": Vector2(0.0, 20.0),
		"BeltKnot": Vector2(0.0, 12.0),
		"LeadArm": Vector2(0.0, 22.0),
		"Glove": Vector2(0.0, 22.0),
		"BackArm": Vector2(0.0, 22.0),
		"LeadLeg": Vector2.ZERO,
		"BackLeg": Vector2.ZERO
	}
	for limb in crouch_shifts:
		_add_track(anim_crouch, limb, "position", [[0.0, crouch_shifts[limb]]])
	lib.add_animation("crouch", anim_crouch)

	# jump_squat: preparatory compression squat (3 ticks = 0.05s)
	var anim_jump_squat: Animation = Animation.new()
	anim_jump_squat.length = 3.0 / 60.0
	for limb in upper_limbs:
		_add_track(anim_jump_squat, limb, "position", [
			[0.0, Vector2(0.0, 6.0)],
			[3.0 / 60.0, Vector2(0.0, 6.0)]
		])
	lib.add_animation("jump_squat", anim_jump_squat)

	# jump: held aerial tuck pose
	var anim_jump: Animation = Animation.new()
	anim_jump.length = 1.0 / 60.0
	_add_track(anim_jump, "LeadLeg", "position", [[0.0, Vector2(0.0, -6.0)]])
	_add_track(anim_jump, "BackLeg", "position", [[0.0, Vector2(0.0, -6.0)]])
	_add_track(anim_jump, "LeadArm", "position", [[0.0, Vector2(0.0, -4.0)]])
	_add_track(anim_jump, "Glove", "position", [[0.0, Vector2(0.0, -4.0)]])
	_add_track(anim_jump, "BackArm", "position", [[0.0, Vector2(0.0, -4.0)]])
	lib.add_animation("jump", anim_jump)

	# fall: held aerial descent pose
	var anim_fall: Animation = Animation.new()
	anim_fall.length = 1.0 / 60.0
	_add_track(anim_fall, "LeadLeg", "position", [[0.0, Vector2(2.0, 2.0)]])
	_add_track(anim_fall, "BackLeg", "position", [[0.0, Vector2(-2.0, 2.0)]])
	lib.add_animation("fall", anim_fall)

	# punch: 12 ticks total (startup ticks 1-4, active ticks 5-7 extending LeadArm +18px, recovery ticks 8-12)
	var anim_punch: Animation = Animation.new()
	anim_punch.length = 12.0 / 60.0
	_add_track(anim_punch, "LeadArm", "position", [
		[0.0, Vector2.ZERO],
		[4.0 / 60.0, Vector2(6.0, 0.0)],
		[5.0 / 60.0, Vector2(18.0, 0.0)],
		[7.0 / 60.0, Vector2(18.0, 0.0)],
		[8.0 / 60.0, Vector2(8.0, 0.0)],
		[12.0 / 60.0, Vector2.ZERO]
	])
	_add_track(anim_punch, "Glove", "position", [
		[0.0, Vector2.ZERO],
		[4.0 / 60.0, Vector2(6.0, 0.0)],
		[5.0 / 60.0, Vector2(18.0, 0.0)],
		[7.0 / 60.0, Vector2(18.0, 0.0)],
		[8.0 / 60.0, Vector2(8.0, 0.0)],
		[12.0 / 60.0, Vector2.ZERO]
	])
	_add_track(anim_punch, "TorsoGi", "position", [
		[0.0, Vector2.ZERO],
		[5.0 / 60.0, Vector2(2.0, 0.0)],
		[7.0 / 60.0, Vector2(2.0, 0.0)],
		[12.0 / 60.0, Vector2.ZERO]
	])
	_add_track(anim_punch, "BackArm", "position", [
		[0.0, Vector2.ZERO],
		[5.0 / 60.0, Vector2(-4.0, 0.0)],
		[7.0 / 60.0, Vector2(-4.0, 0.0)],
		[12.0 / 60.0, Vector2.ZERO]
	])
	lib.add_animation("punch", anim_punch)

	# kick: 19 ticks total (startup ticks 1-7, active ticks 8-11 extending LeadLeg into low kick zone, recovery ticks 12-19)
	var anim_kick: Animation = Animation.new()
	anim_kick.length = 19.0 / 60.0
	_add_track(anim_kick, "LeadLeg", "position", [
		[0.0, Vector2.ZERO],
		[7.0 / 60.0, Vector2(6.0, -4.0)],
		[8.0 / 60.0, Vector2(18.0, -2.0)],
		[11.0 / 60.0, Vector2(18.0, -2.0)],
		[14.0 / 60.0, Vector2(8.0, -2.0)],
		[19.0 / 60.0, Vector2.ZERO]
	])
	_add_track(anim_kick, "TorsoGi", "position", [
		[0.0, Vector2.ZERO],
		[8.0 / 60.0, Vector2(-2.0, 0.0)],
		[11.0 / 60.0, Vector2(-2.0, 0.0)],
		[19.0 / 60.0, Vector2.ZERO]
	])
	lib.add_animation("kick", anim_kick)

	# block: held two-arm cross-guard posture
	var anim_block: Animation = Animation.new()
	anim_block.length = 1.0 / 60.0
	_add_track(anim_block, "LeadArm", "position", [[0.0, Vector2(4.0, -4.0)]])
	_add_track(anim_block, "Glove", "position", [[0.0, Vector2(4.0, -4.0)]])
	_add_track(anim_block, "BackArm", "position", [[0.0, Vector2(2.0, -6.0)]])
	lib.add_animation("block", anim_block)

	# block_stun: plays once, holds last pose (lasts 8 ticks)
	var anim_block_stun: Animation = Animation.new()
	anim_block_stun.length = 8.0 / 60.0
	_add_track(anim_block_stun, "LeadArm", "position", [
		[0.0, Vector2(2.0, -4.0)],
		[8.0 / 60.0, Vector2(2.0, -4.0)]
	])
	_add_track(anim_block_stun, "Glove", "position", [
		[0.0, Vector2(2.0, -4.0)],
		[8.0 / 60.0, Vector2(2.0, -4.0)]
	])
	_add_track(anim_block_stun, "BackArm", "position", [
		[0.0, Vector2(0.0, -6.0)],
		[8.0 / 60.0, Vector2(0.0, -6.0)]
	])
	_add_track(anim_block_stun, "TorsoGi", "position", [
		[0.0, Vector2(-2.0, 0.0)],
		[8.0 / 60.0, Vector2(-2.0, 0.0)]
	])
	lib.add_animation("block_stun", anim_block_stun)

	# crouch_block: held crouch cross-guard posture (visual height <= 32px)
	var anim_crouch_block: Animation = Animation.new()
	anim_crouch_block.length = 1.0 / 60.0
	for limb in crouch_shifts:
		var pos: Vector2 = crouch_shifts[limb]
		if limb == "LeadArm":
			pos += Vector2(4.0, -4.0)
		elif limb == "Glove":
			pos += Vector2(4.0, -4.0)
		elif limb == "BackArm":
			pos += Vector2(2.0, -6.0)
		_add_track(anim_crouch_block, limb, "position", [[0.0, pos]])
	lib.add_animation("crouch_block", anim_crouch_block)

	# crouch_block_stun: holds last pose (lasts 8 ticks, visual height <= 32px)
	var anim_crouch_block_stun: Animation = Animation.new()
	anim_crouch_block_stun.length = 8.0 / 60.0
	for limb in crouch_shifts:
		var pos: Vector2 = crouch_shifts[limb]
		if limb == "LeadArm":
			pos += Vector2(2.0, -4.0)
		elif limb == "Glove":
			pos += Vector2(2.0, -4.0)
		elif limb == "BackArm":
			pos += Vector2(0.0, -6.0)
		elif limb == "TorsoGi":
			pos += Vector2(-2.0, 0.0)
		_add_track(anim_crouch_block_stun, limb, "position", [
			[0.0, pos],
			[8.0 / 60.0, pos]
		])
	lib.add_animation("crouch_block_stun", anim_crouch_block_stun)

	# hit: plays once, holds last pose (recoil leaning backward, lasts 18 ticks)
	var anim_hit: Animation = Animation.new()
	anim_hit.length = 18.0 / 60.0
	_add_track(anim_hit, "TorsoGi", "position", [
		[0.0, Vector2(-6.0, 2.0)],
		[18.0 / 60.0, Vector2(-6.0, 2.0)]
	])
	_add_track(anim_hit, "Head", "position", [
		[0.0, Vector2(-8.0, 0.0)],
		[18.0 / 60.0, Vector2(-8.0, 0.0)]
	])
	_add_track(anim_hit, "Hair", "position", [
		[0.0, Vector2(-8.0, 0.0)],
		[18.0 / 60.0, Vector2(-8.0, 0.0)]
	])
	_add_track(anim_hit, "Headband", "position", [
		[0.0, Vector2(-8.0, 0.0)],
		[18.0 / 60.0, Vector2(-8.0, 0.0)]
	])
	_add_track(anim_hit, "Ties", "position", [
		[0.0, Vector2(-8.0, 0.0)],
		[18.0 / 60.0, Vector2(-8.0, 0.0)]
	])
	_add_track(anim_hit, "Belt", "position", [
		[0.0, Vector2(-4.0, 2.0)],
		[18.0 / 60.0, Vector2(-4.0, 2.0)]
	])
	_add_track(anim_hit, "BeltKnot", "position", [
		[0.0, Vector2(-4.0, 2.0)],
		[18.0 / 60.0, Vector2(-4.0, 2.0)]
	])
	_add_track(anim_hit, "BackArm", "position", [
		[0.0, Vector2(-6.0, 2.0)],
		[18.0 / 60.0, Vector2(-6.0, 2.0)]
	])
	_add_track(anim_hit, "LeadArm", "position", [
		[0.0, Vector2.ZERO],
		[18.0 / 60.0, Vector2.ZERO]
	])
	_add_track(anim_hit, "Glove", "position", [
		[0.0, Vector2.ZERO],
		[18.0 / 60.0, Vector2.ZERO]
	])
	lib.add_animation("hit", anim_hit)

	# knockdown & dead: held poses lying flat on floor (height <= 16 px)
	var knockdown_data: Dictionary = {
		"BackArm": [Vector2(0.0, -10.0), -PI * 0.5],
		"BackLeg": [Vector2(0.0, -12.0), -PI * 0.5],
		"TorsoGi": [Vector2(0.0, -8.0), -PI * 0.5],
		"Belt": [Vector2(0.0, -8.0), -PI * 0.5],
		"BeltKnot": [Vector2(0.0, -6.0), -PI * 0.5],
		"Head": [Vector2(0.0, -8.0), -PI * 0.5],
		"Hair": [Vector2(0.0, -8.0), -PI * 0.5],
		"Headband": [Vector2(0.0, -8.0), -PI * 0.5],
		"Ties": [Vector2(0.0, -15.0), -PI * 0.5],
		"LeadLeg": [Vector2(0.0, -5.0), -PI * 0.5],
		"LeadArm": [Vector2(0.0, -4.0), -PI * 0.5],
		"Glove": [Vector2(0.0, 1.0), -PI * 0.5]
	}
	for anim_name in ["knockdown", "dead"]:
		var a: Animation = Animation.new()
		a.length = 1.0 / 60.0
		for limb in knockdown_data:
			_add_track(a, limb, "position", [[0.0, knockdown_data[limb][0]]])
			_add_track(a, limb, "rotation", [[0.0, knockdown_data[limb][1]]])
		lib.add_animation(anim_name, a)

	return lib

