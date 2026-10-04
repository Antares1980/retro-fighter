class_name DynamicFightCamera
extends Camera2D

## Dynamic Fight Camera for Retro Fighter.
## Implements fixed zoom (1.0), midpoint framing between two fighters,
## clamping between X = 192 and X = 408 to remain within the 600 px stage,
## and exposes get_view_bounds() -> Rect2 for fighter position boundary clamping.

const VIEWPORT_WIDTH: float = 384.0
const VIEWPORT_HEIGHT: float = 224.0
const MIN_CAMERA_X: float = 192.0
const MAX_CAMERA_X: float = 408.0
const DEFAULT_Y: float = 112.0
const FIXED_Y: float = 112.0
const MIN_X: float = 192.0
const MAX_X: float = 408.0

@export var min_x: float = MIN_CAMERA_X
@export var max_x: float = MAX_CAMERA_X
@export var fixed_y: float = FIXED_Y
@export var viewport_width: float = VIEWPORT_WIDTH
@export var viewport_height: float = VIEWPORT_HEIGHT

@export var target1: Node2D = null
@export var target2: Node2D = null

# Property aliases for convenience
var fighter1: Node2D:
	get:
		return target1
	set(val):
		target1 = val

var fighter2: Node2D:
	get:
		return target2
	set(val):
		target2 = val

var left_bound: float:
	get:
		return get_view_bounds().position.x

var right_bound: float:
	get:
		var bounds = get_view_bounds()
		return bounds.position.x + bounds.size.x

var top_bound: float:
	get:
		return get_view_bounds().position.y

var bottom_bound: float:
	get:
		var bounds = get_view_bounds()
		return bounds.position.y + bounds.size.y

func _init() -> void:
	zoom = Vector2(1.0, 1.0)
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	process_priority = 100
	process_physics_priority = 100
	position = Vector2(300.0, FIXED_Y)

func _ready() -> void:
	zoom = Vector2(1.0, 1.0)
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	find_targets()
	update_camera()

func _process(_delta: float) -> void:
	find_targets()
	update_camera()

func _physics_process(_delta: float) -> void:
	find_targets()
	update_camera()

## Automatically resolves fighter targets from parent children or tree group if not assigned.
func find_targets() -> void:
	if is_instance_valid(target1) and is_instance_valid(target2):
		return

	var candidates: Array[Node2D] = []

	if get_parent() != null:
		for child in get_parent().get_children():
			if child != self and (child is CharacterBody2D or (child is Node2D and "player_id" in child)):
				candidates.append(child)

	if candidates.is_empty() and is_inside_tree():
		var group_nodes = get_tree().get_nodes_in_group("fighters")
		for node in group_nodes:
			if node is Node2D and node != self:
				candidates.append(node)

	if candidates.size() >= 2:
		var p1: Node2D = null
		var p2: Node2D = null
		for c in candidates:
			if "player_id" in c:
				if c.player_id == 1:
					p1 = c
				elif c.player_id == 2:
					p2 = c
		if p1 != null and p2 != null:
			target1 = p1
			target2 = p2
		else:
			target1 = candidates[0]
			target2 = candidates[1]
	elif candidates.size() == 1 and not is_instance_valid(target1):
		target1 = candidates[0]

## Sets fighter targets explicitly and immediately updates framing.
func set_targets(p_target1: Node2D, p_target2: Node2D) -> void:
	target1 = p_target1
	target2 = p_target2
	update_camera()

## Calculates the horizontal midpoint between targets.
func get_midpoint_x() -> float:
	var has_t1: bool = is_instance_valid(target1)
	var has_t2: bool = is_instance_valid(target2)

	if has_t1 and has_t2:
		return (target1.global_position.x + target2.global_position.x) * 0.5
	elif has_t1:
		return target1.global_position.x
	elif has_t2:
		return target2.global_position.x
	return global_position.x

## Computes and applies clamped midpoint position while keeping zoom fixed at 1.0.
func update_camera() -> void:
	zoom = Vector2(1.0, 1.0)
	var mid_x: float = get_midpoint_x()
	var clamped_x: float = clamp(mid_x, min_x, max_x)
	global_position = Vector2(clamped_x, fixed_y)

## Returns the viewport boundary rectangle in world space.
## position is top-left corner, size is (viewport_width, viewport_height).
func get_view_bounds() -> Rect2:
	var left: float = global_position.x - (viewport_width * 0.5)
	var top: float = global_position.y - (viewport_height * 0.5)
	return Rect2(left, top, viewport_width, viewport_height)

func get_left_bound() -> float:
	return get_view_bounds().position.x

func get_right_bound() -> float:
	var bounds: Rect2 = get_view_bounds()
	return bounds.position.x + bounds.size.x
