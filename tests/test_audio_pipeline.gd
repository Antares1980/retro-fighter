class_name TestAudioPipeline
extends RefCounted

## Unit and integration tests for Audio Asset Pipeline & Engine Bus Infrastructure.
## Verifies default_bus_layout.tres, audio/music/stage_theme.ogg, and scenes/Main.tscn BGMPlayer.

const MainScene = preload("res://scenes/Main.tscn")

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
	print("\n=== Running Audio Pipeline & Bus Infrastructure Tests ===")
	test_audio_bus_layout()
	test_audio_asset_stream_contract()
	test_main_scene_bgm_composition()
	test_backwards_compatibility()

	print("\n=== Audio Pipeline Test Results: %d passed, %d failed ===" % [passed, failed])
	return failed == 0

func test_audio_bus_layout() -> void:
	print("\nScenario: Audio Bus Layout Contract (Master, Music, SFX)")
	var bus_layout: AudioBusLayout = load("res://default_bus_layout.tres") as AudioBusLayout
	assert_true(bus_layout != null, "res://default_bus_layout.tres loads as AudioBusLayout")

	if bus_layout != null:
		assert_true(bus_layout.bus_count >= 3, "Audio bus layout has at least 3 buses")
		assert_equal(bus_layout.get_bus_name(0), "Master", "Bus 0 is Master")
		assert_equal(bus_layout.get_bus_name(1), "Music", "Bus 1 is Music")
		assert_equal(bus_layout.get_bus_send(1), "Master", "Bus 1 (Music) routes to Master")
		assert_equal(bus_layout.get_bus_name(2), "SFX", "Bus 2 is SFX")
		assert_equal(bus_layout.get_bus_send(2), "Master", "Bus 2 (SFX) routes to Master")

func test_audio_asset_stream_contract() -> void:
	print("\nScenario: Ogg Vorbis Stream Contract & Loop Metadata")
	var stream: Resource = load("res://audio/music/stage_theme.ogg")
	assert_true(stream != null, "res://audio/music/stage_theme.ogg loads successfully")

	if stream != null and stream is AudioStream:
		var audio_stream: AudioStream = stream as AudioStream
		var length: float = audio_stream.get_length()
		assert_true(length > 6.4, "Audio stream length exceeds 6.4s loop offset (actual: %.2fs)" % length)

		if "loop" in audio_stream:
			assert_true(audio_stream.get("loop"), "AudioStream has loop enabled")
		if "loop_offset" in audio_stream:
			var offset: float = float(audio_stream.get("loop_offset"))
			assert_true(offset > 0.0 and offset < length, "AudioStream loop_offset is valid (%.2fs)" % offset)

func test_main_scene_bgm_composition() -> void:
	print("\nScenario: Main Scene BGMPlayer Node Wiring")
	var main = MainScene.instantiate()
	assert_true(main != null, "scenes/Main.tscn instantiates cleanly")

	var bgm_player = main.get_node_or_null("BGMPlayer")
	assert_true(bgm_player != null, "BGMPlayer exists as direct child of Main")
	assert_true(bgm_player is AudioStreamPlayer, "BGMPlayer is of type AudioStreamPlayer")

	if bgm_player is AudioStreamPlayer:
		assert_equal(bgm_player.bus, &"Music", "BGMPlayer is assigned to 'Music' bus")
		assert_false(bgm_player.autoplay, "BGMPlayer autoplay is disabled")
		assert_true(bgm_player.stream != null, "BGMPlayer has audio stream assigned")

	main.free()

func test_backwards_compatibility() -> void:
	print("\nScenario: Backwards Compatibility Across Preloaded Scene Nodes")
	var main = MainScene.instantiate()
	assert_true(main.has_node("Stage"), "Stage child is present")
	assert_true(main.has_node("Camera2D"), "Camera2D child is present")
	assert_true(main.has_node("P1"), "P1 child is present")
	assert_true(main.has_node("P2"), "P2 child is present")
	assert_true(main.has_node("HUD"), "HUD child is present")
	assert_true(main.has_node("BGMPlayer"), "BGMPlayer child is present")
	main.free()
