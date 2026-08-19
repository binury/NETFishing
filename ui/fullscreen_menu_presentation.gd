class_name FullscreenMenuPresentation
extends RefCounted

const UIReferencePresentationType = preload(
	"res://ui/ui_reference_presentation.gd"
)

const WIDE_REFERENCE_SIZE: Vector2 = Vector2(1280.0, 720.0)
const COMPACT_REFERENCE_SIZE: Vector2 = Vector2(960.0, 720.0)
const COMPACT_MAX_ASPECT: float = 1.5
const COMPACT_SOURCE_RECT := Rect2(160.0, 0.0, 960.0, 720.0)


static func uses_compact_profile(display_size: Vector2) -> bool:
	if display_size.x <= 0.0 or display_size.y <= 0.0:
		return false
	return display_size.aspect() <= COMPACT_MAX_ASPECT


static func get_profile_scale(display_size: Vector2) -> float:
	if not uses_compact_profile(display_size):
		return 1.0
	var wide_scale: float = UIReferencePresentationType.get_scale(display_size)
	var compact_scale: float = minf(
		display_size.x / COMPACT_REFERENCE_SIZE.x,
		display_size.y / COMPACT_REFERENCE_SIZE.y,
	)
	return compact_scale / wide_scale


static func get_profile_position(display_size: Vector2) -> Vector2:
	if not uses_compact_profile(display_size):
		return Vector2.ZERO
	var wide_scale: float = UIReferencePresentationType.get_scale(display_size)
	var compact_scale: float = minf(
		display_size.x / COMPACT_REFERENCE_SIZE.x,
		display_size.y / COMPACT_REFERENCE_SIZE.y,
	)
	var profile_scale: float = compact_scale / wide_scale
	var wide_offset: Vector2 = UIReferencePresentationType.get_offset(
		display_size
	)
	var compact_offset: Vector2 = (
		display_size - COMPACT_REFERENCE_SIZE * compact_scale
	) * 0.5
	return (
		(compact_offset - wide_offset) / wide_scale
		- COMPACT_SOURCE_RECT.position * profile_scale
	)


static func get_source_rect(display_size: Vector2) -> Rect2:
	return (
		COMPACT_SOURCE_RECT
		if uses_compact_profile(display_size)
		else Rect2(Vector2.ZERO, WIDE_REFERENCE_SIZE)
	)
