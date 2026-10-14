extends "res://tests/test_combo_runtime.gd"
## Refinement cosmetics/tutorial-state policy + upstream persistence/claims/ad contracts.

func cosmetics(main) -> void:
	var p = main.get_node("/root/Progress")
	check(not p.COSMETICS_ENABLED, "cosmetics disabled policy")
	p.owned = [0, 8, 9]
	p.look = 9
	p.crystals = 1000
	var before: Dictionary = p.to_dict().duplicate(true)
	check(p.active_look() == 0 and p.look == 9, "base presentation preserves saved selected look")
	for i in p.LOOK_PRICES.size():
		check(not p.buy(i), "disabled purchase %d" % i)
		p.select(i)
	check(not p.claim_season() and p.to_dict() == before, "disabled cosmetic actions never mutate ownership/selection/currency")
	main.go_menu()
	main.home.refresh()
	check(not main.home.get_node("%Collection").visible, "home collection button hidden")
	main.home._on_collection_pressed()
	main._navigate(&"collection")
	check(main.home.visible and not main.collection.visible, "home/direct navigation rejects collection")
	main._navigate(&"more")
	main.more.navigate.emit(&"collection")
	check(main.more.visible and not main.collection.visible, "More navigation rejects collection")
	main.show_screen(main.collection)
	check(main.home.visible and not main.collection.visible, "direct screen/debug route rejects collection")
	main.collection.refresh()
	main.collection._on_card(1)
	check(p.to_dict() == before, "dormant collection handler cannot mutate cosmetic data")
	for id in ["classic", "bright", "zen", "levels", "puzzle"]:
		await start(main, id)
		check(main.board.palette == 0 and p.look == 9 and p.owns(9), "saved cosmetic choice dormant in " + id)
		main.go_menu()
	check(ResourceLoader.exists("res://scenes/ui/collection.tscn") and ResourceLoader.exists("res://assets/tiles/look_9_1.png"), "collection and owned-look resources retained")

func persistence(main) -> void:
	var p = main.get_node("/root/Progress")
	var s = main.get_node("/root/Save")
	p.tutorial = true
	p.tutorial_skipped = false
	p.stars = {1: 3, 2: 2}
	p.puzzles = 4
	p.hint_tokens = 7
	p.life = {"gems": 123, "perfects": 2}
	p.achieved = ["perfect10"]
	p.chapter_claims = ["c0_done"]
	p.daily_reward_date = "2026-10-14"
	p._save()
	var expected: Dictionary = p.to_dict().duplicate(true)
	var cfg := ConfigFile.new()
	check(cfg.load(p.PATH) == OK, "progress persisted in isolated profile")
	cfg.set_value("pass", "xp", 3000)
	cfg.set_value("pass", "season", "2026-10")
	cfg.set_value("pass", "claimed", [10])
	cfg.save(p.PATH)
	var fresh = load("res://scripts/progress.gd").new()
	main.get_tree().root.add_child(fresh)
	check(fresh.to_dict() == expected and fresh.look == 9 and fresh.owned == [0, 8, 9], "progress round-trip preserves ownership/selection and all live counters")
	check(not fresh.has_method("add_xp") and not fresh.has_method("claim_pass") and not fresh.has_method("_bank_cosmetic_pass_rewards"), "removed pass has no rewards/XP/banking API")
	check(not fresh.owns(10), "old pass XP grants no cosmetic entitlement or compensation")
	fresh._save()
	cfg = ConfigFile.new()  # ConfigFile.load merges; inspect the disk without old cached keys.
	cfg.load(p.PATH)
	check(not cfg.has_section_key("pass", "xp") and not cfg.has_section_key("pass", "claimed"), "pass gameplay fields not written back")
	fresh.queue_free()
	await settle(main)
	p.merge({"owned": [10], "look": 1, "tutorial": false, "crystals": 2, "season_xp": 3000})
	check(p.owns(9) and p.owns(10) and p.look == 9 and p.crystals == expected.crystals and p.tutorial, "existing merge preserves better ownership/currency/completion and local selection")
	check(not p.to_dict().has("season_xp") and not p.to_dict().has("season_claimed"), "cloud payload adds no season system")
	s.best = 0
	s.best_bright = 0
	s.best_zen = 0
	check(s.submit(400, "classic") and s.submit(250, "bright") and s.submit(100, "zen"), "separate mode records accepted")
	check(not s.submit(399, "classic") and not s.submit(249, "bright") and not s.submit(99, "zen"), "lower records never replace best")
	for id in ["tutorial", "levels", "puzzle", "unknown"]:
		check(not s.submit(9999, id), "non-score mode cannot pollute Classic: " + id)
	check([s.best, s.best_bright, s.best_zen] == [400, 250, 100], "score mode separation survives rejected submissions")
	p.local_scores = {}
	for value in range(1, 13):
		p.add_local_score("score", value)
	p.add_local_score("score_bright", 77)
	p.add_local_score("score_zen", 33)
	p.add_local_score("stars", 5)
	p.add_local_score("stars", 8)
	check(p.local_top("score").size() == 10 and p.local_top("score")[0].score == 12 and p.local_top("score")[-1].score == 3, "local leaderboard sorted and capped at ten")
	check(p.local_top("score_bright")[0].score == 77 and p.local_top("score_zen")[0].score == 33 and p.local_top("stars").size() == 1, "local boards and hidden stars/Zen preserved")
	var ad = main.get_node("/root/Yandex")
	ad.cloud = {"best": 300, "best_bright": 500, "best_zen": 700, "daily_date": "2099-01-01", "daily_best": 9999,
		"progress": {"tutorial": false, "owned": [1]}}
	s.daily_date = "2026-10-14"
	s.daily_best = 111
	s.sync_cloud()
	await settle(main)
	check([s.best, s.best_bright, s.best_zen] == [400, 500, 700], "existing cloud max merge includes hidden Zen")
	check(s.daily_date == "2026-10-14" and s.daily_best == 111, "cloud data does not introduce Daily record sync")
	check(not s.submit_daily(0, "2026-10-15"), "new Daily zero is not a record")
	var fresh_save = load("res://scripts/save.gd").new()
	main.get_tree().root.add_child(fresh_save)
	check(fresh_save.daily_date == "2026-10-15" and fresh_save.daily_best == 0, "new Daily date/zero result persist across restart")
	check([fresh_save.best, fresh_save.best_bright, fresh_save.best_zen] == [400, 500, 700], "normal records persist across restart")
	fresh_save.queue_free()
	ad.cloud = {}

func tutorial_state(main) -> void:
	var p = main.get_node("/root/Progress")
	var s = main.get_node("/root/Save")
	p.tutorial = true
	p.tutorial_skipped = false
	main.go_menu()
	main.home.play_pressed.emit()
	check(main.modes.visible and main.state == main.State.MENU and not p.needs_tutorial(), "old completed tutorial bypasses first-run gate")
	p.tutorial = false
	p.skip_tutorial()
	check(p.tutorial_skipped and not p.tutorial and not p.needs_tutorial(), "skip dismisses guidance without claiming completion")
	main.go_menu()
	main.home.play_pressed.emit()
	check(main.modes.visible, "skipped first-run guidance is not forced again")
	main.rules.tutorial_pressed.emit()
	await settle(main)
	check(main.mode.kind == "tutorial" and main.tut_step == 0, "manual Rules replay remains available after skip")
	var before: Dictionary = p.to_dict().duplicate(true)
	var records := [s.best, s.best_bright, s.best_zen, s.daily_date, s.daily_best, s.mode]
	var ad = main.get_node("/root/Yandex")
	var requests: int = ad.reward_requests.size()
	for i in 4:
		main._on_slot(main._tutorial_target())
	main._use_hint()
	check(ad.reward_requests.size() == requests and p.hint_tokens == before.hint_tokens, "practice hint spends no token/ad")
	var after: Dictionary = p.to_dict().duplicate(true)
	after.erase("tutorial")
	after.erase("tutorial_skipped")
	before.erase("tutorial")
	before.erase("tutorial_skipped")
	check(after == before, "practice strikes award no ordinary progress/achievements")
	main.end_game("time")
	check(p.to_dict().get("life") == before.life and p.crystals == before.crystals, "practice failure grants no game counters/currency")
	check([s.best, s.best_bright, s.best_zen, s.daily_date, s.daily_best, s.mode] == records, "practice never changes scores or selected gameplay mode")
	p.finish_tutorial()
	check(p.tutorial and not p.tutorial_skipped and not p.needs_tutorial(), "completion clears skipped marker")
	main.go_menu()
	p.merge({"tutorial": false, "tutorial_skipped": false})
	check(p.tutorial and not p.needs_tutorial(), "older cloud data cannot force completed user into future lessons")
	main.rules.tutorial_pressed.emit()
	await settle(main)
	check(main.mode.kind == "tutorial", "completed user can still open manual replay")
	main.go_menu()

func claims(main) -> void:
	var p = main.get_node("/root/Progress")
	p.crystals = 0
	p.tasks = [{"id": "gems", "goal": 250, "reward": 25, "progress": 250, "claimed": false}]
	p.task_date = Time.get_date_string_from_system(true)
	check(p.claim(0) == 25 and p.claim(0) == 0 and p.crystals == 25, "task claim pays exact reward once")
	check(p.claim(-1) == 0 and p.claim(1) == 0, "invalid task claim ignored")
	p.life = {"gems": 1000}
	p.achieved = []
	check(p.claim_achievement(2) == 50 and p.claim_achievement(2) == 0 and p.crystals == 75, "achievement claim pays once")
	check(p.claim_achievement(-1) == 0 and p.claim_achievement(1000) == 0, "invalid achievement claim ignored")
	p.stars = {}
	for n in range(1, BoardLogic.CHAPTER_SIZE + 1):
		p.stars[n] = 3
	p.chapter_claims = []
	check(p.claim_chapter(0, "done") == 50 and p.claim_chapter(0, "done") == 0, "hidden chapter completion reward retained once")
	check(p.claim_chapter(0, "full") == 100 and p.claim_chapter(0, "full") == 0, "hidden chapter stars reward retained once")
	var today := Time.get_date_string_from_system(true)
	p.gift_date = Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string(today) - 86400)
	p.streak = 6
	p.owned = [0, 9]
	var gift: Dictionary = p.open_gift()
	check(gift.crystals == 40 and gift.day == 7 and p.owns(8) and p.look == 9, "day-seven gift preserves silent cosmetic ownership with ordinary crystals")
	check(p.open_gift().is_empty(), "gift cannot pay twice on same UTC day")
	p.gift_date = ""
	main.gift.refresh()
	check(main.gift.get_node("%Line").text == main.get_node("/root/L").t("gift_daily_crystals"), "gift promises crystals while collection disabled")
	p.daily_reward_date = "2026-10-14"
	check(p.pay_daily("2026-10-15") == 20 and p.pay_daily("2026-10-15") == 0 and p.pay_daily("2026-10-14") == 0, "pinned Daily reward pays once without rewinding date")
	main.go_menu()

func rewards(main) -> void:
	var p = main.get_node("/root/Progress")
	var ad = main.get_node("/root/Yandex")
	p.crystals = 0
	await start(main, "bright")
	fixture(main, [0, 0, 0])
	main._on_slot(A)
	main.score = 450
	main.keeper.score = 450
	main.time_left = 0.25
	main._process(1.0)
	check(main.state == main.State.OVER and p.crystals == 4 and main.last_earned == 4, "first result pays score currency")
	var stats: Dictionary = p.life.duplicate(true)
	main.end_game("time")
	check(p.crystals == 4 and p.life == stats, "duplicate result does not repay or report progress twice")
	var requests: int = ad.reward_requests.size()
	main._on_double()
	var old_double: Callable = ad.pending_reward
	main._on_double()
	main._on_continue()
	check(ad.reward_requests.size() == requests + 1 and main._ad_pending and main.result.get_node("%Double").disabled, "repeated/conflicting presses send one SDK request and lock controls")
	ad.resolve_reward(false)
	await settle(main)
	check(p.crystals == 4 and not main._ad_pending and main.last_earned == 4 and not main.result.get_node("%Double").disabled, "failed reward re-enables retry without payment")
	old_double.call_deferred(true)
	await settle(main)
	check(p.crystals == 4, "failure consumes SDK receipt; late success cannot pay")
	main._on_double()
	old_double = ad.pending_reward
	ad.resolve_reward(true)
	await settle(main)
	check(p.crystals == 8 and main.last_earned == 0, "reward pays exact earned amount once")
	old_double.call_deferred(true)
	await settle(main)
	check(p.crystals == 8, "duplicate success never pays twice")
	var frozen := snapshot(main)
	requests = ad.reward_requests.size()
	main._on_continue()
	main._on_continue()
	check(ad.reward_requests.size() == requests + 1, "repeated continue requests serialized")
	ad.resolve_reward(true)
	await settle(main)
	check(main.time_left == 15 and main.used_continue and snapshot(main) == frozen, "continue retains exact eligible combo windows")
	main.score = 500
	main.keeper.score = 500
	main.end_game("time")
	check(p.crystals == 9 and main.last_earned == 1, "continued score pays only uncredited delta")
	main._on_double()
	old_double.call_deferred(true)
	await settle(main)
	check(main._ad_pending and p.crystals == 9, "older result receipt cannot consume or pay newer same-game reward")
	ad.resolve_reward(true)
	await settle(main)
	check(p.crystals == 10, "new result delta can be doubled exactly once")
	# Change the result while a video is outstanding, without changing game generation.
	main.last_earned = 2
	main._on_double()
	var stale: Callable = ad.pending_reward
	main._resume_play()
	main.score = 600
	main.keeper.score = 600
	main.end_game("time")
	var before: int = p.crystals
	stale.call_deferred(true)
	await settle(main)
	check(p.crystals == before and main.last_earned == 1 and not main._ad_pending, "new result cancels previous pending reward in same game")
	requests = ad.fullscreen_requests.size()
	main._on_again()
	main._on_again()
	check(ad.fullscreen_requests.size() == requests + 1, "repeated restart sends one fullscreen request")
	main.go_menu()
	ad.resolve_fullscreen()
	await settle(main)
	check(main.state == main.State.MENU and not main._ad_pending, "leaving result cancels fullscreen restart")
	await start(main, "bright", true)
	main.test_day = "2026-10-21"
	var pinned: String = main.daily_run_date
	p.daily_reward_date = "2026-10-13"
	main.score = 600
	main.keeper.score = 600
	ad.authorized = true
	requests = ad.submissions.size()
	main.end_game("time")
	check(ad.submissions.size() == requests and p.daily_reward_date == pinned and main.last_earned == 26, "Daily result uses pinned date/reward without leaderboard submission")
	before = p.crystals
	main._on_double()
	ad.resolve_reward(true)
	await settle(main)
	check(p.crystals == before + 26, "Daily score plus daily reward doubled once")
	ad.authorized = false
	main.go_menu()
	check(not ad.writes.is_empty(), "save/progress writes captured only by fixture")

func other_ads(main) -> void:
	var ad = main.get_node("/root/Yandex")
	var p = main.get_node("/root/Progress")
	await start(main, "classic")
	main.logic.load_cells(3, 1, PackedInt32Array([0, -1, 1]))
	main.score = 200
	main.keeper.score = 200
	main.end_game("stuck")
	var crystals: int = p.crystals
	var counters: Dictionary = p.life.duplicate(true)
	var requests: int = ad.reward_requests.size()
	main._on_shuffle()
	main._on_shuffle()
	check(ad.reward_requests.size() == requests + 1, "repeated shuffle sends one rewarded request")
	ad.resolve_reward(false)
	await settle(main)
	check(not main.used_shuffle and main.state == main.State.OVER and p.crystals == crystals, "failed shuffle changes no game/rewards")
	main._on_shuffle()
	var done: Callable = ad.pending_reward
	ad.resolve_reward(true)
	await settle(main)
	check(main.used_shuffle and main.state == main.State.OVER and not main.result.get_node("%Shuffle").visible,
		"unsolvable shuffle result hides spent action without creating another result")
	check(p.crystals == crystals and p.life == counters, "shuffle never repays unchanged score or game counters")
	done.call_deferred(true)
	await settle(main)
	check(p.crystals == crystals, "duplicate shuffle callback ignored")
	main.go_menu()
	await start(main, "levels")
	main.time_left = 0
	main.end_game("time")
	var cells: PackedInt32Array = main.logic.cells.duplicate()
	requests = ad.reward_requests.size()
	main._on_level_continue()
	main._on_level_continue()
	check(ad.reward_requests.size() == requests + 1, "hidden level continue request serialized")
	done = ad.pending_reward
	ad.resolve_reward(true)
	await settle(main)
	check(main.state == main.State.PLAYING and main.used_continue and main.time_left == 15 and main.logic.cells == cells,
		"hidden level time continue preserves board and gives fifteen seconds")
	done.call_deferred(true)
	await settle(main)
	check(main.time_left == 15, "hidden level duplicate continue cannot refill time")
	main.go_menu()
	await start(main, "bright")
	main.end_game("time")
	var generation: int = main._game_generation
	requests = ad.fullscreen_requests.size()
	main._on_again()
	main._on_again()
	done = ad.pending_fullscreen
	ad.resolve_fullscreen()
	await settle(main, 20)
	check(ad.fullscreen_requests.size() == requests + 1 and main._game_generation == generation + 1
		and main.state == main.State.PLAYING and main.score == 0 and main.time_left == 120, "fullscreen response starts exactly one new Run")
	done.call_deferred(true)
	await settle(main)
	check(main._game_generation == generation + 1 and main.time_left == 120, "duplicate fullscreen response never restarts new game")
	var gems: int = int(p.life.get("gems", 0))
	main._report_progress("gems", 2)
	main.go_menu()
	var cfg := ConfigFile.new()
	cfg.load(p.PATH)
	check(int(cfg.get_value("meta", "life", {}).get("gems", 0)) == gems + 2, "leaving game flushes pending progress to isolated file")

func run_suite(main) -> Dictionary:
	if not main.has_node("/root/TestIsolation"):
		return {"error": "Use the isolated test runner."}
	await cosmetics(main)
	await persistence(main)
	await tutorial_state(main)
	await claims(main)
	await rewards(main)
	await other_ads(main)
	return {"checks": checks, "failed": failures.size(), "failures": failures}
