class_name ControllerFocusNavigation
extends RefCounted

const PERPENDICULAR_WEIGHT: float = 2.5
const MINIMUM_FORWARD_DISTANCE: float = 0.5
const MAXIMUM_DIRECTION_SLOPE: float = 1.0


static func configure_spatial_neighbors(controls: Array) -> void:
	var candidates: Array[Control] = []
	for item: Variant in controls:
		var control := item as Control
		if not is_focusable(control):
			if control != null:
				_clear_neighbors(control)
			continue
		candidates.append(control)
	var traversal_order: Array[Control] = candidates.duplicate()
	traversal_order.sort_custom(_sort_by_position)
	for control: Control in candidates:
		_enable_ancestor_scroll_follow(control)
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
		var traversal_index: int = traversal_order.find(control)
		control.focus_previous = control.get_path_to(
			traversal_order[wrapi(
				traversal_index - 1,
				0,
				traversal_order.size(),
			)]
		)
		control.focus_next = control.get_path_to(
			traversal_order[wrapi(
				traversal_index + 1,
				0,
				traversal_order.size(),
			)]
		)


static func configure_traversal(controls: Array) -> void:
	var candidates: Array[Control] = []
	for item: Variant in controls:
		var control := item as Control
		if is_focusable(control):
			candidates.append(control)
		elif control != null:
			control.focus_previous = NodePath()
			control.focus_next = NodePath()
	if candidates.is_empty():
		return
	for index: int in candidates.size():
		var control: Control = candidates[index]
		_enable_ancestor_scroll_follow(control)
		control.focus_previous = control.get_path_to(
			candidates[wrapi(index - 1, 0, candidates.size())]
		)
		control.focus_next = control.get_path_to(
			candidates[wrapi(index + 1, 0, candidates.size())]
		)


static func is_focusable(control: Control) -> bool:
	if (
		control == null
		or not control.is_visible_in_tree()
		or control.focus_mode not in [Control.FOCUS_CLICK, Control.FOCUS_ALL]
	):
		return false
	var button := control as BaseButton
	return button == null or not button.disabled


static func _clear_neighbors(control: Control) -> void:
	control.focus_neighbor_left = NodePath()
	control.focus_neighbor_right = NodePath()
	control.focus_neighbor_top = NodePath()
	control.focus_neighbor_bottom = NodePath()
	control.focus_previous = NodePath()
	control.focus_next = NodePath()


static func _enable_ancestor_scroll_follow(control: Control) -> void:
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		var scroll := ancestor as ScrollContainer
		if scroll != null:
			scroll.follow_focus = true
		ancestor = ancestor.get_parent()


static func _sort_by_position(first: Control, second: Control) -> bool:
	var first_center: Vector2 = first.get_global_rect().get_center()
	var second_center: Vector2 = second.get_global_rect().get_center()
	if not is_equal_approx(first_center.y, second_center.y):
		return first_center.y < second_center.y
	return first_center.x < second_center.x


static func _neighbor_path(
	origin: Control,
	candidates: Array[Control],
	direction: Vector2,
) -> NodePath:
	var origin_center: Vector2 = origin.get_global_rect().get_center()
	var best: Control = null
	var best_score: float = INF
	for candidate: Control in candidates:
		if candidate == origin or not is_focusable(candidate):
			continue
		var delta: Vector2 = (
			candidate.get_global_rect().get_center() - origin_center
		)
		var forward_distance: float = delta.dot(direction)
		if forward_distance <= MINIMUM_FORWARD_DISTANCE:
			continue
		var perpendicular_distance: float = absf(delta.cross(direction))
		if perpendicular_distance > forward_distance * MAXIMUM_DIRECTION_SLOPE:
			continue
		var score: float = (
			forward_distance
			+ perpendicular_distance * PERPENDICULAR_WEIGHT
		)
		if score < best_score:
			best = candidate
			best_score = score
	if best == null:
		return origin.get_path_to(origin)
	return origin.get_path_to(best)
