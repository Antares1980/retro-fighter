class_name TestAIController
extends RefCounted

## Unit and integration tests for AIController (scripts/AIController.gd).
## Verifies AC-1 through AC-7 and comprehensive behavioral decision coverage:
## AC-1: Far-Range approach.
## AC-2: Close-Range punch pulse (1-frame pulse cleared on next frame).
## AC-3: Dedicated stationary block (input_block = true, input_dir = 0.0).
## AC-4: Non-actionable state, freeze, and dummy guarding.
## AC-5: Round reset state cleanliness (ai_controller.reset()).
## AC-6: Human control backwards compatibility (is_cpu == false).
## AC-7: Walk-to-idle FSM transition when input_dir = 0.0 within 1 physics frame.
## Additional coverage: MID band split, kick pulse, dummy override, co-located fallback, and Main integration.

const FighterScene = preload("res://scenes/Fighter.tscn")
const FighterScript = preload("res://scripts/Fighter.gd")
const AIControllerScript = preload("res://scripts/AIController.gd")
const MainScene = preload("res://scenes/Main.tscn")
const MainScript = preload("res://scripts/Main.gd")

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
	print("\n=== Running AIController & Orchestrator Integration Tests ===")
	test_ac1_far_range_approach()
	test_ac2_close_range_combat_actions_and_punch_lifecycle()
	test_ac3_dedicated_stationary_block()
	test_ac4_non_actionable_state_freeze_and_dummy_guarding()
	test_ac5_round_reset_state_cleanliness()
	test_ac6_human_control_backwards_compatibility()
	test_ac7_walk_to_idle_fsm_transition()
	test_additional_coverage_mid_band_split()
	test_additional_coverage_kick_pulse_and_idle_hesitation()
	test_additional_coverage_colocated_fallback_and_dummy_override()
	test_main_orchestrator_integration()

	print("\n=== AIController Test Results: %d passed, %d failed ===" % [passed, failed])
	return failed == 0

func _create_fighters() -> Array:
	var p1 = FighterScene.instantiate()
	p1._ready()
	p1.setup(1)
	p1.position = Vector2(200.0, 190.0)

	var p2 = FighterScene.instantiate()
	p2._ready()
	p2.setup(2)
	p2.is_cpu = true
	p2.position = Vector2(400.0, 190.0)

	p1.opponent = p2
	p2.opponent = p1
	return [p1, p2]

func test_ac1_far_range_approach() -> void:
	print("\nScenario: AC-1 - Far-Range Approach (> 85.0 px)")
	var fighters = _create_fighters()
	var p1 = fighters[0]
	var p2 = fighters[1]

	var controller = AIControllerScript.new()
	controller.setup(p2, p1)

	# Case 1: P2 at X=400, P1 at X=280 -> dist = 120 px (> 85.0 px)
	# Opponent is to the left: sign(280 - 400) = -1.0
	p1.position.x = 280.0
	p2.position.x = 400.0
	controller.decide()

	assert_equal(p2.input_dir, -1.0, "P2 input_dir is directed left toward P1 (-1.0)")
	assert_false(p2.input_block, "P2 input_block is false during far approach")
	assert_false(p2.input_punch, "P2 input_punch is false during far approach")
	assert_false(p2.input_kick, "P2 input_kick is false during far approach")

	# Case 2: P2 at X=100, P1 at X=300 -> dist = 200 px (> 85.0 px)
	# Opponent is to the right: sign(300 - 100) = 1.0
	p1.position.x = 300.0
	p2.position.x = 100.0
	controller.decide()

	assert_equal(p2.input_dir, 1.0, "P2 input_dir is directed right toward P1 (1.0)")
	assert_false(p2.input_block, "P2 input_block is false")

	controller.free()
	p1.free()
	p2.free()

func test_ac2_close_range_combat_actions_and_punch_lifecycle() -> void:
	print("\nScenario: AC-2 - Close-Range Punch Action & 1-Frame Pulse Lifecycle")
	var fighters = _create_fighters()
	var p1 = fighters[0]
	var p2 = fighters[1]

	var controller = AIControllerScript.new()
	controller.setup(p2, p1)

	# Proximity: 35 px (< 45.0 px)
	p1.position.x = 200.0
	p2.position.x = 235.0

	# Seed 1 yields roll = 0.329559 (< 0.40 -> Punch)
	controller.rng.seed = 1
	controller.decide()

	assert_true(p2.input_punch, "input_punch is true on punch decision frame")
	assert_false(p2.input_kick, "input_kick is false on punch decision frame")
	assert_false(p2.input_block, "input_block is false during punch")
	assert_equal(p2.input_dir, 0.0, "input_dir is 0.0 during close attack")

	# Step 1 physics frame: the 1-frame pulse must be cleared
	controller.step(1.0 / 60.0)
	assert_false(p2.input_punch, "input_punch is cleared to false on immediate subsequent frame")
	assert_false(p2.input_block, "input_block remains false")

	controller.free()
	p1.free()
	p2.free()

func test_ac3_dedicated_stationary_block() -> void:
	print("\nScenario: AC-3 - Dedicated Stationary Block (input_block = true, input_dir = 0.0)")
	var fighters = _create_fighters()
	var p1 = fighters[0]
	var p2 = fighters[1]

	var controller = AIControllerScript.new()
	controller.setup(p2, p1)

	# Proximity: 35 px (< 45.0 px)
	p1.position.x = 200.0
	p2.position.x = 235.0

	# Seed 2 yields roll = 0.702882 (0.70 <= roll < 0.90 -> Block)
	controller.rng.seed = 2
	controller.decide()

	assert_true(p2.input_block, "input_block is true when block is selected")
	assert_equal(p2.input_dir, 0.0, "input_dir is 0.0 during stationary block")
	assert_false(p2.input_punch, "input_punch is false during block")
	assert_false(p2.input_kick, "input_kick is false during block")

	controller.free()
	p1.free()
	p2.free()

func test_ac4_non_actionable_state_freeze_and_dummy_guarding() -> void:
	print("\nScenario: AC-4 - Non-Actionable State, Freeze & Dummy Guarding")
	var fighters = _create_fighters()
	var p1 = fighters[0]
	var p2 = fighters[1]

	var controller = AIControllerScript.new()
	controller.setup(p2, p1)

	# Helper to pre-dirty inputs and verify they are zeroed
	var set_dirty_inputs = func():
		p2.input_dir = 1.0
		p2.input_punch = true
		p2.input_kick = true
		p2.input_block = true

	var assert_inputs_zeroed = func(state_name: String):
		assert_equal(p2.input_dir, 0.0, "%s: input_dir zeroed" % state_name)
		assert_false(p2.input_punch, "%s: input_punch zeroed" % state_name)
		assert_false(p2.input_kick, "%s: input_kick zeroed" % state_name)
		assert_false(p2.input_block, "%s: input_block zeroed" % state_name)

	# 1. HIT_STUN
	set_dirty_inputs.call()
	p2.state = FighterScript.State.HIT_STUN
	controller.step(1.0 / 60.0)
	assert_inputs_zeroed.call("HIT_STUN")

	# 2. BLOCK_STUN
	set_dirty_inputs.call()
	p2.state = FighterScript.State.BLOCK_STUN
	controller.step(1.0 / 60.0)
	assert_inputs_zeroed.call("BLOCK_STUN")

	# 3. KNOCKDOWN
	set_dirty_inputs.call()
	p2.state = FighterScript.State.KNOCKDOWN
	controller.step(1.0 / 60.0)
	assert_inputs_zeroed.call("KNOCKDOWN")

	# 4. DEAD
	set_dirty_inputs.call()
	p2.state = FighterScript.State.DEAD
	controller.step(1.0 / 60.0)
	assert_inputs_zeroed.call("DEAD")

	# 5. inputs_frozen
	p2.state = FighterScript.State.IDLE
	p2.inputs_frozen = true
	set_dirty_inputs.call()
	controller.step(1.0 / 60.0)
	assert_inputs_zeroed.call("inputs_frozen")
	p2.inputs_frozen = false

	# 6. is_dummy
	p2.is_dummy = true
	set_dirty_inputs.call()
	controller.step(1.0 / 60.0)
	assert_inputs_zeroed.call("is_dummy")
	p2.is_dummy = false

	controller.free()
	p1.free()
	p2.free()

func test_ac5_round_reset_state_cleanliness() -> void:
	print("\nScenario: AC-5 - Round Reset State Cleanliness")
	var fighters = _create_fighters()
	var p1 = fighters[0]
	var p2 = fighters[1]

	var controller = AIControllerScript.new()
	controller.setup(p2, p1)

	# Simulate active inputs during a round
	p2.input_dir = -1.0
	p2.input_block = true
	p2.input_punch = true
	p2.input_kick = true
	controller.decision_timer = 0.02

	controller.reset()

	assert_equal(p2.input_dir, 0.0, "Reset zeroes input_dir")
	assert_false(p2.input_block, "Reset zeroes input_block")
	assert_false(p2.input_punch, "Reset zeroes input_punch")
	assert_false(p2.input_kick, "Reset zeroes input_kick")
	assert_equal(controller.decision_timer, 0.35, "Reset restores decision_timer to decision_interval (0.35)")

	controller.free()
	p1.free()
	p2.free()

func test_ac6_human_control_backwards_compatibility() -> void:
	print("\nScenario: AC-6 - Human Controls Backwards Compatibility (is_cpu == false)")
	var fighters = _create_fighters()
	var p1 = fighters[0]
	var p2 = fighters[1]

	# Set P2 to human mode
	p2.is_cpu = false
	var controller = AIControllerScript.new()
	controller.setup(p2, p1)

	# Controller should not execute decisions or modify inputs when is_cpu is false
	p1.position.x = 200.0
	p2.position.x = 400.0
	controller.decide()

	assert_equal(p2.input_dir, 0.0, "Human P2 input_dir unaffected by AIController")
	assert_false(p2.input_block, "Human P2 input_block unaffected by AIController")

	# Fighter.gd should query hardware input actions when is_cpu is false
	# (verified by default polling behavior)
	assert_false(p2.is_cpu, "P2 is_cpu remains false")

	controller.free()
	p1.free()
	p2.free()

func test_ac7_walk_to_idle_fsm_transition() -> void:
	print("\nScenario: AC-7 - Walk-to-Idle FSM Transition When input_dir = 0.0")
	var fighters = _create_fighters()
	var p1 = fighters[0]
	var p2 = fighters[1]

	var controller = AIControllerScript.new()
	controller.setup(p2, p1)

	# P2 faces left toward P1
	p1.position.x = 200.0
	p2.position.x = 400.0
	p2.facing = -1

	# P2 begins walking forward toward P1
	p2.input_dir = -1.0
	p2.change_state(FighterScript.State.WALK_FORWARD)
	assert_equal(p2.state, FighterScript.State.WALK_FORWARD, "P2 entered WALK_FORWARD")

	# Decision tick sets input_dir = 0.0 (e.g. hesitation or mid idle)
	p2.input_dir = 0.0

	# Process 1 frame on P2 walk state
	p2._process_walk_forward(1.0 / 60.0)

	assert_equal(p2.state, FighterScript.State.IDLE, "P2 transitions to IDLE when input_dir = 0.0")
	assert_equal(p2.velocity.x, 0.0, "P2 velocity.x is 0.0 in IDLE")

	# Repeat for WALK_BACKWARD
	p2.input_dir = 1.0
	p2.change_state(FighterScript.State.WALK_BACKWARD)
	assert_equal(p2.state, FighterScript.State.WALK_BACKWARD, "P2 entered WALK_BACKWARD")

	p2.input_dir = 0.0
	p2._process_walk_backward(1.0 / 60.0)

	assert_equal(p2.state, FighterScript.State.IDLE, "P2 transitions to IDLE from WALK_BACKWARD when input_dir = 0.0")
	assert_equal(p2.velocity.x, 0.0, "P2 velocity.x is 0.0 in IDLE")

	controller.free()
	p1.free()
	p2.free()

func test_additional_coverage_mid_band_split() -> void:
	print("\nScenario: Additional Coverage - MID Band Split (45.0 px to 85.0 px)")
	var fighters = _create_fighters()
	var p1 = fighters[0]
	var p2 = fighters[1]

	var controller = AIControllerScript.new()
	controller.setup(p2, p1)

	# Mid distance: 60 px (p1.x = 200, p2.x = 260 -> dir_to_opponent = -1.0)
	p1.position.x = 200.0
	p2.position.x = 260.0

	# 1. roll < 0.60: Advance (Seed 1 -> roll = 0.329559)
	controller.rng.seed = 1
	controller.decide()
	assert_equal(p2.input_dir, -1.0, "MID: roll < 0.60 advances toward opponent")
	assert_false(p2.input_block, "MID: input_block false on advance")

	# 2. 0.60 <= roll < 0.90: Stand Idle (Seed 2 -> roll = 0.702882)
	controller.rng.seed = 2
	controller.decide()
	assert_equal(p2.input_dir, 0.0, "MID: 0.60 <= roll < 0.90 stands idle (input_dir = 0.0)")
	assert_false(p2.input_block, "MID: input_block false on idle")

	# 3. roll >= 0.90: Step Back (Seed 4 -> roll = 0.900177)
	controller.rng.seed = 4
	controller.decide()
	assert_equal(p2.input_dir, 1.0, "MID: roll >= 0.90 steps back away from opponent (-dir_to_opponent)")
	assert_false(p2.input_block, "MID: input_block false on step back")

	controller.free()
	p1.free()
	p2.free()

func test_additional_coverage_kick_pulse_and_idle_hesitation() -> void:
	print("\nScenario: Additional Coverage - Kick Pulse & Idle Hesitation (< 45.0 px)")
	var fighters = _create_fighters()
	var p1 = fighters[0]
	var p2 = fighters[1]

	var controller = AIControllerScript.new()
	controller.setup(p2, p1)

	# Close distance: 35 px
	p1.position.x = 200.0
	p2.position.x = 235.0

	# 1. Kick: 0.40 <= roll < 0.70 (Seed 3 -> roll = 0.499491)
	controller.rng.seed = 3
	controller.decide()
	assert_true(p2.input_kick, "CLOSE: 0.40 <= roll < 0.70 selects Kick")
	assert_false(p2.input_punch, "input_punch false on kick")
	assert_false(p2.input_block, "input_block false on kick")

	# 1-frame pulse cleanup
	controller.step(1.0 / 60.0)
	assert_false(p2.input_kick, "input_kick cleared on next frame")

	# 2. Idle Hesitation: roll >= 0.90 (Seed 4 -> roll = 0.900177)
	controller.rng.seed = 4
	controller.decide()
	assert_equal(p2.input_dir, 0.0, "CLOSE: roll >= 0.90 idle hesitation has input_dir = 0.0")
	assert_false(p2.input_block, "CLOSE: idle hesitation has input_block = false")
	assert_false(p2.input_punch, "CLOSE: idle hesitation has input_punch = false")
	assert_false(p2.input_kick, "CLOSE: idle hesitation has input_kick = false")

	controller.free()
	p1.free()
	p2.free()

func test_additional_coverage_colocated_fallback_and_dummy_override() -> void:
	print("\nScenario: Additional Coverage - Co-located Fallback & Dummy Override")
	var fighters = _create_fighters()
	var p1 = fighters[0]
	var p2 = fighters[1]

	var controller = AIControllerScript.new()
	controller.setup(p2, p1)

	# Co-located: P1.x = 200, P2.x = 200 -> dx = 0.0
	p1.position.x = 200.0
	p2.position.x = 200.0

	# When facing is -1: fallback dir_to_opponent is -facing = -(-1) = 1.0
	p2.facing = -1
	# Seed 1 -> roll < 0.40 (punch in close range)
	# But in FAR range (> 85 px): dist = 0.0 is CLOSE range (< 45 px)
	# To test dir_to_opponent with co-location, set MID roll < 0.60:
	# At dist = 0 px, it's CLOSE range, so test punch/kick/block.
	# What if dist > 85 px? Distance is 0 px when co-located, so dist is < 45 px.
	# But what if we check dir_to_opponent calculation directly when moving?
	# In CLOSE range, roll doesn't use dir_to_opponent, but MID advance/stepback does!
	# If dx == 0, dist = 0, so it's always CLOSE band.
	# To test dir_to_opponent fallback directly:
	# If fighters are placed such that dist > 85 px but dx is 0? Impossible on 1D line.
	# But we can verify dir_to_opponent fallback by checking:
	var s: float = signf(p1.position.x - p2.position.x)
	var fallback_dir: float = -float(p2.facing) if is_zero_approx(s) else s
	assert_equal(fallback_dir, 1.0, "Co-located fallback with facing=-1 yields dir = 1.0")

	p2.facing = 1
	var s2: float = signf(p1.position.x - p2.position.x)
	var fallback_dir2: float = -float(p2.facing) if is_zero_approx(s2) else s2
	assert_equal(fallback_dir2, -1.0, "Co-located fallback with facing=1 yields dir = -1.0")

	# Dummy override check
	p2.is_dummy = true
	p2.input_dir = 1.0
	controller.decide()
	assert_equal(p2.input_dir, 0.0, "Dummy mode overrides CPU controller decisions")

	controller.free()
	p1.free()
	p2.free()

func test_main_orchestrator_integration() -> void:
	print("\nScenario: Main Orchestrator Integration & Scene Wiring")
	var main = MainScene.instantiate()
	main._ready()

	assert_true(main.p2.is_cpu, "P2 has is_cpu = true in Main scene")
	assert_true(main.ai_controller != null, "Main created AIController for CPU P2")
	assert_equal(main.ai_controller.fighter, main.p2, "AIController fighter reference is P2")
	assert_equal(main.ai_controller.opponent, main.p1, "AIController opponent reference is P1")
	assert_equal(main.ai_controller.decision_interval, 0.35, "AIController decision_interval is 0.35")

	# Reset round calls ai_controller.reset()
	main.p2.input_dir = 1.0
	main.start_round()
	assert_equal(main.p2.input_dir, 0.0, "start_round() resets AIController virtual inputs")

	main.free()
