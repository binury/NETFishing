class_name NotepadInkOutline
extends Control

@export var ink_color := Color(0.20, 0.17, 0.13, 0.9)
@export_range(0.5, 6.0, 0.1) var stroke_width: float = 2.0
@export_range(0.0, 16.0, 0.5) var padding: float = 3.0
@export_range(0, 1000000, 1) var shape_seed: int = 17

var _mark_strength: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_mark_strength(strength: float) -> void:
	_mark_strength = clampf(strength, 0.0, 1.0)
	visible = _mark_strength > 0.001
	queue_redraw()


func _draw() -> void:
	if _mark_strength <= 0.001:
		return
	var center: Vector2 = size * 0.5
	var radius := Vector2(
		maxf(size.x * 0.5 - padding, 1.0),
		maxf(size.y * 0.5 - padding, 1.0),
	)
	var primary := _build_rough_loop(center, radius, 0)
	var secondary := _build_rough_loop(
		center + Vector2(0.7, -0.45),
		radius - Vector2(1.2, 0.8),
		41,
	)
	var primary_color: Color = ink_color
	primary_color.a *= _mark_strength
	var secondary_color: Color = ink_color
	secondary_color.a *= _mark_strength * 0.36
	draw_polyline(primary, primary_color, stroke_width, true)
	draw_polyline(secondary, secondary_color, maxf(stroke_width * 0.62, 0.8), true)


func _build_rough_loop(
	center: Vector2,
	radius: Vector2,
	seed_offset: int,
) -> PackedVector2Array:
	const POINT_COUNT: int = 26
	var points := PackedVector2Array()
	for index: int in POINT_COUNT:
		var angle: float = TAU * float(index) / float(POINT_COUNT)
		var wobble: float = (
			sin(float(shape_seed + seed_offset) * 0.73 + float(index) * 2.17)
			+ sin(float(shape_seed + seed_offset) * 0.31 + float(index) * 4.03)
				* 0.45
		)
		var radial_scale: float = 1.0 + wobble * 0.018
		points.append(
			center
			+ Vector2(cos(angle), sin(angle)) * radius * radial_scale
		)
	points.append(points[0])
	return points
