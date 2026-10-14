extends SceneTree
## Stage 3 real-scene regression; launch only through tools/test_isolated.ps1.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	root.get_node("Save").sound = false
	root.get_node("Save").music = false
	root.get_node("Sfx").update_music()
	var main = load("res://scenes/main.tscn").instantiate()
	main.set_script(load("res://tests/bright_run_fixture.gd"))
	root.add_child(main)
	main.set_process(false)
	for i in 12:
		await process_frame
	var suite_script = load("res://tests/test_run_flow.gd")
	if not suite_script.can_instantiate():
		quit(1)
		return
	var suite = suite_script.new()
	var report: Dictionary = await suite.run_suite(main)
	print("RUN_FLOW ", JSON.stringify(report))
	var path := OS.get_environment("RUNTIME_TEST_OUTPUT")
	if not path.is_empty():
		FileAccess.open(path, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	main.queue_free()
	await process_frame
	print("RUN_FLOW_DONE")
	quit(1 if report.has("error") or int(report.get("failed", 0)) > 0 else 0)
