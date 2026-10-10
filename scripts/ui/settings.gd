extends Screen
## Sound, music and vibration. Changes are saved at once.


func _ready() -> void:
	%Vibration.visible = Haptics.available() or OS.is_debug_build()
	%ScaleInfo.visible = OS.is_debug_build()


## `info`: the debug line with the window and UI scale (debug builds only).
func open(info: String) -> void:
	%Sound.set_pressed_no_signal(Save.sound)
	%Music.set_pressed_no_signal(Save.music)
	%Vibration.set_pressed_no_signal(Save.vibration)
	%SoundVolume.set_value_no_signal(Save.sound_volume)
	%MusicVolume.set_value_no_signal(Save.music_volume)
	%ScaleInfo.text = info


func _on_sound_toggled(on: bool) -> void:
	Save.sound = on
	Save.store()
	click()


func _on_sound_volume_changed(x: float) -> void:
	Save.sound_volume = x


func _on_sound_volume_drag_ended(_changed: bool) -> void:
	Save.store()
	Sfx.play("knock3")


func _on_music_toggled(on: bool) -> void:
	Save.music = on
	Save.store()
	click()
	Sfx.update_music()


func _on_music_volume_changed(x: float) -> void:
	Save.music_volume = x
	Sfx.apply_volumes()
	Sfx.update_music()


func _on_music_volume_drag_ended(_changed: bool) -> void:
	Save.store()


func _on_vibration_toggled(on: bool) -> void:
	Save.vibration = on
	Save.store()
	Haptics.buzz("test")


func _on_close_pressed() -> void:
	click()
	navigate.emit(&"back")
