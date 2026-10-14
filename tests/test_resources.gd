extends SceneTree
## Clean-import resource load and pinned source integrity; isolated Dummy only.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	await process_frame
	var checks := 0
	var failures := []
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/media_manifest.json"))
	for path in manifest:
		checks += 1
		if FileAccess.get_sha256("res://"+path) != manifest[path].sha256: failures.append(path+" pinned SHA256")
		checks += 1
		if ResourceLoader.load("res://"+path) == null: failures.append(path+" imported resource")
	checks += 1
	if ProjectSettings.get_setting("application/config/icon") != "res://icon.png" or not load("res://icon.png") is Texture2D: failures.append("project icon reference")
	checks += 1
	if not root.has_node("TestIsolation") or AudioServer.get_driver_name() != "Dummy": failures.append("isolation/Dummy required")
	print("RESOURCES_SUITE ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	if not failures.is_empty(): push_error("FAIL resources suite")
	print("RESOURCES_SUITE_DONE")
	quit(0 if failures.is_empty() else 1)
