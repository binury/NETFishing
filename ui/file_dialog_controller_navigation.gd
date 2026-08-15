class_name FileDialogControllerNavigation
extends RefCounted

const ControllerFocusNavigationType = preload(
	"res://ui/controller_focus_navigation.gd"
)


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
