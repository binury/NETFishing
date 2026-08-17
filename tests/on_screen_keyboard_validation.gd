extends SceneTree

const KeyboardType = preload("res://ui/on_screen_keyboard.gd")
const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const SettingsManagerType = preload(
	"res://settings/player_settings_manager.gd"
)


class ControllerInputProbe:
	extends Node

	var pressed_buttons: Array[int] = []


	func _input(event: InputEvent) -> void:
		var button := event as InputEventJoypadButton
		if button != null and button.pressed:
			pressed_buttons.append(button.button_index)


class NativeKeyboardProbe:
	extends OnScreenKeyboard
	var shown_controls: Array[Control] = []
	var hide_count: int = 0


	func _uses_native_virtual_keyboard() -> bool:
		return true


	func _show_native_keyboard_for(control: Control) -> void:
		shown_controls.append(control)


	func _hide_native_keyboard() -> void:
		hide_count += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_default_and_persistence()
	await _validate_keyboard_entry()
	await _validate_automapped_face_buttons()
	await _validate_native_keyboard()
	print("On-screen keyboard validation: PASS")
	quit()


func _validate_default_and_persistence() -> void:
	var defaults := PlayerSettings.new()
	assert(not defaults.on_screen_keyboard_enabled)
	assert(
		KeyboardType.should_enable_for_controller(false, false, "Linux")
	)
	assert(
		KeyboardType.should_enable_for_controller(false, true, "Linux")
	)
	assert(
		not KeyboardType.should_enable_for_controller(false, true, "Android")
	)
	assert(
		KeyboardType.should_enable_for_controller(true, true, "Android")
	)
	assert(
		KeyboardType.should_use_native_virtual_keyboard(
			false, true, "Android"
		)
	)
	assert(
		not KeyboardType.should_use_native_virtual_keyboard(
			true, true, "Android"
		)
	)
	assert(
		not KeyboardType.should_use_native_virtual_keyboard(
			false, true, "Linux"
		)
	)
	var manager := SettingsManagerType.new()
	root.add_child(manager)
	assert(manager.load_settings())
	var edited: PlayerSettings = manager.current_settings.copy()
	edited.on_screen_keyboard_enabled = true
	assert(manager.apply_settings(edited))
	var reloaded := SettingsManagerType.new()
	root.add_child(reloaded)
	assert(reloaded.load_settings())
	assert(reloaded.current_settings.on_screen_keyboard_enabled)
	manager.queue_free()
	reloaded.queue_free()


func _validate_keyboard_entry() -> void:
	var host := Control.new()
	root.add_child(host)
	var edit := LineEdit.new()
	edit.text = "seed"
	edit.caret_column = 0
	edit.focus_mode = Control.FOCUS_ALL
	host.add_child(edit)
	var keyboard := KeyboardType.new()
	host.add_child(keyboard)
	await process_frame
	keyboard.set_enabled(false)
	assert(keyboard.is_enabled())
	var activate_event := InputEventJoypadButton.new()
	activate_event.button_index = JOY_BUTTON_A
	activate_event.pressed = true
	if keyboard.is_enabled():
		edit.grab_focus()
		keyboard.call("_input", activate_event)
		assert(keyboard.is_open())
		keyboard.call("_close_keyboard", true)
		assert(not keyboard.is_open())
	keyboard.set_enabled(true)
	edit.grab_focus()
	keyboard.call("_input", activate_event)
	assert(keyboard.is_open())
	assert(edit.caret_column == edit.text.length())
	assert(keyboard.get("_buffer_caret") == edit.text.length())
	assert(
		str(
			(keyboard.get("_preview") as RichTextLabel).get_parsed_text()
		).begins_with("seed")
	)
	var left_page_event := InputEventJoypadButton.new()
	left_page_event.button_index = JOY_BUTTON_LEFT_SHOULDER
	left_page_event.pressed = true
	keyboard.call("_input", left_page_event)
	assert(keyboard.is_open())
	assert(keyboard.get("_page") == KeyboardType.Page.SYMBOLS)
	var right_page_event := InputEventJoypadButton.new()
	right_page_event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	right_page_event.pressed = true
	keyboard.call("_input", right_page_event)
	assert(keyboard.is_open())
	assert(keyboard.get("_page") == KeyboardType.Page.LOWER)
	for _frame: int in 2:
		await process_frame
	var focused_key := root.gui_get_focus_owner() as Button
	assert(focused_key != null and focused_key.text == "q")
	var second_key := keyboard.get("_key_buttons")[1] as Button
	second_key.grab_focus()
	var outside_button := Button.new()
	host.add_child(outside_button)
	outside_button.grab_focus()
	assert(root.gui_get_focus_owner() == outside_button)
	keyboard.call("_process", 0.0)
	assert(root.gui_get_focus_owner() == second_key)
	var conflicting_cancel_binding := InputEventJoypadButton.new()
	conflicting_cancel_binding.button_index = JOY_BUTTON_A
	InputMap.action_add_event(&"ui_cancel", conflicting_cancel_binding)
	keyboard.call("_input", activate_event)
	InputMap.action_erase_event(&"ui_cancel", conflicting_cancel_binding)
	assert(keyboard.is_open())
	assert(edit.text == "seedw")
	var left_trigger := InputEventJoypadMotion.new()
	left_trigger.axis = JOY_AXIS_TRIGGER_LEFT
	left_trigger.axis_value = 1.0
	keyboard.call("_input", left_trigger)
	assert(keyboard.get("_buffer_caret") == edit.text.length() - 1)
	var right_trigger := InputEventJoypadMotion.new()
	right_trigger.axis = JOY_AXIS_TRIGGER_RIGHT
	right_trigger.axis_value = 1.0
	keyboard.call("_input", right_trigger)
	assert(keyboard.get("_buffer_caret") == edit.text.length())
	var preview := keyboard.get("_preview") as RichTextLabel
	var preview_height_before_blink: float = preview.get_content_height()
	var preview_text_before_blink: String = preview.get_parsed_text()
	keyboard.call("_process", KeyboardType.CARET_BLINK_INTERVAL)
	assert(
		not bool(keyboard.get("_caret_visible"))
	)
	assert(preview.get_parsed_text() == preview_text_before_blink)
	assert(is_equal_approx(preview.get_content_height(), preview_height_before_blink))
	keyboard.call("_type_character", "a")
	keyboard.call("_type_space")
	keyboard.call("_set_page", KeyboardType.Page.UPPER)
	keyboard.call("_type_character", "B")
	assert(edit.text == "seedwa B")
	keyboard.call("_move_caret", -1)
	keyboard.call("_type_character", "C")
	assert(edit.text == "seedwa CB")
	var input_probe := ControllerInputProbe.new()
	root.add_child(input_probe)
	root.move_child(input_probe, 0)
	var backspace_event := InputEventJoypadButton.new()
	backspace_event.button_index = JOY_BUTTON_X
	backspace_event.pressed = true
	Input.parse_input_event(backspace_event)
	await process_frame
	assert(edit.text == "seedwa B")
	assert(input_probe.pressed_buttons.is_empty())
	var close_event := InputEventJoypadButton.new()
	close_event.button_index = JOY_BUTTON_B
	close_event.pressed = true
	keyboard.call("_input", close_event)
	assert(not keyboard.is_open())
	assert(root.gui_get_focus_owner() == edit)
	input_probe.queue_free()
	edit.grab_focus()
	keyboard.call("_input", activate_event)
	assert(keyboard.is_open())
	var submitted: Array[String] = []
	edit.text_submitted.connect(func(value: String) -> void:
		submitted.append(value)
	)
	keyboard.call("_submit")
	assert(not keyboard.is_open())
	assert(submitted == ["seedwa B"])
	var letter_body := TextEdit.new()
	letter_body.text = "letter"
	letter_body.focus_mode = Control.FOCUS_ALL
	host.add_child(letter_body)
	letter_body.text_changed.connect(func() -> void:
		outside_button.call_deferred("grab_focus")
	)
	letter_body.grab_focus()
	keyboard.call("_input", activate_event)
	assert(keyboard.is_open())
	for _frame: int in 2:
		await process_frame
	var letter_key := keyboard.get("_key_buttons")[2] as Button
	letter_key.grab_focus()
	keyboard.call("_input", activate_event)
	for _frame: int in 2:
		await process_frame
	assert(letter_body.text == "lettere")
	assert(root.gui_get_focus_owner() == letter_key)
	keyboard.call("_input", close_event)
	assert(not keyboard.is_open())
	host.queue_free()


func _validate_automapped_face_buttons() -> void:
	var manager := ControllerMappingManagerType.new()
	root.add_child(manager)
	await process_frame
	var swapped_bindings: Dictionary = (
		ControllerMappingManagerType.default_bindings()
	)
	swapped_bindings[str(ControllerMappingManagerType.ROLE_A)] = {
		"kind": "button",
		"button": int(JOY_BUTTON_B),
	}
	swapped_bindings[str(ControllerMappingManagerType.ROLE_B)] = {
		"kind": "button",
		"button": int(JOY_BUTTON_A),
	}
	manager._active_profile_key = "keyboard-mapping-test"
	manager._profiles[manager._active_profile_key] = {
		"controller_name": "keyboard mapping test",
		"bindings": swapped_bindings,
	}
	var host := Control.new()
	root.add_child(host)
	var edit := LineEdit.new()
	edit.focus_mode = Control.FOCUS_ALL
	host.add_child(edit)
	var keyboard := KeyboardType.new()
	host.add_child(keyboard)
	keyboard.setup_controller_mapping(manager)
	keyboard.set_enabled(true)
	await process_frame
	var mapped_accept := InputEventJoypadButton.new()
	mapped_accept.device = manager.get_active_device_id()
	mapped_accept.button_index = JOY_BUTTON_B
	mapped_accept.pressed = true
	edit.grab_focus()
	keyboard.call("_input", mapped_accept)
	assert(keyboard.is_open())
	for _frame: int in 2:
		await process_frame
	keyboard.call("_input", mapped_accept)
	assert(keyboard.is_open())
	assert(edit.text == "q")
	var mapped_cancel := InputEventJoypadButton.new()
	mapped_cancel.device = manager.get_active_device_id()
	mapped_cancel.button_index = JOY_BUTTON_A
	mapped_cancel.pressed = true
	keyboard.call("_input", mapped_cancel)
	assert(not keyboard.is_open())
	host.queue_free()
	manager.queue_free()


func _validate_native_keyboard() -> void:
	var host := Control.new()
	root.add_child(host)
	var edit := LineEdit.new()
	edit.focus_mode = Control.FOCUS_ALL
	edit.virtual_keyboard_enabled = true
	host.add_child(edit)
	var outside_button := Button.new()
	host.add_child(outside_button)
	var keyboard := NativeKeyboardProbe.new()
	host.add_child(keyboard)
	await process_frame
	edit.grab_focus()
	assert(keyboard.is_open())
	var focus_exit_count: int = 0
	edit.focus_exited.connect(func() -> void:
		focus_exit_count += 1
	)
	assert(keyboard.request_for_control(edit))
	assert(edit.has_focus())
	assert(focus_exit_count == 0)
	assert(not edit.virtual_keyboard_enabled)
	assert(not edit.virtual_keyboard_show_on_focus)
	assert(keyboard.shown_controls == [edit])
	var character_event := InputEventKey.new()
	character_event.keycode = KEY_A
	character_event.unicode = 97
	character_event.pressed = true
	Input.parse_input_event(character_event)
	await process_frame
	assert(edit.has_focus())
	assert(edit.text == "a")
	outside_button.grab_focus()
	await process_frame
	assert(outside_button.has_focus())
	assert(keyboard.is_open())
	var backspace_event := InputEventKey.new()
	backspace_event.keycode = KEY_BACKSPACE
	backspace_event.pressed = true
	Input.parse_input_event(backspace_event)
	await process_frame
	assert(edit.has_focus())
	assert(edit.text.is_empty())
	var close_event := InputEventJoypadButton.new()
	close_event.button_index = JOY_BUTTON_B
	close_event.pressed = true
	keyboard.call("_input", close_event)
	assert(not edit.has_focus())
	assert(not keyboard.is_open())
	assert(edit.virtual_keyboard_enabled)
	assert(edit.virtual_keyboard_show_on_focus)
	assert(keyboard.hide_count == 1)
	assert(keyboard.request_for_control(edit))
	await process_frame
	assert(edit.has_focus())
	assert(keyboard.is_open())
	assert(keyboard.shown_controls == [edit, edit])
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	keyboard.call("_input", escape_event)
	assert(not edit.has_focus())
	assert(not keyboard.is_open())
	assert(keyboard.hide_count == 2)
	host.queue_free()
