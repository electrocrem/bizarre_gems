extends Node
## First autoload in isolated exported fixtures only; never in production project.godot.
func _enter_tree() -> void:
	if AudioServer.get_driver_name() != "Dummy":
		push_error("EXPORT ISOLATION: actual audio driver must be Dummy")
		get_tree().quit(90)
		return
	var token: String = ProjectSettings.get_setting("verification/token", "")
	var owned := false
	if OS.has_feature("web"):
		owned = bool(JavaScriptBridge.eval("location.hostname === '127.0.0.1' && window.__bizarreVerification === " + JSON.stringify(token) + " && window.__mockSdk === true"))
	else:
		var expected := OS.get_environment("BIZARRE_TEST_USER_DIR").replace("\\", "/").simplify_path()
		owned = not expected.is_empty() and OS.get_user_data_dir().replace("\\", "/").simplify_path() == expected and FileAccess.get_file_as_string("user://.test-profile") == token and OS.get_environment("BIZARRE_TEST_TOKEN") == token
	if token.is_empty() or not owned:
		push_error("EXPORT ISOLATION: missing isolated profile/origin ownership")
		get_tree().quit(90)
		return
	print("ISOLATED_AUDIO_DUMMY")
	print("ISOLATED_PROFILE_READY ", OS.get_user_data_dir())
