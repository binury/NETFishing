class_name BubbleContentShell
extends PanelContainer

@export var profile: BubbleMenuProfile
@export_range(0.0, 96.0, 1.0) var content_margin: float = 24.0
@export_range(0, 512, 1) var corner_radius: int = 72
@export_range(0, 12, 1) var border_width: int = 3

var _background_visible: bool = true


func _ready() -> void:
	apply_profile()


func apply_profile() -> void:
	if profile == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = profile.normal_fill
	style.border_color = profile.normal_border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	add_theme_stylebox_override("panel", style)


func set_background_visible(background_visible: bool) -> void:
	_background_visible = background_visible
	if not is_node_ready() or profile == null:
		return
	if _background_visible:
		apply_profile()
		return
	var transparent_style := StyleBoxEmpty.new()
	transparent_style.content_margin_left = content_margin
	transparent_style.content_margin_top = content_margin
	transparent_style.content_margin_right = content_margin
	transparent_style.content_margin_bottom = content_margin
	add_theme_stylebox_override("panel", transparent_style)
