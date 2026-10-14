extends SceneTree
## Compare actual scene widgets with pinned UI builders injected by -ReferenceHud.
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func settle(count := 12) -> void:
	for i in count: await process_frame

func near(a: Rect2, b: Rect2, context: String) -> void:
	check(a.position.distance_to(b.position) <= 1.5,context+" position: "+str(a)+" / "+str(b))
	check(a.size.distance_to(b.size) <= 1.5,context+" size: "+str(a)+" / "+str(b))

func _run() -> void:
	await process_frame
	root.get_node("Save").sound = false
	root.get_node("Save").music = false
	root.get_node("Sfx").update_music()
	var locale = root.get_node("L")
	for config in [[1280,720,false,Rect2()],[853,480,true,Rect2()],[1066,480,true,Rect2(40,8,12,16)]]:
		var vp := SubViewport.new()
		vp.size = Vector2i(config[0],config[1])
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var main = load("res://scenes/main.tscn").instantiate()
		main.set_script(load("res://tests/hud_platform_fixture.gd"))
		main.simulate_android = config[2]
		main.test_insets = config[3]
		vp.add_child(main)
		main.set_process(false)
		await main.start_game("classic")
		main._on_viewport_resized()
		await settle()
		main.board.set_process(false)
		var ref_vp := SubViewport.new()
		ref_vp.size = vp.size
		ref_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(ref_vp)
		var reference = load("res://tests/reference_visuals/hud.gd").new()
		reference.size = Vector2(vp.size)
		ref_vp.add_child(reference)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		reference.add_child(margin)
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var inset: Rect2 = config[3]
		var sides: bool = config[2]
		var m := 4 if sides else 16
		margin.add_theme_constant_override("margin_left",m)
		margin.add_theme_constant_override("margin_right",m)
		margin.add_theme_constant_override("margin_top",m+ceili(maxf(inset.position.y,inset.size.y)))
		margin.add_theme_constant_override("margin_bottom",m+ceili(maxf(inset.position.y,inset.size.y)))
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation",10)
		margin.add_child(column)
		var b = load("res://scripts/board_view.gd").new()
		b.logic = BoardLogic.new()
		b.logic.load_cells(23,15,main.logic.cells)
		b.frame_pad = main.board.frame_pad
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		reference.board = b
		reference.logic = b.logic
		reference.android = sides
		if sides:
			reference._build_classic_side_hud(column)
			reference.classic_sides.visible = true
			reference.classic_sides.add_child(b)
			reference.classic_sides.move_child(b,1)
			b.size_flags_horizontal = Control.SIZE_FILL
			reference._layout_classic_sides(Vector2(vp.size),inset)
		else:
			reference._build_classic_hud(column)
			column.add_child(b)
		await settle()
		b.refresh()
		if not sides: reference._layout_classic_header()
		await settle()
		var widgets: Dictionary = reference.hud_sets["classic_android" if sides else "classic"]
		for language in ["ru","en","tr"]:
			locale.set_language(language)
			main.keeper.combo = 9
			main.keeper.color_streak_kind = 1
			main.keeper.color_streak_hits = 4
			main.keeper._last_hit = main.play_time
			main.hud.set_combo(9)
			main._update_hud()
			main.hud.set_number(main.hud.score_label,12345)
			main.hud.set_number(main.hud.best_label,67890)
			reference._set_hud_number(widgets.score,12345)
			reference._set_hud_number(widgets.best,67890)
			widgets.combo_count.text = locale.t("streak_caption")+" 9"
			widgets.combo_mult.text = "×4"
			widgets.combo_mult.add_theme_color_override("font_color",UiKit.COMBO_COLORS[3].lightened(.3))
			widgets.combo_box.modulate = Color.WHITE
			widgets.combo_bar.value = 100
			for key in widgets.captions: widgets.captions[key].text = locale.t(key)
			widgets.bonus.caption.text = locale.t("color_streak_chain")
			widgets.bonus.progress.modulate = Color.WHITE
			widgets.bonus.gem.texture = main.board.GEM_TEX[1]
			widgets.bonus.count.text = "4"
			await settle()
			var context := "%dx%d_%s_%s" % [vp.size.x,vp.size.y,str(sides),language]
			near(main.board.get_global_rect(),b.get_global_rect(),context+" reference board bounds")
			check(main.board.cell == b.cell,context+" reference cells")
			for pair in [[main.hud.time_label,widgets.time],[main.hud.score_label,widgets.score],[main.hud.best_label,widgets.best],
					[main.hud.combo_mult,widgets.combo_mult],[main.hud.chain_count,widgets.bonus.count]]:
				check(pair[0].get_theme_font_size("font_size") == pair[1].get_theme_font_size("font_size"),context+" reference font size")
				if pair[0] == main.hud.time_label and not sides:
					# Pinned Time uses a shrink-width label inside an HBox; the scene label fills
					# the stable slot. Compare its visible glyph anchor/height, not empty width.
					check(pair[0].get_global_rect().position.distance_to(pair[1].get_global_rect().position) <= 1.5,context+" time glyph anchor")
					check(absf(pair[0].get_global_rect().size.y-pair[1].get_global_rect().size.y) <= 1.5,context+" time glyph height")
				else:
					near(pair[0].get_global_rect(),pair[1].get_global_rect(),context+" value "+pair[0].text)
			for pair in [[main.hud.btn_pause,widgets.pause],[main.hud.btn_restart,widgets.restart],[main.hud.btn_settings,widgets.settings]]:
				near(pair[0].get_global_rect(),pair[1].get_global_rect(),context+" reference action")
			if DisplayServer.get_name() != "headless":
				main.ambient.visible = false
				main.board.modulate.a = 0
				b.modulate.a = 0
				await settle()
				await RenderingServer.frame_post_draw
				var output := OS.get_environment("VISUAL_CAPTURE_DIR")
				check(vp.get_texture().get_image().save_png(output.path_join(context+"_integration.png")) == OK,"save integration")
				check(ref_vp.get_texture().get_image().save_png(output.path_join(context+"_refinement.png")) == OK,"save pinned HUD")
		main.queue_free()
		reference.queue_free()
		await settle(2)
		vp.queue_free()
		ref_vp.queue_free()
		await settle(2)
	locale.set_language("ru")
	print("HUD_REFERENCE ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	if not failures.is_empty(): push_error("FAIL pinned HUD comparison")
	print("HUD_REFERENCE_DONE")
	quit(0 if failures.is_empty() else 1)
