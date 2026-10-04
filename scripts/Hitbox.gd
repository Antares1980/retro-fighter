class_name Hitbox
extends Area2D

## Hitbox for attacking in Retro Fighter.
## Uses a 7-layer bitmask configuration for P1 vs P2 damage delivery.
## Supports one-shot hit registration via hit_consumed flag.

signal hit_landed(hurtbox: Area2D)

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

# Preset Attack Frame Data
const PUNCH_DAMAGE: int = 8
const PUNCH_HIT_STUN: int = 12
const PUNCH_BLOCK_STUN: int = 6
const PUNCH_KNOCKBACK: float = 40.0
const PUNCH_IS_LOW: bool = false
const PUNCH_SIZE: Vector2 = Vector2(24.0, 12.0)
const PUNCH_OFFSET: Vector2 = Vector2(20.0, -36.0)

const KICK_DAMAGE: int = 14
const KICK_HIT_STUN: int = 18
const KICK_BLOCK_STUN: int = 8
const KICK_KNOCKBACK: float = 80.0
const KICK_IS_LOW: bool = true
const KICK_SIZE: Vector2 = Vector2(30.0, 12.0)
const KICK_OFFSET: Vector2 = Vector2(24.0, -12.0)

@export var damage: int = 0
@export var hit_stun_ticks: int = 0
@export var block_stun_ticks: int = 0
@export var knockback_x: float = 0.0
@export var is_low: bool = false

var player_id: int = 0
var hit_consumed: bool = false
var attacker: Node = null

func _init() -> void:
	monitoring = true
	monitorable = true

func _ready() -> void:
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

## Configures the collision layer and collision mask according to the 7-layer bitmask matrix.
## P1 Hitbox: Layer 5 (P1_Hitbox), Mask Layer 6 (P2_Hurtbox)
## P2 Hitbox: Layer 7 (P2_Hitbox), Mask Layer 4 (P1_Hurtbox)
func setup(p_player_id: int) -> void:
	player_id = p_player_id
	if player_id == 1:
		collision_layer = MASK_P1_HITBOX
		collision_mask = MASK_P2_HURTBOX
	elif player_id == 2:
		collision_layer = MASK_P2_HITBOX
		collision_mask = MASK_P1_HURTBOX
	else:
		collision_layer = 0
		collision_mask = 0

## Sets attack parameters for damage delivery.
func set_attack(
	p_damage: int,
	p_hit_stun_ticks: int,
	p_block_stun_ticks: int,
	p_knockback_x: float,
	p_is_low: bool = false,
	p_attacker: Node = null
) -> void:
	damage = p_damage
	hit_stun_ticks = p_hit_stun_ticks
	block_stun_ticks = p_block_stun_ticks
	knockback_x = p_knockback_x
	is_low = p_is_low
	attacker = p_attacker
	hit_consumed = false

## Activates the hitbox for an attack frame window and resets one-shot registration.
func activate() -> void:
	hit_consumed = false
	monitoring = true

## Deactivates the hitbox when the active attack window ends.
func deactivate() -> void:
	monitoring = false

## Resets hit_consumed flag for a new attack swing.
func reset_hit() -> void:
	hit_consumed = false

## Convenience setup for Punch attack.
func configure_punch(facing: int = 1, p_attacker: Node = null) -> void:
	set_attack(PUNCH_DAMAGE, PUNCH_HIT_STUN, PUNCH_BLOCK_STUN, PUNCH_KNOCKBACK, PUNCH_IS_LOW, p_attacker)
	set_box(PUNCH_SIZE, Vector2(PUNCH_OFFSET.x * facing, PUNCH_OFFSET.y))

## Convenience setup for Kick attack.
func configure_kick(facing: int = 1, p_attacker: Node = null) -> void:
	set_attack(KICK_DAMAGE, KICK_HIT_STUN, KICK_BLOCK_STUN, KICK_KNOCKBACK, KICK_IS_LOW, p_attacker)
	set_box(KICK_SIZE, Vector2(KICK_OFFSET.x * facing, KICK_OFFSET.y))

## Retrieves child CollisionShape2D or null.
func get_collision_shape() -> CollisionShape2D:
	for child in get_children():
		if child is CollisionShape2D:
			return child
	return null

## Sets the box size and offset if CollisionShape2D is present.
func set_box(box_size: Vector2, box_offset: Vector2) -> void:
	var col_shape: CollisionShape2D = get_collision_shape()
	if col_shape != null:
		col_shape.position = box_offset
		if col_shape.shape is RectangleShape2D:
			(col_shape.shape as RectangleShape2D).size = box_size

## Attempts to deliver a hit to a Hurtbox with one-shot registration.
func trigger_hit(hurtbox: Area2D) -> bool:
	if hit_consumed:
		return false
	if hurtbox.has_method("take_hit"):
		var accepted = hurtbox.take_hit(self)
		if accepted == null or accepted == true:
			hit_consumed = true
			hit_landed.emit(hurtbox)
			return true
	return false

func _on_area_entered(area: Area2D) -> void:
	trigger_hit(area)
