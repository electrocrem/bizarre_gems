extends Screen
## How to play: pages turned with the arrows or a swipe. The pages themselves are plain nodes
## in scenes/ui/rules.tscn (Pages/Page0...), so they are edited in the editor.

signal tutorial_pressed

var page := 0
var _swipe_x := NAN


func refresh() -> void:
	set_page(0)


func set_page(i: int) -> void:
	var pages := %Pages.get_children()
	page = clampi(i, 0, pages.size() - 1)
	for pi in pages.size():
		pages[pi].visible = pi == page
	$VBox/Nav/Prev.disabled = page == 0
	$VBox/Nav/Next.disabled = page == pages.size() - 1
	for pi in %Dots.get_child_count():
		(%Dots.get_child(pi) as Panel).add_theme_stylebox_override("panel",
			UiKit.box(UiKit.BRASS if pi == page else Color(1, 1, 1, 0.25), Color.TRANSPARENT, 0, 5, Vector4.ZERO))


## swipe left / right to turn the page
func _on_pages_gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_swipe_x = ev.position.x
		elif not is_nan(_swipe_x):
			var dx: float = ev.position.x - _swipe_x
			_swipe_x = NAN
			if absf(dx) > 50.0:
				set_page(page + (1 if dx < 0 else -1))


func _on_prev_pressed() -> void:
	click()
	set_page(page - 1)


func _on_next_pressed() -> void:
	click()
	set_page(page + 1)


func _on_tutorial_pressed() -> void:
	click()
	tutorial_pressed.emit()


func _on_close_pressed() -> void:
	click()
	navigate.emit(&"back")
