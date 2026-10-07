class_name Main
extends Node2D

const FighterScript = preload("res://scripts/Fighter.gd")
const AIControllerScript = preload("res://scripts/AIController.gd")

## Main Match Loop & Orchestrator for Retro Fighter.
## Orchestrates the match FSM: ROUND_INTRO (1.5s) -> IN_ROUND (inputs active, timer 99s)
## -> ROUND_OVER (emits round_ended signal) -> RESET (3.0s delay, resets fighters, restores IDLE).

signal round_ended(winner_id: int, reason: String)
signal match_state_changed(old_state: MatchState, new_state: MatchState)

enum MatchState {
	ROUND_INTRO,
	IN_ROUND,
	ROUND_OVER,
	RESET
}

const ROUND_INTRO_DURATION: float = 1.5
const ROUND_OVER_DURATION: float = 3.0
const INITIAL_ROUND_TIME: int = 99
const P1_START_X: float = 200.0
const P2_START_X: float = 400.0
const FLOOR_Y: float = 190.0

@export var round_intro_duration: float = ROUND_INTRO_DURATION
@export var round_over_duration: float = ROUND_OVER_DURATION
@export var initial_round_time: int = INITIAL_ROUND_TIME

var match_state: MatchState = MatchState.RESET
var round_timer: float = float(INITIAL_ROUND_TIME)
var state_timer: float = 0.0
var last_winner_id: int = 0
var last_reason: String = ""
var ai_controller: Node = null

@onready var p1: CharacterBody2D = $P1 if has_node("P1") else null
@onready var p2: CharacterBody2D = $P2 if has_node("P2") else null
@onready var hud: CanvasLayer = $HUD if has_node("HUD") else null
@onready var camera: Camera2D = $Camera2D if has_node("Camera2D") else null
@onready var stage: Node2D = $Stage if has_node("Stage") else null

var bgm_player: AudioStreamPlayer = null

func _ready() -> void:
	process_physics_priority = 50
	_resolve_nodes()
	if is_instance_valid(p1) and p1.has_method("_ready") and p1.get("hitbox") == null:
		p1._ready()
	if is_instance_valid(p2) and p2.has_method("_ready") and p2.get("hitbox") == null:
		p2._ready()
	if is_instance_valid(hud) and hud.has_method("_ready") and hud.get("timer_label") == null:
		hud._ready()
	start_match()

func _resolve_nodes() -> void:
	if p1 == null and has_node("P1"):
		p1 = get_node("P1")
	if p2 == null and has_node("P2"):
		p2 = get_node("P2")
	if hud == null and has_node("HUD"):
		hud = get_node("HUD")
	if camera == null and has_node("Camera2D"):
		camera = get_node("Camera2D")
	if stage == null and has_node("Stage"):
		stage = get_node("Stage")
	if bgm_player == null and has_node("BGMPlayer"):
		bgm_player = get_node("BGMPlayer")

	if p1 == null or p2 == null:
		for child in get_children():
			if child.get_script() == FighterScript or (child is CharacterBody2D and "player_id" in child):
				if child.player_id == 1 and p1 == null:
					p1 = child
				elif child.player_id == 2 and p2 == null:
					p2 = child
	if hud == null:
		for child in get_children():
			if child is CanvasLayer or child.name == "HUD":
				hud = child
				break
	if camera == null:
		for child in get_children():
			if child is Camera2D:
				camera = child
				break
	if stage == null:
		for child in get_children():
			if child.name == "Stage":
				stage = child
				break

	if is_instance_valid(p1):
		if not p1.health_changed.is_connected(_on_p1_health_changed):
			p1.health_changed.connect(_on_p1_health_changed)
	if is_instance_valid(p2):
		if not p2.health_changed.is_connected(_on_p2_health_changed):
			p2.health_changed.connect(_on_p2_health_changed)
		if p2.get("is_cpu"):
			if ai_controller == null:
				for child in p2.get_children():
					if child.get_script() == AIControllerScript:
						ai_controller = child
						break
				if ai_controller == null:
					ai_controller = AIControllerScript.new()
					p2.add_child(ai_controller)
			ai_controller.setup(p2, p1)

## Starts the full match sequence from Round 1.
func start_match() -> void:
	start_round()

## Initializes and begins a new round.
func start_round() -> void:
	round_timer = float(initial_round_time)
	state_timer = 0.0

	if is_instance_valid(ai_controller) and ai_controller.has_method("reset"):
		ai_controller.reset()

	if is_instance_valid(p1):
		p1.reset_round(P1_START_X)
		p1.global_position.y = FLOOR_Y
	if is_instance_valid(p2):
		p2.reset_round(P2_START_X)
		p2.global_position.y = FLOOR_Y

	if is_instance_valid(hud):
		if hud.has_method("reset_hud"):
			hud.reset_hud()
		elif hud.has_method("update_timer"):
			hud.update_timer(initial_round_time)

	change_match_state(MatchState.ROUND_INTRO, true)

## Transitions match FSM to new_state and applies entry logic.
func change_match_state(new_state: MatchState, force: bool = false) -> void:
	if not force and match_state == new_state:
		return
	var old_state = match_state
	match_state = new_state
	state_timer = 0.0

	match new_state:
		MatchState.ROUND_INTRO:
			_set_inputs_frozen(true)
			if is_instance_valid(hud):
				if hud.has_method("show_announcer"):
					hud.show_announcer("FIGHT!")
				elif hud.has_node("AnnouncerLabel"):
					hud.get_node("AnnouncerLabel").text = "FIGHT!"
					hud.get_node("AnnouncerLabel").visible = true
		MatchState.IN_ROUND:
			_set_inputs_frozen(false)
			if is_instance_valid(hud):
				if hud.has_method("hide_announcer"):
					hud.hide_announcer()
				elif hud.has_node("AnnouncerLabel"):
					hud.get_node("AnnouncerLabel").text = ""
					hud.get_node("AnnouncerLabel").visible = false
			_on_round_started()
		MatchState.ROUND_OVER:
			_set_inputs_frozen(true)
		MatchState.RESET:
			_perform_reset()

	match_state_changed.emit(old_state, new_state)

func _on_round_started() -> void:
	if is_instance_valid(bgm_player) and is_inside_tree():
		if not bgm_player.playing:
			bgm_player.play()

func _physics_process(delta: float) -> void:
	step(delta)

## Advances the match simulation by delta seconds.
## Deterministic stepping hook for tests and physics frames.
func step(delta: float) -> void:
	match match_state:
		MatchState.ROUND_INTRO:
			state_timer += delta
			if state_timer >= round_intro_duration:
				change_match_state(MatchState.IN_ROUND)

		MatchState.IN_ROUND:
			# Check terminal conditions (KO / Double KO) first
			if check_terminal_conditions():
				return

			# Countdown timer
			round_timer = max(0.0, round_timer - delta)
			if is_instance_valid(hud):
				if hud.has_method("update_timer"):
					hud.update_timer(ceili(round_timer))
				elif hud.has_node("TimerLabel"):
					hud.get_node("TimerLabel").text = "%02d" % ceili(round_timer)

			if round_timer <= 0.0:
				_handle_timeout()

		MatchState.ROUND_OVER:
			state_timer += delta
			if state_timer >= round_over_duration:
				change_match_state(MatchState.RESET)

		MatchState.RESET:
			start_round()

## Evaluates whether KO or Double KO terminal condition is met.
func check_terminal_conditions() -> bool:
	if match_state != MatchState.IN_ROUND:
		return false

	var p1_hp: int = p1.health if is_instance_valid(p1) else 100
	var p2_hp: int = p2.health if is_instance_valid(p2) else 100

	if p1_hp <= 0 or p2_hp <= 0:
		if p1_hp <= 0 and p2_hp <= 0:
			_trigger_round_over(0, "DRAW", "DRAW")
		elif p1_hp <= 0:
			_trigger_round_over(2, "KO", "K.O.")
		elif p2_hp <= 0:
			_trigger_round_over(1, "KO", "K.O.")
		return true
	return false

func _handle_timeout() -> void:
	var p1_hp: int = p1.health if is_instance_valid(p1) else 100
	var p2_hp: int = p2.health if is_instance_valid(p2) else 100

	if p1_hp > p2_hp:
		_trigger_round_over(1, "TIME_UP", "TIME UP")
	elif p2_hp > p1_hp:
		_trigger_round_over(2, "TIME_UP", "TIME UP")
	else:
		_trigger_round_over(0, "DRAW", "DRAW")

func _trigger_round_over(winner_id: int, reason: String, banner: String) -> void:
	last_winner_id = winner_id
	last_reason = reason
	change_match_state(MatchState.ROUND_OVER)

	if is_instance_valid(hud):
		if hud.has_method("show_announcer"):
			hud.show_announcer(banner)
		elif hud.has_node("AnnouncerLabel"):
			hud.get_node("AnnouncerLabel").text = banner
			hud.get_node("AnnouncerLabel").visible = true

	round_ended.emit(winner_id, reason)

func _perform_reset() -> void:
	if is_instance_valid(ai_controller) and ai_controller.has_method("reset"):
		ai_controller.reset()
	start_round()

func _set_inputs_frozen(frozen: bool) -> void:
	if is_instance_valid(p1):
		p1.inputs_frozen = frozen
		if frozen and (p1.state == FighterScript.State.WALK_FORWARD or p1.state == FighterScript.State.WALK_BACKWARD):
			p1.change_state(FighterScript.State.IDLE)
			p1.velocity.x = 0.0
	if is_instance_valid(p2):
		p2.inputs_frozen = frozen
		if frozen and (p2.state == FighterScript.State.WALK_FORWARD or p2.state == FighterScript.State.WALK_BACKWARD):
			p2.change_state(FighterScript.State.IDLE)
			p2.velocity.x = 0.0

func _on_p1_health_changed(new_health: int, max_health: int) -> void:
	if is_instance_valid(hud):
		if hud.has_method("update_p1_health"):
			hud.update_p1_health(new_health, max_health)
		elif hud.has_node("P1HealthBar"):
			hud.get_node("P1HealthBar").value = new_health
	if new_health <= 0:
		check_terminal_conditions()

func _on_p2_health_changed(new_health: int, max_health: int) -> void:
	if is_instance_valid(hud):
		if hud.has_method("update_p2_health"):
			hud.update_p2_health(new_health, max_health)
		elif hud.has_node("P2HealthBar"):
			hud.get_node("P2HealthBar").value = new_health
	if new_health <= 0:
		check_terminal_conditions()
