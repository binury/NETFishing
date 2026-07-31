class_name OrganizerTab
extends Button

const INACTIVE_COLOR := Color("d6b875")
const SELECTED_COLOR := Color("f0d995")
const BORDER_COLOR := Color("4c3a25")
const TEXT_COLOR := Color("251b10")
const DISABLED_COLOR := Color("aa9a76")
const RISE_DURATION: float = UIMotion.UTILITY_ENTER_DURATION
const INACTIVE_SETTLE_Y: float = 8.0
const SELECTED_SETTLE_Y: float = 0.0
const HOVER_SETTLE_Y: float = 4.0
const HIDDEN_SETTLE_Y: float = 30.0

var _motion_tween: Tween
var _hovered: bool = false
var _motion_ready: bool = false
var _visual_y: float = INACTIVE_SETTLE_Y


func _ready() -> void:
	toggle_mode = true
	add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	add_theme_font_size_override("font_size", 18)
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


func _on_toggled(_pressed: bool) -> void:
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
	var base_color: Color = SELECTED_COLOR if button_pressed else INACTIVE_COLOR
	var border_width: int = 2
	var shadow_alpha: float = 0.28
	if disabled:
		base_color = DISABLED_COLOR
		border_width = 1
		shadow_alpha = 0.12
	elif has_focus():
		base_color = base_color.lightened(0.09)
		border_width = 4
		shadow_alpha = 0.40
	elif _hovered:
		base_color = base_color.lightened(0.07)
		border_width = 3
		shadow_alpha = 0.34
	var visual_rect := Rect2(Vector2(0.0, _visual_y), size)
	draw_style_box(
		_make_style(base_color, border_width, shadow_alpha),
		visual_rect,
	)
	var font: Font = UtilityPageStyle.TuffyFont
	var ink: Color = Color(TEXT_COLOR, 0.52) if disabled else TEXT_COLOR
	draw_string(
		font,
		Vector2(0.0, _visual_y + 32.0),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		18,
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


func _make_style(fill: Color, border_width: int, shadow_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = BORDER_COLOR
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = 1
	style.corner_radius_top_left = 13
	style.corner_radius_top_right = 13
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.shadow_color = Color(0.12, 0.08, 0.04, shadow_alpha)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0.0, 3.0)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 12.0
	return style


func _cancel_motion() -> void:
	if _motion_tween != null:
		_motion_tween.kill()
		_motion_tween = null


func _clear_motion_tween() -> void:
	_motion_tween = null
