class_name BubbleInformationPanel
extends PanelContainer

@export var profile: BubbleMenuProfile
@export_range(0.0, 96.0, 1.0) var content_margin: float = 20.0
@export_range(0, 512, 1) var corner_radius: int = 96


func _ready() -> void:
	if profile == null:
		return
	var style: StyleBoxFlat = profile.make_normal_style()
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	add_theme_stylebox_override("panel", style)
