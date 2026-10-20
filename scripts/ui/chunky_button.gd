@tool
class_name ChunkyButton
extends Button
## A big "3D" menu button: a coloured face over a darker edge that it sinks into when pressed,
## an icon in a disc, a title with a line under it, an optional progress bar and a red badge.
## `compact` makes a small tile instead: icon on top, title and line under it, centred.
## Everything is drawn here (not by the theme); `title` and `line` are shown through tr().

const TITLE_FONT := preload("res://ui/fonts/bold.tres")
const LINE_FONT := preload("res://ui/fonts/body.tres")
const EDGE := 6.0      ## depth of the edge under the face
const BADGE := Color("#ff3b4e")

@export var color := Color("#ffc83d"):
	set(v):
		color = v
		queue_redraw()
@export var symbol: Texture2D:
	set(v):
		symbol = v
		queue_redraw()
@export var title := "":
	set(v):
		title = v
		queue_redraw()
@export var line := "":
	set(v):
		line = v
		queue_redraw()
@export var compact := false:
	set(v):
		compact = v
		queue_redraw()
## 0..1 draws a bar under the line; below 0 there is none.
@export var progress := -1.0:
	set(v):
		progress = v
		queue_redraw()
## Red dot in the corner with this text ("3", "!"); empty: no dot.
var badge := "":
	set(v):
		badge = v
		queue_redraw()
var _t := 0.0


func _ready() -> void:
	flat = true
	text = ""
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for s in [button_down, button_up, mouse_entered, mouse_exited, focus_entered, focus_exited]:
		s.connect(queue_redraw)


func _process(delta: float) -> void:
	if badge != "" and is_visible_in_tree():
		_t += delta
		queue_redraw()  # the badge breathes


func _box(c: Color, r: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(int(r))
	s.anti_aliasing = true
	return s


func _draw() -> void:
	var mode := get_draw_mode()
	var pressed := mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var hover := mode == DRAW_HOVER
	var sink := EDGE - 1.0 if pressed else 0.0
	var h := size.y - EDGE
	var r := minf(20.0, h * 0.32)
	var face := Rect2(0, sink, size.x, h)
	draw_style_box(_box(Color(0, 0, 0, 0.28), r), Rect2(2, EDGE + 3, size.x - 4, h))
	draw_style_box(_box(color.darkened(0.38), r), Rect2(0, EDGE, size.x, h))
	draw_style_box(_box(color.lightened(0.1) if hover else color, r), face)
	draw_style_box(_box(Color(1, 1, 1, 0.2), r * 0.8), Rect2(face.position + Vector2(5, 4), Vector2(face.size.x - 10, face.size.y * 0.4)))
	if has_focus():
		var fb := _box(Color(0, 0, 0, 0), r + 3)
		fb.set_border_width_all(3)
		fb.border_color = Color.WHITE
		draw_style_box(fb, face.grow(4))
	var light := color.get_luminance() > 0.55
	var ink := UiKit.INK if light else Color.WHITE
	if compact:
		_draw_tile(face, ink, light)
	else:
		_draw_wide(face, ink, light)
	if badge != "":
		var br := clampf(size.y * 0.16, 10.0, 14.0) * (1.0 + 0.08 * sin(_t * 5.0))
		var bc := Vector2(size.x - br * 0.6, sink + br * 0.4)
		draw_circle(bc, br + 2.0, Color.WHITE)
		draw_circle(bc, br, BADGE)
		var fs := int(br * 1.25)
		draw_string(TITLE_FONT, bc + Vector2(-br, fs * 0.36), badge, HORIZONTAL_ALIGNMENT_CENTER, br * 2.0, fs, Color.WHITE)


## The largest size up to fs (not below 10) at which s fits in w.
func _fit(font: Font, s: String, w: float, fs: int) -> int:
	while fs > 10 and font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 1
	return fs


func _text(font: Font, pos: Vector2, s: String, align: HorizontalAlignment, w: float, fs: int, ink: Color, light: bool) -> void:
	if not light:
		draw_string_outline(font, pos, s, align, w, fs, maxi(2, fs / 6), Color(0, 0, 0, 0.35))
	draw_string(font, pos, s, align, w, fs, ink)


func _draw_wide(face: Rect2, ink: Color, light: bool) -> void:
	var h := face.size.y
	var disc := h * 0.36
	var dc := face.position + Vector2(h * 0.52, h * 0.5)
	draw_circle(dc, disc, Color(0, 0, 0, 0.16) if light else Color(1, 1, 1, 0.18))
	if symbol:
		var isz := disc * 1.1
		draw_texture_rect(symbol, Rect2(dc - Vector2.ONE * isz / 2, Vector2.ONE * isz), false, ink)
	var x := face.position.x + h * 1.0
	var w := face.size.x - (x - face.position.x) - h * 0.3
	var ts := _fit(TITLE_FONT, tr(title), w, int(clampf(h * 0.36, 18.0, 34.0)))
	var ls := _fit(LINE_FONT, tr(line), w, int(clampf(h * 0.2, 12.0, 20.0)))
	var has_bar := progress >= 0.0
	var block := ts + (ls + 6 if line != "" else 0) + (10 if has_bar else 0)
	var top := face.position.y + (h - block) / 2.0
	_text(TITLE_FONT, Vector2(x, top + ts * 0.82), tr(title), HORIZONTAL_ALIGNMENT_LEFT, w, ts, ink, light)
	var y := top + ts
	if line != "":
		y += ls + 4
		draw_string(LINE_FONT, Vector2(x, y), tr(line), HORIZONTAL_ALIGNMENT_LEFT, w, ls, Color(ink, 0.85))
	if has_bar:
		var bar := Rect2(x, y + 6, minf(w, 220.0), 7)
		draw_style_box(_box(Color(0, 0, 0, 0.25), 4), bar)
		if progress > 0.0:
			draw_style_box(_box(Color.WHITE if not light else UiKit.INK, 4), Rect2(bar.position, Vector2(maxf(bar.size.x * progress, 8.0), bar.size.y)))


func _draw_tile(face: Rect2, ink: Color, light: bool) -> void:
	var h := face.size.y
	var isz := h * 0.34
	var ts := _fit(TITLE_FONT, tr(title), face.size.x - 8, int(clampf(h * 0.2, 13.0, 22.0)))
	var ls := _fit(LINE_FONT, tr(line), face.size.x - 8, int(clampf(h * 0.16, 11.0, 16.0)))
	var block := isz + 4 + ts + (ls + 3 if line != "" else 0)
	var top := face.position.y + (h - block) / 2.0
	if symbol:
		draw_texture_rect(symbol, Rect2(Vector2(face.position.x + (face.size.x - isz) / 2, top), Vector2.ONE * isz), false, ink)
	var y := top + isz + 4 + ts * 0.85
	_text(TITLE_FONT, Vector2(face.position.x + 4, y), tr(title), HORIZONTAL_ALIGNMENT_CENTER, face.size.x - 8, ts, ink, light)
	if line != "":
		draw_string(LINE_FONT, Vector2(face.position.x + 4, y + ls + 3), tr(line), HORIZONTAL_ALIGNMENT_CENTER, face.size.x - 8, ls, Color(ink, 0.85))
