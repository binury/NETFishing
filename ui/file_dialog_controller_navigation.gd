class_name FileDialogControllerNavigation
extends RefCounted

const ControllerFocusNavigationType = preload(
	"res://ui/controller_focus_navigation.gd"
)
const ROW_TOLERANCE: float = 12.0
const EDGE_TOLERANCE: float = 1.0

const ACCESSIBILITY_NAMES_BY_TOOLTIP: Dictionary[String, String] = {
	"Go to previous folder.": "previous folder",
	"Go to next folder.": "next folder",
	"Go to parent folder.": "parent folder",
	"Refresh files.": "refresh files",
	"(Un)favorite current folder.": "favorite current folder",
	"Create a new folder.": "new folder",
	"Toggle the visibility of hidden files.": "show hidden files",
	"View items as a grid of thumbnails.": "thumbnail view",
	"View items as a list.": "list view",
	"Toggle the visibility of the filter for file names.": (
		"filter file names"
	),
	"Sort files": "sort files",
}


static func configure(dialog: FileDialog) -> void:
	if dialog == null or not dialog.visible or not dialog.is_inside_tree():
		return
	var scope: Window = active_scope(dialog)
	if scope == null:
		return
	configure_scope(scope)


static func configure_scope(
	scope: Window,
	preferred_control: Control = null,
) -> void:
	if scope == null or not scope.visible or not scope.is_inside_tree():
		return
	var controls: Array[Control] = []
	_collect_interactive_controls(scope, scope, controls)
	if controls.is_empty():
		return
	if scope is FileDialog:
		_configure_file_dialog_neighbors(controls)
	else:
		ControllerFocusNavigationType.configure_spatial_neighbors(controls)
	var focus_owner: Control = scope.gui_get_focus_owner()
	if controls.has(preferred_control):
		if focus_owner != preferred_control:
			preferred_control.grab_focus()
		return
	if focus_owner != null and controls.has(focus_owner):
		return
	var preferred: Control = _preferred_initial_control(scope, controls)
	if preferred != null:
		preferred.grab_focus()


static func active_scope(dialog: FileDialog) -> Window:
	if dialog == null or not dialog.visible:
		return null
	return _deepest_exclusive_window(dialog)


static func interactive_controls(scope: Window) -> Array[Control]:
	var controls: Array[Control] = []
	if scope != null:
		_collect_interactive_controls(scope, scope, controls)
	return controls


static func move_from_item_list(
	item_list: ItemList,
	direction: Vector2,
) -> bool:
	if (
		item_list == null
		or not item_list.has_focus()
		or not _item_list_at_edge(item_list, direction)
	):
		return false
	var neighbor_path: NodePath = _neighbor_path_for_direction(
		item_list, direction
	)
	var neighbor := item_list.get_node_or_null(neighbor_path) as Control
	if (
		neighbor == null
		or neighbor == item_list
		or not ControllerFocusNavigationType.is_focusable(neighbor)
	):
		return false
	neighbor.grab_focus()
	return true


static func _deepest_exclusive_window(window: Window) -> Window:
	for child: Node in window.get_children(true):
		var child_window := child as Window
		if (
			child_window == null
			or not child_window.visible
			or not child_window.exclusive
		):
			continue
		return _deepest_exclusive_window(child_window)
	return window


static func _collect_interactive_controls(
	node: Node,
	scope: Window,
	output: Array[Control],
) -> void:
	for child: Node in node.get_children(true):
		var child_window := child as Window
		if child_window != null and child_window != scope:
			continue
		var control := child as Control
		if control != null and _is_controller_interactive(control):
			# Godot marks some visible FileDialog toolbar and menu buttons as
			# accessibility-only. Promote those genuine controls for controller
			# focus while leaving labels, scrollbars, and splitters untouched.
			control.focus_mode = Control.FOCUS_ALL
			_apply_accessibility_name(control)
			output.append(control)
		_collect_interactive_controls(child, scope, output)


static func _is_controller_interactive(control: Control) -> bool:
	if (
		control == null
		or not control.is_visible_in_tree()
		or control.size.x < 8.0
		or control.size.y < 8.0
		or control is ScrollBar
	):
		return false
	var button := control as BaseButton
	if button != null:
		return not button.disabled
	return (
		control is LineEdit
		or control is TextEdit
		or control is ItemList
		or control is Tree
	)


static func _preferred_initial_control(
	scope: Window,
	controls: Array[Control],
) -> Control:
	if scope is FileDialog:
		for control: Control in controls:
			if control is ItemList and control.accessibility_name == (
				"Directories & Files:"
			):
				return control
	for control: Control in controls:
		if control is LineEdit or control is TextEdit:
			return control
	if scope is ConfirmationDialog:
		var confirmation := scope as ConfirmationDialog
		var ok_button: Button = confirmation.get_ok_button()
		if controls.has(ok_button):
			return ok_button
	return controls.front()


static func _configure_file_dialog_neighbors(
	controls: Array[Control],
) -> void:
	var rows: Array[Array] = []
	var ordered: Array[Control] = controls.duplicate()
	ordered.sort_custom(_sort_by_top_then_left)
	for control: Control in ordered:
		var control_top: float = control.get_global_rect().position.y
		var destination_row: Array = []
		for row: Array in rows:
			var row_control := row.front() as Control
			var row_top: float = (
				row_control.get_global_rect().position.y
			)
			if absf(control_top - row_top) <= ROW_TOLERANCE:
				destination_row = row
				break
		if destination_row.is_empty():
			destination_row = []
			rows.append(destination_row)
		destination_row.append(control)
	for row: Array in rows:
		row.sort_custom(_sort_by_left)
	for row_index: int in rows.size():
		var row: Array = rows[row_index]
		for column_index: int in row.size():
			var control := row[column_index] as Control
			var left := row[maxi(column_index - 1, 0)] as Control
			var right := row[mini(column_index + 1, row.size() - 1)] as Control
			var top: Control = _vertical_neighbor(
				control, rows, row_index, -1
			)
			var bottom: Control = _vertical_neighbor(
				control, rows, row_index, 1
			)
			control.focus_neighbor_left = control.get_path_to(left)
			control.focus_neighbor_right = control.get_path_to(right)
			control.focus_neighbor_top = control.get_path_to(top)
			control.focus_neighbor_bottom = control.get_path_to(bottom)
			control.focus_previous = control.get_path_to(
				ordered[wrapi(ordered.find(control) - 1, 0, ordered.size())]
			)
			control.focus_next = control.get_path_to(
				ordered[wrapi(ordered.find(control) + 1, 0, ordered.size())]
			)


static func _vertical_neighbor(
	origin: Control,
	rows: Array[Array],
	origin_row: int,
	direction: int,
) -> Control:
	var origin_rect: Rect2 = origin.get_global_rect()
	var row_index: int = origin_row + direction
	while row_index >= 0 and row_index < rows.size():
		var best: Control
		var best_distance: float = INF
		for candidate_value: Variant in rows[row_index]:
			var candidate := candidate_value as Control
			var candidate_rect: Rect2 = candidate.get_global_rect()
			if not _horizontally_aligned(origin_rect, candidate_rect):
				continue
			var distance: float = absf(
				origin_rect.get_center().x - candidate_rect.get_center().x
			)
			if distance < best_distance:
				best = candidate
				best_distance = distance
		if best != null:
			return best
		row_index += direction
	return origin


static func _horizontally_aligned(first: Rect2, second: Rect2) -> bool:
	return (
		first.position.x <= second.end.x + EDGE_TOLERANCE
		and second.position.x <= first.end.x + EDGE_TOLERANCE
	)


static func _sort_by_top_then_left(first: Control, second: Control) -> bool:
	var first_position: Vector2 = first.get_global_rect().position
	var second_position: Vector2 = second.get_global_rect().position
	if absf(first_position.y - second_position.y) > ROW_TOLERANCE:
		return first_position.y < second_position.y
	return first_position.x < second_position.x


static func _sort_by_left(first: Variant, second: Variant) -> bool:
	return (
		(first as Control).get_global_rect().position.x
		< (second as Control).get_global_rect().position.x
	)


static func _apply_accessibility_name(control: Control) -> void:
	if not control.accessibility_name.is_empty():
		return
	var authored_name: String = ACCESSIBILITY_NAMES_BY_TOOLTIP.get(
		control.tooltip_text, ""
	)
	if not authored_name.is_empty():
		control.accessibility_name = authored_name


static func _item_list_at_edge(
	item_list: ItemList,
	direction: Vector2,
) -> bool:
	if item_list.item_count <= 0:
		return true
	var selected: PackedInt32Array = item_list.get_selected_items()
	if selected.is_empty():
		return false
	var selected_rect: Rect2 = item_list.get_item_rect(selected[0])
	var content_bounds: Rect2 = item_list.get_item_rect(0)
	for item_index: int in range(1, item_list.item_count):
		content_bounds = content_bounds.merge(
			item_list.get_item_rect(item_index)
		)
	if direction == Vector2.UP:
		return selected_rect.position.y <= (
			content_bounds.position.y + EDGE_TOLERANCE
		)
	if direction == Vector2.DOWN:
		return selected_rect.end.y >= (
			content_bounds.end.y - EDGE_TOLERANCE
		)
	if direction == Vector2.LEFT:
		return selected_rect.position.x <= (
			content_bounds.position.x + EDGE_TOLERANCE
		)
	if direction == Vector2.RIGHT:
		return selected_rect.end.x >= (
			content_bounds.end.x - EDGE_TOLERANCE
		)
	return false


static func _neighbor_path_for_direction(
	control: Control,
	direction: Vector2,
) -> NodePath:
	if direction == Vector2.UP:
		return control.focus_neighbor_top
	if direction == Vector2.DOWN:
		return control.focus_neighbor_bottom
	if direction == Vector2.LEFT:
		return control.focus_neighbor_left
	if direction == Vector2.RIGHT:
		return control.focus_neighbor_right
	return NodePath()
