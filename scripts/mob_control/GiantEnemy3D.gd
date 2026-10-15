class_name GiantEnemy3D
extends Area3D

## Giant Boss for Mob Control 3D.
## Features a wide BoxShape3D (9.5, 2.5, 2.5) covering X in [-4.75, +4.75].
## Marches forward along +Z, takes 1 damage per Blue Mob hit.

enum EntityMode { BASE, PYLON }

@export var entity_mode: EntityMode = EntityMode.BASE
@export var hp: int = 150
@export var max_hp: int = 150
@export var speed: float = 1.0
@export var is_invulnerable: bool = false
@export var is_shielded: bool = false

@onready var label: Label3D = $Label3D if has_node("Label3D") else null
@onready var health_bar: Node3D = $HealthBar if has_node("HealthBar") else null

func _ready() -> void:
	collision_layer = 16
	collision_mask = 2
	_update_ui()

func is_base() -> bool:
	return entity_mode == EntityMode.BASE

func is_pylon() -> bool:
	return entity_mode == EntityMode.PYLON

func take_damage(amount: int = 1) -> void:
	if is_invulnerable or is_shielded:
		return
	hp = maxi(0, hp - amount)
	_update_ui()

func _update_ui() -> void:
	if label == null:
		label = get_node_or_null("Label3D")
	if health_bar == null:
		health_bar = get_node_or_null("HealthBar")

	if label != null:
		if is_pylon():
			label.text = "PYLON: %d" % hp
		elif is_shielded or is_invulnerable:
			label.text = "SHIELDED: %d" % hp
		else:
			label.text = "HP: %d" % hp
	if health_bar != null:
		var ratio: float = float(hp) / float(max_hp) if max_hp > 0 else 0.0
		health_bar.scale.x = ratio

func reset(p_hp: int = 150) -> void:
	hp = p_hp
	max_hp = p_hp
	entity_mode = EntityMode.BASE
	is_invulnerable = false
	is_shielded = false
	position = Vector3(0.0, 1.25, -15.0)
	_update_ui()

