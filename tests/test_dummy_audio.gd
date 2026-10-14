extends SceneTree
## The real Sfx event/music paths still execute, with physical output excluded by the actual driver.
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	await process_frame
	if not root.has_node("TestIsolation") or AudioServer.get_driver_name() != "Dummy":
		push_error("FAIL Dummy audio and isolated profile required")
		quit(1)
		return
	var sfx = root.get_node("Sfx")
	var save = root.get_node("Save")
	var settings := [save.sound,save.music,save.sound_volume,save.music_volume]
	check(save.sound and save.music,"fresh isolated profile enables sound/music event logic")
	check(AudioServer.get_driver_name() == "Dummy","actual audio driver Dummy")
	var path: String = ProjectSettings.globalize_path(save.PATH)
	var before := FileAccess.get_sha256(path) if FileAccess.file_exists(path) else ""
	for skin in ["classic","bright"]:
		sfx.set_skin(skin)
		for name in sfx.SOUNDS:
			var index: int = sfx._next
			sfx.play(name)
			var player: AudioStreamPlayer = sfx._pool[index]
			var stream = sfx.BRIGHT[name] if skin == "bright" and sfx.BRIGHT.has(name) else sfx.SOUNDS[name]
			check(player.stream == stream and player.playing,"real sound event selects and plays "+skin+name)
			check(sfx._next == (index+1)%sfx._pool.size(),"real pool advances "+skin+name)
		sfx.update_music()
		check(sfx._music.stream == (sfx.MUSIC_BRIGHT if skin == "bright" else sfx.MUSIC) and sfx._music.playing,"real mode music plays "+skin)
	sfx.set_platform_paused(true)
	var next: int = sfx._next
	sfx.play("precise")
	check(not sfx._music.playing and sfx._next == next,"platform pause still gates events/music")
	sfx.set_platform_paused(false)
	check(sfx._music.playing,"platform resume still restarts music")
	check([save.sound,save.music,save.sound_volume,save.music_volume] == settings,"audio settings unchanged")
	check((FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "") == before,"saved audio settings unchanged")
	check(not sfx._music.finished.is_connected(sfx._music.play),"native OGG loops have no finished restart callback")
	for player in sfx.get_children():
		if player is AudioStreamPlayer:
			player.stop()
			player.stream = null
	for i in 30: await process_frame # Drain the rapid pool replacements through the Dummy mixer.
	print("DUMMY_AUDIO ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	if not failures.is_empty(): push_error("FAIL Dummy audio events")
	print("DUMMY_AUDIO_DONE")
	quit(0 if failures.is_empty() else 1)
