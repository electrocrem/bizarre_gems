@tool
extends PanelContainer
## A card on the mode screen. Everything about it is set in the inspector of scenes/ui/modes.tscn.

signal chosen(mode_id: String)

@export var mode_id := "classic"
@export var accent := Color("#ffc83d"):
	set(v):
		accent = v
		if is_node_ready():
			_style()
@export var preview: Texture2D
@export var play_icon: Texture2D
@export var play_text := "play"


func _ready() -> void:
	%Preview.texture = preview
	%ModeName.text = "mode_" + mode_id
	%Desc.text = "mode_%s_desc" % mode_id
	$VBox/Play.icon = play_icon
	$VBox/Play.text = play_text
	_style()


func _style() -> void:
	add_theme_stylebox_override("panel", UiKit.box(UiKit.PANEL, accent, 3, 20, Vector4(16, 16, 16, 18)))
	%ModeName.add_theme_color_override("font_color", accent.lightened(0.2))


func set_best(text: String) -> void:
	%Best.text = text


func play_button() -> Button:
	return $VBox/Play


func _on_play_pressed() -> void:
	chosen.emit(mode_id)
