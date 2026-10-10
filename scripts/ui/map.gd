extends Screen
## The level map (chapters of 20 levels) or the puzzle list. Unlocked ones first, then a few locked.

signal level_chosen(n: int)
signal puzzle_chosen(n: int)

const CELL := preload("res://scenes/ui/parts/map_cell.tscn")
const HEADER := preload("res://scenes/ui/parts/chapter_header.tscn")

## "levels" or "puzzle"
var kind := "levels"


func refresh() -> void:
	UiKit.clear(%List)
	var puzzles := kind == "puzzle"
	var top := Progress.puzzles + 1 if puzzles else Progress.max_unlocked()
	var shown := int(ceil((top + 10) / 5.0)) * 5
	%Title.text = L.t("mode_puzzle" if puzzles else "mode_levels")
	%Stars.text = str(Progress.puzzles) if puzzles else str(Progress.total_stars())
	%StarIcon.texture = UiKit.icon("check" if puzzles else "star")
	if puzzles:
		%List.add_child(_grid(1, shown, top))
		return
	var csz := BoardLogic.CHAPTER_SIZE
	for c in BoardLogic.chapter_of(shown) + 1:
		var head := HEADER.instantiate()
		%List.add_child(head)
		head.setup(c, UiKit.CHAPTER_THEMES[c % UiKit.CHAPTER_THEMES.size()].top)
		head.reward_claimed.connect(func(n: int):
			Sfx.play("level")
			toast.emit(L.t("chapter_reward", {"n": n}))
			refresh())
		%List.add_child(_grid(c * csz + 1, mini((c + 1) * csz, shown), top))


func _grid(from: int, to: int, top: int) -> GridContainer:
	var puzzles := kind == "puzzle"
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	for n in range(from, to + 1):
		var cell := CELL.instantiate()
		grid.add_child(cell)
		var marks := (4 if n <= Progress.puzzles else -1) if puzzles else Progress.stars_for(n)
		cell.setup(n, n > top, n == top, n % 10 == 0 and not puzzles, marks)
		cell.chosen.connect(func(lvl: int):
			click()
			if puzzles:
				puzzle_chosen.emit(lvl)
			else:
				level_chosen.emit(lvl))
	return grid


func _on_back_pressed() -> void:
	click()
	navigate.emit(&"back")
