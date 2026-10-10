class_name UiKit
## Colours and icons shared by the screens. Fonts, button and panel styles live in
## res://ui/theme.tres (open it in the editor); use these only where code needs a colour.

const BRASS := Color("#ffc83d")        ## accent: gold
const BRASS_LIGHT := Color("#ffe9a3")
const CREAM := Color("#ffffff")
const MUTED := Color("#aab8ec")
const DANGER := Color("#ff5d6c")
const INK := Color("#141a3a")
const GREEN := Color("#5cc87a")
const CRYSTAL := Color("#7fd8ff")
const PANEL := Color(0.08, 0.11, 0.3, 0.97)
const COMBO_COLORS := [Color("#3d8bff"), Color("#22c97a"), Color("#ff9a2e"), Color("#ff4dad")]
## Background of each chapter of the level map: caves, glacier, volcano, jungle, space.
const CHAPTER_THEMES := [
	{"top": Color("#5b4a8a"), "bottom": Color("#1e1733")},
	{"top": Color("#6fa8dc"), "bottom": Color("#1f3f6b")},
	{"top": Color("#c2452d"), "bottom": Color("#3a1210")},
	{"top": Color("#3f9a55"), "bottom": Color("#103a22")},
	{"top": Color("#3b3f9e"), "bottom": Color("#090a26")},
]

const NUMBER_FONT := preload("res://ui/fonts/numbers.tres")


## An icon from assets/ui by name: "play" -> res://assets/ui/icon_play.png.
static func icon(name: String) -> Texture2D:
	return load("res://assets/ui/icon_%s.png" % name)


## A flat rounded box, for styles that are picked in code (colours that change at run time).
static func box(bg: Color, border: Color, bw := 2, radius := 10, pad := Vector4(16, 10, 16, 10)) -> StyleBoxFlat:
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


## Remove every child right away (out of the layout at once, so the parent can be measured).
static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
