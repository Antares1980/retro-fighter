class_name TestEngineFoundation
extends RefCounted

var passed: int = 0
var failed: int = 0

func assert_true(condition: bool, message: String) -> void:
	if condition:
		passed += 1
		print("  [PASS] %s" % message)
	else:
		failed += 1
		printerr("  [FAIL] %s" % message)

func assert_equal(actual, expected, message: String) -> void:
	if actual == expected:
		passed += 1
		print("  [PASS] %s (got expected: %s)" % [message, str(expected)])
	else:
		failed += 1
		printerr("  [FAIL] %s (expected: %s, got: %s)" % [message, str(expected), str(actual)])

func run_all() -> bool:
	print("\n=== Running Retro Fighter Engine Foundation Tests ===")
	test_display_and_viewport_settings()
	test_physics_and_timing_settings()
	test_rendering_settings()
	test_physics_layers()
	test_input_action_map_registration()
	test_p1_input_bindings()
	test_p2_input_bindings_and_fallbacks()
	test_debug_input_bindings()
	test_input_event_matching()
	test_main_scene_instantiation()

	print("\n=== Test Results: %d passed, %d failed ===" % [passed, failed])
	return failed == 0

func test_display_and_viewport_settings() -> void:
	print("\nScenario: Viewport & Display Configuration (AC-11)")
	var width = ProjectSettings.get_setting("display/window/size/viewport_width")
	var height = ProjectSettings.get_setting("display/window/size/viewport_height")
	var override_w = ProjectSettings.get_setting("display/window/size/window_width_override")
	var override_h = ProjectSettings.get_setting("display/window/size/window_height_override")
	var mode = ProjectSettings.get_setting("display/window/stretch/mode")
	var aspect = ProjectSettings.get_setting("display/window/stretch/aspect")

	assert_equal(width, 384, "Viewport width is 384")
	assert_equal(height, 224, "Viewport height is 224")
	assert_equal(override_w, 1152, "Window width override is 1152 (3x integer scale)")
	assert_equal(override_h, 672, "Window height override is 672 (3x integer scale)")
	assert_equal(mode, "viewport", "Stretch mode is 'viewport'")
	assert_equal(aspect, "keep", "Stretch aspect is 'keep'")

func test_physics_and_timing_settings() -> void:
	print("\nScenario: Fixed 60 Hz Physics Rate")
	var ticks = ProjectSettings.get_setting("physics/common/physics_ticks_per_second")
	assert_equal(ticks, 60, "Physics ticks per second is 60")

func test_rendering_settings() -> void:
	print("\nScenario: Pixel-Perfect Texture Filtering")
	var filter = ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")
	assert_equal(filter, 0, "Default texture filter is 0 (Nearest)")

func test_physics_layers() -> void:
	print("\nScenario: 2D Physics Layer Bitmask Names")
	assert_equal(ProjectSettings.get_setting("layer_names/2d_physics/layer_1"), "WorldFloor", "Layer 1 is WorldFloor")
	assert_equal(ProjectSettings.get_setting("layer_names/2d_physics/layer_2"), "FighterBody", "Layer 2 is FighterBody")
	assert_equal(ProjectSettings.get_setting("layer_names/2d_physics/layer_3"), "StageWall", "Layer 3 is StageWall")
	assert_equal(ProjectSettings.get_setting("layer_names/2d_physics/layer_4"), "P1_Hurtbox", "Layer 4 is P1_Hurtbox")
	assert_equal(ProjectSettings.get_setting("layer_names/2d_physics/layer_5"), "P1_Hitbox", "Layer 5 is P1_Hitbox")
	assert_equal(ProjectSettings.get_setting("layer_names/2d_physics/layer_6"), "P2_Hurtbox", "Layer 6 is P2_Hurtbox")
	assert_equal(ProjectSettings.get_setting("layer_names/2d_physics/layer_7"), "P2_Hitbox", "Layer 7 is P2_Hitbox")

func test_input_action_map_registration() -> void:
	print("\nScenario: Input Action Map Existence")
	var expected_actions = [
		"p1_left", "p1_right", "p1_up", "p1_down", "p1_punch", "p1_kick", "p1_block",
		"p2_left", "p2_right", "p2_up", "p2_down", "p2_punch", "p2_kick", "p2_block",
		"toggle_p2_dummy"
	]
	for action in expected_actions:
		assert_true(InputMap.has_action(action), "InputMap contains action '%s'" % action)

func _get_action_keys(action: String) -> Array[Key]:
	var keys: Array[Key] = []
	var events = InputMap.action_get_events(action)
	for event in events:
		if event is InputEventKey:
			if event.physical_keycode != KEY_NONE:
				keys.append(event.physical_keycode)
			elif event.keycode != KEY_NONE:
				keys.append(event.keycode)
	return keys

func test_p1_input_bindings() -> void:
	print("\nScenario: Player 1 Action Keybindings")
	var p1_expected = {
		"p1_left": [KEY_A],
		"p1_right": [KEY_D],
		"p1_up": [KEY_W],
		"p1_down": [KEY_S],
		"p1_punch": [KEY_J],
		"p1_kick": [KEY_K],
		"p1_block": [KEY_L]
	}
	for action in p1_expected:
		var keys = _get_action_keys(action)
		assert_equal(keys, p1_expected[action], "Action '%s' keys match %s" % [action, str(p1_expected[action])])

func test_p2_input_bindings_and_fallbacks() -> void:
	print("\nScenario: Player 2 Action Keybindings & Fallbacks")
	var p2_expected = {
		"p2_left": [KEY_LEFT],
		"p2_right": [KEY_RIGHT],
		"p2_up": [KEY_UP],
		"p2_down": [KEY_DOWN],
		"p2_punch": [KEY_KP_1, KEY_COMMA],
		"p2_kick": [KEY_KP_2, KEY_PERIOD],
		"p2_block": [KEY_KP_0, KEY_SLASH]
	}
	for action in p2_expected:
		var keys = _get_action_keys(action)
		assert_equal(keys, p2_expected[action], "Action '%s' keys match %s" % [action, str(p2_expected[action])])

func test_debug_input_bindings() -> void:
	print("\nScenario: Debug Action Keybindings (AC-10)")
	var keys = _get_action_keys("toggle_p2_dummy")
	assert_equal(keys, [KEY_F1], "Action 'toggle_p2_dummy' is bound to KEY_F1")

func test_input_event_matching() -> void:
	print("\nScenario: Input Event Simulation & Fallback Resolution")
	# P1 Punch
	var ev_punch = InputEventKey.new()
	ev_punch.physical_keycode = KEY_J
	assert_true(InputMap.event_is_action(ev_punch, "p1_punch"), "KEY_J triggers p1_punch")

	# P2 Punch Primary
	var ev_p2_punch1 = InputEventKey.new()
	ev_p2_punch1.physical_keycode = KEY_KP_1
	assert_true(InputMap.event_is_action(ev_p2_punch1, "p2_punch"), "KEY_KP_1 triggers p2_punch")

	# P2 Punch Fallback
	var ev_p2_punch2 = InputEventKey.new()
	ev_p2_punch2.physical_keycode = KEY_COMMA
	assert_true(InputMap.event_is_action(ev_p2_punch2, "p2_punch"), "KEY_COMMA triggers p2_punch")

	# P2 Kick Primary & Fallback
	var ev_p2_kick1 = InputEventKey.new()
	ev_p2_kick1.physical_keycode = KEY_KP_2
	assert_true(InputMap.event_is_action(ev_p2_kick1, "p2_kick"), "KEY_KP_2 triggers p2_kick")

	var ev_p2_kick2 = InputEventKey.new()
	ev_p2_kick2.physical_keycode = KEY_PERIOD
	assert_true(InputMap.event_is_action(ev_p2_kick2, "p2_kick"), "KEY_PERIOD triggers p2_kick")

	# P2 Block Primary & Fallback
	var ev_p2_block1 = InputEventKey.new()
	ev_p2_block1.physical_keycode = KEY_KP_0
	assert_true(InputMap.event_is_action(ev_p2_block1, "p2_block"), "KEY_KP_0 triggers p2_block")

	var ev_p2_block2 = InputEventKey.new()
	ev_p2_block2.physical_keycode = KEY_SLASH
	assert_true(InputMap.event_is_action(ev_p2_block2, "p2_block"), "KEY_SLASH triggers p2_block")

	# Debug Toggle
	var ev_f1 = InputEventKey.new()
	ev_f1.physical_keycode = KEY_F1
	assert_true(InputMap.event_is_action(ev_f1, "toggle_p2_dummy"), "KEY_F1 triggers toggle_p2_dummy")

	# Non-matching check
	var ev_space = InputEventKey.new()
	ev_space.physical_keycode = KEY_SPACE
	assert_true(not InputMap.event_is_action(ev_space, "p1_punch"), "KEY_SPACE does NOT trigger p1_punch")

func test_main_scene_instantiation() -> void:
	print("\nScenario: Main Scene Load and Instantiation (AC-11)")
	var main_scene_path = ProjectSettings.get_setting("application/run/main_scene")
	assert_equal(main_scene_path, "res://scenes/Main.tscn", "Main scene setting is res://scenes/Main.tscn")
	assert_true(ResourceLoader.exists(main_scene_path), "Main scene file exists")
	var scene = load(main_scene_path) as PackedScene
	assert_true(scene != null, "Main scene can be loaded as PackedScene")
	if scene != null:
		var instance = scene.instantiate()
		assert_true(instance != null, "Main scene can be instantiated")
		if instance != null:
			instance.free()
