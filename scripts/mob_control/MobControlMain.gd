class_name MobControlMain
extends Node3D

## Main scene controller for Mob Control 3D.
## Manages 4-phase deterministic stepping: Motion -> Contact Resolution -> State Evaluation -> Bounds Cleanup.
## Enforces MAX_MOBS = 300 cap, multi-cannon squad (up to 5 cannons), gate-charge bullet power scaling,
## Single Endless Survival Phase with dynamic scrolling/respawning gates, gate-crushing advancing Bosses,
## time-escalating Soldier & Boss waves, 3D shatter/explosion animations, and legacy multi-stage support.

signal return_to_menu_requested

enum GameState { PLAYING, STAGE_CLEAR, VICTORY, DEFEAT }

const STAGES: Array[Dictionary] = [
	{
		"stage": 1,
		"waves": 3,
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
		"waves": 4,
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
		"waves": 4,
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
		"waves": 5,
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
		"waves": 5,
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

const BASELINE_GATES: Array[Dictionary] = [
	{"name": "gate_left_1", "pos": Vector3(-2.5, 1.0, -2.0), "op": "+", "val": 2},
	{"name": "gate_right_1", "pos": Vector3(2.5, 1.0, -2.0), "op": "x", "val": 2},
	{"name": "gate_left_2", "pos": Vector3(-2.5, 1.0, -8.0), "op": "x", "val": 3},
	{"name": "gate_right_2", "pos": Vector3(2.5, 1.0, -8.0), "op": "+", "val": 5},
]

const MAX_MOBS: int = 300
const MAX_CANNONS: int = 5
const GATE_CHARGE_THRESHOLD: int = 35
const MAX_BULLET_POWER: int = 25
const CANNON_SPACING_X: float = 1.15
const CANNON_SLOT_OFFSETS: Array[float] = [0.0, -1.15, 1.15, -2.30, 2.30]
const BLUE_SPEED: float = -9.0
const RED_SPEED: float = 4.2
const GIANT_SPEED: float = 1.0
const GIANT_FORTIFIED_SPEED: float = 0.18
const DESTRUCTION_FX_DURATION: float = 0.45
const RED_SPAWN_START_TIME: float = 1.0
const RED_SPAWN_INTERVAL: float = 1.0

const GATE_SCROLL_SPEED: float = 1.8
const GATE_DESPAWN_Z: float = 8.2
const GATE_SPAWN_Z: float = -16.5
const BOSS_BASE_SPEED: float = 2.6
const BOSS_BASE_HP: int = 140
const BOSS_HALF_WIDTH: float = 1.55
const SOLDIER_BASE_INTERVAL: float = 1.4
const SOLDIER_MIN_INTERVAL: float = 0.28
const BOSS_BASE_INTERVAL: float = 14.0
const BOSS_MIN_INTERVAL: float = 5.5

const HI_RES_SIZE: Vector2i = Vector2i(1152, 672)
const RETRO_RES_SIZE: Vector2i = Vector2i(384, 224)
const CLONE_SPACING_X: float = 0.55
const CLONE_SPACING_Z: float = 0.50
const MAX_ROW_WIDTH: int = 5
const HIGHWAY_HALF_WIDTH: float = 4.5
const ROAD_SCROLL_SPEED: float = 8.0
const ROAD_SCROLL_MIN_Z: float = -52.0
const ROAD_SCROLL_MAX_Z: float = 12.0

var current_stage_index: int = 0:
	set(value):
		current_stage_index = clampi(value, 0, STAGES.size() - 1)
		if STAGES.size() > 0:
			var cfg: Dictionary = STAGES[current_stage_index]
			highway_min_z = float(cfg.get("highway_min_z", cfg.get("highway_depth", -32.0)))

var highway_min_z: float = -32.0
var current_wave: int = 1
var total_waves_in_stage: int = 3
var gate_power_charge: int = 0
var survival_mode: bool = true
var dynamic_gates_enabled: bool = true
var bosses_defeated: int = 0
var soldiers_defeated: int = 0
var best_survival_time: float = 0.0
var gate_spawn_timer: float = 0.0
var next_gate_spawn_interval: float = 3.0
var boss_spawn_timer: float = 0.0
var next_boss_spawn_interval: float = 7.5
var soldier_spawn_timer: float = 0.0
var next_soldier_spawn_interval: float = 1.2
var _dynamic_gate_seq: int = 0

var active_pylons: Array[Node3D] = []
var active_vaults: Array[Node3D] = []
var active_obstacles: Array[Node3D] = []
var active_bosses: Array[Node3D] = []
var active_destruction_fx: Array[Node3D] = []
var active_surge_units: Array = []
var road_scroller_nodes: Array[Node3D] = []
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
const CannonScene = preload("res://scenes/mob_control/Cannon3D.tscn")
const MobUnitScene = preload("res://scenes/mob_control/MobUnit3D.tscn")
const GiantEnemyScene = preload("res://scenes/mob_control/GiantEnemy3D.tscn")
const MultiplierGate3DScene = preload("res://scenes/mob_control/MultiplierGate3D.tscn")

var cannons: Array[Cannon3DScript] = []
var bullet_power: int = 1
var cannon_power_label_3d: Label3D = null
var wave_status_label: Label = null

var blue_mobs: Array[MobUnit3DScript] = []
var red_mobs: Array[MobUnit3DScript] = []

@onready var cannon: Cannon3DScript = $Cannon if has_node("Cannon") else null
@onready var giant_enemy: GiantEnemy3DScript = $GiantEnemy if has_node("GiantEnemy") else null
@onready var gates_container: Node3D = $Gates if has_node("Gates") else null
@onready var road_decor: Node3D = $RoadDecor if has_node("RoadDecor") else null
@onready var victory_banner: Control = $UI/VictoryBanner if has_node("UI/VictoryBanner") else null
@onready var defeat_banner: Control = $UI/DefeatBanner if has_node("UI/DefeatBanner") else null
@onready var controls_hint: Label = $UI/ControlsHint if has_node("UI/ControlsHint") else null
@onready var cannon_status_label: Label = $UI/CannonStatusLabel if has_node("UI/CannonStatusLabel") else null

func _ready() -> void:
	_resolve_nodes()
	_apply_high_res_viewport()
	_setup_road_scroller()
	if is_instance_valid(cannon) and not cannon.shoot_requested.is_connected(_on_cannon_shoot_requested):
		cannon.shoot_requested.connect(_on_cannon_shoot_requested)
	_ensure_cannons_initialized()
	init_survival_phase()

func _exit_tree() -> void:
	_restore_retro_viewport()

func _process(delta: float) -> void:
	if state != GameState.PLAYING and not active_destruction_fx.is_empty():
		_step_destruction_fx(delta)

func _apply_high_res_viewport() -> void:
	if is_inside_tree() and get_window() != null:
		var win: Window = get_window()
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_size = HI_RES_SIZE
	if is_inside_tree() and get_viewport() != null:
		get_viewport().msaa_3d = Viewport.MSAA_4X

func _restore_retro_viewport() -> void:
	if is_inside_tree() and get_window() != null:
		var win: Window = get_window()
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		win.content_scale_size = RETRO_RES_SIZE
	if is_inside_tree() and get_viewport() != null:
		get_viewport().msaa_3d = Viewport.MSAA_DISABLED

func _ensure_cannons_initialized() -> void:
	if cannon == null:
		cannon = get_node_or_null("Cannon")
	for i in range(cannons.size() - 1, -1, -1):
		if not is_instance_valid(cannons[i]) or cannons[i].is_queued_for_deletion():
			cannons.remove_at(i)
	if is_instance_valid(cannon) and not cannons.has(cannon):
		cannons.insert(0, cannon)

func get_cannon_count() -> int:
	_ensure_cannons_initialized()
	return cannons.size()

func get_bullet_power() -> int:
	return bullet_power

func _add_cannon() -> Cannon3DScript:
	_ensure_cannons_initialized()
	if cannons.size() >= MAX_CANNONS:
		return null
	var new_cannon: Cannon3DScript
	if CannonScene != null:
		new_cannon = CannonScene.instantiate() as Cannon3DScript
	else:
		new_cannon = Cannon3DScript.new()
	new_cannon.name = "Cannon_%d" % (cannons.size() + 1)
	add_child(new_cannon)
	cannons.append(new_cannon)
	_update_cannon_squad_positions()
	_update_cannon_status_ui()
	return new_cannon

func _update_cannon_squad_positions() -> void:
	_ensure_cannons_initialized()
	if cannons.is_empty() or not is_instance_valid(cannon):
		return
	var min_offset: float = 0.0
	var max_offset: float = 0.0
	for i in range(cannons.size()):
		var off: float = CANNON_SLOT_OFFSETS[i] if i < CANNON_SLOT_OFFSETS.size() else 0.0
		min_offset = minf(min_offset, off)
		max_offset = maxf(max_offset, off)
	cannon.min_x = -5.0 - min_offset
	cannon.max_x = 5.0 - max_offset
	cannon.position.x = clampf(cannon.position.x, cannon.min_x, cannon.max_x)
	for i in range(1, cannons.size()):
		var c: Cannon3DScript = cannons[i]
		if is_instance_valid(c):
			var off: float = CANNON_SLOT_OFFSETS[i] if i < CANNON_SLOT_OFFSETS.size() else 0.0
			c.position = Vector3(cannon.position.x + off, cannon.position.y, cannon.position.z)
	if is_instance_valid(cannon_power_label_3d):
		cannon_power_label_3d.position = Vector3(cannon.position.x, cannon.position.y + 1.15, cannon.position.z)

func _format_survival_time(sec_val: float) -> String:
	var total_sec: int = maxi(0, int(floor(sec_val)))
	@warning_ignore("integer_division")
	var mins: int = total_sec / 60
	var secs: int = total_sec % 60
	return "%02d:%02d" % [mins, secs]

func _update_cannon_status_ui() -> void:
	_ensure_cannons_initialized()
	var count: int = maxi(1, cannons.size())
	if cannon_status_label == null:
		cannon_status_label = get_node_or_null("UI/CannonStatusLabel")
	if cannon_status_label != null:
		cannon_status_label.text = "CANNONS: %d/%d | BULLET POWER: %d" % [count, MAX_CANNONS, bullet_power]
	var ui_layer: Node = get_node_or_null("UI")
	if ui_layer != null:
		if wave_status_label == null or not is_instance_valid(wave_status_label):
			wave_status_label = ui_layer.get_node_or_null("WaveStatusLabel") as Label
			if wave_status_label == null:
				wave_status_label = Label.new()
				wave_status_label.name = "WaveStatusLabel"
				wave_status_label.anchors_preset = Control.PRESET_TOP_WIDE
				wave_status_label.offset_top = 46.0
				wave_status_label.offset_bottom = 76.0
				wave_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				wave_status_label.add_theme_font_size_override("font_size", 20)
				wave_status_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 0.95))
				wave_status_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
				wave_status_label.add_theme_constant_override("outline_size", 4)
				ui_layer.add_child(wave_status_label)
		if survival_mode:
			wave_status_label.text = "SURVIVAL TIME: %s | BOSSES: %d | KILLS: %d" % [_format_survival_time(time_elapsed), bosses_defeated, soldiers_defeated]
		else:
			wave_status_label.text = "STAGE %d/%d | WAVE %d/%d" % [current_stage_index + 1, STAGES.size(), current_wave, total_waves_in_stage]
	if cannon_power_label_3d == null or not is_instance_valid(cannon_power_label_3d):
		cannon_power_label_3d = get_node_or_null("CannonPowerLabel3D") as Label3D
		if cannon_power_label_3d == null:
			cannon_power_label_3d = Label3D.new()
			cannon_power_label_3d.name = "CannonPowerLabel3D"
			cannon_power_label_3d.pixel_size = 0.014
			cannon_power_label_3d.font_size = 36
			cannon_power_label_3d.outline_size = 6
			cannon_power_label_3d.modulate = Color(0.95, 0.95, 1.0, 1.0)
			add_child(cannon_power_label_3d)
	cannon_power_label_3d.text = "CANNONS: %d/%d | PWR: x%d" % [count, MAX_CANNONS, bullet_power]
	if is_instance_valid(cannon):
		cannon_power_label_3d.position = Vector3(cannon.position.x, cannon.position.y + 1.15, cannon.position.z)

func _reset_cannons_and_power() -> void:
	_ensure_cannons_initialized()
	for i in range(cannons.size() - 1, 0, -1):
		var extra: Cannon3DScript = cannons[i]
		if is_instance_valid(extra):
			if extra.get_parent() != null:
				extra.get_parent().remove_child(extra)
			extra.free()
		cannons.remove_at(i)
	bullet_power = 1
	gate_power_charge = 0
	if is_instance_valid(cannon):
		cannon.reset()
	_update_cannon_squad_positions()
	_update_cannon_status_ui()

func _on_bullet_hit_multiplier_gate(mult_value: int) -> void:
	_ensure_cannons_initialized()
	if cannons.size() < MAX_CANNONS:
		_add_cannon()
	elif bullet_power < 6:
		bullet_power = mini(MAX_BULLET_POWER, bullet_power + maxi(1, mult_value))
		_update_cannon_status_ui()
	elif bullet_power < MAX_BULLET_POWER:
		gate_power_charge += 1
		if gate_power_charge >= GATE_CHARGE_THRESHOLD:
			gate_power_charge -= GATE_CHARGE_THRESHOLD
			bullet_power = mini(MAX_BULLET_POWER, bullet_power + 1)
		_update_cannon_status_ui()

func _setup_road_scroller() -> void:
	if road_decor == null:
		road_decor = get_node_or_null("RoadDecor")
		if road_decor == null:
			road_decor = Node3D.new()
			road_decor.name = "RoadDecor"
			add_child(road_decor)

	for marker in road_scroller_nodes:
		if is_instance_valid(marker):
			marker.free()
	road_scroller_nodes.clear()

	var center_mat := StandardMaterial3D.new()
	center_mat.albedo_color = Color(0.95, 0.82, 0.18, 1.0)
	center_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.85, 0.88, 0.92, 1.0)
	edge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.18, 0.02, 1.6)

	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.25, 0.55, 0.95, 1.0)

	var pillar_mesh := BoxMesh.new()
	pillar_mesh.size = Vector3(0.35, 1.2, 0.35)

	var z_cursor: float = ROAD_SCROLL_MIN_Z
	while z_cursor < ROAD_SCROLL_MAX_Z:
		for lane_x in [0.0, -5.2, 5.2]:
			var dash := MeshInstance3D.new()
			dash.mesh = dash_mesh
			dash.material_override = center_mat if is_zero_approx(lane_x) else edge_mat
			dash.position = Vector3(lane_x, 0.01, z_cursor)
			road_decor.add_child(dash)
			road_scroller_nodes.append(dash)
		z_cursor += 4.0

	var p_cursor: float = ROAD_SCROLL_MIN_Z
	while p_cursor < ROAD_SCROLL_MAX_Z:
		for side_x in [-6.4, 6.4]:
			var pillar := MeshInstance3D.new()
			pillar.mesh = pillar_mesh
			pillar.material_override = pillar_mat
			pillar.position = Vector3(side_x, 0.6, p_cursor)
			road_decor.add_child(pillar)
			road_scroller_nodes.append(pillar)
		p_cursor += 6.0

func _step_road_scroller(delta: float) -> void:
	if road_scroller_nodes.is_empty():
		_setup_road_scroller()
	var span: float = ROAD_SCROLL_MAX_Z - ROAD_SCROLL_MIN_Z
	for marker in road_scroller_nodes:
		if is_instance_valid(marker):
			marker.position.z += ROAD_SCROLL_SPEED * delta
			while marker.position.z > ROAD_SCROLL_MAX_Z:
				marker.position.z -= span

func _resolve_nodes() -> void:
	if cannon == null:
		cannon = get_node_or_null("Cannon")
	if giant_enemy == null:
		giant_enemy = get_node_or_null("GiantEnemy")
	if gates_container == null:
		gates_container = get_node_or_null("Gates")
	if road_decor == null:
		road_decor = get_node_or_null("RoadDecor")
	if victory_banner == null:
		victory_banner = get_node_or_null("UI/VictoryBanner")
	if defeat_banner == null:
		defeat_banner = get_node_or_null("UI/DefeatBanner")
	if controls_hint == null:
		controls_hint = get_node_or_null("UI/ControlsHint")
	if cannon_status_label == null:
		cannon_status_label = get_node_or_null("UI/CannonStatusLabel")

func _physics_process(delta: float) -> void:
	step(delta)

func step(delta: float) -> void:
	if state != GameState.PLAYING:
		return

	_resolve_nodes()
	_ensure_cannons_initialized()

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
	for i in range(active_obstacles.size() - 1, -1, -1):
		if not is_instance_valid(active_obstacles[i]) or active_obstacles[i].is_queued_for_deletion():
			active_obstacles.remove_at(i)
	for i in range(active_bosses.size() - 1, -1, -1):
		if not is_instance_valid(active_bosses[i]) or active_bosses[i].is_queued_for_deletion():
			active_bosses.remove_at(i)

	# --- Phase 1: Motion & Spawner ---
	_step_road_scroller(delta)
	_step_destruction_fx(delta)

	if is_instance_valid(cannon):
		_update_cannon_squad_positions()
		cannon.step(delta)
		_update_cannon_squad_positions()

	for mob in blue_mobs:
		if is_live(mob):
			mob.position.z += BLUE_SPEED * delta

	for mob in red_mobs:
		if is_live(mob):
			var spd: float = mob.speed if ("speed" in mob and mob.speed > 0.0) else RED_SPEED
			mob.position.z += spd * delta
			if mob.has_method("step_visuals"):
				mob.step_visuals(delta)

	if not survival_mode and is_instance_valid(giant_enemy) and giant_enemy.visible:
		var g_spd: float = GIANT_FORTIFIED_SPEED if not active_obstacles.is_empty() else GIANT_SPEED
		giant_enemy.position.z += g_spd * delta
		if giant_enemy.has_method("step_visuals"):
			giant_enemy.step_visuals(delta)

	for boss in active_bosses:
		if is_instance_valid(boss) and not boss.is_queued_for_deletion():
			var b_spd: float = boss.speed if ("speed" in boss and boss.speed > 0.0) else BOSS_BASE_SPEED
			boss.position.z += b_spd * delta
			if boss.has_method("step_visuals"):
				boss.step_visuals(delta)

	if dynamic_gates_enabled:
		for gate in get_all_gates():
			if is_instance_valid(gate) and not gate.is_queued_for_deletion():
				if gate.has_method("step_gate"):
					gate.step_gate(delta)

	for pylon in active_pylons:
		if is_instance_valid(pylon) and not pylon.is_queued_for_deletion():
			var p_spd: float = pylon.speed if ("speed" in pylon and pylon.speed > 0.0) else GIANT_SPEED
			pylon.position.z += p_spd * delta
			if pylon.has_method("step_visuals"):
				pylon.step_visuals(delta)

	for vault in active_vaults:
		if is_instance_valid(vault) and not vault.is_queued_for_deletion():
			var v_spd: float = vault.speed if ("speed" in vault and vault.speed > 0.0) else 0.0
			if v_spd > 0.0:
				vault.position.z += v_spd * delta
			if vault.has_method("step_visuals"):
				vault.step_visuals(delta)

	for obs in active_obstacles:
		if is_instance_valid(obs) and not obs.is_queued_for_deletion():
			if obs.has_method("step_obstacle"):
				obs.step_obstacle(delta)

	time_elapsed += delta
	if survival_mode:
		_step_survival_spawners(delta)
	else:
		red_spawn_timer += delta
		var cfg: Dictionary = get_current_stage_config()
		var spawn_interval: float = float(cfg.get("red_spawn_interval", RED_SPAWN_INTERVAL))
		while red_spawn_timer >= RED_SPAWN_START_TIME:
			red_spawn_timer -= spawn_interval
			_spawn_red_mob()

	# --- Phase 2: Explicit Contact Resolution Pass ---
	_resolve_vault_contacts()
	_resolve_gate_contacts()
	_resolve_boss_gate_destruction()
	_resolve_mob_clashes()
	_resolve_pylon_contacts()
	_resolve_boss_contacts()
	if not survival_mode:
		_resolve_giant_contacts()
		_resolve_obstacle_contacts()
		_check_shield_release()
		_check_wave_progression()

	# --- Phase 3: State Evaluation & Latch ---
	_evaluate_game_state()

	# --- Phase 4: Bounds Cleanup ---
	_cleanup_out_of_bounds_mobs()

func get_soldier_max_burst(elapsed: float) -> int:
	return mini(8, 2 + int(floor(maxf(0.0, elapsed) / 18.0)))

func get_max_concurrent_bosses(elapsed: float) -> int:
	var t: float = maxf(0.0, elapsed)
	if t >= 120.0:
		return 4
	elif t >= 70.0:
		return 3
	elif t >= 30.0:
		return 2
	return 1

func get_scaled_boss_hp(elapsed: float) -> int:
	return BOSS_BASE_HP + int(floor(maxf(0.0, elapsed) * 4.5))

func _step_survival_spawners(delta: float) -> void:
	# 1. Dynamic Gate Stream Spawner
	gate_spawn_timer += delta
	var live_gates_count: int = 0
	for g in get_all_gates():
		if is_instance_valid(g) and not g.is_queued_for_deletion():
			live_gates_count += 1
	if gate_spawn_timer >= next_gate_spawn_interval or (live_gates_count < 2 and time_elapsed >= 0.5):
		gate_spawn_timer = 0.0
		next_gate_spawn_interval = rng.randf_range(2.6, 4.0)
		spawn_random_gate(GATE_SPAWN_Z)

	# 2. Time-Escalating Soldier Spawner
	red_spawn_timer += delta
	soldier_spawn_timer += delta
	var soldier_trigger: float = maxf(red_spawn_timer, soldier_spawn_timer)
	if soldier_trigger >= next_soldier_spawn_interval:
		red_spawn_timer = 0.0
		soldier_spawn_timer = 0.0
		var base_soldier_int: float = maxf(SOLDIER_MIN_INTERVAL, SOLDIER_BASE_INTERVAL - (time_elapsed / 60.0) * 0.55)
		next_soldier_spawn_interval = base_soldier_int * rng.randf_range(0.8, 1.2)
		var max_burst: int = get_soldier_max_burst(time_elapsed)
		var burst_count: int = rng.randi_range(1, max_burst)
		for i in range(burst_count):
			var r_mob := _spawn_red_mob()
			if r_mob != null:
				r_mob.position = Vector3(rng.randf_range(-3.8, 3.8), 0.5, -22.0 - float(i) * 0.55)
				if time_elapsed > 2.0:
					r_mob.speed = RED_SPEED * clampf(1.0 + time_elapsed / 180.0, 1.0, 1.65)

	# 3. Time-Escalating Boss Spawner
	boss_spawn_timer += delta
	var max_bosses: int = get_max_concurrent_bosses(time_elapsed)
	if boss_spawn_timer >= next_boss_spawn_interval:
		boss_spawn_timer = 0.0
		var base_boss_int: float = maxf(BOSS_MIN_INTERVAL, BOSS_BASE_INTERVAL - (time_elapsed / 30.0) * 2.0)
		next_boss_spawn_interval = base_boss_int * rng.randf_range(0.85, 1.15)
		if active_bosses.size() < max_bosses:
			var b_hp: int = get_scaled_boss_hp(time_elapsed)
			var b_spd: float = clampf(BOSS_BASE_SPEED + (time_elapsed / 120.0) * 0.8, BOSS_BASE_SPEED, 3.8)
			spawn_boss(Vector3(rng.randf_range(-2.8, 2.8), 1.25, -23.5), b_hp, b_spd)

	_update_cannon_status_ui()

func _on_cannon_shoot_requested(muzzle_pos: Vector3) -> void:
	if state != GameState.PLAYING:
		return
	_ensure_cannons_initialized()
	if cannons.is_empty():
		if get_live_blue_mobs_count() + pending_spawns < MAX_MOBS:
			_spawn_blue_mob(muzzle_pos, {}, bullet_power)
		return
	for i in range(cannons.size()):
		if get_live_blue_mobs_count() + pending_spawns >= MAX_MOBS:
			break
		var c: Cannon3DScript = cannons[i]
		if not is_instance_valid(c):
			continue
		var shot_pos: Vector3 = muzzle_pos if i == 0 else c.get_muzzle_position()
		_spawn_blue_mob(shot_pos, {}, bullet_power)

func _spawn_blue_mob(pos: Vector3, p_passed_gates: Dictionary = {}, p_power: int = -1) -> MobUnit3DScript:
	var mob = MobUnitScene.instantiate() as MobUnit3DScript
	mob.position = pos
	mob.passed_gates = p_passed_gates.duplicate()
	var effective_power: int = p_power if p_power > 0 else 1
	mob.setup("blue", effective_power)
	add_child(mob)
	blue_mobs.append(mob)
	return mob

func _spawn_red_mob() -> MobUnit3DScript:
	if state != GameState.PLAYING:
		return null
	var mob = MobUnitScene.instantiate() as MobUnit3DScript
	var x = rng.randf_range(-3.8, 3.8)
	mob.position = Vector3(x, 0.5, -22.0)
	mob.setup("red", 1)
	add_child(mob)
	red_mobs.append(mob)
	return mob

func spawn_boss(arg1: Variant = Vector3(0.0, 1.25, -22.0), arg2: Variant = -1, speed_val: float = -1.0) -> GiantEnemy3DScript:
	var pos: Vector3 = Vector3(0.0, 1.25, -22.0)
	var hp_val: int = -1
	if arg1 is Vector3:
		pos = arg1
		if arg2 is int or arg2 is float:
			hp_val = int(arg2)
	elif arg1 is int or arg1 is float:
		hp_val = int(arg1)
		if arg2 is Vector3:
			pos = arg2
		else:
			pos = Vector3(rng.randf_range(-2.8, 2.8), 1.25, -22.0)
	var boss: GiantEnemy3DScript
	if GiantEnemyScene != null:
		boss = GiantEnemyScene.instantiate() as GiantEnemy3DScript
	else:
		boss = GiantEnemy3DScript.new()
	var eff_hp: int = hp_val if hp_val > 0 else get_scaled_boss_hp(time_elapsed)
	var eff_spd: float = speed_val if speed_val > 0.0 else BOSS_BASE_SPEED
	boss.is_lane_boss = true
	boss.half_width = BOSS_HALF_WIDTH
	boss.half_depth = 1.0
	boss.half_height = 1.25
	boss.entity_mode = GiantEnemy3DScript.EntityMode.BASE
	boss.hp = maxi(1, eff_hp)
	boss.max_hp = maxi(1, eff_hp)
	boss.speed = eff_spd
	boss.is_invulnerable = false
	boss.is_shielded = false
	boss.position = pos
	boss.name = "SurvivalBoss_%d" % (active_bosses.size() + bosses_defeated + 1)
	boss.add_to_group("bosses")
	add_child(boss)
	active_bosses.append(boss)
	boss._build_entity_model()
	boss._update_ui()
	return boss

func spawn_random_gate(z_pos: float = GATE_SPAWN_Z) -> MultiplierGate3DScript:
	var gate: MultiplierGate3DScript
	if MultiplierGate3DScene != null:
		gate = MultiplierGate3DScene.instantiate() as MultiplierGate3DScript
	else:
		gate = MultiplierGate3DScript.new()
	_dynamic_gate_seq += 1
	gate.name = "dyn_gate_%d" % _dynamic_gate_seq
	gate.gate_id = gate.name
	var is_mult: bool = rng.randf() < 0.38
	if is_mult:
		gate.operation = "x"
		var mult_choices: Array[int] = [2, 2, 3, 3, 4]
		gate.value = mult_choices[rng.randi_range(0, mult_choices.size() - 1)]
	else:
		gate.operation = "+"
		var add_choices: Array[int] = [2, 3, 4, 5, 6]
		gate.value = add_choices[rng.randi_range(0, add_choices.size() - 1)]
	var lane_x: float = rng.randf_range(-2.8, 2.8)
	gate.position = Vector3(lane_x, 1.0, z_pos)
	gate.move_enabled = true
	gate.scroll_speed = GATE_SCROLL_SPEED
	if rng.randf() < 0.45:
		gate.osc_enabled = true
		gate.osc_base_x = clampf(lane_x, -1.8, 1.8)
		gate.osc_amplitude = rng.randf_range(1.0, 1.6)
		gate.osc_speed = rng.randf_range(1.4, 2.3)
	gate.add_to_group("dynamic_gates")
	if gates_container != null:
		gates_container.add_child(gate)
	else:
		add_child(gate)
	gate.update_label()
	return gate

func _ensure_baseline_gates(moving: bool) -> void:
	if gates_container == null:
		gates_container = get_node_or_null("Gates")
		if gates_container == null:
			gates_container = Node3D.new()
			gates_container.name = "Gates"
			add_child(gates_container)

	for cfg in BASELINE_GATES:
		var g_name: String = String(cfg["name"])
		var existing: MultiplierGate3DScript = gates_container.get_node_or_null(g_name) as MultiplierGate3DScript
		if existing != null and existing.is_queued_for_deletion():
			gates_container.remove_child(existing)
			existing.free()
			existing = null
		if existing == null:
			if MultiplierGate3DScene != null:
				existing = MultiplierGate3DScene.instantiate() as MultiplierGate3DScript
			else:
				existing = MultiplierGate3DScript.new()
			existing.name = g_name
			gates_container.add_child(existing)
		existing.gate_id = g_name
		existing.operation = String(cfg["op"])
		existing.value = int(cfg["val"])
		existing.position = cfg["pos"]
		existing.is_locked = false
		existing.blockading_vault = null
		existing.move_enabled = moving
		existing.scroll_speed = GATE_SCROLL_SPEED if moving else 0.0
		existing.osc_enabled = false
		existing.osc_time = 0.0
		existing.update_label()

func _compute_gate_formation_slot(idx: int, total_group: int, anchor_x: float, base_z: float) -> Vector3:
	@warning_ignore("integer_division")
	var row_idx: int = idx / MAX_ROW_WIDTH
	var col_idx: int = idx % MAX_ROW_WIDTH
	var units_in_row: int = mini(MAX_ROW_WIDTH, total_group - row_idx * MAX_ROW_WIDTH)
	var half_span: float = float(units_in_row - 1) * CLONE_SPACING_X * 0.5
	var min_center: float = -HIGHWAY_HALF_WIDTH + half_span
	var max_center: float = HIGHWAY_HALF_WIDTH - half_span
	var row_center_x: float = clampf(anchor_x, min_center, max_center) if min_center <= max_center else 0.0
	var offset_x: float = (float(col_idx) - float(units_in_row - 1) * 0.5) * CLONE_SPACING_X
	var slot_x: float = clampf(row_center_x + offset_x, -HIGHWAY_HALF_WIDTH, HIGHWAY_HALF_WIDTH)
	var slot_z: float = base_z - float(row_idx) * CLONE_SPACING_Z
	return Vector3(slot_x, 0.5, slot_z)

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

	if gate.operation == "x":
		_on_bullet_hit_multiplier_gate(gate.value)

	var k: int = gate.calculate_clones()
	var remaining_space: int = MAX_MOBS - (get_live_blue_mobs_count() + pending_spawns)
	var allowed: int = maxi(0, mini(k, remaining_space))
	if allowed <= 0:
		return

	var anchor_x: float = mob.global_position.x if is_inside_tree() else mob.position.x
	var base_z: float = (gate.global_position.z if is_inside_tree() else gate.position.z) - 0.6
	var total_group: int = 1 + allowed
	var parent_slot: Vector3 = _compute_gate_formation_slot(0, total_group, anchor_x, base_z)
	mob.position.x = parent_slot.x

	var parent_power: int = maxi(1, mob.power if "power" in mob else 1)
	pending_spawns += allowed
	for i in range(allowed):
		var clone_pos: Vector3 = _compute_gate_formation_slot(i + 1, total_group, anchor_x, base_z)
		var clone_data = {
			"pos": clone_pos,
			"passed_gates": mob.passed_gates.duplicate(),
			"power": parent_power
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
	var pwr: int = int(clone_data.get("power", 1))
	_spawn_blue_mob(clone_data["pos"], clone_data["passed_gates"], pwr)

func flush_pending_spawns() -> void:
	var queue_copy = pending_spawn_queue.duplicate()
	pending_spawn_queue.clear()
	for item in queue_copy:
		_instantiate_clone(item)

func _spawn_destruction_fx(world_pos: Vector3, extent: Vector3 = Vector3(1.5, 1.5, 1.5), base_color: Color = Color(1.0, 0.65, 0.15)) -> Node3D:
	var fx := Node3D.new()
	fx.name = "DestructionFX_%d" % (active_destruction_fx.size() + 1)
	fx.position = world_pos
	fx.set_meta("elapsed", 0.0)
	fx.set_meta("duration", DESTRUCTION_FX_DURATION)

	var shard_mesh := BoxMesh.new()
	shard_mesh.size = Vector3(0.28, 0.28, 0.28)

	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = base_color
	shard_mat.emission_enabled = true
	shard_mat.emission = base_color * 1.4

	var shard_count: int = 12
	for i in range(shard_count):
		var angle: float = (TAU / float(shard_count)) * float(i)
		var ring_r: float = 0.25 + float(i % 3) * 0.2
		var shard := MeshInstance3D.new()
		shard.name = "Shard_%d" % i
		shard.mesh = shard_mesh
		shard.material_override = shard_mat
		shard.position = Vector3(
			cos(angle) * ring_r * maxf(0.4, extent.x * 0.35),
			(float(i % 3) - 1.0) * 0.25,
			sin(angle) * ring_r * maxf(0.4, extent.z * 0.35)
		)
		var spd_h: float = 3.2 + float(i % 4) * 1.1
		var vel := Vector3(cos(angle) * spd_h, 3.8 + float(i % 3) * 1.2, sin(angle) * spd_h)
		var ang_vel := Vector3(4.5 - float(i % 3) * 2.0, 6.0, 3.5 + float(i % 2) * 3.0)
		shard.set_meta("vel", vel)
		shard.set_meta("ang_vel", ang_vel)
		fx.add_child(shard)

	add_child(fx)
	active_destruction_fx.append(fx)
	return fx

func _step_destruction_fx(delta: float) -> void:
	for i in range(active_destruction_fx.size() - 1, -1, -1):
		var fx: Node3D = active_destruction_fx[i]
		if not is_instance_valid(fx) or fx.is_queued_for_deletion():
			active_destruction_fx.remove_at(i)
			continue
		var elapsed: float = float(fx.get_meta("elapsed", 0.0)) + delta
		var duration: float = maxf(0.05, float(fx.get_meta("duration", DESTRUCTION_FX_DURATION)))
		fx.set_meta("elapsed", elapsed)
		if elapsed >= duration:
			active_destruction_fx.remove_at(i)
			fx.queue_free()
			continue
		var scale_factor: float = clampf(1.0 - (elapsed / duration), 0.02, 1.0)
		for child in fx.get_children():
			if child is Node3D:
				var c_node := child as Node3D
				var vel: Vector3 = c_node.get_meta("vel", Vector3.UP)
				var ang_vel: Vector3 = c_node.get_meta("ang_vel", Vector3.ONE)
				c_node.position += vel * delta
				vel.y -= 16.0 * delta
				c_node.set_meta("vel", vel)
				c_node.rotation += ang_vel * delta
				c_node.scale = Vector3.ONE * scale_factor

func on_mob_clash(blue: MobUnit3DScript, red: MobUnit3DScript) -> void:
	if not is_live(blue) or not is_live(red):
		return
	var red_hp: int = maxi(1, red.power if "power" in red else 1)
	var blue_pwr: int = maxi(1, blue.power if "power" in blue else 1)
	var red_pos: Vector3 = red.global_position if is_inside_tree() else red.position
	red.is_consumed = true
	red.queue_free()
	soldiers_defeated += 1
	_spawn_destruction_fx(red_pos, Vector3(0.5, 0.6, 0.5), Color(0.95, 0.22, 0.22))
	if blue_pwr > red_hp:
		blue.power = blue_pwr - red_hp
	else:
		blue.power = 0
		blue.is_consumed = true
		blue.queue_free()
	_check_shield_release()

func on_boss_destroy_gate(boss: GiantEnemy3DScript, gate: MultiplierGate3DScript) -> void:
	if not is_instance_valid(boss) or not is_instance_valid(gate) or gate.is_queued_for_deletion():
		return
	var g_pos: Vector3 = gate.global_position if is_inside_tree() else gate.position
	_spawn_destruction_fx(g_pos, Vector3(2.4, 1.5, 0.8), Color(0.25, 0.78, 1.0))
	gate.is_locked = true
	gate.queue_free()

func on_mob_hit_boss(blue: MobUnit3DScript, boss: GiantEnemy3DScript) -> void:
	if not is_live(blue) or not is_instance_valid(boss) or boss.is_queued_for_deletion():
		return
	var dmg: int = maxi(1, blue.power if "power" in blue else 1)
	blue.is_consumed = true
	blue.queue_free()
	boss.take_damage(dmg)
	if boss.hp <= 0:
		var b_pos: Vector3 = boss.global_position if is_inside_tree() else boss.position
		_spawn_destruction_fx(b_pos, Vector3(3.5, 2.2, 1.8), Color(1.0, 0.72, 0.15))
		bosses_defeated += 1
		var idx: int = active_bosses.find(boss)
		if idx != -1:
			active_bosses.remove_at(idx)
		if not boss.is_queued_for_deletion():
			boss.queue_free()
		_update_cannon_status_ui()

func on_mob_hit_pylon(blue: MobUnit3DScript, pylon: GiantEnemy3DScript) -> void:
	if not is_live(blue):
		return
	var dmg: int = maxi(1, blue.power if "power" in blue else 1)
	blue.is_consumed = true
	blue.queue_free()
	if is_instance_valid(pylon):
		pylon.take_damage(dmg)
		if pylon.hp <= 0:
			var p_pos: Vector3 = pylon.global_position if is_inside_tree() else pylon.position
			_spawn_destruction_fx(p_pos, Vector3(3.0, 2.0, 1.5), Color(0.25, 0.85, 1.0))
			if not pylon.is_queued_for_deletion():
				pylon.queue_free()
			var idx = active_pylons.find(pylon)
			if idx != -1:
				active_pylons.remove_at(idx)
			_check_shield_release()

func on_mob_hit_vault(blue: MobUnit3DScript, vault: Node3D) -> void:
	if not is_live(blue):
		return
	var dmg: int = maxi(1, blue.power if "power" in blue else 1)
	blue.is_consumed = true
	blue.queue_free()
	if is_instance_valid(vault):
		if vault.has_method("take_damage"):
			vault.take_damage(dmg)
		elif "hp" in vault:
			vault.hp = maxi(0, vault.hp - dmg)
			if vault.has_method("_update_ui"):
				vault._update_ui()
		if "hp" in vault and vault.hp <= 0:
			_destroy_vault(vault)

func _destroy_vault(vault: Node3D) -> void:
	if not is_instance_valid(vault):
		return
	var v_pos: Vector3 = vault.global_position if is_inside_tree() else vault.position
	_spawn_destruction_fx(v_pos, Vector3(2.8, 2.0, 1.5), Color(0.85, 0.55, 1.0))
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

func on_mob_hit_obstacle(blue: MobUnit3DScript, obstacle: Node3D) -> void:
	if not is_live(blue) or not is_instance_valid(obstacle) or obstacle.is_queued_for_deletion():
		return
	var raw_pwr: int = maxi(1, blue.power if "power" in blue else 1)
	var is_haz: bool = obstacle.has_method("is_hazard") and obstacle.is_hazard()
	var dmg: int = maxi(1, int(ceil(float(raw_pwr) * 0.5))) if is_haz else raw_pwr
	blue.is_consumed = true
	blue.queue_free()

	if obstacle.has_method("take_damage"):
		obstacle.take_damage(dmg)
	elif "hp" in obstacle:
		obstacle.hp = maxi(0, obstacle.hp - dmg)

	if "hp" in obstacle and obstacle.hp <= 0:
		var o_pos: Vector3 = obstacle.global_position if is_inside_tree() else obstacle.position
		var hw: float = obstacle.half_width if "half_width" in obstacle else 1.5
		var fx_col := Color(0.95, 0.25, 0.25) if is_haz else Color(0.95, 0.65, 0.22)
		_spawn_destruction_fx(o_pos, Vector3(hw * 2.0, 2.0, 1.5), fx_col)
		var idx: int = active_obstacles.find(obstacle)
		if idx != -1:
			active_obstacles.remove_at(idx)
		if not obstacle.is_queued_for_deletion():
			obstacle.queue_free()

func on_mob_hit_giant(blue: MobUnit3DScript, giant: GiantEnemy3DScript) -> void:
	if not is_live(blue):
		return
	var dmg: int = maxi(1, blue.power if "power" in blue else 1)
	blue.is_consumed = true
	blue.queue_free()
	if not is_instance_valid(giant):
		return
	if giant.is_shielded or giant.is_invulnerable:
		# GWT 1: 0 damage discard while shielded
		return
	_apply_damage_to_base(dmg)

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
		mob.setup("red", 1)
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
				var p_pos: Vector3 = p.global_position if is_inside_tree() else p.position
				_spawn_destruction_fx(p_pos, Vector3(3.0, 2.0, 1.5), Color(0.25, 0.85, 1.0))
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

func _check_wave_progression() -> void:
	for i in range(active_obstacles.size() - 1, -1, -1):
		var obs = active_obstacles[i]
		if not is_instance_valid(obs) or obs.is_queued_for_deletion() or ("hp" in obs and obs.hp <= 0):
			if is_instance_valid(obs) and not obs.is_queued_for_deletion():
				obs.queue_free()
			active_obstacles.remove_at(i)

	if active_obstacles.is_empty() and current_wave < total_waves_in_stage:
		if is_instance_valid(giant_enemy) and giant_enemy.hp > 0:
			current_wave += 1
			_spawn_wave_obstacles(current_stage_index, current_wave)
			_update_cannon_status_ui()

func is_base_shielded() -> bool:
	return is_instance_valid(giant_enemy) and (giant_enemy.is_shielded or giant_enemy.is_invulnerable)

func get_current_lock_act() -> int:
	return current_lock_act

func get_all_gates() -> Array:
	var list: Array = []
	if gates_container != null:
		for child in gates_container.get_children():
			if child is MultiplierGate3DScript and not child.is_queued_for_deletion():
				list.append(child)
	for child in get_children():
		if child is MultiplierGate3DScript and not child.is_queued_for_deletion() and not list.has(child):
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
			if is_instance_valid(bg) and not bg.is_queued_for_deletion() and not list.has(bg):
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

func _resolve_boss_gate_destruction() -> void:
	if active_bosses.is_empty():
		return
	var gates: Array = get_all_gates()
	for boss in active_bosses:
		if not is_instance_valid(boss) or boss.is_queued_for_deletion() or boss.hp <= 0:
			continue
		var bx: float = boss.global_position.x if is_inside_tree() else boss.position.x
		var bz: float = boss.global_position.z if is_inside_tree() else boss.position.z
		var b_hw: float = boss.half_width if ("half_width" in boss and boss.half_width > 0.0) else 1.55
		var b_hz: float = boss.half_depth if ("half_depth" in boss and boss.half_depth > 0.0) else 1.0
		for gate in gates:
			if not is_instance_valid(gate) or gate.is_queued_for_deletion():
				continue
			var gx: float = gate.global_position.x if is_inside_tree() else gate.position.x
			var gz: float = gate.global_position.z if is_inside_tree() else gate.position.z
			if abs(bx - gx) <= (b_hw + 1.8) and abs(bz - gz) <= (b_hz + 0.45):
				on_boss_destroy_gate(boss, gate)

func _resolve_boss_contacts() -> void:
	for i in range(active_bosses.size() - 1, -1, -1):
		var boss = active_bosses[i]
		if not is_instance_valid(boss) or boss.is_queued_for_deletion() or boss.hp <= 0:
			continue
		var bx: float = boss.global_position.x if is_inside_tree() else boss.position.x
		var bz: float = boss.global_position.z if is_inside_tree() else boss.position.z
		var by: float = boss.global_position.y if is_inside_tree() else boss.position.y
		var hw: float = boss.half_width if ("half_width" in boss and boss.half_width > 0.0) else 1.55
		var hz: float = boss.half_depth if ("half_depth" in boss and boss.half_depth > 0.0) else 1.0
		var hy: float = boss.half_height if ("half_height" in boss and boss.half_height > 0.0) else 1.25

		for blue in blue_mobs:
			if not is_live(blue):
				continue
			var mx: float = blue.global_position.x if is_inside_tree() else blue.position.x
			var mz: float = blue.global_position.z if is_inside_tree() else blue.position.z
			var my: float = blue.global_position.y if is_inside_tree() else blue.position.y
			if abs(mx - bx) <= (hw + 0.22) and abs(mz - bz) <= (hz + 0.22) and abs(my - by) <= (hy + 0.35):
				on_mob_hit_boss(blue, boss)
				if not is_instance_valid(boss) or boss.is_queued_for_deletion() or boss.hp <= 0:
					break

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
				if not is_live(blue):
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
	if not is_instance_valid(giant_enemy) or not giant_enemy.visible:
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

func _resolve_obstacle_contacts() -> void:
	for i in range(active_obstacles.size() - 1, -1, -1):
		var obs = active_obstacles[i]
		if not is_instance_valid(obs) or obs.is_queued_for_deletion():
			continue
		var ox: float = obs.global_position.x
		var oz: float = obs.global_position.z
		var oy: float = obs.global_position.y
		var hw: float = obs.half_width if ("half_width" in obs and obs.half_width > 0.0) else 1.5
		var hz: float = obs.half_depth if ("half_depth" in obs and obs.half_depth > 0.0) else 0.75
		var hy: float = obs.half_height if ("half_height" in obs and obs.half_height > 0.0) else 1.25

		for blue in blue_mobs:
			if not is_live(blue):
				continue
			if abs(blue.global_position.x - ox) <= (hw + 0.22) and \
			   abs(blue.global_position.z - oz) <= (hz + 0.22) and \
			   abs(blue.global_position.y - oy) <= (hy + 0.35):
				on_mob_hit_obstacle(blue, obs)
				if not is_instance_valid(obs) or obs.is_queued_for_deletion() or ("hp" in obs and obs.hp <= 0):
					break

func _evaluate_game_state() -> void:
	# Check Defeat condition first
	var defeat_triggered: bool = false
	if not survival_mode and is_instance_valid(giant_enemy) and giant_enemy.visible and giant_enemy.global_position.z >= 9.0:
		defeat_triggered = true
	if not defeat_triggered:
		for boss in active_bosses:
			if is_instance_valid(boss) and not boss.is_queued_for_deletion() and boss.hp > 0:
				var bz: float = boss.global_position.z if is_inside_tree() else boss.position.z
				if bz >= 9.0:
					defeat_triggered = true
					break
	if not defeat_triggered:
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
		best_survival_time = maxf(best_survival_time, time_elapsed)
		if defeat_banner != null:
			if survival_mode:
				defeat_banner.text = "DEFEAT!\nSURVIVED: %s | BOSSES DEFEATED: %d | KILLS: %d\nPRESS R OR SPACE TO RETRY | ESC: MENU" % [_format_survival_time(time_elapsed), bosses_defeated, soldiers_defeated]
			else:
				defeat_banner.text = "DEFEAT!\nPRESS R TO RESTART OR ESC FOR MENU"
			defeat_banner.visible = true
		if victory_banner != null:
			victory_banner.visible = false
		return

	if survival_mode:
		return

	# Check Stage Clear or Campaign Victory second (only in legacy stage mode when not in Defeat)
	if is_instance_valid(giant_enemy) and giant_enemy.hp <= 0:
		if giant_enemy.visible:
			var g_pos: Vector3 = giant_enemy.global_position if is_inside_tree() else giant_enemy.position
			_spawn_destruction_fx(g_pos, Vector3(6.5, 2.5, 2.0), Color(1.0, 0.78, 0.15))
			giant_enemy.visible = false
		if current_stage_index < STAGES.size() - 1:
			state = GameState.STAGE_CLEAR
			if victory_banner != null:
				victory_banner.text = "STAGE %d CLEAR!\nPRESS SPACE OR ENTER TO ADVANCE" % (current_stage_index + 1)
				victory_banner.visible = true
			if defeat_banner != null:
				defeat_banner.visible = false
		else:
			state = GameState.VICTORY
			if victory_banner != null:
				victory_banner.text = "CAMPAIGN VICTORY!\nPRESS R TO RESTART OR ESC FOR MENU"
				victory_banner.visible = true
			if defeat_banner != null:
				defeat_banner.visible = false

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

	if dynamic_gates_enabled:
		for gate in get_all_gates():
			if is_instance_valid(gate) and not gate.is_queued_for_deletion():
				var gz: float = gate.global_position.z if is_inside_tree() else gate.position.z
				if gz >= GATE_DESPAWN_Z:
					gate.queue_free()

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
	for obs in active_obstacles:
		if is_instance_valid(obs) and not obs.is_queued_for_deletion():
			obs.queue_free()
	active_obstacles.clear()
	for boss in active_bosses:
		if is_instance_valid(boss) and not boss.is_queued_for_deletion():
			boss.queue_free()
	active_bosses.clear()
	for fx in active_destruction_fx:
		if is_instance_valid(fx) and not fx.is_queued_for_deletion():
			fx.queue_free()
	active_destruction_fx.clear()
	for surge in active_surge_units:
		if is_instance_valid(surge) and not surge.is_queued_for_deletion():
			surge.queue_free()
	active_surge_units.clear()

	if gates_container != null:
		for child in gates_container.get_children():
			if is_instance_valid(child) and child.is_in_group("dynamic_gates"):
				if not child.is_queued_for_deletion():
					child.queue_free()

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
		for obs in get_tree().get_nodes_in_group("obstacles"):
			if is_instance_valid(obs) and not obs.is_queued_for_deletion():
				obs.queue_free()
		for boss in get_tree().get_nodes_in_group("bosses"):
			if is_instance_valid(boss) and not boss.is_queued_for_deletion():
				boss.queue_free()
		for dyn_g in get_tree().get_nodes_in_group("dynamic_gates"):
			if is_instance_valid(dyn_g) and not dyn_g.is_queued_for_deletion():
				dyn_g.queue_free()
		for surge in get_tree().get_nodes_in_group("surge_units"):
			if is_instance_valid(surge) and not surge.is_queued_for_deletion():
				surge.queue_free()

func init_survival_phase() -> void:
	survival_mode = true
	dynamic_gates_enabled = true
	current_stage_index = 0
	highway_min_z = -32.0
	state = GameState.PLAYING
	current_lock_act = 1
	shield_locks_enabled = false
	cleanup_stage_entities()
	_ensure_baseline_gates(true)
	if is_instance_valid(giant_enemy):
		giant_enemy.reset(1200)
		giant_enemy.visible = false
	_reset_cannons_and_power()
	red_spawn_timer = 0.0
	soldier_spawn_timer = 0.0
	gate_spawn_timer = 0.0
	next_gate_spawn_interval = 3.0
	boss_spawn_timer = 0.0
	next_boss_spawn_interval = 7.5
	next_soldier_spawn_interval = SOLDIER_BASE_INTERVAL
	time_elapsed = 0.0
	bosses_defeated = 0
	soldiers_defeated = 0
	if is_instance_valid(victory_banner):
		victory_banner.visible = false
	if is_instance_valid(defeat_banner):
		defeat_banner.visible = false
	spawn_boss(Vector3(2.2, 1.25, -20.0), BOSS_BASE_HP, BOSS_BASE_SPEED)
	_update_cannon_status_ui()

func init_stage(stage_idx: int) -> void:
	survival_mode = false
	dynamic_gates_enabled = false
	current_stage_index = clampi(stage_idx, 0, STAGES.size() - 1)
	state = GameState.PLAYING
	current_lock_act = 1
	shield_locks_enabled = true
	cleanup_stage_entities()
	_ensure_baseline_gates(false)
	var cfg: Dictionary = STAGES[current_stage_index]
	highway_min_z = float(cfg.get("highway_min_z", cfg.get("highway_depth", -32.0)))
	current_wave = 1
	total_waves_in_stage = maxi(1, int(cfg.get("waves", 3)))
	if is_instance_valid(giant_enemy):
		var base_hp: int = int(cfg.get("base_hp", 1200))
		giant_enemy.reset(base_hp)
	_reset_cannons_and_power()
	red_spawn_timer = 0.0
	time_elapsed = 0.0
	if is_instance_valid(victory_banner):
		victory_banner.visible = false
	if is_instance_valid(defeat_banner):
		defeat_banner.visible = false
	_spawn_stage_layout(current_stage_index)
	_update_cannon_status_ui()

func advance_stage() -> void:
	if current_stage_index + 1 < STAGES.size():
		init_stage(current_stage_index + 1)
	else:
		state = GameState.VICTORY
		if victory_banner != null:
			victory_banner.text = "CAMPAIGN VICTORY!\nPRESS R TO RESTART OR ESC FOR MENU"
			victory_banner.visible = true
		if defeat_banner != null:
			defeat_banner.visible = false

func _spawn_stage_layout(stage_idx: int) -> void:
	_spawn_wave_obstacles(stage_idx, current_wave)
	if auto_spawn_vaults:
		spawn_stage_vault(stage_idx)

func spawn_obstacle(mode: int, pos: Vector3, hp_val: int, half_w: float = 1.6, osc_amp: float = 0.0, osc_spd: float = 2.2) -> GiantEnemy3DScript:
	var obs: GiantEnemy3DScript
	if GiantEnemyScene != null:
		obs = GiantEnemyScene.instantiate() as GiantEnemy3DScript
	else:
		obs = GiantEnemy3DScript.new()
	obs.half_width = half_w
	obs.half_depth = 0.70
	obs.half_height = 1.25
	obs.entity_mode = mode as GiantEnemy3DScript.EntityMode
	obs.hp = maxi(1, hp_val)
	obs.max_hp = maxi(1, hp_val)
	obs.speed = 0.0
	obs.is_invulnerable = false
	obs.is_shielded = false
	obs.position = pos
	obs.osc_base_x = pos.x
	if mode == GiantEnemy3DScript.EntityMode.MOVING_BLOCK or osc_amp > 0.0:
		obs.osc_enabled = true
		obs.osc_amplitude = osc_amp if osc_amp > 0.0 else 2.2
		obs.osc_speed = osc_spd
	obs.name = "Obstacle_%d_%d" % [current_wave, active_obstacles.size() + 1]
	obs.add_to_group("obstacles")
	add_child(obs)
	active_obstacles.append(obs)
	obs._build_entity_model()
	obs._update_ui()
	return obs

func _spawn_wave_obstacles(stage_idx: int, wave_idx: int) -> void:
	var base_obs_hp: int = 120 + stage_idx * 90 + (wave_idx - 1) * 60
	var left_x: float = -2.6 if (wave_idx % 2 == 1) else 2.6
	var right_x: float = -left_x
	spawn_obstacle(GiantEnemy3DScript.EntityMode.WALL, Vector3(left_x, 1.25, -10.2), base_obs_hp, 1.45)
	spawn_obstacle(GiantEnemy3DScript.EntityMode.HAZARD, Vector3(right_x, 1.25, -10.2), int(round(float(base_obs_hp) * 0.85)), 1.35)
	spawn_obstacle(
		GiantEnemy3DScript.EntityMode.MOVING_BLOCK,
		Vector3(0.0, 1.25, -11.4),
		int(round(float(base_obs_hp) * 1.15)),
		1.45,
		2.3,
		2.1 + float(wave_idx) * 0.25
	)
	if wave_idx > 1 and state == GameState.PLAYING:
		var raider_count: int = 2 + wave_idx
		for i in range(raider_count):
			var r_mob := _spawn_red_mob()
			if r_mob != null:
				var rx: float = -3.6 + (7.2 / float(maxi(1, raider_count - 1))) * float(i)
				r_mob.position = Vector3(rx, 0.5, -18.0 - float(i % 2) * 0.6)

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
	if vault.has_method("_build_entity_model"):
		vault._build_entity_model()
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

func retry_stage() -> void:
	if survival_mode:
		init_survival_phase()
	else:
		init_stage(current_stage_index)

func reset_stage() -> void:
	if survival_mode:
		init_survival_phase()
	else:
		init_stage(current_stage_index)

func return_to_menu() -> void:
	if _returning_to_menu:
		return
	_returning_to_menu = true
	_restore_retro_viewport()
	return_to_menu_requested.emit()
	if is_inside_tree() and get_tree() != null and (get_tree().current_scene == self or get_tree().current_scene == null):
		get_tree().change_scene_to_file("res://scenes/Menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE)):
		return_to_menu()
		if get_viewport():
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var is_advance_or_retry_key: bool = (
			event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE or
			event.keycode == KEY_ENTER or event.physical_keycode == KEY_ENTER or
			event.keycode == KEY_KP_ENTER or event.physical_keycode == KEY_KP_ENTER or
			event.keycode == KEY_R or event.physical_keycode == KEY_R
		)
		if is_advance_or_retry_key:
			if state == GameState.STAGE_CLEAR:
				advance_stage()
				if get_viewport():
					get_viewport().set_input_as_handled()
			elif state == GameState.DEFEAT:
				retry_stage()
				if get_viewport():
					get_viewport().set_input_as_handled()
			elif state == GameState.VICTORY:
				if survival_mode:
					init_survival_phase()
				else:
					init_stage(0)
				if get_viewport():
					get_viewport().set_input_as_handled()
