class_name Cannon3D
extends Node3D

## Wheeled player cannon for Mob Control 3D.
## Steers horizontally along X in [-5.0, +5.0] and fires Blue mobs at 0.14s intervals.

signal shoot_requested(muzzle_pos: Vector3)

const FIRE_INTERVAL: float = 0.14

@export var speed: float = 8.0
@export var min_x: float = -5.0
@export var max_x: float = 5.0

var move_input: float = 0.0
var fire_held: bool = false
var fire_accumulator: float = 0.0

@onready var muzzle: Marker3D = $Muzzle if has_node("Muzzle") else null

func step(delta: float) -> void:
	var left_active: bool = move_input < -0.1 or Input.is_action_pressed("p1_left") or Input.is_action_pressed("p2_left") or Input.is_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_LEFT)
	var right_active: bool = move_input > 0.1 or Input.is_action_pressed("p1_right") or Input.is_action_pressed("p2_right") or Input.is_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_RIGHT)
	var mc_fire_active: bool = Input.is_action_pressed("mc_fire") if InputMap.has_action("mc_fire") else false
	var effective_fire: bool = fire_held or Input.is_action_pressed("p1_punch") or mc_fire_active or Input.is_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_J) or Input.is_physical_key_pressed(KEY_J)

	var dir: float = 0.0
	if left_active:
		dir -= 1.0
	if right_active:
		dir += 1.0
	position.x = clampf(position.x + dir * speed * delta, min_x, max_x)

	if effective_fire:
		fire_accumulator += delta
		if fire_accumulator >= FIRE_INTERVAL:
			fire_accumulator -= FIRE_INTERVAL
			if muzzle == null:
				muzzle = get_node_or_null("Muzzle")
			var muzzle_pos: Vector3 = muzzle.global_position if muzzle != null else Vector3(position.x, 0.5, 8.0)
			shoot_requested.emit(muzzle_pos)
	else:
		fire_accumulator = 0.0

func reset() -> void:
	position = Vector3(0.0, 0.5, 9.0)
	move_input = 0.0
	fire_held = false
	fire_accumulator = 0.0
