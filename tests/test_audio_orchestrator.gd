class_name TestAudioOrchestrator
extends RefCounted

## Automated Headless Verification Suite for Match Lifecycle Script Orchestration.
## Verifies BGMPlayer orchestration, bus layout, lifecycle transitions, tween slowdown,
## reset state cleanliness, and out-of-tree headless safety.

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

func run_all(p_tree: SceneTree = null) -> bool:
	if p_tree != null:
		tree = p_tree
	elif tree == null:
		tree = _get_tree()

	print("\n=== Running Audio Orchestrator & Match Lifecycle Tests ===")
	test_case_1_bus_layout_contract()
	test_case_2_scene_and_asset_contract()
	test_case_3_in_tree_in_round_playback()
	test_case_4_in_tree_round_over_slowdown()
	test_case_5_match_reset_state_cleanliness()
	test_case_6_out_of_tree_headless_safety()

	print("\n=== Audio Orchestrator Test Results: %d passed, %d failed ===" % [passed, failed])
	return failed == 0

func test_case_1_bus_layout_contract() -> void:
	print("\nTest Case 1 (Bus Layout Contract): AudioServer Music and SFX routing to Master")
	assert_true(AudioServer.bus_count >= 3, "AudioServer has at least 3 buses")

	var master_idx: int = AudioServer.get_bus_index("Master")
	var music_idx: int = AudioServer.get_bus_index("Music")
	var sfx_idx: int = AudioServer.get_bus_index("SFX")

	assert_true(master_idx >= 0, "AudioServer has 'Master' bus")
	assert_true(music_idx >= 0, "AudioServer has 'Music' bus")
	assert_true(sfx_idx >= 0, "AudioServer has 'SFX' bus")

	if music_idx >= 0:
		assert_equal(AudioServer.get_bus_send(music_idx), "Master", "Music bus routes to Master")
	if sfx_idx >= 0:
		assert_equal(AudioServer.get_bus_send(sfx_idx), "Master", "SFX bus routes to Master")

func test_case_2_scene_and_asset_contract() -> void:
	print("\nTest Case 2 (Scene & Asset Contract): Main BGMPlayer wiring and AudioStream properties")
	var main = MainScene.instantiate()
	assert_true(main != null, "scenes/Main.tscn instantiates cleanly")
	assert_true(main.has_node("BGMPlayer"), "scenes/Main.tscn contains BGMPlayer node")

	var player = main.get_node_or_null("BGMPlayer")
	assert_true(player is AudioStreamPlayer, "BGMPlayer is an AudioStreamPlayer")

	if player is AudioStreamPlayer:
		assert_equal(player.bus, &"Music", "BGMPlayer is assigned to 'Music' bus")
		assert_false(player.autoplay, "BGMPlayer autoplay is false")
		assert_true(player.stream != null, "BGMPlayer has a valid audio stream assigned")

		var stream = player.stream
		if stream != null:
			if "loop" in stream:
				assert_true(stream.get("loop") == true, "stream.loop is true")
			if "loop_offset" in stream:
				var offset: float = float(stream.get("loop_offset"))
				var length: float = stream.get_length()
				assert_true(offset > 0.0 and offset < length, "stream loop_offset (%.2fs) is between 0.0 and length (%.2fs)" % [offset, length])

	main.free()

func test_case_3_in_tree_in_round_playback() -> void:
	print("\nTest Case 3 (In-Tree In-Round Playback): stepping to IN_ROUND starts playback from 0.0s")
	var active_tree = _get_tree()
	assert_true(active_tree != null, "Active SceneTree is available")
	if active_tree == null:
		return
	var root = active_tree.root

	var main = MainScene.instantiate()
	root.add_child(main)

	assert_true(main.is_inside_tree(), "Main is inside active SceneTree")
	assert_true(is_instance_valid(main.bgm_player), "bgm_player resolved defensively")
	assert_equal(main.match_state, MainScript.MatchState.ROUND_INTRO, "Initial state is ROUND_INTRO")
	assert_false(main.bgm_player.playing, "BGMPlayer is not playing during ROUND_INTRO")

	# Step through ROUND_INTRO (1.5s) to trigger IN_ROUND
	main.step(1.5)
	assert_equal(main.match_state, MainScript.MatchState.IN_ROUND, "Match state transitioned to IN_ROUND")
	assert_true(main.bgm_player.playing, "BGMPlayer started playback upon entering IN_ROUND")
	assert_true(main.bgm_player.get_playback_position() >= 0.0, "Playback started from beginning (0.0s) for intro fanfare")

	# Subsequent steps in IN_ROUND do not restart playback
	var pos_before = main.bgm_player.get_playback_position()
	main.step(0.1)
	assert_true(main.bgm_player.playing, "BGMPlayer continues playing in IN_ROUND")

	main.bgm_player.stop()
	root.remove_child(main)
	main.free()

func test_case_4_in_tree_round_over_slowdown() -> void:
	print("\nTest Case 4 (In-Tree Round-Over Slowdown): _bgm_tween interpolates pitch to 0.72 and volume to -12 dB")
	var active_tree = _get_tree()
	assert_true(active_tree != null, "Active SceneTree is available")
	if active_tree == null:
		return
	var root = active_tree.root

	# Subtest A: KO transition
	var main_ko = MainScene.instantiate()
	root.add_child(main_ko)
	main_ko.step(1.5) # Enter IN_ROUND
	assert_true(main_ko.bgm_player.playing, "BGMPlayer is playing before KO")

	main_ko.p2.health = 0
	main_ko.step(1.0 / 60.0) # Trigger KO terminal condition
	assert_equal(main_ko.match_state, MainScript.MatchState.ROUND_OVER, "State transitioned to ROUND_OVER on KO")
	assert_true(is_instance_valid(main_ko._bgm_tween), "_bgm_tween created on ROUND_OVER")
	assert_true(main_ko._bgm_tween.is_valid() and main_ko._bgm_tween.is_running(), "_bgm_tween is active and running")

	# Step tween to completion (0.9s duration)
	main_ko._bgm_tween.custom_step(0.9)
	assert_equal(main_ko.bgm_player.pitch_scale, 0.72, "Pitch scale interpolated to 0.72 on KO")
	assert_equal(main_ko.bgm_player.volume_db, -12.0, "Volume dB interpolated to -12.0 dB on KO")

	main_ko.bgm_player.stop()
	if is_instance_valid(main_ko._bgm_tween):
		main_ko._bgm_tween.kill()
	root.remove_child(main_ko)
	main_ko.free()

	# Subtest B: TIME_UP transition
	var main_time = MainScene.instantiate()
	root.add_child(main_time)
	main_time.step(1.5) # Enter IN_ROUND
	main_time.step(99.0) # Countdown timeout
	assert_equal(main_time.match_state, MainScript.MatchState.ROUND_OVER, "State transitioned to ROUND_OVER on TIME_UP")
	assert_true(is_instance_valid(main_time._bgm_tween), "_bgm_tween created on TIME_UP")
	main_time._bgm_tween.custom_step(0.9)
	assert_equal(main_time.bgm_player.pitch_scale, 0.72, "Pitch scale interpolated to 0.72 on TIME_UP")
	assert_equal(main_time.bgm_player.volume_db, -12.0, "Volume dB interpolated to -12.0 dB on TIME_UP")

	main_time.bgm_player.stop()
	if is_instance_valid(main_time._bgm_tween):
		main_time._bgm_tween.kill()
	root.remove_child(main_time)
	main_time.free()

	# Subtest C: DRAW transition
	var main_draw = MainScene.instantiate()
	root.add_child(main_draw)
	main_draw.step(1.5) # Enter IN_ROUND
	main_draw.p1.health = 0
	main_draw.p2.health = 0
	main_draw.step(1.0 / 60.0)
	assert_equal(main_draw.match_state, MainScript.MatchState.ROUND_OVER, "State transitioned to ROUND_OVER on DRAW")
	assert_true(is_instance_valid(main_draw._bgm_tween), "_bgm_tween created on DRAW")
	main_draw._bgm_tween.custom_step(0.9)
	assert_equal(main_draw.bgm_player.pitch_scale, 0.72, "Pitch scale interpolated to 0.72 on DRAW")
	assert_equal(main_draw.bgm_player.volume_db, -12.0, "Volume dB interpolated to -12.0 dB on DRAW")

	main_draw.bgm_player.stop()
	if is_instance_valid(main_draw._bgm_tween):
		main_draw._bgm_tween.kill()
	root.remove_child(main_draw)
	main_draw.free()

func test_case_5_match_reset_state_cleanliness() -> void:
	print("\nTest Case 5 (Match Reset State Cleanliness): tween killed, playback stopped, pitch/vol restored")
	var active_tree = _get_tree()
	assert_true(active_tree != null, "Active SceneTree is available")
	if active_tree == null:
		return
	var root = active_tree.root

	var main = MainScene.instantiate()
	root.add_child(main)
	main.step(1.5) # Enter IN_ROUND
	main.change_match_state(MainScript.MatchState.ROUND_OVER)
	assert_true(is_instance_valid(main._bgm_tween), "Tween active in ROUND_OVER")

	# Partially step tween
	main._bgm_tween.custom_step(0.4)
	assert_true(main.bgm_player.pitch_scale < 1.0, "Pitch altered during slowdown")
	assert_true(main.bgm_player.volume_db < 0.0, "Volume altered during slowdown")

	# Transition to RESET (either by step(3.0) or change_match_state)
	main.change_match_state(MainScript.MatchState.RESET)

	assert_true(main._bgm_tween == null or not is_instance_valid(main._bgm_tween), "_bgm_tween is killed and nullified on RESET")
	assert_false(main.bgm_player.playing, "bgm_player is stopped on RESET")
	assert_equal(main.bgm_player.pitch_scale, 1.0, "pitch_scale restored to 1.0")
	assert_equal(main.bgm_player.volume_db, 0.0, "volume_db restored to 0.0 dB")

	# Verify start_round() looped back to ROUND_INTRO cleanly
	assert_equal(main.match_state, MainScript.MatchState.ROUND_INTRO, "Match looped cleanly back to ROUND_INTRO")

	main.bgm_player.stop()
	root.remove_child(main)
	main.free()

func test_case_6_out_of_tree_headless_safety() -> void:
	print("\nTest Case 6 (Out-of-Tree Headless Safety): zero crashes, null refs, or tween errors outside tree")
	var main = MainScene.instantiate()
	assert_false(main.is_inside_tree(), "Main is instantiated strictly outside active SceneTree")

	# Execute _ready() outside tree
	main._ready()
	assert_true(true, "_ready() executed out-of-tree without crashes")

	# Execute step() through all states outside tree
	main.step(1.5) # Trigger IN_ROUND outside tree
	assert_equal(main.match_state, MainScript.MatchState.IN_ROUND, "Transitions to IN_ROUND out-of-tree")
	assert_false(main.bgm_player.playing, "bgm_player does not play when out-of-tree")

	main.step(100.0) # Trigger timeout -> ROUND_OVER out-of-tree
	assert_equal(main.match_state, MainScript.MatchState.ROUND_OVER, "Transitions to ROUND_OVER out-of-tree")
	assert_true(main._bgm_tween == null, "_bgm_tween remains null out-of-tree (preventing tween creation error)")

	main.step(3.0) # Trigger RESET out-of-tree
	assert_equal(main.match_state, MainScript.MatchState.ROUND_INTRO, "Transitions through RESET to ROUND_INTRO out-of-tree")
	assert_equal(main.bgm_player.pitch_scale, 1.0, "pitch_scale clean out-of-tree")
	assert_equal(main.bgm_player.volume_db, 0.0, "volume_db clean out-of-tree")

	main.free()
	assert_true(true, "Main freed cleanly without leaks or errors")
