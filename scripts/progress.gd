extends Node
## Long-term progress for the bright modes: level stars, crystals, the tile looks the player
## owns, and today's three tasks. Stored in user://progress.cfg.

signal changed

const PATH := "user://progress.cfg"
const STAR_CRYSTALS := 5          ## crystals per newly earned star
const LOOK_PRICES := [0, 60, 90, 120, 160, 200]
## Daily task pool. "max" tasks track the best single value instead of adding up.
const TASK_POOL := [
	{"id": "clear_boards", "goal": 3, "reward": 30},
	{"id": "combo4", "goal": 2, "reward": 20},
	{"id": "gems", "goal": 250, "reward": 25},
	{"id": "stars3", "goal": 2, "reward": 35},
	{"id": "levels", "goal": 3, "reward": 25},
	{"id": "run_score", "goal": 600, "reward": 30, "max": true},
	{"id": "zen_boards", "goal": 3, "reward": 25},
	{"id": "perfects", "goal": 2, "reward": 30},
]

var stars := {}      ## level number -> best stars (0..3)
var crystals := 0
var owned: Array = [0]
var look := 0        ## selected tile look, the first one bright games start with
var task_date := ""
var tasks: Array = []


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		var st: Dictionary = cfg.get_value("levels", "stars", {})
		for k in st:
			stars[int(k)] = int(st[k])
		crystals = int(cfg.get_value("shop", "crystals", 0))
		owned = cfg.get_value("shop", "owned", [0])
		look = int(cfg.get_value("shop", "look", 0))
		task_date = str(cfg.get_value("tasks", "date", ""))
		tasks = cfg.get_value("tasks", "list", [])
	refresh_tasks()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("levels", "stars", stars)
	cfg.set_value("shop", "crystals", crystals)
	cfg.set_value("shop", "owned", owned)
	cfg.set_value("shop", "look", look)
	cfg.set_value("tasks", "date", task_date)
	cfg.set_value("tasks", "list", tasks)
	cfg.save(PATH)
	changed.emit()


# ---------------- levels and stars ----------------

func stars_for(level: int) -> int:
	return int(stars.get(level, 0))


## The highest level the player may start: one past the last level with a star.
func max_unlocked() -> int:
	var n := 1
	while stars_for(n) > 0:
		n += 1
	return n


func total_stars() -> int:
	var t := 0
	for k in stars:
		t += int(stars[k])
	return t


## Stars for a level result by share of gems knocked out.
static func stars_for_share(share: float) -> int:
	if share >= 0.999:
		return 3
	if share >= 0.85:
		return 2
	if share >= 0.6:
		return 1
	return 0


## Store a level result; returns how many new stars were earned (each pays crystals).
func record_level(level: int, got: int) -> int:
	var old := stars_for(level)
	if got > old:
		stars[level] = got
		crystals += (got - old) * STAR_CRYSTALS
	if old == 0 and got > 0:
		report("levels")
	if got == 3 and old < 3:
		report("stars3")
	_save()
	return maxi(0, got - old)


# ---------------- daily tasks ----------------

## Today's three tasks, the same for everyone (seeded by the UTC date).
func refresh_tasks() -> void:
	var today := Time.get_date_string_from_system(true)
	if task_date == today and tasks.size() == 3:
		return
	task_date = today
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bizarre-tasks-" + today)
	var pool: Array = TASK_POOL.duplicate()
	tasks = []
	for i in 3:
		var t: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		tasks.append({"id": t.id, "goal": t.goal, "reward": t.reward, "max": t.get("max", false),
			"progress": 0, "claimed": false})
	_save()


func report(id: String, amount := 1) -> void:
	refresh_tasks()
	var hit := false
	for t in tasks:
		if t.id == id and int(t.progress) < int(t.goal):
			if t.get("max", false):
				t.progress = mini(int(t.goal), maxi(int(t.progress), amount))
			else:
				t.progress = mini(int(t.goal), int(t.progress) + amount)
			hit = true
	if hit:
		_save()


func task_done(i: int) -> bool:
	return int(tasks[i].progress) >= int(tasks[i].goal)


func claim(i: int) -> int:
	if i < 0 or i >= tasks.size() or not task_done(i) or bool(tasks[i].claimed):
		return 0
	tasks[i].claimed = true
	crystals += int(tasks[i].reward)
	_save()
	return int(tasks[i].reward)


func unclaimed() -> int:
	var n := 0
	for i in tasks.size():
		if task_done(i) and not bool(tasks[i].claimed):
			n += 1
	return n


# ---------------- tile looks ----------------

func owns(i: int) -> bool:
	return i in owned


func buy(i: int) -> bool:
	if owns(i) or crystals < int(LOOK_PRICES[i]):
		return false
	crystals -= int(LOOK_PRICES[i])
	owned.append(i)
	look = i
	_save()
	return true


func select(i: int) -> void:
	if owns(i):
		look = i
		_save()
