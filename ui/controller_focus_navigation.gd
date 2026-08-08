class_name ControllerFocusNavigation
extends RefCounted

const PERPENDICULAR_WEIGHT: float = 2.5
const MINIMUM_FORWARD_DISTANCE: float = 0.5


static func configure_spatial_neighbors(controls: Array) -> void:
	var candidates: Array[Control] = []
	for item: Variant in controls:
		var control := item as Control
		if control == null or not control.is_visible_in_tree():
			continue
		candidates.append(control)
	for control: Control in candidates:
		control.focus_neighbor_left = _neighbor_path(
			control, candidates, Vector2.LEFT
		)
		control.focus_neighbor_right = _neighbor_path(
			control, candidates, Vector2.RIGHT
		)
		control.focus_neighbor_top = _neighbor_path(
			control, candidates, Vector2.UP
		)
		control.focus_neighbor_bottom = _neighbor_path(
			control, candidates, Vector2.DOWN
		)


static func _neighbor_path(
	origin: Control,
	candidates: Array[Control],
	direction: Vector2,
) -> NodePath:
	var origin_center: Vector2 = origin.get_global_rect().get_center()
	var best: Control = null
	var best_score: float = INF
	for candidate: Control in candidates:
		if candidate == origin or candidate.focus_mode == Control.FOCUS_NONE:
			continue
		var delta: Vector2 = (
			candidate.get_global_rect().get_center() - origin_center
		)
		var forward_distance: float = delta.dot(direction)
		if forward_distance <= MINIMUM_FORWARD_DISTANCE:
			continue
		var perpendicular_distance: float = absf(delta.cross(direction))
		var score: float = (
			forward_distance
			+ perpendicular_distance * PERPENDICULAR_WEIGHT
		)
		if score < best_score:
			best = candidate
			best_score = score
	if best == null:
		return NodePath()
	return origin.get_path_to(best)
