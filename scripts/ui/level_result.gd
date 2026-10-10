extends Screen
## The end of a map level or puzzle: stars (levels only), what next.

signal next_pressed
signal retry_pressed
signal map_pressed
signal double_pressed
signal continue_pressed

const DIM_STAR := Color(0.25, 0.3, 0.5, 1)


## r: title, outcome, line, stars (-1: a puzzle, no stars), can_next, reward (crystals for the x2 ad),
## continue_text ("" hides the continue button)
func show_result(r: Dictionary) -> void:
	%Title.text = r.title
	%Outcome.text = r.outcome
	%Line.text = r.line
	%Next.visible = r.can_next
	%Stars.visible = r.stars >= 0
	var reward: int = r.reward
	%Double.visible = reward > 0
	%Double.text = L.t("double_ad", {"n": reward})
	%Continue.visible = r.continue_text != ""
	%Continue.text = r.continue_text
	for st in %Stars.get_children():
		st.modulate = DIM_STAR
		st.scale = Vector2.ONE


## Light up `got` stars one by one (call once the dialog is on screen).
func play_stars(got: int) -> void:
	for i in got:
		var st: TextureRect = %Stars.get_child(i)
		var tw := create_tween()
		tw.tween_interval(0.35 + i * 0.35)
		tw.tween_callback(func():
			st.modulate = UiKit.BRASS
			st.pivot_offset = st.size / 2
			st.scale = Vector2.ONE * 1.5
			Sfx.play("star", 1.0 + i * 0.12))
		tw.tween_property(st, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_double() -> void:
	%Double.visible = false


func _on_next_pressed() -> void:
	click()
	next_pressed.emit()


func _on_retry_pressed() -> void:
	click()
	retry_pressed.emit()


func _on_map_pressed() -> void:
	click()
	map_pressed.emit()


func _on_double_pressed() -> void:
	click()
	double_pressed.emit()


func _on_continue_pressed() -> void:
	click()
	continue_pressed.emit()
