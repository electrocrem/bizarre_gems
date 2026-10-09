extends Node
## Player progress: best score and audio settings. Stored locally and, on Yandex Games,
## in the player's cloud data so it follows them across devices.

signal changed

const PATH := "user://save.cfg"

var best := 0          ## classic (desktop) board
var best_compact := 0  ## compact (phone) board
var sound := true
var music := true
var vibration := true
var sound_volume := 1.0
var music_volume := 0.7
var daily_date := ""
var daily_best := 0


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		best = int(cfg.get_value("game", "best", 0))
		best_compact = int(cfg.get_value("game", "best_compact", 0))
		sound = bool(cfg.get_value("audio", "sound", true))
		music = bool(cfg.get_value("audio", "music", true))
		vibration = bool(cfg.get_value("audio", "vibration", true))
		sound_volume = float(cfg.get_value("audio", "sound_volume", 1.0))
		music_volume = float(cfg.get_value("audio", "music_volume", 0.7))
		daily_date = str(cfg.get_value("daily", "date", ""))
		daily_best = int(cfg.get_value("daily", "best", 0))


## Merge cloud data once the SDK is up. The higher best score wins.
func sync_cloud() -> void:
	Yandex.load_data(func(d: Dictionary):
		if d.is_empty():
			return
		var newer := false
		if int(d.get("best", 0)) > best:
			best = int(d.get("best", 0))
			newer = true
		if int(d.get("best_compact", 0)) > best_compact:
			best_compact = int(d.get("best_compact", 0))
			newer = true
		if newer:
			_write_local()
			changed.emit()
		Yandex.save_data(_data()))


## Best score of today's daily board. Returns true on a new daily record.
func submit_daily(score: int, date: String) -> bool:
	if daily_date != date:
		daily_date = date
		daily_best = 0
	if score <= daily_best:
		return false
	daily_best = score
	store()
	return true


func daily_best_for(date: String) -> int:
	return daily_best if daily_date == date else 0


func best_for(mode: String) -> int:
	return best_compact if mode == "compact" else best


## Returns true on a new record for this board mode.
func submit(score: int, mode := "classic") -> bool:
	if score <= best_for(mode):
		return false
	if mode == "compact":
		best_compact = score
	else:
		best = score
	store()
	return true


func store() -> void:
	_write_local()
	Yandex.save_data(_data())
	changed.emit()


func _data() -> Dictionary:
	return {"best": best, "best_compact": best_compact, "sound": sound, "music": music, "vibration": vibration,
		"sound_volume": sound_volume, "music_volume": music_volume, "daily_date": daily_date, "daily_best": daily_best}


func _write_local() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "best", best)
	cfg.set_value("game", "best_compact", best_compact)
	cfg.set_value("audio", "sound", sound)
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "vibration", vibration)
	cfg.set_value("audio", "sound_volume", sound_volume)
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("daily", "date", daily_date)
	cfg.set_value("daily", "best", daily_best)
	cfg.save(PATH)
