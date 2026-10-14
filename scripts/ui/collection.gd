extends Screen
## Tile packs: buy with crystals, pick the one the bright modes use.

const CARD := preload("res://scenes/ui/parts/look_card.tscn")


func refresh() -> void:
	if not Progress.COSMETICS_ENABLED:
		return
	%Crystals.text = str(Progress.crystals)
	UiKit.clear(%Grid)
	for i in Progress.LOOK_PRICES.size():
		var price := int(Progress.LOOK_PRICES[i])
		var card := CARD.instantiate()
		%Grid.add_child(card)
		if Progress.look == i:
			card.setup(i, L.t("selected"), null, false, false)
		elif not Progress.owns(i) and price == Progress.SEASON:
			var now := Progress.season_look() == i  # a seasonal pack is free in its season
			card.setup(i, L.t("season_claim" if now else "season_only"), UiKit.icon("gift") if now else null, now, now)
		elif not Progress.owns(i) and price == Progress.GIFT:
			card.setup(i, L.t("gift_only"), null, false, false)
		elif Progress.owns(i):
			card.setup(i, L.t("select"), null, false, true)
		else:
			card.setup(i, str(price), UiKit.icon("crystal"), true, Progress.crystals >= price)
		card.action_pressed.connect(_on_card)
	relayout_requested.emit()


func _on_card(i: int) -> void:
	if not Progress.COSMETICS_ENABLED:
		return
	if Progress.owns(i):
		Progress.select(i)
		click()
	elif int(Progress.LOOK_PRICES[i]) == Progress.SEASON:
		Progress.claim_season()
		Sfx.play("star")
	elif Progress.buy(i):
		Sfx.play("star")
	else:
		toast.emit(L.t("not_enough"))
	refresh()


func _on_close_pressed() -> void:
	click()
	navigate.emit(&"back")
