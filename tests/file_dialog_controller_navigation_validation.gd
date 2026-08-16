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
	var parent_button: Button
	var create_folder_button: Button
	var path_edit: LineEdit
	var drive_button: MenuButton
	var refresh_button: Button
	var favorite_button: Button
	var hidden_button: Button
	var grid_button: Button
	var list_button: Button
	var filter_button: Button
	var sort_button: MenuButton
	var cancel_button: Button
	var select_button: Button
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
			parent_button = (
				button
				if button.tooltip_text == "Go to parent folder."
				else parent_button
			)
			create_folder_button = (
				button
				if button.tooltip_text == "Create a new folder."
				else create_folder_button
			)
			refresh_button = (
				button
				if button.tooltip_text == "Refresh files."
				else refresh_button
			)
			favorite_button = (
				button
				if button.tooltip_text == "(Un)favorite current folder."
				else favorite_button
			)
			hidden_button = (
				button
				if button.tooltip_text == (
					"Toggle the visibility of hidden files."
				)
				else hidden_button
			)
			grid_button = (
				button
				if button.tooltip_text == (
					"View items as a grid of thumbnails."
				)
				else grid_button
			)
			list_button = (
				button
				if button.tooltip_text == "View items as a list."
				else list_button
			)
			filter_button = (
				button
				if button.tooltip_text == (
					"Toggle the visibility of the filter for file names."
				)
				else filter_button
			)
			cancel_button = button if button.text == "Cancel" else cancel_button
			select_button = (
				button
				if button.text == "Select Current Folder"
				else select_button
			)
		var menu := control as MenuButton
		if menu != null:
			drive_button = menu if menu.accessibility_name == "Drive" else drive_button
			sort_button = (
				menu if menu.tooltip_text == "Sort files" else sort_button
			)
	assert(directory_list != null)
	assert(parent_button != null)
	assert(path_edit != null)
	assert(create_folder_button != null)
	assert(drive_button != null)
	assert(refresh_button != null)
	assert(favorite_button != null)
	assert(hidden_button != null)
	assert(grid_button != null)
	assert(list_button != null)
	assert(filter_button != null)
	assert(sort_button != null)
	assert(cancel_button != null)
	assert(select_button != null)
	assert(dialog.gui_get_focus_owner() == directory_list)
	_assert_neighbor(path_edit, &"focus_neighbor_left", parent_button)
	_assert_neighbor(path_edit, &"focus_neighbor_right", drive_button)
	_assert_neighbor(drive_button, &"focus_neighbor_left", path_edit)
	_assert_neighbor(refresh_button, &"focus_neighbor_left", drive_button)
	_assert_neighbor(favorite_button, &"focus_neighbor_left", refresh_button)
	_assert_neighbor(
		create_folder_button, &"focus_neighbor_left", favorite_button
	)
	_assert_neighbor(hidden_button, &"focus_neighbor_right", grid_button)
	_assert_neighbor(grid_button, &"focus_neighbor_right", list_button)
	_assert_neighbor(list_button, &"focus_neighbor_right", filter_button)
	_assert_neighbor(filter_button, &"focus_neighbor_right", sort_button)
	_assert_neighbor(sort_button, &"focus_neighbor_top", create_folder_button)
	_assert_neighbor(
		create_folder_button, &"focus_neighbor_bottom", sort_button
	)
	_assert_neighbor(directory_list, &"focus_neighbor_top", hidden_button)
	_assert_neighbor(directory_list, &"focus_neighbor_bottom", select_button)
	_assert_neighbor(cancel_button, &"focus_neighbor_right", select_button)
	_assert_neighbor(select_button, &"focus_neighbor_left", cancel_button)
	assert(favorite_button.accessibility_name == "favorite current folder")
	assert(create_folder_button.accessibility_name == "new folder")
	assert(filter_button.accessibility_name == "filter file names")
	_assert_directionally_reachable(directory_list, root_controls)
	directory_list.clear()
	directory_list.add_item("test folder")
	directory_list.select(0)
	directory_list.grab_focus()
	assert(
		FileDialogControllerNavigationType.move_from_item_list(
			directory_list, Vector2.UP
		)
	)
	assert(dialog.gui_get_focus_owner() == hidden_button)
	directory_list.grab_focus()
	assert(
		FileDialogControllerNavigationType.move_from_item_list(
			directory_list, Vector2.DOWN
		)
	)
	assert(dialog.gui_get_focus_owner() == select_button)
	sort_button.grab_focus()
	var accept_press := InputEventAction.new()
	accept_press.action = &"ui_accept"
	accept_press.pressed = true
	Input.parse_input_event(accept_press)
	var accept_release := InputEventAction.new()
	accept_release.action = &"ui_accept"
	accept_release.pressed = false
	Input.parse_input_event(accept_release)
	await process_frame
	assert(sort_button.get_popup().visible)
	sort_button.get_popup().hide()
	await process_frame

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
	var keyboard := OnScreenKeyboardType.new()
	root.add_child(keyboard)
	await process_frame
	keyboard.set_enabled(false)
	font_controller.set_controller_text_entry_request(
		Callable(keyboard, "request_for_control"),
		Callable(keyboard, "is_open"),
	)
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
	var path_edit: LineEdit
	var select_button: Button
	for control: Control in controls:
		if (
			control is ItemList
			and control.accessibility_name == "Directories & Files:"
		):
			directory_list = control as ItemList
		if control is LineEdit and control.accessibility_name == "Path:":
			path_edit = control as LineEdit
		if control is Button and (control as Button).text == (
			"Select Current Folder"
		):
			select_button = control as Button
	assert(directory_list != null)
	assert(path_edit != null)
	assert(select_button != null)
	_assert_directionally_reachable(directory_list, controls)
	directory_list.clear()
	directory_list.add_item("test folder")
	directory_list.select(0)
	directory_list.grab_focus()
	var down_event := InputEventJoypadButton.new()
	down_event.button_index = JOY_BUTTON_DPAD_DOWN
	down_event.pressed = true
	var dialog_controller := font_controller.get(
		"_file_dialog_controller"
	) as FileDialogController
	dialog_controller.call("_input", down_event)
	assert(scope.gui_get_focus_owner() == select_button)
	path_edit.grab_focus()
	var accept_event := InputEventJoypadButton.new()
	accept_event.button_index = JOY_BUTTON_A
	accept_event.pressed = true
	dialog_controller.call("_input", accept_event)
	assert(keyboard.is_open())
	keyboard.call("_close_keyboard", true)
	dialog.queue_free()
	font_controller.queue_free()
	keyboard.queue_free()
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


func _assert_neighbor(
	origin: Control,
	property_name: StringName,
	expected: Control,
) -> void:
	var neighbor_path: NodePath = origin.get(property_name)
	var neighbor := origin.get_node_or_null(neighbor_path) as Control
	assert(neighbor == expected)
