class_name TestMenu
extends RefCounted

## Automated Test Suite for Arcade Hub Launcher & Game Selection Menu.
## Validates Menu scene layout, button navigation, signals, audio playback,
## out-of-tree execution safety, and in-game return to menu across all match states.

const MenuScene = preload("res://scenes/Menu.tscn")
const MenuScript = preload("res://scripts/Menu.gd")
const MainScene = preload("res://scenes/Main.tscn")
const MainScript = preload("res://scripts/Main.gd")

var passed: int = 0
var failed: int = 0
var tree: SceneTree = null

func _init(p_tree: SceneTree = null) -> void:
	if p_tree != null:
		tree = p_tree
	elif Engine.get_main_loop() is SceneTree:
		tree = Engine.get_main_loop() as SceneTree

func _get_tree() -> SceneTree:
	if tree != null:
		return tree
	if Engine.get_main_loop() is SceneTree:
		tree = Engine.get_main_loop() as SceneTree
		return tree
	return null

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
	if (typeof(actual) == TYPE_FLOAT or typeof(actual) == TYPE_INT) and (typeof(expected) == TYPE_FLOAT or typeof(expected) == TYPE_INT):
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

func run_all(p_tree: SceneTree = null) -> bool:
	if p_tree != null:
		tree = p_tree
	elif tree == null:
		tree = _get_tree()

	print("\n=== Running Arcade Hub Launcher & Menu Tests ===")
	test_scenario_1_default_boot_to_arcade_menu_hub()
	test_scenario_2_launching_retro_fighter_from_menu()
	test_scenario_3_returning_from_retro_fighter_to_menu()
	test_scenario_4_placeholder_slot_integrity_and_navigation()
	test_scenario_5_out_of_tree_execution_and_clean_bypass()

	print("\n=== Menu Test Results: %d passed, %d failed ===" % [passed, failed])
	return failed == 0

func test_scenario_1_default_boot_to_arcade_menu_hub() -> void:
	print("\nScenario 1: Default Boot to Arcade Menu Hub")
	var main_scene_setting = ProjectSettings.get_setting("application/run/main_scene")
	assert_equal(main_scene_setting, "res://scenes/Menu.tscn", "run/main_scene is res://scenes/Menu.tscn")

	var menu = MenuScene.instantiate()
	assert_true(menu != null, "scenes/Menu.tscn instantiates cleanly")
	assert_true(menu is Control, "Menu root is Control")
	assert_equal(menu.custom_minimum_size, Vector2(384, 224), "Menu custom_minimum_size is 384x224")

	assert_true(menu.has_node("VBoxContainer"), "Menu contains VBoxContainer")
	assert_true(menu.has_node("VBoxContainer/RetroFighterButton"), "Menu contains RetroFighterButton")
	assert_true(menu.has_node("VBoxContainer/ComingSoonButton"), "Menu contains ComingSoonButton")
	assert_true(menu.has_node("VBoxContainer/QuitButton"), "Menu contains QuitButton")

	var btn_rf = menu.get_node("VBoxContainer/RetroFighterButton") as Button
	var btn_cs = menu.get_node("VBoxContainer/ComingSoonButton") as Button
	var btn_q = menu.get_node("VBoxContainer/QuitButton") as Button

	assert_equal(btn_rf.text, "1. RETRO FIGHTER", "Option 1 text is '1. RETRO FIGHTER'")
	assert_equal(btn_cs.text, "2. MOB CONTROL 3D", "Slot 2 text is '2. MOB CONTROL 3D'")
	assert_equal(btn_q.text, "3. QUIT", "Option 3 text is '3. QUIT'")

	assert_equal(ProjectSettings.get_setting("display/window/size/viewport_width"), 384, "display/window/size/viewport_width is 384")
	assert_equal(ProjectSettings.get_setting("display/window/size/viewport_height"), 224, "display/window/size/viewport_height is 224")
	assert_equal(ProjectSettings.get_setting("display/window/stretch/mode"), "viewport", "display/window/stretch/mode is viewport")
	assert_equal(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep", "display/window/stretch/aspect is keep")

	assert_true(menu.has_node("BGMPlayer"), "Menu contains BGMPlayer node")
	var bgm = menu.get_node("BGMPlayer") as AudioStreamPlayer
	assert_true(bgm != null, "BGMPlayer is an AudioStreamPlayer")
	assert_equal(bgm.bus, &"Music", "BGMPlayer is assigned to 'Music' bus")
	assert_false(bgm.autoplay, "BGMPlayer autoplay is false")
	assert_true(bgm.stream != null, "BGMPlayer has stream assigned")
	if bgm.stream != null:
		assert_true(bgm.stream.resource_path.ends_with("stage_theme.ogg"), "BGMPlayer assigned stage_theme.ogg")

	# Node aliases contract
	assert_equal(menu.RetroFighterButton, btn_rf, "menu.RetroFighterButton alias matches node")
	assert_equal(menu.ComingSoonButton, btn_cs, "menu.ComingSoonButton alias matches node")
	assert_equal(menu.QuitButton, btn_q, "menu.QuitButton alias matches node")
	assert_equal(menu.BGMPlayer, bgm, "menu.BGMPlayer alias matches node")

	var active_tree = _get_tree()
	if active_tree != null:
		active_tree.root.add_child(menu)
		assert_true(menu.is_inside_tree(), "Menu is added to scene tree")
		assert_true(menu.bgm_player.playing, "BGMPlayer plays stage_theme.ogg when added to scene tree")
		menu.bgm_player.stop()

		var vbox = menu.get_node("VBoxContainer") as VBoxContainer
		vbox.notification(Container.NOTIFICATION_SORT_CHILDREN)
		var viewport_rect = Rect2(0, 0, 384, 224)
		var title_node = menu.get_node("Title") as Control
		var title_rect = title_node.get_global_rect()
		var rf_rect = btn_rf.get_global_rect()
		var cs_rect = btn_cs.get_global_rect()
		var q_rect = btn_q.get_global_rect()

		assert_true(viewport_rect.encloses(title_rect), "Title is fully enclosed in 384x224 logical viewport")
		assert_true(viewport_rect.encloses(rf_rect), "RetroFighterButton is fully enclosed in 384x224 logical viewport")
		assert_true(viewport_rect.encloses(cs_rect), "ComingSoonButton is fully enclosed in 384x224 logical viewport")
		assert_true(viewport_rect.encloses(q_rect), "QuitButton is fully enclosed in 384x224 logical viewport")

		assert_false(title_rect.intersects(rf_rect), "Title does not overlap RetroFighterButton")
		assert_false(title_rect.intersects(cs_rect), "Title does not overlap ComingSoonButton")
		assert_false(title_rect.intersects(q_rect), "Title does not overlap QuitButton")
		assert_false(rf_rect.intersects(cs_rect), "RetroFighterButton does not overlap ComingSoonButton")
		assert_false(rf_rect.intersects(q_rect), "RetroFighterButton does not overlap QuitButton")
		assert_false(cs_rect.intersects(q_rect), "ComingSoonButton does not overlap QuitButton")

		active_tree.root.remove_child(menu)

	menu.free()

func test_scenario_2_launching_retro_fighter_from_menu() -> void:
	print("\nScenario 2: Launching Retro Fighter from Menu")
	var active_tree = _get_tree()
	if active_tree == null:
		printerr("SceneTree not available for Scenario 2")
		return

	# Subtest 2a: Selection via p1_punch
	var menu1 = MenuScene.instantiate()
	active_tree.root.add_child(menu1)
	assert_true(menu1.btn_retro_fighter.has_focus(), "Initial focus is placed on btn_retro_fighter")

	var emitted_punch: Array = []
	menu1.game_selected.connect(func(path: String): emitted_punch.append(path))

	var ev_punch = InputEventAction.new()
	ev_punch.action = "p1_punch"
	ev_punch.pressed = true
	menu1._unhandled_input(ev_punch)

	assert_equal(emitted_punch.size(), 1, "p1_punch emits game_selected once")
	if emitted_punch.size() > 0:
		assert_equal(emitted_punch[0], "res://scenes/Main.tscn", "p1_punch emits game_selected('res://scenes/Main.tscn')")
	active_tree.root.remove_child(menu1)
	menu1.free()

	# Subtest 2b: Selection via ui_accept
	var menu2 = MenuScene.instantiate()
	active_tree.root.add_child(menu2)
	assert_true(menu2.btn_retro_fighter.has_focus(), "Initial focus is placed on btn_retro_fighter")

	var emitted_accept: Array = []
	menu2.game_selected.connect(func(path: String): emitted_accept.append(path))

	var ev_accept = InputEventAction.new()
	ev_accept.action = "ui_accept"
	ev_accept.pressed = true
	menu2._unhandled_input(ev_accept)

	assert_equal(emitted_accept.size(), 1, "ui_accept emits game_selected once")
	if emitted_accept.size() > 0:
		assert_equal(emitted_accept[0], "res://scenes/Main.tscn", "ui_accept emits game_selected('res://scenes/Main.tscn')")
	active_tree.root.remove_child(menu2)
	menu2.free()

	# Subtest 2c: Selection via mouse click (pressed signal) for all three buttons (AC2)
	var menu3 = MenuScene.instantiate()
	active_tree.root.add_child(menu3)
	var emitted_click: Array = []
	var quit_emitted: Array = []
	menu3.game_selected.connect(func(path: String): emitted_click.append(path))
	menu3.quit_requested.connect(func(): quit_emitted.append(true))

	# Click RetroFighterButton
	menu3.btn_retro_fighter.pressed.emit()
	assert_equal(emitted_click.size(), 1, "Mouse click on RetroFighterButton emits game_selected once")
	if emitted_click.size() > 0:
		assert_equal(emitted_click[0], "res://scenes/Main.tscn", "Mouse click emits game_selected('res://scenes/Main.tscn')")
	active_tree.root.remove_child(menu3)
	menu3.free()

	# Click ComingSoonButton
	var menu3_cs = MenuScene.instantiate()
	active_tree.root.add_child(menu3_cs)
	var emitted_click_cs: Array = []
	menu3_cs.game_selected.connect(func(path: String): emitted_click_cs.append(path))
	menu3_cs.btn_coming_soon.pressed.emit()
	assert_equal(emitted_click_cs.size(), 1, "Mouse click on ComingSoonButton emits game_selected once")
	if emitted_click_cs.size() > 0:
		assert_equal(emitted_click_cs[0], "res://scenes/mob_control/MobControlMain.tscn", "Mouse click emits game_selected('res://scenes/mob_control/MobControlMain.tscn')")
	active_tree.root.remove_child(menu3_cs)
	menu3_cs.free()

	# Click QuitButton
	var menu3_q = MenuScene.instantiate()
	active_tree.root.add_child(menu3_q)
	var emitted_click_q: Array = []
	menu3_q.quit_requested.connect(func(): emitted_click_q.append(true))
	menu3_q.btn_quit.pressed.emit()
	assert_equal(emitted_click_q.size(), 1, "Mouse click on QuitButton emits quit_requested once")
	active_tree.root.remove_child(menu3_q)
	menu3_q.free()

	# Subtest 2d: Target Main.tscn initialization & BGM contract
	var main = MainScene.instantiate()
	active_tree.root.add_child(main)
	assert_equal(main.match_state, MainScript.MatchState.ROUND_INTRO, "Main.tscn initializes into ROUND_INTRO")
	assert_true(main.bgm_player.stream.resource_path.ends_with("retro-fighter.ogg"), "Main.tscn assigned retro-fighter.ogg")
	assert_true(main.bgm_player.playing, "Main BGMPlayer is playing during ROUND_INTRO")

	main.step(1.5)
	assert_equal(main.match_state, MainScript.MatchState.IN_ROUND, "Main transitioned to IN_ROUND")
	assert_true(main.bgm_player.playing, "Main BGMPlayer is playing in IN_ROUND")

	main.bgm_player.stop()
	active_tree.root.remove_child(main)
	main.free()

func test_scenario_3_returning_from_retro_fighter_to_menu() -> void:
	print("\nScenario 3: Returning from Retro Fighter to Menu Across Match States")
	var active_tree = _get_tree()
	if active_tree == null:
		printerr("SceneTree not available for Scenario 3")
		return

	var states = [
		{"state": MainScript.MatchState.ROUND_INTRO, "name": "ROUND_INTRO"},
		{"state": MainScript.MatchState.IN_ROUND, "name": "IN_ROUND"},
		{"state": MainScript.MatchState.ROUND_OVER, "name": "ROUND_OVER"},
		{"state": MainScript.MatchState.RESET, "name": "RESET"}
	]

	for item in states:
		var target_state = item["state"]
		var state_name = item["name"]

		var main = MainScene.instantiate()
		active_tree.root.add_child(main)

		if target_state == MainScript.MatchState.RESET:
			main.match_state = MainScript.MatchState.RESET
		else:
			main.change_match_state(target_state, true)
		assert_equal(main.match_state, target_state, "Main set to state %s" % state_name)

		# Ensure bgm_player is playing before test
		if is_instance_valid(main.bgm_player) and not main.bgm_player.playing:
			main.bgm_player.play()

		var return_emitted: Array = []
		main.return_to_menu_requested.connect(func(): return_emitted.append(true))

		var ev_cancel = InputEventAction.new()
		ev_cancel.action = "ui_cancel"
		ev_cancel.pressed = true

		# First press: triggers return hook
		main._unhandled_input(ev_cancel)
		assert_equal(return_emitted.size(), 1, "[%s] return_to_menu_requested emitted exactly once" % state_name)
		assert_false(main.bgm_player.playing, "[%s] bgm_player stopped immediately" % state_name)
		assert_true(main._returning_to_menu, "[%s] _returning_to_menu guard flag is true" % state_name)

		# Repeated press: one-shot guard blocks further transitions/emissions
		main._unhandled_input(ev_cancel)
		assert_equal(return_emitted.size(), 1, "[%s] One-shot guard prevents multiple return_to_menu_requested emissions" % state_name)

		active_tree.root.remove_child(main)
		main.free()

func test_scenario_4_placeholder_slot_integrity_and_navigation() -> void:
	print("\nScenario 4: Slot 2 Mob Control 3D Navigation & Activation")
	var active_tree = _get_tree()
	if active_tree == null:
		printerr("SceneTree not available for Scenario 4")
		return

	var menu = MenuScene.instantiate()
	active_tree.root.add_child(menu)

	# Verify ComingSoon properties (now enabled for Mob Control 3D)
	assert_false(menu.ComingSoonButton.disabled, "ComingSoonButton.disabled == false")
	assert_equal(menu.ComingSoonButton.focus_mode, Control.FOCUS_ALL, "ComingSoonButton.focus_mode == Control.FOCUS_ALL")

	# Initial focus on Retro Fighter
	assert_true(menu.btn_retro_fighter.has_focus(), "Retro Fighter button has initial focus")

	# Navigate down via p1_down
	var ev_down = InputEventAction.new()
	ev_down.action = "p1_down"
	ev_down.pressed = true

	menu._unhandled_input(ev_down)
	assert_true(menu.ComingSoonButton.has_focus(), "p1_down moves focus to ComingSoonButton")

	menu._unhandled_input(ev_down)
	assert_true(menu.btn_quit.has_focus(), "p1_down moves focus to QuitButton")

	menu._unhandled_input(ev_down)
	assert_true(menu.btn_retro_fighter.has_focus(), "p1_down cycles back to RetroFighterButton")

	# Navigate up via p1_up
	var ev_up = InputEventAction.new()
	ev_up.action = "p1_up"
	ev_up.pressed = true

	menu._unhandled_input(ev_up)
	assert_true(menu.btn_quit.has_focus(), "p1_up cycles back to QuitButton")

	menu._unhandled_input(ev_up)
	assert_true(menu.ComingSoonButton.has_focus(), "p1_up moves focus to ComingSoonButton")

	menu._unhandled_input(ev_up)
	assert_true(menu.btn_retro_fighter.has_focus(), "p1_up returns focus to RetroFighterButton")

	# Navigate down via ui_down
	var ev_ui_down = InputEventAction.new()
	ev_ui_down.action = "ui_down"
	ev_ui_down.pressed = true

	menu._unhandled_input(ev_ui_down)
	assert_true(menu.ComingSoonButton.has_focus(), "ui_down moves focus to ComingSoonButton")

	menu._unhandled_input(ev_ui_down)
	assert_true(menu.btn_quit.has_focus(), "ui_down moves focus to QuitButton")

	menu._unhandled_input(ev_ui_down)
	assert_true(menu.btn_retro_fighter.has_focus(), "ui_down cycles back to RetroFighterButton")

	# Navigate up via ui_up
	var ev_ui_up = InputEventAction.new()
	ev_ui_up.action = "ui_up"
	ev_ui_up.pressed = true

	menu._unhandled_input(ev_ui_up)
	assert_true(menu.btn_quit.has_focus(), "ui_up cycles back to QuitButton")

	menu._unhandled_input(ev_ui_up)
	assert_true(menu.ComingSoonButton.has_focus(), "ui_up moves focus to ComingSoonButton")

	menu._unhandled_input(ev_ui_up)
	assert_true(menu.btn_retro_fighter.has_focus(), "ui_up returns focus to RetroFighterButton")

	# Activating ComingSoonButton emits game_selected with MobControlMain.tscn
	var game_emitted: Array = []
	menu.game_selected.connect(func(p: String): game_emitted.append(p))

	# Focus ComingSoonButton and trigger p1_punch
	menu.ComingSoonButton.grab_focus()
	assert_true(menu.ComingSoonButton.has_focus(), "ComingSoonButton has focus before activation")

	var ev_punch = InputEventAction.new()
	ev_punch.action = "p1_punch"
	ev_punch.pressed = true
	menu._unhandled_input(ev_punch)

	assert_equal(game_emitted.size(), 1, "ComingSoonButton activation via p1_punch emits game_selected once")
	if game_emitted.size() > 0:
		assert_equal(game_emitted[0], "res://scenes/mob_control/MobControlMain.tscn", "game_selected emitted with MobControlMain.tscn")

	active_tree.root.remove_child(menu)
	menu.free()

	# Activating ComingSoonButton via ui_accept
	var menu_cs_acc = MenuScene.instantiate()
	active_tree.root.add_child(menu_cs_acc)
	var emitted_cs_acc: Array = []
	menu_cs_acc.game_selected.connect(func(p: String): emitted_cs_acc.append(p))
	menu_cs_acc.ComingSoonButton.grab_focus()
	var ev_cs_acc = InputEventAction.new()
	ev_cs_acc.action = "ui_accept"
	ev_cs_acc.pressed = true
	menu_cs_acc._unhandled_input(ev_cs_acc)
	assert_equal(emitted_cs_acc.size(), 1, "ComingSoonButton activation via ui_accept emits game_selected once")
	if emitted_cs_acc.size() > 0:
		assert_equal(emitted_cs_acc[0], "res://scenes/mob_control/MobControlMain.tscn", "game_selected emitted with MobControlMain.tscn")
	active_tree.root.remove_child(menu_cs_acc)
	menu_cs_acc.free()

	# Activating QuitButton via p1_punch and ui_accept
	var menu_q_act = MenuScene.instantiate()
	active_tree.root.add_child(menu_q_act)
	var quit_act_emitted: Array = []
	menu_q_act.quit_requested.connect(func(): quit_act_emitted.append(true))
	menu_q_act.QuitButton.grab_focus()
	assert_true(menu_q_act.QuitButton.has_focus(), "QuitButton has focus before activation")
	var ev_q_punch = InputEventAction.new()
	ev_q_punch.action = "p1_punch"
	ev_q_punch.pressed = true
	menu_q_act._unhandled_input(ev_q_punch)
	assert_equal(quit_act_emitted.size(), 1, "QuitButton activation via p1_punch emits quit_requested once")
	active_tree.root.remove_child(menu_q_act)
	menu_q_act.free()

	var menu_q_acc = MenuScene.instantiate()
	active_tree.root.add_child(menu_q_acc)
	var quit_acc_emitted: Array = []
	menu_q_acc.quit_requested.connect(func(): quit_acc_emitted.append(true))
	menu_q_acc.QuitButton.grab_focus()
	var ev_q_acc = InputEventAction.new()
	ev_q_acc.action = "ui_accept"
	ev_q_acc.pressed = true
	menu_q_acc._unhandled_input(ev_q_acc)
	assert_equal(quit_acc_emitted.size(), 1, "QuitButton activation via ui_accept emits quit_requested once")
	active_tree.root.remove_child(menu_q_acc)
	menu_q_acc.free()

func test_scenario_5_out_of_tree_execution_and_clean_bypass() -> void:
	print("\nScenario 5: Out-of-tree Execution & Clean Bypass")

	# Out-of-tree launch_game cleanly bypasses change_scene_to_file
	var menu_out_launch = MenuScene.instantiate()
	assert_false(menu_out_launch.is_inside_tree(), "menu_out_launch is strictly outside scene tree")

	var launch_result: Array = []
	menu_out_launch.game_selected.connect(func(p: String): launch_result.append(p))
	menu_out_launch.launch_game("res://scenes/Main.tscn")

	assert_equal(launch_result.size(), 1, "launch_game emits game_selected once")
	if launch_result.size() > 0:
		assert_equal(launch_result[0], "res://scenes/Main.tscn", "launch_game emits game_selected out-of-tree without crashes")
	assert_true(menu_out_launch._is_transitioning, "menu_out_launch _is_transitioning guard flag is set")
	menu_out_launch.free()

	# Out-of-tree quit_game cleanly bypasses get_tree().quit()
	var menu_out_quit = MenuScene.instantiate()
	assert_false(menu_out_quit.is_inside_tree(), "menu_out_quit is strictly outside scene tree")

	var quit_result: Array = []
	menu_out_quit.quit_requested.connect(func(): quit_result.append(true))
	menu_out_quit.quit_game()

	assert_equal(quit_result.size(), 1, "quit_game emits quit_requested out-of-tree without crashes")
	assert_true(menu_out_quit._is_transitioning, "menu_out_quit _is_transitioning guard flag is set")
	menu_out_quit.free()
