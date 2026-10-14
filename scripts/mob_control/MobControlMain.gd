class_name MobControlMain
extends Node3D

## Main scene controller for Mob Control 3D.
## Manages 4-phase deterministic stepping: Motion -> Contact Resolution -> State Evaluation -> Bounds Cleanup.
## Enforces MAX_MOBS = 300 cap, 1-to-1 swarm attrition, modifier gate replication, and Giant Boss assault.

signal return_to_menu_requested

enum GameState { PLAYING, VICTORY, DEFEAT }

const MAX_MOBS: int = 300
const BLUE_SPEED: float = -9.0
const RED_SPEED: float = 4.2
const GIANT_SPEED: float = 1.0
const RED_SPAWN_START_TIME: float = 1.0
const RED_SPAWN_INTERVAL: float = 1.0

var state: GameState = GameState.PLAYING
var _returning_to_menu: bool = false
var pending_spawns: int = 0
var pending_spawn_queue: Array = []
var red_spawn_timer: float = 0.0
var time_elapsed: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

const Cannon3DScript = preload("res://scripts/mob_control/Cannon3D.gd")
const GiantEnemy3DScript = preload("res://scripts/mob_control/GiantEnemy3D.gd")
const MultiplierGate3DScript = preload("res://scripts/mob_control/MultiplierGate3D.gd")
const MobUnit3DScript = preload("res://scripts/mob_control/MobUnit3D.gd")
const MobUnitScene = preload("res://scenes/mob_control/MobUnit3D.tscn")

var blue_mobs: Array[MobUnit3DScript] = []
var red_mobs: Array[MobUnit3DScript] = []

@onready var cannon: Cannon3DScript = $Cannon if has_node("Cannon") else null
@onready var giant_enemy: GiantEnemy3DScript = $GiantEnemy if has_node("GiantEnemy") else null
@onready var gates_container: Node3D = $Gates if has_node("Gates") else null
@onready var victory_banner: Control = $UI/VictoryBanner if has_node("UI/VictoryBanner") else null
@onready var defeat_banner: Control = $UI/DefeatBanner if has_node("UI/DefeatBanner") else null
@onready var controls_hint: Label = $UI/ControlsHint if has_node("UI/ControlsHint") else null

func _ready() -> void:
	_resolve_nodes()
	if is_instance_valid(cannon) and not cannon.shoot_requested.is_connected(_on_cannon_shoot_requested):
		cannon.shoot_requested.connect(_on_cannon_shoot_requested)
	if is_instance_valid(victory_banner):
		victory_banner.visible = false
	if is_instance_valid(defeat_banner):
		defeat_banner.visible = false

func _resolve_nodes() -> void:
	if cannon == null:
		cannon = get_node_or_null("Cannon")
	if giant_enemy == null:
		giant_enemy = get_node_or_null("GiantEnemy")
	if gates_container == null:
		gates_container = get_node_or_null("Gates")
	if victory_banner == null:
		victory_banner = get_node_or_null("UI/VictoryBanner")
	if defeat_banner == null:
		defeat_banner = get_node_or_null("UI/DefeatBanner")
	if controls_hint == null:
		controls_hint = get_node_or_null("UI/ControlsHint")

func _physics_process(delta: float) -> void:
	step(delta)

func step(delta: float) -> void:
	if state != GameState.PLAYING:
		return

	_resolve_nodes()

	# Pre-tick dead instance pruning
	for i in range(blue_mobs.size() - 1, -1, -1):
		if not is_instance_valid(blue_mobs[i]):
			blue_mobs.remove_at(i)
	for i in range(red_mobs.size() - 1, -1, -1):
		if not is_instance_valid(red_mobs[i]):
			red_mobs.remove_at(i)

	# --- Phase 1: Motion & Spawner ---
	if is_instance_valid(cannon):
		cannon.step(delta)

	for mob in blue_mobs:
		if is_live(mob):
			mob.position.z += BLUE_SPEED * delta

	for mob in red_mobs:
		if is_live(mob):
			mob.position.z += RED_SPEED * delta

	if is_instance_valid(giant_enemy):
		giant_enemy.position.z += GIANT_SPEED * delta

	time_elapsed += delta
	red_spawn_timer += delta
	while red_spawn_timer >= RED_SPAWN_START_TIME:
		red_spawn_timer -= RED_SPAWN_INTERVAL
		_spawn_red_mob()

	# --- Phase 2: Explicit Contact Resolution Pass ---
	_resolve_gate_contacts()
	_resolve_mob_clashes()
	_resolve_giant_contacts()

	# --- Phase 3: State Evaluation & Latch ---
	_evaluate_game_state()

	# --- Phase 4: Bounds Cleanup ---
	_cleanup_out_of_bounds_mobs()

func _on_cannon_shoot_requested(muzzle_pos: Vector3) -> void:
	if state != GameState.PLAYING:
		return
	if get_live_blue_mobs_count() + pending_spawns >= MAX_MOBS:
		return
	_spawn_blue_mob(muzzle_pos)

func _spawn_blue_mob(pos: Vector3, p_passed_gates: Dictionary = {}) -> MobUnit3DScript:
	var mob = MobUnitScene.instantiate() as MobUnit3DScript
	mob.position = pos
	mob.passed_gates = p_passed_gates.duplicate()
	mob.setup("blue")
	add_child(mob)
	blue_mobs.append(mob)
	return mob

func _spawn_red_mob() -> MobUnit3DScript:
	if state != GameState.PLAYING:
		return null
	var mob = MobUnitScene.instantiate() as MobUnit3DScript
	var x = rng.randf_range(-4.5, 4.5)
	mob.position = Vector3(x, 0.5, -22.0)
	mob.setup("red")
	add_child(mob)
	red_mobs.append(mob)
	return mob

func on_mob_entered_gate(mob: MobUnit3DScript, gate: MultiplierGate3DScript) -> void:
	if not is_live(mob) or mob.passed_gates.has(gate.gate_id):
		return
	mob.passed_gates[gate.gate_id] = true

	var k: int = gate.calculate_clones()
	var remaining_space: int = MAX_MOBS - (get_live_blue_mobs_count() + pending_spawns)
	var allowed: int = maxi(0, mini(k, remaining_space))
	if allowed <= 0:
		return

	pending_spawns += allowed
	for i in range(allowed):
		var clone_pos = Vector3(mob.global_position.x, 0.5, gate.global_position.z - 0.6)
		var clone_data = {
			"pos": clone_pos,
			"passed_gates": mob.passed_gates.duplicate()
		}
		pending_spawn_queue.append(clone_data)
		call_deferred("_deferred_spawn_clone", clone_data)

func _deferred_spawn_clone(clone_data: Dictionary) -> void:
	var idx = pending_spawn_queue.find(clone_data)
	if idx != -1:
		pending_spawn_queue.remove_at(idx)
		_instantiate_clone(clone_data)

func _instantiate_clone(clone_data: Dictionary) -> void:
	if pending_spawns > 0:
		pending_spawns -= 1
	_spawn_blue_mob(clone_data["pos"], clone_data["passed_gates"])

func flush_pending_spawns() -> void:
	var queue_copy = pending_spawn_queue.duplicate()
	pending_spawn_queue.clear()
	for item in queue_copy:
		_instantiate_clone(item)

func on_mob_clash(blue: MobUnit3DScript, red: MobUnit3DScript) -> void:
	if not is_live(blue) or not is_live(red):
		return
	blue.is_consumed = true
	red.is_consumed = true
	blue.queue_free()
	red.queue_free()

func on_mob_hit_giant(blue: MobUnit3DScript, giant: GiantEnemy3DScript) -> void:
	if not is_live(blue):
		return
	blue.is_consumed = true
	blue.queue_free()
	if is_instance_valid(giant):
		giant.take_damage(1)

func _resolve_gate_contacts() -> void:
	if gates_container == null:
		return
	for child in gates_container.get_children():
		if child is MultiplierGate3DScript:
			var gate: MultiplierGate3DScript = child
			var gz = gate.global_position.z
			var gx = gate.global_position.x
			var gy = gate.global_position.y
			for mob in blue_mobs:
				if not is_live(mob):
					continue
				if abs(mob.global_position.x - gx) <= (2.0 + 0.22) and \
				   abs(mob.global_position.z - gz) <= (0.3 + 0.22) and \
				   abs(mob.global_position.y - gy) <= (1.0 + 0.35):
					on_mob_entered_gate(mob, gate)

func _resolve_mob_clashes() -> void:
	for blue in blue_mobs:
		if not is_live(blue):
			continue
		for red in red_mobs:
			if not is_live(red):
				continue
			if abs(blue.global_position.x - red.global_position.x) <= 0.44 and \
			   abs(blue.global_position.z - red.global_position.z) <= 0.44 and \
			   abs(blue.global_position.y - red.global_position.y) <= 0.70:
				on_mob_clash(blue, red)
				break

func _resolve_giant_contacts() -> void:
	if not is_instance_valid(giant_enemy):
		return
	var gx = giant_enemy.global_position.x
	var gz = giant_enemy.global_position.z
	var gy = giant_enemy.global_position.y

	for blue in blue_mobs:
		if not is_live(blue):
			continue
		if abs(blue.global_position.x - gx) <= (4.75 + 0.22) and \
		   abs(blue.global_position.z - gz) <= (1.25 + 0.22) and \
		   abs(blue.global_position.y - gy) <= (1.25 + 0.35):
			on_mob_hit_giant(blue, giant_enemy)

func _evaluate_game_state() -> void:
	# Check Defeat condition first
	var defeat_triggered: bool = false
	if is_instance_valid(giant_enemy) and giant_enemy.global_position.z >= 9.0:
		defeat_triggered = true
	else:
		for red in red_mobs:
			if is_live(red) and red.global_position.z >= 9.0:
				defeat_triggered = true
				break

	if defeat_triggered:
		state = GameState.DEFEAT
		if defeat_banner != null:
			defeat_banner.visible = true
		return

	# Check Victory condition second (only when not in Defeat)
	if is_instance_valid(giant_enemy) and giant_enemy.hp <= 0:
		state = GameState.VICTORY
		if victory_banner != null:
			victory_banner.visible = true

func _cleanup_out_of_bounds_mobs() -> void:
	var surviving_blue: Array[MobUnit3DScript] = []
	for mob in blue_mobs:
		if is_live(mob):
			if mob.global_position.z < -25.0:
				mob.queue_free()
			else:
				surviving_blue.append(mob)
	blue_mobs = surviving_blue

	var surviving_red: Array[MobUnit3DScript] = []
	for mob in red_mobs:
		if is_live(mob):
			if mob.global_position.z > 12.0:
				mob.queue_free()
			else:
				surviving_red.append(mob)
	red_mobs = surviving_red

func is_live(mob: Variant) -> bool:
	if mob == null or not is_instance_valid(mob):
		return false
	if mob is Node and (mob as Node).is_queued_for_deletion():
		return false
	if "is_consumed" in mob and mob.is_consumed:
		return false
	return true

func get_live_blue_mobs_count() -> int:
	var count: int = 0
	for mob in blue_mobs:
		if is_live(mob):
			count += 1
	return count

func cleanup_all_mobs() -> void:
	for mob in blue_mobs:
		if is_instance_valid(mob):
			mob.free()
	blue_mobs.clear()
	for mob in red_mobs:
		if is_instance_valid(mob):
			mob.free()
	red_mobs.clear()
	pending_spawns = 0
	pending_spawn_queue.clear()

func reset_stage() -> void:
	state = GameState.PLAYING
	if is_instance_valid(giant_enemy):
		giant_enemy.reset(150)
	if is_instance_valid(cannon):
		cannon.reset()
	red_spawn_timer = 0.0
	time_elapsed = 0.0
	cleanup_all_mobs()
	if is_instance_valid(victory_banner):
		victory_banner.visible = false
	if is_instance_valid(defeat_banner):
		defeat_banner.visible = false
	_returning_to_menu = false

func return_to_menu() -> void:
	if _returning_to_menu:
		return
	_returning_to_menu = true
	return_to_menu_requested.emit()
	if is_inside_tree() and get_tree() != null and (get_tree().current_scene == self or get_tree().current_scene == null):
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		return_to_menu()
		if get_viewport():
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		if state != GameState.PLAYING:
			reset_stage()
			if get_viewport():
				get_viewport().set_input_as_handled()
