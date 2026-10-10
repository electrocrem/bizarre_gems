extends Screen
## Lifetime statistics. The rows are in scenes/ui/stats.tscn; each value label is named after
## its key without "stat_" (stat_games -> %Games).


func refresh() -> void:
	var life: Dictionary = Progress.life
	var games := 0
	var fav := ""
	var fav_n := 0
	for id in ["classic", "bright", "zen", "levels", "puzzle"]:
		var n := int(life.get("games_" + id, 0))
		games += n
		if n > fav_n:
			fav_n = n
			fav = id
	%Games.text = str(games)
	%Fav.text = L.t("mode_" + fav) if fav != "" else "—"
	%Time.text = L.t("stat_minutes", {"n": int(life.get("play_secs", 0)) / 60})
	%Gems.text = str(int(life.get("gems", 0)))
	%Boards.text = str(int(life.get("clear_boards", 0)))
	%Combo.text = str(int(life.get("max_combo", 0)))
	%Perfects.text = str(int(life.get("perfects", 0)))
	%Levels.text = str(Progress.max_unlocked() - 1)
	%Stars.text = str(Progress.total_stars())
	%Puzzles.text = str(Progress.puzzles)
	%Dailies.text = str(int(life.get("dailies", 0)))
	%Best.text = str(maxi(Save.best, maxi(Save.best_bright, Save.best_zen)))


func _on_close_pressed() -> void:
	click()
	navigate.emit(&"back")
