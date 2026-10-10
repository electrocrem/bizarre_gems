extends Node
## Long-term progress for the bright modes: level stars, crystals, the tile looks the player
## owns, and today's three tasks. Stored in user://progress.cfg.

signal changed

const PATH := "user://progress.cfg"
const STAR_CRYSTALS := 5          ## crystals per newly earned star
## Price per tile look: crystals, SEASON (free while its season is on) or GIFT (7-day streak).
const SEASON := -1
const GIFT := -2
const LOOK_PRICES := [0, 60, 90, 120, 160, 200, SEASON, SEASON, GIFT]
const WINTER_LOOK := 6
const HALLOWEEN_LOOK := 7
const GOLD_LOOK := 8
## Lifetime goals; "stat" is the counter they read, same names as the task reports.
const ACHIEVEMENTS := [
	{"id": "clears10", "stat": "clear_boards", "goal": 10, "reward": 40},
	{"id": "clears100", "stat": "clear_boards", "goal": 100, "reward": 150},
	{"id": "gems1000", "stat": "gems", "goal": 1000, "reward": 50},
	{"id": "gems10000", "stat": "gems", "goal": 10000, "reward": 200},
	{"id": "combo4x10", "stat": "combo4", "goal": 10, "reward": 60},
	{"id": "perfect10", "stat": "perfects", "goal": 10, "reward": 60},
	{"id": "levels10", "stat": "levels", "goal": 10, "reward": 50},
	{"id": "levels30", "stat": "levels", "goal": 30, "reward": 120},
	{"id": "stars3x10", "stat": "stars3", "goal": 10, "reward": 80},
	{"id": "puzzles10", "stat": "puzzles", "goal": 10, "reward": 60},
	{"id": "streak7", "stat": "streak", "goal": 7, "reward": 100},
]
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
var life := {}          ## lifetime counters (gems, clear_boards, ...) for achievements
var achieved: Array = []  ## achievement ids already claimed
var gift_date := ""     ## last day the daily gift was opened
var streak := 0         ## days in a row the gift was opened
var puzzles := 0        ## puzzles solved (the next one is puzzles + 1)
var tutorial := false   ## the first-run tutorial was completed
## Local leaderboards (Android and anywhere without Yandex): board -> [{score, date}], best 10.
var local_scores := {}
var _dirty := false
var _since := 0.0


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
		life = cfg.get_value("meta", "life", {})
		achieved = cfg.get_value("meta", "achieved", [])
		gift_date = str(cfg.get_value("meta", "gift_date", ""))
		streak = int(cfg.get_value("meta", "streak", 0))
		puzzles = int(cfg.get_value("meta", "puzzles", 0))
		tutorial = bool(cfg.get_value("meta", "tutorial", false))
		local_scores = cfg.get_value("meta", "local_scores", {})
	refresh_tasks()


func _save() -> void:
	_dirty = false
	_since = 0.0
	var cfg := ConfigFile.new()
	cfg.set_value("levels", "stars", stars)
	cfg.set_value("shop", "crystals", crystals)
	cfg.set_value("shop", "owned", owned)
	cfg.set_value("shop", "look", look)
	cfg.set_value("tasks", "date", task_date)
	cfg.set_value("tasks", "list", tasks)
	cfg.set_value("meta", "life", life)
	cfg.set_value("meta", "achieved", achieved)
	cfg.set_value("meta", "gift_date", gift_date)
	cfg.set_value("meta", "streak", streak)
	cfg.set_value("meta", "puzzles", puzzles)
	cfg.set_value("meta", "tutorial", tutorial)
	cfg.set_value("meta", "local_scores", local_scores)
	cfg.save(PATH)
	Yandex.save_data(Save.cloud_data())
	changed.emit()


## Everything worth keeping across devices, for the player's Yandex cloud data.
func to_dict() -> Dictionary:
	return {"stars": stars, "crystals": crystals, "owned": owned, "look": look, "life": life, "achieved": achieved,
		"gift_date": gift_date, "streak": streak, "puzzles": puzzles, "tutorial": tutorial}


## Merge cloud progress into the local one, keeping the better of each.
func merge(d: Dictionary) -> void:
	if d.is_empty():
		return
	var st: Dictionary = d.get("stars", {})
	for k in st:
		stars[int(k)] = maxi(stars_for(int(k)), int(st[k]))
	crystals = maxi(crystals, int(d.get("crystals", 0)))
	for i in d.get("owned", []):
		if not (int(i) in owned):
			owned.append(int(i))
	var cl: Dictionary = d.get("life", {})
	for k in cl:
		life[k] = maxi(int(life.get(k, 0)), int(cl[k]))
	for a in d.get("achieved", []):
		if not (a in achieved):
			achieved.append(a)
	if str(d.get("gift_date", "")) > gift_date:
		gift_date = str(d.get("gift_date", ""))
		streak = int(d.get("streak", streak))
	puzzles = maxi(puzzles, int(d.get("puzzles", 0)))
	tutorial = tutorial or bool(d.get("tutorial", false))
	_save()


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
	if id == "run_score":
		life[id] = maxi(int(life.get(id, 0)), amount)
	else:
		life[id] = int(life.get(id, 0)) + amount
	for t in tasks:
		if t.id == id and int(t.progress) < int(t.goal):
			if t.get("max", false):
				t.progress = mini(int(t.goal), maxi(int(t.progress), amount))
			else:
				t.progress = mini(int(t.goal), int(t.progress) + amount)
	_dirty = true  # reports come every strike; the file and the cloud are written in batches


## Write pending progress now (end of a game, leaving a level).
func flush() -> void:
	if _dirty:
		_save()


func _process(delta: float) -> void:
	if _dirty:
		_since += delta
		if _since > 3.0:
			_save()


# ---------------- achievements ----------------

func achievement_progress(i: int) -> int:
	var a: Dictionary = ACHIEVEMENTS[i]
	return mini(int(life.get(a.stat, 0)), int(a.goal))


func achievement_done(i: int) -> bool:
	return achievement_progress(i) >= int(ACHIEVEMENTS[i].goal)


func claim_achievement(i: int) -> int:
	var a: Dictionary = ACHIEVEMENTS[i]
	if not achievement_done(i) or a.id in achieved:
		return 0
	achieved.append(a.id)
	crystals += int(a.reward)
	_save()
	return int(a.reward)


func achievements_due() -> int:
	var n := 0
	for i in ACHIEVEMENTS.size():
		if achievement_done(i) and not (ACHIEVEMENTS[i].id in achieved):
			n += 1
	return n


# ---------------- daily gift ----------------

func gift_ready() -> bool:
	return gift_date != Time.get_date_string_from_system(true)


## Crystals for day n of a streak: 10, 15, ... 40 on day 7 and after.
static func gift_amount(day: int) -> int:
	return 10 + 5 * (clampi(day, 1, 7) - 1)


## Open today's gift. Returns {"crystals", "day", "look"} (look = -1 unless a look was unlocked).
func open_gift() -> Dictionary:
	if not gift_ready():
		return {}
	var today := Time.get_date_string_from_system(true)
	var yesterday := Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(today) - 86400)
	streak = streak + 1 if gift_date == yesterday else 1
	gift_date = today
	var amount := gift_amount(streak)
	crystals += amount
	life["streak"] = maxi(int(life.get("streak", 0)), streak)
	var unlocked := -1
	if streak % 7 == 0 and not owns(GOLD_LOOK):
		owned.append(GOLD_LOOK)
		unlocked = GOLD_LOOK
	_save()
	return {"crystals": amount, "day": streak, "look": unlocked}


# ---------------- seasons ----------------

## The seasonal look available today, or -1.
static func season_look() -> int:
	var d := Time.get_date_dict_from_system(true)
	if d.month == 12 or d.month <= 2:
		return WINTER_LOOK
	if (d.month == 10 and d.day >= 15) or (d.month == 11 and d.day <= 5):
		return HALLOWEEN_LOOK
	return -1


func claim_season() -> bool:
	var s2 := season_look()
	if s2 < 0 or owns(s2):
		return false
	owned.append(s2)
	look = s2
	_save()
	return true


func solved_puzzle(n: int) -> void:
	if n > puzzles:
		puzzles = n
		report("puzzles")
	_save()


## Keep a result in this device's top 10 for a board ("score", "score_bright", "stars", ...).
func add_local_score(board: String, value: int) -> void:
	if board == "" or value <= 0:
		return
	var list: Array = local_scores.get(board, [])
	if board == "stars":
		list = []  # one entry: the current total
	list.append({"score": value, "date": Time.get_date_string_from_system()})
	list.sort_custom(func(a, b): return int(a.score) > int(b.score))
	local_scores[board] = list.slice(0, 10)
	_save()


func local_top(board: String) -> Array:
	return local_scores.get(board, [])


func finish_tutorial() -> void:
	tutorial = true
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
	if owns(i) or int(LOOK_PRICES[i]) < 0 or crystals < int(LOOK_PRICES[i]):
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
