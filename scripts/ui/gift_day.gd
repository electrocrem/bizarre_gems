extends VBoxContainer
## One day of the daily gift streak; the day you get next is highlighted.


func setup(day: int, amount: int, next: bool) -> void:
	%Day.text = L.t("day_n", {"n": day})
	%Amount.text = "+%d" % amount
	%Amount.add_theme_color_override("font_color", UiKit.BRASS if next else UiKit.CREAM)
	%Amount.add_theme_stylebox_override("normal", UiKit.box(Color(UiKit.BRASS, 0.25) if next else Color(0, 0, 0, 0.25),
		UiKit.BRASS if next else Color(1, 1, 1, 0.1), 2, 10, Vector4(6, 8, 6, 8)))
