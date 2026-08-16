extends SceneTree

const GameUIType = preload("res://ui/game_ui.gd")
const PlayerType = preload("res://player/player.gd")


func _init() -> void:
	assert(
		ProjectSettings.get_setting("display/window/handheld/orientation", -1) == 0
	)
	assert(
		ProjectSettings.get_setting(
			"input_devices/pointing/emulate_mouse_from_touch", false
		)
	)
	assert(_has_joypad_motion(&"move_forward", JOY_AXIS_LEFT_Y, -1.0))
	assert(_has_joypad_motion(&"move_backward", JOY_AXIS_LEFT_Y, 1.0))
	assert(_has_joypad_motion(&"move_left", JOY_AXIS_LEFT_X, -1.0))
	assert(_has_joypad_motion(&"move_right", JOY_AXIS_LEFT_X, 1.0))
	assert(_has_joypad_button(&"jump", JOY_BUTTON_A))
	assert(_has_joypad_button(&"ui_accept", JOY_BUTTON_A))
	assert(_has_joypad_button(&"ui_cancel", JOY_BUTTON_B))
	assert(not _has_joypad_button(&"interact", JOY_BUTTON_Y))
	assert(_has_joypad_button(&"character_call", JOY_BUTTON_Y))
	assert(_has_joypad_button(&"fish_primary", JOY_BUTTON_RIGHT_SHOULDER))
	assert(not _has_joypad_motion(
		&"fish_primary", JOY_AXIS_TRIGGER_LEFT, 1.0
	))
	assert(not _has_joypad_motion(
		&"fish_primary", JOY_AXIS_TRIGGER_RIGHT, 1.0
	))
	assert(_has_joypad_button(&"sprint", JOY_BUTTON_LEFT_STICK))
	assert(not _has_joypad_button(
		&"camera_zoom_out", JOY_BUTTON_LEFT_SHOULDER
	))
	assert(not _has_joypad_button(
		&"camera_zoom_in", JOY_BUTTON_RIGHT_SHOULDER
	))
	assert(_has_joypad_button(&"hotbar_previous", JOY_BUTTON_DPAD_LEFT))
	assert(_has_joypad_button(&"hotbar_next", JOY_BUTTON_DPAD_RIGHT))
	assert(_has_joypad_button(&"open_backpack", JOY_BUTTON_X))
	assert(_has_joypad_button(&"open_system_menu", JOY_BUTTON_START))
	assert(_has_joypad_button(&"open_emotes", JOY_BUTTON_DPAD_UP))
	assert(_has_joypad_button(&"open_quick_actions", JOY_BUTTON_DPAD_DOWN))
	assert(_has_joypad_button(&"open_chat", JOY_BUTTON_BACK))
	assert(_has_joypad_button(&"focus_gameplay", JOY_BUTTON_LEFT_SHOULDER))
	assert(
		GameUIType.VIRTUAL_MOUSE_TRIGGER_AXIS == JOY_AXIS_TRIGGER_RIGHT
	)
	assert(
		GameUIType.VIRTUAL_MOUSE_SHARED_TRIGGER_AXIS
		== JOY_AXIS_TRIGGER_LEFT
	)
	assert(
		GameUIType.VIRTUAL_MOUSE_SECONDARY_CLICK_AXIS
		== JOY_AXIS_TRIGGER_LEFT
	)
	assert(PlayerType.CONTROLLER_ZOOM_TRIGGER_AXIS == JOY_AXIS_TRIGGER_LEFT)
	assert(is_zero_approx(
		GameUIType.normalized_trigger_strength(-1.0, -1.0)
	))
	assert(is_equal_approx(
		GameUIType.normalized_trigger_strength(1.0, -1.0),
		1.0,
	))
	assert(is_equal_approx(
		GameUIType.normalized_trigger_strength(-1.0, 0.0),
		1.0,
	))
	assert(is_equal_approx(
		GameUIType.normalized_trigger_strength(-1.0, 1.0),
		1.0,
	))
	assert(is_equal_approx(
		GameUIType.directional_trigger_strength(-1.0, 0.0, -1.0),
		1.0,
	))
	assert(is_zero_approx(
		GameUIType.directional_trigger_strength(1.0, 0.0, -1.0)
	))
	assert(is_equal_approx(
		GameUIType.directional_trigger_strength(1.0, 0.0, 1.0),
		1.0,
	))
	print("android readiness validation passed")
	quit()


func _has_joypad_button(action: StringName, button_index: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var button_event: InputEventJoypadButton = event as InputEventJoypadButton
		if button_event != null and button_event.button_index == button_index:
			return true
	return false


func _has_joypad_motion(
	action: StringName,
	axis: JoyAxis,
	direction: float,
) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var motion_event: InputEventJoypadMotion = event as InputEventJoypadMotion
		if (
			motion_event != null
			and motion_event.axis == axis
			and is_equal_approx(motion_event.axis_value, direction)
		):
			return true
	return false
