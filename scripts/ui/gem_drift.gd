class_name GemDrift
extends Control
## Gems floating up behind the home screen, slowly turning: a living backdrop.

const COUNT := 16

var _gems: Array[Dictionary] = []
var _tex: Array[Texture2D] = []
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for t in BoardView.TILE_TEX:
		_tex.append(t)
	for i in COUNT:
		_gems.append(_new_gem(true))


func _new_gem(anywhere: bool) -> Dictionary:
	return {"x": randf(), "y": randf_range(0.0, 1.1) if anywhere else 1.1, "v": randf_range(0.015, 0.04),
		"s": randf_range(0.6, 1.3), "r": randf() * TAU, "vr": randf_range(-0.5, 0.5), "k": randi() % _tex.size(),
		"a": randf_range(0.10, 0.22), "w": randf_range(0.5, 1.2)}


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	for g in _gems:
		g.y -= g.v * delta
		g.r += g.vr * delta
		if g.y < -0.1:
			g.merge(_new_gem(false), true)
	queue_redraw()


func _draw() -> void:
	var base := clampf(minf(size.x, size.y) * 0.09, 28.0, 72.0)
	for g in _gems:
		var p := Vector2((g.x + 0.03 * sin(_t * g.w + g.y * 6.0)) * size.x, g.y * size.y)
		var sz: float = base * g.s
		draw_set_transform(p, g.r)
		draw_texture_rect(_tex[g.k], Rect2(-Vector2.ONE * sz / 2, Vector2.ONE * sz), false, Color(1, 1, 1, g.a))
	draw_set_transform(Vector2.ZERO)
