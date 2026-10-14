extends "res://tests/run_flow_ad_fixture.gd"
## All SDK writes/callbacks are receipts in this isolated native process.
var reward_requests: Array[Callable] = []
var fullscreen_requests: Array[Callable] = []
var writes: Array[Dictionary] = []
var submissions: Array[Dictionary] = []
var cloud := {}
var authorized := false

func show_rewarded(done: Callable) -> void:
	reward_requests.append(done)
	super.show_rewarded(done)

func show_fullscreen(done: Callable) -> void:
	fullscreen_requests.append(done)
	super.show_fullscreen(done)

func save_data(data: Dictionary) -> void:
	writes.append(data.duplicate(true))

func load_data(done: Callable) -> void:
	done.call_deferred(cloud.duplicate(true))

func is_authorized() -> bool:
	return authorized

func submit_score(value: int, board := "score") -> void:
	submissions.append({"score": value, "board": board})
