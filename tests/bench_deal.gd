extends SceneTree
## Timing of tuned solvable deals per level.  godot --headless --path . --script res://tests/bench_deal.gd

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for lvn in [1, 4, 7, 10, 14]:
		var lv := BoardLogic.bright_level(lvn)
		var d := BoardLogic.best_dims(Vector2(360, 640), lv.slots)
		var b := BoardLogic.new()
		var t0 := Time.get_ticks_msec()
		var m := b.setup_tuned(d.x, d.y, rng, 2, lv.kinds, lv.per_kind, lv.min_moves, lv.max_moves, lv.tries, true, lv.jokers, lv.boxes)
		print("level %2d  %dx%d  %4d ms  moves %d" % [lvn, d.x, d.y, Time.get_ticks_msec() - t0, m])
	var rb := BoardLogic.new()
	var rd := BoardLogic.best_dims(Vector2(360, 640), 200)
	var t1 := Time.get_ticks_msec()
	var rm := rb.setup_tuned(rd.x, rd.y, rng, 6, 6, 28, 4, 999, 30, true, 0.1, 5)
	var ch := rb.add_chains(rng, 3)
	print("run      %dx%d  %4d ms  moves %d  gems %d" % [rd.x, rd.y, Time.get_ticks_msec() - t1, rm, rb.gems_left()])
	quit()
