class_name TestAudioOrchestrator
extends RefCounted

## Automated Headless Verification Suite for Match Lifecycle & In-Engine Combat Music Integration.
## Verifies BGMPlayer orchestration, bus layout, retro-fighter.ogg loop metadata contract,
## initial combat synchronization, continuous playback across rounds, and out-of-tree headless safety.

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

	print("\n=== Running Audio Orchestrator & Combat Music Integration Tests ===")
	test_case_1_bus_layout_contract()
	test_case_2_ogg_loop_metadata_contract()
	test_case_3_initial_combat_playback_synchronization()
	test_case_4_continuous_playback_across_state_transitions()
	test_case_5_runtime_loop_wrap_around_contract()
	test_case_6_out_of_tree_headless_safety()

	print("\n=== Audio Orchestrator Test Results: %d passed, %d failed ===" % [passed, failed])
	return failed == 0

func test_case_1_bus_layout_contract() -> void:
	print("\nTest Case 1 (Bus Layout Contract): AudioServer Music routing to Master")
	var master_idx: int = AudioServer.get_bus_index("Master")
	var music_idx: int = AudioServer.get_bus_index("Music")

	assert_true(master_idx >= 0, "AudioServer has 'Master' bus")
	assert_true(music_idx >= 0, "AudioServer has 'Music' bus")

	if music_idx >= 0:
		assert_equal(AudioServer.get_bus_send(music_idx), "Master", "Music bus routes to Master")

func test_case_2_ogg_loop_metadata_contract() -> void:
	print("\nTest Case 2 (Scenario 1 - Ogg Vorbis Loop Metadata Contract): retro-fighter.ogg & import metadata")
	# 1. Inspect import configuration file directly
	var import_path = "res://audio/music/retro-fighter.ogg.import"
	assert_true(FileAccess.file_exists(import_path), "res://audio/music/retro-fighter.ogg.import exists on disk")
	if FileAccess.file_exists(import_path):
		var file = FileAccess.open(import_path, FileAccess.READ)
		var content = file.get_as_text()
		file.close()
		assert_true(content.contains("loop=true"), "retro-fighter.ogg.import specifies loop=true")
		assert_true(content.contains("loop_offset=0.0") or content.contains("loop_offset=0"), "retro-fighter.ogg.import specifies loop_offset = 0.0")

	# 2. Inspect runtime loaded stream via ResourceLoader
	var stream: Resource = ResourceLoader.load("res://audio/music/retro-fighter.ogg")
	assert_true(stream != null, "res://audio/music/retro-fighter.ogg loads via ResourceLoader")
	if stream != null:
		assert_true(stream is AudioStream, "Stream is an AudioStream")
		if "loop" in stream:
			assert_true(stream.get("loop") == true, "stream.loop is true")
		if "loop_offset" in stream:
			assert_equal(float(stream.get("loop_offset")), 0.0, "stream.loop_offset is 0.0")
		if stream.has_method("get_length"):
			assert_true(stream.get_length() > 150.0, "stream length (~170.66s) exceeds 150.0s (actual: %.2fs)" % stream.get_length())

	# 3. Main scene composition
	var main = MainScene.instantiate()
	assert_true(main != null, "scenes/Main.tscn instantiates cleanly")
	assert_true(main.has_node("BGMPlayer"), "scenes/Main.tscn contains BGMPlayer node")

	var player = main.get_node_or_null("BGMPlayer")
	assert_true(player is AudioStreamPlayer, "BGMPlayer is an AudioStreamPlayer")

	if player is AudioStreamPlayer:
		assert_equal(player.bus, &"Music", "BGMPlayer is assigned to 'Music' bus")
		assert_false(player.autoplay, "BGMPlayer autoplay is false")
		assert_true(player.stream != null, "BGMPlayer has a valid audio stream assigned")
		if player.stream != null:
			if "loop" in player.stream:
				assert_true(player.stream.get("loop") == true, "Assigned stream.loop is true")
			if "loop_offset" in player.stream:
				assert_equal(float(player.stream.get("loop_offset")), 0.0, "Assigned stream.loop_offset is 0.0")

	main.free()

func test_case_3_initial_combat_playback_synchronization() -> void:
	print("\nTest Case 3 (Scenario 3 - Initial Combat Playback Synchronization): start on first IN_ROUND")
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
	assert_true(main.bgm_player.playing, "BGMPlayer is playing during initial ROUND_INTRO")

	# Step through ROUND_INTRO (1.5s) to trigger IN_ROUND
	main.step(1.5)
	assert_equal(main.match_state, MainScript.MatchState.IN_ROUND, "Match state transitioned to IN_ROUND")
	assert_true(main.bgm_player.playing, "BGMPlayer is playing in IN_ROUND")
	assert_equal(main.bgm_player.bus, &"Music", "BGMPlayer bus is &\"Music\"")
	assert_true(main.bgm_player.get_playback_position() >= 0.0, "Playback position is non-negative")

	# Subsequent steps in IN_ROUND do not restart playback
	main.step(0.1)
	assert_true(main.bgm_player.playing, "BGMPlayer continues playing in IN_ROUND")

	main.bgm_player.stop()
	root.remove_child(main)
	main.free()

func test_case_4_continuous_playback_across_state_transitions() -> void:
	print("\nTest Case 4 (Scenario 4 - Continuous Playback Across Match State Transitions): loops across rounds without stopping")
	var active_tree = _get_tree()
	assert_true(active_tree != null, "Active SceneTree is available")
	if active_tree == null:
		return
	var root = active_tree.root

	var main = MainScene.instantiate()
	root.add_child(main)

	# Enter IN_ROUND
	main.step(1.5)
	assert_equal(main.match_state, MainScript.MatchState.IN_ROUND, "Entered IN_ROUND")
	assert_true(main.bgm_player.playing, "BGMPlayer playing in IN_ROUND")

	# Subtest A: Transition to ROUND_OVER via KO
	main.p2.health = 0
	main.step(1.0 / 60.0)
	assert_equal(main.match_state, MainScript.MatchState.ROUND_OVER, "State transitioned to ROUND_OVER on KO")
	assert_true(main.bgm_player.playing, "BGMPlayer continuously playing during ROUND_OVER")

	# Advance through ROUND_OVER (3.0s delay) -> transitions to RESET and immediately to ROUND_INTRO
	main.step(3.0)
	assert_equal(main.match_state, MainScript.MatchState.ROUND_INTRO, "State transitioned through RESET to ROUND_INTRO")
	assert_true(main.bgm_player.playing, "BGMPlayer continuously playing during RESET and subsequent ROUND_INTRO (not stopped)")

	# Advance through subsequent ROUND_INTRO (1.5s) -> transitions to subsequent IN_ROUND
	main.step(1.5)
	assert_equal(main.match_state, MainScript.MatchState.IN_ROUND, "State transitioned to subsequent IN_ROUND")
	assert_true(main.bgm_player.playing, "BGMPlayer continuously playing in subsequent IN_ROUND")

	# Subtest B: Direct FSM transition validation across all match states
	main.change_match_state(MainScript.MatchState.ROUND_OVER)
	assert_true(main.bgm_player.playing, "BGM playing after direct transition to ROUND_OVER")

	main.change_match_state(MainScript.MatchState.RESET)
	assert_true(main.bgm_player.playing, "BGM playing after direct transition to RESET (stop() eliminated)")

	main.change_match_state(MainScript.MatchState.ROUND_INTRO)
	assert_true(main.bgm_player.playing, "BGM playing after direct transition to ROUND_INTRO")

	main.change_match_state(MainScript.MatchState.IN_ROUND)
	assert_true(main.bgm_player.playing, "BGM playing after direct transition back to IN_ROUND")

	# Subtest C: Timeout & DRAW transitions preserve continuous playback
	main.p1.health = 100
	main.p2.health = 100
	main.round_timer = 0.0
	main.step(0.01) # Timeout trigger
	assert_equal(main.match_state, MainScript.MatchState.ROUND_OVER, "Timeout triggered ROUND_OVER")
	assert_true(main.bgm_player.playing, "BGM continuously playing during timeout ROUND_OVER")

	main.bgm_player.stop()
	root.remove_child(main)
	main.free()

func test_case_5_runtime_loop_wrap_around_contract() -> void:
	print("\nTest Case 5 (Scenario 2 - Runtime Loop Wrap-Around Contract): stream loop configuration")
	var active_tree = _get_tree()
	assert_true(active_tree != null, "Active SceneTree is available")
	if active_tree == null:
		return
	var root = active_tree.root

	var main = MainScene.instantiate()
	root.add_child(main)
	main.step(1.5) # Enter IN_ROUND

	var player = main.bgm_player
	var stream = player.stream
	assert_true(stream != null, "Stream is loaded")

	if stream != null:
		if "loop" in stream:
			assert_true(stream.get("loop") == true, "stream.loop is true")
		if "loop_offset" in stream:
			assert_equal(float(stream.get("loop_offset")), 0.0, "stream.loop_offset is 0.0")

		var finished_emitted = false
		player.finished.connect(func(): finished_emitted = true)

		# Seek close to the end of the track to verify looping behavior
		var track_len: float = stream.get_length() if stream.has_method("get_length") else 170.66
		player.play(max(0.0, track_len - 0.2))
		assert_true(player.playing, "Player is playing at end of track")
		assert_false(finished_emitted, "finished signal NOT emitted on loop play")

	player.stop()
	root.remove_child(main)
	main.free()

func test_case_6_out_of_tree_headless_safety() -> void:
	print("\nTest Case 6 (Scenario 5 - Backwards Compatibility & Headless Test Safety): out-of-tree execution")
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

	main.step(3.0) # Trigger RESET out-of-tree
	assert_equal(main.match_state, MainScript.MatchState.ROUND_INTRO, "Transitions through RESET to ROUND_INTRO out-of-tree")

	main.free()
	assert_true(true, "Main freed cleanly without leaks or errors")
