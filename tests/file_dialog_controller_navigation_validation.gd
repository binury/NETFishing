extends SceneTree

const FileDialogControllerNavigationType = preload(
	"res://ui/file_dialog_controller_navigation.gd"
)
const InterfaceFontControllerType = preload(
	"res://ui/interface_font_controller.gd"
)
const OnScreenKeyboardType = preload("res://ui/on_screen_keyboard.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = false
	root.add_child(dialog)
	dialog.current_dir = "/tmp"
	dialog.popup_centered(Vector2i(900, 540))
	for _frame: int in 3:
		await process_frame
	FileDialogControllerNavigationType.configure(dialog)
	await process_frame

	var root_scope: Window = (
		FileDialogControllerNavigationType.active_scope(dialog)
	)
	assert(root_scope == dialog)
	var root_controls: Array[Control] = (
		FileDialogControllerNavigationType.interactive_controls(root_scope)
	)
	var directory_list: ItemList
	var create_folder_button: Button
	var path_edit: LineEdit
	var has_menu_button: bool = false
	var has_cancel: bool = false
	var has_select: bool = false
	for control: Control in root_controls:
		if (
			control is ItemList
			and control.accessibility_name == "Directories & Files:"
		):
			directory_list = control as ItemList
		if control is LineEdit and control.accessibility_name == "Path:":
			path_edit = control as LineEdit
		var button := control as Button
		if button != null:
			create_folder_button = (
				button
				if button.tooltip_text == "Create a new folder."
				else create_folder_button
			)
			has_cancel = has_cancel or button.text == "Cancel"
			has_select = has_select or button.text == "Select Current Folder"
		has_menu_button = has_menu_button or control is MenuButton
	assert(directory_list != null)
	assert(path_edit != null)
	assert(create_folder_button != null)
	assert(has_menu_button)
	assert(has_cancel)
	assert(has_select)
	assert(dialog.gui_get_focus_owner() == directory_list)
	_assert_directionally_reachable(directory_list, root_controls)

	create_folder_button.pressed.emit()
	for _frame: int in 3:
		await process_frame
	FileDialogControllerNavigationType.configure(dialog)
	await process_frame
	var folder_scope: Window = (
		FileDialogControllerNavigationType.active_scope(dialog)
	)
	assert(folder_scope != null and folder_scope != dialog)
	var folder_controls: Array[Control] = (
		FileDialogControllerNavigationType.interactive_controls(folder_scope)
	)
	var folder_name_edit: LineEdit
	var folder_cancel: Button
	var folder_ok: Button
	for control: Control in folder_controls:
		if control is LineEdit:
			folder_name_edit = control as LineEdit
		var button := control as Button
		if button != null and button.text == "Cancel":
			folder_cancel = button
		if button != null and button.text == "OK":
			folder_ok = button
	assert(folder_name_edit != null)
	assert(folder_cancel != null)
	assert(folder_ok != null)
	assert(folder_scope.gui_get_focus_owner() == folder_name_edit)
	_assert_directionally_reachable(folder_name_edit, folder_controls)

	var keyboard := OnScreenKeyboardType.new()
	root.add_child(keyboard)
	keyboard.set_enabled(true)
	folder_name_edit.grab_focus()
	assert(keyboard.request_for_control(folder_name_edit))
	assert(keyboard.is_open())
	assert(keyboard.get_parent() == folder_scope)
	keyboard.call("_close_keyboard", true)

	var main_source: String = FileAccess.get_file_as_string(
		"res://main/main.gd"
	)
	assert(main_source.contains("picker_scope != _data_folder_dialog"))
	assert(main_source.contains("picker_scope.hide()"))
	assert(main_source.contains("is_controller_text_entry_open()"))

	dialog.queue_free()
	keyboard.queue_free()
	await process_frame
	await _validate_compact_dialog()
	print("File dialog controller navigation validation: PASS")
	quit()


func _validate_compact_dialog() -> void:
	root.size = Vector2i(640, 480)
	var font_controller := InterfaceFontControllerType.new()
	root.add_child(font_controller)
	await process_frame
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = false
	root.add_child(dialog)
	dialog.current_dir = "/tmp"
	font_controller.popup_file_dialog(dialog)
	for _frame: int in 4:
		await process_frame
	assert(dialog.size.x <= 616 and dialog.size.y <= 456)
	var scope: Window = FileDialogControllerNavigationType.active_scope(dialog)
	var controls: Array[Control] = (
		FileDialogControllerNavigationType.interactive_controls(scope)
	)
	var directory_list: ItemList
	for control: Control in controls:
		if (
			control is ItemList
			and control.accessibility_name == "Directories & Files:"
		):
			directory_list = control as ItemList
			break
	assert(directory_list != null)
	_assert_directionally_reachable(directory_list, controls)
	dialog.queue_free()
	font_controller.queue_free()
	await process_frame


func _assert_directionally_reachable(
	start: Control,
	controls: Array[Control],
) -> void:
	var expected: Dictionary[int, bool] = {}
	for control: Control in controls:
		expected[control.get_instance_id()] = true
	var visited: Dictionary[int, bool] = {start.get_instance_id(): true}
	var pending: Array[Control] = [start]
	while not pending.is_empty():
		var current: Control = pending.pop_front()
		for path: NodePath in [
			current.focus_neighbor_left,
			current.focus_neighbor_right,
			current.focus_neighbor_top,
			current.focus_neighbor_bottom,
		]:
			var neighbor := current.get_node_or_null(path) as Control
			if (
				neighbor == null
				or not expected.has(neighbor.get_instance_id())
				or visited.has(neighbor.get_instance_id())
			):
				continue
			visited[neighbor.get_instance_id()] = true
			pending.append(neighbor)
	assert(visited.size() == expected.size())
