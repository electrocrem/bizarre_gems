extends SceneTree
## Production sequence, real scene and isolated SDK. Also checks menus/localisation/layout.
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
	main.set_script(load("res://tests/hud_platform_fixture.gd"))
	root.add_child(main)
	main.set_process(false)
	for i in 8: await process_frame
	var reports := []
	if "--menus-only" not in OS.get_cmdline_user_args():
		reports.append(await load("res://tests/test_tutorial.gd").new().run_suite(main))
		print("TUTORIAL_FLOW ",JSON.stringify(reports[-1]))
	reports.append(await load("res://tests/test_menu_tutorial_ui.gd").new().run_suite(main))
	var failed := 0
	for report in reports:
		print("TUTORIAL_SUITE ",JSON.stringify(report))
		failed += int(report.get("failed",0)) + (1 if report.has("error") else 0)
	main.go_menu()
	main.queue_free()
	await process_frame
	if failed > 0: push_error("FAIL tutorial suite")
	print("TUTORIAL_SUITE_DONE")
	quit(1 if failed > 0 else 0)
