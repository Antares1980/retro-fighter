class_name MobUnit3D
extends Area3D

## Swarm Mob unit for Mob Control 3D.
## Blue mobs multiply through gates and damage the Giant Boss.
## Red mobs march toward the player cannon and clash 1-to-1 with Blue mobs.

@export var team: String = "blue"
@export var speed: float = 9.0

var is_consumed: bool = false
var passed_gates: Dictionary = {}
var hp: int = 1

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null

func _ready() -> void:
	setup(team)

func setup(p_team: String) -> void:
	team = p_team
	if team == "blue":
		collision_layer = 2
		collision_mask = 28 # Layers 3 (Red), 4 (Gates), 5 (Giant) -> 4 + 8 + 16 = 28
		speed = 9.0
		_apply_material(Color("#1e90ff"))
	else:
		collision_layer = 4
		collision_mask = 2 # Layer 2 (Blue)
		speed = 4.2
		_apply_material(Color("#e62222"))

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
