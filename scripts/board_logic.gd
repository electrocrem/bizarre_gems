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
## Board presets. Classic is the original wide board (desktop); compact has fewer, bigger
## cells for phones and picks its shape from the screen. Each has its own leaderboard.
const CLASSIC := {"id": "classic", "kinds": 10, "per_kind": 27, "cols": 23, "rows": 15, "slots": 345, "shining": 8, "board": "score"}
const COMPACT := {"id": "compact", "kinds": 6, "per_kind": 14, "cols": 7, "rows": 15, "slots": 108, "shining": 3, "board": "score_mobile"}
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var cols := LONG
var rows := SHORT
var cells := PackedInt32Array()
var shine := PackedByteArray()  ## 1 where the gem is a shining (bonus) gem


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
