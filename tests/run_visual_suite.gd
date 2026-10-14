extends SceneTree
## Run only through tools/test_isolated.ps1; -Render enables actual canvas captures.

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
	var reports := {}
	for name in ["visual_unification", "special_visuals", "bright_palette", "classic_feedback"]:
		var suite = load("res://tests/test_%s.gd" % name).new()
		reports[name] = await suite.run_suite(main)
		print("VISUAL_REPORT ", name, " ", JSON.stringify(reports[name]))
	var failed := false
	for report in reports.values():
		failed = failed or report.has("error") or int(report.get("failed", 0)) > 0
	if failed:
		push_error("FAIL visual suite")
	main.queue_free()
	await process_frame
	print("VISUAL_SUITE_DONE")
	quit(1 if failed else 0)
