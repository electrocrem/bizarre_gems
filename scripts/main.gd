extends Control
## Game flow and UI. The interface is built in code so layout adapts to any
## screen Yandex Games gives us, from a phone held upright to a wide desktop.

enum State { MENU, PLAYING, PAUSED, OVER }

const START_TIME := 120.0
const CONTINUE_TIME := 15.0
const HINT_AFTER := 15.0
const TOTAL_GEMS := BoardLogic.KINDS * BoardLogic.PER_KIND

const BRASS := Color("#d2ab55")
const BRASS_LIGHT := Color("#f7e2a8")
const CREAM := Color("#f1e8d4")
const MUTED := Color("#8ea6a1")
const DANGER := Color("#ff5d4f")
const INK := Color("#0a1315")
const PANEL := Color(0.035, 0.086, 0.094, 0.96)

const ICONS := {
	"pause": preload("res://assets/ui/icon_pause.png"),
	"play": preload("res://assets/ui/icon_play.png"),
	"sound_on": preload("res://assets/ui/icon_sound_on.png"),
	"sound_off": preload("res://assets/ui/icon_sound_off.png"),
	"music_on": preload("res://assets/ui/icon_music_on.png"),
	"music_off": preload("res://assets/ui/icon_music_off.png"),
	"trophy": preload("res://assets/ui/icon_trophy.png"),
	"home": preload("res://assets/ui/icon_home.png"),
	"video": preload("res://assets/ui/icon_video.png"),
	"shuffle": preload("res://assets/ui/icon_shuffle.png"),
	"restart": preload("res://assets/ui/icon_restart.png"),
	"settings": preload("res://assets/ui/icon_settings.png"),
	"calendar": preload("res://assets/ui/icon_calendar.png"),
}

var logic := BoardLogic.new()
var keeper := ScoreKeeper.new()
var daily := false
var ambient: Ambient
var shown_score := 0.0
var play_time := 0.0
var rng := RandomNumberGenerator.new()
var state := State.MENU
var time_left := START_TIME
var score := 0
var cleared := 0
var used_continue := false
var used_shuffle := false
var idle := 0.0
var end_reason := ""
var last_tick := -1
var leaders_return: Control
var autoplay := false  # debug builds only: plays itself, for testing effects and screenshots
var _auto_t := 0.0

var f_display: Font
var f_body: Font
var f_bold: Font
var f_num: Font

var board: BoardView
var hud: HBoxContainer
var title_label: Label
var time_caption: Label
var time_label: Label
var time_delta: Label
var time_bar: ProgressBar
var score_caption: Label
var score_label: Label
var best_caption: Label
var best_label: Label
var combo_box: VBoxContainer
var combo_mult: Label
var combo_count: Label
var combo_bar: ProgressBar
var banner_box: VBoxContainer
var banner_title: Label
var banner_sub: Label
var btn_pause: Button
var btn_settings: Button
var settings_return: Control
var compact := false
var ui_scale_info := ""
var margin: MarginContainer
var panel_style: StyleBoxFlat
var panel_style_compact: StyleBoxFlat
var dim: ColorRect
var center: CenterContainer
var toast: Label
var bar_fill: StyleBoxFlat
var bar_fill_low: StyleBoxFlat

var menu_panel: PanelContainer
var pause_panel: PanelContainer
var over_panel: PanelContainer
var leaders_panel: PanelContainer
var settings_panel: PanelContainer
var ui := {}  # widgets that carry translated text


func _ready() -> void:
	rng.randomize()
	_load_fonts()
	theme = _make_theme()
	_build()
	_apply_ui_scale()
	get_window().size_changed.connect(_apply_ui_scale)
	get_viewport().size_changed.connect(_on_viewport_resized)
	board.slot_pressed.connect(_on_slot)
	Yandex.pause_requested.connect(_on_platform_pause)
	Yandex.resume_requested.connect(_on_platform_resume)
	Save.changed.connect(_update_hud)
	L.language_changed.connect(_apply_texts)

	var d := _dims()
	logic.setup(d.x, d.y, rng)
	board.logic = logic
	_apply_texts()
	_on_viewport_resized()
	_show_panel(menu_panel)
	_update_hud()
	if OS.is_debug_build():
		autoplay = "--autoplay" in OS.get_cmdline_user_args()
		if OS.has_feature("web"):
			autoplay = autoplay or str(JavaScriptBridge.eval("location.search")).contains("autoplay")
	if Yandex.is_ready:
		_on_sdk_ready()
	else:
		Yandex.sdk_ready.connect(_on_sdk_ready, CONNECT_ONE_SHOT)


func _on_sdk_ready() -> void:
	L.set_language(Yandex.language())
	Save.sync_cloud()
	Yandex.loading_ready()
	Sfx.update_music()


# ================= game flow =================

func start_game(is_daily := false) -> void:
	daily = is_daily
	if daily:
		# the same layout for everyone today: fixed 23x15 shape, seeded by the date
		var r := RandomNumberGenerator.new()
		r.seed = hash("bizarre-gems-" + _today())
		logic.setup(BoardLogic.LONG, BoardLogic.SHORT, r)
		var d := _dims()
		if d.y > d.x:
			logic.transpose()
	else:
		var d := _dims()
		logic.setup(d.x, d.y, rng)
	score = 0
	shown_score = 0.0
	keeper.reset()
	play_time = 0.0
	_update_combo_widget()
	cleared = 0
	time_left = START_TIME
	used_continue = false
	used_shuffle = false
	board.clear_fx()
	board.refresh()
	board.deal_in()
	ambient.pulse(BRASS, 0.6)
	Sfx.play("start")
	_resume_play()


func _today() -> String:
	return Time.get_date_string_from_system(true)


func _resume_play() -> void:
	state = State.PLAYING
	idle = 0.0
	last_tick = -1
	board.interactive = true
	_show_panel(null)
	board.grab_focus()
	Yandex.gameplay(true)
	_update_hud()


func pause_game() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	board.interactive = false
	Yandex.gameplay(false)
	_show_panel(pause_panel)


func go_menu() -> void:
	if state == State.PLAYING:
		Yandex.gameplay(false)
	state = State.MENU
	board.interactive = false
	_show_panel(menu_panel)


func end_game(reason: String) -> void:
	state = State.OVER
	end_reason = reason
	board.interactive = false
	Yandex.gameplay(false)
	var is_best := false
	if daily:
		is_best = Save.submit_daily(score, _today())
	else:
		is_best = Save.submit(score)
		if Yandex.is_authorized():
			Yandex.submit_score(Save.best)
	Sfx.play("over")
	Haptics.buzz("over")
	ui.over_title.text = L.t("stuck" if reason == "stuck" else "times_up")
	ui.over_score.text = str(score)
	ui.over_best.visible = is_best and score > 0
	ui.over_best.text = L.t("new_daily_best" if daily else "new_best")
	ui.over_line.text = L.t("cleared", {"n": cleared, "total": TOTAL_GEMS}) + "\n" + L.t("stats", {"combo": keeper.best_combo, "precise": keeper.precise_count})
	if daily:
		ui.over_line.text = L.t("daily") + " · " + L.t("daily_best", {"n": Save.daily_best_for(_today())}) + "\n" + ui.over_line.text
	ui.btn_continue.visible = reason == "time" and not used_continue
	ui.btn_shuffle.visible = reason == "stuck" and not used_shuffle and logic.gems_left() > 1
	_show_panel(over_panel)
	_update_hud()


func _on_slot(p: Vector2i) -> void:
	if state != State.PLAYING or not logic.is_empty(p):
		return
	board.ripple(p)
	var gone := logic.matches_from(p)
	if gone.is_empty():
		time_left = maxf(0.0, time_left - 1.0)
		board.play_miss(p)
		Sfx.play("miss")
		Haptics.buzz("miss")
		if keeper.miss():
			_combo_break()
		_flash_delta("−1", true)
		if time_left <= 0.0:
			end_game("time")
		return
	var kinds: Array[int] = []
	for g in gone:
		kinds.append(logic.kind_at(g))
	var nshine := logic.shining_count(gone)
	logic.remove(gone)
	var n := gone.size()
	var res := keeper.hit(n, play_time, nshine)
	score = keeper.score
	_pop(score_label, 1.3)
	if nshine > 0:
		Sfx.play("bonus")
		board.play_burst(p, 14 * nshine, false)
		ambient.pulse(Color(1.0, 0.84, 0.4), 0.5)
	cleared += n
	time_left += res.time
	idle = 0.0
	var event: String = res.event
	board.play_knock(p, gone, kinds, res.points, res.mult, event != "")
	Sfx.play("knock%d" % mini(n, 4), 1.0 + mini(res.combo, 12) * 0.025)
	if res.time > 0:
		_flash_delta("+%d" % int(res.time), false)
	if res.tier_up:
		Sfx.play("combo_up", 1.0, -2.0)
		Haptics.buzz("tier")
		ambient.pulse(BRASS, 0.4)
		board.play_wave(p, 1.0)
		board.shake(0.1)
	if event == "precise":
		Sfx.play("precise")
		Haptics.buzz("precise")
		ambient.pulse(BRASS_LIGHT, 0.8)
		board.play_wave(p, 2.0, true)
		board.play_burst(p, 40)
		board.flash(BRASS_LIGHT, 0.22)
		_banner(L.t("precise"), ScoreKeeper.PRECISE_POINTS, ScoreKeeper.PRECISE_TIME, BRASS_LIGHT)
	elif event == "perfect":
		Sfx.play("perfect")
		Haptics.buzz("perfect")
		ambient.pulse(Color("#ff9ed2"), 1.0)
		board.play_wave(p, 3.0, true)
		board.play_burst(p, 90)
		board.flash(Color.WHITE, 0.4)
		board.shake(0.3)
		_banner(L.t("perfect"), ScoreKeeper.PERFECT_POINTS, ScoreKeeper.PERFECT_TIME, Color("#ff9ed2"))
	_update_combo_widget(res.tier_up)
	if autoplay and (event != "" or res.tier_up):
		print("[autoplay] combo=%d mult=%d event=%s" % [res.combo, res.mult, event])
		if event != "":
			_auto_t = -2.0  # hold still so the banner can be captured
	_update_hud()
	if not logic.has_any_move():
		end_game("stuck")


func _process(delta: float) -> void:
	if absf(score - shown_score) > 0.5:
		shown_score = lerpf(shown_score, score, minf(1.0, delta * 10.0))
	else:
		shown_score = score
	score_label.text = str(int(round(shown_score)))
	if state != State.PLAYING:
		return
	time_left -= delta
	play_time += delta
	if keeper.update(play_time):
		_combo_break()
	if keeper.combo >= 2:
		combo_bar.value = keeper.window_left(play_time) / ScoreKeeper.COMBO_WINDOW * 100.0
	idle += delta
	if autoplay:
		_auto_t += delta
		if _auto_t > 0.45:
			_auto_t = 0.0
			_auto_move()
	if idle > HINT_AFTER:
		idle = -1000.0  # one hint per quiet spell
		board.show_hint(logic.find_move())
	var secs := int(ceil(time_left))
	if secs <= 10 and secs != last_tick and secs > 0:
		last_tick = secs
		Sfx.play("tick", 1.0, -4.0)
		_pop(time_label, 1.35)
	if time_left <= 0.0:
		time_left = 0.0
		end_game("time")
	_update_hud()


## Debug autoplay: strike the move that knocks out the most gems.
func _auto_move() -> void:
	var best := Vector2i(-1, -1)
	var best_n := 0
	for y in logic.rows:
		for x in logic.cols:
			var q := Vector2i(x, y)
			if logic.is_empty(q):
				var n := logic.matches_from(q).size()
				if n > best_n:
					best_n = n
					best = q
	if best.x >= 0:
		_on_slot(best)


func _on_continue() -> void:
	Sfx.play("click")
	Yandex.show_rewarded(func(ok: bool):
		if not ok:
			_toast(L.t("ad_failed"))
			return
		used_continue = true
		time_left = CONTINUE_TIME
		_flash_delta("+15", false)
		Sfx.play("bonus")
		_resume_play())


func _on_shuffle() -> void:
	Sfx.play("click")
	Yandex.show_rewarded(func(ok: bool):
		if not ok:
			_toast(L.t("ad_failed"))
			return
		used_shuffle = true
		logic.shuffle_remaining(rng)
		board.clear_fx()
		board.deal_in()
		if logic.has_any_move():
			_resume_play()
		else:
			end_game("stuck"))


func _on_again() -> void:
	Sfx.play("click")
	ui.btn_again.disabled = true
	Yandex.show_fullscreen(func(_shown: bool):
		ui.btn_again.disabled = false
		start_game(daily))


func _on_platform_pause() -> void:
	Sfx.set_platform_paused(true)
	pause_game()


func _on_platform_resume() -> void:
	Sfx.set_platform_paused(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and not OS.has_feature("web"):
		pause_game()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


## Android back button: pause, close the open panel, and only leave the app from the menu.
func _on_back() -> void:
	if settings_panel.visible:
		_close_settings()
	elif leaders_panel.visible:
		_show_panel(leaders_return)
	elif state == State.PLAYING:
		pause_game()
	elif state == State.PAUSED or state == State.OVER:
		go_menu()
	else:
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE, KEY_P]:
			if state == State.PLAYING:
				pause_game()
			elif state == State.PAUSED:
				_resume_play()
			get_viewport().set_input_as_handled()


# ================= leaderboard =================

func _open_leaders(from: Control) -> void:
	Sfx.play("click")
	leaders_return = from
	_show_panel(leaders_panel)
	_refresh_leaders()


func _refresh_leaders() -> void:
	var list: VBoxContainer = ui.leaders_list
	for c in list.get_children():
		c.queue_free()
	ui.btn_login.visible = false
	if not Yandex.available:
		ui.leaders_status.text = L.t("leaders_offline")
		ui.leaders_status.visible = true
		return
	ui.leaders_status.text = L.t("leaders_loading")
	ui.leaders_status.visible = true
	Yandex.fetch_leaderboard(func(res: Dictionary):
		var entries: Array = res.get("entries", [])
		ui.leaders_status.visible = entries.is_empty()
		ui.leaders_status.text = L.t("leaders_empty")
		ui.btn_login.visible = not Yandex.is_authorized()
		for e in entries:
			list.add_child(_leader_row(e))
		_fit_panels.call_deferred())


func _leader_row(e: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var me := bool(e.get("me", false))
	var col := BRASS_LIGHT if me else CREAM
	var rank := _label(str(int(e.get("rank", 0))), f_num, 20, MUTED)
	rank.custom_minimum_size.x = 44
	rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var name_s: String = str(e.get("name", ""))
	if name_s.is_empty():
		name_s = L.t("anon")
	if me:
		name_s += " · " + L.t("you")
	var nm := _label(name_s, f_bold if me else f_body, 20, col)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var sc := _label(str(int(e.get("score", 0))), f_num, 20, col)
	row.add_child(rank)
	row.add_child(nm)
	row.add_child(sc)
	return row


func _on_login() -> void:
	Yandex.open_auth(func(ok: bool):
		if ok:
			Yandex.submit_score(Save.best)
			_refresh_leaders())


# ================= UI building =================

func _load_fonts() -> void:
	var ts := TextServerManager.get_primary_interface()
	var wght := ts.name_to_tag("wght")
	f_display = load("res://assets/fonts/RussoOne-Regular.ttf")
	var manrope: FontFile = load("res://assets/fonts/Manrope-Variable.ttf")
	var mono: FontFile = load("res://assets/fonts/JetBrainsMono-Variable.ttf")
	f_body = _variation(manrope, wght, 560)
	f_bold = _variation(manrope, wght, 800)
	f_num = _variation(mono, wght, 600)


func _variation(base: FontFile, tag: int, weight: int) -> FontVariation:
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {tag: weight}
	return v


func _box(bg: Color, border: Color, bw := 2, radius := 10, pad := Vector4(16, 10, 16, 10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	s.anti_aliasing = true
	return s


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = f_body
	th.default_font_size = 21
	th.set_color("font_color", "Label", CREAM)

	th.set_stylebox("normal", "Button", _box(Color(0, 0, 0, 0.25), Color(BRASS, 0.5)))
	th.set_stylebox("hover", "Button", _box(Color(BRASS, 0.12), BRASS))
	th.set_stylebox("pressed", "Button", _box(Color(BRASS, 0.22), BRASS))
	th.set_stylebox("disabled", "Button", _box(Color(0, 0, 0, 0.2), Color(BRASS, 0.2)))
	th.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), BRASS_LIGHT, 3))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		th.set_color(k, "Button", CREAM)
	th.set_color("font_disabled_color", "Button", Color(CREAM, 0.4))
	th.set_font("font", "Button", f_bold)
	th.set_constant("icon_max_width", "Button", 26)
	th.set_constant("h_separation", "Button", 10)

	th.set_type_variation("PrimaryButton", "Button")
	th.set_stylebox("normal", "PrimaryButton", _box(BRASS, BRASS, 2, 10, Vector4(26, 13, 26, 13)))
	th.set_stylebox("hover", "PrimaryButton", _box(Color("#e2bd68"), Color("#e2bd68"), 2, 10, Vector4(26, 13, 26, 13)))
	th.set_stylebox("pressed", "PrimaryButton", _box(Color("#b8923f"), Color("#b8923f"), 2, 10, Vector4(26, 13, 26, 13)))
	th.set_stylebox("disabled", "PrimaryButton", _box(Color(BRASS, 0.4), Color(BRASS, 0.4), 2, 10, Vector4(26, 13, 26, 13)))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		th.set_color(k, "PrimaryButton", Color("#1b1408"))

	th.set_type_variation("IconButton", "Button")
	for st in ["normal", "hover", "pressed", "disabled"]:
		var b: StyleBoxFlat = th.get_stylebox(st, "Button").duplicate()
		b.content_margin_left = 10
		b.content_margin_right = 10
		th.set_stylebox(st, "IconButton", b)

	panel_style = _box(PANEL, Color(BRASS, 0.45), 2, 16, Vector4(30, 26, 30, 26))
	panel_style_compact = _box(PANEL, Color(BRASS, 0.45), 2, 14, Vector4(18, 16, 18, 16))
	th.set_stylebox("panel", "PanelContainer", panel_style)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(k, "CheckButton", CREAM)
	th.set_font("font", "CheckButton", f_bold)
	th.set_constant("icon_max_width", "CheckButton", 0)
	var on: Texture2D = load("res://assets/ui/switch_on.png")
	var off: Texture2D = load("res://assets/ui/switch_off.png")
	for k in ["checked", "checked_mirrored", "checked_disabled", "checked_disabled_mirrored"]:
		th.set_icon(k, "CheckButton", on)
	for k in ["unchecked", "unchecked_mirrored", "unchecked_disabled", "unchecked_disabled_mirrored"]:
		th.set_icon(k, "CheckButton", off)
	var knob: Texture2D = load("res://assets/ui/knob.png")
	for k in ["grabber", "grabber_highlight", "grabber_disabled"]:
		th.set_icon(k, "HSlider", knob)
	th.set_stylebox("focus", "CheckButton", _box(Color(0, 0, 0, 0), BRASS_LIGHT, 2, 8, Vector4(6, 4, 6, 4)))
	th.set_stylebox("slider", "HSlider", _box(Color(BRASS, 0.2), Color(0, 0, 0, 0), 0, 4, Vector4(0, 4, 0, 4)))
	th.set_stylebox("grabber_area", "HSlider", _box(BRASS, BRASS, 0, 4, Vector4(0, 4, 0, 4)))
	th.set_stylebox("grabber_area_highlight", "HSlider", _box(BRASS_LIGHT, BRASS_LIGHT, 0, 4, Vector4(0, 4, 0, 4)))
	th.set_stylebox("background", "ProgressBar", _box(Color(BRASS, 0.15), Color(0, 0, 0, 0), 0, 3, Vector4.ZERO))
	bar_fill = _box(BRASS, BRASS, 0, 3, Vector4.ZERO)
	bar_fill_low = _box(DANGER, DANGER, 0, 3, Vector4.ZERO)
	th.set_stylebox("fill", "ProgressBar", bar_fill)
	return th


func _label(text: String, font: Font = null, size := 0, color := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	if font:
		l.add_theme_font_override("font", font)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _caption(text: String) -> Label:
	var l := _label(text, f_bold, 13, MUTED)
	l.uppercase = true
	return l


func _para(text: String) -> Label:
	var l := _label(text, f_body, 20)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _button(text: String, icon_name := "", primary := false, cb := Callable()) -> Button:
	var b := Button.new()
	b.text = text
	if icon_name != "":
		b.icon = ICONS[icon_name]
	if primary:
		b.theme_type_variation = "PrimaryButton"
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


func _icon_button(icon_name: String, cb: Callable) -> Button:
	var b := Button.new()
	b.icon = ICONS[icon_name]
	b.theme_type_variation = "IconButton"
	b.custom_minimum_size = Vector2(52, 52)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.pressed.connect(cb)
	return b


func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/ui/velvet.png")
	bg.stretch_mode = TextureRect.STRETCH_TILE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var vig := TextureRect.new()
	vig.texture = preload("res://assets/ui/vignette.png")
	vig.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vig.stretch_mode = TextureRect.STRETCH_SCALE
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)
	ambient = Ambient.new()
	ambient.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ambient)

	margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	# ---- HUD ----
	hud = HBoxContainer.new()
	hud.add_theme_constant_override("separation", 22)
	col.add_child(hud)
	title_label = _label("", f_display, 30, BRASS)
	title_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hud.add_child(title_label)

	var tbox := VBoxContainer.new()
	tbox.add_theme_constant_override("separation", 3)
	tbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tbox.size_flags_stretch_ratio = 2.0
	tbox.custom_minimum_size.x = 130
	time_caption = _caption("")
	tbox.add_child(time_caption)
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 10)
	time_label = _label("120", f_num, 28)
	time_delta = _label("", f_num, 18, BRASS)
	time_delta.modulate.a = 0.0
	trow.add_child(time_label)
	trow.add_child(time_delta)
	tbox.add_child(trow)
	time_bar = ProgressBar.new()
	time_bar.show_percentage = false
	time_bar.custom_minimum_size.y = 6
	time_bar.max_value = 100
	tbox.add_child(time_bar)
	hud.add_child(tbox)

	var sbox := VBoxContainer.new()
	sbox.add_theme_constant_override("separation", 3)
	score_caption = _caption("")
	score_label = _label("0", f_num, 28)
	sbox.add_child(score_caption)
	sbox.add_child(score_label)
	hud.add_child(sbox)
	var bbox := VBoxContainer.new()
	bbox.add_theme_constant_override("separation", 3)
	best_caption = _caption("")
	best_label = _label("0", f_num, 28)
	bbox.add_child(best_caption)
	bbox.add_child(best_label)
	hud.add_child(bbox)

	combo_box = VBoxContainer.new()
	combo_box.add_theme_constant_override("separation", 2)
	combo_box.custom_minimum_size.x = 96
	combo_mult = _label("×2", f_display, 30, BRASS)
	combo_mult.pivot_offset = Vector2(20, 18)
	combo_count = _label("", f_bold, 13, MUTED)
	combo_count.uppercase = true
	combo_bar = ProgressBar.new()
	combo_bar.show_percentage = false
	combo_bar.custom_minimum_size.y = 4
	combo_box.add_child(combo_count)
	combo_box.add_child(combo_mult)
	combo_box.add_child(combo_bar)
	combo_box.modulate.a = 0.0
	hud.add_child(combo_box)

	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	btns.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn_pause = _icon_button("pause", func(): Sfx.play("click"); pause_game())
	btn_settings = _icon_button("settings", _open_settings_from_hud)
	btns.add_child(btn_pause)
	btns.add_child(btn_settings)
	hud.add_child(btns)

	# ---- board ----
	board = BoardView.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.number_font = f_num
	col.add_child(board)

	# ---- combo banner (above the board, below panels) ----
	var bc := CenterContainer.new()
	bc.set_anchors_preset(Control.PRESET_FULL_RECT)
	bc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bc)
	banner_box = VBoxContainer.new()
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_title = _label("", f_display, 64, BRASS_LIGHT)
	banner_sub = _label("", f_num, 30, CREAM)
	for l in [banner_title, banner_sub]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_constant_override("outline_size", 14)
		l.add_theme_color_override("font_outline_color", Color(0.02, 0.05, 0.06, 0.9))
		banner_box.add_child(l)
	banner_box.modulate.a = 0.0
	bc.add_child(banner_box)

	# ---- overlays ----
	dim = ColorRect.new()
	dim.color = Color(0.02, 0.05, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_build_menu()
	_build_pause()
	_build_over()
	_build_leaders()
	_build_settings()

	toast = _label("", f_bold, 20, INK)
	var tsb := _box(BRASS_LIGHT, BRASS_LIGHT, 0, 10, Vector4(18, 10, 18, 10))
	toast.add_theme_stylebox_override("normal", tsb)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 40)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast.modulate.a = 0.0
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)


func _panel() -> Array:
	var p := PanelContainer.new()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	center.add_child(p)
	return [p, v]


func _row(children: Array) -> HFlowContainer:
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 10)
	r.add_theme_constant_override("v_separation", 10)
	for c in children:
		r.add_child(c)
	return r


func _build_menu() -> void:
	var pv := _panel()
	menu_panel = pv[0]
	var v: VBoxContainer = pv[1]
	ui.menu_title = _label("", f_display, 44, BRASS)
	ui.menu_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.menu_tag = _para("")
	ui.menu_tag.add_theme_color_override("font_color", MUTED)
	v.add_child(ui.menu_title)
	v.add_child(ui.menu_tag)
	v.add_child(HSeparator.new())
	# the rules scroll inside the panel so the title and buttons always fit the screen
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.menu_scroll = scroll
	var rules := VBoxContainer.new()
	rules.add_theme_constant_override("separation", 12)
	rules.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rules)
	ui.menu_rules = rules
	v.add_child(scroll)
	ui.how = _caption("")
	rules.add_child(ui.how)
	for k in ["rule1", "rule2", "rule3", "rule4", "rule5"]:
		ui[k] = _para("")
		rules.add_child(ui[k])
	var pay := VBoxContainer.new()
	pay.add_theme_constant_override("separation", 4)
	for k in ["pay2", "pay3", "pay4", "pay_combo", "pay_precise", "pay_shine"]:
		ui[k] = _label("", f_num, 18, BRASS_LIGHT)
		ui[k].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pay.add_child(ui[k])
	rules.add_child(pay)
	ui.btn_play = _button("", "play", true, func(): start_game())
	ui.btn_leaders_menu = _button("", "trophy", false, func(): _open_leaders(menu_panel))
	ui.btn_settings_menu = _icon_button("settings", func(): _open_settings(menu_panel))
	ui.btn_daily = _button("", "calendar", false, func(): Sfx.play("click"); start_game(true))
	v.add_child(_row([ui.btn_play, ui.btn_daily, ui.btn_leaders_menu, ui.btn_settings_menu]))


func _build_pause() -> void:
	var pv := _panel()
	pause_panel = pv[0]
	var v: VBoxContainer = pv[1]
	ui.pause_title = _label("", f_display, 40, BRASS)
	v.add_child(ui.pause_title)
	ui.btn_resume = _button("", "play", true, func(): Sfx.play("click"); _resume_play())
	ui.btn_menu_pause = _button("", "home", false, func(): Sfx.play("click"); go_menu())
	ui.btn_settings_pause = _icon_button("settings", func(): _open_settings(pause_panel))
	v.add_child(_row([ui.btn_resume, ui.btn_menu_pause, ui.btn_settings_pause]))


func _build_over() -> void:
	var pv := _panel()
	over_panel = pv[0]
	var v: VBoxContainer = pv[1]
	ui.over_title = _label("", f_display, 40, BRASS)
	ui.over_score = _label("0", f_num, 72)
	ui.over_best = _label("", f_bold, 22, BRASS_LIGHT)
	ui.over_line = _para("")
	ui.over_line.add_theme_color_override("font_color", MUTED)
	v.add_child(ui.over_title)
	v.add_child(ui.over_score)
	v.add_child(ui.over_best)
	v.add_child(ui.over_line)
	ui.btn_continue = _button("", "video", false, _on_continue)
	ui.btn_shuffle = _button("", "shuffle", false, _on_shuffle)
	v.add_child(ui.btn_continue)
	v.add_child(ui.btn_shuffle)
	ui.btn_again = _button("", "restart", true, _on_again)
	ui.btn_leaders_over = _button("", "trophy", false, func(): _open_leaders(over_panel))
	ui.btn_menu_over = _button("", "home", false, func(): Sfx.play("click"); go_menu())
	v.add_child(_row([ui.btn_again, ui.btn_leaders_over, ui.btn_menu_over]))


func _build_leaders() -> void:
	var pv := _panel()
	leaders_panel = pv[0]
	var v: VBoxContainer = pv[1]
	ui.leaders_title = _label("", f_display, 36, BRASS)
	v.add_child(ui.leaders_title)
	ui.leaders_status = _para("")
	ui.leaders_status.add_theme_color_override("font_color", MUTED)
	v.add_child(ui.leaders_status)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 0
	ui.leaders_scroll = scroll
	ui.leaders_list = VBoxContainer.new()
	ui.leaders_list.add_theme_constant_override("separation", 6)
	ui.leaders_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(ui.leaders_list)
	v.add_child(scroll)
	ui.btn_login = _button("", "", false, _on_login)
	ui.btn_login.visible = false
	v.add_child(ui.btn_login)
	ui.btn_close_leaders = _button("", "", true, func(): Sfx.play("click"); _show_panel(leaders_return))
	v.add_child(_row([ui.btn_close_leaders]))


func _build_settings() -> void:
	var pv := _panel()
	settings_panel = pv[0]
	var v: VBoxContainer = pv[1]
	ui.settings_title = _label("", f_display, 36, BRASS)
	v.add_child(ui.settings_title)
	ui.chk_sound = _check(Save.sound, func(on: bool):
		Save.sound = on
		Save.store()
		Sfx.play("click"))
	ui.sld_sound = _slider(Save.sound_volume, func(x: float):
		Save.sound_volume = x, func(): Save.store(); Sfx.play("knock3"))
	v.add_child(_setting_row(ui.chk_sound, ui.sld_sound))
	ui.chk_music = _check(Save.music, func(on: bool):
		Save.music = on
		Save.store()
		Sfx.play("click")
		Sfx.update_music())
	ui.sld_music = _slider(Save.music_volume, func(x: float):
		Save.music_volume = x
		Sfx.apply_volumes()
		Sfx.update_music(), func(): Save.store())
	v.add_child(_setting_row(ui.chk_music, ui.sld_music))
	ui.chk_vibration = _check(Save.vibration, func(on: bool):
		Save.vibration = on
		Save.store()
		Haptics.buzz("test"))
	ui.chk_vibration.visible = Haptics.available() or OS.is_debug_build()
	v.add_child(ui.chk_vibration)
	ui.btn_settings_done = _button("", "", true, func(): Sfx.play("click"); _close_settings())
	v.add_child(_row([ui.btn_settings_done]))
	ui.scale_info = _label("", f_num, 12, MUTED)
	ui.scale_info.visible = OS.is_debug_build()
	v.add_child(ui.scale_info)


func _check(on: bool, cb: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = on
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.toggled.connect(cb)
	return c


func _slider(value: float, on_change: Callable, on_release: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(150, 36)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value_changed.connect(on_change)
	s.drag_ended.connect(func(_changed: bool): on_release.call())
	return s


func _setting_row(check: CheckButton, slider: HSlider) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 14)
	r.add_child(check)
	r.add_child(slider)
	return r


func _open_settings(from: Control) -> void:
	Sfx.play("click")
	settings_return = from
	ui.chk_sound.set_pressed_no_signal(Save.sound)
	ui.chk_music.set_pressed_no_signal(Save.music)
	ui.chk_vibration.set_pressed_no_signal(Save.vibration)
	ui.sld_sound.set_value_no_signal(Save.sound_volume)
	ui.sld_music.set_value_no_signal(Save.music_volume)
	var vs := get_viewport_rect().size
	ui.scale_info.text = "%s, view %dx%d" % [ui_scale_info, int(vs.x), int(vs.y)]
	_show_panel(settings_panel)


func _open_settings_from_hud() -> void:
	if state == State.PLAYING:
		pause_game()
	_open_settings(_current_panel())


func _close_settings() -> void:
	_show_panel(settings_return)


func _current_panel() -> Control:
	for p in [menu_panel, pause_panel, over_panel, leaders_panel]:
		if p.visible:
			return p
	return null


func _apply_texts() -> void:
	title_label.text = L.t("title")
	time_caption.text = L.t("time")
	score_caption.text = L.t("score")
	best_caption.text = L.t("best")
	ui.menu_title.text = L.t("title")
	ui.menu_tag.text = L.t("tagline")
	ui.how.text = L.t("how_title")
	for k in ["rule1", "rule2", "rule3", "rule4", "rule5", "pay2", "pay3", "pay4", "pay_combo", "pay_precise", "pay_shine"]:
		ui[k].text = L.t(k)
	ui.btn_play.text = L.t("play")
	ui.btn_leaders_menu.text = L.t("leaders")
	ui.btn_daily.text = L.t("daily")
	ui.pause_title.text = L.t("paused")
	ui.btn_resume.text = L.t("resume")
	ui.btn_menu_pause.text = L.t("menu")
	ui.over_best.text = L.t("new_best")
	ui.btn_continue.text = L.t("continue_ad")
	ui.btn_shuffle.text = L.t("shuffle_ad")
	ui.btn_again.text = L.t("again")
	ui.btn_leaders_over.text = L.t("leaders")
	ui.btn_menu_over.text = L.t("menu")
	ui.leaders_title.text = L.t("leaders")
	ui.btn_login.text = L.t("login")
	ui.btn_close_leaders.text = L.t("close")
	ui.settings_title.text = L.t("settings")
	ui.chk_sound.text = L.t("sounds")
	ui.chk_music.text = L.t("music_opt")
	ui.chk_vibration.text = L.t("vibration")
	ui.btn_settings_done.text = L.t("done")
	_fit_panels.call_deferred()


## Little scale bump for HUD numbers.
func _pop(c: Control, k := 1.25) -> void:
	c.pivot_offset = Vector2(0, c.size.y / 2)
	c.scale = Vector2.ONE * k
	create_tween().tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _show_panel(p: Control) -> void:
	var was_dim := dim.visible
	for x in [menu_panel, pause_panel, over_panel, leaders_panel, settings_panel]:
		x.visible = x == p
	dim.visible = p != null
	btn_pause.disabled = state != State.PLAYING
	if p:
		# fade and grow in; the dim layer only fades when it was hidden before
		if not was_dim:
			dim.modulate.a = 0.0
			create_tween().tween_property(dim, "modulate:a", 1.0, 0.2)
		p.modulate.a = 0.0
		p.scale = Vector2.ONE * 0.94
		p.pivot_offset = p.size / 2
		var tw := create_tween().set_parallel()
		tw.tween_property(p, "modulate:a", 1.0, 0.18)
		tw.tween_property(p, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var first := _first_button(p)
		if first:
			first.grab_focus.call_deferred()


func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button and c.visible:
			return c
		var b := _first_button(c)
		if b:
			return b
	return null


func _update_hud() -> void:
	var secs := int(ceil(time_left))
	time_label.text = str(secs)
	var low := state == State.PLAYING and secs <= 15
	time_label.add_theme_color_override("font_color", DANGER if low else CREAM)
	time_bar.add_theme_stylebox_override("fill", bar_fill_low if low else bar_fill)
	time_bar.value = clampf(time_left / START_TIME, 0.0, 1.0) * 100.0
	best_label.text = str(maxi(Save.best, score))
	btn_pause.disabled = state != State.PLAYING


func _flash_delta(text: String, negative: bool) -> void:
	time_delta.text = text + (" с" if L.lang == "ru" else (" sn" if L.lang == "tr" else " s"))
	time_delta.add_theme_color_override("font_color", DANGER if negative else BRASS)
	time_delta.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(time_delta, "modulate:a", 0.0, 0.4)


func _toast(text: String) -> void:
	toast.text = text
	var tw := create_tween()
	tw.tween_property(toast, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.2)
	tw.tween_property(toast, "modulate:a", 0.0, 0.3)


# ================= combo UI =================

func _update_combo_widget(pulse := false) -> void:
	var c := keeper.combo
	if c < 2:
		combo_box.modulate.a = 0.0
		return
	var m := ScoreKeeper.multiplier_for(c)
	combo_mult.text = "×%d" % m
	combo_mult.add_theme_color_override("font_color", board.TEXT_COLORS[clampi(m, 1, 4) - 1])
	combo_count.text = L.t("combo_count", {"n": c})
	combo_box.modulate.a = 1.0
	if pulse:
		var tw := create_tween()
		combo_mult.scale = Vector2.ONE * 1.6
		tw.tween_property(combo_mult, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _combo_break() -> void:
	Sfx.play("combo_break", 1.0, -6.0)
	var tw := create_tween()
	tw.tween_property(combo_box, "modulate:a", 0.0, 0.35)


func _banner(title: String, pts: int, secs: float, color: Color) -> void:
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", color)
	banner_sub.text = L.t("bonus_line", {"p": pts, "s": int(secs)})
	var vs := get_viewport_rect().size
	banner_title.add_theme_font_size_override("font_size", int(clampf(vs.x / 13.0, 34.0, 64.0)))
	banner_box.pivot_offset = banner_box.size / 2
	banner_box.scale = Vector2.ONE * 0.4
	banner_box.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(banner_box, "scale", Vector2.ONE * 1.08, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner_box, "scale", Vector2.ONE, 0.12)
	tw.tween_interval(0.9)
	tw.parallel().tween_property(banner_box, "position:y", banner_box.position.y - 30, 1.3)
	tw.tween_property(banner_box, "modulate:a", 0.0, 0.35)


# ================= layout =================

## Board shape for the current screen: wide screens get 23x15, tall ones 15x23.
## Board shape for the free space under the HUD: tall phones get tall boards, wide screens wide ones.
func _dims() -> Vector2i:
	var a := board.size - Vector2.ONE * board.frame_pad * 2.0
	if a.x < 50.0 or a.y < 50.0:
		a = get_viewport_rect().size - Vector2(32, 120)
	return BoardLogic.best_dims(a)


## Fit the board to its area. Before a game starts the board is re-dealt in the best shape;
## during a game it is only transposed (when that shape fits better) or rescaled.
func _relayout_board() -> void:
	var d := _dims()
	if Vector2i(logic.cols, logic.rows) != d:
		if state == State.MENU:
			logic.setup(d.x, d.y, rng)
			board.clear_fx()
		elif Vector2i(logic.rows, logic.cols) == d:
			logic.transpose()
			board.transposed()
	board.refresh()


func _on_viewport_resized() -> void:
	var s := get_viewport_rect().size
	compact = s.x < 640 or s.y < 600
	title_label.visible = s.x >= 980
	var m := 6 if compact else 16
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, m)
	hud.add_theme_constant_override("separation", 10 if compact else 22)
	combo_box.custom_minimum_size.x = 64 if compact else 96
	var w := clampf(s.x - (16 if compact else 40), 280, 620)
	for p in [menu_panel, pause_panel, over_panel, leaders_panel, settings_panel]:
		p.custom_minimum_size.x = w
		p.add_theme_stylebox_override("panel", panel_style_compact if compact else panel_style)
	ui.menu_title.add_theme_font_size_override("font_size", 34 if compact else 44)
	ui.over_score.add_theme_font_size_override("font_size", 52 if compact else 72)
	board.frame_pad = 5.0 if compact else 10.0
	_relayout_board.call_deferred()
	_fit_panels.call_deferred()


## Shrink the scrolling middle of tall panels so the whole panel fits the screen.
func _fit_panels() -> void:
	var avail := get_viewport_rect().size.y - (12.0 if compact else 32.0)
	for pair in [[menu_panel, ui.menu_scroll, ui.menu_rules], [leaders_panel, ui.leaders_scroll, ui.leaders_list]]:
		var panel: Control = pair[0]
		var scroll: ScrollContainer = pair[1]
		var content: Control = pair[2]
		scroll.custom_minimum_size.y = 0
		var fixed := panel.get_combined_minimum_size().y
		var want := content.get_combined_minimum_size().y
		scroll.custom_minimum_size.y = clampf(avail - fixed, 80.0, maxf(80.0, want))


## Pick the logical resolution from the kind of device, not from DPI (DPI reports are
## unreliable on some phones and browsers). The short side of the screen always maps to the
## same number of logical pixels, so the UI takes the same share of the screen everywhere:
## phones 480, tablets 600, desktops 720 (and the UI grows with a bigger window).
func _apply_ui_scale() -> void:
	var win := get_window()
	var px := Vector2(win.size)
	if px.x <= 0.0 or px.y <= 0.0:
		return
	var base := 720
	if _is_touch_device():
		var aspect := maxf(px.x, px.y) / minf(px.x, px.y)
		base = 480 if aspect >= 1.6 else 600
	ui_scale_info = "%dx%d px, base %d, touch %s" % [int(px.x), int(px.y), base, _is_touch_device()]
	if win.content_scale_size != Vector2i(base, base):
		win.content_scale_size = Vector2i(base, base)


func _is_touch_device() -> bool:
	return OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
