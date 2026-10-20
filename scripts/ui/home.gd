extends Screen
## The home screen: crystals and settings on top, floating gems over the title, a big button
## for each main mode (Classic with its record, Levels with the next level and the chapter's
## progress), tiles for the other modes, the daily challenge with the time until the next one
## (and a friend's challenge from a link), a row of round buttons with red badges. Gems drift
## up behind it all (GemDrift).

signal mode_chosen(mode_id: String)
signal daily_pressed
signal challenge_pressed

## The challenge from the launch link ({"mode", "score", ...}), shown as a card; set by main.
var challenge := {}
var _t := 0.0
var _clock := -1  ## the second the daily countdown last showed


func _ready() -> void:
	%CrystalPill.add_theme_stylebox_override("normal", UiKit.box(Color(0.03, 0.05, 0.16, 0.6), Color(UiKit.CRYSTAL, 0.5), 2, 99, Vector4(12, 6, 16, 6)))
	%CrystalPill.add_theme_stylebox_override("hover", UiKit.box(Color(0.06, 0.09, 0.25, 0.7), UiKit.CRYSTAL, 2, 99, Vector4(12, 6, 16, 6)))
	%CrystalPill.add_theme_stylebox_override("pressed", UiKit.box(Color(0.06, 0.09, 0.25, 0.7), UiKit.CRYSTAL, 2, 99, Vector4(12, 6, 16, 6)))
	%CrystalPill.add_theme_color_override("font_color", UiKit.CRYSTAL)
	%CrystalPill.add_theme_font_override("font", UiKit.NUMBER_FONT)
	%CrystalPill.add_theme_font_size_override("font_size", 20)
	if OS.has_feature("android"):  # phones: the upright levels first, the wide classic second
		%VBox.move_child(%Levels, %Classic.get_index())


func refresh() -> void:
	%CrystalPill.text = str(Progress.crystals)
	var best := Save.best_for("classic")
	%Classic.line = L.t("best") + ": " + str(best) if best > 0 else L.t("home_first")
	var lv := Progress.max_unlocked()
	var ch := BoardLogic.chapter_of(lv)
	var in_ch := (lv - 1) % BoardLogic.CHAPTER_SIZE
	%Levels.title = L.t("home_level", {"n": lv})
	%Levels.line = L.t("chapter_" + str(ch % 5)) + " · " + "%d/%d" % [in_ch, BoardLogic.CHAPTER_SIZE]
	%Levels.progress = float(in_ch) / BoardLogic.CHAPTER_SIZE
	%Bright.line = L.t("best") + ": " + str(Save.best_for("bright"))
	%Zen.line = L.t("best") + ": " + str(Save.best_for("zen"))
	%Puzzle.line = L.t("puzzles_solved", {"n": Progress.puzzles})
	var due := Progress.unclaimed()
	%Tasks.badge = str(due) if due > 0 else ""
	%Gift.badge = "!" if Progress.gift_ready() else ""
	var adue := Progress.achievements_due()
	%More.badge = str(adue) if adue > 0 else ""
	%Challenge.visible = not challenge.is_empty()
	if not challenge.is_empty():
		%Challenge.title = L.t("ch_card", {"n": challenge.score, "m": L.t("mode_" + str(challenge.mode))})
	if Progress.daily_reward_ready():
		%Daily.title = L.t("daily_card", {"n": Progress.DAILY_CRYSTALS})
		%Daily.badge = "!"
	else:
		%Daily.title = L.t("daily_card_done", {"n": Save.daily_best_for(Time.get_date_string_from_system(true))})
		%Daily.badge = ""
	_clock = -1
	_update_clock()


## "New in 05:12:33": the daily board changes at midnight UTC (the date it is seeded with).
func _update_clock() -> void:
	var now := int(Time.get_unix_time_from_system())
	if now == _clock:
		return
	_clock = now
	var left := 86400 - now % 86400
	%Daily.line = L.t("daily_new_in", {"t": "%02d:%02d:%02d" % [left / 3600, left / 60 % 60, left % 60]})


func focus_button() -> Button:
	match str(Save.mode):
		"levels":
			return %Levels
		"bright":
			return %Bright
		"zen":
			return %Zen
		"puzzle":
			return %Puzzle
	return %Classic


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var gems := %Gems.get_children()
	for i in gems.size():
		gems[i].rotation = sin(_t * 1.3 + i * 1.7) * 0.12
		gems[i].position.y = sin(_t * 1.6 + i * 2.1) * 4.0
		gems[i].scale = Vector2.ONE * (1.0 + 0.06 * sin(_t * 2.0 + i * 2.1))
	_update_clock()


func layout(view: Vector2, _compact: bool) -> void:
	var w := clampf(view.x - 40.0, 280.0, 520.0)
	%VBox.custom_minimum_size.x = w
	%Title.add_theme_font_size_override("font_size", int(clampf(w / 9.5, 34.0, 54.0)))
	%Gems.visible = view.y >= 820
	%Tagline.visible = view.y >= 880
	%VBox.add_theme_constant_override("separation", 8 if view.y < 700 else 12)
	# the mode buttons grow to fill tall screens: what is left after the fixed parts, shared out
	# (two big buttons, a row of tiles at 0.9 and the daily card at 0.8 of their height)
	var fixed := 48.0 + 110.0 + 96.0 + 12.0 * 9 + 48.0
	if %Gems.visible:
		fixed += 76.0
	if %Tagline.visible:
		fixed += 46.0
	var big := clampf((view.y - fixed) / 4.7, 64.0, 124.0)
	%Classic.custom_minimum_size.y = big
	%Levels.custom_minimum_size.y = big
	for t in %Tiles.get_children():
		t.custom_minimum_size.y = big * 0.9
	%Daily.custom_minimum_size.y = big * 0.8
	%Challenge.custom_minimum_size.y = big * 0.8


## Still too tall (a short window, wrapped round buttons): tighter spacing, then no gems, then
## scale the rest down around the screen's centre.
func fit(_avail: float) -> void:
	var v: VBoxContainer = %VBox
	v.scale = Vector2.ONE
	var top_m := get_theme_constant("margin_top")
	var avail := size.y - top_m - get_theme_constant("margin_bottom")
	if v.get_combined_minimum_size().y > avail:
		v.add_theme_constant_override("separation", 6)
	if v.get_combined_minimum_size().y > avail:
		%Gems.visible = false
		%Tagline.visible = false
	var h := v.get_combined_minimum_size().y
	if h > avail:
		var k := maxf(avail / h, 0.5)
		# pivot chosen so the scaled content ends up centred on the screen, not at the overflowing box's middle
		var top := top_m + (avail - h * k) / 2.0
		v.pivot_offset = Vector2(v.size.x / 2.0, (top - v.position.y) / (1.0 - k))
		v.scale = Vector2.ONE * k


func _on_mode_pressed(id: String) -> void:
	click()
	mode_chosen.emit(id)


func _on_daily_pressed() -> void:
	click()
	daily_pressed.emit()


func _on_challenge_pressed() -> void:
	click()
	challenge_pressed.emit()


func _on_settings_pressed() -> void:
	click()
	navigate.emit(&"settings")


func _on_gift_pressed() -> void:
	click()
	navigate.emit(&"gift")


func _on_tasks_pressed() -> void:
	click()
	navigate.emit(&"tasks")


func _on_collection_pressed() -> void:
	click()
	navigate.emit(&"collection")


func _on_leaders_pressed() -> void:
	navigate.emit(&"leaders")


func _on_more_pressed() -> void:
	click()
	navigate.emit(&"more")
