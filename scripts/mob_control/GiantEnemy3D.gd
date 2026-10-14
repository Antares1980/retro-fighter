class_name GiantEnemy3D
extends Area3D

## Giant Boss for Mob Control 3D.
## Features a wide BoxShape3D (9.5, 2.5, 2.5) covering X in [-4.75, +4.75].
## Marches forward along +Z, takes 1 damage per Blue Mob hit.

@export var hp: int = 150
@export var max_hp: int = 150
@export var speed: float = 1.0

@onready var label: Label3D = $Label3D if has_node("Label3D") else null
@onready var health_bar: Node3D = $HealthBar if has_node("HealthBar") else null

func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	_update_ui()

func take_damage(amount: int = 1) -> void:
	hp = maxi(0, hp - amount)
	_update_ui()

func _update_ui() -> void:
	if label == null:
		label = get_node_or_null("Label3D")
	if health_bar == null:
		health_bar = get_node_or_null("HealthBar")

	if label != null:
		label.text = "HP: %d" % hp
	if health_bar != null:
		var ratio: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
		health_bar.scale.x = ratio

func reset(p_hp: int = 150) -> void:
	hp = p_hp
	max_hp = p_hp
	position = Vector3(0.0, 1.25, -15.0)
	_update_ui()
