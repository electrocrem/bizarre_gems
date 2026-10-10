class_name StrikeReplay
extends Control
## The result screen's "best strike": the struck slot in the middle and the gems it took on
## the cross around it, replayed in a loop (beams, the gems pop, the points rise, all back).

const LOOP := 2.8
const BEAM := Color(1.0, 0.9, 0.6)

var data := {}
var tex: Callable  ## kind -> Texture2D, the board's own tiles
var font: Font
var _t := 0.0


func show_strike(d: Dictionary, tex_fn: Callable, f: Font) -> void:
	data = d
	tex = tex_fn
	font = f
	_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if is_visible_in_tree() and not data.is_empty():
		_t = fmod(_t + delta, LOOP)
		queue_redraw()


func _draw() -> void:
	if data.is_empty() or size.x < 20.0 or size.y < 20.0:
		return
	var c := size / 2
	var cell := minf(size.x, size.y) / 5.2
	var strike := _t > 0.7 and _t < 1.25
	draw_rect(Rect2(c - Vector2.ONE * cell * 0.45, Vector2.ONE * cell * 0.9), Color(1, 1, 1, 0.5 if strike else 0.14))
	if strike:
		var k := (_t - 0.7) / 0.55
		draw_arc(c, cell * (0.4 + k * 1.6), 0, TAU, 32, Color(BEAM, 1.0 - k), 3.0)
	for part in data.parts:
		var d: Vector2i = part[0]
		var dir := Vector2(signi(d.x), signi(d.y))
		var dist := maxi(absi(d.x), absi(d.y))
		var pos := c + dir * cell * (2.0 if dist > 1 else 1.0)
		if dist > 2:
			for i in 3:  # the gem was further away than drawn
				draw_circle(c + dir * cell * (0.95 + i * 0.22), cell * 0.05, Color(1, 1, 1, 0.45))
		if strike:
			draw_line(c, pos, Color(BEAM, 1.0 - (_t - 0.7) / 0.55), cell * 0.14)
		var s := 1.0
		if _t > 0.95 and _t <= 1.3:
			s = 1.0 - (_t - 0.95) / 0.35
		elif _t > 1.3 and _t <= 2.3:
			s = 0.0
		elif _t > 2.3:
			s = minf(1.0, (_t - 2.3) / 0.3)
		if s > 0.01:
			var t2: Texture2D = tex.call(int(part[1]))
			draw_texture_rect(t2, Rect2(pos - Vector2.ONE * cell * 0.45 * s, Vector2.ONE * cell * 0.9 * s), false)
	if font and _t > 1.0 and _t < 2.3:
		var a := minf(1.0, (_t - 1.0) / 0.2) * minf(1.0, (2.3 - _t) / 0.3)
		var fs := int(cell * 0.75)
		var y := c.y - cell * 0.1 - (_t - 1.0) * cell * 0.5
		var txt := "+%d" % int(data.points)
		draw_string(font, Vector2(c.x - cell * 2.5, y + 2), txt, HORIZONTAL_ALIGNMENT_CENTER, cell * 5, fs, Color(0, 0, 0, a * 0.6))
		draw_string(font, Vector2(c.x - cell * 2.5, y), txt, HORIZONTAL_ALIGNMENT_CENTER, cell * 5, fs, Color(1.0, 0.85, 0.35, a))
