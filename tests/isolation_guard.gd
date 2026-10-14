extends Node
## First autoload in the disposable test project only. Never registered in production.

func _enter_tree() -> void:
	if AudioServer.get_driver_name() != "Dummy":
		push_error("TEST ISOLATION: actual audio driver must be Dummy")
		get_tree().quit(90)
		return
	print("ISOLATED_AUDIO_DUMMY")
	var expected := OS.get_environment("BIZARRE_TEST_USER_DIR").replace("\\", "/").simplify_path()
	var project := OS.get_environment("BIZARRE_TEST_PROJECT").replace("\\", "/").simplify_path()
	var actual := OS.get_user_data_dir().replace("\\", "/").simplify_path()
	var source := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	if expected.is_empty() or project.is_empty() or actual != expected or source != project:
		push_error("TEST ISOLATION: unexpected project or user directory")
		get_tree().quit(90)
		return
	if OS.has_feature("web") or OS.get_name() != "Windows":
		push_error("TEST ISOLATION: this runner requires native Windows SDK stubs")
		get_tree().quit(90)
		return
	if FileAccess.get_file_as_string("user://.test-profile") != OS.get_environment("BIZARRE_TEST_TOKEN"):
		push_error("TEST ISOLATION: missing profile ownership marker")
		get_tree().quit(90)
		return
	print("ISOLATED_PROFILE_READY ", actual)
