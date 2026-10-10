class_name Screen
extends Control
## Base for every menu screen and dialog (scenes/ui/*.tscn).
##
## A screen only shows things and reports what the player pressed: it emits `navigate` to open
## another screen and its own signals for game actions (start a game, watch an ad...). The main
## scene (scripts/main.gd) listens and decides what happens. Screens may read the autoloads
## (Save, Progress, L, Sfx, Yandex) directly.

## Open another screen by its node name in snake_case ("tasks", "level_result"...) or one of:
## "back" (what the Back key does), "settings", "leaders", "map", "puzzle_map", "rules".
signal navigate(to: StringName)
## A short message at the bottom of the screen.
signal toast(text: String)
## The content changed size (a list was filled): main fits the dialog to the screen again.
signal relayout_requested

## Full-screen layouts (home, modes, map) arrange themselves; dialogs are centred and scaled to fit.
@export var full_screen := false


## Called right before the screen is shown: fill in fresh data here.
func refresh() -> void:
	pass


## Dialogs with a scrolling list: shrink the list so the dialog fits `avail` px of height.
func fit(_avail: float) -> void:
	pass


## The button that gets keyboard focus when the screen opens (null: the first visible one).
func focus_button() -> Button:
	return null


## Window size changed (`compact`: a small window or phone).
func layout(_view: Vector2, _compact: bool) -> void:
	pass


func click() -> void:
	Sfx.play("click")
