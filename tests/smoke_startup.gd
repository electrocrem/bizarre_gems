extends SceneTree
## Run the real main scene, then release audio playback before the headless engine exits.
## Launch only through tools/test_isolated.ps1.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for i in 120:
		await process_frame
	if main.state != main.State.MENU or not main.home.visible:
		push_error("FAIL startup did not reach the home screen")
		quit(1)
		return
	for player in root.get_node("Sfx").get_children():
		if player is AudioStreamPlayer:
			player.stop()
	# Let the audio server release playback handles before quitting the process.
	await create_timer(0.1).timeout
	main.queue_free()
	await process_frame
	print("STARTUP_SMOKE_DONE")
	quit()
