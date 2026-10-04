class_name Hurtbox
extends Area2D

## Hurtbox for receiving damage and stun in Retro Fighter.
## Uses a 7-layer bitmask configuration for P1 vs P2 damage receiving.
## Standing size: 24 x 54 px (offset 0, -27)
## Crouching size: 24 x 32 px (offset 0, -16)

signal hit_received(hitbox: Area2D)

# 7-Layer Collision Bitmask Definitions (1-indexed layers)
const LAYER_WORLDFLOOR: int = 1
const LAYER_FIGHTERBODY: int = 2
const LAYER_STAGEWALL: int = 3
const LAYER_P1_HURTBOX: int = 4
const LAYER_P1_HITBOX: int = 5
const LAYER_P2_HURTBOX: int = 6
const LAYER_P2_HITBOX: int = 7

# Bitmask values (1 << (layer - 1))
const MASK_WORLDFLOOR: int = 1 << 0   # 1
const MASK_FIGHTERBODY: int = 1 << 1  # 2
const MASK_STAGEWALL: int = 1 << 2    # 4
const MASK_P1_HURTBOX: int = 1 << 3   # 8
const MASK_P1_HITBOX: int = 1 << 4    # 16
const MASK_P2_HURTBOX: int = 1 << 5   # 32
const MASK_P2_HITBOX: int = 1 << 6    # 64

# Geometry presets (origin at bottom-center / feet)
const STANDING_SIZE: Vector2 = Vector2(24.0, 54.0)
const STANDING_OFFSET: Vector2 = Vector2(0.0, -27.0)
const CROUCHING_SIZE: Vector2 = Vector2(24.0, 32.0)
const CROUCHING_OFFSET: Vector2 = Vector2(0.0, -16.0)

var player_id: int = 0
var fighter: Node = null
var is_crouching: bool = false
var is_invulnerable: bool = false

func _init() -> void:
	monitoring = false
	monitorable = true

## Configures the collision layer and collision mask according to the 7-layer bitmask matrix.
## P1 Hurtbox: Layer 4 (P1_Hurtbox), Mask 0 (None)
## P2 Hurtbox: Layer 6 (P2_Hurtbox), Mask 0 (None)
func setup(p_player_id: int) -> void:
	player_id = p_player_id
	if player_id == 1:
		collision_layer = MASK_P1_HURTBOX
		collision_mask = 0
	elif player_id == 2:
		collision_layer = MASK_P2_HURTBOX
		collision_mask = 0
	else:
		collision_layer = 0
		collision_mask = 0

## Retrieves child CollisionShape2D or null.
func get_collision_shape() -> CollisionShape2D:
	for child in get_children():
		if child is CollisionShape2D:
			return child
	return null

## Switches between standing (24x54) and crouching (24x32) dimensions.
func set_crouching(crouch: bool) -> void:
	is_crouching = crouch
	var col_shape: CollisionShape2D = get_collision_shape()
	if col_shape != null:
		if is_crouching:
			col_shape.position = CROUCHING_OFFSET
			if col_shape.shape is RectangleShape2D:
				(col_shape.shape as RectangleShape2D).size = CROUCHING_SIZE
		else:
			col_shape.position = STANDING_OFFSET
			if col_shape.shape is RectangleShape2D:
				(col_shape.shape as RectangleShape2D).size = STANDING_SIZE

## Processes hit receipt from an incoming Hitbox.
## Returns true if the hit was accepted, false if ignored (e.g. invulnerable).
func take_hit(hitbox: Area2D) -> bool:
	if is_invulnerable:
		return false
	hit_received.emit(hitbox)
	if fighter != null and fighter.has_method("receive_hit"):
		fighter.receive_hit(
			hitbox.damage,
			hitbox.hit_stun_ticks,
			hitbox.block_stun_ticks,
			hitbox.knockback_x,
			hitbox.is_low,
			hitbox.attacker
		)
	elif get_parent() != null and get_parent().has_method("receive_hit"):
		get_parent().receive_hit(
			hitbox.damage,
			hitbox.hit_stun_ticks,
			hitbox.block_stun_ticks,
			hitbox.knockback_x,
			hitbox.is_low,
			hitbox.attacker
		)
	return true
