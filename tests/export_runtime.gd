extends Node
## Exercises the real exported main scene, production SDK bridge and imported resources.
## Enabled only in tools/test_exports.ps1 disposable projects.
var checks := 0
var failures: Array[String] = []
var reports := []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func settle(count := 20) -> void:
	for i in count: await get_tree().process_frame
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	await settle(120)
	var main = get_tree().current_scene
	check(main != null and main.state == main.State.MENU and main.home.visible, "real exported main scene reaches menu")
	if main == null: return
	main.set_process(false)
	var save = get_node("/root/Save")
	var progress = get_node("/root/Progress")
	var reload_run := "--verify-reload" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		reload_run = bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('reload')"))
		check(get_node("/root/Yandex").available, "exported Yandex wrapper connected to local mock")
	if reload_run:
		check(save.best == 123456 and save.best_bright == 234567, "records persist across real process/page restart")
		check(save.music == false and is_equal_approx(save.music_volume, 0.25), "audio preferences persist")
		check(progress.tutorial and not progress.needs_tutorial(), "completed tutorial persists")
		check(progress.crystals == 321, "currency persists")
	else:
		for id in ["classic", "bright"]:
			await main.start_game(id)
			await settle()
			check(main.mode.id == id and main.state == main.State.PLAYING and main.logic.gems_left() > 0, "export starts " + id)
			var at: Vector2i = main.logic.find_move()
			var gems: int = main.logic.gems_left()
			main._on_slot(at)
			check(main.logic.gems_left() < gems and main.score > 0, "real exported strike " + id)
			main.pause_game()
			check(main.state == main.State.PAUSED, "export pauses " + id)
			main._resume_play()
			main.go_menu()
		await main.start_game("bright", true)
		check(main.daily and main.daily_run_date == Time.get_date_string_from_system(true), "exported Daily pins UTC date")
		main.go_menu()
		reports.append(await load("res://tests/test_tutorial.gd").new().run_suite(main))
		reports.append(await load("res://tests/test_web_music.gd" if OS.has_feature("web") else "res://tests/test_music.gd").new().run_suite(main))
		for report in reports:
			check(not report.has("error") and int(report.get("failed",0)) == 0, "exported tutorial/music suite " + JSON.stringify(report))
		save.best = 123456
		save.best_bright = 234567
		save.music = false
		save.music_volume = 0.25
		progress.tutorial = true
		progress.tutorial_skipped = false
		progress.crystals = 321
		save.store()
		progress._save()
		get_node("/root/Sfx").update_music()
	main.go_menu()
	await settle()
	var result := {"checks":checks,"failures":failures,"failed":failures.size(),"reports":reports,"reload":reload_run,"platform":OS.get_name(),"audio_driver":AudioServer.get_driver_name()}
	print("EXPORT_RUNTIME ", JSON.stringify(result))
	print("EXPORT_RUNTIME_DONE")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.__bizarreResult = " + JSON.stringify(result))
		# Keep the real scene running for canvas/input/resize/browser checks.
		var callback := JavaScriptBridge.create_callback(func(a):
			_command(str(a[0]), main))
		get_node("/root/Yandex")._keep.append(callback)
		JavaScriptBridge.get_interface("window").__bizarreCommand = callback
	else:
		for player in get_node("/root/Sfx").get_children():
			if player is AudioStreamPlayer: player.stop()
		await get_tree().create_timer(0.1).timeout
		get_tree().quit(1 if failures.size() else 0)
func _command(command: String, main) -> void:
	if command == "tutorial": await main.start_game("tutorial")
	elif command == "daily": await main.start_game("bright",true)
	elif command in ["classic","bright"]: await main.start_game(command)
	elif command == "menu": main.go_menu()
	await settle()
	var target: Vector2i = main._tutorial_target() if main.mode.kind == "tutorial" else main.logic.find_move()
	var point: Vector2 = main.board.get_global_transform() * (main.board.origin + (Vector2(target) + Vector2.ONE * 0.5) * main.board.cell)
	JavaScriptBridge.eval("window.__bizarreState = " + JSON.stringify({"command":command,"mode":main.mode.id,"daily":main.daily,"dims":[main.logic.cols,main.logic.rows],"board":[main.board.size.x,main.board.size.y],"stats":[main.hud.get_node("Stats").size.x,main.hud.get_node("Stats").size.y],"safe":str(main.safe),"state":main.state,"hits":main.tut_hits,"target":[point.x,point.y],"viewport":[main.get_viewport_rect().size.x,main.get_viewport_rect().size.y]}))
