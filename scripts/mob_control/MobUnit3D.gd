class_name MobUnit3D
extends Area3D

## Swarm Mob unit for Mob Control 3D.
## Blue mobs multiply through gates and damage the Giant Boss.
## Red mobs march toward the player cannon and clash with Blue mobs.

@export var team: String = "blue"
@export var speed: float = 9.0

var is_consumed: bool = false
var passed_gates: Dictionary = {}
var hp: int = 1
var power: int = 1:
	set(val):
		power = maxi(0, val)
		hp = power
		_update_power_visuals()

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null

func _ready() -> void:
	setup(team, power if power > 0 else 1)

func setup(p_team: String, p_power: int = -1) -> void:
	team = p_team
	if p_power > 0:
		power = p_power
	elif power <= 0:
		power = 1
	hp = power
	if team == "blue":
		collision_layer = 2
		collision_mask = 28 # Layers 3 (Red), 4 (Gates), 5 (Giant) -> 4 + 8 + 16 = 28
		speed = 9.0
		_update_power_visuals()
	else:
		collision_layer = 4
		collision_mask = 2 # Layer 2 (Blue)
		speed = 4.2
		if mesh_instance == null:
			mesh_instance = get_node_or_null("MeshInstance3D")
		if mesh_instance != null:
			mesh_instance.scale = Vector3.ONE
		_apply_material(Color("#e62222"))

func _update_power_visuals() -> void:
	if team != "blue":
		return
	if mesh_instance == null:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if mesh_instance == null:
		return
	if power <= 1:
		mesh_instance.scale = Vector3.ONE
		_apply_material(Color("#1e90ff"))
		return
	var s: float = clampf(1.0 + log(float(power)) * 0.12, 1.0, 1.45)
	mesh_instance.scale = Vector3(s, s, s)
	var t: float = clampf(log(float(power)) / log(25.0), 0.0, 1.0)
	var base_blue := Color("#1e90ff")
	var mid_cyan := Color("#00f2ff")
	var high_gold := Color("#ffd700")
	var tint: Color = base_blue.lerp(mid_cyan, clampf(t * 2.0, 0.0, 1.0)) if t < 0.5 else mid_cyan.lerp(high_gold, clampf((t - 0.5) * 2.0, 0.0, 1.0))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint * 0.35
	mesh_instance.material_override = mat

func _apply_material(color: Color) -> void:
	if mesh_instance == null:
		mesh_instance = get_node_or_null("MeshInstance3D")
	if mesh_instance != null:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mesh_instance.material_override = mat

func consume() -> void:
	if is_consumed:
		return
	is_consumed = true
	queue_free()
