extends Screen
## The end of a timed game: score, records, rewards, the best strike replayed, what next.

signal again_pressed
signal double_pressed
signal continue_pressed
signal shuffle_pressed
signal share_pressed
signal menu_pressed


## r: title, score, new_best (text or ""), line, reward (crystals), can_continue, can_shuffle, can_share
func show_result(r: Dictionary) -> void:
	%Title.text = r.title
	%Score.text = str(r.score)
	%NewBest.text = r.new_best
	%NewBest.visible = r.new_best != ""
	%Line.text = r.line
	var reward: int = r.reward
	%Reward.text = L.t("reward_line", {"n": reward})
	%Reward.visible = reward > 0
	%Double.text = L.t("double_ad", {"n": reward})
	%Double.visible = reward > 0
	%Continue.visible = r.can_continue
	%Shuffle.visible = r.can_shuffle
	%Share.visible = r.can_share
	set_ad_pending(false)


func set_ad_pending(pending: bool) -> void:
	for button in [%Double, %Continue, %Shuffle, %Again]:
		button.disabled = pending


## The game's best strike, looped; `tile` maps a gem kind to its texture.
func show_best_strike(strike: Dictionary, tile: Callable) -> void:
	%BestStrike.visible = not strike.is_empty() and not strike.parts.is_empty()
	if %BestStrike.visible:
		%Caption.text = L.t("best_strike", {"n": strike.n, "p": strike.points})
		(%Replay as StrikeReplay).show_strike(strike, tile, UiKit.NUMBER_FONT)


func hide_double() -> void:
	%Double.visible = false


func hide_shuffle() -> void:
	%Shuffle.visible = false


func _on_again_pressed() -> void:
	click()
	%Again.disabled = true  # until the ad before the next game is over
	again_pressed.emit()


func _on_double_pressed() -> void:
	click()
	double_pressed.emit()


func _on_continue_pressed() -> void:
	click()
	continue_pressed.emit()


func _on_shuffle_pressed() -> void:
	click()
	shuffle_pressed.emit()


func _on_share_pressed() -> void:
	click()
	share_pressed.emit()


func _on_leaders_pressed() -> void:
	navigate.emit(&"leaders")


func _on_menu_pressed() -> void:
	click()
	menu_pressed.emit()


func layout(_view: Vector2, compact: bool) -> void:
	%Score.add_theme_font_size_override("font_size", 52 if compact else 72)
