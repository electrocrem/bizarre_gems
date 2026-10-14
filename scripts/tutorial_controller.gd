extends RefCounted
## Pinned practice sequence; all strikes, scoring, obstacle ticks and deals use the game controller.
const Lessons = preload("res://scripts/tutorial_lessons.gd")
var g
var tut_step := 0
var tut_hits := 0
var tut_waiting := false
var tut_clock_running := false
var tut_feedback_key := ""
var tut_feedback_args := {}
var tut_last_result := {}

func _init(game) -> void:
	g = game

func render() -> void:
	g.practice.present(g, self)

func lesson_id() -> String:
	return Lessons.STEPS[clampi(tut_step, 0, Lessons.STEPS.size() - 1)]

func target() -> Vector2i:
	return Lessons.target(lesson_id(), tut_hits) if not tut_waiting else Vector2i(-1, -1)

func step(i: int) -> void:
	tut_step = i
	tut_hits = 0
	tut_waiting = false
	tut_clock_running = false
	tut_feedback_key = ""
	tut_feedback_args.clear()
	tut_last_result.clear()
	g.keeper.reset()
	var run := Lessons.run_rules(lesson_id())
	g.keeper.configure_combo_rules(not run, run)
	g.keeper.configure_time_rewards(not run)
	g.keeper.time_bonuses = not run
	g._reset_visual_feedback()
	g._game_generation += 1 # Retry/Next invalidate delayed work from the previous exercise.
	var old_delta: Tween = g.hud.time_delta.get_meta("delta_tween") if g.hud.time_delta.has_meta("delta_tween") else null
	if old_delta and old_delta.is_valid(): old_delta.kill()
	g.hud.time_delta.modulate.a = 0.0
	g.score = 0
	g.shown_score = 0.0
	g.play_time = 0.0
	g.strikes_done = 0
	g.cleared = 0
	g.best_strike.clear()
	g.wave = 1
	g.time_left = 1.5 if lesson_id() == "clock" else g.START_TIME
	g.idle = 0.0
	g.dealing = false
	g.board.interactive = g.state == g.State.PLAYING
	g._deal_board()
	g.board.clear_fx()
	g.board.refresh()
	guidance()
	render()
	g.hud.set_combo(g.keeper.combo)
	g._update_hud()

func guidance(force := false) -> void:
	var target := target()
	var guided := target.x >= 0 and (force or tut_step < 3 or lesson_id() == "miss")
	g.tut_hand.visible = guided and g.state == g.State.PLAYING
	g.board.tutorial_focus = target if guided else Vector2i(-1, -1)
	g.board.show_hint(target if guided else Vector2i(-1, -1))
	if guided:
		g._place_hand(target)

func help() -> void:
	if g.mode.kind != "tutorial" or g.state != g.State.PLAYING or tut_waiting or tut_clock_running or g.dealing:
		return
	tut_feedback_key = ""
	render()
	if lesson_id() == "free":
		g.board.show_hint(g.logic.find_move())
	else:
		guidance(true)

func next() -> void:
	if g.mode.kind != "tutorial" or not tut_waiting or g.state != g.State.PLAYING:
		return
	if tut_step == Lessons.STEPS.size() - 1:
		leave(false)
	else:
		step(tut_step + 1)

func retry() -> void:
	if g.mode.kind == "tutorial" and g.state == g.State.PLAYING and not g.dealing:
		step(tut_step)

func leave(skipped: bool) -> void:
	if g.mode.kind != "tutorial":
		return
	if skipped:
		Progress.skip_tutorial()
	g.go_menu()
	g.show_screen(g.modes)

func done(key := "", args := {}) -> void:
	tut_waiting = true
	tut_clock_running = false
	g.board.interactive = false
	g.tut_hand.visible = false
	g.board.tutorial_focus = Vector2i(-1, -1)
	g.board.show_hint(Vector2i(-1, -1))
	feedback(key if key != "" else "lesson_" + lesson_id() + "_result", args)
	if tut_step == Lessons.STEPS.size() - 1:
		Progress.finish_tutorial()
		Sfx.play("level")


func after_strike(result: Dictionary, at: Vector2i) -> void:
	tut_last_result = result.duplicate(true)
	var id := lesson_id()
	if id in ["run", "clear"]:
		if not g.logic.has_any_move():
			g._next_wave(at)
		return
	tut_hits += 1
	var args := {"p": result.awarded_points, "s": result.awarded_time, "n": result.removed,
		"m": result.mult, "base": result.ordinary_points, "double": result.double_hit_points,
		"color": result.color_streak_points, "combo": result.combo}
	if id == "classic":
		g.end_game("stuck")
	elif tut_hits >= Lessons.goal(id):
		if id in ["timeout", "clock"]:
			tut_clock_running = true
			g.board.interactive = false
			tut_feedback_key = ""
			guidance()
			render()
		else:
			done("", args)
	else:
		if id not in ["double", "box"]:
			g._deal_board()
			g.board.refresh()
		guidance()
		var key := "lesson_receipt"
		if id == "box":
			key = "lesson_box_cracked"
		elif id == "special":
			key = "lesson_pair_support" if result.removed == 2 else ("lesson_precise_award" if result.event == "precise" else "lesson_receipt")
		elif id == "chameleon" and tut_hits == g.CHAM_EVERY:
			key = "lesson_chameleon_shift"
		feedback(key, args)

func wave_done(full_clear: bool, seconds: float, points: int) -> void:
	tut_hits += 1
	var args := {"s": int(seconds), "p": points, "w": g.wave - 1}
	if tut_hits >= Lessons.goal(lesson_id()):
		done("lesson_clear_result" if full_clear else "lesson_run_result", args)
	else:
		guidance()
		feedback("lesson_board_receipt", args)
	g._update_hud()


## Practice freezes clocks, except for two short, explicit timeout demonstrations.

func process(delta: float) -> void:
	if g.dealing or tut_waiting:
		return
	if tut_clock_running:
		g.play_time += delta
		if lesson_id() == "clock":
			g.time_left = maxf(0.0, g.time_left - delta)
		if g.keeper.update(g.play_time):
			g._combo_break()
		if lesson_id() == "timeout" and g.keeper.combo == 0:
			done()
		elif lesson_id() == "clock" and g.time_left <= 0.0:
			g.end_game("time")
		g.hud.combo_bar.value = g.keeper.window_left(g.play_time) / g.keeper.combo_window * 100.0
		g._update_hud()
	else:
		g.idle += delta
		if g.idle > g.HINT_AFTER and tut_feedback_key == "":
			feedback("lesson_idle")

func feedback(key: String, args := {}) -> void:
	tut_feedback_key = key
	tut_feedback_args = args
	render()
