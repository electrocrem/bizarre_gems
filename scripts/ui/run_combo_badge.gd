extends Control
## Original upstream badge paint and timing, fitted inside an invariant reserved slot.
const PULSE_SCALE := 1.35
const PULSE_SECONDS := .3
const FADE_SECONDS := .35
@onready var panel: PanelContainer = $Fit/Panel
@onready var label: Label = $Fit/Panel/VBox/Mult
@onready var bar: ProgressBar = $Fit/Panel/VBox/ComboBar
var _pulse: Tween
var _fade: Tween

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_fit)
	panel.minimum_size_changed.connect(_fit)
	_fit.call_deferred()

func _fit() -> void:
	var extent := panel.get_combined_minimum_size()
	var fit := minf(1, minf(size.x/maxf(1,extent.x*PULSE_SCALE),size.y/maxf(1,extent.y*PULSE_SCALE)))
	# Fit is applied by a separate parent; the original panel still pulses exactly 1.35.
	$Fit.scale = Vector2.ONE*fit
	$Fit.position = (size-extent*fit)*.5
	panel.size = extent
	panel.pivot_offset = extent*.5

func show_combo(streak: int, multiplier: int, pulse: bool) -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	if streak < 2:
		panel.modulate.a = 0
		return
	label.text = "%s ×%d · %d" % [L.t("combo").to_upper(),multiplier,streak]
	(panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = UiKit.COMBO_COLORS[clampi(multiplier,1,4)-1]
	panel.modulate.a = 1
	_fit()
	if pulse:
		if _pulse and _pulse.is_valid():
			_pulse.kill()
		panel.scale = Vector2.ONE*PULSE_SCALE
		_pulse = create_tween()
		_pulse.tween_property(panel,"scale",Vector2.ONE,PULSE_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func fade_combo() -> void:
	if _fade and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(panel,"modulate:a",0,FADE_SECONDS)

func reset() -> void:
	for tween in [_pulse,_fade]:
		if tween and tween.is_valid():
			tween.kill()
	panel.scale = Vector2.ONE
	panel.modulate.a = 0
