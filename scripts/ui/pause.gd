extends Screen
## Pause: resume, leave to the menu (asks first), settings.

signal resume_pressed


func _on_resume_pressed() -> void:
	click()
	resume_pressed.emit()


func _on_menu_pressed() -> void:
	click()
	navigate.emit(&"confirm")


func _on_settings_pressed() -> void:
	navigate.emit(&"settings")
