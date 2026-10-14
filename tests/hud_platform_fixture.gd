extends "res://tests/bright_run_fixture.gd"
func _enter_tree() -> void:
	if simulate_android:
		get_node("Game/Column/Board").set_script(load("res://tests/android_board_fixture.gd"))

func _is_native_android() -> bool:
	return simulate_android

func _set_orientation(_landscape: bool) -> void:
	pass # Device orientation is a physical-platform check; geometry remains exercised.
