extends HBoxContainer
## One line of a leaderboard. The player's own line is gold.


func setup(rank: int, player: String, score: int, me: bool) -> void:
	%Rank.text = str(rank)
	if player.is_empty():
		player = L.t("anon")
	if me:
		player += " · " + L.t("you")
		%PlayerName.theme_type_variation = &"Bold"
	%PlayerName.text = player
	%Score.text = str(score)
	var color := UiKit.MENU_BRASS if me else UiKit.MENU_TEXT
	%PlayerName.add_theme_color_override("font_color", color)
	%Score.add_theme_color_override("font_color", color)
