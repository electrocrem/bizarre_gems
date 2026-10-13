extends SceneTree
## CLI entry point for the real upstream scene/handler regression suite.
## Launch only with tools/test_isolated.ps1; it isolates all autoload storage.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	root.get_node("Save").sound = false
	root.get_node("Save").music = false
	root.get_node("Sfx").update_music()
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main.set_process(false)
	for i in 12:
		await process_frame
	var suite = load("res://tests/test_strike_accounting.gd").new()
	var report: Dictionary = suite.run_suite(main)
	print("STRIKE_ACCOUNTING ", JSON.stringify(report))
	var failed := report.has("error") or int(report.get("failed", 0)) > 0
	if failed:
		push_error("FAIL strike accounting regression")
	print("STRIKE_ACCOUNTING_DONE")
	quit(1 if failed else 0)
