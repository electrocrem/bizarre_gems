extends RefCounted
## Rules from refinement@bcee016; run only through the isolated combo suite.
const A := Vector2i(3, 3)
const B := Vector2i(4, 3)
var checks := 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func rules() -> void:
	var modern := ScoreKeeper.new()
	modern.configure_combo_rules(false, true)
	modern.time_bonuses = false
	var classic := ScoreKeeper.new()
	classic.configure_combo_rules(true, false)
	classic.configure_time_rewards(true)
	var hit_sizes := [3, 2, 3, 2, 3, 3, 3, 3, 3, 3, 2, 4, 4, 4, 4, 4]
	for i in hit_sizes.size():
		var colors: Array[int] = []
		colors.resize(hit_sizes[i])
		colors.fill(i % 2)
		var r := modern.hit(hit_sizes[i], i * 0.3, 2, A, colors)
		var c := classic.hit(hit_sizes[i], i * 0.3, 2, A, colors)
		check(r.points == c.points and r.event == c.event and r.mult == c.mult,
			"shared points, multiplier and unique cycle %d" % i)
		check(r.time == 0 and modern.special_bonus_time == 0, "Run has no hit seconds %d" % i)
		check(modern.precise_streak == classic.precise_streak, "pair support/cycle progress %d" % i)
	modern.reset()
	for i in 10:
		var r := modern.hit(2, i * 0.1, 0, A, [0, 0])
		check(r.mult == (1 if i == 0 else (2 if i < 4 else (3 if i < 8 else 4))), "tier boundary %d" % i)
	modern.reset()
	modern.hit(2, 0.0, 0, A, [99, 99])
	var result := modern.hit(2, 0.1, 0, B, [99, 99])
	check(result.color_streak_points == 0 and modern.color_streak_kind == -1, "joker-only strikes cannot create color 99")
