class_name Hud
extends BoxContainer
## The in-game bar: score, best, time (or moves), the combo badge and the buttons.
## Two layouts share this script: scenes/game/hud_classic.tscn (the first version's look) and
## scenes/game/hud_bright.tscn (big score). main.gd shows the one for the current mode.

signal pause_pressed
signal restart_pressed
signal settings_pressed
signal hint_pressed

@export var skin := "bright"

@onready var score_label: Label = %Score
@onready var best_label: Label = %Best
@onready var time_label: Label = %Time
@onready var time_bar: ProgressBar = %TimeBar
@onready var time_delta: Label = %Delta
@onready var combo_box: PanelContainer = %Combo
@onready var combo_mult: Label = %Mult
@onready var combo_count: Label = %Count
@onready var combo_bar: ProgressBar = %ComboBar
@onready var btn_pause: Button = %Pause
@onready var btn_restart: Button = %Restart
@onready var btn_settings: Button = %Settings
@onready var btn_hint: Button = get_node_or_null("%Hint")      ## bright only
@onready var level_label: Label = get_node_or_null("%Level")   ## bright only
@onready var title_label: Label = get_node_or_null("%Title")   ## classic only


func _ready() -> void:
	if OS.has_feature("mobile") or DisplayServer.is_touchscreen_available():
		# phones: settings next to pause, restart out on the edge, away from it
		var row := btn_settings.get_parent()
		row.move_child(btn_settings, 1)
		row.move_child(btn_restart, -1)


func layout(view: Vector2, compact: bool) -> void:
	combo_box.custom_minimum_size.x = 64 if compact else 96
	if title_label:
		title_label.visible = view.x >= 980
		add_theme_constant_override("separation", 10 if compact else 18)
	else:
		%Top.add_theme_constant_override("separation", 10 if compact else 22)


## Time left (or moves) as text, the bar from 0 to 1; `low` turns both red.
func set_time(text: String, fraction: float, low: bool) -> void:
	time_label.text = text
	time_label.add_theme_color_override("font_color", UiKit.DANGER if low else UiKit.CREAM)
	time_bar.theme_type_variation = &"ProgressBarLow" if low else &""
	time_bar.value = clampf(fraction, 0.0, 1.0) * 100.0


func set_buttons(playing: bool, can_restart: bool) -> void:
	btn_pause.disabled = not playing
	btn_restart.disabled = not can_restart


## The combo badge: hidden below a streak of 2; `pulse` bumps it when the multiplier goes up.
func set_combo(streak: int, pulse := false) -> void:
	if streak < 2:
		combo_box.modulate.a = 0.0
		return
	var m := ScoreKeeper.multiplier_for(streak)
	var color: Color = UiKit.COMBO_COLORS[clampi(m, 1, 4) - 1]
	combo_count.text = L.t("combo_count", {"n": streak})
	if skin == "classic":
		combo_mult.text = "×%d" % m
		combo_mult.add_theme_color_override("font_color", color.lightened(0.3))
	else:
		combo_mult.text = "%s ×%d · %d" % [L.t("combo").to_upper(), m, streak]
		(combo_box.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = color
	combo_box.modulate.a = 1.0
	if pulse:
		combo_box.pivot_offset = combo_box.size / 2
		combo_box.scale = Vector2.ONE * 1.35
		create_tween().tween_property(combo_box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func fade_combo() -> void:
	create_tween().tween_property(combo_box, "modulate:a", 0.0, 0.35)


## "+3 s" / "−1 s" next to the clock (unit "steps" for the moves mode).
func flash_delta(text: String, negative: bool, unit := "time") -> void:
	if unit == "steps":
		time_delta.text = text + " " + L.t("steps_unit")
	else:
		time_delta.text = text + (" с" if L.lang == "ru" else (" sn" if L.lang == "tr" else " s"))
	time_delta.add_theme_color_override("font_color", UiKit.DANGER if negative else UiKit.BRASS)
	time_delta.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(time_delta, "modulate:a", 0.0, 0.4)


## Little scale bump for a number.
func pop(c: Control, k := 1.25) -> void:
	c.pivot_offset = Vector2(0, c.size.y / 2)
	c.scale = Vector2.ONE * k
	create_tween().tween_property(c, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_pause_pressed() -> void:
	Sfx.play("click")
	pause_pressed.emit()


func _on_restart_pressed() -> void:
	Sfx.play("click")
	restart_pressed.emit()


func _on_settings_pressed() -> void:
	settings_pressed.emit()


func _on_hint_pressed() -> void:
	hint_pressed.emit()
