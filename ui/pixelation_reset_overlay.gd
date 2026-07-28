class_name PixelationResetOverlay
extends CanvasLayer

const DISPLAY_REFERENCE_SIZE: Vector2 = Vector2(1280.0, 720.0)
const MINIMUM_PRESENTATION_SCALE: float = 0.90
const MAXIMUM_PRESENTATION_SCALE: float = 1.35
const LARGE_DISPLAY_GROWTH: float = 0.45
const SCREEN_MARGIN: float = 16.0
const FADE_DURATION: float = 0.55

signal reset_requested
signal return_to_settings_requested

@onready var _presentation_root: Control = %ResetPresentationRoot
@onready var _reset_button: Button = %ResetPixelationButton

var _fade_tween: Tween
var _fade_generation: int = 0
var _settings_open: bool = false


func _ready() -> void:
	_reset_button.pressed.connect(reset_requested.emit)
	_reset_button.gui_input.connect(_on_reset_button_gui_input)
	get_viewport().size_changed.connect(_update_responsive_layout)
	_presentation_root.modulate.a = 0.0
	_set_interactive(false)
	_update_responsive_layout()


func set_settings_open(is_open: bool) -> void:
	_settings_open = is_open
	_fade_generation += 1
	if _fade_tween != null:
		_fade_tween.kill()
		_fade_tween = null
	if is_open:
		show()
		_set_interactive(true)
	else:
		_set_interactive(false)
	var target_alpha: float = 1.0 if is_open else 0.0
	if is_equal_approx(_presentation_root.modulate.a, target_alpha):
		_finish_fade(_fade_generation, is_open)
		return
	var generation: int = _fade_generation
	_fade_tween = create_tween()
	_fade_tween.tween_property(
		_presentation_root,
		"modulate:a",
		target_alpha,
		FADE_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_fade_tween.finished.connect(
		_finish_fade.bind(generation, is_open),
		CONNECT_ONE_SHOT
	)


func focus_reset_button() -> void:
	if visible and _settings_open:
		_reset_button.grab_focus()


func _on_reset_button_gui_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("ui_up")
		or event.is_action_pressed("ui_focus_prev")
	):
		return_to_settings_requested.emit()
		get_viewport().set_input_as_handled()


func _update_responsive_layout() -> void:
	if not is_node_ready():
		return
	var display_size: Vector2 = Vector2(get_window().size)
	if display_size.x <= 1.0 or display_size.y <= 1.0:
		return
	var responsive_scale: float = minf(
		display_size.x / DISPLAY_REFERENCE_SIZE.x,
		display_size.y / DISPLAY_REFERENCE_SIZE.y
	)
	var presentation_scale: float
	if responsive_scale < 1.0:
		presentation_scale = lerpf(
			MINIMUM_PRESENTATION_SCALE,
			1.0,
			clampf((responsive_scale - 0.5) / 0.5, 0.0, 1.0)
		)
	else:
		presentation_scale = minf(
			MAXIMUM_PRESENTATION_SCALE,
			1.0 + (responsive_scale - 1.0) * LARGE_DISPLAY_GROWTH
		)
	_presentation_root.scale = Vector2.ONE * presentation_scale
	_presentation_root.position = (
		display_size
		- _presentation_root.size * presentation_scale
		- Vector2.ONE * SCREEN_MARGIN
	)


func _set_interactive(interactive: bool) -> void:
	if not interactive and _reset_button.has_focus():
		_reset_button.release_focus()
	_reset_button.focus_mode = (
		Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
	)
	_reset_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if interactive
		else Control.MOUSE_FILTER_IGNORE
	)


func _finish_fade(generation: int, faded_in: bool) -> void:
	if generation != _fade_generation or faded_in != _settings_open:
		return
	_fade_tween = null
	_presentation_root.modulate.a = 1.0 if faded_in else 0.0
	if not faded_in:
		hide()
