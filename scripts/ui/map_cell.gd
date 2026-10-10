extends VBoxContainer
## A level or puzzle on the map: its number (or a lock) and its stars / check mark under it.

signal chosen(n: int)

var n := 0


## `stars`: 0-3 for a level, -1 for an unsolved puzzle, 4 for a solved one.
func setup(number: int, locked: bool, current: bool, milestone: bool, stars: int) -> void:
	n = number
	var b: Button = $Button
	b.disabled = locked
	b.text = "" if locked else str(n)
	b.icon = UiKit.icon("lock") if locked else (UiKit.icon("medal") if milestone else null)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER if locked else HORIZONTAL_ALIGNMENT_LEFT
	b.theme_type_variation = &"PrimaryButton" if current else &""
	var marks := %Marks.get_children()
	if stars < 0 or stars == 4:  # puzzles: one check mark
		marks[0].texture = UiKit.icon("check")
		marks[0].modulate = UiKit.GREEN if stars == 4 else Color(1, 1, 1, 0.12)
		marks[1].visible = false
		marks[2].visible = false
	else:
		for i in 3:
			marks[i].modulate = UiKit.BRASS if i < stars else Color(1, 1, 1, 0.15)


func _on_button_pressed() -> void:
	chosen.emit(n)
