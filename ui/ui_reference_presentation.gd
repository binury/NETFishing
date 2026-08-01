class_name UIReferencePresentation
extends RefCounted

# All functional UI is authored in this coordinate system and receives one
# centered, uniform transform at presentation time. Texture source dimensions
# describe sampling quality and aspect ratio; a canonical Control rect owns
# every texture's on-screen layout size.
#
# Edge-docked overlays use the same canonical units and uniform scale, but may
# use the extra logical canvas outside the centered stage on non-16:9 windows.
# This keeps deliberate window-edge attachment without letting individual
# controls calculate monitor- or DPI-specific geometry.
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


static func get_visible_reference_size(display_size: Vector2) -> Vector2:
	return display_size / get_scale(display_size)


static func get_stage_position(display_size: Vector2) -> Vector2:
	return (get_visible_reference_size(display_size) - REFERENCE_SIZE) * 0.5


static func get_rect(display_size: Vector2) -> Rect2:
	var presentation_scale: float = get_scale(display_size)
	return Rect2(
		get_offset(display_size),
		REFERENCE_SIZE * presentation_scale,
	)
