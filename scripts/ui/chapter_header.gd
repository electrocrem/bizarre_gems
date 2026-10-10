extends PanelContainer
## The heading over each chapter of the level map: name, the boss rule, stars and rewards.

signal reward_claimed(n: int)


func setup(c: int, sky: Color) -> void:
	add_theme_stylebox_override("panel", UiKit.box(Color(sky, 0.55), Color(sky.lightened(0.35), 0.8), 2, 14, Vector4(14, 8, 14, 8)))
	%ChapterName.text = L.t("chapter_n", {"n": c + 1}) + " · " + L.t("chapter_%d" % (c % 5))
	%Rule.text = L.t("boss_rule") + " " + L.t("rule_" + str(BoardLogic.CHAPTER_RULES[c % BoardLogic.CHAPTER_RULES.size()]))
	var st := Progress.chapter_stats(c)
	%Stars.text = "%d/%d" % [st.stars, st.max]
	for what in Progress.chapter_due(c):
		var kind: String = what
		var b := Button.new()
		b.text = "+%d" % (Progress.CHAPTER_DONE if kind == "done" else Progress.CHAPTER_FULL)
		b.icon = UiKit.icon("crystal")
		b.theme_type_variation = &"PrimaryButton"
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func():
			var n := Progress.claim_chapter(c, kind)
			if n > 0:
				reward_claimed.emit(n))
		%Rewards.add_child(b)
