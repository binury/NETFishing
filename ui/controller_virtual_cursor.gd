class_name ControllerVirtualCursor
extends Control

const CURSOR_SIZE: Vector2 = Vector2(28.0, 28.0)
const OUTER_COLOR: Color = Color(0.02, 0.10, 0.14, 0.96)
const INNER_COLOR: Color = Color(0.34, 0.86, 0.91, 1.0)
const CENTER_COLOR: Color = Color(0.96, 1.0, 1.0, 1.0)


func _ready() -> void:
	size = CURSOR_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	visible = false
	queue_redraw()


func set_pointer_position(pointer_position: Vector2) -> void:
	position = pointer_position - CURSOR_SIZE * 0.5


func _draw() -> void:
	var center: Vector2 = CURSOR_SIZE * 0.5
	draw_circle(center, 8.0, OUTER_COLOR)
	draw_circle(center, 5.0, INNER_COLOR)
	draw_circle(center, 1.75, CENTER_COLOR)
	draw_line(Vector2(center.x, 0.0), Vector2(center.x, 6.0), CENTER_COLOR, 2.0)
	draw_line(
		Vector2(center.x, CURSOR_SIZE.y - 6.0),
		Vector2(center.x, CURSOR_SIZE.y),
		CENTER_COLOR,
		2.0,
	)
	draw_line(Vector2(0.0, center.y), Vector2(6.0, center.y), CENTER_COLOR, 2.0)
	draw_line(
		Vector2(CURSOR_SIZE.x - 6.0, center.y),
		Vector2(CURSOR_SIZE.x, center.y),
		CENTER_COLOR,
		2.0,
	)
