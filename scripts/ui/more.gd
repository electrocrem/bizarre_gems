extends Screen
## "More" from the home screen: the less used screens, so the home row stays short.


func refresh() -> void:
	var due := Progress.achievements_due()
	$VBox/Achievements.text = L.t("achievements") + (" (%d)" % due if due > 0 else "")


func _on_achievements_pressed() -> void:
	click()
	navigate.emit(&"achievements")


func _on_stats_pressed() -> void:
	click()
	navigate.emit(&"stats")


func _on_rules_pressed() -> void:
	click()
	navigate.emit(&"rules")


func _on_settings_pressed() -> void:
	navigate.emit(&"settings")


func _on_close_pressed() -> void:
	click()
	navigate.emit(&"back")
