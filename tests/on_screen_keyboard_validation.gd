extends SceneTree

const KeyboardType = preload("res://ui/on_screen_keyboard.gd")
const SettingsManagerType = preload(
	"res://settings/player_settings_manager.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_default_and_persistence()
	await _validate_keyboard_entry()
	print("On-screen keyboard validation: PASS")
	quit()


func _validate_default_and_persistence() -> void:
	var defaults := PlayerSettings.new()
	assert(not defaults.on_screen_keyboard_enabled)
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
	edit.focus_mode = Control.FOCUS_ALL
	host.add_child(edit)
	var keyboard := KeyboardType.new()
	host.add_child(keyboard)
	await process_frame
	keyboard.set_enabled(true)
	edit.grab_focus()
	var activate_event := InputEventJoypadButton.new()
	activate_event.button_index = JOY_BUTTON_A
	activate_event.pressed = true
	keyboard.call("_input", activate_event)
	assert(keyboard.is_open())
	keyboard.call("_type_character", "a")
	keyboard.call("_type_space")
	keyboard.call("_set_page", KeyboardType.Page.UPPER)
	keyboard.call("_type_character", "B")
	assert(edit.text == "a B")
	keyboard.call("_move_caret", -1)
	keyboard.call("_type_character", "C")
	assert(edit.text == "a CB")
	var backspace_event := InputEventJoypadButton.new()
	backspace_event.button_index = JOY_BUTTON_X
	backspace_event.pressed = true
	keyboard.call("_input", backspace_event)
	assert(edit.text == "a B")
	var defocus_event := InputEventJoypadButton.new()
	defocus_event.button_index = JOY_BUTTON_LEFT_SHOULDER
	defocus_event.pressed = true
	keyboard.call("_input", defocus_event)
	assert(not keyboard.is_open())
	assert(root.gui_get_focus_owner() == null)
	edit.grab_focus()
	keyboard.call("_input", activate_event)
	assert(keyboard.is_open())
	var submitted: Array[String] = []
	edit.text_submitted.connect(func(value: String) -> void:
		submitted.append(value)
	)
	keyboard.call("_submit")
	assert(not keyboard.is_open())
	assert(submitted == ["a B"])
	host.queue_free()
