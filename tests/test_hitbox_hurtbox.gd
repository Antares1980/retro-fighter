class_name TestHitboxHurtbox
extends RefCounted

const Hitbox = preload("res://scripts/Hitbox.gd")
const Hurtbox = preload("res://scripts/Hurtbox.gd")

## Unit and integration tests for Hitbox & Hurtbox system,
## 7-layer bitmasks, setup(player_id), and one-shot hit registration.

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
	print("\n=== Running Retro Fighter Hitbox & Hurtbox Tests ===")
	test_layer_constants()
	test_hitbox_setup_p1_and_p2()
	test_hurtbox_setup_p1_and_p2()
	test_collision_matrix_isolation()
	test_hitbox_oneshot_registration()
	test_attack_presets_and_facing()
	test_hurtbox_geometry_and_crouching()
	test_hurtbox_hit_reception_and_dispatch()
	test_hurtbox_invulnerability()
	test_signals_emission()

	print("\n=== Test Results: %d passed, %d failed ===" % [passed, failed])
	return failed == 0

func test_layer_constants() -> void:
	print("\nScenario: 7-Layer Collision Bitmask Constants")
	assert_equal(Hitbox.LAYER_WORLDFLOOR, 1, "Layer 1 is WorldFloor")
	assert_equal(Hitbox.LAYER_FIGHTERBODY, 2, "Layer 2 is FighterBody")
	assert_equal(Hitbox.LAYER_STAGEWALL, 3, "Layer 3 is StageWall")
	assert_equal(Hitbox.LAYER_P1_HURTBOX, 4, "Layer 4 is P1_Hurtbox")
	assert_equal(Hitbox.LAYER_P1_HITBOX, 5, "Layer 5 is P1_Hitbox")
	assert_equal(Hitbox.LAYER_P2_HURTBOX, 6, "Layer 6 is P2_Hurtbox")
	assert_equal(Hitbox.LAYER_P2_HITBOX, 7, "Layer 7 is P2_Hitbox")

	assert_equal(Hitbox.MASK_WORLDFLOOR, 1, "Mask WorldFloor is 1 (bit 1)")
	assert_equal(Hitbox.MASK_FIGHTERBODY, 2, "Mask FighterBody is 2 (bit 2)")
	assert_equal(Hitbox.MASK_STAGEWALL, 4, "Mask StageWall is 4 (bit 3)")
	assert_equal(Hitbox.MASK_P1_HURTBOX, 8, "Mask P1_Hurtbox is 8 (bit 4)")
	assert_equal(Hitbox.MASK_P1_HITBOX, 16, "Mask P1_Hitbox is 16 (bit 5)")
	assert_equal(Hitbox.MASK_P2_HURTBOX, 32, "Mask P2_Hurtbox is 32 (bit 6)")
	assert_equal(Hitbox.MASK_P2_HITBOX, 64, "Mask P2_Hitbox is 64 (bit 7)")

func test_hitbox_setup_p1_and_p2() -> void:
	print("\nScenario: Hitbox setup(player_id) Parameterization")
	var hit_p1 = Hitbox.new()
	hit_p1.setup(1)
	assert_equal(hit_p1.player_id, 1, "Hitbox P1 has player_id 1")
	assert_equal(hit_p1.collision_layer, Hitbox.MASK_P1_HITBOX, "Hitbox P1 collision_layer is Layer 5 (16)")
	assert_equal(hit_p1.collision_mask, Hitbox.MASK_P2_HURTBOX, "Hitbox P1 collision_mask is Layer 6 (32)")
	assert_true(hit_p1.get_collision_layer_value(5), "Hitbox P1 layer 5 is true")
	assert_false(hit_p1.get_collision_layer_value(4), "Hitbox P1 layer 4 is false")
	assert_false(hit_p1.get_collision_layer_value(6), "Hitbox P1 layer 6 is false")
	assert_false(hit_p1.get_collision_layer_value(7), "Hitbox P1 layer 7 is false")
	assert_true(hit_p1.get_collision_mask_value(6), "Hitbox P1 mask 6 is true")
	assert_false(hit_p1.get_collision_mask_value(4), "Hitbox P1 mask 4 is false")
	hit_p1.free()

	var hit_p2 = Hitbox.new()
	hit_p2.setup(2)
	assert_equal(hit_p2.player_id, 2, "Hitbox P2 has player_id 2")
	assert_equal(hit_p2.collision_layer, Hitbox.MASK_P2_HITBOX, "Hitbox P2 collision_layer is Layer 7 (64)")
	assert_equal(hit_p2.collision_mask, Hitbox.MASK_P1_HURTBOX, "Hitbox P2 collision_mask is Layer 4 (8)")
	assert_true(hit_p2.get_collision_layer_value(7), "Hitbox P2 layer 7 is true")
	assert_false(hit_p2.get_collision_layer_value(5), "Hitbox P2 layer 5 is false")
	assert_true(hit_p2.get_collision_mask_value(4), "Hitbox P2 mask 4 is true")
	assert_false(hit_p2.get_collision_mask_value(6), "Hitbox P2 mask 6 is false")
	hit_p2.free()

	var hit_invalid = Hitbox.new()
	hit_invalid.setup(0)
	assert_equal(hit_invalid.collision_layer, 0, "Invalid setup player_id clears collision_layer to 0")
	assert_equal(hit_invalid.collision_mask, 0, "Invalid setup player_id clears collision_mask to 0")
	hit_invalid.free()

func test_hurtbox_setup_p1_and_p2() -> void:
	print("\nScenario: Hurtbox setup(player_id) Parameterization")
	var hurt_p1 = Hurtbox.new()
	hurt_p1.setup(1)
	assert_equal(hurt_p1.player_id, 1, "Hurtbox P1 has player_id 1")
	assert_equal(hurt_p1.collision_layer, Hurtbox.MASK_P1_HURTBOX, "Hurtbox P1 collision_layer is Layer 4 (8)")
	assert_equal(hurt_p1.collision_mask, 0, "Hurtbox P1 collision_mask is None (0)")
	assert_true(hurt_p1.get_collision_layer_value(4), "Hurtbox P1 layer 4 is true")
	assert_false(hurt_p1.get_collision_layer_value(6), "Hurtbox P1 layer 6 is false")
	hurt_p1.free()

	var hurt_p2 = Hurtbox.new()
	hurt_p2.setup(2)
	assert_equal(hurt_p2.player_id, 2, "Hurtbox P2 has player_id 2")
	assert_equal(hurt_p2.collision_layer, Hurtbox.MASK_P2_HURTBOX, "Hurtbox P2 collision_layer is Layer 6 (32)")
	assert_equal(hurt_p2.collision_mask, 0, "Hurtbox P2 collision_mask is None (0)")
	assert_true(hurt_p2.get_collision_layer_value(6), "Hurtbox P2 layer 6 is true")
	assert_false(hurt_p2.get_collision_layer_value(4), "Hurtbox P2 layer 4 is false")
	hurt_p2.free()

	var hurt_invalid = Hurtbox.new()
	hurt_invalid.setup(99)
	assert_equal(hurt_invalid.collision_layer, 0, "Invalid player_id clears hurtbox layer to 0")
	assert_equal(hurt_invalid.collision_mask, 0, "Invalid player_id clears hurtbox mask to 0")
	hurt_invalid.free()

func test_collision_matrix_isolation() -> void:
	print("\nScenario: Collision Matrix Interaction & Friendly-Fire Isolation")
	var hit_p1 = Hitbox.new()
	var hit_p2 = Hitbox.new()
	var hurt_p1 = Hurtbox.new()
	var hurt_p2 = Hurtbox.new()

	hit_p1.setup(1)
	hit_p2.setup(2)
	hurt_p1.setup(1)
	hurt_p2.setup(2)

	# P1 Hitbox detects P2 Hurtbox
	var p1_hits_p2: bool = (hit_p1.collision_mask & hurt_p2.collision_layer) != 0
	assert_true(p1_hits_p2, "P1 Hitbox mask overlaps P2 Hurtbox layer (hits opponent)")

	# P1 Hitbox does NOT detect P1 Hurtbox (no friendly fire)
	var p1_hits_p1: bool = (hit_p1.collision_mask & hurt_p1.collision_layer) != 0
	assert_false(p1_hits_p1, "P1 Hitbox mask does NOT overlap P1 Hurtbox layer (no friendly-fire)")

	# P2 Hitbox detects P1 Hurtbox
	var p2_hits_p1: bool = (hit_p2.collision_mask & hurt_p1.collision_layer) != 0
	assert_true(p2_hits_p1, "P2 Hitbox mask overlaps P1 Hurtbox layer (hits opponent)")

	# P2 Hitbox does NOT detect P2 Hurtbox (no friendly fire)
	var p2_hits_p2: bool = (hit_p2.collision_mask & hurt_p2.collision_layer) != 0
	assert_false(p2_hits_p2, "P2 Hitbox mask does NOT overlap P2 Hurtbox layer (no friendly-fire)")

	# Hitboxes do not detect environment / bodies
	assert_equal(hit_p1.collision_mask & Hitbox.MASK_WORLDFLOOR, 0, "P1 Hitbox ignores WorldFloor")
	assert_equal(hit_p1.collision_mask & Hitbox.MASK_FIGHTERBODY, 0, "P1 Hitbox ignores FighterBody")
	assert_equal(hit_p1.collision_mask & Hitbox.MASK_STAGEWALL, 0, "P1 Hitbox ignores StageWall")

	assert_equal(hit_p2.collision_mask & Hitbox.MASK_WORLDFLOOR, 0, "P2 Hitbox ignores WorldFloor")
	assert_equal(hit_p2.collision_mask & Hitbox.MASK_FIGHTERBODY, 0, "P2 Hitbox ignores FighterBody")
	assert_equal(hit_p2.collision_mask & Hitbox.MASK_STAGEWALL, 0, "P2 Hitbox ignores StageWall")

	# Hurtbox masks do not monitor any layer
	assert_equal(hurt_p1.collision_mask, 0, "P1 Hurtbox collision_mask is 0")
	assert_equal(hurt_p2.collision_mask, 0, "P2 Hurtbox collision_mask is 0")

	hit_p1.free()
	hit_p2.free()
	hurt_p1.free()
	hurt_p2.free()

func test_hitbox_oneshot_registration() -> void:
	print("\nScenario: Hitbox One-Shot Registration (hit_consumed)")
	var hitbox = Hitbox.new()
	hitbox.setup(1)
	hitbox.configure_punch(1)

	var hurtbox = Hurtbox.new()
	hurtbox.setup(2)

	assert_false(hitbox.hit_consumed, "Initial hit_consumed is false")

	# First hit lands successfully
	var hit1_result = hitbox.trigger_hit(hurtbox)
	assert_true(hit1_result, "First hit attempt returns true (hit landed)")
	assert_true(hitbox.hit_consumed, "hit_consumed becomes true after landing hit")

	# Subsequent hit attempts during the same swing must be blocked (one-shot registration)
	var hit2_result = hitbox.trigger_hit(hurtbox)
	assert_false(hit2_result, "Second hit attempt during same swing returns false (hit consumed)")

	var hurtbox2 = Hurtbox.new()
	hurtbox2.setup(2)
	var hit3_result = hitbox.trigger_hit(hurtbox2)
	assert_false(hit3_result, "Hit on another hurtbox while hit_consumed is true is also blocked")
	hurtbox2.free()

	# Reset hit restores one-shot registration
	hitbox.reset_hit()
	assert_false(hitbox.hit_consumed, "reset_hit() resets hit_consumed to false")
	var hit4_result = hitbox.trigger_hit(hurtbox)
	assert_true(hit4_result, "Hit lands again after reset_hit()")

	# activate() also resets hit_consumed
	hitbox.activate()
	assert_false(hitbox.hit_consumed, "activate() resets hit_consumed to false")

	# set_attack() also resets hit_consumed
	hitbox.trigger_hit(hurtbox)
	assert_true(hitbox.hit_consumed, "Hit consumed again")
	hitbox.set_attack(10, 10, 5, 20.0, false)
	assert_false(hitbox.hit_consumed, "set_attack() resets hit_consumed to false")

	hitbox.free()
	hurtbox.free()

func test_attack_presets_and_facing() -> void:
	print("\nScenario: Attack Presets and Facing Direction Horizontal Offsets")
	var hitbox = Hitbox.new()
	var col_shape = CollisionShape2D.new()
	col_shape.shape = RectangleShape2D.new()
	hitbox.add_child(col_shape)

	# Punch Facing Right (+1)
	hitbox.configure_punch(1)
	assert_equal(hitbox.damage, 8, "Punch damage is 8")
	assert_equal(hitbox.hit_stun_ticks, 12, "Punch hit stun is 12 ticks")
	assert_equal(hitbox.block_stun_ticks, 6, "Punch block stun is 6 ticks")
	assert_equal(hitbox.knockback_x, 40.0, "Punch knockback is 40.0 px/s")
	assert_false(hitbox.is_low, "Punch is high (is_low = false)")
	assert_equal(col_shape.position, Vector2(20, -36), "Punch facing right offset is (20, -36)")
	assert_equal((col_shape.shape as RectangleShape2D).size, Vector2(24, 12), "Punch shape size is (24, 12)")

	# Punch Facing Left (-1)
	hitbox.configure_punch(-1)
	assert_equal(col_shape.position, Vector2(-20, -36), "Punch facing left offset is (-20, -36)")

	# Kick Facing Right (+1)
	hitbox.configure_kick(1)
	assert_equal(hitbox.damage, 14, "Kick damage is 14")
	assert_equal(hitbox.hit_stun_ticks, 18, "Kick hit stun is 18 ticks")
	assert_equal(hitbox.block_stun_ticks, 8, "Kick block stun is 8 ticks")
	assert_equal(hitbox.knockback_x, 80.0, "Kick knockback is 80.0 px/s")
	assert_true(hitbox.is_low, "Kick is low (is_low = true)")
	assert_equal(col_shape.position, Vector2(24, -12), "Kick facing right offset is (24, -12)")
	assert_equal((col_shape.shape as RectangleShape2D).size, Vector2(30, 12), "Kick shape size is (30, 12)")

	# Kick Facing Left (-1)
	hitbox.configure_kick(-1)
	assert_equal(col_shape.position, Vector2(-24, -12), "Kick facing left offset is (-24, -12)")

	hitbox.free()

func test_hurtbox_geometry_and_crouching() -> void:
	print("\nScenario: Hurtbox Geometry & Standing/Crouching Dimensions")
	var hurtbox = Hurtbox.new()
	var col_shape = CollisionShape2D.new()
	col_shape.shape = RectangleShape2D.new()
	hurtbox.add_child(col_shape)

	# Standing defaults
	assert_equal(Hurtbox.STANDING_SIZE, Vector2(24.0, 54.0), "Standing hurtbox size is 24x54 px")
	assert_equal(Hurtbox.STANDING_OFFSET, Vector2(0.0, -27.0), "Standing hurtbox offset is (0, -27)")
	assert_equal(Hurtbox.CROUCHING_SIZE, Vector2(24.0, 32.0), "Crouching hurtbox size is 24x32 px")
	assert_equal(Hurtbox.CROUCHING_OFFSET, Vector2(0.0, -16.0), "Crouching hurtbox offset is (0, -16)")

	# Initial setup standing
	hurtbox.set_crouching(false)
	assert_false(hurtbox.is_crouching, "is_crouching is false")
	assert_equal(col_shape.position, Vector2(0.0, -27.0), "Standing collision shape offset is (0, -27)")
	assert_equal((col_shape.shape as RectangleShape2D).size, Vector2(24.0, 54.0), "Standing collision shape size is 24x54")

	# Transition to crouching
	hurtbox.set_crouching(true)
	assert_true(hurtbox.is_crouching, "is_crouching is true")
	assert_equal(col_shape.position, Vector2(0.0, -16.0), "Crouching collision shape offset is (0, -16)")
	assert_equal((col_shape.shape as RectangleShape2D).size, Vector2(24.0, 32.0), "Crouching collision shape size is 24x32")

	# Return to standing
	hurtbox.set_crouching(false)
	assert_false(hurtbox.is_crouching, "is_crouching returned to false")
	assert_equal(col_shape.position, Vector2(0.0, -27.0), "Restored collision shape offset is (0, -27)")
	assert_equal((col_shape.shape as RectangleShape2D).size, Vector2(24.0, 54.0), "Restored collision shape size is 24x54")

	hurtbox.free()

# Helper mock class to verify fighter receive_hit dispatch
class MockFighter extends Node:
	var received_damage: int = -1
	var received_hit_stun: int = -1
	var received_block_stun: int = -1
	var received_knockback: float = -1.0
	var received_is_low: bool = false
	var received_attacker: Node = null

	func receive_hit(
		damage: int,
		hit_stun_ticks: int,
		block_stun_ticks: int,
		knockback_x: float,
		is_low: bool,
		attacker: CharacterBody2D
	) -> void:
		received_damage = damage
		received_hit_stun = hit_stun_ticks
		received_block_stun = block_stun_ticks
		received_knockback = knockback_x
		received_is_low = is_low
		received_attacker = attacker

func test_hurtbox_hit_reception_and_dispatch() -> void:
	print("\nScenario: Hurtbox Hit Reception & Fighter Dispatch Contract")
	var mock_fighter = MockFighter.new()
	var hurtbox = Hurtbox.new()
	hurtbox.fighter = mock_fighter

	var hitbox = Hitbox.new()
	hitbox.configure_punch(1, null)

	var accepted = hurtbox.take_hit(hitbox)
	assert_true(accepted, "take_hit returned true")
	assert_equal(mock_fighter.received_damage, 8, "MockFighter received damage 8")
	assert_equal(mock_fighter.received_hit_stun, 12, "MockFighter received hit stun 12 ticks")
	assert_equal(mock_fighter.received_block_stun, 6, "MockFighter received block stun 6 ticks")
	assert_equal(mock_fighter.received_knockback, 40.0, "MockFighter received knockback 40.0 px/s")
	assert_false(mock_fighter.received_is_low, "MockFighter received is_low = false")

	# Test Kick dispatch
	hitbox.configure_kick(1, null)
	hurtbox.take_hit(hitbox)
	assert_equal(mock_fighter.received_damage, 14, "MockFighter received kick damage 14")
	assert_equal(mock_fighter.received_hit_stun, 18, "MockFighter received kick hit stun 18 ticks")
	assert_equal(mock_fighter.received_block_stun, 8, "MockFighter received kick block stun 8 ticks")
	assert_equal(mock_fighter.received_knockback, 80.0, "MockFighter received kick knockback 80.0 px/s")
	assert_true(mock_fighter.received_is_low, "MockFighter received kick is_low = true")

	hitbox.free()
	hurtbox.free()
	mock_fighter.free()

func test_hurtbox_invulnerability() -> void:
	print("\nScenario: Hurtbox Invulnerability Flag")
	var hurtbox = Hurtbox.new()
	hurtbox.is_invulnerable = true

	var hitbox = Hitbox.new()
	hitbox.configure_punch(1)

	var hit_result = hitbox.trigger_hit(hurtbox)
	assert_false(hit_result, "Hit on invulnerable hurtbox is rejected")
	assert_false(hitbox.hit_consumed, "Hitbox hit_consumed remains false when rejected by invulnerability")

	hurtbox.is_invulnerable = false
	var hit_result2 = hitbox.trigger_hit(hurtbox)
	assert_true(hit_result2, "Hit on vulnerable hurtbox succeeds")
	assert_true(hitbox.hit_consumed, "Hitbox hit_consumed becomes true")

	hitbox.free()
	hurtbox.free()

func test_signals_emission() -> void:
	print("\nScenario: Hitbox and Hurtbox Signals Emission")
	var hitbox = Hitbox.new()
	var hurtbox = Hurtbox.new()

	var events = {
		"hit_landed": false,
		"hit_received": false
	}

	hitbox.hit_landed.connect(func(_target): events["hit_landed"] = true)
	hurtbox.hit_received.connect(func(_source): events["hit_received"] = true)

	var hit_result = hitbox.trigger_hit(hurtbox)
	assert_true(hit_result, "trigger_hit succeeded")
	assert_true(events["hit_landed"], "Hitbox emitted hit_landed signal")
	assert_true(events["hit_received"], "Hurtbox emitted hit_received signal")

	hitbox.free()
	hurtbox.free()
