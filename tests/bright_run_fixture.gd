extends "res://scripts/main.gd"
## Real upstream scene containers; only device, system date and safe insets are simulated.
var simulate_android := false
var test_insets := Rect2()
var test_day := "2026-10-14"

func _is_touch_device() -> bool:
	return simulate_android

func _safe_insets() -> Rect2:
	return test_insets

func _apply_ui_scale() -> void:
	pass

func _today() -> String:
	return test_day
