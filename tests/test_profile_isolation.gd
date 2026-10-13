extends SceneTree
## Verifies actual engine paths before boot, then real Save/Progress writes and native SDK stubs.

var failed := 0

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failed += 1

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var expected := OS.get_environment("BIZARRE_TEST_USER_DIR").replace("\\", "/").simplify_path()
	check(not expected.is_empty() and OS.get_user_data_dir().simplify_path() == expected, "user:// resolves inside the disposable profile")
	check(ProjectSettings.globalize_path("user://save.cfg").simplify_path() == expected.path_join("save.cfg"), "save.cfg uses the same isolated directory")
	check(FileAccess.get_file_as_string("user://.test-profile") == OS.get_environment("BIZARRE_TEST_TOKEN"), "profile belongs to this invocation")
	check(not OS.has_feature("web") and OS.get_name() == "Windows", "native Windows runner cannot connect the browser SDK")
	# The runner executes this branch in a minimal project without any game autoloads.
	if "--profile-probe" in OS.get_cmdline_user_args():
		print("PROFILE_PROBE_DONE")
		quit(1 if failed else 0)
		return
	if failed:
		quit(1)
		return
	await process_frame
	var save := root.get_node("Save")
	var progress := root.get_node("Progress")
	var yandex := root.get_node("Yandex")
	check(save.best == 0 and progress.crystals == 0 and progress.local_scores.is_empty(), "fresh profile has no player records or progress")
	check(not yandex.available and yandex._yg == null, "Yandex SDK is disconnected")
	check(not ProjectSettings.has_setting("autoload/_mcp_game_helper") and not DirAccess.dir_exists_absolute("res://addons/godot_ai"), "test project has no Godot AI runtime")
	check(save.submit(314, "classic"), "real record writer accepts a test score")
	progress.crystals = 271
	progress.local_scores = {"score": [{"score": 314, "date": "test"}]}
	progress._save()
	var cfg := ConfigFile.new()
	check(cfg.load("user://save.cfg") == OK and cfg.get_value("game", "best", 0) == 314, "record is persisted in the isolated profile")
	cfg = ConfigFile.new()
	check(cfg.load("user://progress.cfg") == OK and cfg.get_value("shop", "crystals", 0) == 271, "progress is persisted in the isolated profile")
	check(cfg.get_value("meta", "local_scores", {}) == progress.local_scores, "local leaderboard is persisted in the isolated profile")
	yandex.save_data({"test": true})
	yandex.submit_score(314)
	var cloud: Dictionary = await _load_stub(yandex)
	check(cloud.is_empty(), "cloud reads stay empty after test submissions")
	print("PROFILE_ISOLATION_DONE")
	quit(1 if failed else 0)

func _load_stub(yandex: Node) -> Dictionary:
	yandex.load_data(func(data: Dictionary): _stub_loaded.emit(data))
	return await _stub_loaded

signal _stub_loaded(data: Dictionary)
