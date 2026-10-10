extends Screen
## The daily gift: a week of growing rewards for coming back every day.

const DAY := preload("res://scenes/ui/parts/gift_day.tscn")


func refresh() -> void:
	UiKit.clear(%Days)
	var ready := Progress.gift_ready()
	var next_day := (Progress.streak % 7) + 1 if ready else ((Progress.streak - 1) % 7) + 1
	for d in range(1, 8):
		var day := DAY.instantiate()
		%Days.add_child(day)
		day.setup(d, Progress.gift_amount(d), d == next_day)
	$VBox/Buttons/Take.visible = ready
	%Line.text = L.t("gift_day7") if ready else L.t("gift_tomorrow")


func focus_button() -> Button:
	return $VBox/Buttons/Take if Progress.gift_ready() else $VBox/Buttons/Close


func _on_take_pressed() -> void:
	var r := Progress.open_gift()
	if r.is_empty():
		return
	Sfx.play("level")
	toast.emit(L.t("gift_got", {"n": r.crystals}) + ("  ·  " + L.t("gift_look") if int(r.look) >= 0 else ""))
	refresh()


func _on_close_pressed() -> void:
	click()
	navigate.emit(&"back")
