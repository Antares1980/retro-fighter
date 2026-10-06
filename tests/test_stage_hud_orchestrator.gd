class_name TestStageHUDOrchestrator
extends RefCounted

## Unit and integration tests for Stage, HUD, and Main Match Loop Orchestrator.
## Verifies scenes/Stage.tscn, scenes/HUD.tscn, scenes/Main.tscn, and scripts/Main.gd
## covering AC-07, AC-08, AC-09, AC-10, and AC-11.

const StageScene = preload("res://scenes/Stage.tscn")
const HUDScene = preload("res://scenes/HUD.tscn")
const HUDScript = preload("res://scripts/HUD.gd")
const MainScene = preload("res://scenes/Main.tscn")
const MainScript = preload("res://scripts/Main.gd")
const FighterScript = preload("res://scripts/Fighter.gd")
const DynamicFightCameraScript = preload("res://scripts/DynamicFightCamera.gd")

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
	print("\n=== Running Stage, HUD & Match Loop Orchestrator Tests ===")
	test_stage_structure_and_ground_collision()
	test_hud_elements_and_color_transitions()
	test_main_scene_wiring()
	test_match_fsm_intro_to_in_round()
	test_ac07_ko_and_round_reset()
	test_ac08_timeout_win_determination()
	test_ac09_draw_timeout_and_double_ko()
	test_ac10_p2_dummy_persistence_in_orchestrator()
	test_ac11_standalone_launch_readiness()

	print("\n=== Stage, HUD & Match Orchestrator Test Results: %d passed, %d failed ===" % [passed, failed])
	return failed == 0

func test_stage_structure_and_ground_collision() -> void:
	print("\nScenario: Stage Scene Visuals & Collision Layout")
	var stage = StageScene.instantiate()
	assert_true(stage != null, "scenes/Stage.tscn instantiates successfully")

	# Backdrop
	var backdrop = stage.get_node_or_null("SunsetBackdrop")
	assert_true(backdrop != null, "SunsetBackdrop exists")
	if backdrop is TextureRect:
		assert_equal(backdrop.offset_right, 600.0, "Backdrop width is 600 px")
		assert_equal(backdrop.offset_bottom, 224.0, "Backdrop height is 224 px")

	# Cityscape silhouette
	var cityscape = stage.get_node_or_null("Cityscape")
	assert_true(cityscape != null, "Cityscape Polygon2D exists")
	assert_true(cityscape is Polygon2D, "Cityscape is Polygon2D")

	# Ground Collision at Y = 190
	var ground = stage.get_node_or_null("Ground")
	assert_true(ground != null, "Ground StaticBody2D exists")
	if ground is StaticBody2D:
		assert_equal(ground.collision_layer, 1, "Ground collision_layer is Layer 1 (WorldFloor)")
		var col_shape = ground.get_node_or_null("CollisionShape2D")
		assert_true(col_shape != null, "Ground has CollisionShape2D")
		if col_shape != null and col_shape.shape is RectangleShape2D:
			var rect: RectangleShape2D = col_shape.shape
			var top_y = col_shape.position.y - (rect.size.y * 0.5)
			assert_equal(top_y, 190.0, "Ground collision surface is precisely at Y = 190.0")

	# Stage Walls
	var walls = stage.get_node_or_null("StageWalls")
	assert_true(walls != null, "StageWalls StaticBody2D exists")
	if walls is StaticBody2D:
		assert_equal(walls.collision_layer, 4, "StageWalls collision_layer is Layer 3 (bit 3, value 4)")

	stage.free()

func test_hud_elements_and_color_transitions() -> void:
	print("\nScenario: HUD Elements & Health Bar Depleting Colors")
	var hud = HUDScene.instantiate()
	assert_true(hud != null, "scenes/HUD.tscn instantiates successfully")
	assert_true(hud is CanvasLayer, "HUD root inherits CanvasLayer")
	assert_true(hud.get_script() == HUDScript, "HUD script is HUD.gd")

	var p1_bar = hud.get_node_or_null("P1HealthBar")
	var p2_bar = hud.get_node_or_null("P2HealthBar")
	var timer_lbl = hud.get_node_or_null("TimerLabel")
	var announcer_lbl = hud.get_node_or_null("AnnouncerLabel")

	assert_true(p1_bar != null, "P1HealthBar ProgressBar exists")
	assert_true(p2_bar != null, "P2HealthBar ProgressBar exists")
	assert_true(timer_lbl != null, "TimerLabel Label exists")
	assert_true(announcer_lbl != null, "AnnouncerLabel Label exists")

	# P2 fill mode should be FILL_END_TO_BEGIN (1) to deplete toward center
	if p2_bar != null:
		assert_equal(p2_bar.fill_mode, ProgressBar.FILL_END_TO_BEGIN, "P2HealthBar fill_mode is FILL_END_TO_BEGIN (1)")

	# Color transitions: Yellow (>50%) -> Orange (<=50%) -> Red (<=25%)
	hud.update_p1_health(100, 100)
	assert_equal(p1_bar.modulate, HUDScript.COLOR_HIGH_HP, "Full HP (100) health bar is Yellow")

	hud.update_p1_health(50, 100)
	assert_equal(p1_bar.modulate, HUDScript.COLOR_MID_HP, "Mid HP (50) health bar is Orange")

	hud.update_p1_health(20, 100)
	assert_equal(p1_bar.modulate, HUDScript.COLOR_LOW_HP, "Low HP (20) health bar is Red")

	# Timer updates
	hud.update_timer(99)
	assert_equal(timer_lbl.text, "99", "Timer displays 99")
	hud.update_timer(7)
	assert_equal(timer_lbl.text, "07", "Timer formats single digit with leading zero (07)")

	# Announcer banners
	hud.show_announcer("FIGHT!")
	assert_true(announcer_lbl.visible, "Announcer banner visible when shown")
	assert_equal(announcer_lbl.text, "FIGHT!", "Announcer displays 'FIGHT!'")

	hud.hide_announcer()
	assert_false(announcer_lbl.visible, "Announcer banner hidden after hide_announcer()")

	hud.free()

func test_main_scene_wiring() -> void:
	print("\nScenario: Main Scene Wiring and Instantiation")
	var main = MainScene.instantiate()
	assert_true(main != null, "scenes/Main.tscn instantiates successfully")
	assert_true(main is Node2D, "Main root is Node2D")
	assert_true(main.get_script() == MainScript, "Main script is Main.gd")

	var stage = main.get_node_or_null("Stage")
	var cam = main.get_node_or_null("Camera2D")
	var p1 = main.get_node_or_null("P1")
	var p2 = main.get_node_or_null("P2")
	var hud = main.get_node_or_null("HUD")

	assert_true(stage != null, "Stage child exists in Main")
	assert_true(cam != null, "Camera2D child exists in Main")
	assert_true(p1 != null, "P1 child exists in Main")
	assert_true(p2 != null, "P2 child exists in Main")
	assert_true(hud != null, "HUD child exists in Main")

	assert_equal(p1.player_id, 1, "P1 player_id is 1")
	assert_equal(p2.player_id, 2, "P2 player_id is 2")
	assert_equal(p1.position, Vector2(200.0, 190.0), "P1 starting position is (200, 190)")
	assert_equal(p2.position, Vector2(400.0, 190.0), "P2 starting position is (400, 190)")
	assert_equal(cam.position, Vector2(300.0, 112.0), "Camera starting position is (300, 112)")

	main.free()

func test_match_fsm_intro_to_in_round() -> void:
	print("\nScenario: Match FSM ROUND_INTRO (1.5s, FIGHT!, inputs frozen) -> IN_ROUND")
	var main = MainScene.instantiate()
	main._ready()

	assert_equal(main.match_state, MainScript.MatchState.ROUND_INTRO, "Initial match state is ROUND_INTRO")
	assert_true(main.p1.inputs_frozen, "P1 inputs frozen during ROUND_INTRO")
	assert_true(main.p2.inputs_frozen, "P2 inputs frozen during ROUND_INTRO")
	assert_equal(main.hud.announcer_label.text, "FIGHT!", "Announcer banner displays 'FIGHT!' during ROUND_INTRO")
	assert_true(main.hud.announcer_label.visible, "Announcer banner is visible during ROUND_INTRO")

	# Advance 1.0s -> still in ROUND_INTRO
	main.step(1.0)
	assert_equal(main.match_state, MainScript.MatchState.ROUND_INTRO, "Still in ROUND_INTRO after 1.0s")
	assert_true(main.p1.inputs_frozen, "Inputs remain frozen after 1.0s")

	# Advance remaining 0.5s -> transitions to IN_ROUND
	main.step(0.5)
	assert_equal(main.match_state, MainScript.MatchState.IN_ROUND, "Transitions to IN_ROUND at 1.5s")
	assert_false(main.p1.inputs_frozen, "P1 inputs active in IN_ROUND")
	assert_false(main.p2.inputs_frozen, "P2 inputs active in IN_ROUND")
	assert_false(main.hud.announcer_label.visible, "Announcer banner hidden during IN_ROUND")

	main.free()

func test_ac07_ko_and_round_reset() -> void:
	print("\nScenario: AC-07 - KO Detection, Banner, Signal, and 3.0s Reset")
	var main = MainScene.instantiate()
	main._ready()
	main.change_match_state(MainScript.MatchState.IN_ROUND)

	var signal_received: Array = []
	main.round_ended.connect(func(winner_id: int, reason: String):
		signal_received.append([winner_id, reason])
	)

	# Given P2 at 8 HP
	main.p2.health = 8

	# When P1 lands punch (8 damage) -> P2 reaches 0 HP
	main.p1.hitbox.configure_punch(1, main.p1)
	main.p1.hitbox.trigger_hit(main.p2.hurtbox)

	assert_equal(main.p2.health, 0, "P2 health drops to 0")
	assert_equal(main.p2.state, FighterScript.State.KNOCKDOWN, "P2 enters KNOCKDOWN")
	assert_equal(main.match_state, MainScript.MatchState.ROUND_OVER, "Match transitions to ROUND_OVER upon KO")
	assert_equal(main.last_winner_id, 1, "P1 is declared the winner")
	assert_equal(main.last_reason, "KO", "Winner reason is 'KO'")
	assert_equal(main.hud.announcer_label.text, "K.O.", "Announcer banner displays 'K.O.'")
	assert_true(main.hud.announcer_label.visible, "Announcer banner is visible")
	assert_true(main.p1.inputs_frozen, "Inputs frozen in ROUND_OVER")
	assert_true(main.p2.inputs_frozen, "Inputs frozen in ROUND_OVER")

	assert_equal(signal_received.size(), 1, "round_ended signal emitted exactly once")
	assert_equal(signal_received[0], [1, "KO"], "Signal emitted with winner_id=1, reason='KO'")

	# Advance 2.0s -> still in ROUND_OVER
	main.step(2.0)
	assert_equal(main.match_state, MainScript.MatchState.ROUND_OVER, "Still in ROUND_OVER after 2.0s")

	# Advance 1.0s (total 3.0s) -> reset occurs and loops back to ROUND_INTRO
	main.step(1.0)
	assert_equal(main.match_state, MainScript.MatchState.ROUND_INTRO, "Resets and loops back to ROUND_INTRO after 3.0s")
	assert_equal(main.p1.health, 100, "P1 health restored to 100")
	assert_equal(main.p2.health, 100, "P2 health restored to 100")
	assert_equal(main.p1.state, FighterScript.State.IDLE, "P1 state restored to IDLE")
	assert_equal(main.p2.state, FighterScript.State.IDLE, "P2 state restored to IDLE")
	assert_equal(main.p1.global_position.x, 200.0, "P1 position restored to X=200")
	assert_equal(main.p2.global_position.x, 400.0, "P2 position restored to X=400")
	assert_equal(int(main.round_timer), 99, "Round timer reset to 99")

	main.free()

func test_ac08_timeout_win_determination() -> void:
	print("\nScenario: AC-08 - Timeout Win Determination & Signal")
	var main = MainScene.instantiate()
	main._ready()
	main.change_match_state(MainScript.MatchState.IN_ROUND)

	var signal_received: Array = []
	main.round_ended.connect(func(winner_id: int, reason: String):
		signal_received.append([winner_id, reason])
	)

	# Given P1 at 80 HP, P2 at 50 HP
	main.p1.health = 80
	main.p2.health = 50
	main.hud.update_p1_health(80, 100)
	main.hud.update_p2_health(50, 100)

	# Advance timer to 0 (99 seconds)
	main.step(99.0)

	assert_equal(main.match_state, MainScript.MatchState.ROUND_OVER, "Match transitions to ROUND_OVER on timeout")
	assert_equal(main.last_winner_id, 1, "P1 declared winner due to higher HP (80 > 50)")
	assert_equal(main.last_reason, "TIME_UP", "Reason is 'TIME_UP'")
	assert_equal(main.hud.announcer_label.text, "TIME UP", "Announcer banner displays 'TIME UP'")
	assert_true(main.hud.announcer_label.visible, "Announcer banner visible")
	assert_true(main.p1.inputs_frozen, "Inputs frozen on timeout")

	assert_equal(signal_received.size(), 1, "round_ended signal emitted")
	assert_equal(signal_received[0], [1, "TIME_UP"], "Signal emitted with winner_id=1, reason='TIME_UP'")

	main.free()

func test_ac09_draw_timeout_and_double_ko() -> void:
	print("\nScenario: AC-09 - Draw Resolution (Equal HP Timeout & Double KO)")
	# Case 1: Timeout on equal HP
	var main1 = MainScene.instantiate()
	main1._ready()
	main1.change_match_state(MainScript.MatchState.IN_ROUND)

	var signal1: Array = []
	main1.round_ended.connect(func(winner_id: int, reason: String):
		signal1.append([winner_id, reason])
	)

	main1.p1.health = 60
	main1.p2.health = 60

	main1.step(99.0)
	assert_equal(main1.match_state, MainScript.MatchState.ROUND_OVER, "Transitions to ROUND_OVER on timeout")
	assert_equal(main1.last_winner_id, 0, "Winner ID is 0 (DRAW) on equal health timeout")
	assert_equal(main1.last_reason, "DRAW", "Reason is 'DRAW'")
	assert_equal(main1.hud.announcer_label.text, "DRAW", "Announcer banner displays 'DRAW'")
	assert_equal(signal1[0], [0, "DRAW"], "Signal emitted with winner_id=0, reason='DRAW'")
	main1.free()

	# Case 2: Double KO within same physics tick
	var main2 = MainScene.instantiate()
	main2._ready()
	main2.change_match_state(MainScript.MatchState.IN_ROUND)

	var signal2: Array = []
	main2.round_ended.connect(func(winner_id: int, reason: String):
		signal2.append([winner_id, reason])
	)

	main2.p1.health = 0
	main2.p2.health = 0
	main2.step(1.0 / 60.0)

	assert_equal(main2.match_state, MainScript.MatchState.ROUND_OVER, "Transitions to ROUND_OVER on double KO")
	assert_equal(main2.last_winner_id, 0, "Winner ID is 0 on double KO")
	assert_equal(main2.last_reason, "DRAW", "Reason is 'DRAW' on double KO")
	assert_equal(main2.hud.announcer_label.text, "DRAW", "Announcer banner displays 'DRAW'")
	assert_equal(signal2[0], [0, "DRAW"], "Signal emitted with winner_id=0, reason='DRAW'")
	main2.free()

func test_ac10_p2_dummy_persistence_in_orchestrator() -> void:
	print("\nScenario: AC-10 - Player 2 Dummy Persistence Across Match Reset")
	var main = MainScene.instantiate()
	main._ready()
	main.change_match_state(MainScript.MatchState.IN_ROUND)

	assert_false(main.p2.is_dummy, "P2 initially in HUMAN mode")

	# Toggle dummy mode
	main.p2.toggle_dummy()
	assert_true(main.p2.is_dummy, "P2 toggles to DUMMY mode")

	# P2 dummy auto crouch-blocks incoming punch
	main.p1.hitbox.configure_punch(1, main.p1)
	main.p1.hitbox.trigger_hit(main.p2.hurtbox)
	assert_equal(main.p2.health, 99, "P2 dummy crouch-blocks and takes only 1 HP damage")

	# Trigger round reset
	main.change_match_state(MainScript.MatchState.ROUND_OVER)
	main.step(3.0)

	# Verify dummy mode persists across round reset per AC-10
	assert_equal(main.match_state, MainScript.MatchState.ROUND_INTRO, "Match loop resets to ROUND_INTRO")
	assert_true(main.p2.is_dummy, "P2 dummy mode persists across round reset")

	main.free()

func test_ac11_standalone_launch_readiness() -> void:
	print("\nScenario: AC-11 - Standalone Launch Readiness")
	var main_scene_setting = ProjectSettings.get_setting("application/run/main_scene")
	assert_equal(main_scene_setting, "res://scenes/Main.tscn", "Main scene is res://scenes/Main.tscn")

	var packed = load(main_scene_setting) as PackedScene
	assert_true(packed != null, "scenes/Main.tscn loads as PackedScene")

	var instance = packed.instantiate()
	assert_true(instance != null, "scenes/Main.tscn instantiates cleanly")
	assert_true(instance.has_node("Stage"), "Main has Stage instance")
	assert_true(instance.has_node("Camera2D"), "Main has Camera2D instance")
	assert_true(instance.has_node("P1"), "Main has P1 instance")
	assert_true(instance.has_node("P2"), "Main has P2 instance")
	assert_true(instance.has_node("HUD"), "Main has HUD instance")

	instance.free()
