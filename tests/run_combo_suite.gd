extends SceneTree
## Native rules + real scene checks. Launch only through tools/test_isolated.ps1.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	root.get_node("Save").sound = false
	root.get_node("Save").music = false
	root.get_node("Sfx").update_music()
	var reports := {}
	var special = load("res://tests/test_special_combo.gd").new()
	reports.special = special.run_rules()
	for config in [["bonuses", "test_classic_bonus_combos", "rules"],
			["balance", "test_classic_balance", "_rules"], ["shared", "test_unified_combos", "rules"]]:
		var suite = load("res://tests/%s.gd" % config[1]).new()
		suite.call(config[2])
		reports[config[0]] = {"checks": suite.checks, "failed": suite.failures.size(), "failures": suite.failures}
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main.set_process(false)
	for i in 12:
		await process_frame
	var runtime = load("res://tests/test_combo_runtime.gd").new()
	reports.runtime = await runtime.run_suite(main)
	print("COMBO_SUITE ", JSON.stringify(reports))
	var failed := false
	for report in reports.values():
		failed = failed or report.has("error") or int(report.get("failed", 0)) > 0
	if failed:
		push_error("FAIL combo suite")
	main.queue_free()
	await process_frame
	print("COMBO_SUITE_DONE")
	quit(1 if failed else 0)
