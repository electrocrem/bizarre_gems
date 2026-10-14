extends Screen
## Achievements: lifetime goals, each pays crystals once.

const ROW := preload("res://scenes/ui/parts/progress_row.tscn")


func refresh() -> void:
	UiKit.clear(%List)
	for i in Progress.ACHIEVEMENTS.size():
		var a: Dictionary = Progress.ACHIEVEMENTS[i]
		var got: bool = a.id in Progress.achieved
		var done := got or Progress.achievement_done(i)
		var row := ROW.instantiate()
		%List.add_child(row)
		row.setup(L.t("ach_" + str(a.id), {"n": a.goal}), Progress.achievement_progress(i), int(a.goal), int(a.reward), got,
			UiKit.MENU_BRASS if done else Color(1, 1, 1, 0.25))
		var idx := i
		row.claim_pressed.connect(func():
			Progress.claim_achievement(idx)
			Sfx.play("star")
			refresh())
	relayout_requested.emit()


func fit(avail: float) -> void:
	%Scroll.custom_minimum_size.y = 0
	var fixed := get_combined_minimum_size().y
	var want: float = %List.size.y if %List.size.y > 0.0 else %List.get_combined_minimum_size().y
	%Scroll.custom_minimum_size.y = clampf(avail - fixed, 80.0, maxf(80.0, want))


func _on_close_pressed() -> void:
	click()
	navigate.emit(&"back")
