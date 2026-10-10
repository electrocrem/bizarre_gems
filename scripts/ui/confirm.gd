extends Screen
## "Leave to the menu?" before a running game is thrown away.

signal leave_pressed


func _on_stay_pressed() -> void:
	click()
	navigate.emit(&"pause")


func _on_leave_pressed() -> void:
	click()
	leave_pressed.emit()
