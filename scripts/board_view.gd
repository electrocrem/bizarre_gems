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
## tile colour per gem kind, matches the tile art (used for shards)
const GEM_GLOW: Array[Color] = [Color("#ff4d5e"), Color("#3d8bff"), Color("#22c97a"), Color("#a35cff"), Color("#ff9a2e"),
	Color("#ffcf33"), Color("#dfe5f0"), Color("#ff6fb5"), Color("#2fd6e0"), Color("#9be03a")]
## Rotates the hue of everything on the board; tweened when the palette changes on a big combo.
const HUE_SHADER := """
shader_type canvas_item;
uniform float hue = 0.0;
void fragment() {
	float a = hue * 6.2831853;
	vec3 c = COLOR.rgb;
	vec3 yiq = mat3(vec3(0.299, 0.596, 0.211), vec3(0.587, -0.274, -0.523), vec3(0.114, -0.322, 0.312)) * c;
	yiq.yz = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * yiq.yz;
	COLOR.rgb = mat3(vec3(1.0, 1.0, 1.0), vec3(0.956, -0.272, -1.106), vec3(0.621, -0.647, 1.703)) * yiq;
}
"""
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
var _fx: Control  ## effects layer, redrawn every frame; the board itself redraws only on change
var _shake_off := Vector2.ZERO
var _shards: Array[Dictionary] = []
var _pops: Array[Dictionary] = []
var _praise: Array[Dictionary] = []
var _hue_mat := ShaderMaterial.new()
var hue := 0.0:
	set(v):
		hue = v
		_hue_mat.set_shader_parameter("hue", v)


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_frame.bg_color = Color(0.04, 0.07, 0.2, 0.55)
	_frame.border_color = Color(1, 1, 1, 0.14)
	_frame.set_border_width_all(3)
	_frame.set_corner_radius_all(20)
	_frame.shadow_color = Color(0, 0, 0, 0.45)
	_frame.shadow_size = 18
	resized.connect(_relayout)
	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fx)
	_fx.draw.connect(_draw_fx)
	var sh := Shader.new()
	sh.code = HUE_SHADER
	_hue_mat.shader = sh
	material = _hue_mat
	_fx.use_parent_material = true


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
	queue_redraw()
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
	_shards.clear(); _pops.clear(); _praise.clear()
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
		_pops.append({"p": h, "t": 0.0})
		var base: Color = GEM_GLOW[kinds[i]]
		for j in 7:
			var a := randf() * TAU
			_shards.append({"p": h, "v": Vector2.from_angle(a) * cell * randf_range(2.5, 6.0) + Vector2(0, -cell * 3.0),
				"r": randf() * TAU, "vr": randf_range(-9, 9), "s": cell * randf_range(0.12, 0.22),
				"c": base.lightened(randf_range(0.0, 0.35)), "t": 0.0, "life": randf_range(0.5, 0.8)})
		for j in 4 + mult * 3:
			var a := randf() * TAU
			_sparks.append({"p": h, "v": Vector2.from_angle(a) * cell * randf_range(2, 5 + mult), "t": 0.0,
				"life": randf_range(0.35, 0.6), "s": randf_range(0.25, 0.5), "c": _spark_color(rainbow)})
	var col: Color = TEXT_COLORS[clampi(mult, 1, 4) - 1]
	_texts.append({"p": c, "s": "+%d" % points, "t": 0.0, "c": col, "k": 1.0 + (mult - 1) * 0.18})
	_hint = Vector2i(-1, -1)
	queue_redraw()  # gems were removed


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


## Big word of praise floating up from a slot ("Great!").
func praise(text: String, at: Vector2i, color: Color, big := 1.0) -> void:
	_praise.append({"p": slot_center(at), "s": text, "c": color, "k": big, "t": 0.0})


## Small ring where the player pressed.
func ripple(at: Vector2i) -> void:
	_ripples.append({"p": slot_center(at), "t": 0.0})


func play_miss(at: Vector2i) -> void:
	_misses.append({"p": slot_center(at), "t": 0.0})
	_shake = 0.18


func show_hint(p: Vector2i) -> void:
	_hint = p
	_hint_t = 0.0


## The board changed outside the view (shuffle, new game): rebuild the static layer.
func mark_dirty() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _deal_t < 1.0:
		_deal_t += delta
		queue_redraw()
	_glint_timer -= delta
	if _glint_timer <= 0.0 and logic:
		_glint_timer = randf_range(0.12, 0.3)
		var i := randi() % logic.cells.size()
		if logic.cells[i] >= 0:
			_glints.append({"i": i, "t": 0.0})
	_age(_glints, delta, 0.6)
	_age(_ripples, delta, 0.35)
	_age(_beams, delta, 0.3)
	_age(_texts, delta, 0.9)
	_age(_misses, delta, 0.45)
	_age(_waves, delta, 0.6)
	_age(_pops, delta, 0.22)
	_age(_praise, delta, 1.1)
	if not _shards.is_empty():
		var g2 := cell * 22.0
		for sd in _shards:
			sd.t += delta
			sd.v.y += g2 * delta
			sd.p += sd.v * delta
			sd.r += sd.vr * delta
		_shards = _shards.filter(func(sd): return sd.t < sd.life)
	if not _flyers.is_empty():
		var g := cell * 26.0
		for f in _flyers:
			f.v.y += g * delta
			f.p += f.v * delta
			f.r += f.vr * delta
		_flyers = _flyers.filter(func(f): return f.p.y < size.y + cell * 2)
	if not _sparks.is_empty():
		for sp in _sparks:
			sp.t += delta
			sp.p += sp.v * delta
			sp.v *= 0.9
		_sparks = _sparks.filter(func(sp): return sp.t < sp.life)
	_flash = maxf(0.0, _flash - delta * 1.4)
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		_shake_off = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * cell * 0.08 if _shake > 0.0 else Vector2.ZERO
		queue_redraw()
	_hint_t += delta
	_fx.queue_redraw()


func _age(list: Array[Dictionary], delta: float, life: float) -> void:
	if list.is_empty():
		return
	for e in list:
		e.t += delta
	var keep := list.filter(func(e): return e.t < life)
	list.assign(keep)


# ---------------- drawing ----------------

## Static layer: frame, slots, halos and gems. Rebuilt only when something changes.
func _draw() -> void:
	if logic == null:
		return
	var off := _shake_off
	draw_set_transform(off)
	var grid_size := Vector2(logic.cols, logic.rows) * cell
	draw_style_box(_frame, Rect2(origin - Vector2.ONE * frame_pad, grid_size + Vector2.ONE * frame_pad * 2))

	var focus := _cursor if _keyboard else _hover
	if interactive and focus.x >= 0 and logic.is_empty(focus):
		var lane := Color(0.82, 0.67, 0.33, 0.08)
		draw_rect(Rect2(origin.x, origin.y + focus.y * cell, grid_size.x, cell), lane)
		draw_rect(Rect2(origin.x + focus.x * cell, origin.y, cell, grid_size.y), lane)

	var gem := cell * 0.96
	for y in logic.rows:
		for x in logic.cols:
			var ctr := origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell
			draw_texture_rect(SLOT_TEX, Rect2(ctr - Vector2.ONE * cell * 0.48, Vector2.ONE * cell * 0.96), false)
	for y in logic.rows:
		for x in logic.cols:
			var i := y * logic.cols + x
			var k := logic.cells[i]
			if k < 0:
				continue
			var gs := gem * _deal_scale(i)
			if gs <= 0.5:
				continue
			var ctr := origin + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell
			draw_texture_rect(GEM_TEX[k], Rect2(ctr - Vector2.ONE * gs / 2, Vector2.ONE * gs), false)

	if interactive and focus.x >= 0:
		var col := Color(0.82, 0.67, 0.33, 1.0 if _keyboard else 0.6)
		draw_rect(Rect2(origin + Vector2(focus) * cell + Vector2.ONE * 2, Vector2.ONE * (cell - 4)), col, false, 2.0)


## Effects layer, drawn on top every frame: shining gems, glints, beams, sparks, texts.
func _draw_fx() -> void:
	if logic == null:
		return
	var c := _fx
	var off := _shake_off
	c.draw_set_transform(off)
	var gem := cell * 0.96
	# shining gems: no marker, just a sparkle that flares up every second or so
	for i in logic.shine.size():
		if logic.shine[i] == 0 or logic.cells[i] < 0:
			continue
		var flare := sin(_time * 2.6 + i * 1.7)
		if flare < 0.35:
			continue
		var f := (flare - 0.35) / 0.65
		var ctr := origin + (Vector2(i % logic.cols, i / logic.cols) + Vector2(0.62, 0.32)) * cell
		var ss := cell * 0.7 * f
		c.draw_set_transform(ctr + off, _time * 2.0 + i)
		c.draw_texture_rect(SPARKLE_TEX, Rect2(-Vector2.ONE * ss / 2, Vector2.ONE * ss), false, Color(1, 0.97, 0.85, f))
		c.draw_set_transform(off)
	for gl in _glints:
		var gi: int = gl.i
		if gi >= logic.cells.size() or logic.cells[gi] < 0:
			continue
		var gp := origin + (Vector2(gi % logic.cols, gi / logic.cols) + Vector2(0.3, 0.3)) * cell
		var ga: float = sin(gl.t / 0.6 * PI)
		var gsz := cell * 0.45 * ga
		c.draw_texture_rect(SPARKLE_TEX, Rect2(gp - Vector2.ONE * gsz / 2, Vector2.ONE * gsz), false, Color(1, 1, 1, ga * 0.9))
	for rp in _ripples:
		var q: float = rp.t / 0.35
		c.draw_arc(rp.p, cell * (0.3 + q * 0.6), 0, TAU, 16, Color(BEAM, (1.0 - q) * 0.7), 2.0)
	if _hint.x >= 0:
		var a := 0.45 + 0.35 * sin(_hint_t * 8.0)
		c.draw_circle(slot_center(_hint), cell * 0.32, Color(BEAM, a * 0.35))
		c.draw_arc(slot_center(_hint), cell * 0.36, 0, TAU, 20, Color(BEAM, a), 2.0)
	for b in _beams:
		var a: float = 1.0 - b.t / 0.3
		var bc := Color.from_hsv(fmod(b.t * 3.0 + b.a.x * 0.002, 1.0), 0.5, 1.0) if b.rainbow else BEAM
		c.draw_line(b.a, b.b, Color(bc, a * 0.35), (4.0 + 6.0 * a) * b.w)
		c.draw_line(b.a, b.b, Color(bc, a), (1.0 + 3.0 * a) * b.w)
	for w in _waves:
		if w.t < 0.0:
			continue
		var q: float = w.t / 0.6
		var rad: float = cell * (0.5 + q * 4.5 * w.k)
		var wc := Color.from_hsv(fmod(q * 2.0, 1.0), 0.45, 1.0) if w.rainbow else BEAM
		c.draw_arc(w.p, rad, 0, TAU, 40, Color(wc, (1.0 - q) * 0.8), (2.0 + 4.0 * (1.0 - q)) * w.k)
	for sp in _sparks:
		var a: float = 1.0 - sp.t / sp.life
		var sz: float = cell * sp.s * (0.6 + a * 0.6)
		var sc: Color = sp.get("c", Color(1, 0.95, 0.8))
		c.draw_texture_rect(SPARKLE_TEX, Rect2(sp.p - Vector2.ONE * sz / 2, Vector2.ONE * sz), false, Color(sc, a))
	for pp in _pops:
		var q: float = pp.t / 0.22
		c.draw_circle(pp.p, cell * (0.3 + q * 0.35), Color(1, 1, 1, (1.0 - q) * 0.75))
	for sd in _shards:
		var a: float = 1.0 - sd.t / sd.life
		var r: float = sd.r
		var k: float = sd.s
		var tri := PackedVector2Array([Vector2(cos(r), sin(r)) * k, Vector2(cos(r + 2.3), sin(r + 2.3)) * k * 0.8, Vector2(cos(r + 4.1), sin(r + 4.1)) * k * 0.9])
		c.draw_set_transform(sd.p + off)
		c.draw_colored_polygon(tri, Color(sd.c, a))
	c.draw_set_transform(off)
	for m in _misses:
		var a: float = 1.0 - m.t / 0.45
		var q := cell * 0.22
		c.draw_line(m.p - Vector2(q, q), m.p + Vector2(q, q), Color(MISS, a), 3.0)
		c.draw_line(m.p + Vector2(q, -q), m.p + Vector2(-q, q), Color(MISS, a), 3.0)
	if number_font:
		for t in _texts:
			var a: float = 1.0 - t.t / 0.9
			var pop: float = 1.0 + 0.35 * maxf(0.0, 1.0 - t.t / 0.15)
			var fs := int(maxf(16.0, cell * 0.75) * t.k * pop)
			var p: Vector2 = t.p - Vector2(cell * 2.0, t.t * cell * 1.6 - fs * 0.35)
			c.draw_string(number_font, p + Vector2(1, 2), t.s, HORIZONTAL_ALIGNMENT_CENTER, cell * 4, fs, Color(0, 0, 0, a * 0.6))
			c.draw_string(number_font, p, t.s, HORIZONTAL_ALIGNMENT_CENTER, cell * 4, fs, Color(t.c, a))
	if number_font:
		for pr in _praise:
			var q: float = pr.t / 1.1
			var a: float = clampf((1.0 - q) * 2.5, 0.0, 1.0)
			var pop: float = 1.0 + 0.5 * maxf(0.0, 1.0 - pr.t / 0.12)
			var fs := int(maxf(26.0, cell * 0.9) * pr.k * pop)
			var w := maxf(size.x, cell * 8)
			var pos: Vector2 = Vector2(clampf(pr.p.x - w / 2, -w / 2 + size.x / 2, size.x / 2 - w / 2), pr.p.y - cell * 0.8 - q * cell * 1.8)
			c.draw_string_outline(number_font, pos, pr.s, HORIZONTAL_ALIGNMENT_CENTER, w, fs, int(fs * 0.22), Color(0.05, 0.05, 0.15, a))
			c.draw_string(number_font, pos, pr.s, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(pr.c, a))
	if _flash > 0.0:
		c.draw_set_transform(Vector2.ZERO)
		var grid_size := Vector2(logic.cols, logic.rows) * cell
		c.draw_rect(Rect2(origin - Vector2.ONE * frame_pad, grid_size + Vector2.ONE * frame_pad * 2), Color(_flash_color, _flash))


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
