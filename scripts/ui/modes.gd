extends Screen
## Mode selection: a card per mode (scenes/ui/parts/mode_card.tscn) with its best result.

signal mode_chosen(mode_id: String)


func _ready() -> void:
	if OS.has_feature("android"):  # phones start with the upright modes; the wide classic goes last
		%Cards.move_child(%Cards.get_node("Classic"), -1)
	for card in %Cards.get_children():
		card.visible = card.mode_id in ["classic","bright"]
		card.chosen.connect(func(id: String):
			if id in ["classic","bright"]: click(); mode_chosen.emit(id))


func refresh() -> void:
	for card in %Cards.get_children():
		var id: String = card.mode_id
		var line := L.t("best") + ": " + str(Save.best_for(id))
		if id == "levels":
			line = L.t("stars_total") + ": " + str(Progress.total_stars())
		elif id == "puzzle":
			line = L.t("puzzles_solved", {"n": Progress.puzzles})
		card.set_best(line)


## The card of the mode played last gets the focus.
func focus_button() -> Button:
	for card in %Cards.get_children():
		if card.visible and card.mode_id == str(Save.mode):
			return card.play_button()
	return null


func layout(view: Vector2, _compact: bool) -> void:
	%Cards.columns = 2 if view.x >= 880 else 1
	$VBox/Head/Title.add_theme_font_size_override("font_size",24 if view.x < 440 else 32)
	for card in %Cards.get_children():
		card.custom_minimum_size.x = 400 if view.x >= 880 else clampf(size.x - 32,260,440)


func _on_back_pressed() -> void:
	click()
	navigate.emit(&"back")
