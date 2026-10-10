extends HBoxContainer
## A task or achievement: its text, a progress bar, and a claim button once it is done.

signal claim_pressed


## `icon_color` shows the medal icon in that colour and makes the row a little smaller
## (achievements, a long list); leave it transparent for none.
func setup(text: String, progress: int, goal: int, reward: int, claimed: bool, icon_color := Color.TRANSPARENT) -> void:
	if icon_color.a > 0.0:
		%Name.add_theme_font_size_override("font_size", 17)
		%Bar.custom_minimum_size.y = 6
		%Done.add_theme_font_size_override("font_size", 24)
		%Count.add_theme_font_size_override("font_size", 15)
	%Name.text = text
	%Bar.max_value = goal
	%Bar.value = progress
	%Icon.visible = icon_color.a > 0.0
	%Icon.modulate = icon_color
	var done := progress >= goal
	%Done.visible = claimed
	%Claim.visible = done and not claimed
	%Claim.text = "+%d" % reward
	%Count.visible = not done and not claimed
	%Count.text = "%d/%d" % [progress, goal]


func _on_claim_pressed() -> void:
	claim_pressed.emit()
