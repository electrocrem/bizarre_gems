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
const MENU_BRASS := Color("#c6a35c")
const MENU_TEXT := Color("#f4edda")
const MENU_MUTED := Color("#a6b7b7")
const MENU_PANEL := Color("#10272b")
static var _menu_theme: Theme

## A separate theme for screens; the accepted game HUD keeps its original theme.
static func menu_theme() -> Theme:
	if _menu_theme: return _menu_theme
	var theme: Theme = preload("res://ui/theme.tres").duplicate(true)
	for type in ["Label","Body","Bold","Heading","Title","Number","NumberGold","Crystals"]:
		theme.set_color("font_color",type,MENU_TEXT)
	theme.set_color("font_color","Muted",MENU_MUTED)
	for type in ["Button","IconButton","RoundButton","DailyCard","ChallengeCard","PrimaryButton"]:
		var primary: bool = type == "PrimaryButton"
		for state in ["normal","hover","pressed","disabled","focus"]:
			var fill := MENU_BRASS if primary else Color(MENU_PANEL,.85)
			var edge := Color(MENU_BRASS,.6)
			if state == "hover": fill = fill.lightened(.12); edge = MENU_TEXT
			elif state == "pressed": fill = fill.darkened(.15)
			elif state == "focus": fill = Color.TRANSPARENT; edge = MENU_TEXT
			elif state == "disabled": fill.a = .35; edge.a = .25
			theme.set_stylebox(state,type,box(fill,edge,2 if state == "focus" else 1,10,Vector4(16,12,16,12)))
		for key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","icon_normal_color","icon_hover_color","icon_pressed_color","icon_focus_color"]:
			theme.set_color(key,type,Color("#112326") if primary else MENU_TEXT)
	for type in ["PanelContainer","PanelCompact"]:
		theme.set_stylebox("panel",type,box(Color(MENU_PANEL,.97),Color(MENU_BRASS,.45),1,14,Vector4(18,16,18,16)))
	_menu_theme = theme
	return theme


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
