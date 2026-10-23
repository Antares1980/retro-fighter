class_name GiantEnemy3D
extends Area3D

## Giant Mech Boss, Shield Pylon, Vault, & Highway Obstacles for Mob Control 3D.
## Supports EntityMode { BASE, PYLON, WALL, MOVING_BLOCK, HAZARD } with composite 3D silhouettes,
## horizontal lane oscillation for moving blocks, hit-flash feedback, and zero-HP screen removal.

enum EntityMode { BASE, PYLON, WALL, MOVING_BLOCK, HAZARD }

@export var entity_mode: EntityMode = EntityMode.BASE:
	set(val):
		entity_mode = val
		if is_inside_tree():
			_build_entity_model()
			_update_ui()
@export var hp: int = 150
@export var max_hp: int = 150
@export var speed: float = 1.0
@export var is_invulnerable: bool = false
@export var is_shielded: bool = false

@onready var label: Label3D = $Label3D if has_node("Label3D") else null
@onready var health_bar: Node3D = $HealthBar if has_node("HealthBar") else null
@onready var base_mesh: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null

var target_gate: Node3D = null
var blockaded_gate: Node3D:
	get:
		return target_gate
	set(val):
		target_gate = val

var half_width: float = 2.0
var half_depth: float = 1.25
var half_height: float = 1.25

var osc_enabled: bool = false
var osc_base_x: float = 0.0
var osc_amplitude: float = 2.0
var osc_speed: float = 2.2
var osc_phase: float = 0.0
var osc_time: float = 0.0

var hit_flash_timer: float = 0.0
var mech_model: Node3D = null
var _built_mode: int = -1
var _model_parts: Array[MeshInstance3D] = []
var _default_materials: Array[StandardMaterial3D] = []
var _flash_material: StandardMaterial3D = null

func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	_build_entity_model()
	_update_ui()

func is_base() -> bool:
	return entity_mode == EntityMode.BASE and not is_vault()

func is_pylon() -> bool:
	return entity_mode == EntityMode.PYLON

func is_vault() -> bool:
	return is_in_group("vaults")

func is_wall() -> bool:
	return entity_mode == EntityMode.WALL

func is_moving_block() -> bool:
	return entity_mode == EntityMode.MOVING_BLOCK

func is_hazard() -> bool:
	return entity_mode == EntityMode.HAZARD

func is_obstacle() -> bool:
	return entity_mode in [EntityMode.WALL, EntityMode.MOVING_BLOCK, EntityMode.HAZARD]

func is_hit_flashing() -> bool:
	return hit_flash_timer > 0.0

func take_damage(amount: int = 1) -> void:
	if is_invulnerable or is_shielded:
		return
	hp = maxi(0, hp - amount)
	if hp > 0:
		_trigger_hit_flash()
	_update_ui()

func _trigger_hit_flash() -> void:
	hit_flash_timer = 0.10
	if mech_model == null or not is_instance_valid(mech_model):
		_build_entity_model()
	if _flash_material == null:
		_flash_material = StandardMaterial3D.new()
		_flash_material.albedo_color = Color(1.0, 0.96, 0.85, 1.0)
		_flash_material.emission_enabled = true
		_flash_material.emission = Color(1.0, 0.85, 0.55, 1.0) * 1.6
	for part in _model_parts:
		if is_instance_valid(part):
			part.material_override = _flash_material
	if is_instance_valid(mech_model):
		mech_model.scale = Vector3(1.04, 0.95, 1.05)

func step_obstacle(delta: float) -> void:
	if osc_enabled or entity_mode == EntityMode.MOVING_BLOCK:
		osc_time += delta
		var limit: float = maxf(0.2, 4.5 - half_width)
		position.x = clampf(osc_base_x + sin(osc_time * osc_speed + osc_phase) * osc_amplitude, -limit, limit)
	step_visuals(delta)

func step_visuals(delta: float) -> void:
	if hit_flash_timer > 0.0:
		hit_flash_timer = maxf(0.0, hit_flash_timer - delta)
		if hit_flash_timer <= 0.0:
			for i in range(_model_parts.size()):
				var part: MeshInstance3D = _model_parts[i]
				if is_instance_valid(part) and i < _default_materials.size():
					part.material_override = _default_materials[i]
			if is_instance_valid(mech_model):
				mech_model.scale = Vector3.ONE

func _build_entity_model() -> void:
	if base_mesh == null:
		base_mesh = get_node_or_null("MeshInstance3D")
	if base_mesh != null:
		base_mesh.visible = false

	var effective_mode: int = int(entity_mode)
	if is_vault():
		effective_mode = 99
	if mech_model != null and is_instance_valid(mech_model) and _built_mode == effective_mode:
		return

	if mech_model != null and is_instance_valid(mech_model):
		mech_model.free()
	_model_parts.clear()
	_default_materials.clear()

	mech_model = Node3D.new()
	mech_model.name = "MechModel3D"
	add_child(mech_model)
	_built_mode = effective_mode

	var w: float = maxf(1.2, half_width * 2.0) if (is_obstacle() or is_vault() or is_pylon()) else 8.8
	var primary_col := Color(0.92, 0.70, 0.12, 1.0)
	var secondary_col := Color(0.28, 0.30, 0.36, 1.0)
	var accent_col := Color(1.0, 0.22, 0.18, 1.0)

	if is_pylon():
		primary_col = Color(0.18, 0.72, 0.96, 1.0)
		secondary_col = Color(0.12, 0.25, 0.42, 1.0)
		accent_col = Color(0.45, 0.95, 1.0, 1.0)
	elif is_vault():
		primary_col = Color(0.75, 0.52, 0.96, 1.0)
		secondary_col = Color(0.24, 0.16, 0.36, 1.0)
		accent_col = Color(1.0, 0.84, 0.25, 1.0)
	elif is_wall():
		primary_col = Color(0.76, 0.44, 0.20, 1.0)
		secondary_col = Color(0.32, 0.24, 0.18, 1.0)
		accent_col = Color(0.95, 0.78, 0.22, 1.0)
	elif is_moving_block():
		primary_col = Color(0.22, 0.62, 0.88, 1.0)
		secondary_col = Color(0.16, 0.24, 0.34, 1.0)
		accent_col = Color(1.0, 0.75, 0.15, 1.0)
	elif is_hazard():
		primary_col = Color(0.85, 0.12, 0.22, 1.0)
		secondary_col = Color(0.22, 0.06, 0.10, 1.0)
		accent_col = Color(1.0, 0.45, 0.10, 1.0)

	_add_box_part("CoreChassis", Vector3(w * 0.72, 1.85, 1.45), Vector3(0.0, -0.15, 0.0), primary_col, 0.15)
	_add_box_part("CommandHead", Vector3(w * 0.34, 0.85, 1.05), Vector3(0.0, 1.05, 0.05), secondary_col, 0.1)
	_add_box_part("VisorEye", Vector3(w * 0.28, 0.24, 0.16), Vector3(0.0, 1.08, 0.56), accent_col, 1.2)
	_add_box_part("LeftPauldron", Vector3(w * 0.20, 1.45, 1.65), Vector3(-w * 0.42, 0.15, 0.0), secondary_col, 0.1)
	_add_box_part("RightPauldron", Vector3(w * 0.20, 1.45, 1.65), Vector3(w * 0.42, 0.15, 0.0), secondary_col, 0.1)
	_add_box_part("LeftCannon", Vector3(w * 0.10, 0.35, 1.15), Vector3(-w * 0.38, 0.75, 0.55), accent_col, 0.5)
	_add_box_part("RightCannon", Vector3(w * 0.10, 0.35, 1.15), Vector3(w * 0.38, 0.75, 0.55), accent_col, 0.5)

func _add_box_part(part_name: String, box_size: Vector3, pos: Vector3, col: Color, emission_mult: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	var bm := BoxMesh.new()
	bm.size = box_size
	mi.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = 0.4
	mat.roughness = 0.45
	if emission_mult > 0.0:
		mat.emission_enabled = true
		mat.emission = col * emission_mult
	mi.material_override = mat
	mi.position = pos
	mech_model.add_child(mi)
	_model_parts.append(mi)
	_default_materials.append(mat)
	return mi

func get_visual_part_count() -> int:
	if mech_model == null or not is_instance_valid(mech_model):
		_build_entity_model()
	return _model_parts.size()

func _update_ui() -> void:
	if label == null:
		label = get_node_or_null("Label3D")
	if health_bar == null:
		health_bar = get_node_or_null("HealthBar")

	if label != null:
		if is_pylon():
			label.text = "PYLON: %d" % hp
		elif is_vault():
			label.text = "VAULT: %d" % hp
		elif is_wall():
			label.text = "WALL: %d" % hp
		elif is_moving_block():
			label.text = "ARMOR: %d" % hp
		elif is_hazard():
			label.text = "HAZARD: %d" % hp
		elif is_shielded or is_invulnerable:
			label.text = "SHIELDED: %d" % hp
		else:
			label.text = "HP: %d" % hp
	if health_bar != null:
		var ratio: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
		health_bar.scale.x = clampf(ratio, 0.0, 1.0)

func reset(p_hp: int = 150) -> void:
	hp = p_hp
	max_hp = p_hp
	entity_mode = EntityMode.BASE
	is_invulnerable = false
	is_shielded = false
	osc_enabled = false
	hit_flash_timer = 0.0
	visible = true
	position = Vector3(0.0, 1.25, -15.0)
	_build_entity_model()
	if is_instance_valid(mech_model):
		mech_model.scale = Vector3.ONE
	_update_ui()
