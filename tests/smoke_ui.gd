extends SceneTree
## Smoke test of the whole UI: opens every screen, plays a little of every mode, ends games.
## Any script error is printed by Godot; the test fails if one shows up in the log.
## godot --headless --path . --script res://tests/smoke_ui.gd

var main: Node


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	await process_frame  # the autoloads are in place by now; scripts that use them can compile
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	_run()


func _frames(n := 3) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(5)
	for name in main.screens:
		if name == &"collection":
			main._navigate(name)
			await _frames()
			_check(not main.collection.visible, "disabled collection rejects navigation")
			continue
		if name in [&"home", &"modes", &"map", &"pause", &"confirm", &"result", &"level_result"]:
			continue  # full-screen menus and the in-game dialogs are opened below
		main._navigate(name)
		await _frames()
		_check(main.screens[name].visible, "screen %s opens" % name)
		main._navigate(&"back")
		await _frames()
	main._open_map("levels")
	await _frames()
	_check(not main.map.visible and main.modes.visible, "dormant level map is gated")
	main._open_map("puzzle")
	await _frames()
	for id in ["classic", "bright", "zen", "tutorial"]:
		await main.start_game(id)
		await _frames()
		_check(main.state == main.State.PLAYING, id + " starts")
		for i in 8:
			main._auto_move()
			await _frames(1)
		main.pause_game()
		await _frames()
		_check(main.pause.visible, id + " pauses")
		main._resume_play()
		if id != "tutorial":
			main.end_game("time")
			await _frames()
			_check(main.result.visible or main.level_result.visible, id + " shows a result")
	main.start_level(1)
	await _frames()
	main._end_level()
	await _frames()
	_check(main.level_result.visible, "level result")
	main.start_puzzle(1)
	await _frames()
	main._end_puzzle()
	await _frames()
	main._open_settings(main.home)
	await _frames()
	main._navigate(&"back")
	main._open_leaders(main.home)
	await _frames(10)
	main.go_menu()
	await _frames()
	_check(main.home.visible, "back home")
	root.get_node("L").set_language("en")
	await _frames()
	_check(main.home.get_node("%Play").text == "play", "buttons keep their keys")
	_check(tr("play") == "Play", "English text")
	# Finish playback before shutting down the native headless audio server.
	for player in root.get_node("Sfx").get_children():
		if player is AudioStreamPlayer:
			player.stop()
	await create_timer(0.1).timeout
	main.queue_free()
	await process_frame
	print("smoke test done")
	quit()


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		push_error("FAIL " + what)
