class_name UIReferencePresentation
extends RefCounted

const REFERENCE_SIZE: Vector2 = Vector2(1280.0, 720.0)


static func get_scale(display_size: Vector2) -> float:
	return minf(
		maxf(display_size.x, 1.0) / REFERENCE_SIZE.x,
		maxf(display_size.y, 1.0) / REFERENCE_SIZE.y,
	)


static func get_offset(display_size: Vector2) -> Vector2:
	var presentation_scale: float = get_scale(display_size)
	return (
		display_size - REFERENCE_SIZE * presentation_scale
	) * 0.5


static func get_rect(display_size: Vector2) -> Rect2:
	var presentation_scale: float = get_scale(display_size)
	return Rect2(
		get_offset(display_size),
		REFERENCE_SIZE * presentation_scale,
	)
