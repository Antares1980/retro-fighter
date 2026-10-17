class_name MobControlMain
extends Node3D

## Main scene controller for Mob Control 3D.
## Manages 4-phase deterministic stepping: Motion -> Contact Resolution -> State Evaluation -> Bounds Cleanup.
## Enforces MAX_MOBS = 300 cap, 1-to-1 swarm attrition, modifier gate replication, and Giant Boss assault.

signal return_to_menu_requested

enum GameState { PLAYING, STAGE_CLEAR, VICTORY, DEFEAT }

const STAGES: Array[Dictionary] = [
	{
		"stage": 1,
		"base_hp": 1200,
		"highway_depth": -32.0,
		"highway_min_z": -32.0,
		"cleanup_bound": -35.0,
		"lock_1": {"hp": 250, "surge_reds": 5, "speed_mult": 1.0},
		"lock_2": {"hp": 350, "surge_reds": 8, "speed_mult": 1.0},
		"lock_3": {"hp": 500, "surge_reds": 12, "speed_mult": 1.0},
		"vault_hp": 400,
		"unlocked_gate": "x4",
		"vault_gate_mult": 4,
		"red_spawn_interval": 1.8,
	},
	{
		"stage": 2,
		"base_hp": 2500,
		"highway_depth": -36.0,
		"highway_min_z": -36.0,
		"cleanup_bound": -39.0,
		"lock_1": {"hp": 400, "surge_reds": 8, "speed_mult": 1.0},
		"lock_2": {"hp": 550, "surge_reds": 12, "speed_mult": 1.05},
		"lock_3": {"hp": 750, "surge_reds": 16, "speed_mult": 1.05},
		"vault_hp": 700,
		"unlocked_gate": "x4",
		"vault_gate_mult": 4,
		"red_spawn_interval": 1.5,
	},
	{
		"stage": 3,
		"base_hp": 4500,
		"highway_depth": -42.0,
		"highway_min_z": -42.0,
		"cleanup_bound": -45.0,
		"lock_1": {"hp": 600, "surge_reds": 10, "speed_mult": 1.05},
		"lock_2": {"hp": 850, "surge_reds": 15, "speed_mult": 1.1},
		"lock_3": {"hp": 1100, "surge_reds": 20, "speed_mult": 1.1},
		"vault_hp": 1200,
		"unlocked_gate": "x5",
		"vault_gate_mult": 5,
		"red_spawn_interval": 1.2,
	},
	{
		"stage": 4,
		"base_hp": 7000,
		"highway_depth": -46.0,
		"highway_min_z": -46.0,
		"cleanup_bound": -49.0,
		"lock_1": {"hp": 850, "surge_reds": 12, "speed_mult": 1.1},
		"lock_2": {"hp": 1150, "surge_reds": 18, "speed_mult": 1.15},
		"lock_3": {"hp": 1450, "surge_reds": 25, "speed_mult": 1.15},
		"vault_hp": 1800,
		"unlocked_gate": "x5",
		"vault_gate_mult": 5,
		"red_spawn_interval": 1.0,
	},
	{
		"stage": 5,
		"base_hp": 10000,
		"highway_depth": -52.0,
		"highway_min_z": -52.0,
		"cleanup_bound": -55.0,
		"lock_1": {"hp": 1100, "surge_reds": 15, "speed_mult": 1.15},
		"lock_2": {"hp": 1400, "surge_reds": 22, "speed_mult": 1.2},
		"lock_3": {"hp": 1800, "surge_reds": 30, "speed_mult": 1.2},
		"vault_hp": 2500,
		"unlocked_gate": "x5",
		"vault_gate_mult": 5,
		"red_spawn_interval": 0.8,
	},
]

const MAX_MOBS: int = 300
const BLUE_SPEED: float = -9.0
const RED_SPEED: float = 4.2
const GIANT_SPEED: float = 1.0
const RED_SPAWN_START_TIME: float = 1.0
const RED_SPAWN_INTERVAL: float = 1.0

var current_stage_index: int = 0:
	set(value):
		current_stage_index = clampi(value, 0, STAGES.size() - 1)
		if STAGES.size() > 0:
			var cfg: Dictionary = STAGES[current_stage_index]
			highway_min_z = float(cfg.get("highway_min_z", cfg.get("highway_depth", -32.0)))

var highway_min_z: float = -32.0
var active_pylons: Array[Node3D] = []
var active_vaults: Array[Node3D] = []
var active_surge_units: Array = []
var current_lock_act: int = 1
var shield_locks_enabled: bool = false
var auto_spawn_vaults: bool = false

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
const GiantEnemyScene = preload("res://scenes/mob_control/GiantEnemy3D.tscn")
const MultiplierGate3DScene = preload("res://scenes/mob_control/MultiplierGate3D.tscn")

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
	if STAGES.size() > 0:
		var cfg: Dictionary = STAGES[current_stage_index]
		highway_min_z = float(cfg.get("highway_min_z", cfg.get("highway_depth", -32.0)))
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
	for i in range(active_pylons.size() - 1, -1, -1):
		if not is_instance_valid(active_pylons[i]):
			active_pylons.remove_at(i)
	for i in range(active_surge_units.size() - 1, -1, -1):
		if not is_instance_valid(active_surge_units[i]):
			active_surge_units.remove_at(i)
	for i in range(active_vaults.size() - 1, -1, -1):
		if not is_instance_valid(active_vaults[i]):
			active_vaults.remove_at(i)

	# --- Phase 1: Motion & Spawner ---
	if is_instance_valid(cannon):
		cannon.step(delta)

	for mob in blue_mobs:
		if is_live(mob):
			mob.position.z += BLUE_SPEED * delta

	for mob in red_mobs:
		if is_live(mob):
			var spd: float = mob.speed if ("speed" in mob and mob.speed > 0.0) else RED_SPEED
			mob.position.z += spd * delta

	if is_instance_valid(giant_enemy):
		giant_enemy.position.z += GIANT_SPEED * delta

	for pylon in active_pylons:
		if is_instance_valid(pylon) and not pylon.is_queued_for_deletion():
			var p_spd: float = pylon.speed if ("speed" in pylon and pylon.speed > 0.0) else GIANT_SPEED
			pylon.position.z += p_spd * delta

	for vault in active_vaults:
		if is_instance_valid(vault) and not vault.is_queued_for_deletion():
			var v_spd: float = vault.speed if ("speed" in vault and vault.speed > 0.0) else 0.0
			if v_spd > 0.0:
				vault.position.z += v_spd * delta

	time_elapsed += delta
	red_spawn_timer += delta
	while red_spawn_timer >= RED_SPAWN_START_TIME:
		red_spawn_timer -= RED_SPAWN_INTERVAL
		_spawn_red_mob()

	# --- Phase 2: Explicit Contact Resolution Pass ---
	_resolve_vault_contacts()
	_resolve_gate_contacts()
	_resolve_mob_clashes()
	_resolve_pylon_contacts()
	_resolve_giant_contacts()
	_check_shield_release()

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
	if mob != null and "team" in mob and mob.team == "red":
		on_red_mob_entered_gate(mob, gate)
		return
	var gid: String = gate.gate_id if gate.gate_id != "" else str(gate.get_instance_id())
	if not is_live(mob) or mob.passed_gates.has(gid) or (gate.gate_id != "" and mob.passed_gates.has(gate.gate_id)):
		return
	if not gate.is_active():
		return

	mob.passed_gates[gid] = true
	if gate.gate_id != "":
		mob.passed_gates[gate.gate_id] = true

	if gate.is_evolution_gate:
		gate.feed_blue(1)

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

func on_red_mob_entered_gate(red: MobUnit3DScript, gate: MultiplierGate3DScript) -> void:
	var gid: String = gate.gate_id if gate.gate_id != "" else str(gate.get_instance_id())
	if not is_live(red) or red.passed_gates.has(gid) or (gate.gate_id != "" and red.passed_gates.has(gate.gate_id)):
		return
	red.passed_gates[gid] = true
	if gate.gate_id != "":
		red.passed_gates[gate.gate_id] = true

	if gate.is_evolution_gate:
		gate.sabotage_red(1)

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
	_check_shield_release()

func on_mob_hit_pylon(blue: MobUnit3DScript, pylon: GiantEnemy3DScript) -> void:
	if not is_live(blue):
		return
	blue.is_consumed = true
	blue.queue_free()
	if is_instance_valid(pylon):
		pylon.take_damage(1)
		if pylon.hp <= 0:
			if not pylon.is_queued_for_deletion():
				pylon.queue_free()
			var idx = active_pylons.find(pylon)
			if idx != -1:
				active_pylons.remove_at(idx)
			_check_shield_release()

func on_mob_hit_vault(blue: MobUnit3DScript, vault: Node3D) -> void:
	if not is_live(blue):
		return
	blue.is_consumed = true
	blue.queue_free()
	if is_instance_valid(vault):
		if vault.has_method("take_damage"):
			vault.take_damage(1)
		elif "hp" in vault:
			vault.hp = maxi(0, vault.hp - 1)
			if vault.has_method("_update_ui"):
				vault._update_ui()
		if "hp" in vault and vault.hp <= 0:
			_destroy_vault(vault)

func _destroy_vault(vault: Node3D) -> void:
	if not is_instance_valid(vault):
		return
	var gate = null
	if "target_gate" in vault and is_instance_valid(vault.target_gate):
		gate = vault.target_gate
	elif "blockaded_gate" in vault and is_instance_valid(vault.blockaded_gate):
		gate = vault.blockaded_gate
	elif vault.has_meta("target_gate"):
		gate = vault.get_meta("target_gate")
	elif vault.has_meta("blockaded_gate"):
		gate = vault.get_meta("blockaded_gate")

	if is_instance_valid(gate):
		if "is_locked" in gate:
			gate.is_locked = false
		if "blockading_vault" in gate and gate.blockading_vault == vault:
			gate.blockading_vault = null
		if gate.has_method("unlock"):
			gate.unlock()
		if gate.has_method("update_label"):
			gate.update_label()

	for g in get_all_gates():
		if is_instance_valid(g) and "blockading_vault" in g and g.blockading_vault == vault:
			if "is_locked" in g:
				g.is_locked = false
			g.blockading_vault = null
			if g.has_method("unlock"):
				g.unlock()
			if g.has_method("update_label"):
				g.update_label()

	var idx = active_vaults.find(vault)
	if idx != -1:
		active_vaults.remove_at(idx)
	if not vault.is_queued_for_deletion():
		vault.queue_free()

func on_mob_hit_giant(blue: MobUnit3DScript, giant: GiantEnemy3DScript) -> void:
	if not is_live(blue):
		return
	blue.is_consumed = true
	blue.queue_free()
	if not is_instance_valid(giant):
		return
	if giant.is_shielded or giant.is_invulnerable:
		# GWT 1: 0 damage discard while shielded
		return
	_apply_damage_to_base(1)

func _apply_damage_to_base(amount: int = 1) -> void:
	if not is_instance_valid(giant_enemy) or giant_enemy.is_shielded or giant_enemy.is_invulnerable:
		return

	var use_locks: bool = shield_locks_enabled or giant_enemy.max_hp > 150
	if not use_locks:
		giant_enemy.take_damage(amount)
		return

	var cfg: Dictionary = get_current_stage_config()
	var total_base_hp: int = giant_enemy.max_hp if giant_enemy.max_hp > 0 else int(cfg.get("base_hp", 1200))
	var prev_hp: int = giant_enemy.hp
	var new_hp: int = prev_hp - amount

	var thresh: int = -1
	var lock_key: String = ""
	if current_lock_act == 1:
		thresh = int(round(float(total_base_hp) * 0.75))
		lock_key = "lock_1"
	elif current_lock_act == 2:
		thresh = int(round(float(total_base_hp) * 0.50))
		lock_key = "lock_2"
	elif current_lock_act == 3:
		thresh = int(round(float(total_base_hp) * 0.25))
		lock_key = "lock_3"

	if thresh > 0 and prev_hp > thresh and new_hp <= thresh:
		# GWT 1: Clamped exactly to threshold percentage, base becomes invulnerable
		giant_enemy.hp = thresh
		giant_enemy.is_shielded = true
		giant_enemy.is_invulnerable = true
		giant_enemy._update_ui()

		var lock_cfg: Dictionary = cfg.get(lock_key, {})
		_trigger_shield_lock(current_lock_act, lock_cfg)
		current_lock_act += 1
	else:
		giant_enemy.take_damage(amount)

func _trigger_shield_lock(_act: int, lock_data: Dictionary) -> void:
	var pylon_hp: int = int(lock_data.get("hp", 250))
	var surge_count: int = int(lock_data.get("surge_reds", 5))
	var speed_mult: float = float(lock_data.get("speed_mult", 1.0))

	_spawn_shield_pylon(pylon_hp)
	_spawn_counter_surge_wave(surge_count, speed_mult)

func _spawn_shield_pylon(pylon_hp: int) -> GiantEnemy3DScript:
	var pylon: GiantEnemy3DScript
	if GiantEnemyScene != null:
		pylon = GiantEnemyScene.instantiate() as GiantEnemy3DScript
	else:
		pylon = GiantEnemy3DScript.new()
	pylon.entity_mode = GiantEnemy3DScript.EntityMode.PYLON
	pylon.hp = pylon_hp
	pylon.max_hp = pylon_hp
	pylon.speed = GIANT_SPEED
	pylon.is_invulnerable = false
	pylon.is_shielded = false
	var base_z: float = giant_enemy.global_position.z if is_instance_valid(giant_enemy) else -15.0
	pylon.position = Vector3(0.0, 1.25, base_z + 3.0)
	pylon.name = "ShieldPylon_%d" % current_lock_act
	pylon.add_to_group("pylons")
	add_child(pylon)
	active_pylons.append(pylon)
	pylon._update_ui()
	return pylon

func _spawn_counter_surge_wave(count: int, speed_mult: float = 1.0) -> Array:
	var spawned: Array = []
	if state != GameState.PLAYING:
		return spawned
	var base_z: float = giant_enemy.global_position.z if is_instance_valid(giant_enemy) else -15.0
	var spawn_z: float = base_z + 2.0
	for i in range(count):
		var mob = MobUnitScene.instantiate() as MobUnit3DScript
		var x: float = -4.0 + (8.0 / float(maxi(1, count - 1))) * float(i) if count > 1 else 0.0
		var z_offset: float = float(i % 3) * 0.4
		mob.position = Vector3(x, 0.5, spawn_z + z_offset)
		mob.setup("red")
		mob.add_to_group("surge_units")
		add_child(mob)
		mob.speed = RED_SPEED * speed_mult
		red_mobs.append(mob)
		active_surge_units.append(mob)
		spawned.append(mob)
	return spawned

func _check_shield_release() -> void:
	if not is_instance_valid(giant_enemy) or not giant_enemy.is_shielded:
		return

	for i in range(active_pylons.size() - 1, -1, -1):
		var p = active_pylons[i]
		if not is_instance_valid(p) or p.is_queued_for_deletion() or ("hp" in p and p.hp <= 0):
			if is_instance_valid(p) and not p.is_queued_for_deletion():
				p.queue_free()
			active_pylons.remove_at(i)

	for i in range(active_surge_units.size() - 1, -1, -1):
		var s = active_surge_units[i]
		if not is_live(s):
			active_surge_units.remove_at(i)

	# GWT 2: Shield drops only when pylon HP reaches 0 and all surge reds are eliminated
	if active_pylons.is_empty() and active_surge_units.is_empty():
		giant_enemy.is_shielded = false
		giant_enemy.is_invulnerable = false
		giant_enemy._update_ui()

func is_base_shielded() -> bool:
	return is_instance_valid(giant_enemy) and (giant_enemy.is_shielded or giant_enemy.is_invulnerable)

func get_current_lock_act() -> int:
	return current_lock_act

func get_all_gates() -> Array:
	var list: Array = []
	if gates_container != null:
		for child in gates_container.get_children():
			if child is MultiplierGate3DScript:
				list.append(child)
	for child in get_children():
		if child is MultiplierGate3DScript and not list.has(child):
			list.append(child)
	for v in active_vaults:
		if is_instance_valid(v):
			var bg = null
			if "target_gate" in v and is_instance_valid(v.target_gate):
				bg = v.target_gate
			elif "blockaded_gate" in v and is_instance_valid(v.blockaded_gate):
				bg = v.blockaded_gate
			elif v.has_meta("target_gate"):
				bg = v.get_meta("target_gate")
			elif v.has_meta("blockaded_gate"):
				bg = v.get_meta("blockaded_gate")
			if is_instance_valid(bg) and not list.has(bg):
				list.append(bg)

	return list

func _resolve_vault_contacts() -> void:
	for i in range(active_vaults.size() - 1, -1, -1):
		var vault = active_vaults[i]
		if not is_instance_valid(vault) or vault.is_queued_for_deletion():
			continue
		var vx: float = vault.global_position.x
		var vz: float = vault.global_position.z
		var vy: float = vault.global_position.y
		var hw: float = vault.half_width if ("half_width" in vault and vault.half_width > 0.0) else 2.0
		var hz: float = vault.half_depth if ("half_depth" in vault and vault.half_depth > 0.0) else 1.25
		var hy: float = vault.half_height if ("half_height" in vault and vault.half_height > 0.0) else 1.25

		for blue in blue_mobs:
			if not is_live(blue):
				continue
			if abs(blue.global_position.x - vx) <= (hw + 0.22) and \
			   abs(blue.global_position.z - vz) <= (hz + 0.22) and \
			   abs(blue.global_position.y - vy) <= (hy + 0.35):
				on_mob_hit_vault(blue, vault)
				if not is_instance_valid(vault) or vault.is_queued_for_deletion() or ("hp" in vault and vault.hp <= 0):
					break

func _resolve_gate_contacts() -> void:
	var gates: Array = get_all_gates()
	for gate in gates:
		if not is_instance_valid(gate) or gate.is_queued_for_deletion():
			continue
		var gz: float = gate.global_position.z
		var gx: float = gate.global_position.x
		var gy: float = gate.global_position.y

		for mob in blue_mobs:
			if not is_live(mob):
				continue
			if abs(mob.global_position.x - gx) <= (2.0 + 0.22) and \
			   abs(mob.global_position.z - gz) <= (0.3 + 0.22) and \
			   abs(mob.global_position.y - gy) <= (1.0 + 0.35):
				on_mob_entered_gate(mob, gate)

		for red in red_mobs:
			if not is_live(red):
				continue
			if abs(red.global_position.x - gx) <= (2.0 + 0.22) and \
			   abs(red.global_position.z - gz) <= (0.3 + 0.22) and \
			   abs(red.global_position.y - gy) <= (1.0 + 0.35):
				on_red_mob_entered_gate(red, gate)

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

func _resolve_pylon_contacts() -> void:
	for pylon in active_pylons:
		if not is_instance_valid(pylon) or pylon.is_queued_for_deletion():
			continue
		var px = pylon.global_position.x
		var pz = pylon.global_position.z
		var py = pylon.global_position.y

		for blue in blue_mobs:
			if not is_live(blue):
				continue
			if abs(blue.global_position.x - px) <= (4.75 + 0.22) and \
			   abs(blue.global_position.z - pz) <= (1.25 + 0.22) and \
			   abs(blue.global_position.y - py) <= (1.25 + 0.35):
				on_mob_hit_pylon(blue, pylon)

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
		for pylon in active_pylons:
			if is_instance_valid(pylon) and pylon.global_position.z >= 9.0:
				defeat_triggered = true
				break
		if not defeat_triggered:
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

func get_current_stage_config() -> Dictionary:
	if current_stage_index >= 0 and current_stage_index < STAGES.size():
		return STAGES[current_stage_index]
	return STAGES[0]

func get_highway_min_z() -> float:
	return highway_min_z

func get_cleanup_bound_z() -> float:
	return highway_min_z - 3.0

func _cleanup_out_of_bounds_mobs() -> void:
	var bound_z: float = get_cleanup_bound_z()
	var surviving_blue: Array[MobUnit3DScript] = []
	for mob in blue_mobs:
		if is_live(mob):
			if mob.global_position.z < bound_z:
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

func cleanup_stage_entities() -> void:
	cleanup_all_mobs()
	for pylon in active_pylons:
		if is_instance_valid(pylon) and not pylon.is_queued_for_deletion():
			pylon.queue_free()
	active_pylons.clear()
	for vault in active_vaults:
		if is_instance_valid(vault) and not vault.is_queued_for_deletion():
			vault.queue_free()
	active_vaults.clear()
	for surge in active_surge_units:
		if is_instance_valid(surge) and not surge.is_queued_for_deletion():
			surge.queue_free()
	active_surge_units.clear()

	if is_instance_valid(giant_enemy):
		giant_enemy.is_shielded = false
		giant_enemy.is_invulnerable = false

	if is_inside_tree() and get_tree() != null:
		for pylon in get_tree().get_nodes_in_group("pylons"):
			if is_instance_valid(pylon) and not pylon.is_queued_for_deletion():
				pylon.queue_free()
		for vault in get_tree().get_nodes_in_group("vaults"):
			if is_instance_valid(vault) and not vault.is_queued_for_deletion():
				vault.queue_free()
		for surge in get_tree().get_nodes_in_group("surge_units"):
			if is_instance_valid(surge) and not surge.is_queued_for_deletion():
				surge.queue_free()

func init_stage(stage_idx: int) -> void:
	current_stage_index = clampi(stage_idx, 0, STAGES.size() - 1)
	state = GameState.PLAYING
	current_lock_act = 1
	shield_locks_enabled = true
	cleanup_stage_entities()
	var cfg: Dictionary = STAGES[current_stage_index]
	highway_min_z = float(cfg.get("highway_min_z", cfg.get("highway_depth", -32.0)))
	if is_instance_valid(giant_enemy):
		var base_hp: int = int(cfg.get("base_hp", 1200))
		giant_enemy.reset(base_hp)
	if is_instance_valid(cannon):
		cannon.reset()
	red_spawn_timer = 0.0
	time_elapsed = 0.0
	if is_instance_valid(victory_banner):
		victory_banner.visible = false
	if is_instance_valid(defeat_banner):
		defeat_banner.visible = false
	_spawn_stage_layout(current_stage_index)

func advance_stage() -> void:
	if current_stage_index + 1 < STAGES.size():
		init_stage(current_stage_index + 1)
	else:
		state = GameState.VICTORY
		if victory_banner != null:
			victory_banner.visible = true

func _spawn_stage_layout(stage_idx: int) -> void:
	if auto_spawn_vaults:
		spawn_stage_vault(stage_idx)

func spawn_vault(arg1: Variant, arg2: Variant, target_gate: MultiplierGate3DScript = null) -> Node3D:
	var pos: Vector3
	var vault_hp: int
	if arg1 is Vector3:
		pos = arg1
		vault_hp = int(arg2)
	else:
		vault_hp = int(arg1)
		pos = arg2 if arg2 is Vector3 else Vector3.ZERO

	var vault: Node3D
	if GiantEnemyScene != null:
		var giant = GiantEnemyScene.instantiate() as GiantEnemy3DScript
		giant.speed = 0.0
		giant.hp = vault_hp
		giant.max_hp = vault_hp
		giant.is_invulnerable = false
		giant.is_shielded = false
		vault = giant
	else:
		vault = Node3D.new()
		vault.set("hp", vault_hp)
		vault.set("max_hp", vault_hp)

	vault.position = pos
	vault.name = "Vault_%d" % (active_vaults.size() + 1)
	vault.add_to_group("vaults")
	if "target_gate" in vault:
		vault.target_gate = target_gate
	elif "blockaded_gate" in vault:
		vault.blockaded_gate = target_gate
	else:
		vault.set_meta("target_gate", target_gate)
		vault.set_meta("blockaded_gate", target_gate)

	if target_gate != null:
		target_gate.lock(vault)

	add_child(vault)
	active_vaults.append(vault)
	if vault.has_method("_update_ui"):
		vault._update_ui()
	return vault

func _spawn_vault(arg1: Variant, arg2: Variant, target_gate: MultiplierGate3DScript = null) -> Node3D:
	return spawn_vault(arg1, arg2, target_gate)

func spawn_vault_for_gate(gate: MultiplierGate3DScript, vault_hp: int = -1) -> Node3D:
	if vault_hp <= 0:
		var cfg: Dictionary = get_current_stage_config()
		vault_hp = int(cfg.get("vault_hp", 400))
	var vault_pos = Vector3(gate.global_position.x, 1.25, gate.global_position.z + 0.5)
	return spawn_vault(vault_pos, vault_hp, gate)

func spawn_evolution_gate(arg1: Variant, arg2: Variant = 1, arg3: Variant = "") -> MultiplierGate3DScript:
	var pos: Vector3 = Vector3.ZERO
	var start_level: int = 1
	var gate_id_str: String = ""

	if arg1 is Vector3:
		pos = arg1
		if arg2 is int or arg2 is float:
			start_level = int(arg2)
		elif arg2 is String:
			gate_id_str = arg2
		if arg3 is String and arg3 != "":
			gate_id_str = arg3
		elif arg3 is int or arg3 is float:
			start_level = int(arg3)
	elif arg1 is String:
		gate_id_str = arg1
		if arg2 is Vector3:
			pos = arg2
		elif arg2 is int or arg2 is float:
			start_level = int(arg2)
		if arg3 is int or arg3 is float:
			start_level = int(arg3)
		elif arg3 is Vector3:
			pos = arg3

	var gate: MultiplierGate3DScript
	if MultiplierGate3DScene != null:
		gate = MultiplierGate3DScene.instantiate() as MultiplierGate3DScript
	else:
		gate = MultiplierGate3DScript.new()
	gate.gate_id = gate_id_str if gate_id_str != "" else "evolution_gate_%d" % (get_all_gates().size() + 1)
	gate.position = pos
	gate.setup_evolution(start_level)
	if gates_container != null:
		gates_container.add_child(gate)
	else:
		add_child(gate)
	return gate

func _spawn_evolution_gate(arg1: Variant, arg2: Variant = 1, arg3: Variant = "") -> MultiplierGate3DScript:
	return spawn_evolution_gate(arg1, arg2, arg3)


func spawn_stage_vault(stage_idx: int) -> Node3D:
	var cfg: Dictionary = STAGES[clampi(stage_idx, 0, STAGES.size() - 1)]
	var v_hp: int = int(cfg.get("vault_hp", 400))
	var mult: int = int(cfg.get("vault_gate_mult", 4))
	var gate: MultiplierGate3DScript
	if MultiplierGate3DScene != null:
		gate = MultiplierGate3DScene.instantiate() as MultiplierGate3DScript
	else:
		gate = MultiplierGate3DScript.new()
	gate.gate_id = "stage_%d_vault_gate" % (stage_idx + 1)
	gate.operation = "x"
	gate.value = mult
	gate.position = Vector3(2.5, 1.0, -8.0)
	if gates_container != null:
		gates_container.add_child(gate)
	else:
		add_child(gate)
	return spawn_vault_for_gate(gate, v_hp)

func reset_stage() -> void:
	state = GameState.PLAYING
	current_lock_act = 1
	shield_locks_enabled = false
	if is_instance_valid(giant_enemy):
		giant_enemy.reset(150)
	if is_instance_valid(cannon):
		cannon.reset()
	red_spawn_timer = 0.0
	time_elapsed = 0.0
	cleanup_stage_entities()
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
