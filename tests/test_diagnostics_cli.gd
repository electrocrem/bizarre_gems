extends SceneTree
## Each explicit CLI selection starts in a fresh isolated process with Dummy audio.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	await process_frame
	root.get_node("Yandex").set_script(load("res://tests/progress_sdk_fixture.gd"))
	root.get_node("Yandex").is_ready = true
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	for i in 24: await process_frame
	while main._run_starting: await process_frame
	var exp = main.ComboExperiment
	var ok: bool = root.has_node("TestIsolation") and AudioServer.get_driver_name() == "Dummy" and exp.is_read_only() and main._ab_active and main.state == main.State.PLAYING
	if exp.target_mode == "bright": ok = ok and main.keeper.combo_window == 3.5 and main.keeper.timed_special and not main.keeper.time_bonuses
	else: ok = ok and main.keeper.combo_window == exp.window_seconds() and main.keeper.timed_special == (exp.special_rules == "timed")
	main.go_menu()
	ok = ok and exp.is_read_only() and main.last_combo_report.end_reason == "abandoned"
	print("DIAGNOSTICS_CLI ",JSON.stringify({"ok":ok,"variant":exp.variant,"mode":exp.target_mode,"rules":exp.special_rules,"seed":exp.board_seed}))
	main.queue_free()
	for player in root.get_node("Sfx").get_children():
		if player is AudioStreamPlayer: player.stop(); player.stream = null
	await create_timer(.2).timeout
	if not ok: push_error("FAIL diagnostics CLI")
	print("DIAGNOSTICS_CLI_DONE")
	quit(0 if ok else 1)
