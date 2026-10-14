extends SceneTree
## Compare the scene-owned preview against pinned refinement drawing in disposable viewports.
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	await process_frame
	if not root.has_node("TestIsolation") or DisplayServer.get_name() == "headless" or not FileAccess.file_exists("res://tests/reference_menu/preview.gd"):
		push_error("FAIL use -Render -ReferenceMenu")
		quit(1)
		return
	root.get_node("Save").sound = false
	root.get_node("Save").music = false
	root.get_node("Sfx").update_music()
	for id in ["classic","bright"]:
		for width in [320,400,440]:
			var vp := SubViewport.new()
			vp.size = Vector2i(width,480)
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(vp)
			var card = load("res://scenes/ui/parts/mode_card.tscn").instantiate()
			card.mode_id = id
			card.theme = UiKit.menu_theme()
			vp.add_child(card)
			card.size = Vector2(width,480)
			for i in 12: await process_frame
			var preview: Control = card.get_node("%Preview")
			var reference_vp := SubViewport.new()
			reference_vp.size = vp.size # Identical clip-space origin avoids GPU rounding differences at polygon edges.
			reference_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			root.add_child(reference_vp)
			var reference = load("res://tests/reference_menu/preview.gd").new()
			reference.visual_profile = "classic" if id == "classic" else "classic_run"
			reference.number_font = UiKit.NUMBER_FONT
			reference_vp.add_child(reference)
			reference.position = preview.global_position
			reference.size = preview.size
			for i in 8: await process_frame
			await RenderingServer.frame_post_draw
			var actual := vp.get_texture().get_image().get_region(Rect2i(preview.global_position,preview.size))
			var expected := reference_vp.get_texture().get_image().get_region(Rect2i(preview.global_position,preview.size))
			actual.convert(Image.FORMAT_RGBA8)
			expected.convert(Image.FORMAT_RGBA8)
			check(actual.get_data() == expected.get_data(),"pinned preview pixels "+id+str(width))
			var path := OS.get_environment("VISUAL_CAPTURE_DIR").path_join("preview_%s_%d" % [id,width])
			actual.save_png(path+"_actual.png")
			expected.save_png(path+"_reference.png")
			vp.queue_free()
			reference_vp.queue_free()
			await process_frame
	print("MENU_REFERENCE ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	if not failures.is_empty(): push_error("FAIL menu reference")
	print("MENU_REFERENCE_DONE")
	quit(1 if not failures.is_empty() else 0)
