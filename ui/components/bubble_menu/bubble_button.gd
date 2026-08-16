class_name BubbleButton
extends Button

const ICON_FILL_RATIO: float = 0.76

@export var profile: BubbleMenuProfile

@export_group("Authored Layout")
@export var neutral_size: Vector2 = Vector2(120.0, 116.0)
@export var desktop_anchor: Vector2 = Vector2.ZERO
@export var compact_anchor: Vector2 = Vector2.ZERO
@export var compact_minimum_size: Vector2 = Vector2.ZERO

@export_group("Typography")
@export var label_control_path: NodePath
@export_range(1, 256, 1) var minimum_font_size: int = 14
@export_range(1, 256, 1) var maximum_font_size: int = 32

@export_group("Motion")
@export_range(0.0, 32.0, 0.1) var horizontal_amplitude: float = 1.8
@export_range(0.0, 32.0, 0.1) var vertical_amplitude: float = 4.0
@export_range(0.1, 30.0, 0.1) var motion_period: float = 5.0
@export_range(0.0, TAU, 0.01) var motion_phase: float = 0.0
@export_range(0.0, 0.2, 0.001) var deformation_amplitude: float = 0.016
@export_range(0.1, 30.0, 0.1) var deformation_period: float = 6.0

var neutral_position: Vector2 = Vector2.ZERO
var presented_size: Vector2 = Vector2.ZERO
var emphasis: float = 0.0
var _hovered: bool = false


func _ready() -> void:
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	resized.connect(_update_pivot)
	_update_pivot()
	apply_profile()
	_apply_icon_presentation(neutral_size)


func _gui_input(event: InputEvent) -> void:
	if _adjustment_direction(self) == 0:
		return
	var direction: int = 0
	if event.is_action_pressed(&"ui_left"):
		direction = -1
	elif event.is_action_pressed(&"ui_right"):
		direction = 1
	if direction == 0:
		return
	var adjustment_button: BaseButton = _find_adjustment_button(direction)
	if adjustment_button == null:
		return
	adjustment_button.pressed.emit()
	accept_event()


func _find_adjustment_button(direction: int) -> BaseButton:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return null
	for child: Node in parent_node.get_children():
		var button := child as BaseButton
		if (
			button != null
			and button.visible
			and not button.disabled
			and _adjustment_direction(button) == direction
		):
			return button
	return null


func _adjustment_direction(button: BaseButton) -> int:
	var descriptions: Array[String] = [
		button.text.strip_edges().to_lower(),
		button.tooltip_text.strip_edges().to_lower(),
		button.accessibility_name.strip_edges().to_lower(),
	]
	for description: String in descriptions:
		if description in ["-", "−", "minus", "decrease"]:
			return -1
		if description in ["+", "plus", "increase"]:
			return 1
	return 0


func apply_layout(
	center: Vector2,
	bubble_size: Vector2,
	font_size_ratio: float,
) -> void:
	position = center - bubble_size * 0.5
	size = bubble_size
	neutral_position = position
	presented_size = bubble_size
	_update_pivot()
	_apply_icon_presentation(bubble_size)
	var label_control: Control = get_label_control()
	var font_size := clampi(
		roundi(minf(bubble_size.x, bubble_size.y) * font_size_ratio),
		minimum_font_size,
		maximum_font_size
	)
	label_control.add_theme_font_size_override("font_size", font_size)


func get_layout_size(layout_scale: float, compact: bool) -> Vector2:
	var bubble_size: Vector2 = neutral_size * layout_scale
	if compact:
		bubble_size.x = maxf(bubble_size.x, compact_minimum_size.x)
		bubble_size.y = maxf(bubble_size.y, compact_minimum_size.y)
	if _uses_icon_only_presentation():
		var diameter: float = maxf(bubble_size.x, bubble_size.y)
		bubble_size = Vector2(diameter, diameter)
	return bubble_size


func get_authored_anchor(compact: bool) -> Vector2:
	return compact_anchor if compact else desktop_anchor


func get_label_control() -> Control:
	if not label_control_path.is_empty():
		var custom_label := get_node_or_null(label_control_path) as Control
		if custom_label != null:
			return custom_label
	return self


func _uses_icon_only_presentation() -> bool:
	return icon != null and text.is_empty() and label_control_path.is_empty()


func _apply_icon_presentation(bubble_size: Vector2) -> void:
	if not _uses_icon_only_presentation():
		return
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	expand_icon = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_theme_constant_override(
		"icon_max_width",
		maxi(1, roundi(minf(bubble_size.x, bubble_size.y) * ICON_FILL_RATIO)),
	)


func advance_emphasis(delta: float) -> void:
	var target: float = 1.0 if _hovered else 0.0
	emphasis = move_toward(
		emphasis,
		target,
		profile.emphasis_speed * delta
	)


func calculate_target(
	elapsed: float,
	layout_scale: float,
	motion_scale: float,
) -> Vector2:
	var phase: float = (
		elapsed / motion_period * TAU
		+ motion_phase
	)
	var idle_offset := Vector2(
		sin(phase * 0.73 + motion_phase) * horizontal_amplitude,
		sin(phase) * vertical_amplitude
	) * layout_scale * motion_scale
	idle_offset.y -= (
		profile.hover_focus_lift
		* emphasis
		* layout_scale
	)
	return neutral_position + idle_offset


func calculate_visual_scale(
	elapsed: float,
	motion_scale: float,
) -> Vector2:
	var deformation_phase: float = (
		elapsed / deformation_period * TAU
		+ motion_phase * 1.37
	)
	var deformation_amount: float = (
		sin(deformation_phase)
		* deformation_amplitude
		* motion_scale
		* lerpf(1.0, profile.emphasized_deformation_scale, emphasis)
	)
	if _uses_icon_only_presentation():
		deformation_amount = 0.0
	var hover_scale: float = lerpf(
		1.0,
		profile.hover_focus_scale,
		emphasis
	)
	return Vector2(
		1.0 + deformation_amount,
		1.0 - deformation_amount
	) * hover_scale


func get_visual_radius(visual_scale: Vector2) -> float:
	var visual_size: Vector2 = presented_size * visual_scale
	return (visual_size.x + visual_size.y) * 0.25


func apply_presentation(
	target_position: Vector2,
	visual_scale: Vector2,
	position_weight: float,
) -> void:
	position = position.lerp(target_position, position_weight)
	scale = visual_scale


func _has_point(point: Vector2) -> bool:
	var radius: Vector2 = size * 0.5
	if radius.x <= 0.0 or radius.y <= 0.0:
		return false
	var normalized: Vector2 = (point - radius) / radius
	return normalized.length_squared() <= 1.0


func _set_hovered(value: bool) -> void:
	_hovered = value


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func apply_profile() -> void:
	if profile == null:
		return
	add_theme_stylebox_override("normal", profile.make_normal_style())
	var hover_style: StyleBoxFlat = profile.make_hover_style()
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("focus", profile.make_normal_style())
	add_theme_stylebox_override("pressed", profile.make_pressed_style())
	add_theme_stylebox_override("disabled", profile.make_disabled_style())
	add_theme_color_override("font_color", profile.text_color)
	add_theme_color_override("font_hover_color", profile.text_hover_color)
	add_theme_color_override("font_focus_color", profile.text_color)
	add_theme_color_override("font_pressed_color", profile.text_pressed_color)
	add_theme_color_override("font_disabled_color", profile.text_disabled_color)
	var label_control: Control = get_label_control()
	if label_control != self:
		label_control.add_theme_color_override("font_color", profile.text_color)
