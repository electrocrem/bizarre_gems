@tool
extends VBoxContainer
## Round icon button with a caption under it (home screen). Set the icon and caption key in the
## inspector; `badge` adds a counter or mark after the caption.

signal pressed

@export var icon: Texture2D:
	set(v):
		icon = v
		if is_node_ready():
			%Button.icon = v
@export var caption := "":
	set(v):
		caption = v
		if is_node_ready():
			_update_caption()
var badge := "":
	set(v):
		badge = v
		_update_caption()


func _ready() -> void:
	%Button.icon = icon
	%Button.pressed.connect(func(): pressed.emit())
	_update_caption()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_update_caption()


func _update_caption() -> void:
	if is_node_ready():
		%Caption.text = tr(caption) + badge
