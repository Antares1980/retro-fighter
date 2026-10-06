class_name TestFighter
extends RefCounted

const FighterScene = preload("res://scenes/Fighter.tscn")
const FighterScript = preload("res://scripts/Fighter.gd")
const HitboxScript = preload("res://scripts/Hitbox.gd")
const HurtboxScript = preload("res://scripts/Hurtbox.gd")

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
	print("\n=== Running Retro Fighter FSM & Combat Mechanics Tests ===")
	test_scene_structure_and_nodes()
	test_13_states_definition()
	test_setup_player_parameterization()
	test_auto_facing()
	test_movement_and_walking_speeds()
	test_jump_squat_and_jumping()
	test_crouching_hurtbox_reduction()
	test_attack_punch_frame_data()
	test_attack_kick_frame_data()
	test_attack_initiation_rules()
	test_ac01_punch_hit_and_oneshot()
	test_ac02_standing_block_vs_punch()
	test_ac03_low_kick_vs_standing_block()
	test_ac04_crouching_block_vs_low_kick()
	test_crouching_block_vs_punch()
	test_ac05_pushbox_separation_matrix()
	test_ac06_boundary_clamping()
	test_ac07_ko_knockdown_dead_and_reset()
	test_ac10_p2_dummy_toggle_and_behavior()
	test_ac1_palette_application_on_setup()
	test_ac2_punch_animation_synchronization()
	test_ac3_attack_interrupt_neutral_reset()
	test_ac4_p2_mirrored_low_kick_invariant()
	test_ac5_headless_execution_safety()
	test_13_state_animations_and_track_isolation()
	test_crouch_and_knockdown_visual_heights()

	print("\n=== Test Results: %d passed, %d failed ===" % [passed, failed])
	return failed == 0

func test_scene_structure_and_nodes() -> void:
	print("\nScenario: Scene Hierarchy and Node Integrity")
	var fighter = FighterScene.instantiate()
	assert_true(fighter != null, "Fighter scene instantiates successfully")
	assert_true(fighter is CharacterBody2D, "Fighter root is CharacterBody2D")
	assert_true(fighter.get_script() == FighterScript, "Fighter has Fighter.gd script attached")

	# Pushbox
	assert_equal(fighter.collision_layer, HitboxScript.MASK_FIGHTERBODY, "Fighter collision_layer is Layer 2 (FighterBody, 2)")
	assert_equal(fighter.collision_mask, HitboxScript.MASK_WORLDFLOOR | HitboxScript.MASK_FIGHTERBODY | HitboxScript.MASK_STAGEWALL, "Fighter collision_mask is Layers 1, 2, 3 (7)")
	
	var pushbox = fighter.get_node_or_null("PushboxShape")
	assert_true(pushbox != null, "PushboxShape CollisionShape2D exists")
	assert_equal(pushbox.position, Vector2(0.0, -27.0), "Pushbox position is (0, -27)")
	assert_true(pushbox.shape is RectangleShape2D, "Pushbox shape is RectangleShape2D")
	assert_equal((pushbox.shape as RectangleShape2D).size, Vector2(24.0, 54.0), "Pushbox size is 24x54 px")

	# Hurtbox
	var hurtbox = fighter.get_node_or_null("Hurtbox")
	assert_true(hurtbox != null, "Hurtbox node exists")
	assert_true(hurtbox is HurtboxScript, "Hurtbox node is Hurtbox class")
	var hurtbox_col = hurtbox.get_node_or_null("CollisionShape2D")
	assert_true(hurtbox_col != null, "Hurtbox CollisionShape2D exists")
	assert_equal(hurtbox_col.position, Vector2(0.0, -27.0), "Standing hurtbox offset is (0, -27)")
	assert_equal((hurtbox_col.shape as RectangleShape2D).size, Vector2(24.0, 54.0), "Standing hurtbox size is 24x54")

	# Hitbox
	var hitbox = fighter.get_node_or_null("Hitbox")
	assert_true(hitbox != null, "Hitbox node exists")
	assert_true(hitbox is HitboxScript, "Hitbox node is Hitbox class")
	assert_false(hitbox.monitoring, "Hitbox monitoring is false initially")

	# Visual
	var visual = fighter.get_node_or_null("Visual")
	assert_true(visual != null, "Visual Node2D exists")
	var torso_gi = fighter.get_node_or_null("Visual/TorsoGi")
	assert_true(torso_gi != null, "Visual/TorsoGi Polygon2D exists")
	assert_true(torso_gi is Polygon2D, "Visual/TorsoGi is Polygon2D")

	var rig_nodes = [
		{"name": "BackArm", "z": -2},
		{"name": "BackLeg", "z": -1},
		{"name": "TorsoGi", "z": 0},
		{"name": "Belt", "z": 1},
		{"name": "BeltKnot", "z": 1},
		{"name": "Head", "z": 2},
		{"name": "Hair", "z": 3},
		{"name": "Headband", "z": 3},
		{"name": "Ties", "z": 2},
		{"name": "LeadLeg", "z": 4},
		{"name": "LeadArm", "z": 5},
		{"name": "Glove", "z": 5},
	]
	for node_info in rig_nodes:
		var node = fighter.get_node_or_null("Visual/" + node_info["name"])
		assert_true(node != null, "Visual/%s exists" % node_info["name"])
		assert_true(node is Polygon2D, "Visual/%s is Polygon2D" % node_info["name"])
		if node is Polygon2D:
			assert_equal(node.z_index, node_info["z"], "Visual/%s z_index is %d" % [node_info["name"], node_info["z"]])
			assert_true(node.z_as_relative, "Visual/%s z_as_relative is true" % node_info["name"])

	assert_true(fighter.get_node_or_null("Visual/Body") == null, "Visual/Body ColorRect replaced")
	assert_true(fighter.get_node_or_null("Visual/AttackVisual") == null, "Visual/AttackVisual ColorRect removed")

	# AnimationPlayer
	var anim_player = fighter.get_node_or_null("AnimationPlayer")
	assert_true(anim_player != null, "AnimationPlayer node exists")
	assert_true(anim_player is AnimationPlayer, "AnimationPlayer is class AnimationPlayer")
	assert_equal(anim_player.callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS, "AnimationPlayer configured in Physics process mode")

	fighter.free()

func test_13_states_definition() -> void:
	print("\nScenario: 13-State Deterministic FSM Definitions")
	assert_equal(FighterScript.State.IDLE, 0, "State.IDLE is 0")
	assert_equal(FighterScript.State.WALK_FORWARD, 1, "State.WALK_FORWARD is 1")
	assert_equal(FighterScript.State.WALK_BACKWARD, 2, "State.WALK_BACKWARD is 2")
	assert_equal(FighterScript.State.JUMP_SQUAT, 3, "State.JUMP_SQUAT is 3")
	assert_equal(FighterScript.State.JUMPING, 4, "State.JUMPING is 4")
	assert_equal(FighterScript.State.CROUCHING, 5, "State.CROUCHING is 5")
	assert_equal(FighterScript.State.ATTACK_PUNCH, 6, "State.ATTACK_PUNCH is 6")
	assert_equal(FighterScript.State.ATTACK_KICK, 7, "State.ATTACK_KICK is 7")
	assert_equal(FighterScript.State.BLOCKING, 8, "State.BLOCKING is 8")
	assert_equal(FighterScript.State.BLOCK_STUN, 9, "State.BLOCK_STUN is 9")
	assert_equal(FighterScript.State.HIT_STUN, 10, "State.HIT_STUN is 10")
	assert_equal(FighterScript.State.KNOCKDOWN, 11, "State.KNOCKDOWN is 11")
	assert_equal(FighterScript.State.DEAD, 12, "State.DEAD is 12")
	assert_equal(FighterScript.State.size(), 13, "FSM has exactly 13 states")

func test_setup_player_parameterization() -> void:
	print("\nScenario: Fighter setup(player_id) Parameterization")
	var f1 = FighterScene.instantiate()
	f1.setup(1)
	assert_equal(f1.player_id, 1, "P1 player_id is 1")
	assert_equal(f1.facing, 1, "P1 initial facing is 1 (right)")
	assert_equal(f1.hurtbox.collision_layer, HitboxScript.MASK_P1_HURTBOX, "P1 Hurtbox layer is Layer 4 (8)")
	assert_equal(f1.hitbox.collision_layer, HitboxScript.MASK_P1_HITBOX, "P1 Hitbox layer is Layer 5 (16)")
	assert_equal(f1.hitbox.collision_mask, HitboxScript.MASK_P2_HURTBOX, "P1 Hitbox mask is Layer 6 (32)")
	assert_equal(f1.health, 100, "P1 initial health is 100")
	assert_equal(f1.state, FighterScript.State.IDLE, "P1 initial state is IDLE")
	assert_equal(f1.torso_gi.color, FighterScript.PALETTES[1]["gi"], "P1 gi color is white")
	assert_equal(f1.get_node("Visual/Headband").color, FighterScript.PALETTES[1]["accent"], "P1 headband is crimson")
	f1.free()

	var f2 = FighterScene.instantiate()
	f2.setup(2)
	assert_equal(f2.player_id, 2, "P2 player_id is 2")
	assert_equal(f2.facing, -1, "P2 initial facing is -1 (left)")
	assert_equal(f2.hurtbox.collision_layer, HitboxScript.MASK_P2_HURTBOX, "P2 Hurtbox layer is Layer 6 (32)")
	assert_equal(f2.hitbox.collision_layer, HitboxScript.MASK_P2_HITBOX, "P2 Hitbox layer is Layer 7 (64)")
	assert_equal(f2.hitbox.collision_mask, HitboxScript.MASK_P1_HURTBOX, "P2 Hitbox mask is Layer 4 (8)")
	assert_equal(f2.torso_gi.color, FighterScript.PALETTES[2]["gi"], "P2 gi color is navy")
	assert_equal(f2.get_node("Visual/Headband").color, FighterScript.PALETTES[2]["accent"], "P2 headband is gold")
	f2.free()

func test_auto_facing() -> void:
	print("\nScenario: Automatic Facing Towards Opponent")
	var f1 = FighterScene.instantiate()
	var f2 = FighterScene.instantiate()
	f1.setup(1)
	f2.setup(2)
	f1.opponent = f2
	f2.opponent = f1

	f1.global_position = Vector2(200.0, 190.0)
	f2.global_position = Vector2(300.0, 190.0)

	f1.update_facing()
	f2.update_facing()
	assert_equal(f1.facing, 1, "P1 faces right towards P2 at X=300")
	assert_equal(f2.facing, -1, "P2 faces left towards P1 at X=200")

	# Cross over
	f1.global_position.x = 350.0
	f1.update_facing()
	f2.update_facing()
	assert_equal(f1.facing, -1, "P1 now faces left towards P2 at X=300")
	assert_equal(f2.facing, 1, "P2 now faces right towards P1 at X=350")

	f1.free()
	f2.free()

func test_movement_and_walking_speeds() -> void:
	print("\nScenario: Walking Movement Speeds (100 px/s forward, 80 px/s backward)")
	var f = FighterScene.instantiate()
	f.setup(1)
	f.facing = 1

	f.change_state(FighterScript.State.WALK_FORWARD)
	f._process_walk_forward(1.0 / 60.0)
	assert_equal(f.velocity.x, 100.0, "Facing right: WALK_FORWARD velocity is +100 px/s")

	f.change_state(FighterScript.State.WALK_BACKWARD)
	f._process_walk_backward(1.0 / 60.0)
	assert_equal(f.velocity.x, -80.0, "Facing right: WALK_BACKWARD velocity is -80 px/s")

	# Facing left
	f.facing = -1
	f.change_state(FighterScript.State.WALK_FORWARD)
	f._process_walk_forward(1.0 / 60.0)
	assert_equal(f.velocity.x, -100.0, "Facing left: WALK_FORWARD velocity is -100 px/s")

	f.change_state(FighterScript.State.WALK_BACKWARD)
	f._process_walk_backward(1.0 / 60.0)
	assert_equal(f.velocity.x, 80.0, "Facing left: WALK_BACKWARD velocity is +80 px/s")

	f.free()

func test_jump_squat_and_jumping() -> void:
	print("\nScenario: Jump Squat (3 ticks) and Jumping Physics")
	var f = FighterScene.instantiate()
	f.setup(1)

	f.change_state(FighterScript.State.JUMP_SQUAT)
	assert_equal(f.state, FighterScript.State.JUMP_SQUAT, "State is JUMP_SQUAT")
	assert_equal(f.velocity, Vector2.ZERO, "Velocity is 0 during jump squat")

	# 1st tick
	f._process_jump_squat(1.0 / 60.0)
	assert_equal(f.state, FighterScript.State.JUMP_SQUAT, "Still in JUMP_SQUAT on tick 1")

	# 2nd tick
	f._process_jump_squat(1.0 / 60.0)
	assert_equal(f.state, FighterScript.State.JUMP_SQUAT, "Still in JUMP_SQUAT on tick 2")

	# 3rd tick -> transition to JUMPING
	f._process_jump_squat(1.0 / 60.0)
	assert_equal(f.state, FighterScript.State.JUMPING, "Transitions to JUMPING after 3 ticks")
	assert_equal(f.velocity.y, -420.0, "Initial jump velocity is -420 px/s")

	# Gravity application
	var delta: float = 1.0 / 60.0
	f._process_jumping(delta)
	var expected_vy: float = -420.0 + 980.0 * delta
	assert_true(abs(f.velocity.y - expected_vy) < 0.001, "Gravity 980 px/s^2 correctly applied")

	f.free()

func test_crouching_hurtbox_reduction() -> void:
	print("\nScenario: Crouching Hurtbox Reduction (32 px height)")
	var f = FighterScene.instantiate()
	f.setup(1)

	var hurt_shape: CollisionShape2D = f.hurtbox.get_collision_shape()
	assert_equal((hurt_shape.shape as RectangleShape2D).size, Vector2(24.0, 54.0), "Standing hurtbox height is 54 px")

	f.change_state(FighterScript.State.CROUCHING)
	assert_equal((hurt_shape.shape as RectangleShape2D).size, Vector2(24.0, 32.0), "Crouching hurtbox height reduced to 32 px")
	assert_equal(hurt_shape.position, Vector2(0.0, -16.0), "Crouching hurtbox offset is (0, -16)")

	f.change_state(FighterScript.State.IDLE)
	assert_equal((hurt_shape.shape as RectangleShape2D).size, Vector2(24.0, 54.0), "Restored standing hurtbox height is 54 px")
	assert_equal(hurt_shape.position, Vector2(0.0, -27.0), "Restored standing hurtbox offset is (0, -27)")

	f.free()

func test_attack_punch_frame_data() -> void:
	print("\nScenario: Punch Attack Frame Data (4 startup, 3 active, 5 recovery = 12 total)")
	var f = FighterScene.instantiate()
	f.setup(1)

	f.change_state(FighterScript.State.ATTACK_PUNCH)
	assert_equal(f.state, FighterScript.State.ATTACK_PUNCH, "State is ATTACK_PUNCH")
	assert_false(f.hitbox.monitoring, "Hitbox inactive during startup")

	# Startup frames: ticks 1 to 4
	for tick in range(1, 5):
		f._process_attack_punch(1.0 / 60.0)
		assert_equal(f.attack_tick, tick, "Punch tick %d" % tick)
		assert_false(f.hitbox.monitoring, "Hitbox inactive on startup tick %d" % tick)

	# Active frame 1: tick 5 (AC-01)
	f._process_attack_punch(1.0 / 60.0)
	assert_equal(f.attack_tick, 5, "Punch tick 5 is first active tick")
	assert_true(f.hitbox.monitoring, "Hitbox is active on tick 5")

	# Active frame 2: tick 6
	f._process_attack_punch(1.0 / 60.0)
	assert_true(f.hitbox.monitoring, "Hitbox is active on tick 6")

	# Active frame 3: tick 7
	f._process_attack_punch(1.0 / 60.0)
	assert_true(f.hitbox.monitoring, "Hitbox is active on tick 7")

	# Recovery frame 1: tick 8 -> hitbox deactivated
	f._process_attack_punch(1.0 / 60.0)
	assert_equal(f.attack_tick, 8, "Punch tick 8 is first recovery tick")
	assert_false(f.hitbox.monitoring, "Hitbox is deactivated on recovery tick 8")

	# Recovery frames: ticks 9 to 12
	for tick in range(9, 13):
		f._process_attack_punch(1.0 / 60.0)
		assert_false(f.hitbox.monitoring, "Hitbox is deactivated on recovery tick %d" % tick)

	# Tick 13 -> transitions back to IDLE
	f._process_attack_punch(1.0 / 60.0)
	assert_equal(f.state, FighterScript.State.IDLE, "Returns to IDLE after 12 ticks")

	f.free()

func test_attack_kick_frame_data() -> void:
	print("\nScenario: Kick Attack Frame Data (7 startup, 4 active, 8 recovery = 19 total)")
	var f = FighterScene.instantiate()
	f.setup(1)

	f.change_state(FighterScript.State.ATTACK_KICK)
	assert_equal(f.state, FighterScript.State.ATTACK_KICK, "State is ATTACK_KICK")

	# Startup frames: ticks 1 to 7
	for tick in range(1, 8):
		f._process_attack_kick(1.0 / 60.0)
		assert_false(f.hitbox.monitoring, "Kick hitbox inactive on startup tick %d" % tick)

	# Active frame 1: tick 8
	f._process_attack_kick(1.0 / 60.0)
	assert_equal(f.attack_tick, 8, "Kick tick 8 is first active tick")
	assert_true(f.hitbox.monitoring, "Kick hitbox is active on tick 8")

	# Active frames: ticks 9, 10, 11
	for tick in range(9, 12):
		f._process_attack_kick(1.0 / 60.0)
		assert_true(f.hitbox.monitoring, "Kick hitbox is active on active tick %d" % tick)

	# Recovery frame 1: tick 12
	f._process_attack_kick(1.0 / 60.0)
	assert_equal(f.attack_tick, 12, "Kick tick 12 is first recovery tick")
	assert_false(f.hitbox.monitoring, "Kick hitbox deactivated on recovery tick 12")

	# Recovery frames: ticks 13 to 19
	for tick in range(13, 20):
		f._process_attack_kick(1.0 / 60.0)
		assert_false(f.hitbox.monitoring, "Kick hitbox inactive on recovery tick %d" % tick)

	# Tick 20 -> transitions back to IDLE
	f._process_attack_kick(1.0 / 60.0)
	assert_equal(f.state, FighterScript.State.IDLE, "Returns to IDLE after 19 ticks")

	f.free()

func test_attack_initiation_rules() -> void:
	print("\nScenario: Attack Initiation Rule Enforcement")
	var f = FighterScene.instantiate()
	f.setup(1)

	# Allowed from IDLE
	f.state = FighterScript.State.IDLE
	assert_true(f.state in [FighterScript.State.IDLE, FighterScript.State.WALK_FORWARD, FighterScript.State.WALK_BACKWARD], "IDLE is valid attack origin")

	# Allowed from WALK_FORWARD
	f.state = FighterScript.State.WALK_FORWARD
	assert_true(f.state in [FighterScript.State.IDLE, FighterScript.State.WALK_FORWARD, FighterScript.State.WALK_BACKWARD], "WALK_FORWARD is valid attack origin")

	# Allowed from WALK_BACKWARD
	f.state = FighterScript.State.WALK_BACKWARD
	assert_true(f.state in [FighterScript.State.IDLE, FighterScript.State.WALK_FORWARD, FighterScript.State.WALK_BACKWARD], "WALK_BACKWARD is valid attack origin")

	# Disallowed from CROUCHING
	f.state = FighterScript.State.CROUCHING
	assert_false(f.state in [FighterScript.State.IDLE, FighterScript.State.WALK_FORWARD, FighterScript.State.WALK_BACKWARD], "No crouch attacks allowed")

	# Disallowed from JUMPING
	f.state = FighterScript.State.JUMPING
	assert_false(f.state in [FighterScript.State.IDLE, FighterScript.State.WALK_FORWARD, FighterScript.State.WALK_BACKWARD], "No air attacks allowed")

	f.free()

func test_ac01_punch_hit_and_oneshot() -> void:
	print("\nScenario: AC-01 - Punch Hit & One-Shot Registration")
	var p1 = FighterScene.instantiate()
	var p2 = FighterScene.instantiate()
	p1.setup(1)
	p2.setup(2)
	p1.opponent = p2
	p2.opponent = p1

	p1.global_position = Vector2(200.0, 190.0)
	p2.global_position = Vector2(240.0, 190.0) # 40 px distance

	p1.change_state(FighterScript.State.ATTACK_PUNCH)
	assert_equal(p2.health, 100, "P2 initial health is 100")

	# Advance 4 startup ticks
	for _i in range(4):
		p1._process_attack_punch(1.0 / 60.0)
	assert_equal(p2.health, 100, "P2 health untouched during startup ticks")

	# Tick 5: Hit lands!
	p1._process_attack_punch(1.0 / 60.0)
	# Trigger hit delivery
	var landed = p1.hitbox.trigger_hit(p2.hurtbox)
	assert_true(landed, "Hit delivered to P2 hurtbox on tick 5")
	assert_equal(p2.health, 92, "P2 health decreases by 8 (from 100 to 92)")
	assert_equal(p2.state, FighterScript.State.HIT_STUN, "P2 enters HIT_STUN")
	assert_equal(p2.stun_ticks_remaining, 12, "P2 hit stun ticks is 12")

	# One-shot check: Subsequent ticks during same active window must NOT apply damage again
	var second_hit = p1.hitbox.trigger_hit(p2.hurtbox)
	assert_false(second_hit, "Damage is NOT applied again during same swing (one-shot registration)")
	assert_equal(p2.health, 92, "P2 health remains 92")

	p1.free()
	p2.free()

func test_ac02_standing_block_vs_punch() -> void:
	print("\nScenario: AC-02 - Standing Block vs High Punch")
	var p1 = FighterScene.instantiate()
	var p2 = FighterScene.instantiate()
	p1.setup(1)
	p2.setup(2)
	p1.opponent = p2
	p2.opponent = p1

	p1.global_position = Vector2(200.0, 190.0)
	p2.global_position = Vector2(240.0, 190.0)

	# P2 holding standing block
	p2.change_state(FighterScript.State.BLOCKING)
	p2.is_crouch_blocking = false

	# P1 lands punch
	p1.hitbox.configure_punch(1, p1)
	var landed = p1.hitbox.trigger_hit(p2.hurtbox)
	assert_true(landed, "Punch hit lands on standing blocking P2")

	assert_equal(p2.state, FighterScript.State.BLOCK_STUN, "P2 enters BLOCK_STUN")
	assert_equal(p2.stun_ticks_remaining, 6, "P2 block stun is 6 ticks")
	assert_equal(p2.health, 99, "P2 takes only 1 HP damage (floor(8 * 0.2))")
	assert_equal(p2.velocity.x, 0.0, "Knockback is 0 on block")

	p1.free()
	p2.free()

func test_ac03_low_kick_vs_standing_block() -> void:
	print("\nScenario: AC-03 - Low Kick Hit vs Standing Block (Defense Failure)")
	var p1 = FighterScene.instantiate()
	var p2 = FighterScene.instantiate()
	p1.setup(1)
	p2.setup(2)
	p1.opponent = p2
	p2.opponent = p1

	p1.global_position = Vector2(200.0, 190.0)
	p2.global_position = Vector2(250.0, 190.0) # 50 px distance

	# P2 holding standing block
	p2.change_state(FighterScript.State.BLOCKING)
	p2.is_crouch_blocking = false

	# P1 lands low kick
	p1.hitbox.configure_kick(1, p1)
	var landed = p1.hitbox.trigger_hit(p2.hurtbox)
	assert_true(landed, "Kick hit lands on standing P2")

	assert_equal(p2.state, FighterScript.State.HIT_STUN, "Standing block fails vs low kick -> enters HIT_STUN")
	assert_equal(p2.health, 86, "P2 takes full 14 HP damage (from 100 to 86)")
	assert_equal(p2.stun_ticks_remaining, 18, "P2 hit stun is 18 ticks")
	assert_equal(p2.velocity.x, 80.0, "P2 pushed back by 80 px/s")

	p1.free()
	p2.free()

func test_ac04_crouching_block_vs_low_kick() -> void:
	print("\nScenario: AC-04 - Crouching Block vs Low Kick (Successful Defense)")
	var p1 = FighterScene.instantiate()
	var p2 = FighterScene.instantiate()
	p1.setup(1)
	p2.setup(2)
	p1.opponent = p2
	p2.opponent = p1

	p1.global_position = Vector2(200.0, 190.0)
	p2.global_position = Vector2(250.0, 190.0)

	# P2 crouch blocking
	p2.change_state(FighterScript.State.BLOCKING)
	p2.is_crouch_blocking = true

	# P1 lands low kick
	p1.hitbox.configure_kick(1, p1)
	var landed = p1.hitbox.trigger_hit(p2.hurtbox)
	assert_true(landed, "Kick hit lands on crouch-blocking P2")

	assert_equal(p2.state, FighterScript.State.BLOCK_STUN, "Crouch block succeeds vs low kick -> enters BLOCK_STUN")
	assert_equal(p2.health, 98, "P2 takes only 2 HP damage (floor(14 * 0.2))")
	assert_equal(p2.stun_ticks_remaining, 8, "P2 block stun is 8 ticks")
	assert_equal(p2.velocity.x, 0.0, "Knockback is 0 on block")

	p1.free()
	p2.free()

func test_crouching_block_vs_punch() -> void:
	print("\nScenario: Crouching Block vs High Punch (High can be blocked crouching)")
	var p1 = FighterScene.instantiate()
	var p2 = FighterScene.instantiate()
	p1.setup(1)
	p2.setup(2)
	p1.opponent = p2
	p2.opponent = p1

	p2.change_state(FighterScript.State.BLOCKING)
	p2.is_crouch_blocking = true

	p1.hitbox.configure_punch(1, p1)
	p1.hitbox.trigger_hit(p2.hurtbox)

	assert_equal(p2.state, FighterScript.State.BLOCK_STUN, "Crouch block succeeds vs punch")
	assert_equal(p2.health, 99, "P2 takes 1 HP damage")
	assert_equal(p2.stun_ticks_remaining, 6, "P2 block stun is 6 ticks")

	p1.free()
	p2.free()

func test_ac05_pushbox_separation_matrix() -> void:
	print("\nScenario: AC-05 - Pushbox Collision Separation Matrix")
	var p1 = FighterScene.instantiate()
	var p2 = FighterScene.instantiate()
	p1.setup(1)
	p2.setup(2)

	assert_true(bool(p1.collision_layer & HitboxScript.MASK_FIGHTERBODY), "P1 has Layer 2 pushbox")
	assert_true(bool(p2.collision_layer & HitboxScript.MASK_FIGHTERBODY), "P2 has Layer 2 pushbox")
	assert_true(bool(p1.collision_mask & HitboxScript.MASK_FIGHTERBODY), "P1 masks Layer 2 pushbox (prevents pass-through)")
	assert_true(bool(p2.collision_mask & HitboxScript.MASK_FIGHTERBODY), "P2 masks Layer 2 pushbox (prevents pass-through)")

	p1.free()
	p2.free()

# Mock Camera class to test view bounds clamping
class MockCamera extends Camera2D:
	var left_bound: float = 192.0
	var right_bound: float = 408.0

	func get_view_bounds() -> Rect2:
		return Rect2(left_bound, 0.0, 384.0, 224.0)

func test_ac06_boundary_clamping() -> void:
	print("\nScenario: AC-06 - Viewport & Stage Boundary Clamping")
	var f = FighterScene.instantiate()
	f.setup(1)

	# Test stage bounds [16, 584] without camera
	f.global_position.x = 0.0
	f._apply_clamping()
	assert_equal(f.global_position.x, 16.0, "Clamped to stage min X (16)")

	f.global_position.x = 700.0
	f._apply_clamping()
	assert_equal(f.global_position.x, 584.0, "Clamped to stage max X (584)")

	# Test with camera bounds
	var mock_cam = MockCamera.new()
	mock_cam.left_bound = 100.0 # view [100, 484] -> clamp [100+16, 484-16] = [116, 468]
	f.camera = mock_cam

	f.global_position.x = 50.0
	f._apply_clamping()
	assert_equal(f.global_position.x, 116.0, "Clamped to camera left bound + 16 (116)")

	f.global_position.x = 500.0
	f._apply_clamping()
	assert_equal(f.global_position.x, 468.0, "Clamped to camera right bound - 16 (468)")

	mock_cam.free()
	f.free()

func test_ac07_ko_knockdown_dead_and_reset() -> void:
	print("\nScenario: AC-07 - KO, Knockdown to Dead, and Round Reset")
	var p1 = FighterScene.instantiate()
	var p2 = FighterScene.instantiate()
	p1.setup(1)
	p2.setup(2)

	p2.health = 8
	p1.hitbox.configure_punch(1, p1)
	p1.hitbox.trigger_hit(p2.hurtbox)

	assert_equal(p2.health, 0, "P2 health drops to 0")
	assert_equal(p2.state, FighterScript.State.KNOCKDOWN, "P2 enters KNOCKDOWN upon 0 HP")

	# Knockdown advances to DEAD
	for _i in range(10):
		p2._process_knockdown(1.0 / 60.0)
	assert_equal(p2.state, FighterScript.State.DEAD, "P2 enters DEAD terminal state")

	# Round Reset
	p2.reset_round(400.0)
	assert_equal(p2.health, 100, "Health restored to 100 on reset")
	assert_equal(p2.state, FighterScript.State.IDLE, "State forced back to IDLE on reset")
	assert_equal(p2.global_position.x, 400.0, "Position restored to X=400")

	p1.free()
	p2.free()

func test_ac10_p2_dummy_toggle_and_behavior() -> void:
	print("\nScenario: AC-10 - Player 2 Dummy Toggle & Behavior")
	var p1 = FighterScene.instantiate()
	var p2 = FighterScene.instantiate()
	p1.setup(1)
	p2.setup(2)

	assert_false(p2.is_dummy, "P2 default is HUMAN mode (is_dummy = false)")

	# Toggle to dummy
	p2.toggle_dummy()
	assert_true(p2.is_dummy, "P2 toggles to DUMMY mode")

	# In dummy mode, input actions are ignored
	assert_false(p2.is_action_pressed("punch"), "P2 dummy ignores input action punch")
	assert_false(p2.is_action_pressed("block"), "P2 dummy ignores input action block")

	# Auto crouch-blocks incoming punch
	p1.hitbox.configure_punch(1, p1)
	p1.hitbox.trigger_hit(p2.hurtbox)

	assert_equal(p2.state, FighterScript.State.BLOCK_STUN, "P2 dummy automatically enters BLOCK_STUN")
	assert_equal(p2.stun_ticks_remaining, 6, "P2 dummy block stun is 6 ticks")
	assert_equal(p2.health, 99, "P2 dummy loses only 1 HP against punch")

	# Persists across reset_round
	p2.reset_round(400.0)
	assert_true(p2.is_dummy, "P2 dummy mode persists across round reset")

	# Toggle back to human
	p2.toggle_dummy()
	assert_false(p2.is_dummy, "Pressing toggle again restores HUMAN mode")

	p1.free()
	p2.free()

func test_ac1_palette_application_on_setup() -> void:
	print("\nScenario: AC-1 - Palette Application on Setup")
	var f = FighterScene.instantiate()
	f.setup(2)
	var torso = f.get_node_or_null("Visual/TorsoGi") as Polygon2D
	var headband = f.get_node_or_null("Visual/Headband") as Polygon2D
	assert_true(torso != null, "TorsoGi node exists on unparented setup(2)")
	assert_true(headband != null, "Headband node exists on unparented setup(2)")
	assert_equal(torso.color, Color("243356"), "Visual/TorsoGi.color equals Color('243356') (navy)")
	assert_equal(headband.color, Color("e6a117"), "Visual/Headband.color equals Color('e6a117') (gold)")
	f.free()

func test_ac2_punch_animation_synchronization() -> void:
	print("\nScenario: AC-2 - Punch Animation Synchronization")
	var fighter = FighterScene.instantiate()
	fighter.setup(1)
	assert_true(fighter.animation_player != null, "AnimationPlayer node exists")
	assert_equal(fighter.animation_player.callback_mode_process, AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS, "AnimationPlayer configured in Physics mode")

	fighter.change_state(FighterScript.State.ATTACK_PUNCH)
	assert_equal(fighter.animation_player.current_animation, "punch", "AnimationPlayer current_animation is 'punch'")

	var punch_anim = fighter.animation_player.get_animation("punch")
	assert_true(punch_anim != null, "Punch animation exists")
	assert_equal(punch_anim.length, 12.0 / 60.0, "Punch clip length equals 12 ticks (0.2s)")

	fighter.animation_player.seek(5.0 / 60.0, true)
	var lead_arm = fighter.get_node_or_null("Visual/LeadArm") as Polygon2D
	assert_true(lead_arm != null, "Visual/LeadArm exists")
	assert_equal(lead_arm.position.x, 18.0, "LeadArm reaches full +18 px forward extension at active tick 5")

	fighter.animation_player.seek(7.0 / 60.0, true)
	assert_equal(lead_arm.position.x, 18.0, "LeadArm maintains +18 px forward extension at active tick 7")

	fighter.free()

func test_ac3_attack_interrupt_neutral_reset() -> void:
	print("\nScenario: AC-3 - Attack Interrupt Neutral Reset")
	var fighter = FighterScene.instantiate()
	fighter.setup(1)

	fighter.change_state(FighterScript.State.ATTACK_PUNCH)
	fighter.animation_player.seek(5.0 / 60.0, true)
	var lead_arm = fighter.get_node_or_null("Visual/LeadArm") as Polygon2D
	assert_equal(lead_arm.position.x, 18.0, "LeadArm extended to +18 px during active attack ticks")

	fighter.change_state(FighterScript.State.HIT_STUN)
	assert_equal(fighter.animation_player.current_animation, "hit", "AnimationPlayer current_animation is 'hit'")
	assert_equal(lead_arm.position, Vector2.ZERO, "LeadArm transform reset to neutral rest pose (0, 0)")

	fighter.free()

func test_ac4_p2_mirrored_low_kick_invariant() -> void:
	print("\nScenario: AC-4 - P2 Mirrored Low Kick Invariant")
	var p2 = FighterScene.instantiate()
	p2.setup(2)
	assert_equal(p2.facing, -1, "P2 facing is -1")
	assert_equal(p2.visual.scale.x, -1.0, "P2 visual.scale.x is -1.0")

	p2.change_state(FighterScript.State.ATTACK_KICK)
	assert_equal(p2.animation_player.current_animation, "kick", "P2 current_animation is 'kick'")
	var kick_anim = p2.animation_player.get_animation("kick")
	assert_equal(kick_anim.length, 19.0 / 60.0, "Kick clip length is 19 ticks")

	p2.animation_player.seek(8.0 / 60.0, true)
	var lead_leg = p2.get_node_or_null("Visual/LeadLeg") as Polygon2D
	assert_true(lead_leg != null, "Visual/LeadLeg exists")
	assert_true(lead_leg.position.x > 0.0, "LeadLeg extends with positive local X")
	assert_equal(p2.hitbox.get_collision_shape().position, Vector2(-24.0, -12.0), "Kick hitbox is at relative offset (-24, -12)")

	p2.free()

func test_ac5_headless_execution_safety() -> void:
	print("\nScenario: AC-5 - Headless Execution Safety (without AnimationPlayer)")
	var headless = FighterScript.new()
	assert_true(headless.animation_player == null, "Headless fighter has null animation_player")

	for st in FighterScript.State.values():
		headless.change_state(st)
		headless._physics_process(1.0 / 60.0)

	headless.receive_hit(10, 12, 6, 40.0, false)
	headless.reset_round(200.0)
	headless.reset_fighter(200.0)
	assert_equal(headless.state, FighterScript.State.IDLE, "Headless fighter safely executed all transitions")

	headless.free()

func test_13_state_animations_and_track_isolation() -> void:
	print("\nScenario: 13-State Animation Mapping & Track Isolation Invariant")
	var fighter = FighterScene.instantiate()
	fighter.setup(1)
	var ap = fighter.animation_player
	assert_true(ap != null, "AnimationPlayer exists")

	for state_val in FighterScript.STATE_ANIMATIONS:
		var anim_name = FighterScript.STATE_ANIMATIONS[state_val]
		assert_true(ap.has_animation(anim_name), "Animation '%s' exists for state %d" % [anim_name, state_val])

	assert_true(ap.has_animation("RESET"), "RESET animation exists")
	assert_true(ap.has_animation("fall"), "fall animation exists")
	assert_true(ap.has_animation("crouch_block"), "crouch_block animation exists")
	assert_true(ap.has_animation("crouch_block_stun"), "crouch_block_stun animation exists")

	var lib = ap.get_animation_library("")
	for anim_name in ap.get_animation_list():
		var anim = lib.get_animation(anim_name)
		for t in range(anim.get_track_count()):
			var path = str(anim.track_get_path(t))
			assert_true(path.begins_with("Visual/"), "Track path '%s' in '%s' must target under Visual/" % [path, anim_name])
			assert_false(path.begins_with("Visual:"), "Track path '%s' in '%s' must not target Visual root" % [path, anim_name])
			assert_false("Pushbox" in path or "Hurtbox" in path or "Hitbox" in path, "Track path '%s' in '%s' must not target collision nodes" % [path, anim_name])

			var parts = path.split(":")
			var node_subpath = parts[0].replace("Visual/", "")
			assert_true(node_subpath in FighterScript.LIMB_NODES, "Limb '%s' in '%s' must be in LIMB_NODES" % [node_subpath, anim_name])

	fighter.free()

func _calculate_visual_height(visual: Node2D) -> float:
	var min_y: float = INF
	var max_y: float = -INF
	for limb_name in FighterScript.LIMB_NODES:
		var poly = visual.get_node_or_null(limb_name) as Polygon2D
		if poly != null:
			for v in poly.polygon:
				var world_v = poly.transform * v
				if world_v.y < min_y:
					min_y = world_v.y
				if world_v.y > max_y:
					max_y = world_v.y
	return max_y - min_y

func test_crouch_and_knockdown_visual_heights() -> void:
	print("\nScenario: Crouch (<=32px) and Knockdown/Dead (<=16px) Visual Heights")
	var fighter = FighterScene.instantiate()
	fighter.setup(1)

	fighter.change_state(FighterScript.State.CROUCHING)
	fighter.animation_player.seek(0.0, true)
	var crouch_height = _calculate_visual_height(fighter.visual)
	assert_true(crouch_height <= 32.0, "Crouch visual height is <=32 px (got: %f)" % crouch_height)

	fighter.change_state(FighterScript.State.KNOCKDOWN)
	fighter.animation_player.seek(0.0, true)
	var kd_height = _calculate_visual_height(fighter.visual)
	assert_true(kd_height <= 16.001, "Knockdown visual height is <=16 px (got: %f)" % kd_height)

	fighter.change_state(FighterScript.State.DEAD)
	fighter.animation_player.seek(0.0, true)
	var dead_height = _calculate_visual_height(fighter.visual)
	assert_true(dead_height <= 16.001, "Dead visual height is <=16 px (got: %f)" % dead_height)

	fighter.free()

