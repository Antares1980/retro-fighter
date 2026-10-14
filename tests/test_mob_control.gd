class_name TestMobControl
extends RefCounted

## Automated Test Suite for Mob Control 3D Arcade Game.
## Validates Menu integration, Cannon kinematics & firing cadence, Math modifier gate replication,
## 1-to-1 swarm attrition, Giant Boss assault, Winnability, Defeat priority, stage reset, and memory integrity.

const MenuScene = preload("res://scenes/Menu.tscn")
const MobControlMainScene = preload("res://scenes/mob_control/MobControlMain.tscn")
const MobControlMainScript = preload("res://scripts/mob_control/MobControlMain.gd")
const Cannon3DScene = preload("res://scenes/mob_control/Cannon3D.tscn")
const MobUnit3DScene = preload("res://scenes/mob_control/MobUnit3D.tscn")
const MultiplierGate3DScene = preload("res://scenes/mob_control/MultiplierGate3D.tscn")
const GiantEnemy3DScene = preload("res://scenes/mob_control/GiantEnemy3D.tscn")

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
	elif actual is Vector3 and expected is Vector3:
		matches = (actual as Vector3).is_equal_approx(expected as Vector3)
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

	print("\n=== Running Mob Control 3D Tests ===")
	test_scenario_1_menu_navigation_and_clean_return()
	test_scenario_2_cannon_movement_cadence_and_cap()
	test_scenario_3_modifier_gate_replication_and_giant_ui()
	test_scenario_4_1v1_swarm_attrition()
	test_scenario_5_giant_boss_assault_and_victory()
	test_scenario_5b_end_to_end_winnability()
	test_scenario_6_enemy_breach_defeat_priority_and_reset()
	test_scenario_7_controls_discoverability_steering_and_space_fire()
	test_scenario_8_raw_key_fallback_and_scene_attachment()
	test_scenario_9_freed_instance_safety_and_pruning()

	print("\n=== Mob Control Test Results: %d passed, %d failed ===" % [passed, failed])
	return failed == 0

func test_scenario_1_menu_navigation_and_clean_return() -> void:
	print("\nScenario 1: Menu Navigation, Slot 2 Property Contract, and Clean Return")
	var active_tree = _get_tree()

	var menu = MenuScene.instantiate()
	if active_tree != null:
		active_tree.root.add_child(menu)

	assert_equal(menu.ComingSoonButton.text, "2. MOB CONTROL 3D", "ComingSoonButton.text is '2. MOB CONTROL 3D'")
	assert_false(menu.ComingSoonButton.disabled, "ComingSoonButton.disabled == false")
	assert_equal(menu.ComingSoonButton.focus_mode, Control.FOCUS_ALL, "ComingSoonButton.focus_mode == Control.FOCUS_ALL")

	var game_selected_emitted: Array = []
	menu.game_selected.connect(func(p: String): game_selected_emitted.append(p))
	menu._on_coming_soon_pressed()

	assert_equal(game_selected_emitted.size(), 1, "Activating Slot 2 emits game_selected once")
	if game_selected_emitted.size() > 0:
		assert_equal(game_selected_emitted[0], "res://scenes/mob_control/MobControlMain.tscn", "Emitted path is MobControlMain.tscn")

	if active_tree != null:
		active_tree.root.remove_child(menu)
	menu.free()

	# Test MobControlMain ESC return hook
	var main = MobControlMainScene.instantiate()
	if active_tree != null:
		active_tree.root.add_child(main)

	var return_emitted: Array = []
	main.return_to_menu_requested.connect(func(): return_emitted.append(true))

	var ev_cancel = InputEventAction.new()
	ev_cancel.action = "ui_cancel"
	ev_cancel.pressed = true

	main._unhandled_input(ev_cancel)
	assert_equal(return_emitted.size(), 1, "ESC emits return_to_menu_requested once")
	assert_true(main._returning_to_menu, "_returning_to_menu guard flag is true")

	# Repeated press guarded
	main._unhandled_input(ev_cancel)
	assert_equal(return_emitted.size(), 1, "Repeated ESC does not re-emit return_to_menu_requested")

	main.cleanup_all_mobs()
	if active_tree != null:
		active_tree.root.remove_child(main)
	main.free()

func test_scenario_2_cannon_movement_cadence_and_cap() -> void:
	print("\nScenario 2: Cannon Movement, Firing Cadence, Release Reset, and Cap Enforcement")
	var main = MobControlMainScene.instantiate()
	var active_tree = _get_tree()
	if active_tree != null:
		active_tree.root.add_child(main)

	var cannon = main.cannon
	assert_true(cannon != null, "Cannon exists in MobControlMain")
	assert_equal(cannon.position, Vector3(0.0, 0.5, 9.0), "Initial cannon position is (0.0, 0.5, 9.0)")

	# Test movement clamping
	cannon.move_input = -1.0
	for i in range(60):
		cannon.step(1.0 / 60.0)
	assert_true(cannon.position.x <= -4.99 and cannon.position.x >= -5.0, "Cannon clamped at min_x = -5.0")

	cannon.move_input = 1.0
	for i in range(120):
		cannon.step(1.0 / 60.0)
	assert_true(cannon.position.x >= 4.99 and cannon.position.x <= 5.0, "Cannon clamped at max_x = +5.0")

	cannon.reset()
	assert_equal(cannon.position, Vector3(0.0, 0.5, 9.0), "Cannon reset restores (0.0, 0.5, 9.0)")

	# Test shooting cadence: 1.0s stepped in 60 increments of 1/60s
	cannon.fire_held = true
	var shot_steps: Array = []
	for step_idx in range(1, 61):
		main.step(1.0 / 60.0)
		var current_count = main.get_live_blue_mobs_count()
		if current_count > shot_steps.size():
			shot_steps.append(step_idx)

	# First shot at step 9 (t = 9 * 1/60 = 0.15s >= 0.14s)
	assert_true(shot_steps.size() > 0, "Cannon fired at least one shot")
	if shot_steps.size() > 0:
		assert_equal(shot_steps[0], 9, "First shot fires at step 9 (accumulated time >= 0.14s)")

	# Exactly 7 mobs produced after 60 steps (1.0s / 0.14s = 7)
	assert_equal(main.get_live_blue_mobs_count(), 7, "Exactly 7 Blue Mobs exist after 1.0s of fire")

	# Check mob properties
	for mob in main.blue_mobs:
		assert_false(mob.is_consumed, "Blue mob is_consumed is false")
		assert_equal(mob.team, "blue", "Mob team is blue")

	# Test release resets accumulator
	cannon.fire_held = false
	main.step(1.0 / 60.0)
	assert_equal(cannon.fire_accumulator, 0.0, "Fire accumulator resets to 0.0 on release")

	# Re-holding requires another full 0.14s (8 steps of 1/60s = 0.133s < 0.14s)
	cannon.fire_held = true
	for i in range(8):
		main.step(1.0 / 60.0)
	assert_equal(main.get_live_blue_mobs_count(), 7, "No shot fired before 0.14s elapsed after release")

	main.step(1.0 / 60.0) # Step 9: 9/60 = 0.15s >= 0.14s
	assert_equal(main.get_live_blue_mobs_count(), 8, "Shot fired on step 9 after re-engaging fire")

	# Test MAX_MOBS cap enforcement at cannon
	main.cleanup_all_mobs()
	# Pre-populate up to MAX_MOBS (300)
	for i in range(MobControlMainScript.MAX_MOBS):
		main._spawn_blue_mob(Vector3(0.0, 0.5, 0.0))
	assert_equal(main.get_live_blue_mobs_count(), 300, "Spawned 300 live blue mobs")

	cannon.fire_accumulator = 0.14
	cannon.fire_held = true
	main.step(1.0 / 60.0)
	assert_equal(main.get_live_blue_mobs_count(), 300, "Global cap prevents firing beyond MAX_MOBS = 300")
	assert_equal(main.pending_spawns, 0, "pending_spawns remains 0 when at cap")

	main.cleanup_all_mobs()
	if active_tree != null:
		active_tree.root.remove_child(main)
	main.free()

func test_scenario_3_modifier_gate_replication_and_giant_ui() -> void:
	print("\nScenario 3: Math Multiplier Gate Replication, Deferred Spawning, & Giant UI Update")
	var main = MobControlMainScene.instantiate()
	var active_tree = _get_tree()
	if active_tree != null:
		active_tree.root.add_child(main)

	# Locate gate_left_1 (+2 at Z = -2.0)
	var gate = main.gates_container.get_node("gate_left_1") as MultiplierGate3D
	assert_true(gate != null, "gate_left_1 exists")
	assert_equal(gate.operation, "+", "gate_left_1 operation is '+'")
	assert_equal(gate.value, 2, "gate_left_1 value is 2")

	# Spawn 1 Blue Mob at X = -2.5, Z = -1.9 (overlapping gate_left_1)
	var entering_mob = main._spawn_blue_mob(Vector3(-2.5, 0.5, -1.9))
	assert_equal(main.get_live_blue_mobs_count(), 1, "1 live blue mob spawned before gate overlap")

	# Step contact resolution
	main._resolve_gate_contacts()
	assert_equal(main.pending_spawns, 2, "pending_spawns is 2 immediately upon gate overlap")
	assert_false(entering_mob.is_consumed, "Entering mob is_consumed remains false")
	assert_true(entering_mob.passed_gates.has("gate_left_1"), "Entering mob marked gate_left_1 in passed_gates")

	# Flush clones
	main.flush_pending_spawns()
	assert_equal(main.pending_spawns, 0, "pending_spawns is 0 after flush")
	assert_equal(main.get_live_blue_mobs_count(), 3, "Total live blue mobs in corridor is 3 (1 entering + 2 clones)")

	# Check clone positions and passed_gates inheritance
	for mob in main.blue_mobs:
		assert_equal(mob.position.x, -2.5, "Clone X inherits parent X (-2.5)")
		assert_true(mob.passed_gates.has("gate_left_1"), "Clone inherits passed_gates")

	# Advance the 3 mobs into Giant Boss at Z = -15.0
	for mob in main.blue_mobs:
		mob.position.z = -15.0

	main._resolve_giant_contacts()
	assert_equal(main.giant_enemy.hp, 147, "Giant Boss HP decremented from 150 to 147 (150 - 3)")
	assert_equal(main.giant_enemy.label.text, "HP: 147", "Giant Boss Label3D displays 'HP: 147'")
	assert_true(is_equal_approx(main.giant_enemy.health_bar.scale.x, 147.0 / 150.0), "HealthBar scale is 147.0 / 150.0")

	# Test safe cap formula: 298 live blue mobs hitting +5 gate (k = 5)
	main.cleanup_all_mobs()
	for i in range(297):
		main._spawn_blue_mob(Vector3(0.0, 0.5, 0.0))
	var test_mob = main._spawn_blue_mob(Vector3(-2.5, 0.5, -1.9))
	assert_equal(main.get_live_blue_mobs_count(), 298, "298 live blue mobs present")

	# Re-trigger gate
	main._resolve_gate_contacts()
	# allowed = maxi(0, mini(2, 300 - 298)) = 2
	assert_equal(main.pending_spawns, 2, "pending_spawns safely clamped to 2")
	main.flush_pending_spawns()
	assert_equal(main.get_live_blue_mobs_count(), 300, "Total live blue mobs reached exactly MAX_MOBS = 300")

	# Re-overlapping gate with passed_gates spawns 0
	main._resolve_gate_contacts()
	assert_equal(main.pending_spawns, 0, "No additional clones queued for mob with passed_gate")

	main.cleanup_all_mobs()
	if active_tree != null:
		active_tree.root.remove_child(main)
	main.free()

func test_scenario_4_1v1_swarm_attrition() -> void:
	print("\nScenario 4: 1-to-1 Swarm Attrition Combat")
	var main = MobControlMainScene.instantiate()
	var active_tree = _get_tree()
	if active_tree != null:
		active_tree.root.add_child(main)

	# 1 Blue and 1 Red colliding
	var blue = main._spawn_blue_mob(Vector3(0.0, 0.5, 0.0))
	var red = main._spawn_red_mob()
	red.position = Vector3(0.0, 0.5, 0.1)

	assert_equal(main.blue_mobs.size(), 1, "1 blue mob created")
	assert_equal(main.red_mobs.size(), 1, "1 red mob created")

	main._resolve_mob_clashes()

	assert_true(blue.is_consumed, "Blue mob is_consumed is true")
	assert_true(red.is_consumed, "Red mob is_consumed is true")
	assert_false(main.is_live(blue), "Blue mob is not live after clash")
	assert_false(main.is_live(red), "Red mob is not live after clash")

	main.cleanup_all_mobs()

	# 1 Red Mob overlapping 3 co-located Blue Mobs: exactly 1 Blue and 1 Red consumed
	var b1 = main._spawn_blue_mob(Vector3(1.0, 0.5, 0.0))
	var b2 = main._spawn_blue_mob(Vector3(1.0, 0.5, 0.0))
	var b3 = main._spawn_blue_mob(Vector3(1.0, 0.5, 0.0))
	var r1 = main._spawn_red_mob()
	r1.position = Vector3(1.0, 0.5, 0.0)

	main._resolve_mob_clashes()

	var consumed_blue: int = 0
	for b in [b1, b2, b3]:
		if b.is_consumed:
			consumed_blue += 1

	assert_equal(consumed_blue, 1, "Exactly 1 Blue Mob consumed in multi-clash")
	assert_true(r1.is_consumed, "The Red Mob was consumed in multi-clash")

	var live_blue: int = 0
	for b in [b1, b2, b3]:
		if main.is_live(b):
			live_blue += 1
	assert_equal(live_blue, 2, "Exactly 2 Blue Mobs remain alive and active")

	main.cleanup_all_mobs()
	if active_tree != null:
		active_tree.root.remove_child(main)
	main.free()

func test_scenario_5_giant_boss_assault_and_victory() -> void:
	print("\nScenario 5: Giant Boss HP Depletion, Victory Latch, & Banner Verification")
	var main = MobControlMainScene.instantiate()
	var active_tree = _get_tree()
	if active_tree != null:
		active_tree.root.add_child(main)

	main.giant_enemy.hp = 2
	main.giant_enemy._update_ui()

	var b1 = main._spawn_blue_mob(Vector3(0.0, 1.25, -15.0))
	var b2 = main._spawn_blue_mob(Vector3(1.0, 1.25, -15.0))

	main.step(1.0 / 60.0)

	assert_equal(main.giant_enemy.hp, 0, "Giant Boss HP reached 0")
	assert_equal(main.state, MobControlMainScript.GameState.VICTORY, "Game state latched to VICTORY")
	assert_true(main.victory_banner.visible, "VictoryBanner is visible")
	assert_true(main.victory_banner.text.contains("VICTORY!"), "VictoryBanner text contains 'VICTORY!'")

	# Live Red Mob positioned at Z >= 9.0 after VICTORY
	var red = MobUnit3DScene.instantiate() as MobUnit3D
	red.setup("red")
	red.position = Vector3(0.0, 0.5, 9.5)
	main.add_child(red)
	main.red_mobs.append(red)
	main.step(1.0 / 60.0)

	assert_equal(main.state, MobControlMainScript.GameState.VICTORY, "State remains VICTORY after Red Mob breaches post-win")
	assert_false(main.defeat_banner.visible, "DefeatBanner remains false")

	main.cleanup_all_mobs()
	if active_tree != null:
		active_tree.root.remove_child(main)
	main.free()

func test_scenario_5b_end_to_end_winnability() -> void:
	print("\nScenario 5b: End-to-End Winnability in Live Stepping Across Gate Corridor")
	var lanes = [-2.5, -1.0, 2.5]
	for lane_x in lanes:
		var main = MobControlMainScene.instantiate()
		var active_tree = _get_tree()
		if active_tree != null:
			active_tree.root.add_child(main)

		main.rng.seed = 12345
		main.cannon.position.x = lane_x
		main.cannon.fire_held = true

		var reached_victory: bool = false
		for step_num in range(360):
			main.step(1.0 / 60.0)
			main.flush_pending_spawns()
			if main.state == MobControlMainScript.GameState.VICTORY:
				reached_victory = true
				break

		assert_true(reached_victory, "Lane X = %s reaches VICTORY within 360 steps (6.0s)" % str(lane_x))
		assert_equal(main.state, MobControlMainScript.GameState.VICTORY, "Final state is VICTORY for lane X = %s" % str(lane_x))
		assert_equal(main.giant_enemy.hp, 0, "Giant Boss HP reached 0 for lane X = %s" % str(lane_x))

		main.cleanup_all_mobs()
		if active_tree != null:
			active_tree.root.remove_child(main)
		main.free()

func test_scenario_6_enemy_breach_defeat_priority_and_reset() -> void:
	print("\nScenario 6: Enemy Breach, Defeat Priority, In-Place Restart, & ESC Terminal Handling")
	var main = MobControlMainScene.instantiate()
	var active_tree = _get_tree()
	if active_tree != null:
		active_tree.root.add_child(main)

	# KEY_R during PLAYING does nothing
	var ev_r = InputEventKey.new()
	ev_r.pressed = true
	ev_r.keycode = KEY_R
	main._unhandled_input(ev_r)
	assert_equal(main.state, MobControlMainScript.GameState.PLAYING, "KEY_R during PLAYING does not change state")

	# Red Mob reaches Z >= 9.0 -> DEFEAT
	var red = main._spawn_red_mob()
	red.position = Vector3(0.0, 0.5, 9.0)
	main.step(1.0 / 60.0)

	assert_equal(main.state, MobControlMainScript.GameState.DEFEAT, "State latched to DEFEAT on enemy breach")
	assert_true(main.defeat_banner.visible, "DefeatBanner is visible")
	assert_true(main.defeat_banner.text.contains("DEFEAT!"), "DefeatBanner text contains 'DEFEAT!'")

	# Tie breaker test: same tick Boss HP 0 and Red Mob reaches Z >= 9.0 -> DEFEAT takes priority
	main.reset_stage()
	assert_equal(main.state, MobControlMainScript.GameState.PLAYING, "Stage reset to PLAYING")

	main.giant_enemy.hp = 0
	var red_tie = main._spawn_red_mob()
	red_tie.position = Vector3(0.0, 0.5, 9.1)
	main._evaluate_game_state()

	assert_equal(main.state, MobControlMainScript.GameState.DEFEAT, "DEFEAT takes priority in same-tick tie")

	# Test 12-point contract of reset_stage()
	main.reset_stage()
	assert_equal(main.state, MobControlMainScript.GameState.PLAYING, "[1] state == GameState.PLAYING")
	assert_equal(main.giant_enemy.hp, 150, "[2] Giant Boss HP is 150")
	assert_equal(main.giant_enemy.position, Vector3(0.0, 1.25, -15.0), "[2] Giant Boss position is (0.0, 1.25, -15.0)")
	assert_equal(main.cannon.position, Vector3(0.0, 0.5, 9.0), "[3] Cannon position is (0.0, 0.5, 9.0)")
	assert_equal(main.cannon.move_input, 0.0, "[4] Cannon move_input == 0.0")
	assert_false(main.cannon.fire_held, "[4] Cannon fire_held == false")
	assert_equal(main.cannon.fire_accumulator, 0.0, "[5] Fire cooldown accumulator is 0.0")
	assert_equal(main.red_spawn_timer, 0.0, "[6] Red spawner timer is 0.0")
	assert_equal(main.pending_spawns, 0, "[7] pending_spawns == 0")
	assert_equal(main.get_live_blue_mobs_count(), 0, "[8] Total active blue mobs count is 0")
	assert_equal(main.red_mobs.size(), 0, "[8] Total active red mobs count is 0")
	assert_false(main.victory_banner.visible, "[10] VictoryBanner.visible == false")
	assert_false(main.defeat_banner.visible, "[10] DefeatBanner.visible == false")
	assert_equal(main.giant_enemy.label.text, "HP: 150", "[11] Giant Boss Label3D is 'HP: 150'")
	assert_equal(main.giant_enemy.health_bar.scale.x, 1.0, "[11] Giant Boss HealthBar scale is 1.0")
	assert_false(main._returning_to_menu, "[12] _returning_to_menu == false")

	main.cleanup_all_mobs()
	if active_tree != null:
		active_tree.root.remove_child(main)
	main.free()

func test_scenario_7_controls_discoverability_steering_and_space_fire() -> void:
	print("\nScenario 7: Controls Discoverability, Steering (A/D/Arrows), Space Firing & Regression Safety")
	var main = MobControlMainScene.instantiate()
	var active_tree = _get_tree()
	if active_tree != null:
		active_tree.root.add_child(main)

	# 1. Discoverability Contract: Controls hint label presence & visibility
	assert_true(main.controls_hint != null, "ControlsHint label exists in MobControlMain")
	if main.controls_hint != null:
		assert_true(main.controls_hint.visible, "ControlsHint is visible on screen")
		assert_true(main.controls_hint.text.contains("A/D or ARROWS: STEER"), "ControlsHint explains steering")
		assert_true(main.controls_hint.text.contains("HOLD J or SPACE: FIRE"), "ControlsHint explains firing")
		assert_true(main.controls_hint.text.contains("ESC: MENU"), "ControlsHint explains returning to menu")

	var cannon = main.cannon
	assert_true(cannon != null, "Cannon exists for controls testing")

	# 2. AC1: Left steering via p1_left (A) and p2_left (Left Arrow)
	cannon.reset()
	Input.action_press("p1_left")
	cannon.step(1.0 / 60.0)
	Input.action_release("p1_left")
	assert_true(cannon.position.x < 0.0, "p1_left steers cannon horizontally left")

	cannon.reset()
	Input.action_press("p1_left")
	for i in range(60):
		cannon.step(1.0 / 60.0)
	Input.action_release("p1_left")
	assert_true(cannon.position.x <= -4.99 and cannon.position.x >= -5.0, "p1_left clamped firmly at min_x = -5.0")

	cannon.reset()
	Input.action_press("p2_left")
	cannon.step(1.0 / 60.0)
	Input.action_release("p2_left")
	assert_true(cannon.position.x < 0.0, "p2_left steers cannon horizontally left")

	cannon.reset()
	Input.action_press("p2_left")
	for i in range(60):
		cannon.step(1.0 / 60.0)
	Input.action_release("p2_left")
	assert_true(cannon.position.x <= -4.99 and cannon.position.x >= -5.0, "p2_left clamped firmly at min_x = -5.0")

	# 3. AC2: Right steering via p1_right (D) and p2_right (Right Arrow)
	cannon.reset()
	Input.action_press("p1_right")
	cannon.step(1.0 / 60.0)
	Input.action_release("p1_right")
	assert_true(cannon.position.x > 0.0, "p1_right steers cannon horizontally right")

	cannon.reset()
	Input.action_press("p1_right")
	for i in range(60):
		cannon.step(1.0 / 60.0)
	Input.action_release("p1_right")
	assert_true(cannon.position.x >= 4.99 and cannon.position.x <= 5.0, "p1_right clamped firmly at max_x = +5.0")

	cannon.reset()
	Input.action_press("p2_right")
	cannon.step(1.0 / 60.0)
	Input.action_release("p2_right")
	assert_true(cannon.position.x > 0.0, "p2_right steers cannon horizontally right")

	cannon.reset()
	Input.action_press("p2_right")
	for i in range(60):
		cannon.step(1.0 / 60.0)
	Input.action_release("p2_right")
	assert_true(cannon.position.x >= 4.99 and cannon.position.x <= 5.0, "p2_right clamped firmly at max_x = +5.0")

	# 4. AC3: Continuous firing via J (p1_punch) and Space (mc_fire)
	main.cleanup_all_mobs()
	cannon.reset()

	# Test J key (p1_punch)
	Input.action_press("p1_punch")
	for i in range(8):
		main.step(1.0 / 60.0)
	assert_equal(main.get_live_blue_mobs_count(), 0, "No shot before 0.14s with p1_punch")
	main.step(1.0 / 60.0)
	assert_equal(main.get_live_blue_mobs_count(), 1, "First shot fires at 0.15s with p1_punch")
	Input.action_release("p1_punch")
	main.step(1.0 / 60.0)
	assert_equal(cannon.fire_accumulator, 0.0, "Accumulator resets to 0.0 when p1_punch released")

	# Test Space key (mc_fire)
	main.cleanup_all_mobs()
	cannon.reset()
	Input.action_press("mc_fire")
	for i in range(8):
		main.step(1.0 / 60.0)
	assert_equal(main.get_live_blue_mobs_count(), 0, "No shot before 0.14s with mc_fire")
	main.step(1.0 / 60.0)
	assert_equal(main.get_live_blue_mobs_count(), 1, "First shot fires at 0.15s with mc_fire")
	# Step through remaining frames for 1 full second (total 60 frames)
	for i in range(51):
		main.step(1.0 / 60.0)
	assert_equal(main.get_live_blue_mobs_count(), 7, "Exactly 7 mobs spawned after 1.0s of mc_fire")
	Input.action_release("mc_fire")
	main.step(1.0 / 60.0)
	assert_equal(cannon.fire_accumulator, 0.0, "Accumulator resets to 0.0 when mc_fire released")

	# Test P1-only fire constraint: p2_punch must NOT fire cannon
	main.cleanup_all_mobs()
	cannon.reset()
	Input.action_press("p2_punch")
	for i in range(30):
		main.step(1.0 / 60.0)
	Input.action_release("p2_punch")
	assert_equal(main.get_live_blue_mobs_count(), 0, "p2_punch does not fire cannon (P1-only firing contract)")

	# 5. AC4: Game State Transition & Restart Stability
	main.state = MobControlMainScript.GameState.DEFEAT
	var ev_r = InputEventKey.new()
	ev_r.pressed = true
	ev_r.keycode = KEY_R
	main._unhandled_input(ev_r)
	assert_equal(main.state, MobControlMainScript.GameState.PLAYING, "Pressing R during DEFEAT resets state to PLAYING")
	assert_equal(cannon.position, Vector3(0.0, 0.5, 9.0), "Cannon position restored to (0.0, 0.5, 9.0)")

	# Verify steering responsive after reset
	Input.action_press("p1_left")
	cannon.step(1.0 / 60.0)
	Input.action_release("p1_left")
	assert_true(cannon.position.x < 0.0, "Cannon steering responsive after DEFEAT restart")

	main.state = MobControlMainScript.GameState.VICTORY
	main._unhandled_input(ev_r)
	assert_equal(main.state, MobControlMainScript.GameState.PLAYING, "Pressing R during VICTORY resets state to PLAYING")
	assert_equal(cannon.position, Vector3(0.0, 0.5, 9.0), "Cannon position restored to (0.0, 0.5, 9.0)")

	# 6. AC5: Return to Arcade Hub Menu
	var return_called: Array = []
	main.return_to_menu_requested.connect(func(): return_called.append(true))
	var ev_esc = InputEventAction.new()
	ev_esc.action = "ui_cancel"
	ev_esc.pressed = true
	main._unhandled_input(ev_esc)
	assert_equal(return_called.size(), 1, "ESC key emits return_to_menu_requested")
	assert_true(main._returning_to_menu, "_returning_to_menu set to true")

	# 7. AC6: Zero regression on Retro Fighter 2D Input Contracts
	var core_actions = [
		"p1_left", "p1_right", "p1_up", "p1_down", "p1_punch", "p1_kick", "p1_block",
		"p2_left", "p2_right", "p2_up", "p2_down", "p2_punch", "p2_kick", "p2_block",
		"toggle_p2_dummy", "mc_fire"
	]
	for act in core_actions:
		assert_true(InputMap.has_action(act), "Input action '%s' exists in InputMap" % act)

	main.cleanup_all_mobs()
	if active_tree != null:
		active_tree.root.remove_child(main)
	main.free()

func test_scenario_8_raw_key_fallback_and_scene_attachment() -> void:
	print("\nScenario 8: Raw Key Fallbacks & Scene Instantiation Attachment Smoke Test (GWT 1-11)")
	var active_tree = _get_tree()

	# GWT 11: Scene Instantiation & Script Attachment Smoke Test
	var main = MobControlMainScene.instantiate()
	assert_true(main.get_script() != null, "MobControlMain has non-null script attached")
	if active_tree != null:
		active_tree.root.add_child(main)

	assert_true(main.cannon != null, "MobControlMain _ready() initialized cannon != null")
	assert_true(main.giant_enemy != null, "MobControlMain _ready() initialized giant_enemy != null")
	assert_equal(main.state, MobControlMainScript.GameState.PLAYING, "MobControlMain state initialized to PLAYING")

	main.cannon.reset()
	var start_x = main.cannon.position.x
	Input.action_press("p1_right")
	main.step(1.0 / 60.0)
	Input.action_release("p1_right")
	assert_true(main.cannon.position.x > start_x, "Calling step() with p1_right moves cannon horizontally +x")

	# GWT 2: Left Steering & Boundary Clamping via KEY_A and KEY_LEFT
	var cannon = main.cannon
	cannon.reset()

	var press_key = func(code: Key):
		var ev = InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = true
		Input.parse_input_event(ev)
		Input.flush_buffered_events()

	var release_key = func(code: Key):
		var ev = InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = false
		Input.parse_input_event(ev)
		Input.flush_buffered_events()

	# Test KEY_A
	cannon.reset()
	press_key.call(KEY_A)
	cannon.step(1.0 / 60.0)
	release_key.call(KEY_A)
	assert_true(cannon.position.x < 0.0, "Holding KEY_A steers cannon horizontally left")

	cannon.reset()
	press_key.call(KEY_A)
	for i in range(60):
		cannon.step(1.0 / 60.0)
	release_key.call(KEY_A)
	assert_true(cannon.position.x <= -4.99 and cannon.position.x >= -5.0, "KEY_A clamped firmly at min_x = -5.0")

	# Test KEY_LEFT
	cannon.reset()
	press_key.call(KEY_LEFT)
	cannon.step(1.0 / 60.0)
	release_key.call(KEY_LEFT)
	assert_true(cannon.position.x < 0.0, "Holding KEY_LEFT steers cannon horizontally left")

	cannon.reset()
	press_key.call(KEY_LEFT)
	for i in range(60):
		cannon.step(1.0 / 60.0)
	release_key.call(KEY_LEFT)
	assert_true(cannon.position.x <= -4.99 and cannon.position.x >= -5.0, "KEY_LEFT clamped firmly at min_x = -5.0")

	# GWT 3: Right Steering & Boundary Clamping via KEY_D and KEY_RIGHT
	# Test KEY_D
	cannon.reset()
	press_key.call(KEY_D)
	cannon.step(1.0 / 60.0)
	release_key.call(KEY_D)
	assert_true(cannon.position.x > 0.0, "Holding KEY_D steers cannon horizontally right")

	cannon.reset()
	press_key.call(KEY_D)
	for i in range(60):
		cannon.step(1.0 / 60.0)
	release_key.call(KEY_D)
	assert_true(cannon.position.x >= 4.99 and cannon.position.x <= 5.0, "KEY_D clamped firmly at max_x = +5.0")

	# Test KEY_RIGHT
	cannon.reset()
	press_key.call(KEY_RIGHT)
	cannon.step(1.0 / 60.0)
	release_key.call(KEY_RIGHT)
	assert_true(cannon.position.x > 0.0, "Holding KEY_RIGHT steers cannon horizontally right")

	cannon.reset()
	press_key.call(KEY_RIGHT)
	for i in range(60):
		cannon.step(1.0 / 60.0)
	release_key.call(KEY_RIGHT)
	assert_true(cannon.position.x >= 4.99 and cannon.position.x <= 5.0, "KEY_RIGHT clamped firmly at max_x = +5.0")

	# GWT 4: Continuous Fire via KEY_J and KEY_SPACE & accumulator reset
	main.cleanup_all_mobs()
	cannon.reset()
	press_key.call(KEY_J)
	for i in range(8):
		main.step(1.0 / 60.0)
	assert_equal(main.get_live_blue_mobs_count(), 0, "No shot before 0.14s with KEY_J")
	main.step(1.0 / 60.0)
	assert_equal(main.get_live_blue_mobs_count(), 1, "First shot fires at 0.15s with KEY_J")
	release_key.call(KEY_J)
	main.step(1.0 / 60.0)
	assert_equal(cannon.fire_accumulator, 0.0, "Accumulator resets to 0.0 when KEY_J released")

	main.cleanup_all_mobs()
	cannon.reset()
	press_key.call(KEY_SPACE)
	for i in range(8):
		main.step(1.0 / 60.0)
	assert_equal(main.get_live_blue_mobs_count(), 0, "No shot before 0.14s with KEY_SPACE")
	main.step(1.0 / 60.0)
	assert_equal(main.get_live_blue_mobs_count(), 1, "First shot fires at 0.15s with KEY_SPACE")
	release_key.call(KEY_SPACE)
	main.step(1.0 / 60.0)
	assert_equal(cannon.fire_accumulator, 0.0, "Accumulator resets to 0.0 when KEY_SPACE released")

	main.cleanup_all_mobs()
	if active_tree != null:
		active_tree.root.remove_child(main)
	main.free()

func test_scenario_9_freed_instance_safety_and_pruning() -> void:
	print("\nScenario 9: Freed Instance Safety, Parameter Untyping, and Dead Reference Pruning (GWT 1-4)")
	var main = MobControlMainScene.instantiate()
	var active_tree = _get_tree()
	if active_tree != null:
		active_tree.root.add_child(main)

	assert_equal(main.state, MobControlMainScript.GameState.PLAYING, "main.state initialized to PLAYING")

	# --- GWT 1a: Handling Synchronously Freed Objects in is_live ---
	var standalone_mob = MobUnit3DScene.instantiate()
	standalone_mob.free()
	assert_false(is_instance_valid(standalone_mob), "GWT 1a: is_instance_valid is false after mob.free()")
	assert_false(main.is_live(standalone_mob), "GWT 1a: is_live returns false for synchronously freed mob without error")

	# --- GWT 1b: Handling Queue-Freed Objects in is_live ---
	var q_mob = MobUnit3DScene.instantiate()
	main.add_child(q_mob)
	q_mob.queue_free()
	assert_true(q_mob.is_queued_for_deletion(), "GWT 1b: q_mob is queued for deletion")
	assert_false(main.is_live(q_mob), "GWT 1b: is_live returns false for queue_freed mob")

	# Clean up queue-freed object from tree
	main.remove_child(q_mob)
	q_mob.free()

	# Also verify null and consumed safety
	assert_false(main.is_live(null), "is_live returns false for null")
	var consumed_mob = MobUnit3DScene.instantiate()
	consumed_mob.is_consumed = true
	assert_false(main.is_live(consumed_mob), "is_live returns false for is_consumed mob")
	consumed_mob.free()

	# --- GWT 2 & 4: Synchronous mob.free() In-List Regression Suite for blue_mobs ---
	main.cleanup_all_mobs()
	var b_freed = main._spawn_blue_mob(Vector3(0.0, 0.5, 0.0))
	var b_survivor = main._spawn_blue_mob(Vector3(1.0, 0.5, 5.0))
	assert_true(b_freed != null, "GWT 2: b_freed mob non-null")
	assert_true(b_survivor != null, "GWT 2: b_survivor mob non-null")
	assert_equal(main.blue_mobs.size(), 2, "GWT 2: blue_mobs has 2 mobs initially")

	var b_survivor_initial_z = b_survivor.position.z

	# Destroy b_freed synchronously while reference remains in blue_mobs
	b_freed.free()
	assert_false(is_instance_valid(b_freed), "GWT 2: is_instance_valid(b_freed) is false after synchronous free")
	assert_equal(main.blue_mobs.size(), 2, "GWT 2: blue_mobs still holds 2 entries (including dead ref) before step()")

	# Calling is_live and get_live_blue_mobs_count synchronously with dead instance in list
	assert_false(main.is_live(b_freed), "GWT 2: is_live(b_freed) returns false on freed reference")
	assert_equal(main.get_live_blue_mobs_count(), 1, "GWT 2: get_live_blue_mobs_count() returns 1 (ignores dead instance)")

	# Calling step() synchronously must not raise SCRIPT ERROR and must prune the dead reference
	var delta: float = 1.0 / 60.0
	main.step(delta)

	assert_equal(main.blue_mobs.size(), 1, "GWT 2: blue_mobs pruned freed reference to size 1")
	assert_true(main.blue_mobs[0] == b_survivor, "GWT 2: surviving mob is the remaining element in blue_mobs")
	assert_true(b_survivor.position.z != b_survivor_initial_z, "GWT 2: surviving blue mob position.z changed")
	assert_equal(b_survivor.position.z, b_survivor_initial_z + MobControlMainScript.BLUE_SPEED * delta, "GWT 2: surviving blue mob moved by BLUE_SPEED * delta")

	# --- GWT 2 & 4: Synchronous mob.free() In-List Regression Suite for red_mobs ---
	main.cleanup_all_mobs()
	var r_freed = main._spawn_red_mob()
	var r_survivor = main._spawn_red_mob()
	assert_true(r_freed != null, "GWT 4: r_freed mob non-null")
	assert_true(r_survivor != null, "GWT 4: r_survivor mob non-null")
	assert_equal(main.red_mobs.size(), 2, "GWT 4: red_mobs has 2 mobs initially")

	var r_survivor_initial_z = r_survivor.position.z

	# Destroy r_freed synchronously while reference remains in red_mobs
	r_freed.free()
	assert_false(is_instance_valid(r_freed), "GWT 4: is_instance_valid(r_freed) is false after synchronous free")
	assert_equal(main.red_mobs.size(), 2, "GWT 4: red_mobs still holds 2 entries (including dead ref) before step()")

	# Calling is_live synchronously
	assert_false(main.is_live(r_freed), "GWT 4: is_live(r_freed) returns false on freed red mob reference")

	# Calling step() synchronously must not raise SCRIPT ERROR and must prune the dead reference
	main.step(delta)

	assert_equal(main.red_mobs.size(), 1, "GWT 4: red_mobs pruned freed reference to size 1")
	assert_true(main.red_mobs[0] == r_survivor, "GWT 4: surviving mob is the remaining element in red_mobs")
	assert_true(r_survivor.position.z != r_survivor_initial_z, "GWT 4: surviving red mob position.z changed")
	assert_equal(r_survivor.position.z, r_survivor_initial_z + MobControlMainScript.RED_SPEED * delta, "GWT 4: surviving red mob moved by RED_SPEED * delta")

	# Additional multi-element pruning verification: head, middle, tail
	main.cleanup_all_mobs()
	var mb1 = main._spawn_blue_mob(Vector3(0.0, 0.5, 0.0))
	var mb2 = main._spawn_blue_mob(Vector3(1.0, 0.5, 1.0))
	var mb3 = main._spawn_blue_mob(Vector3(2.0, 0.5, 2.0))
	var mb2_initial_z = mb2.position.z
	mb1.free()
	mb3.free()
	assert_equal(main.blue_mobs.size(), 3, "blue_mobs holds 3 entries before multi-prune step()")
	main.step(delta)
	assert_equal(main.blue_mobs.size(), 1, "blue_mobs pruned head and tail freed references to size 1")
	assert_true(main.blue_mobs[0] == mb2, "surviving middle mob mb2 remains")
	assert_equal(mb2.position.z, mb2_initial_z + MobControlMainScript.BLUE_SPEED * delta, "mb2 moved by BLUE_SPEED * delta")

	main.cleanup_all_mobs()
	if active_tree != null:
		active_tree.root.remove_child(main)
	main.free()



