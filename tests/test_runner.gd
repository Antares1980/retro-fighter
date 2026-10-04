extends SceneTree

func _init():
	var test_foundation = load("res://tests/test_engine_foundation.gd").new()
	var success_foundation: bool = test_foundation.run_all()

	var test_hitbox = load("res://tests/test_hitbox_hurtbox.gd").new()
	var success_hitbox: bool = test_hitbox.run_all()

	var test_fighter = load("res://tests/test_fighter.gd").new()
	var success_fighter: bool = test_fighter.run_all()

	var test_camera = load("res://tests/test_camera.gd").new()
	var success_camera: bool = test_camera.run_all()

	if success_foundation and success_hitbox and success_fighter and success_camera:
		print("\n[ALL TESTS PASSED SUCCESSFULLY]")
		quit(0)
	else:
		printerr("\n[TESTS FAILED]")
		quit(1)
