extends Screen
## The home screen: floating gems over the title, a big Play, the best score, the daily
## challenge (and a friend's challenge from a link), crystals, a row of round buttons.

signal play_pressed
signal daily_pressed
signal challenge_pressed

## The challenge from the launch link ({"mode", "score", ...}), shown as a card; set by main.
var challenge := {}
var _t := 0.0


func refresh() -> void:
	%Collection.visible = Progress.COSMETICS_ENABLED
	%Best.text = L.t("best") + ": " + str(Save.best_for(str(Save.mode)))
	%Crystals.text = str(Progress.crystals)
	var due := Progress.unclaimed()
	%Tasks.badge = " (%d)" % due if due > 0 else ""
	%Gift.badge = " !" if Progress.gift_ready() else ""
	var adue := Progress.achievements_due()
	%More.badge = " (%d)" % adue if adue > 0 else ""
	%Challenge.visible = not challenge.is_empty()
	if not challenge.is_empty():
		%Challenge.text = L.t("ch_card", {"n": challenge.score, "m": L.t("mode_" + str(challenge.mode))})
	if Progress.daily_reward_ready():
		%Daily.text = L.t("daily_card", {"n": Progress.DAILY_CRYSTALS})
	else:
		%Daily.text = L.t("daily_card_done", {"n": Save.daily_best_for(Time.get_date_string_from_system(true))})


func focus_button() -> Button:
	return %Play


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var gems := %Gems.get_children()
	for i in gems.size():
		gems[i].rotation = sin(_t * 1.3 + i * 1.7) * 0.12
		gems[i].scale = Vector2.ONE * (1.0 + 0.06 * sin(_t * 2.0 + i * 2.1))
	%Play.pivot_offset = %Play.size / 2
	%Play.scale = Vector2.ONE * (1.0 + 0.035 * sin(_t * 3.0))


func layout(view: Vector2, _compact: bool) -> void:
	var short := view.y < 600
	%Title.add_theme_font_size_override("font_size", 40 if short else (46 if view.x < 600 else 64))
	%Gems.visible = view.y >= 560
	%VBox.add_theme_constant_override("separation", 8 if short else 18)
	%Play.custom_minimum_size = Vector2(260, 62 if short else 78)


## When the round buttons wrap (a narrow window, long captions) the screen can still overflow:
## then tighter spacing, then no gems, then scale the rest down around the screen's centre.
func fit(_avail: float) -> void:
	var v: VBoxContainer = %VBox
	v.scale = Vector2.ONE
	var top_m := get_theme_constant("margin_top")
	var avail := size.y - top_m - get_theme_constant("margin_bottom")
	if v.get_combined_minimum_size().y > avail:
		v.add_theme_constant_override("separation", 8)
	if v.get_combined_minimum_size().y > avail:
		%Gems.visible = false
	var h := v.get_combined_minimum_size().y
	if h > avail:
		var k := maxf(avail / h, 0.5)
		# pivot chosen so the scaled content ends up centred on the screen, not at the overflowing box's middle
		var top := top_m + (avail - h * k) / 2.0
		v.pivot_offset = Vector2(v.size.x / 2.0, (top - v.position.y) / (1.0 - k))
		v.scale = Vector2.ONE * k


func _on_play_pressed() -> void:
	click()
	play_pressed.emit()


func _on_daily_pressed() -> void:
	click()
	daily_pressed.emit()


func _on_challenge_pressed() -> void:
	click()
	challenge_pressed.emit()


func _on_gift_pressed() -> void:
	click()
	navigate.emit(&"gift")


func _on_tasks_pressed() -> void:
	click()
	navigate.emit(&"tasks")


func _on_collection_pressed() -> void:
	if not Progress.COSMETICS_ENABLED:
		return
	click()
	navigate.emit(&"collection")


func _on_leaders_pressed() -> void:
	navigate.emit(&"leaders")


func _on_more_pressed() -> void:
	click()
	navigate.emit(&"more")
