class_name TestCamera
extends RefCounted

## Unit and integration tests for Dynamic Fight Camera (scenes/Camera2D.tscn and scripts/DynamicFightCamera.gd).
## Verifies fixed zoom 1.0, midpoint framing, camera clamping [192, 408],
## get_view_bounds() calculation, and AC-06 fighter boundary clamping.

const CameraScene = preload("res://scenes/Camera2D.tscn")
const CameraScript = preload("res://scripts/DynamicFightCamera.gd")
const FighterScene = preload("res://scenes/Fighter.tscn")
const FighterScript = preload("res://scripts/Fighter.gd")

var passed: int = 0
var failed: int = 0

func assert_true(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  [PASS] %s" % message)
	else:
		failed += 1
		printerr("  [FAIL] %s" % message)

func assert_false(condition: bool, message: String) -> void:
	assert_true(not condition, message)

func assert_equal(actual, expected, message: String) -> void:
	var matches: bool = false
	if (typeof(actual) == TYPE_FLOAT or typeof(actual) == TYPE_INT) and (typeof(expected) == TYPE_FLOAT or typeof(expected) == TYPE_INT) and (typeof(actual) == TYPE_FLOAT or typeof(expected) == TYPE_FLOAT):
		matches = is_equal_approx(float(actual), float(expected))
	elif actual is Vector2 and expected is Vector2:
		matches = (actual as Vector2).is_equal_approx(expected as Vector2)
	elif actual is Color and expected is Color:
		matches = (actual as Color).is_equal_approx(expected as Color)
	else:
		matches = (actual == expected)

	if matches:
		passed += 1
		print("  [PASS] %s (got expected: %s)" % [message, str(expected)])
	else:
		failed += 1
		printerr("  [FAIL] %s (expected: %s, got: %s)" % [message, str(expected), str(actual)])

func run_all() -> bool:
	print("\n=== Running Retro Fighter Dynamic Camera Tests ===")
	test_scene_and_script_instantiation()
	test_camera_constants()
	test_fixed_zoom()
	test_midpoint_framing()
	test_camera_boundary_clamping()
	test_view_bounds_rect()
	test_automatic_target_resolution()
	test_single_target_fallback()
	test_ac06_fighter_camera_clamping_integration()

	print("\n=== Camera Test Results: %d passed, %d failed ===" % [passed, failed])
	return failed == 0

func test_scene_and_script_instantiation() -> void:
	print("\nScenario: Scene and Script Instantiation")
	var cam_node = CameraScene.instantiate()
	assert_true(cam_node != null, "scenes/Camera2D.tscn instantiates successfully")
	assert_true(cam_node is Camera2D, "Camera node inherits Camera2D")
	assert_true(cam_node.get_script() == CameraScript, "Camera node has DynamicFightCamera script")
	assert_equal(cam_node.position, Vector2(300.0, 112.0), "Initial camera scene position is (300, 112)")
	cam_node.free()

func test_camera_constants() -> void:
	print("\nScenario: Dynamic Camera Constants")
	assert_equal(CameraScript.VIEWPORT_WIDTH, 384.0, "Viewport width is 384.0 px")
	assert_equal(CameraScript.VIEWPORT_HEIGHT, 224.0, "Viewport height is 224.0 px")
	assert_equal(CameraScript.MIN_CAMERA_X, 192.0, "Min camera X is 192.0 px")
	assert_equal(CameraScript.MAX_CAMERA_X, 408.0, "Max camera X is 408.0 px")
	assert_equal(CameraScript.FIXED_Y, 112.0, "Fixed Y position is 112.0 px")
	assert_equal(CameraScript.MIN_X, 192.0, "Min X constant alias is 192.0 px")
	assert_equal(CameraScript.MAX_X, 408.0, "Max X constant alias is 408.0 px")

func test_fixed_zoom() -> void:
	print("\nScenario: Fixed Zoom 1.0 (Pan Only)")
	var cam = CameraScript.new()
	assert_equal(cam.zoom, Vector2(1.0, 1.0), "Initial camera zoom is (1.0, 1.0)")

	# Attempt to mutate zoom, update_camera should re-enforce 1.0
	cam.zoom = Vector2(2.0, 2.0)
	cam.update_camera()
	assert_equal(cam.zoom, Vector2(1.0, 1.0), "Camera zoom is strictly fixed at (1.0, 1.0)")
	cam.free()

func test_midpoint_framing() -> void:
	print("\nScenario: Midpoint Framing Between Fighters")
	var cam = CameraScript.new()
	var t1 = Node2D.new()
	var t2 = Node2D.new()

	t1.global_position = Vector2(200.0, 190.0)
	t2.global_position = Vector2(400.0, 190.0)

	cam.set_targets(t1, t2)
	assert_equal(cam.global_position.x, 300.0, "Camera frames midpoint at X=300 for targets at 200 and 400")
	assert_equal(cam.global_position.y, 112.0, "Camera Y remains fixed at 112.0")

	# Move fighters asymmetrically
	t1.global_position.x = 260.0
	t2.global_position.x = 380.0
	cam.update_camera()
	assert_equal(cam.global_position.x, 320.0, "Camera frames midpoint at X=320 for targets at 260 and 380")

	t1.global_position.x = 220.0
	t2.global_position.x = 340.0
	cam.update_camera()
	assert_equal(cam.global_position.x, 280.0, "Camera frames midpoint at X=280 for targets at 220 and 340")

	cam.free()
	t1.free()
	t2.free()

func test_camera_boundary_clamping() -> void:
	print("\nScenario: Camera Clamping Between X=192 and X=408")
	var cam = CameraScript.new()
	var t1 = Node2D.new()
	var t2 = Node2D.new()
	cam.set_targets(t1, t2)

	# Left clamp test: midpoint = (50 + 150) / 2 = 100 < 192
	t1.global_position.x = 50.0
	t2.global_position.x = 150.0
	cam.update_camera()
	assert_equal(cam.global_position.x, 192.0, "Camera clamped to MIN_CAMERA_X (192.0) when midpoint is 100")

	# Extreme left: midpoint = (16 + 80) / 2 = 48 < 192
	t1.global_position.x = 16.0
	t2.global_position.x = 80.0
	cam.update_camera()
	assert_equal(cam.global_position.x, 192.0, "Camera clamped to MIN_CAMERA_X (192.0) when fighters at stage left")

	# Right clamp test: midpoint = (450 + 550) / 2 = 500 > 408
	t1.global_position.x = 450.0
	t2.global_position.x = 550.0
	cam.update_camera()
	assert_equal(cam.global_position.x, 408.0, "Camera clamped to MAX_CAMERA_X (408.0) when midpoint is 500")

	# Extreme right: midpoint = (520 + 584) / 2 = 552 > 408
	t1.global_position.x = 520.0
	t2.global_position.x = 584.0
	cam.update_camera()
	assert_equal(cam.global_position.x, 408.0, "Camera clamped to MAX_CAMERA_X (408.0) when fighters at stage right")

	cam.free()
	t1.free()
	t2.free()

func test_view_bounds_rect() -> void:
	print("\nScenario: View Bounds Rect2 and Bound Helpers")
	var cam = CameraScript.new()

	# Center at 300
	cam.global_position = Vector2(300.0, 112.0)
	var bounds_center: Rect2 = cam.get_view_bounds()
	assert_equal(bounds_center.position.x, 108.0, "Center view bounds left is 108.0 (300 - 192)")
	assert_equal(bounds_center.position.y, 0.0, "Center view bounds top is 0.0 (112 - 112)")
	assert_equal(bounds_center.size.x, 384.0, "View bounds width is 384.0")
	assert_equal(bounds_center.size.y, 224.0, "View bounds height is 224.0")
	assert_equal(cam.get_left_bound(), 108.0, "cam.get_left_bound() is 108.0")
	assert_equal(cam.get_right_bound(), 492.0, "cam.get_right_bound() is 492.0")
	assert_equal(cam.left_bound, 108.0, "cam.left_bound getter is 108.0")
	assert_equal(cam.right_bound, 492.0, "cam.right_bound getter is 492.0")

	# Left edge clamp at 192
	cam.global_position = Vector2(192.0, 112.0)
	var bounds_left: Rect2 = cam.get_view_bounds()
	assert_equal(bounds_left.position.x, 0.0, "Left clamped view bounds left is 0.0 (192 - 192)")
	assert_equal(cam.get_right_bound(), 384.0, "Left clamped view bounds right is 384.0")

	# Right edge clamp at 408
	cam.global_position = Vector2(408.0, 112.0)
	var bounds_right: Rect2 = cam.get_view_bounds()
	assert_equal(bounds_right.position.x, 216.0, "Right clamped view bounds left is 216.0 (408 - 192)")
	assert_equal(cam.get_right_bound(), 600.0, "Right clamped view bounds right is 600.0 (stage max width)")

	cam.free()

func test_automatic_target_resolution() -> void:
	print("\nScenario: Automatic Target Resolution from Parent Node")
	var root = Node2D.new()
	var p1 = FighterScene.instantiate()
	var p2 = FighterScene.instantiate()
	var cam = CameraScene.instantiate()

	p1.setup(1)
	p2.setup(2)

	root.add_child(p1)
	root.add_child(p2)
	root.add_child(cam)

	cam.find_targets()
	assert_equal(cam.target1, p1, "Camera automatically found P1 as target1")
	assert_equal(cam.target2, p2, "Camera automatically found P2 as target2")
	assert_equal(cam.fighter1, p1, "fighter1 alias returns P1")
	assert_equal(cam.fighter2, p2, "fighter2 alias returns P2")

	root.free()

func test_single_target_fallback() -> void:
	print("\nScenario: Single Target Fallback")
	var cam = CameraScript.new()
	var t1 = Node2D.new()
	t1.global_position = Vector2(350.0, 190.0)

	cam.target1 = t1
	cam.target2 = null
	cam.update_camera()

	assert_equal(cam.global_position.x, 350.0, "Camera follows single target at X=350")

	t1.global_position.x = 100.0
	cam.update_camera()
	assert_equal(cam.global_position.x, 192.0, "Camera clamps single target to min_x=192")

	cam.free()
	t1.free()

func test_ac06_fighter_camera_clamping_integration() -> void:
	print("\nScenario: AC-06 - Dynamic Camera & Fighter Viewport Boundary Clamping Integration")
	var root = Node2D.new()
	var p1 = FighterScene.instantiate()
	var p2 = FighterScene.instantiate()
	var cam = CameraScene.instantiate()

	root.add_child(cam)
	root.add_child(p1)
	root.add_child(p2)

	p1.setup(1)
	p2.setup(2)

	# Establish maximum allowable distance within 384 px viewport:
	# Camera centered at X=300 -> view bounds [108, 492]
	# P1 at left bound + 16 = 124.0
	# P2 at right bound - 16 = 476.0
	# Span: 476 - 124 = 352 px (exact viewport width 384 - 32 margin)
	p1.global_position = Vector2(124.0, 190.0)
	p2.global_position = Vector2(476.0, 190.0)

	cam.set_targets(p1, p2)
	assert_equal(cam.global_position.x, 300.0, "Camera centered at midpoint X=300.0")
	assert_equal(cam.left_bound, 108.0, "Camera left bound is 108.0")
	assert_equal(cam.right_bound, 492.0, "Camera right bound is 492.0")

	# P1 attempts to walk further backward (left, towards negative X)
	p1.global_position.x = 100.0 # Attempted off-screen position
	p1._apply_clamping()
	assert_equal(p1.global_position.x, 124.0, "P1 position clamped to camera left + 16 (124.0) - cannot walk off-screen")

	# P2 attempts to walk further backward (right, towards positive X)
	p2.global_position.x = 510.0 # Attempted off-screen position
	p2._apply_clamping()
	assert_equal(p2.global_position.x, 476.0, "P2 position clamped to camera right - 16 (476.0) - cannot walk off-screen")

	# Stage left wall interaction:
	# Fighters shift to the left: P1 at stage minimum (16.0), P2 at 368.0
	# Midpoint is (16 + 368) / 2 = 192.0 -> camera clamped to 192.0
	p1.global_position = Vector2(16.0, 190.0)
	p2.global_position = Vector2(368.0, 190.0)
	cam.update_camera()

	assert_equal(cam.global_position.x, 192.0, "Camera at left limit 192.0")
	assert_equal(cam.left_bound, 0.0, "Camera view left aligned with stage origin 0.0")

	p1.global_position.x = 5.0 # Tries to cross stage boundary
	p1._apply_clamping()
	assert_equal(p1.global_position.x, 16.0, "P1 clamped at stage min X (16.0)")

	# Stage right wall interaction:
	# Fighters shift to the right: P1 at 232.0, P2 at stage maximum (584.0)
	# Midpoint is (232 + 584) / 2 = 408.0 -> camera clamped to 408.0
	p1.global_position = Vector2(232.0, 190.0)
	p2.global_position = Vector2(584.0, 190.0)
	cam.update_camera()

	assert_equal(cam.global_position.x, 408.0, "Camera at right limit 408.0")
	assert_equal(cam.right_bound, 600.0, "Camera view right aligned with stage max 600.0")

	p2.global_position.x = 610.0 # Tries to cross stage boundary
	p2._apply_clamping()
	assert_equal(p2.global_position.x, 584.0, "P2 clamped at stage max X (584.0)")

	root.free()
