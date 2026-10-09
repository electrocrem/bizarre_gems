extends SceneTree
## Rule tests. Run:  godot --headless --path . --script res://tests/test_logic.gd

var failed := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failed += 1
		printerr("  FAIL ", what)


func board_from(rows: Array[String]) -> BoardLogic:
	# '.' is an empty slot, digits are gem kinds
	var b := BoardLogic.new()
	var cells := PackedInt32Array()
	for r in rows:
		for ch in r:
			cells.append(-1 if ch == "." else int(ch))
	b.load_cells(rows[0].length(), rows.size(), cells)
	return b


func _init() -> void:
	print("BoardLogic")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	var b := BoardLogic.new()
	b.setup(BoardLogic.LONG, BoardLogic.SHORT, rng)
	var counts := {}
	for k in b.cells:
		counts[k] = counts.get(k, 0) + 1
	check(b.cells.size() == 345, "board has 23x15 slots")
	check(counts.get(-1, 0) == 75, "75 empty slots")
	var all27 := true
	for k in BoardLogic.KINDS:
		all27 = all27 and counts.get(k, 0) == 27
	check(all27, "each of 10 kinds appears 27 times")

	# pair on a row, gap skipping
	var t := board_from(["1..1", "....", "2..3"])
	var m := t.matches_from(Vector2i(1, 0))
	check(m.size() == 2 and Vector2i(0, 0) in m and Vector2i(3, 0) in m, "left/right pair is knocked out")
	check(t.matches_from(Vector2i(1, 1)).is_empty(), "no pair from a middle slot is a miss")

	# first gem only: the 1 behind the 2 must not count
	var u := board_from(["1", ".", "2", "1", ".", "1"])
	var mu := u.matches_from(Vector2i(0, 1))
	check(mu.is_empty(), "only the first gem in each direction counts")
	var mu2 := u.matches_from(Vector2i(0, 4))
	check(mu2.size() == 2, "vertical pair through an empty slot")

	# cross with three of a kind and two pairs
	var x := board_from([".5.", "5.5", ".7."])
	check(x.matches_from(Vector2i(1, 1)).size() == 3, "three of a kind is knocked out together")
	var y := board_from([".5.", "6.6", ".5."])
	check(y.matches_from(Vector2i(1, 1)).size() == 4, "two different pairs both go")

	check(BoardLogic.points_for(2) == 2 and BoardLogic.points_for(3) == 4 and BoardLogic.points_for(4) == 6, "scoring 2/4/6")
	check(BoardLogic.bonus_for(2) == 0 and BoardLogic.bonus_for(3) == 1 and BoardLogic.bonus_for(4) == 2, "time bonus 0/1/2")

	# transpose keeps every move
	var before := 0
	for yy in b.rows:
		for xx in b.cols:
			if b.is_empty(Vector2i(xx, yy)):
				before += b.matches_from(Vector2i(xx, yy)).size()
	b.transpose()
	var after := 0
	for yy in b.rows:
		for xx in b.cols:
			if b.is_empty(Vector2i(xx, yy)):
				after += b.matches_from(Vector2i(xx, yy)).size()
	check(b.cols == 15 and b.rows == 23 and before == after, "transpose keeps every move")

	# shuffle keeps gem counts and finds a move
	var s := board_from(["1.2", "...", "3.1"])
	check(not s.has_any_move(), "stuck board detected")
	var left := s.gems_left()
	s.shuffle_remaining(rng)
	check(s.gems_left() == left, "shuffle keeps the gems")

	# play a full random game to the end
	b.setup(BoardLogic.LONG, BoardLogic.SHORT, rng)
	var moves := 0
	while b.has_any_move() and moves < 1000:
		var p := b.find_move()
		b.remove(b.matches_from(p))
		moves += 1
	check(not b.has_any_move() and moves > 20, "greedy play reaches a stuck board (%d moves, %d gems left)" % [moves, b.gems_left()])

	var tall := BoardLogic.best_dims(Vector2(540, 1150))
	var wide := BoardLogic.best_dims(Vector2(1250, 620))
	check(tall.y > tall.x and wide.x > wide.y, "board shape follows the screen (%s tall, %s wide)" % [tall, wide])
	var ok_sizes := true
	for a in [Vector2(540, 1150), Vector2(1250, 620), Vector2(700, 700), Vector2(380, 1400), Vector2(2000, 500)]:
		var d := BoardLogic.best_dims(a)
		ok_sizes = ok_sizes and d.x * d.y >= 317 and d.x * d.y <= 372
	check(ok_sizes, "every shape has 345 slots ±8% for the 270 gems")
	var sq := BoardLogic.new()
	sq.setup(tall.x, tall.y, rng)
	var gems := 0
	for kk in sq.cells:
		if kk >= 0: gems += 1
	check(gems == 270, "270 gems on a %dx%d board" % [tall.x, tall.y])
	var cm := BoardLogic.COMPACT
	var phone := BoardLogic.best_dims(Vector2(540, 1150), cm.slots)
	var small := BoardLogic.new()
	small.setup(phone.x, phone.y, rng, cm.shining, cm.kinds, cm.per_kind)
	var cnt := {}
	for kk in small.cells:
		cnt[kk] = cnt.get(kk, 0) + 1
	check(phone.y > phone.x and phone.x * phone.y >= 99 and phone.x * phone.y <= 116,
		"compact phone board %s has about 108 slots" % [phone])
	check(cnt.size() == cm.kinds + 1 and cnt.get(0, 0) == cm.per_kind, "compact board: 6 kinds x 14 gems")

	var sh := BoardLogic.new()
	sh.setup(BoardLogic.LONG, BoardLogic.SHORT, rng)
	var shining := 0
	var on_gems := true
	for i in sh.cells.size():
		if sh.shine[i] == 1:
			shining += 1
			on_gems = on_gems and sh.cells[i] >= 0
	check(shining == BoardLogic.SHINING and on_gems, "8 shining gems, all on gems")
	var before_t := shining
	sh.transpose()
	var after_t := 0
	for v in sh.shine: after_t += v
	check(after_t == before_t, "transpose keeps shining gems")
	var mv := sh.find_move()
	var gone := sh.matches_from(mv)
	var nsh := sh.shining_count(gone)
	sh.remove(gone)
	var shine_left := 0
	for v in sh.shine: shine_left += v
	check(shine_left == before_t - nsh, "removing gems clears their shine")
	sh.shuffle_remaining(rng)
	var ok_after := true
	for i in sh.cells.size():
		if sh.shine[i] == 1: ok_after = ok_after and sh.cells[i] >= 0
	check(ok_after, "shuffle moves the shine together with its gem")

	print("ScoreKeeper")
	var k := ScoreKeeper.new()
	var r := k.hit(2, 0.0)
	check(r.points == 2 and r.mult == 1 and r.combo == 1, "first strike scores plain points")
	r = k.hit(2, 1.0)
	check(r.mult == 2 and r.points == 4 and r.tier_up, "second strike in the window doubles")
	r = k.hit(2, 5.0)
	check(r.combo == 1 and r.mult == 1, "a pause longer than the window resets the combo")
	k.hit(2, 5.5)
	check(k.miss(), "a miss breaks a running combo")
	check(k.combo == 0, "combo is zero after a miss")
	for i in 9:
		r = k.hit(2, 6.0 + i)
	check(r.combo == 9 and r.mult == 4 and k.best_combo == 9, "nine in a row reach x4")
	check(k.update(30.0) and k.combo == 0, "update() expires the combo")

	k.reset()
	r = k.hit(3, 0.0)
	check(r.event == "" and r.time == 1.0, "one 3-gem strike is not a precise combo yet")
	k.hit(4, 1.0)
	r = k.hit(3, 2.0)
	check(r.event == "precise" and r.time == 1.0 + ScoreKeeper.PRECISE_TIME, "3rd big strike in a row: precise combo")
	check(r.points == BoardLogic.points_for(3) * 2 + ScoreKeeper.PRECISE_POINTS, "precise bonus adds on top of x2")
	r = k.hit(4, 3.0)
	check(r.event == "perfect" and r.time == 2.0 + ScoreKeeper.PERFECT_TIME, "4th big strike: perfect combo")
	r = k.hit(3, 4.0)
	check(r.event == "perfect" and k.precise_count == 3, "every big strike after that is perfect too")
	r = k.hit(2, 5.0)
	check(r.event == "" and k.precise_streak == 0, "a 2-gem strike ends the precise streak")

	k.reset()
	r = k.hit(2, 0.0, 1)
	check(r.points == 2 + ScoreKeeper.SHINE_POINTS and r.time == ScoreKeeper.SHINE_TIME, "a shining gem adds +5 points and +2 s")

	print("FAILED: %d" % failed if failed else "all passed")
	quit(1 if failed else 0)
