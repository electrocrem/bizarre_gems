extends Node
## Sound effects and background music. Effects share a small pool of players.

const SOUNDS := {
	"knock2": preload("res://assets/audio/knock2.wav"),
	"knock3": preload("res://assets/audio/knock3.wav"),
	"knock4": preload("res://assets/audio/knock4.wav"),
	"miss": preload("res://assets/audio/miss.wav"),
	"tick": preload("res://assets/audio/tick.wav"),
	"click": preload("res://assets/audio/click.wav"),
	"start": preload("res://assets/audio/start.wav"),
	"over": preload("res://assets/audio/over.wav"),
	"bonus": preload("res://assets/audio/bonus.wav"),
	"combo_up": preload("res://assets/audio/combo_up.wav"),
	"combo_break": preload("res://assets/audio/combo_break.wav"),
	"precise": preload("res://assets/audio/precise.wav"),
	"perfect": preload("res://assets/audio/perfect.wav"),
}
const MUSIC := preload("res://assets/audio/music.wav")

var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _platform_paused := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	_music.stream = MUSIC
	apply_volumes()
	_music.finished.connect(_music.play)
	add_child(_music)


func play(name: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not Save.sound or _platform_paused:
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = SOUNDS[name]
	p.pitch_scale = pitch
	p.volume_db = volume_db + linear_to_db(maxf(Save.sound_volume, 0.001))
	p.play()


func apply_volumes() -> void:
	_music.volume_db = -9.0 + linear_to_db(maxf(Save.music_volume, 0.001))


func update_music() -> void:
	var want := Save.music and Save.music_volume > 0.01 and not _platform_paused
	if want and not _music.playing:
		_music.play()
	elif not want and _music.playing:
		_music.stop()


## Silence everything while an ad or the platform overlay is on screen.
func set_platform_paused(v: bool) -> void:
	_platform_paused = v
	AudioServer.set_bus_mute(0, v)
	update_music()
