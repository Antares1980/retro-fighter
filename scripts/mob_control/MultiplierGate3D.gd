class_name MultiplierGate3D
extends Area3D

## Math modifier gate for Mob Control 3D.
## Replicates passing Blue mobs based on addition (+) or multiplication (x).

@export var gate_id: String = ""
@export var operation: String = "+"
@export var value: int = 2

@onready var label: Label3D = $Label3D if has_node("Label3D") else null

func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	update_label()

func update_label() -> void:
	if label == null:
		label = get_node_or_null("Label3D")
	if label != null:
		label.text = "%s%d" % [operation, value]

func calculate_clones() -> int:
	if operation == "x":
		return maxi(0, value - 1)
	return maxi(0, value)
