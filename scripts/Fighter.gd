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
const GI_COLOR_P1: Color = Color(0.2, 0.4, 0.9, 1.0)
const GI_COLOR_P2: Color = Color(0.9, 0.2, 0.2, 1.0)

@export var player_id: int = 1
@export var max_health: int = MAX_HEALTH
var health: int = MAX_HEALTH
var state: State = State.IDLE
var facing: int = 1
var is_dummy: bool = false
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
@onready var body_rect: ColorRect = $Visual/Body if has_node("Visual/Body") else null
@onready var head_rect: ColorRect = $Visual/Head if has_node("Visual/Head") else null
@onready var attack_visual: ColorRect = $Visual/AttackVisual if has_node("Visual/AttackVisual") else null

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
	if body_rect == null and has_node("Visual/Body"):
		body_rect = $Visual/Body
	if head_rect == null and has_node("Visual/Head"):
		head_rect = $Visual/Head
	if attack_visual == null and has_node("Visual/AttackVisual"):
		attack_visual = $Visual/AttackVisual

## Configures the fighter for Player 1 or Player 2.
## P1: Hurtbox Layer 4, Hitbox Layer 5 (mask 6), gi color blue.
## P2: Hurtbox Layer 6, Hitbox Layer 7 (mask 4), gi color red.
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
		set_gi_color(GI_COLOR_P1)
	elif player_id == 2:
		facing = -1
		set_gi_color(GI_COLOR_P2)

	set_facing(facing)

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

	var input_dir: float = _get_horizontal_input()
	if input_dir != 0.0:
		if (input_dir > 0 and facing == 1) or (input_dir < 0 and facing == -1):
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

	var input_dir: float = _get_horizontal_input()
	if (input_dir > 0 and facing == -1) or (input_dir < 0 and facing == 1):
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

	var input_dir: float = _get_horizontal_input()
	if (input_dir > 0 and facing == 1) or (input_dir < 0 and facing == -1):
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
		_set_attack_visual(true, "punch")
	elif attack_tick == PUNCH_STARTUP_TICKS + PUNCH_ACTIVE_TICKS + 1:
		if hitbox != null:
			hitbox.deactivate()
		_set_attack_visual(false)
	elif attack_tick > PUNCH_TOTAL_TICKS:
		if hitbox != null:
			hitbox.deactivate()
		_set_attack_visual(false)
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
		_set_attack_visual(true, "kick")
	elif attack_tick == KICK_STARTUP_TICKS + KICK_ACTIVE_TICKS + 1:
		if hitbox != null:
			hitbox.deactivate()
		_set_attack_visual(false)
	elif attack_tick > KICK_TOTAL_TICKS:
		if hitbox != null:
			hitbox.deactivate()
		_set_attack_visual(false)
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
		_set_attack_visual(false)

	# Enter new state
	match new_state:
		State.IDLE:
			velocity.x = 0.0
			is_crouch_blocking = false
			if hurtbox != null:
				hurtbox.set_crouching(false)
			_set_visual_crouch(false)
		State.WALK_FORWARD:
			velocity.x = float(facing) * WALK_FORWARD_SPEED
		State.WALK_BACKWARD:
			velocity.x = -float(facing) * WALK_BACKWARD_SPEED
		State.CROUCHING:
			velocity.x = 0.0
			if hurtbox != null:
				hurtbox.set_crouching(true)
			_set_visual_crouch(true)
		State.BLOCKING:
			velocity.x = 0.0
			if is_action_pressed("down") or is_crouch_blocking:
				is_crouch_blocking = true
				if hurtbox != null:
					hurtbox.set_crouching(true)
				_set_visual_crouch(true)
			else:
				is_crouch_blocking = false
				if hurtbox != null:
					hurtbox.set_crouching(false)
				_set_visual_crouch(false)
		State.JUMP_SQUAT:
			velocity = Vector2.ZERO
			jump_squat_timer = 0
		State.JUMPING:
			velocity.y = JUMP_VELOCITY
			velocity.x = jump_dir_x
			if hurtbox != null:
				hurtbox.set_crouching(false)
			_set_visual_crouch(false)
		State.ATTACK_PUNCH:
			velocity.x = 0.0
			attack_tick = 0
			if hitbox != null:
				hitbox.configure_punch(facing, self)
				hitbox.deactivate()
		State.ATTACK_KICK:
			velocity.x = 0.0
			attack_tick = 0
			if hitbox != null:
				hitbox.configure_kick(facing, self)
				hitbox.deactivate()
		State.KNOCKDOWN:
			velocity.x = 0.0
			knockdown_timer = 0
			if hitbox != null:
				hitbox.deactivate()
			knocked_down.emit()
		State.DEAD:
			velocity = Vector2.ZERO
			if hitbox != null:
				hitbox.deactivate()
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
	_set_attack_visual(false)

	if player_id == 1:
		facing = 1
	elif player_id == 2:
		facing = -1
	set_facing(facing)

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
	if is_dummy and player_id == 2:
		return false
	return Input.is_action_pressed(get_action_name(action))

func is_action_just_pressed(action: String) -> bool:
	if is_dummy and player_id == 2:
		return false
	return Input.is_action_just_pressed(get_action_name(action))

func is_action_just_released(action: String) -> bool:
	if is_dummy and player_id == 2:
		return false
	return Input.is_action_just_released(get_action_name(action))

func _get_horizontal_input() -> float:
	var left_pressed: bool = is_action_pressed("left")
	var right_pressed: bool = is_action_pressed("right")
	if left_pressed and not right_pressed:
		return -1.0
	elif right_pressed and not left_pressed:
		return 1.0
	return 0.0

func set_gi_color(color: Color) -> void:
	if body_rect != null:
		body_rect.color = color

func _set_visual_crouch(crouch: bool) -> void:
	if body_rect != null:
		if crouch:
			body_rect.offset_top = -32.0
		else:
			body_rect.offset_top = -54.0
	if head_rect != null:
		if crouch:
			head_rect.offset_top = -32.0
			head_rect.offset_bottom = -18.0
		else:
			head_rect.offset_top = -54.0
			head_rect.offset_bottom = -40.0

func _set_attack_visual(active: bool, attack_type: String = "") -> void:
	if attack_visual != null:
		attack_visual.visible = active
		if active:
			if attack_type == "punch":
				attack_visual.offset_left = 12.0
				attack_visual.offset_top = -42.0
				attack_visual.offset_right = 32.0
				attack_visual.offset_bottom = -30.0
			elif attack_type == "kick":
				attack_visual.offset_left = 12.0
				attack_visual.offset_top = -18.0
				attack_visual.offset_right = 36.0
				attack_visual.offset_bottom = -6.0

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
