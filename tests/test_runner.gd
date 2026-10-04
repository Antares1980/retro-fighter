extends SceneTree

func _init():
	var test_foundation = load("res://tests/test_engine_foundation.gd").new()
	var success_foundation: bool = test_foundation.run_all()

	var test_hitbox = load("res://tests/test_hitbox_hurtbox.gd").new()
	var success_hitbox: bool = test_hitbox.run_all()

	if success_foundation and success_hitbox:
		print("\n[ALL TESTS PASSED SUCCESSFULLY]")
		quit(0)
	else:
		printerr("\n[TESTS FAILED]")
		quit(1)
