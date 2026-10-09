class_name BoardLogic
extends RefCounted
## Pure game rules, no rendering. A board is a grid of gem kinds; EMPTY marks a free slot.
##
## A move is a press on an empty slot. From there the first gem in each of the four
## directions is taken; every kind that appears at least twice among them is knocked out.

const KINDS := 10
const PER_KIND := 27
const LONG := 23
const SHORT := 15
const EMPTY := -1
const SHINING := 8  ## gems with a bonus on them at the start of a game
## Game modes. Classic is the original game: 270 gems, a wide 23x15 board on desktops (tall
## on phones), and the round ends when no moves are left. Bright is the toy-style mode: fewer,
## bigger tiles, a fresh board whenever moves run out. Each has its own leaderboard.
const CLASSIC := {"id": "classic", "kinds": 10, "per_kind": 27, "cols": 23, "rows": 15, "slots": 345, "shining": 8,
	"board": "score", "waves": false}
const BRIGHT := {"id": "bright", "kinds": 6, "per_kind": 14, "cols": 7, "rows": 15, "slots": 108, "shining": 3,
	"board": "score_bright", "waves": true}
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var cols := LONG
var rows := SHORT
var cells := PackedInt32Array()
var shine := PackedByteArray()  ## 1 where the gem is a shining (bonus) gem
## For boards built by setup_solvable: strike slots in placement order. Playing them in
## reverse order knocks out every gem on the board.
var solution: Array[Vector2i] = []


func setup(c: int, r: int, rng: RandomNumberGenerator, shining := SHINING, kinds := KINDS, per_kind := PER_KIND) -> void:
	cols = c
	rows = r
	var bag := PackedInt32Array()
	for k in kinds:
		for i in per_kind:
			bag.append(k)
	while bag.size() < cols * rows:
		bag.append(EMPTY)
	_shuffle(bag, rng)
	cells = bag
	shine = PackedByteArray()
	shine.resize(cells.size())
	var gem_slots: Array[int] = []
	for i in cells.size():
		if cells[i] != EMPTY:
			gem_slots.append(i)
	for n in mini(shining, gem_slots.size()):
		var j := rng.randi_range(n, gem_slots.size() - 1)
		var t := gem_slots[n]
		gem_slots[n] = gem_slots[j]
		gem_slots[j] = t
		shine[gem_slots[n]] = 1


func load_cells(c: int, r: int, data: PackedInt32Array) -> void:
	cols = c
	rows = r
	cells = data.duplicate()
	shine = PackedByteArray()
	shine.resize(cells.size())


func kind_at(p: Vector2i) -> int:
	return cells[p.y * cols + p.x]


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < cols and p.y < rows


func is_empty(p: Vector2i) -> bool:
	return kind_at(p) == EMPTY


## First gem met in each direction from p (up to four positions).
func hits_from(p: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		var q := p + d
		while in_bounds(q) and kind_at(q) == EMPTY:
			q += d
		if in_bounds(q):
			out.append(q)
	return out


## Positions that a press on p would knock out. Empty when the press is a miss.
func matches_from(p: Vector2i) -> Array[Vector2i]:
	var hits := hits_from(p)
	var count := {}
	for h in hits:
		var k := kind_at(h)
		count[k] = count.get(k, 0) + 1
	var out: Array[Vector2i] = []
	for h in hits:
		if count[kind_at(h)] >= 2:
			out.append(h)
	return out


func is_shining(p: Vector2i) -> bool:
	return shine[p.y * cols + p.x] == 1


func shining_count(ps: Array[Vector2i]) -> int:
	var n := 0
	for p in ps:
		if is_shining(p):
			n += 1
	return n


func remove(ps: Array[Vector2i]) -> void:
	for p in ps:
		cells[p.y * cols + p.x] = EMPTY
		shine[p.y * cols + p.x] = 0


func has_any_move() -> bool:
	for y in rows:
		for x in cols:
			var p := Vector2i(x, y)
			if is_empty(p) and not matches_from(p).is_empty():
				return true
	return false


func find_move() -> Vector2i:
	for y in rows:
		for x in cols:
			var p := Vector2i(x, y)
			if is_empty(p) and not matches_from(p).is_empty():
				return p
	return Vector2i(-1, -1)


## How many empty slots are a valid move right now.
func count_moves() -> int:
	var n := 0
	for y in rows:
		for x in cols:
			var p := Vector2i(x, y)
			if is_empty(p) and not matches_from(p).is_empty():
				n += 1
	return n


## Gems in the square of side 2r+1 around p (the bomb booster).
func area(p: Vector2i, r := 1) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q := p + Vector2i(dx, dy)
			if in_bounds(q) and not is_empty(q):
				out.append(q)
	return out


## Bright mode level: the board grows and gains kinds as levels go up.
static func bright_level(level: int) -> Dictionary:
	var lv := maxi(level, 1)
	var slots := mini(36 + (lv - 1) * 12, 120)
	var kinds := 4 if lv <= 2 else (5 if lv <= 4 else 6)
	# early boards are airier (more empty slots = more possible moves), later ones fill up
	var density := minf(0.6 + 0.03 * (lv - 1), 0.78)
	var per_kind := maxi(2, int(round(slots * density)) / kinds)
	# early levels promise many opening moves; from level 8 the deal leans stingy
	var min_moves := maxi(2, 10 - (lv - 1) * 2)
	var max_moves := 8 if lv >= 8 else 999
	return {"slots": slots, "kinds": kinds, "per_kind": per_kind, "min_moves": min_moves, "max_moves": max_moves,
		"tries": 120 if lv >= 8 else 60}


## Build a board that can be cleared completely by the cross rule alone. It is made
## backwards from an empty grid: each step picks an empty strike slot and puts 2-4 gems of
## one kind where that strike would hit first, making sure the strike would take exactly
## those gems. Undoing the steps in reverse order is then a full solution.
func setup_solvable(c: int, r: int, rng: RandomNumberGenerator, shining: int, kinds: int, gems: int) -> int:
	cols = c
	rows = r
	cells = PackedInt32Array()
	cells.resize(c * r)
	cells.fill(EMPTY)
	shine = PackedByteArray()
	shine.resize(c * r)
	solution.clear()
	var used := PackedInt32Array()
	used.resize(kinds)
	var placed := 0
	var fails := 0
	while placed < gems and fails < 3000:
		var p := Vector2i(rng.randi_range(0, c - 1), rng.randi_range(0, r - 1))
		if not is_empty(p):
			fails += 1
			continue
		var cands: Array = []  # per direction: empty slots in front of the first gem
		var hits: Array[int] = []  # per direction: kind of the first gem, or -2 at the edge
		for d in DIRS:
			var q := p + d
			var ray: Array[Vector2i] = []
			while in_bounds(q) and is_empty(q):
				ray.append(q)
				q += d
			cands.append(ray)
			hits.append(kind_at(q) if in_bounds(q) else -2)
		var open_dirs: Array[int] = []
		for i in 4:
			if not cands[i].is_empty():
				open_dirs.append(i)
		if open_dirs.size() < 2:
			fails += 1
			continue
		var roll := rng.randf()
		var want := 4 if roll < 0.06 else (3 if roll < 0.25 else 2)
		want = mini(mini(want, open_dirs.size()), gems - placed)
		if want < 2:
			break
		for i in range(open_dirs.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := open_dirs[i]
			open_dirs[i] = open_dirs[j]
			open_dirs[j] = t
		var chosen := open_dirs.slice(0, want)
		# the strike must take only the new gems: the other directions' first gems may not
		# pair up with each other or with the new kind
		var others: Array[int] = []
		for i in 4:
			if not (i in chosen) and hits[i] >= 0:
				others.append(hits[i])
		var dup := false
		for i in others.size():
			for j in range(i + 1, others.size()):
				dup = dup or others[i] == others[j]
		if dup:
			fails += 1
			continue
		var kind := -1
		for k in kinds:
			if not (k in others) and (kind < 0 or used[k] < used[kind]):
				kind = k
		if kind < 0:
			fails += 1
			continue
		for i in chosen:
			var ray: Array = cands[i]
			var pos: Vector2i = ray[rng.randi_range(0, ray.size() - 1)]
			cells[pos.y * cols + pos.x] = kind
		used[kind] += want
		placed += want
		solution.append(p)
	var gem_slots: Array[int] = []
	for i in cells.size():
		if cells[i] != EMPTY:
			gem_slots.append(i)
	for n in mini(shining, gem_slots.size()):
		var j := rng.randi_range(n, gem_slots.size() - 1)
		var t := gem_slots[n]
		gem_slots[n] = gem_slots[j]
		gem_slots[j] = t
		shine[gem_slots[n]] = 1
	return placed


## Deal repeatedly and keep the first layout whose number of opening moves falls in
## [min_moves, max_moves]; if none does in `tries`, keep the closest one. Returns its moves.
func setup_tuned(c: int, r: int, rng: RandomNumberGenerator, shining: int, kinds: int, per_kind: int,
		min_moves: int, max_moves := 999, tries := 40, solvable := false) -> int:
	var best_cells := PackedInt32Array()
	var best_shine := PackedByteArray()
	var best_solution: Array[Vector2i] = []
	var best_gap := 1 << 30
	var best_moves := 0
	for t in tries:
		if solvable:
			setup_solvable(c, r, rng, shining, kinds, kinds * per_kind)
		else:
			setup(c, r, rng, shining, kinds, per_kind)
		var m := count_moves()
		if m >= min_moves and m <= max_moves:
			return m
		var gap := (min_moves - m) if m < min_moves else (m - max_moves)
		if gap < best_gap:
			best_gap = gap
			best_cells = cells.duplicate()
			best_shine = shine.duplicate()
			best_solution = solution.duplicate()
			best_moves = m
	cells = best_cells
	shine = best_shine
	solution = best_solution
	return best_moves


func gems_left() -> int:
	var n := 0
	for k in cells:
		if k != EMPTY:
			n += 1
	return n


## Swap rows and columns. The cross rule is symmetric, so every move stays valid.
func transpose() -> void:
	var out := PackedInt32Array()
	out.resize(cells.size())
	var sh := PackedByteArray()
	sh.resize(cells.size())
	for y in rows:
		for x in cols:
			out[x * rows + y] = cells[y * cols + x]
			sh[x * rows + y] = shine[y * cols + x]
	shine = sh
	var c := cols
	cols = rows
	rows = c
	cells = out


## Re-deal the remaining gems over the whole board until at least one move exists.
func shuffle_remaining(rng: RandomNumberGenerator) -> void:
	for attempt in 30:
		# shuffle gems and their shine flags with the same permutation
		for i in range(cells.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t := cells[i]
			cells[i] = cells[j]
			cells[j] = t
			var u := shine[i]
			shine[i] = shine[j]
			shine[j] = u
		if has_any_move():
			return


## Grid shape that gives the biggest cells in the given area for about `slots` slots
## (within -8%..+8%). The gem count is fixed by the mode; only the shape changes.
static func best_dims(area: Vector2, slots := 345) -> Vector2i:
	var fallback := Vector2i(LONG, SHORT) if slots >= 300 else Vector2i(7, 15)
	if area.x <= 0.0 or area.y <= 0.0:
		return fallback
	var lo := int(slots * 0.92)
	var hi := int(slots * 1.08)
	var best := fallback
	var best_cell := -1.0
	for c in range(5, 40):
		for r in [floori(float(slots) / c), ceili(float(slots) / c)]:
			var n: int = c * r
			if r < 5 or n < lo or n > hi:
				continue
			var cell := minf(area.x / c, area.y / r)
			var closer := absi(n - slots) < absi(best.x * best.y - slots)
			if cell > best_cell + 0.01 or (absf(cell - best_cell) <= 0.01 and closer):
				best_cell = cell
				best = Vector2i(c, r)
	return best


static func bonus_for(n: int) -> int:
	if n >= 4:
		return 2
	if n == 3:
		return 1
	return 0


static func points_for(n: int) -> int:
	return n + bonus_for(n)


static func _shuffle(a: PackedInt32Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := a[i]
		a[i] = a[j]
		a[j] = t
