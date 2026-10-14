extends SceneTree
## Imported authored resources and real music players, isolated profiles and Dummy only.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	await process_frame
	if not root.has_node("TestIsolation") or AudioServer.get_driver_name() != "Dummy": quit(1); return
	root.get_node("Yandex").set_script(load("res://tests/progress_sdk_fixture.gd"))
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.set_process(false)
	for i in 12: await process_frame
	var report: Dictionary = await load("res://tests/test_music.gd").new().run_suite(main)
	print("MUSIC_SUITE ",JSON.stringify(report))
	var failed: bool = report.has("error") or int(report.get("failed",0)) > 0
	main.queue_free()
	var sfx = root.get_node("Sfx")
	for player in sfx.get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
	await create_timer(.2).timeout
	if failed: push_error("FAIL music suite")
	print("MEDIA_SUITE_DONE")
	quit(1 if failed else 0)
