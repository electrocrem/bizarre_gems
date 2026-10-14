extends RefCounted
## Web Dummy cannot exercise the physical Sample backend/autoplay. Check real resources,
## Production player contracts here; CPU decoding/live mixer are checked on Windows.
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func run_suite(main) -> Dictionary:
	var sfx = main.get_node("/root/Sfx")
	var save = main.get_node("/root/Save")
	check(AudioServer.get_driver_name() == "Dummy", "actual Web Dummy driver")
	for stream in [sfx.MUSIC,sfx.MUSIC_BRIGHT]:
		check(stream is AudioStreamOggVorbis and stream.loop and stream.loop_offset == 0.0, "original OGG loop metadata")
		check(stream.get_length() > 76.0,"original Web OGG duration")
	save.music = true
	save.music_volume = 0.7
	sfx.set_platform_paused(false)
	sfx.apply_volumes()
	for config in [["classic",false],["bright",false],["bright",true]]:
		await main.start_game(config[0],config[1])
		var expected = sfx.MUSIC if config[0] == "classic" else sfx.MUSIC_BRIGHT
		check(sfx._music.stream == expected and sfx._music.playing,"Web mode selects original track "+str(config))
		var instance: int = sfx._music.get_instance_id()
		var playback = sfx._music.get_stream_playback()
		main.pause_game()
		main._resume_play()
		await main.start_game(config[0],config[1])
		check(sfx._music.get_instance_id() == instance and sfx._music.get_stream_playback() == playback,"Web pause/resume/restart retains single player")
		var count := 0
		for player in sfx.get_children():
			if player is AudioStreamPlayer and player.stream in [sfx.MUSIC,sfx.MUSIC_BRIGHT]: count += 1
		check(count == 1,"Web only one background player")
		save.music_volume = 0.25
		sfx.apply_volumes()
		check(is_equal_approx(sfx._music.volume_db,-9.0+linear_to_db(.25)),"Web production volume curve")
		save.music = false
		sfx.update_music()
		check(not sfx._music.playing,"Web music toggle")
		save.music = true
		sfx.update_music()
		sfx.set_platform_paused(true)
		check(not sfx._music.playing and AudioServer.is_bus_mute(0),"Web platform pause")
		sfx.set_platform_paused(false)
		check(sfx._music.playing and not AudioServer.is_bus_mute(0),"Web platform resume")
	main.go_menu()
	return {"checks":checks,"failed":failures.size(),"failures":failures,"audio_driver":AudioServer.get_driver_name(),"mix_rate":AudioServer.get_mix_rate(),"manual_required":"Web Sample backend, live mixer and autoplay with real audio","not_exercised":["Web PCM decoding/mixer under Dummy","Web audible loop/autoplay"]}
