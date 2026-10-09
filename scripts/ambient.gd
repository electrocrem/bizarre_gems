class_name Ambient
extends Control
## Living background: slow drifting pools of coloured light and dust motes rising through them.
## pulse() brightens it briefly when something big happens on the board.

const GLOW_TEX := preload("res://assets/fx/glow.png")
const SPARKLE_TEX := preload("res://assets/fx/sparkle.png")
const BLOBS := [
	{"c": Color("#2fb5a8"), "s": 0.9, "sp": Vector2(0.050, 0.037), "ph": 0.0},
	{"c": Color("#7a4fd6"), "s": 0.8, "sp": Vector2(0.031, 0.043), "ph": 2.1},
	{"c": Color("#d2ab55"), "s": 0.6, "sp": Vector2(0.041, 0.029), "ph": 4.2},
	{"c": Color("#e2507f"), "s": 0.55, "sp": Vector2(0.027, 0.051), "ph": 5.5},
]
const MOTES := 36

var _t := 0.0
var _pulse := 0.0
var _pulse_color := Color.WHITE
var _motes: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in MOTES:
		_motes.append(_new_mote(true))


func _new_mote(anywhere: bool) -> Dictionary:
	return {
		"x": randf(), "y": randf() if anywhere else 1.05,
		"v": randf_range(0.008, 0.025), "s": randf_range(4.0, 11.0),
		"w": randf_range(0.5, 1.5), "a": randf_range(0.15, 0.45),
	}


func pulse(color: Color, strength := 1.0) -> void:
	_pulse_color = color
	_pulse = maxf(_pulse, strength)


func _process(delta: float) -> void:
	_t += delta
	_pulse = maxf(0.0, _pulse - delta * 1.2)
	for m in _motes:
		m.y -= m.v * delta
		if m.y < -0.05:
			m.merge(_new_mote(false), true)
	queue_redraw()


func _draw() -> void:
	var s := size
	var big := maxf(s.x, s.y)
	for b in BLOBS:
		var sp: Vector2 = b.sp
		var p := Vector2(0.5 + 0.38 * sin(_t * sp.x * TAU * 0.25 + b.ph), 0.5 + 0.38 * cos(_t * sp.y * TAU * 0.25 + b.ph * 1.3)) * s
		var r: float = big * b.s
		var col: Color = b.c
		draw_texture_rect(GLOW_TEX, Rect2(p - Vector2.ONE * r / 2, Vector2.ONE * r), false, Color(col, 0.10 + _pulse * 0.10))
	if _pulse > 0.0:
		draw_texture_rect(GLOW_TEX, Rect2(s / 2 - Vector2.ONE * big * 0.7, Vector2.ONE * big * 1.4), false, Color(_pulse_color, _pulse * 0.18))
	for m in _motes:
		var x: float = (m.x + 0.02 * sin(_t * m.w + m.y * 9.0)) * s.x
		var sz: float = m.s * (1.0 + _pulse * 0.5)
		var tw: float = 0.6 + 0.4 * sin(_t * 3.0 * m.w + m.x * 20.0)
		draw_texture_rect(SPARKLE_TEX, Rect2(Vector2(x, m.y * s.y) - Vector2.ONE * sz / 2, Vector2.ONE * sz), false, Color(1, 0.93, 0.78, m.a * tw))
