extends RefCounted
## Integration regressions for the real Main._on_slot handler.
## Run only through tools/test_isolated.ps1 with tests/run_strike_accounting.gd.
## Adapted from refinement@bcee016 to scene-based navigation and the current keeper.
## Fixtures leave another legal move, so no result screen, reward or save is triggered.
## Progress reports are restored synchronously before the next process frame.

var checks := 0
var failures: Array[String] = []
var results: Array = []


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)


func run_suite(main) -> Dictionary:
	checks = 0
	failures.clear()
	results.clear()
	if main.state != main.State.MENU:
		return {"error": "Run this suite from the main menu."}
	var progress = main.get_node("/root/Progress")
	if progress.task_date != Time.get_date_string_from_system(true):
		return {"error": "Restart the project after the UTC date changes before running this suite."}
	var progress_before := {
		"life": progress.life.duplicate(true), "tasks": progress.tasks.duplicate(true),
		"_dirty": progress._dirty, "_since": progress._since,
	}
	var main_before := {}
	for key in ["logic", "keeper", "mode", "state", "time_left", "score", "shown_score",
			"cleared", "play_time", "strikes_done", "strikes", "strikes_max", "goal_kind", "dealing", "idle", "best_strike"]:
		main_before[key] = main.get(key)
	main._use_mode("classic")
	_case(main, progress, "both partners in cross", "direct", 0, 0, 2, 2, 0.0)
	_case(main, progress, "partner outside cross", "outside", 0, 0, 3, 6, 1.0)
	_case(main, progress, "box cracks but stays", "box", 0, 0, 1, 2, 0.0)
	_case(main, progress, "outside partner at x2", "outside", 1, 0, 3, 10, 1.0 + ScoreKeeper.TIER_TIME)
	_case(main, progress, "direct pair with shining bonus", "direct", 0, 1, 2, 7, 2.0)
	_case(main, progress, "outside linked box only cracks", "chained_box", 0, 0, 2, 2, 0.0)
	_case(main, progress, "direct linked box only cracks", "linked_box", 0, 0, 1, 2, 0.0)
	_case(main, progress, "two boxes are a successful hit", "two_boxes", 0, 0, 0, 2, 0.0)
	_repeat_boxes(main, progress)
	_case(main, progress, "transposed outside partner", "outside", 0, 0, 3, 6, 1.0, true)
	_ignored_input(main, progress)
	# Exercise upstream mode branches without integrating their stage 2/3 rules.
	main._use_mode("bright")
	_case(main, progress, "bright outside partner", "outside", 0, 0, 3, 6, 0.0)
	_case(main, progress, "bright linked box only cracks", "linked_box", 0, 0, 1, 2, 0.0)
	main._use_mode("levels")
	_case(main, progress, "level outside partner", "outside", 0, 0, 3, 6, 1.0)
	main._use_mode("zen")
	_case(main, progress, "zen outside partner", "outside", 0, 0, 3, 6, 0.0)
	main._use_mode("puzzle")
	_case(main, progress, "puzzle linked box only cracks", "linked_box", 0, 0, 1, 2, 0.0)
	for key in progress_before:
		progress.set(key, progress_before[key])
	for key in main_before:
		main.set(key, main_before[key])
	main.board.logic = main.logic
	main.board.clear_fx()
	main._use_mode(str(main.mode.id))
	main.board.refresh()
	main.show_screen(main.home)
	main._update_hud()
	return {"checks": checks, "failed": failures.size(), "failures": failures, "cases": results}


func _case(main, progress, label: String, kind: String, prior_hits: int, shining: int,
		want_removed: int, want_points: int, want_time: float, transpose := false) -> void:
	var b := BoardLogic.new()
	var rows := ["1.1..", ".....", "1.2.2"] if kind in ["outside", "chained_box"] else ["1.1..", ".....", "2.2.."]
	var cells := PackedInt32Array()
	for row in rows:
		for ch in row:
			cells.append(-1 if ch == "." else int(ch))
	b.load_cells(5, 3, cells)
	if kind in ["box", "linked_box", "two_boxes"]:
		b.hp[0] = 2
	if kind == "two_boxes":
		b.hp[2] = 2
	if kind != "box" and kind != "two_boxes":
		var partner := 10 if kind in ["outside", "chained_box"] else 2
		b.chain[0] = partner
		b.chain[partner] = 0
	if kind == "chained_box":
		b.hp[10] = 2
	b.shine[2] = shining
	if transpose:
		b.transpose()
	main.logic = b
	main.board.logic = b
	main.board.clear_fx()
	main.board.refresh()
	main.keeper = ScoreKeeper.new()
	# Stage 1 preserves upstream time/combo rules; balance is integrated in stage 2.
	main.keeper.time_bonuses = main.mode.kind == "classic"
	for i in prior_hits:
		main.keeper.hit(2, float(i))
	main.score = main.keeper.score
	main.cleared = 0
	main.best_strike = {}
	main.time_left = 120.0
	main.play_time = float(prior_hits)
	main.strikes_done = 0
	main.strikes = 20
	main.strikes_max = 20
	main.goal_kind = -1
	main.dealing = false
	main.state = main.State.PLAYING
	var before_gems := b.gems_left()
	var before_score = main.score
	var before_report := int(progress.life.get("gems", 0))
	var slot := Vector2i(0, 1) if transpose else Vector2i(1, 0)
	var cells_before := b.cells.duplicate()
	main._on_slot(slot)
	var removed := before_gems - b.gems_left()
	var points = main.score - before_score
	var seconds = main.time_left - 120.0
	_check(removed == want_removed, label + ": actual unique removals")
	_check(main.cleared == removed, label + ": cleared equals actual removals")
	_check(int(progress.life.get("gems", 0)) - before_report == removed, label + ": reported gems equal actual removals")
	_check(int(main.best_strike.get("n", -1)) == removed, label + ": best strike counts only destroyed gems")
	_check(points == want_points and main.score == main.keeper.score, label + ": score and chain bonus")
	_check(is_equal_approx(seconds, want_time), label + ": time bonus")
	_check(main.keeper.combo == prior_hits + 1 and main.strikes_done == 1, label + ": successful hits remain distinct from removed gems")
	var parts: Array = main.best_strike.get("parts", [])
	var parts_valid := true
	var seen := {}
	for part in parts:
		var cell: Vector2i = slot + part[0]
		parts_valid = parts_valid and b.kind_at(cell) == BoardLogic.EMPTY and not seen.has(cell)
		parts_valid = parts_valid and part[1] == cells_before[cell.y * b.cols + cell.x]
		seen[cell] = true
	var expected_parts := 1 if kind in ["box", "linked_box"] else (0 if kind == "two_boxes" else 2)
	_check(parts_valid and parts.size() == expected_parts, label + ": replay contains unique destroyed cross gems with original colors")
	if main.mode.skin == "classic":
		_check(main.board._flyers.size() == removed, label + ": only destroyed gems get removal effects")
	_check(main.state == main.State.PLAYING and b.has_any_move(), label + ": no completion or rewards")
	if kind in ["box", "linked_box", "two_boxes"]:
		_check(b.kind_at(Vector2i(0, 0)) == 1 and b.hp[0] == 1, label + ": box stays cracked")
	if kind == "chained_box":
		_check(b.kind_at(Vector2i(0, 2)) == 1 and b.hp[10] == 1, label + ": outside box stays cracked with no extra reward")
	results.append({"case": label, "removed": removed, "cleared": main.cleared,
		"points": points, "time": seconds, "best_strike_gems": main.best_strike.get("n", -1)})
	main.state = main.State.MENU


func _repeat_boxes(main, progress) -> void:
	var before_report := int(progress.life.get("gems", 0))
	main.state = main.State.PLAYING
	main._on_slot(Vector2i(1, 0))
	_check(main.cleared == 2 and main.logic.gems_left() == 2, "second hit destroys the two previously cracked boxes once")
	_check(int(progress.life.get("gems", 0)) - before_report == 2, "second hit reports only its actual removals")
	_check(main.keeper.combo == 2 and main.strikes_done == 2, "box damage and destruction are separate successful strikes")
	_check(main.best_strike.n == 2 and main.best_strike.parts.size() == 2, "second hit replaces empty-removal replay with destroyed boxes")
	_check(main.score == 6 and main.keeper.score == main.score, "second hit retains current upstream x2 scoring")
	_check(is_equal_approx(main.time_left, 120.0 + ScoreKeeper.TIER_TIME), "second hit retains current upstream tier time")
	_check(main.state == main.State.PLAYING and main.logic.has_any_move(), "box repeat leaves a legal move and no result rewards")
	main.state = main.State.MENU


func _ignored_input(main, progress) -> void:
	main.state = main.State.PLAYING
	var cells_before: PackedInt32Array = main.logic.cells.duplicate()
	var score_before: int = main.score
	var cleared_before: int = main.cleared
	var strikes_before: int = main.strikes_done
	var best_before: Dictionary = main.best_strike.duplicate(true)
	var report_before := int(progress.life.get("gems", 0))
	for slot in [Vector2i(-1, 0), Vector2i(main.logic.cols, 0), Vector2i(0, main.logic.rows), Vector2i(2, 2)]:
		main._on_slot(slot)
	_check(main.logic.cells == cells_before and main.score == score_before and main.cleared == cleared_before,
		"out-of-bounds and occupied slots do not remove gems or award points")
	_check(main.strikes_done == strikes_before and main.best_strike == best_before
		and int(progress.life.get("gems", 0)) == report_before, "ignored slots do not alter hit, replay or progress statistics")
	# A genuine miss keeps the successful strike/removal totals but breaks the combo.
	var time_before: float = main.time_left
	main._on_slot(Vector2i(1, 1))
	_check(main.keeper.combo == 0 and is_equal_approx(main.time_left, time_before - 1.0), "genuine miss keeps upstream penalty and combo reset")
	_check(main.cleared == cleared_before and main.strikes_done == strikes_before
		and main.best_strike == best_before and int(progress.life.get("gems", 0)) == report_before,
		"miss does not increment removals, successful strikes, replay or progress")
	main.state = main.State.MENU
