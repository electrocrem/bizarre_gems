extends VBoxContainer
## A tile pack in the collection: three of its tiles, its name and what can be done with it.

signal action_pressed(look: int)

var look := 0


func setup(i: int, button_text: String, button_icon: Texture2D, primary: bool, enabled: bool) -> void:
	look = i
	for k in 3:
		(%Tiles.get_child(k) as TextureRect).texture = load("res://assets/tiles/look_%d_%d.png" % [i, k * 2])
	%PackName.text = L.t("look_%d" % i)
	%Action.text = button_text
	%Action.icon = button_icon
	%Action.theme_type_variation = &"PrimaryButton" if primary else &""
	%Action.disabled = not enabled


func _on_action_pressed() -> void:
	action_pressed.emit(look)
