extends SceneTree

func _init():
	var test = load("res://tests/test_engine_foundation.gd").new()
	var success: bool = test.run_all()
	if success:
		print("\n[ALL TESTS PASSED SUCCESSFULLY]")
		quit(0)
	else:
		printerr("\n[TESTS FAILED]")
		quit(1)
