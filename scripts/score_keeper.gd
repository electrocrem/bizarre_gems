class_name ScoreKeeper
extends RefCounted
## Scoring with combos. Time is game time in seconds (pauses don't count).
##
## Combo: successful strikes in a row, each within COMBO_WINDOW of the previous one.
## A miss or a pause longer than the window resets it. Points are multiplied by the combo tier.
##
## Precise combo: strikes in a row that each knock out PRECISE_MIN or more gems.
## The 3rd such strike in a row is a "precise" combo, the 4th and every one after it is "perfect".

const COMBO_WINDOW := 3.0
const PRECISE_MIN := 3
const PRECISE_AT := 3
const PERFECT_AT := 4
const PRECISE_POINTS := 10
const PRECISE_TIME := 3.0
const PERFECT_POINTS := 20
const PERFECT_TIME := 5.0
const SHINE_POINTS := 5
const SHINE_TIME := 2.0
## combo length -> multiplier (first entry whose length is reached, checked from the top)
const TIERS := [[9, 4], [5, 3], [2, 2], [0, 1]]

var score := 0
var combo := 0
var best_combo := 0
var precise_streak := 0
var precise_count := 0
var _last_hit := -1000.0


static func multiplier_for(c: int) -> int:
	for t in TIERS:
		if c >= t[0]:
			return t[1]
	return 1


func reset() -> void:
	score = 0
	combo = 0
	best_combo = 0
	precise_streak = 0
	precise_count = 0
	_last_hit = -1000.0


## Seconds left before the combo expires, 0 when there is no combo.
func window_left(now: float) -> float:
	if combo < 2:
		return 0.0
	return maxf(0.0, COMBO_WINDOW - (now - _last_hit))


## Call every frame. Returns true when the combo just ran out.
func update(now: float) -> bool:
	if combo > 0 and now - _last_hit > COMBO_WINDOW:
		var had := combo >= 2
		combo = 0
		precise_streak = 0
		return had
	return false


## Returns true when a running combo (2+) was broken.
func miss() -> bool:
	var had := combo >= 2
	combo = 0
	precise_streak = 0
	return had


## A successful strike that knocked out n gems, `shining` of them shining gems.
## Returns {points, time, combo, mult, tier_up, event, shine} where event is "", "precise" or "perfect".
func hit(n: int, now: float, shining := 0) -> Dictionary:
	if now - _last_hit > COMBO_WINDOW:
		combo = 0
		precise_streak = 0
	var old_mult := multiplier_for(combo)
	combo += 1
	best_combo = maxi(best_combo, combo)
	_last_hit = now
	var mult := multiplier_for(combo)
	var points := BoardLogic.points_for(n) * mult
	var time := float(BoardLogic.bonus_for(n))
	var event := ""
	if n >= PRECISE_MIN:
		precise_streak += 1
		if precise_streak >= PERFECT_AT:
			event = "perfect"
			points += PERFECT_POINTS
			time += PERFECT_TIME
		elif precise_streak == PRECISE_AT:
			event = "precise"
			points += PRECISE_POINTS
			time += PRECISE_TIME
		if event != "":
			precise_count += 1
	else:
		precise_streak = 0
	points += shining * SHINE_POINTS
	time += shining * SHINE_TIME
	score += points
	return {"points": points, "time": time, "combo": combo, "mult": mult, "tier_up": mult > old_mult, "event": event, "shine": shining}
