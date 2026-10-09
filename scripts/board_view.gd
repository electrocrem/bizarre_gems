class_name BoardView
extends Control
## Draws the board and its effects, turns pointer and keyboard input into slot presses.

signal slot_pressed(p: Vector2i)

const GEM_TEX: Array[Texture2D] = [
	preload("res://assets/gems/gem_0.png"), preload("res://assets/gems/gem_1.png"),
	preload("res://assets/gems/gem_2.png"), preload("res://assets/gems/gem_3.png"),
	preload("res://assets/gems/gem_4.png"), preload("res://assets/gems/gem_5.png"),
	preload("res://assets/gems/gem_6.png"), preload("res://assets/gems/gem_7.png"),
	preload("res://assets/gems/gem_8.png"), preload("res://assets/gems/gem_9.png"),
]
const SLOT_TEX := preload("res://assets/ui/slot.png")
const SPARKLE_TEX := preload("res://assets/fx/sparkle.png")
const GLOW_TEX := preload("res://assets/fx/glow.png")
## halo colour per gem kind, matches the gem art
const GEM_GLOW: Array[Color] = [Color("#e2334c"), Color("#2f6ff0"), Color("#17a866"), Color("#9a4fe6"), Color("#f28a22"),
	Color("#f4c62e"), Color("#ece8f2"), Color("#f25fae"), Color("#3fd6dc"), Color("#a6dc3a")]
const GOLD := Color(1.0, 0.84, 0.4)
const BEAM := Color(0.97, 0.89, 0.66)
const MISS := Color(1.0, 0.36, 0.31)
const TEXT_COLORS: Array[Color] = [Color(0.97, 0.89, 0.66), Color(1.0, 0.78, 0.35), Color(1.0, 0.55, 0.3), Color(1.0, 0.42, 0.7)]
var frame_pad := 10.0

var logic: BoardLogic
var interactive := false
var number_font: Font
var cell := 30.0
var origin := Vector2.ZERO

var _hover := Vector2i(-1, -1)
var _cursor := Vector2i(-1, -1)
var _keyboard := false
var _flyers: Array[Dictionary] = []
var _beams: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _misses: Array[Dictionary] = []
var _sparks: Array[Dictionary] = []
var _waves: Array[Dictionary] = []
var _flash := 0.0
var _flash_color := Color.WHITE
var _shake := 0.0
var _hint := Vector2i(-1, -1)
var _hint_t := 0.0
var _frame := StyleBoxFlat.new()
var _time := 0.0
var _deal_t := 99.0  ## seconds since the board was dealt; drives the deal-in animation
var _deal_delay := PackedFloat32Array()
var _glints: Array[Dictionary] = []
var _glint_timer := 0.0
var _ripples: Array[Dictionary] = []


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.bg_color = Color(0.05, 0.13, 0.14, 0.55)
	_frame.border_color = Color(0.82, 0.67, 0.33, 0.55)
	_frame.set_border_width_all(2)
	_frame.set_corner_radius_all(14)
	_frame.shadow_color = Color(0, 0, 0, 0.45)
	_frame.shadow_size = 18
	resized.connect(_relayout)


func _relayout() -> void:
	if logic == null:
		return
	var avail := size - Vector2.ONE * frame_pad * 2
	cell = maxf(8.0, floorf(minf(avail.x / logic.cols, avail.y / logic.rows)))
	origin = ((size - Vector2(logic.cols, logic.rows) * cell) / 2).floor()
	queue_redraw()


func refresh() -> void:
	_relayout()


## Animate gems dropping in, in a wave from the board centre.
func deal_in() -> void:
	_deal_t = 0.0
	_deal_delay.resize(logic.cols * logic.rows)
	var c := Vector2(logic.cols - 1, logic.rows - 1) / 2.0
	var far := c.length()
	for y in logic.rows:
		for x in logic.cols:
			_deal_delay[y * logic.cols + x] = Vector2(x, y).distance_to(c) / far * 0.45 + randf() * 0.12


func _deal_scale(i: int) -> float:
	if _deal_t >= 1.0 or i >= _deal_delay.size():
		return 1.0
	var t := clampf((_deal_t - _deal_delay[i]) / 0.3, 0.0, 1.0)
	if t <= 0.0:
		return 0.0
	# ease-out-back: a small overshoot before settling
	var u := t - 1.0
	return 1.0 + 2.70158 * u * u * u + 1.70158 * u * u


func clear_fx() -> void:
	_flyers.clear(); _beams.clear(); _texts.clear(); _misses.clear(); _sparks.clear(); _waves.clear()
	_flash = 0.0
	_hint = Vector2i(-1, -1)


func slot_center(p: Vector2i) -> Vector2:
	return origin + (Vector2(p) + Vector2(0.5, 0.5)) * cell


func slot_at(pos: Vector2) -> Vector2i:
	var q := ((pos - origin) / cell).floor()
	var p := Vector2i(int(q.x), int(q.y))
	return p if logic and logic.in_bounds(p) else Vector2i(-1, -1)


# ---------------- effects ----------------

## mult is the combo multiplier (1..4): more sparks and a hotter colour for the score text.
func play_knock(from: Vector2i, gone: Array[Vector2i], kinds: Array[int], points: int, mult := 1, rainbow := false) -> void:
	var c := slot_center(from)
	for i in gone.size():
		var h := slot_center(gone[i])
		_beams.append({"a": c, "b": h, "t": 0.0, "rainbow": rainbow, "w": 1.0 + (mult - 1) * 0.5})
		var away := signf(h.x - c.x)
		if away == 0.0:
			away = randf_range(-1, 1)
		_flyers.append({"k": kinds[i], "p": h, "v": Vector2(away * cell * randf_range(2, 4), -cell * randf_range(6, 9)),
			"r": 0.0, "vr": randf_range(-7, 7)})
		for j in 4 + mult * 3:
			var a := randf() * TAU
			_sparks.append({"p": h, "v": Vector2.from_angle(a) * cell * randf_range(2, 5 + mult), "t": 0.0,
				"life": randf_range(0.35, 0.6), "s": randf_range(0.25, 0.5), "c": _spark_color(rainbow)})
	var col: Color = TEXT_COLORS[clampi(mult, 1, 4) - 1]
	_texts.append({"p": c, "s": "+%d" % points, "t": 0.0, "c": col, "k": 1.0 + (mult - 1) * 0.18})
	_hint = Vector2i(-1, -1)


## Expanding ring from a slot; strength 1 for a combo step, 2-3 for precise/perfect.
func play_wave(at: Vector2i, strength := 1.0, rainbow := false) -> void:
	_waves.append({"p": slot_center(at), "t": 0.0, "k": strength, "rainbow": rainbow})
	if strength >= 2.0:
		_waves.append({"p": slot_center(at), "t": -0.12, "k": strength * 0.7, "rainbow": rainbow})


## Firework of sparks over the whole board.
func play_burst(at: Vector2i, count: int, rainbow := true) -> void:
	var c := slot_center(at)
	for i in count:
		var a := randf() * TAU
		_sparks.append({"p": c, "v": Vector2.from_angle(a) * cell * randf_range(4, 16), "t": 0.0,
			"life": randf_range(0.6, 1.2), "s": randf_range(0.35, 0.9), "c": _spark_color(rainbow)})


func flash(color: Color, strength := 0.35) -> void:
	_flash_color = color
	_flash = strength


func shake(amount := 0.18) -> void:
	_shake = maxf(_shake, amount)


func _spark_color(rainbow: bool) -> Color:
	return Color.from_hsv(randf(), 0.55, 1.0) if rainbow else Color(1, 0.95, 0.8)


## Small ring where the player pressed.
func ripple(at: Vector2i) -> void:
	_ripples.append({"p": slot_center(at), "t": 0.0})


func play_miss(at: Vector2i) -> void:
	_misses.append({"p": slot_center(at), "t": 0.0})
	_shake = 0.18


func show_hint(p: Vector2i) -> void:
	_hint = p
	_hint_t = 0.0


func _process(delta: float) -> void:
	_time += delta
	_deal_t += delta
	_glint_timer -= delta
	if _glint_timer <= 0.0 and logic:
		_glint_timer = randf_range(0.12, 0.3)
		var i := randi() % logic.cells.size()
		if logic.cells[i] >= 0:
			_glints.append({"i": i, "t": 0.0})
	for gl in _glints: gl.t += delta
	_glints = _glints.filter(func(gl): return gl.t < 0.6)
	for rp in _ripples: rp.t += delta
	_ripples = _ripples.filter(func(rp): return rp.t < 0.35)
	var g := cell * 26.0
	for f in _flyers:
		f.v.y += g * delta
		f.p += f.v * delta
		f.r += f.vr * delta
	_flyers = _flyers.filter(func(f): return f.p.y < size.y + cell * 2)
	for s in _sparks:
		s.t += delta
		s.p += s.v * delta
		s.v *= 0.9
	_sparks = _sparks.filter(func(s): return s.t < s.life)
	for b in _beams: b.t += delta
	for t in _texts: t.t += delta
	for m in _misses: m.t += delta
	_beams = _beams.filter(func(b): return b.t < 0.3)
	_texts = _texts.filter(func(t): return t.t < 0.9)
	_misses = _misses.filter(func(m): return m.t < 0.45)
	for w in _waves: w.t += delta
	_waves = _waves.filter(func(w): return w.t < 0.6)
	_flash = maxf(0.0, _flash - delta * 1.4)
	_shake = maxf(0.0, _shake - delta)
	_hint_t += delta
	queue_redraw()


# ---------------- drawing ----------------

func _draw() -> void:
	if logic == null:
		return
	var off := Vector2.ZERO
	if _shake > 0:
		off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * cell * 0.08
	draw_set_transform(off)
	var grid_size := Vector2(logic.cols, logic.rows) * cell
	draw_style_box(_frame, Rect2(origin - Vector2.ONE * frame_pad, grid_size + Vector2.ONE * frame_pad * 2))

	var focus := _cursor if _keyboard else _hover
	if interactive and focus.x >= 0 and logic.is_empty(focus):
		var lane := Color(0.82, 0.67, 0.33, 0.08)
		draw_rect(Rect2(origin.x, origin.y + focus.y * cell, grid_size.x, cell), lane)
		draw_rect(Rect2(origin.x + focus.x * cell, origin.y, cell, grid_size.y), lane)

	var gem := cell * 0.97
	var ring := Color(0.82, 0.67, 0.33, 0.16)
	# pass 1: empty slots and coloured halos under the gems
	for y in logic.rows:
		for x in logic.cols:
			var i := y * logic.cols + x
			var ctr := origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell
			var k := logic.cells[i]
			if k < 0:
				draw_texture_rect(SLOT_TEX, Rect2(ctr - Vector2.ONE * cell * 0.42, Vector2.ONE * cell * 0.84), false)
				draw_arc(ctr, cell * 0.3, 0, TAU, 16, ring, maxf(1.0, cell * 0.035), true)
			else:
				var shining := logic.shine[i] == 1
				var hs := cell * (1.9 if shining else 1.3) * _deal_scale(i)
				var hc := GOLD if shining else GEM_GLOW[k]
				var ha := 0.6 + 0.25 * sin(_time * 4.0 + i) if shining else 0.3
				draw_texture_rect(GLOW_TEX, Rect2(ctr - Vector2.ONE * hs / 2, Vector2.ONE * hs), false, Color(hc, ha))
	# pass 2: the gems
	for y in logic.rows:
		for x in logic.cols:
			var i := y * logic.cols + x
			var k := logic.cells[i]
			if k < 0:
				continue
			var ctr := origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell
			var gs := gem * _deal_scale(i)
			if gs <= 0.5:
				continue
			draw_texture_rect(GEM_TEX[k], Rect2(ctr - Vector2.ONE * gs / 2, Vector2.ONE * gs), false)
			if logic.shine[i] == 1:
				# rotating golden ring of dashes around a shining gem
				for seg in 6:
					var a0 := _time * 2.0 + seg * TAU / 6.0
					draw_arc(ctr, cell * 0.56, a0, a0 + 0.6, 6, Color(GOLD, 0.9), maxf(1.5, cell * 0.06), true)
				var ss := cell * (0.55 + 0.12 * sin(_time * 5.0 + i))
				draw_set_transform(ctr + off, _time * 1.5 + i)
				draw_texture_rect(SPARKLE_TEX, Rect2(-Vector2.ONE * ss / 2, Vector2.ONE * ss), false, Color(GOLD, 0.95))
				draw_set_transform(off)
	# pass 3: passing glints
	for gl in _glints:
		var gi: int = gl.i
		if gi >= logic.cells.size() or logic.cells[gi] < 0:
			continue
		var gp := origin + (Vector2(gi % logic.cols, gi / logic.cols) + Vector2(0.3, 0.3)) * cell
		var ga: float = sin(gl.t / 0.6 * PI)
		var gsz := cell * 0.45 * ga
		draw_texture_rect(SPARKLE_TEX, Rect2(gp - Vector2.ONE * gsz / 2, Vector2.ONE * gsz), false, Color(1, 1, 1, ga * 0.9))
	for rp in _ripples:
		var q: float = rp.t / 0.35
		draw_arc(rp.p, cell * (0.3 + q * 0.6), 0, TAU, 24, Color(BEAM, (1.0 - q) * 0.7), 2.0, true)

	if _hint.x >= 0:
		var a := 0.45 + 0.35 * sin(_hint_t * 8.0)
		draw_circle(slot_center(_hint), cell * 0.32, Color(BEAM, a * 0.35))
		draw_arc(slot_center(_hint), cell * 0.36, 0, TAU, 24, Color(BEAM, a), 2.0)

	if interactive and focus.x >= 0:
		var col := Color(0.82, 0.67, 0.33, 1.0 if _keyboard else 0.6)
		draw_rect(Rect2(origin + Vector2(focus) * cell + Vector2.ONE * 2, Vector2.ONE * (cell - 4)), col, false, 2.0)

	for b in _beams:
		var a: float = 1.0 - b.t / 0.3
		var bc := Color.from_hsv(fmod(b.t * 3.0 + b.a.x * 0.002, 1.0), 0.5, 1.0) if b.rainbow else BEAM
		draw_line(b.a, b.b, Color(bc, a * 0.35), (4.0 + 6.0 * a) * b.w, true)
		draw_line(b.a, b.b, Color(bc, a), (1.0 + 3.0 * a) * b.w, true)
	for w in _waves:
		if w.t < 0.0:
			continue
		var q: float = w.t / 0.6
		var rad: float = cell * (0.5 + q * 4.5 * w.k)
		var wc := Color.from_hsv(fmod(q * 2.0, 1.0), 0.45, 1.0) if w.rainbow else BEAM
		draw_arc(w.p, rad, 0, TAU, 48, Color(wc, (1.0 - q) * 0.8), (2.0 + 4.0 * (1.0 - q)) * w.k, true)
	for s in _sparks:
		var a: float = 1.0 - s.t / s.life
		var sz: float = cell * s.s * (0.6 + a * 0.6)
		var sc: Color = s.get("c", Color(1, 0.95, 0.8))
		draw_texture_rect(SPARKLE_TEX, Rect2(s.p - Vector2.ONE * sz / 2, Vector2.ONE * sz), false, Color(sc, a))
	for f in _flyers:
		draw_set_transform(f.p + off, f.r)
		draw_texture_rect(GEM_TEX[f.k], Rect2(-Vector2.ONE * gem / 2, Vector2.ONE * gem), false)
	draw_set_transform(off)
	for m in _misses:
		var a: float = 1.0 - m.t / 0.45
		var q := cell * 0.22
		draw_line(m.p - Vector2(q, q), m.p + Vector2(q, q), Color(MISS, a), 3.0, true)
		draw_line(m.p + Vector2(q, -q), m.p + Vector2(-q, q), Color(MISS, a), 3.0, true)
	if number_font:
		for t in _texts:
			var a: float = 1.0 - t.t / 0.9
			var pop: float = 1.0 + 0.35 * maxf(0.0, 1.0 - t.t / 0.15)
			var fs := int(maxf(16.0, cell * 0.75) * t.k * pop)
			var p: Vector2 = t.p - Vector2(cell * 2.0, t.t * cell * 1.6 - fs * 0.35)
			draw_string(number_font, p + Vector2(1, 2), t.s, HORIZONTAL_ALIGNMENT_CENTER, cell * 4, fs, Color(0, 0, 0, a * 0.6))
			draw_string(number_font, p, t.s, HORIZONTAL_ALIGNMENT_CENTER, cell * 4, fs, Color(t.c, a))
	if _flash > 0.0:
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(origin - Vector2.ONE * frame_pad, grid_size + Vector2.ONE * frame_pad * 2), Color(_flash_color, _flash))


# ---------------- input ----------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_keyboard = false
		var p := slot_at(event.position)
		if p != _hover:
			_hover = p
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_keyboard = false
		var p := slot_at(event.position)
		if p.x >= 0:
			grab_focus()
			slot_pressed.emit(p)
		accept_event()
	elif event is InputEventKey and event.pressed:
		var dirs := {KEY_LEFT: Vector2i(-1, 0), KEY_RIGHT: Vector2i(1, 0), KEY_UP: Vector2i(0, -1), KEY_DOWN: Vector2i(0, 1),
			KEY_A: Vector2i(-1, 0), KEY_D: Vector2i(1, 0), KEY_W: Vector2i(0, -1), KEY_S: Vector2i(0, 1)}
		if dirs.has(event.keycode):
			_keyboard = true
			if _cursor.x < 0:
				_cursor = Vector2i(logic.cols / 2, logic.rows / 2)
			else:
				var d: Vector2i = dirs[event.keycode]
				_cursor = Vector2i(posmod(_cursor.x + d.x, logic.cols), posmod(_cursor.y + d.y, logic.rows))
			queue_redraw()
			accept_event()
		elif event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] and _cursor.x >= 0:
			slot_pressed.emit(_cursor)
			accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hover = Vector2i(-1, -1)
		queue_redraw()


## Keep the keyboard cursor on the same slot after a transpose.
func transposed() -> void:
	if _cursor.x >= 0:
		_cursor = Vector2i(_cursor.y, _cursor.x)
	_hover = Vector2i(-1, -1)
	clear_fx()
