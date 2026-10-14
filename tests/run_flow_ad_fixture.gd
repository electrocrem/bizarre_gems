extends "res://tests/rewarded_ad_fixture.gd"
## Fake SDK callbacks and Share receipt; no calls to external services.
var pending_fullscreen: Callable
var shared_payload := ""
var shared_text := ""

func show_fullscreen(done: Callable) -> void:
	pending_fullscreen = done

func resolve_fullscreen() -> void:
	var done := pending_fullscreen
	pending_fullscreen = Callable()
	if done.is_valid():
		done.call_deferred(true)

func share(payload: String, text: String, done: Callable) -> void:
	shared_payload = payload
	shared_text = text
	done.call_deferred("copied")
