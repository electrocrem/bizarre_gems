extends Screen
## Today's tasks with their progress; a finished task pays crystals when claimed.

const ROW := preload("res://scenes/ui/parts/progress_row.tscn")


func refresh() -> void:
	Progress.refresh_tasks()
	%Crystals.text = str(Progress.crystals)
	UiKit.clear(%List)
	for i in Progress.tasks.size():
		var t: Dictionary = Progress.tasks[i]
		var row := ROW.instantiate()
		%List.add_child(row)
		row.setup(L.t("task_" + str(t.id), {"n": t.goal}), int(t.progress), int(t.goal), int(t.reward), bool(t.claimed))
		var idx := i
		row.claim_pressed.connect(func():
			Progress.claim(idx)
			Sfx.play("star")
			refresh())
	relayout_requested.emit()


func _on_close_pressed() -> void:
	click()
	navigate.emit(&"back")
