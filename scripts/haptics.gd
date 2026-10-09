extends Node
## Light vibration on phones. Pulses are short and weak on purpose.

const PATTERNS := {
	"miss": [28, 0.25],
	"tier": [18, 0.2],
	"precise": [45, 0.35],
	"perfect": [80, 0.5],
	"over": [60, 0.3],
	"test": [40, 0.35],
}
const MIN_GAP_MS := 80

var _last := -MIN_GAP_MS


func available() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web")


func buzz(kind: String) -> void:
	if not Save.vibration or not available():
		return
	var now := Time.get_ticks_msec()
	if now - _last < MIN_GAP_MS:
		return
	_last = now
	var p: Array = PATTERNS.get(kind, [20, 0.2])
	Input.vibrate_handheld(int(p[0]), float(p[1]))
