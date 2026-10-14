extends RefCounted
## Adapted from refinement@bcee016. HUD assertions belong to stage 6; experiment to stage 8.
## Challenge supplies the seed explicitly: upstream has a separate shareable-game RNG.
var checks := 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func digest(b) -> String:
	return (str(b.cells) + str(b.shine) + str(b.hp) + str(b.chain) + str(b.ice) + str(b.bomb) + str(b.cham)).sha256_text()

func run_suite(main) -> Dictionary:
	main.go_menu()
	var observations := []
	for config in [["classic", false], ["bright", false], ["bright", true]]:
		await main.start_game(config[0], config[1], {} if config[1] else {"mode":config[0], "seed":8181, "dims":Vector2i(23,15) if config[0] == "classic" else Vector2i(18,11), "score":0})
		main.board.set_process(false)
		var before := digest(main.logic)
		var geometry := [main.logic.cols, main.logic.rows, main.board.cell, main.board.origin]
		var profile := "classic" if config[0] == "classic" else "classic_run"
		check(main.mode.skin == config[0] and main.board.skin == main.mode.skin, "logical skin retained " + str(config))
		check(main.visual_profile == profile and main.board.visual_profile == profile, "reference profile " + str(config))
		check(main.ambient.skin == "classic", "velvet backdrop")
		check(main.time_left == 120 and main.score == 0 and main.keeper.combo_window == 3.5, "initial rules unchanged")
		if config[0] == "bright":
			for k in 6:
				check(main.board._tex(k) == main.board.GEM_TEX[main.board.RUN_GEM_INDICES[k]], "faceted gem mapping " + str(k))
			check(main.board._tex(BoardLogic.JOKER) == main.board.JOKER_TEX, "joker fallback texture retained")
			check(not main.logic.has_bombs() and main.logic.ice.count(0) == main.logic.ice.size(), "hazards remain disabled")
		var music_skin: String = main.get_node("/root/Sfx").skin
		for override in ["bright", "classic", "classic_run", profile]:
			main.board.visual_profile = override
			check(digest(main.logic) == before and main.score == 0 and main.time_left == 120, "profile cannot mutate rules")
			check(geometry == [main.logic.cols, main.logic.rows, main.board.cell, main.board.origin], "profile cannot resize field")
			check(main.get_node("/root/Sfx").skin == music_skin, "profile cannot select music")
		if config[1]:
			await main.start_game("bright", true)
			check(digest(main.logic) == before, "Daily restart deterministic")
		observations.append({"mode":config, "hash":before})
		if DisplayServer.get_name() != "headless":
			main.board._deal_t = 99
			main.board.queue_redraw()
			for i in 3:
				await main.get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image: Image = main.get_viewport().get_texture().get_image()
			var label: String = "daily" if config[1] else config[0]
			check(image.save_png(OS.get_environment("VISUAL_CAPTURE_DIR").path_join("mode_"+label+".png")) == OK, "capture real scene " + label)
		main.go_menu()
		check(main.ambient.skin == "classic" and main.ambient._velvet.material == null, "menu restores original backdrop")
	check(not main.get_node("/root/Progress").COSMETICS_ENABLED, "cosmetics remain disabled")
	return {"checks":checks, "failed":failures.size(), "failures":failures, "boards":observations}
