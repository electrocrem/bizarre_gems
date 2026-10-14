extends SceneTree
## Real scene + Save/Progress/SDK regressions; tools/test_isolated.ps1 only.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	if not root.has_node("TestIsolation"):
		quit(1)
		return
	root.get_node("Save").sound = false
	root.get_node("Save").music = false
	root.get_node("Sfx").update_music()
	root.get_node("Yandex").set_script(load("res://tests/progress_sdk_fixture.gd"))
	var main = load("res://scenes/main.tscn").instantiate()
	main.set_script(load("res://tests/bright_run_fixture.gd"))
	root.add_child(main)
	main.set_process(false)
	for i in 8:
		await process_frame
	var suite_script = load("res://tests/test_progress_systems.gd")
	if not suite_script.can_instantiate():
		quit(1)
		return
	var report: Dictionary = await suite_script.new().run_suite(main)
	print("PROGRESS_SUITE ", JSON.stringify(report))
	var path := OS.get_environment("RUNTIME_TEST_OUTPUT")
	if not path.is_empty():
		FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	if report.has("error") or int(report.get("failed", 0)) > 0:
		push_error("FAIL progress suite")
	main.queue_free()
	await process_frame
	print("PROGRESS_SUITE_DONE")
	quit(1 if report.has("error") or int(report.get("failed", 0)) > 0 else 0)
