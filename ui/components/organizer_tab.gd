class_name OrganizerTab
extends Button

const PALETTE: Array[Color] = [
	Color("b9deea"),
	Color("3d9ca0"),
	Color("4f9b72"),
]
const TEXT_COLOR := Color("102b35")
const RISE_DURATION: float = UIMotion.UTILITY_ENTER_DURATION
const INACTIVE_SETTLE_Y: float = 7.0
const SELECTED_SETTLE_Y: float = 1.0
const HOVER_SETTLE_Y: float = 5.0
const HIDDEN_SETTLE_Y: float = 30.0
const CAP_HEIGHT: float = 22.0
const FONT_SIZE: int = 15

@export_range(0, 2, 1) var palette_index: int = 0:
	set(value):
		palette_index = clampi(value, 0, PALETTE.size() - 1)
		queue_redraw()

var _motion_tween: Tween
var _hovered: bool = false
var _motion_ready: bool = false
var _visual_y: float = INACTIVE_SETTLE_Y
var _selected: bool = false


func _ready() -> void:
	toggle_mode = true
	_selected = button_pressed
	add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	add_theme_font_size_override("font_size", FONT_SIZE)
	for color_name: StringName in [
		&"font_color",
		&"font_hover_color",
		&"font_focus_color",
		&"font_pressed_color",
		&"font_disabled_color",
	]:
		add_theme_color_override(color_name, Color.TRANSPARENT)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(refresh_state)
	focus_exited.connect(refresh_state)
	toggled.connect(_on_toggled)
	_apply_empty_styles()
	call_deferred("_initialize_motion")


func refresh_state(animate: bool = true) -> void:
	queue_redraw()
	if _motion_ready:
		_move_to_target(animate)


func set_selected(value: bool, animate: bool = true) -> void:
	_selected = value
	set_pressed_no_signal(value)
	refresh_state(animate)


func animate_entrance(delay: float = 0.0) -> void:
	_cancel_motion()
	_motion_ready = true
	_set_visual_y(HIDDEN_SETTLE_Y)
	_motion_tween = create_tween()
	if delay > 0.0:
		_motion_tween.tween_interval(delay)
	_motion_tween.tween_method(
		_set_visual_y, _visual_y, _target_y(), RISE_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_motion_tween.finished.connect(_clear_motion_tween, CONNECT_ONE_SHOT)


func settle_for_close() -> void:
	_cancel_motion()
	if not _motion_ready:
		return
	_motion_tween = create_tween()
	_motion_tween.tween_method(
		_set_visual_y,
		_visual_y,
		HIDDEN_SETTLE_Y,
		UIMotion.UTILITY_EXIT_DURATION,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_motion_tween.finished.connect(_clear_motion_tween, CONNECT_ONE_SHOT)


func _initialize_motion() -> void:
	_motion_ready = true
	_set_visual_y(_target_y())


func _on_toggled(is_pressed: bool) -> void:
	if _selected and not is_pressed:
		# A selected organizer tab is a page marker, not a collapsible toggle.
		# Restore without another signal before any lower-state frame is drawn.
		set_pressed_no_signal(true)
		refresh_state(false)
		return
	_selected = is_pressed
	refresh_state()


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	refresh_state()


func _target_y() -> float:
	if button_pressed:
		return SELECTED_SETTLE_Y
	if _hovered or has_focus():
		return HOVER_SETTLE_Y
	return INACTIVE_SETTLE_Y


func _move_to_target(animate: bool) -> void:
	_cancel_motion()
	if not animate:
		_set_visual_y(_target_y())
		return
	_motion_tween = create_tween()
	_motion_tween.tween_method(
		_set_visual_y, _visual_y, _target_y(), RISE_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_motion_tween.finished.connect(_clear_motion_tween, CONNECT_ONE_SHOT)


func _draw() -> void:
	var base_color: Color = PALETTE[palette_index]
	base_color = (
		base_color.lightened(0.06)
		if button_pressed
		else base_color.darkened(0.07)
	)
	if disabled:
		base_color = base_color.lerp(Color("8a978f"), 0.62)
	elif has_focus():
		base_color = base_color.lightened(0.12)
	elif _hovered:
		base_color = base_color.lightened(0.08)
	var width: float = size.x
	var height: float = size.y
	var points := PackedVector2Array([
		Vector2(10.0, _visual_y),
		Vector2(width - 10.0, _visual_y),
		Vector2(width - 5.0, _visual_y + 5.0),
		Vector2(width - 5.0, _visual_y + 17.0),
		Vector2(width, _visual_y + 26.0),
		Vector2(width, _visual_y + height),
		Vector2(0.0, _visual_y + height),
		Vector2(0.0, _visual_y + 26.0),
		Vector2(5.0, _visual_y + 17.0),
		Vector2(5.0, _visual_y + 5.0),
	])
	draw_colored_polygon(points, base_color)
	var font: Font = UtilityPageStyle.TuffyFont
	var ink: Color = Color(TEXT_COLOR, 0.52) if disabled else TEXT_COLOR
	var baseline: float = _visual_y + CAP_HEIGHT * 0.5 + FONT_SIZE * 0.35
	draw_string(
		font,
		Vector2(0.0, baseline),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		FONT_SIZE,
		ink,
	)


func _apply_empty_styles() -> void:
	for style_name: StringName in [
		&"normal",
		&"hover",
		&"focus",
		&"pressed",
		&"disabled",
	]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())


func _set_visual_y(value: float) -> void:
	_visual_y = value
	queue_redraw()


func _cancel_motion() -> void:
	if _motion_tween != null:
		_motion_tween.kill()
		_motion_tween = null


func _clear_motion_tween() -> void:
	_motion_tween = null
