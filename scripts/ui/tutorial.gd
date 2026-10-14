extends PanelContainer
## Scene-owned practice card. The sequence controller supplies state; this view never scores.
signal next_pressed
signal retry_pressed
signal skip_pressed
signal exit_pressed

func _ready() -> void:
	theme = UiKit.menu_theme()
	$Card/Actions/Next.pressed.connect(func(): next_pressed.emit())
	$Card/Actions/Retry.pressed.connect(func(): retry_pressed.emit())
	$Card/Actions/Skip.pressed.connect(func(): skip_pressed.emit())
	$Card/Actions/Exit.pressed.connect(func(): exit_pressed.emit())
	add_theme_stylebox_override("panel", UiKit.box(Color(UiKit.MENU_PANEL,.94),Color(UiKit.MENU_BRASS,.45),1,14,Vector4(12,12,12,12)))
	$Card.minimum_size_changed.connect(func(): get_parent().get_parent().get_parent()._layout_game.call_deferred())
	for action in $Card/Actions.get_children():
		if not action is Button: continue
		for slot in ["normal","hover","pressed","disabled"]:
			var style := action.get_theme_stylebox(slot).duplicate() as StyleBoxFlat
			style.content_margin_left = 6
			style.content_margin_right = 6
			style.content_margin_top = 6
			style.content_margin_bottom = 6
			if action.name != "Next":
				style.set_border_width_all(0)
				style.bg_color = Color.TRANSPARENT if slot in ["normal","disabled"] else Color(UiKit.MENU_BRASS,.12)
			action.add_theme_stylebox_override(slot,style)

func present(game, sequence) -> void:
	var id: String = sequence.lesson_id()
	visible = game.mode.kind == "tutorial" and game.state == game.State.PLAYING and game._current_screen() == null
	$Card/Instruction.visible = true
	$Card/Caption.text = "%d/%d · %s" % [sequence.tut_step+1,sequence.Lessons.STEPS.size(),L.t("lesson_"+id+"_title")]
	if not sequence.tut_waiting:
		if id == "special":
			$Card/Caption.text += " · " + L.t("lesson_special_progress", {"n":game.keeper.precise_streak,"s":"%.1f" % game.keeper.special_window_left(game.play_time)})
		elif sequence.Lessons.goal(id) > 1:
			$Card/Caption.text += " · %d/%d" % [sequence.tut_hits,sequence.Lessons.goal(id)]
	var instruction := L.t("lesson_"+id)
	if sequence.tut_clock_running:
		instruction = L.t("lesson_clock_wait" if id == "clock" else "lesson_timeout_wait")
	elif id == "chameleon" and sequence.tut_hits >= game.CHAM_EVERY:
		instruction = L.t("lesson_chameleon_take")
	$Card/Instruction.set_meta("instruction",instruction)
	$Card/Instruction.text = L.t(sequence.tut_feedback_key,sequence.tut_feedback_args) if sequence.tut_feedback_key != "" else instruction
	if not sequence.tut_waiting and sequence.tut_feedback_key != "" and sequence.tut_feedback_key not in ["lesson_wrong","lesson_occupied","lesson_no_match","lesson_idle"]:
		$Card/Instruction.text += "\n" + (instruction if id == "chameleon" and sequence.tut_hits >= game.CHAM_EVERY else L.t("lesson_continue"))
	$Card/Actions/Next.visible = sequence.tut_waiting
	$Card/Actions/Next.text = L.t("lesson_finish" if sequence.tut_step == 19 else "next")
	$Card/Actions/Retry.disabled = game.dealing
	$Card/Actions/Retry.tooltip_text = L.t("lesson_retry")
	$Card/Actions/Skip.text = L.t("lesson_skip")
	$Card/Actions/Exit.tooltip_text = L.t("menu")
	game._layout_game.call_deferred()
