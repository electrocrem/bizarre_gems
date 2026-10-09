class_name Ambient
extends Control
## Living background: slow drifting pools of coloured light (one shader pass) and dust motes
## rising through them. pulse() brightens it briefly when something big happens on the board.

const SPARKLE_TEX := preload("res://assets/fx/sparkle.png")
const SHADER := """
shader_type canvas_item;
uniform vec4 top : source_color = vec4(0.23, 0.36, 0.86, 1.0);
uniform vec4 bottom : source_color = vec4(0.11, 0.18, 0.56, 1.0);
uniform float pulse = 0.0;
uniform vec4 pulse_color : source_color = vec4(1.0);
uniform float aspect = 1.0;

void fragment() {
	vec3 c = mix(top.rgb, bottom.rgb, smoothstep(0.0, 1.0, UV.y));
	// soft diagonal bands of light drifting slowly
	float band = sin((UV.x * aspect + UV.y) * 7.0 - TIME * 0.35) * 0.5 + 0.5;
	c += vec3(1.0) * pow(band, 6.0) * 0.045;
	// glow at the top centre, brighter on a pulse
	float d = distance(vec2(UV.x * aspect, UV.y), vec2(0.5 * aspect, 0.18));
	c += mix(vec3(1.0), pulse_color.rgb, pulse) * exp(-d * d * 3.0) * (0.10 + pulse * 0.25);
	COLOR = vec4(c, 1.0);
}
"""
## classic skin: soft drifting pools of light added on top of the velvet
const POOLS_SHADER := """
shader_type canvas_item;
render_mode blend_add;
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
	c = c * (0.10 + pulse * 0.10) + pulse_color.rgb * pulse * 0.10 * exp(-dot(UV - 0.5, UV - 0.5) * 3.0);
	COLOR = vec4(c, 1.0);
}
"""
const MOTES := 22

var _t := 0.0
var _pulse := 0.0
var _mat := ShaderMaterial.new()
var _pools: ColorRect  ## bright skin: gradient
var _velvet: TextureRect
var _vignette: TextureRect
var _classic_pools: ColorRect
var _classic_mat := ShaderMaterial.new()
var skin := "classic"
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
	_velvet = TextureRect.new()
	_velvet.texture = preload("res://assets/ui/velvet.png")
	_velvet.stretch_mode = TextureRect.STRETCH_TILE
	_vignette = TextureRect.new()
	_vignette.texture = preload("res://assets/ui/vignette.png")
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	var csh := Shader.new()
	csh.code = POOLS_SHADER
	_classic_mat.shader = csh
	_classic_pools = ColorRect.new()
	_classic_pools.material = _classic_mat
	for n in [_velvet, _vignette, _classic_pools]:
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(n)
	set_skin(skin)
	_layer = Control.new()
	_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.draw.connect(_draw_motes)
	add_child(_layer)
	resized.connect(func():
		_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
		_classic_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0)))
	for i in MOTES:
		_motes.append(_new_mote(true))


func _new_mote(anywhere: bool) -> Dictionary:
	return {
		"x": randf(), "y": randf() if anywhere else 1.05,
		"v": randf_range(0.008, 0.025), "s": randf_range(4.0, 11.0),
		"w": randf_range(0.5, 1.5), "a": randf_range(0.15, 0.45),
	}


## "classic": velvet with drifting light; "bright": colour gradient that fades between palettes.
func set_skin(name: String) -> void:
	skin = name
	var classic := name != "bright"
	_pools.visible = not classic
	for n in [_velvet, _vignette, _classic_pools]:
		n.visible = classic


## Fade the gradient to a new palette.
func fade_palette(top: Color, bottom: Color, seconds := 0.8) -> void:
	var from_top: Color = _mat.get_shader_parameter("top") if _mat.get_shader_parameter("top") != null else top
	var from_bottom: Color = _mat.get_shader_parameter("bottom") if _mat.get_shader_parameter("bottom") != null else bottom
	var tw := create_tween()
	tw.tween_method(func(t: float):
		_mat.set_shader_parameter("top", from_top.lerp(top, t))
		_mat.set_shader_parameter("bottom", from_bottom.lerp(bottom, t)), 0.0, 1.0, seconds)


func pulse(color: Color, strength := 1.0) -> void:
	_pulse = maxf(_pulse, strength)
	_mat.set_shader_parameter("pulse_color", color)
	_classic_mat.set_shader_parameter("pulse_color", color)


func _process(delta: float) -> void:
	_t += delta
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta * 1.2)
		_mat.set_shader_parameter("pulse", _pulse)
		_classic_mat.set_shader_parameter("pulse", _pulse)
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
