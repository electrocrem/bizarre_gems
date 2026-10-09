class_name Ambient
extends Control
## Living background: slow drifting pools of coloured light (one shader pass) and dust motes
## rising through them. pulse() brightens it briefly when something big happens on the board.

const SPARKLE_TEX := preload("res://assets/fx/sparkle.png")
const SHADER := """
shader_type canvas_item;
render_mode blend_add;  // pools only ever light up the cloth underneath
uniform float aspect = 1.0;
uniform float pulse = 0.0;
uniform vec4 pulse_color : source_color = vec4(1.0);

vec3 pool(vec2 p, vec2 c, float r, vec3 col) {
	vec2 d = p - c;
	return col * exp(-dot(d, d) / (r * r));
}

void fragment() {
	float t = TIME;
	vec2 p = vec2(UV.x * aspect, UV.y);
	vec2 span = vec2(aspect, 1.0);
	vec3 c = vec3(0.0);
	c += pool(p, span * vec2(0.5 + 0.38 * sin(t * 0.031), 0.5 + 0.38 * cos(t * 0.023)), 0.55, vec3(0.18, 0.71, 0.66));
	c += pool(p, span * vec2(0.5 + 0.38 * sin(t * 0.019 + 2.1), 0.5 + 0.38 * cos(t * 0.027 + 2.7)), 0.5, vec3(0.48, 0.31, 0.84));
	c += pool(p, span * vec2(0.5 + 0.38 * sin(t * 0.026 + 4.2), 0.5 + 0.38 * cos(t * 0.018 + 5.4)), 0.38, vec3(0.82, 0.67, 0.33));
	c += pool(p, span * vec2(0.5 + 0.38 * sin(t * 0.017 + 5.5), 0.5 + 0.38 * cos(t * 0.032 + 7.1)), 0.34, vec3(0.89, 0.31, 0.5));
	c = c * (0.10 + pulse * 0.10) + pulse_color.rgb * pulse * 0.10 * exp(-dot(UV - 0.5, UV - 0.5) * 3.0);
	COLOR = vec4(c, 1.0);
}
"""
const MOTES := 22

var _t := 0.0
var _pulse := 0.0
var _mat := ShaderMaterial.new()
var _pools: ColorRect
var _layer: Control
var _motes: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_pools = ColorRect.new()
	_pools.material = _mat
	_pools.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pools.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_pools)
	_layer = Control.new()
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.draw.connect(_draw_motes)
	add_child(_layer)
	resized.connect(func(): _mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0)))
	for i in MOTES:
		_motes.append(_new_mote(true))


func _new_mote(anywhere: bool) -> Dictionary:
	return {
		"x": randf(), "y": randf() if anywhere else 1.05,
		"v": randf_range(0.008, 0.025), "s": randf_range(4.0, 11.0),
		"w": randf_range(0.5, 1.5), "a": randf_range(0.15, 0.45),
	}


func pulse(color: Color, strength := 1.0) -> void:
	_pulse = maxf(_pulse, strength)
	_mat.set_shader_parameter("pulse_color", color)


func _process(delta: float) -> void:
	_t += delta
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 1.2)
		_mat.set_shader_parameter("pulse", _pulse)
	for m in _motes:
		m.y -= m.v * delta
		if m.y < -0.05:
			m.merge(_new_mote(false), true)
	_layer.queue_redraw()


func _draw_motes() -> void:
	var s := size
	for m in _motes:
		var x: float = (m.x + 0.02 * sin(_t * m.w + m.y * 9.0)) * s.x
		var sz: float = m.s * (1.0 + _pulse * 0.5)
		var tw: float = 0.6 + 0.4 * sin(_t * 3.0 * m.w + m.x * 20.0)
		_layer.draw_texture_rect(SPARKLE_TEX, Rect2(Vector2(x, m.y * s.y) - Vector2.ONE * sz / 2, Vector2.ONE * sz), false, Color(1, 0.93, 0.78, m.a * tw))
