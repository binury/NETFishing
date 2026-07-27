class_name BubbleMenuProfile
extends Resource

@export_group("Typography")
@export_range(0.01, 1.0, 0.001) var font_size_ratio: float = 0.17

@export_group("Interaction")
@export_range(1.0, 1.2, 0.001) var hover_focus_scale: float = 1.035
@export_range(0.0, 16.0, 0.1) var hover_focus_lift: float = 2.0
@export_range(0.1, 30.0, 0.1) var emphasis_speed: float = 10.0
@export_range(0.0, 1.0, 0.01) var emphasized_deformation_scale: float = 0.6

@export_group("Cluster")
@export_range(0.1, 30.0, 0.1) var position_response: float = 8.0
@export_range(0.0, 24.0, 0.1) var contact_gap: float = 3.0
@export_range(0.0, 24.0, 0.1) var maximum_separation: float = 3.0

@export_group("Shape")
@export_range(0.0, 32.0, 0.5) var content_margin: float = 8.0
@export_range(0, 512, 1) var corner_radius: int = 128
@export_range(0, 12, 1) var normal_border_width: int = 2
@export_range(0, 12, 1) var emphasized_border_width: int = 3

@export_group("Colors")
@export var normal_fill: Color = Color(0.82, 0.93, 0.96, 0.96)
@export var normal_border: Color = Color(0.91, 0.98, 1.0, 0.85)
@export var hover_fill: Color = Color(0.91, 0.975, 0.985, 1.0)
@export var hover_border: Color = Color(1.0, 1.0, 1.0, 0.95)
@export var pressed_fill: Color = Color(0.7, 0.87, 0.92, 1.0)
@export var pressed_border: Color = Color(0.94, 0.99, 1.0, 1.0)
@export var disabled_fill: Color = Color(0.66, 0.77, 0.8, 0.78)
@export var disabled_border: Color = Color(0.81, 0.9, 0.92, 0.55)
@export var text_color: Color = Color(0.035, 0.145, 0.22, 1.0)
@export var text_hover_color: Color = Color(0.025, 0.12, 0.19, 1.0)
@export var text_pressed_color: Color = Color(0.025, 0.11, 0.17, 1.0)
@export var text_disabled_color: Color = Color(0.16, 0.25, 0.29, 0.72)


func make_normal_style() -> StyleBoxFlat:
	return _make_style(
		normal_fill,
		normal_border,
		normal_border_width
	)


func make_hover_style() -> StyleBoxFlat:
	return _make_style(
		hover_fill,
		hover_border,
		emphasized_border_width
	)


func make_pressed_style() -> StyleBoxFlat:
	return _make_style(
		pressed_fill,
		pressed_border,
		emphasized_border_width
	)


func make_disabled_style() -> StyleBoxFlat:
	return _make_style(
		disabled_fill,
		disabled_border,
		normal_border_width
	)


func _make_style(
	fill_color: Color,
	outline_color: Color,
	outline_width: int,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	style.bg_color = fill_color
	style.border_width_left = outline_width
	style.border_width_top = outline_width
	style.border_width_right = outline_width
	style.border_width_bottom = outline_width
	style.border_color = outline_color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	return style
