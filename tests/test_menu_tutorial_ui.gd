extends RefCounted
## Reachability and layout of scene-based screens/practice in RU/EN/TR, using isolated real scenes.
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func settle(tree: SceneTree, count := 8) -> void:
	for i in count: await tree.process_frame

func translations(main) -> void:
	var file := FileAccess.open("res://i18n/strings.csv",FileAccess.READ)
	var header := file.get_csv_line()
	check(header == PackedStringArray(["keys","ru","en","tr"]),"CSV language columns")
	var seen := {}
	var locale = main.get_node("/root/L")
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0] == "": continue
		check(row.size() == 4 and not seen.has(row[0]),"unique complete CSV row "+row[0])
		if row.size() != 4: continue
		seen[row[0]] = true
		var placeholders := RegEx.new()
		placeholders.compile("\\{([^}]+)\\}")
		var expected := []
		for m in placeholders.search_all(row[1]): expected.append(m.get_string(1))
		expected.sort()
		for lang in 3:
			locale.set_language(locale.SUPPORTED[lang])
			var found := []
			for m in placeholders.search_all(row[lang+1]): found.append(m.get_string(1))
			found.sort()
			check(not row[lang+1].is_empty() and expected == found,"placeholder parity "+row[0]+locale.lang)
			check(locale.t(row[0]) == row[lang+1],"imported translation "+row[0]+locale.lang)
	for id in main.TutorialLessons.STEPS:
		for suffix in ["","_title","_result"]: check(seen.has("lesson_"+id+suffix),"complete lesson text "+id+suffix)

func menus(main) -> void:
	main.go_menu()
	main.get_node("/root/Progress").tutorial = true
	main.home.get_node("%Play").pressed.emit()
	check(main.modes.visible and not main.home.visible and not main.dim.visible,"Play opens velvet mode selection")
	for card in main.modes.get_node("%Cards").get_children():
		check(card.visible == (card.mode_id in ["classic","bright"]),"mode visibility "+card.mode_id)
		if card.mode_id not in ["classic","bright"]:
			card.chosen.emit(card.mode_id)
			check(main.state == main.State.MENU,"hidden card cannot launch "+card.mode_id)
	for id in ["classic","bright"]:
		var card = main.modes.get_node("%Cards").get_node(id.capitalize())
		card.play_button().pressed.emit()
		while main._run_starting: await main.get_tree().process_frame
		check(main.state == main.State.PLAYING and main.mode.id == id and main.score == 0 and main.time_left == 120,"actual mode card launches "+id)
		main.go_menu()
		main.show_screen(main.modes)
	for route in [&"map",&"puzzle_map",&"levels",&"zen",&"puzzle",&"collection"]:
		main._navigate(route)
		check(not main.map.visible and not main.collection.visible and main.state == main.State.MENU,"route gate "+route)
	main.show_screen(main.map)
	check(not main.map.visible,"direct screen gate")
	main.go_menu()
	main.home.get_node("%More").pressed.emit()
	check(main.more.visible,"More action preserved")
	for route in [&"rules",&"settings",&"stats",&"achievements",&"tasks",&"gift",&"leaders"]:
		main._navigate(route)
		await settle(main.get_tree())
		check(main.screens[route].visible,"service route "+route)
		main.go_menu()
	check(not main.screens.has(&"pass") and not main.get_node("/root/Progress").COSMETICS_ENABLED,"cosmetics/pass remain unavailable")
	main.pending_challenge = {"mode":"classic","seed":42,"dims":Vector2i(9,7),"score":50}
	main.home.challenge = main.pending_challenge
	main.home.refresh()
	check(main.home.get_node("%Challenge").visible,"Challenge card retained")
	main.home.get_node("%Challenge").pressed.emit()
	check(main.challenge == main.pending_challenge and main.mode.id == "classic","Challenge launch retained")
	main.end_game("time")
	var result_score: int = main.score
	var result_progress: Dictionary = main.get_node("/root/Progress").to_dict().duplicate(true)
	main.result.set_ad_pending(true)
	main.get_node("/root/L").set_language("en")
	check(main.result.get_node("%Title").text == main.get_node("/root/L").t("times_up") and main.score == result_score,"dynamic result retranslated without playing")
	check(main.result.get_node("%Again").disabled and main.get_node("/root/Progress").to_dict() == result_progress,"result language change keeps pending gates and payouts")
	main.go_menu()
	main._navigate(&"rules")
	main.rules.set_page(1)
	main.get_node("/root/L").set_language("tr")
	check(main.rules.page == 1,"language switch preserves rules page")
	main.go_menu()

func layouts(main) -> void:
	var locale = main.get_node("/root/L")
	for resolution in [Vector2i(1280,720),Vector2i(960,540),Vector2i(800,600),Vector2i(480,850),Vector2i(360,640)]:
		for language in locale.SUPPORTED:
			var vp := SubViewport.new()
			vp.size = resolution
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			main.add_child(vp)
			var sample = load("res://scenes/main.tscn").instantiate()
			sample.set_script(load("res://tests/hud_platform_fixture.gd"))
			sample.simulate_android = resolution.x < resolution.y
			sample.test_insets = Rect2(8,16,8,12)
			vp.add_child(sample)
			sample.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			sample.set_process(false)
			locale.set_language(language)
			await settle(main.get_tree(),24) # Finish the screen's .24 s grow-in before testing scroll reachability.
			var safe := Rect2(Vector2(8,16),Vector2(resolution)-Vector2(16,28))
			check(sample.home.get_node("%Play").size.x >= 260,"readable home Play "+str(resolution)+language)
			var scroll: ScrollContainer = sample.home.get_node("%Scroll")
			check(sample.home.get_node("%VBox").size.x <= scroll.size.x,"home content fits scroll width "+str(resolution)+language)
			check(sample.home.get_node("%Leaders").get_node("%Caption").text.begins_with(locale.t("leaders")),"live round-button translation "+language)
			scroll.ensure_control_visible(sample.home.get_node("%More"))
			await settle(main.get_tree())
			check(scroll.get_global_rect().grow(1).encloses(sample.home.get_node("%More").get_global_rect()),"last home action reachable "+str(resolution)+language)
			sample.show_screen(sample.modes)
			await settle(main.get_tree(),20)
			var cards = sample.modes.get_node("%Cards")
			check(cards.columns == (2 if resolution.x >= 880 else 1),"pinned card columns")
			check(cards.size.x <= sample.modes.get_node("%Scroll").size.x,"mode cards fit width")
			for route in [&"more",&"settings",&"rules",&"leaders",&"stats",&"tasks",&"gift",&"achievements"]:
				sample._navigate(route)
				await settle(main.get_tree(),24)
				check(safe.grow(1).encloses(sample.screens[route].get_global_rect()),"dialog safe "+str(resolution)+language+route)
				sample.go_menu()
			sample.show_screen(sample.modes)
			await settle(main.get_tree(),24)
			var rng_state: int = sample.rng.state
			var cells: PackedInt32Array = sample.logic.cells.duplicate()
			for card in cards.get_children(): card.get_node("%Preview").queue_redraw()
			await settle(main.get_tree())
			check(sample.rng.state == rng_state and sample.logic.cells == cells,"preview cannot consume game RNG or mutate board")
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				vp.get_texture().get_image().save_png(OS.get_environment("VISUAL_CAPTURE_DIR").path_join("modes_%dx%d_%s.png" % [resolution.x,resolution.y,language]))
			await sample.start_game("tutorial")
			for i in (0 if "--menus-only" in OS.get_cmdline_user_args() else 20):
				sample._tutorial_step(i)
				var id: String = sample._tutorial_id()
				for state in ["instruction","error","receipt","result"]:
					if state == "error": sample._tutorial_feedback("lesson_wrong")
					elif state == "receipt": sample._tutorial_feedback("lesson_pair_support" if id == "special" else "lesson_receipt",{"n":4,"p":12,"s":3,"m":2})
					elif state == "result": sample._tutorial_done("",{"n":4,"p":20,"s":5,"m":4,"base":8,"double":4,"color":4,"combo":9,"w":4})
					await settle(main.get_tree())
					var context: String = str(resolution)+language+id+state
					var grid := Rect2(sample.board.global_position+sample.board.origin,Vector2(5,5)*sample.board.cell)
					var card: Rect2 = sample.practice.get_global_rect()
					check(safe.grow(1).encloses(grid) and safe.grow(1).encloses(card),"safe practice "+context)
					check(not grid.intersects(card),"guidance outside field "+context)
					check(sample.board.cell >= 28,"usable cells "+context)
					check(sample.tut_label.get_visible_line_count() == sample.tut_label.get_line_count(),"all instruction lines visible "+context)
					check(not sample.tut_label.text.contains("{") and not sample.tut_label.text.begins_with("lesson_"),"formatted translation "+context)
					check(not sample.hud.run_badge.is_visible_in_tree(),"practice never gets Run badge "+context)
					for action in sample.practice.get_node("Card/Actions").get_children():
						if action is Button and action.visible:
							check(card.grow(1).encloses(action.get_global_rect()) and action.size.y >= 44,"touch action fits "+context+action.name)
					if sample.tut_hand.visible:
						sample._update_hand()
						check(safe.grow(1).encloses(sample.tut_hand.get_global_rect()),"guided hand safe "+context)
				if DisplayServer.get_name() != "headless" and id in ["empty","special","clock"]:
					sample._tutorial_step(i)
					for hit in sample.TutorialLessons.goal(id): sample._on_slot(sample._tutorial_target())
					if id == "clock": sample._process(1.6)
					sample.shown_score = sample.score
					sample.hud.set_number(sample.hud.score_label,sample.score)
					await main.get_tree().create_timer(.8).timeout
					await RenderingServer.frame_post_draw
					check(vp.get_texture().get_image().save_png(OS.get_environment("VISUAL_CAPTURE_DIR").path_join("practice_%dx%d_%s_%s.png" % [resolution.x,resolution.y,language,id])) == OK,"practice capture")
			sample.go_menu()
			await settle(main.get_tree(),20)
			sample.home.get_node("%Scroll").scroll_vertical = 0
			await settle(main.get_tree())
			if DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				vp.get_texture().get_image().save_png(OS.get_environment("VISUAL_CAPTURE_DIR").path_join("home_%dx%d_%s.png" % [resolution.x,resolution.y,language]))
				if resolution.x in [360,1280]:
					for route in [&"more",&"settings",&"rules"]:
						sample._navigate(route)
						if route == &"rules": sample.rules.set_page(1)
						await settle(main.get_tree(),24)
						await RenderingServer.frame_post_draw
						vp.get_texture().get_image().save_png(OS.get_environment("VISUAL_CAPTURE_DIR").path_join("screen_%s_%dx%d_%s.png" % [route,resolution.x,resolution.y,language]))
			vp.queue_free()
			await settle(main.get_tree())

func run_suite(main) -> Dictionary:
	translations(main)
	await menus(main)
	await layouts(main)
	return {"checks":checks,"failed":failures.size(),"failures":failures}
