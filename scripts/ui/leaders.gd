extends Screen
## Leaderboards: Yandex Games' tables, or this device's own best results without Yandex.

## sent after a successful login: the player's best for the table of the mode they play
signal login_done

const BOARDS := ["score", "score_bright", "score_zen", "stars"]
const ROW := preload("res://scenes/ui/parts/leader_row.tscn")

var board := "score"


func _ready() -> void:
	for i in BOARDS.size():
		var b: Button = %Tabs.get_child(i)
		var k: String = BOARDS[i]
		b.pressed.connect(func():
			board = k
			click()
			refresh())


func refresh() -> void:
	for i in BOARDS.size():
		(%Tabs.get_child(i) as Button).theme_type_variation = &"PrimaryButton" if BOARDS[i] == board else &""
	UiKit.clear(%List)
	%Login.visible = false
	%Status.visible = true
	if not Yandex.available:
		var top := Progress.local_top(board)
		%Status.text = L.t("leaders_local") if not top.is_empty() else L.t("leaders_local_empty")
		for i in top.size():
			_add_row(i + 1, str(top[i].date), int(top[i].score), i == 0)
		return
	%Status.text = L.t("leaders_loading")
	var asked := board
	Yandex.fetch_leaderboard(func(res: Dictionary):
		if asked != board:
			return  # another tab was picked meanwhile
		var entries: Array = res.get("entries", [])
		%Status.visible = entries.is_empty()
		%Status.text = L.t("leaders_empty")
		%Login.visible = not Yandex.is_authorized()
		for e in entries:
			_add_row(int(e.get("rank", 0)), str(e.get("name", "")), int(e.get("score", 0)), bool(e.get("me", false))), board)


func _add_row(rank: int, player: String, score: int, me: bool) -> void:
	var row := ROW.instantiate()
	%List.add_child(row)
	row.setup(rank, player, score, me)
	relayout_requested.emit()


func fit(avail: float) -> void:
	%Scroll.custom_minimum_size.y = 0
	var fixed := get_combined_minimum_size().y
	# wrapped text overstates its minimum height until laid out, so prefer the real height
	var want: float = %List.size.y if %List.size.y > 0.0 else %List.get_combined_minimum_size().y
	%Scroll.custom_minimum_size.y = clampf(avail - fixed, 80.0, maxf(80.0, want))


func _on_login_pressed() -> void:
	Yandex.open_auth(func(ok: bool):
		if ok:
			login_done.emit()
			refresh())


func _on_close_pressed() -> void:
	click()
	navigate.emit(&"back")
