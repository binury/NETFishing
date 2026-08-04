class_name ControllerMappingManager
extends Node

signal active_profile_changed
signal active_controller_changed(controller_name: String)

const FORMAT_VERSION: int = 1
const PROFILE_PATH: String = "user://controller_mappings.json"
const PROFILE_TEMP_PATH: String = "user://controller_mappings.json.tmp"
const PROFILE_BACKUP_PATH: String = "user://controller_mappings.json.backup"
const MAX_PROFILE_BYTES: int = 1024 * 1024
const CAPTURE_AXIS_THRESHOLD: float = 0.55
const ROLE_A: StringName = &"a"
const ROLE_B: StringName = &"b"
const ROLE_X: StringName = &"x"
const ROLE_Y: StringName = &"y"
const ROLE_LB: StringName = &"lb"
const ROLE_RB: StringName = &"rb"
const ROLE_LT: StringName = &"lt"
const ROLE_RT: StringName = &"rt"
const ROLE_SELECT: StringName = &"select"
const ROLE_START: StringName = &"start"
const ROLE_LEFT_STICK_CLICK: StringName = &"left_stick_click"
const ROLE_RIGHT_STICK_CLICK: StringName = &"right_stick_click"
const ROLE_DPAD_UP: StringName = &"dpad_up"
const ROLE_DPAD_DOWN: StringName = &"dpad_down"
const ROLE_DPAD_LEFT: StringName = &"dpad_left"
const ROLE_DPAD_RIGHT: StringName = &"dpad_right"
const ROLE_LEFT_STICK_X: StringName = &"left_stick_x"
const ROLE_LEFT_STICK_Y: StringName = &"left_stick_y"
const ROLE_RIGHT_STICK_X: StringName = &"right_stick_x"
const ROLE_RIGHT_STICK_Y: StringName = &"right_stick_y"

const ROLE_ORDER: Array[StringName] = [
	ROLE_A,
	ROLE_B,
	ROLE_X,
	ROLE_Y,
	ROLE_LB,
	ROLE_RB,
	ROLE_LT,
	ROLE_RT,
	ROLE_SELECT,
	ROLE_START,
	ROLE_LEFT_STICK_CLICK,
	ROLE_RIGHT_STICK_CLICK,
	ROLE_DPAD_UP,
	ROLE_DPAD_DOWN,
	ROLE_DPAD_LEFT,
	ROLE_DPAD_RIGHT,
	ROLE_LEFT_STICK_X,
	ROLE_LEFT_STICK_Y,
	ROLE_RIGHT_STICK_X,
	ROLE_RIGHT_STICK_Y,
]

const ROLE_LABELS: Dictionary = {
	ROLE_A: "jump / menu accept",
	ROLE_B: "menu back",
	ROLE_X: "player menu",
	ROLE_Y: "interact",
	ROLE_LB: "focus chat or world",
	ROLE_RB: "primary action",
	ROLE_LT: "virtual mouse",
	ROLE_RT: "camera zoom",
	ROLE_SELECT: "chat",
	ROLE_START: "pause",
	ROLE_LEFT_STICK_CLICK: "sprint",
	ROLE_RIGHT_STICK_CLICK: "unassigned stick click",
	ROLE_DPAD_UP: "emote wheel",
	ROLE_DPAD_DOWN: "quick menu",
	ROLE_DPAD_LEFT: "previous hotbar slot",
	ROLE_DPAD_RIGHT: "next hotbar slot",
	ROLE_LEFT_STICK_X: "move left / right",
	ROLE_LEFT_STICK_Y: "move up / down",
	ROLE_RIGHT_STICK_X: "camera left / right",
	ROLE_RIGHT_STICK_Y: "camera up / down",
}

const ROLE_PROMPTS: Dictionary = {
	ROLE_A: "press the a button",
	ROLE_B: "press the b button",
	ROLE_X: "press the x button",
	ROLE_Y: "press the y button",
	ROLE_LB: "press the left bumper",
	ROLE_RB: "press the right bumper",
	ROLE_LT: "squeeze the left trigger",
	ROLE_RT: "squeeze the right trigger",
	ROLE_SELECT: "press select / back",
	ROLE_START: "press start",
	ROLE_LEFT_STICK_CLICK: "click the left stick",
	ROLE_RIGHT_STICK_CLICK: "click the right stick",
	ROLE_DPAD_UP: "press d-pad up",
	ROLE_DPAD_DOWN: "press d-pad down",
	ROLE_DPAD_LEFT: "press d-pad left",
	ROLE_DPAD_RIGHT: "press d-pad right",
	ROLE_LEFT_STICK_X: "move the left stick left",
	ROLE_LEFT_STICK_Y: "move the left stick up",
	ROLE_RIGHT_STICK_X: "move the right stick left",
	ROLE_RIGHT_STICK_Y: "move the right stick up",
}

const STICK_AXIS_ROLES: Array[StringName] = [
	ROLE_LEFT_STICK_X,
	ROLE_LEFT_STICK_Y,
	ROLE_RIGHT_STICK_X,
	ROLE_RIGHT_STICK_Y,
]
const TRIGGER_ROLES: Array[StringName] = [ROLE_LT, ROLE_RT]

const BUTTON_ACTION_ROLES: Dictionary = {
	&"jump": ROLE_A,
	&"ui_accept": ROLE_A,
	&"ui_cancel": ROLE_B,
	&"open_backpack": ROLE_X,
	&"interact": ROLE_Y,
	&"focus_gameplay": ROLE_LB,
	&"fish_primary": ROLE_RB,
	&"open_chat": ROLE_SELECT,
	&"open_system_menu": ROLE_START,
	&"sprint": ROLE_LEFT_STICK_CLICK,
	&"open_emotes": ROLE_DPAD_UP,
	&"open_quick_actions": ROLE_DPAD_DOWN,
	&"hotbar_previous": ROLE_DPAD_LEFT,
	&"hotbar_next": ROLE_DPAD_RIGHT,
}

const AXIS_ACTION_ROLES: Dictionary = {
	&"move_left": [ROLE_LEFT_STICK_X, -1.0],
	&"move_right": [ROLE_LEFT_STICK_X, 1.0],
	&"move_forward": [ROLE_LEFT_STICK_Y, -1.0],
	&"move_backward": [ROLE_LEFT_STICK_Y, 1.0],
	&"ui_left": [ROLE_LEFT_STICK_X, -1.0],
	&"ui_right": [ROLE_LEFT_STICK_X, 1.0],
	&"ui_up": [ROLE_LEFT_STICK_Y, -1.0],
	&"ui_down": [ROLE_LEFT_STICK_Y, 1.0],
}

const UI_DPAD_ACTION_ROLES: Dictionary = {
	&"ui_up": ROLE_DPAD_UP,
	&"ui_down": ROLE_DPAD_DOWN,
	&"ui_left": ROLE_DPAD_LEFT,
	&"ui_right": ROLE_DPAD_RIGHT,
}

var _profiles: Dictionary = {}
var _active_device_id: int = 0
var _active_profile_key: String = "default"
var _active_controller_name: String = "controller"
var _default_joy_events: Dictionary = {}
var _axis_rest_by_device: Dictionary = {}


func _ready() -> void:
	_capture_project_defaults()
	load_profiles()
	_refresh_active_controller()


func _input(event: InputEvent) -> void:
	var device_id: int = -1
	var button_event := event as InputEventJoypadButton
	if button_event != null and button_event.pressed:
		device_id = button_event.device
	var motion_event := event as InputEventJoypadMotion
	if (
		motion_event != null
		and absf(motion_event.axis_value) >= CAPTURE_AXIS_THRESHOLD
	):
		device_id = motion_event.device
	if device_id >= 0 and device_id != _active_device_id:
		_set_active_controller(device_id)


func _process(_delta: float) -> void:
	var connected: Array[int] = Input.get_connected_joypads()
	if connected.is_empty():
		connected.append(0)
	if not connected.has(_active_device_id):
		_set_active_controller(connected[0])
	elif (
		_active_controller_name == "controller"
		and Input.get_connected_joypads().has(_active_device_id)
	):
		_set_active_controller(_active_device_id)
	_sample_axis_rest_values(_active_device_id)


func load_profiles() -> bool:
	_recover_interrupted_write()
	if not FileAccess.file_exists(PROFILE_PATH):
		_profiles = {}
		return true
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return false
	if file.get_length() > MAX_PROFILE_BYTES:
		file.close()
		push_warning("Controller mappings are too large; using defaults.")
		_profiles = {}
		return false
	var json := JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()
	if error != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("Controller mappings are malformed; using defaults.")
		_profiles = {}
		return false
	var data: Dictionary = json.data
	if int(data.get("format_version", -1)) != FORMAT_VERSION:
		push_warning("Controller mapping version is unsupported; using defaults.")
		_profiles = {}
		return false
	var raw_profiles: Variant = data.get("profiles", {})
	if typeof(raw_profiles) != TYPE_DICTIONARY:
		_profiles = {}
		return false
	_profiles = _validated_profiles(raw_profiles as Dictionary)
	return true


func _validated_profiles(raw_profiles: Dictionary) -> Dictionary:
	var validated: Dictionary = {}
	for key_value: Variant in raw_profiles:
		var raw_profile: Variant = raw_profiles[key_value]
		if typeof(raw_profile) != TYPE_DICTIONARY:
			continue
		var profile := raw_profile as Dictionary
		var raw_bindings: Variant = profile.get("bindings", {})
		if typeof(raw_bindings) != TYPE_DICTIONARY:
			continue
		var bindings := raw_bindings as Dictionary
		var complete: bool = true
		for role: StringName in ROLE_ORDER:
			var raw_binding: Variant = bindings.get(str(role), {})
			if (
				typeof(raw_binding) != TYPE_DICTIONARY
				or not validate_binding(role, raw_binding as Dictionary)
			):
				complete = false
				break
		if not complete:
			continue
		validated[str(key_value)] = {
			"controller_name": str(
				profile.get("controller_name", "controller")
			),
			"bindings": bindings.duplicate(true),
		}
	return validated


func has_custom_mapping() -> bool:
	return _profiles.has(_active_profile_key)


func get_active_device_id() -> int:
	return _active_device_id


func get_active_controller_name() -> String:
	return _active_controller_name


func get_role_label(role: StringName) -> String:
	return str(ROLE_LABELS.get(role, str(role)))


func get_role_prompt(role: StringName) -> String:
	return str(ROLE_PROMPTS.get(role, "press or move the requested input"))


func role_expects_axis(role: StringName) -> bool:
	return role in STICK_AXIS_ROLES


func role_accepts_axis(role: StringName) -> bool:
	return role in STICK_AXIS_ROLES or role in TRIGGER_ROLES


func get_active_bindings() -> Dictionary:
	var raw_profile: Variant = _profiles.get(_active_profile_key, {})
	var profile: Dictionary = (
		raw_profile as Dictionary
		if typeof(raw_profile) == TYPE_DICTIONARY else {}
	)
	var bindings: Variant = profile.get("bindings", {})
	if (
		typeof(bindings) == TYPE_DICTIONARY
		and not (bindings as Dictionary).is_empty()
	):
		return (bindings as Dictionary).duplicate(true)
	return default_bindings()


func get_binding(role: StringName) -> Dictionary:
	var bindings: Dictionary = get_active_bindings()
	var binding: Variant = bindings.get(str(role), {})
	if typeof(binding) == TYPE_DICTIONARY:
		return (binding as Dictionary).duplicate(true)
	return {}


func set_binding(role: StringName, binding: Dictionary) -> bool:
	if role not in ROLE_ORDER or not validate_binding(role, binding):
		return false
	var bindings: Dictionary = get_active_bindings()
	bindings[str(role)] = binding.duplicate(true)
	return replace_active_bindings(bindings)


func replace_active_bindings(bindings: Dictionary) -> bool:
	for role: StringName in ROLE_ORDER:
		var binding: Variant = bindings.get(str(role), {})
		if typeof(binding) != TYPE_DICTIONARY:
			return false
		if not validate_binding(role, binding as Dictionary):
			return false
	var previous: Dictionary = _profiles.duplicate(true)
	_profiles[_active_profile_key] = {
		"controller_name": _active_controller_name,
		"bindings": bindings.duplicate(true),
	}
	if not _save_profiles():
		_profiles = previous
		return false
	_apply_active_profile()
	active_profile_changed.emit()
	return true


func reset_active_profile() -> bool:
	if not _profiles.has(_active_profile_key):
		_restore_project_defaults()
		active_profile_changed.emit()
		return true
	var previous: Dictionary = _profiles.duplicate(true)
	_profiles.erase(_active_profile_key)
	if not _save_profiles():
		_profiles = previous
		return false
	_restore_project_defaults()
	active_profile_changed.emit()
	return true


func binding_from_event(role: StringName, event: InputEvent) -> Dictionary:
	var button := event as InputEventJoypadButton
	if role in TRIGGER_ROLES and button != null and button.pressed:
		return {
			"kind": "button",
			"button": int(button.button_index),
		}
	if role_accepts_axis(role):
		var motion := event as InputEventJoypadMotion
		if motion == null:
			return {}
		_sample_axis_rest_values(motion.device)
		var rest: float = _axis_rest_value(motion.device, motion.axis)
		var travel: float = motion.axis_value - rest
		if absf(travel) < CAPTURE_AXIS_THRESHOLD:
			return {}
		return {
			"kind": "axis",
			"axis": int(motion.axis),
			"direction": signf(travel),
			"rest": rest,
		}
	if button == null or not button.pressed:
		return {}
	return {
		"kind": "button",
		"button": int(button.button_index),
	}


func validate_binding(role: StringName, binding: Dictionary) -> bool:
	var binding_kind: String = str(binding.get("kind", ""))
	if role_expects_axis(role) and binding_kind != "axis":
		return false
	if role not in STICK_AXIS_ROLES and role not in TRIGGER_ROLES:
		if binding_kind != "button":
			return false
	if role in TRIGGER_ROLES and binding_kind not in ["axis", "button"]:
		return false
	if binding_kind == "button":
		var button_index: int = int(binding.get("button", -1))
		return button_index >= 0 and button_index < JOY_BUTTON_MAX
	var axis_index: int = int(binding.get("axis", -1))
	var direction: float = float(binding.get("direction", 0.0))
	var rest: float = float(binding.get("rest", 0.0))
	return (
		axis_index >= 0
		and axis_index < JOY_AXIS_MAX
		and not is_zero_approx(direction)
		and rest >= -1.0
		and rest <= 1.0
	)


func binding_label(binding: Dictionary) -> String:
	if str(binding.get("kind", "")) == "button":
		return "button %d" % int(binding.get("button", -1))
	if str(binding.get("kind", "")) == "axis":
		return "axis %d %s" % [
			int(binding.get("axis", -1)),
			"+" if float(binding.get("direction", 0.0)) > 0.0 else "−",
		]
	return "unmapped"


func get_role_strength(role: StringName) -> float:
	if not has_custom_mapping():
		return 0.0
	var binding: Dictionary = get_binding(role)
	if str(binding.get("kind", "")) == "button":
		return (
			1.0
			if Input.is_joy_button_pressed(
				_active_device_id,
				int(binding.get("button", -1)),
			)
			else 0.0
		)
	return _axis_binding_strength(binding)


func get_role_axis(role: StringName) -> float:
	if not has_custom_mapping():
		return 0.0
	var binding: Dictionary = get_binding(role)
	if str(binding.get("kind", "")) != "axis":
		return 0.0
	var raw: float = Input.get_joy_axis(
		_active_device_id,
		int(binding.get("axis", -1)),
	)
	var direction: float = signf(float(binding.get("direction", -1.0)))
	var rest: float = float(binding.get("rest", 0.0))
	var delta: float = raw - rest
	if is_zero_approx(delta):
		return 0.0
	var toward_captured_direction: bool = signf(delta) == direction
	var endpoint: float = direction if toward_captured_direction else -direction
	var available: float = absf(endpoint - rest)
	if available <= 0.001:
		return 0.0
	var magnitude: float = clampf(absf(delta) / available, 0.0, 1.0)
	return -magnitude if toward_captured_direction else magnitude


func event_matches_role(event: InputEvent, role: StringName) -> bool:
	if not has_custom_mapping():
		return false
	var binding: Dictionary = get_binding(role)
	var button := event as InputEventJoypadButton
	if button != null and str(binding.get("kind", "")) == "button":
		return button.button_index == int(binding.get("button", -1))
	var motion := event as InputEventJoypadMotion
	if motion == null or str(binding.get("kind", "")) != "axis":
		return false
	if motion.axis != int(binding.get("axis", -1)):
		return false
	return _axis_binding_strength(binding, motion.axis_value) >= 0.5


func event_uses_role(event: InputEvent, role: StringName) -> bool:
	if not has_custom_mapping():
		return false
	var binding: Dictionary = get_binding(role)
	var button := event as InputEventJoypadButton
	if button != null and str(binding.get("kind", "")) == "button":
		return button.button_index == int(binding.get("button", -1))
	var motion := event as InputEventJoypadMotion
	return (
		motion != null
		and str(binding.get("kind", "")) == "axis"
		and motion.axis == int(binding.get("axis", -1))
	)


static func default_bindings() -> Dictionary:
	return {
		str(ROLE_A): _button_binding(JOY_BUTTON_A),
		str(ROLE_B): _button_binding(JOY_BUTTON_B),
		str(ROLE_X): _button_binding(JOY_BUTTON_X),
		str(ROLE_Y): _button_binding(JOY_BUTTON_Y),
		str(ROLE_LB): _button_binding(JOY_BUTTON_LEFT_SHOULDER),
		str(ROLE_RB): _button_binding(JOY_BUTTON_RIGHT_SHOULDER),
		str(ROLE_LT): _axis_binding(JOY_AXIS_TRIGGER_RIGHT, 1.0, 0.0),
		str(ROLE_RT): _axis_binding(JOY_AXIS_TRIGGER_LEFT, 1.0, 0.0),
		str(ROLE_SELECT): _button_binding(JOY_BUTTON_BACK),
		str(ROLE_START): _button_binding(JOY_BUTTON_START),
		str(ROLE_LEFT_STICK_CLICK): _button_binding(JOY_BUTTON_LEFT_STICK),
		str(ROLE_RIGHT_STICK_CLICK): _button_binding(JOY_BUTTON_RIGHT_STICK),
		str(ROLE_DPAD_UP): _button_binding(JOY_BUTTON_DPAD_UP),
		str(ROLE_DPAD_DOWN): _button_binding(JOY_BUTTON_DPAD_DOWN),
		str(ROLE_DPAD_LEFT): _button_binding(JOY_BUTTON_DPAD_LEFT),
		str(ROLE_DPAD_RIGHT): _button_binding(JOY_BUTTON_DPAD_RIGHT),
		str(ROLE_LEFT_STICK_X): _axis_binding(JOY_AXIS_LEFT_X, -1.0, 0.0),
		str(ROLE_LEFT_STICK_Y): _axis_binding(JOY_AXIS_LEFT_Y, -1.0, 0.0),
		str(ROLE_RIGHT_STICK_X): _axis_binding(JOY_AXIS_RIGHT_X, -1.0, 0.0),
		str(ROLE_RIGHT_STICK_Y): _axis_binding(JOY_AXIS_RIGHT_Y, -1.0, 0.0),
	}


static func _button_binding(button: JoyButton) -> Dictionary:
	return {"kind": "button", "button": int(button)}


static func _axis_binding(
	axis: JoyAxis,
	direction: float,
	rest: float,
) -> Dictionary:
	return {
		"kind": "axis",
		"axis": int(axis),
		"direction": direction,
		"rest": rest,
	}


func _axis_binding_strength(
	binding: Dictionary,
	raw_override: float = INF,
) -> float:
	var axis: int = int(binding.get("axis", -1))
	if axis < 0:
		return 0.0
	var raw: float = (
		Input.get_joy_axis(_active_device_id, axis)
		if is_inf(raw_override) else raw_override
	)
	var rest: float = float(binding.get("rest", 0.0))
	var direction: float = signf(float(binding.get("direction", 0.0)))
	var endpoint: float = direction
	var available: float = absf(endpoint - rest)
	if available <= 0.001:
		return 0.0
	return clampf((raw - rest) * direction / available, 0.0, 1.0)


func _refresh_active_controller() -> void:
	var connected: Array[int] = Input.get_connected_joypads()
	_set_active_controller(connected[0] if not connected.is_empty() else 0)


func _set_active_controller(device_id: int) -> void:
	var previous_profile_key: String = _active_profile_key
	_active_device_id = maxi(device_id, 0)
	var controller_is_listed: bool = Input.get_connected_joypads().has(
		_active_device_id
	)
	var guid: String = (
		Input.get_joy_guid(_active_device_id).strip_edges()
		if controller_is_listed else ""
	)
	var controller_name: String = (
		Input.get_joy_name(_active_device_id).strip_edges()
		if controller_is_listed else "controller"
	)
	if controller_name.is_empty():
		controller_name = "controller"
	_active_controller_name = controller_name
	_active_profile_key = (
		guid
		if not guid.is_empty()
		else "name:" + controller_name
	)
	if (
		previous_profile_key == "name:controller"
		and _active_profile_key != previous_profile_key
		and _profiles.has(previous_profile_key)
		and not _profiles.has(_active_profile_key)
	):
		var previous_profile: Variant = _profiles[previous_profile_key]
		if typeof(previous_profile) == TYPE_DICTIONARY:
			_profiles[_active_profile_key] = (
				previous_profile as Dictionary
			).duplicate(true)
			_profiles.erase(previous_profile_key)
			_save_profiles()
	_sample_axis_rest_values(_active_device_id)
	_apply_active_profile()
	active_controller_changed.emit(_active_controller_name)


func _sample_axis_rest_values(device_id: int) -> void:
	var key: String = str(device_id)
	if _axis_rest_by_device.has(key):
		return
	var values: Dictionary = {}
	for axis: int in JOY_AXIS_MAX:
		values[str(axis)] = Input.get_joy_axis(device_id, axis)
	_axis_rest_by_device[key] = values


func _axis_rest_value(device_id: int, axis: int) -> float:
	_sample_axis_rest_values(device_id)
	var values: Dictionary = _axis_rest_by_device.get(str(device_id), {})
	return float(values.get(str(axis), 0.0))


func _capture_project_defaults() -> void:
	for action: StringName in _all_managed_actions():
		var joy_events: Array[InputEvent] = []
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				joy_events.append(event.duplicate())
		_default_joy_events[action] = joy_events


func _all_managed_actions() -> Array[StringName]:
	var result: Array[StringName] = []
	for source: Dictionary in [
		BUTTON_ACTION_ROLES,
		AXIS_ACTION_ROLES,
		UI_DPAD_ACTION_ROLES,
	]:
		for action_value: Variant in source.keys():
			var action: StringName = StringName(action_value)
			if action not in result:
				result.append(action)
	return result


func _remove_managed_joy_events() -> void:
	for action: StringName in _all_managed_actions():
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				InputMap.action_erase_event(action, event)


func _restore_project_defaults() -> void:
	_remove_managed_joy_events()
	for action_value: Variant in _default_joy_events:
		var action: StringName = StringName(action_value)
		for event: InputEvent in _default_joy_events[action]:
			InputMap.action_add_event(action, event.duplicate())


func _apply_active_profile() -> void:
	if not has_custom_mapping():
		_restore_project_defaults()
		return
	_remove_managed_joy_events()
	var bindings: Dictionary = get_active_bindings()
	for action_value: Variant in BUTTON_ACTION_ROLES:
		var action: StringName = StringName(action_value)
		_add_button_action_binding(
			action,
			bindings.get(str(BUTTON_ACTION_ROLES[action]), {}),
		)
	for action_value: Variant in AXIS_ACTION_ROLES:
		var action: StringName = StringName(action_value)
		var role_data: Array = AXIS_ACTION_ROLES[action]
		_add_axis_action_binding(
			action,
			bindings.get(str(role_data[0]), {}),
			float(role_data[1]),
		)
	for action_value: Variant in UI_DPAD_ACTION_ROLES:
		var action: StringName = StringName(action_value)
		_add_button_action_binding(
			action,
			bindings.get(str(UI_DPAD_ACTION_ROLES[action]), {}),
		)


func _add_button_action_binding(action: StringName, value: Variant) -> void:
	if not InputMap.has_action(action) or typeof(value) != TYPE_DICTIONARY:
		return
	var binding: Dictionary = value as Dictionary
	if str(binding.get("kind", "")) != "button":
		return
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = int(binding.get("button", -1))
	InputMap.action_add_event(action, event)


func _add_axis_action_binding(
	action: StringName,
	value: Variant,
	logical_direction: float,
) -> void:
	if not InputMap.has_action(action) or typeof(value) != TYPE_DICTIONARY:
		return
	var binding: Dictionary = value as Dictionary
	if str(binding.get("kind", "")) != "axis":
		return
	var captured_negative_direction: float = signf(
		float(binding.get("direction", -1.0))
	)
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = int(binding.get("axis", -1))
	event.axis_value = logical_direction * -captured_negative_direction
	InputMap.action_add_event(action, event)


func _save_profiles() -> bool:
	var file := FileAccess.open(PROFILE_TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"format_version": FORMAT_VERSION,
		"profiles": _profiles,
	}, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		_remove_if_present(PROFILE_TEMP_PATH)
		return false
	_remove_if_present(PROFILE_BACKUP_PATH)
	var had_primary: bool = FileAccess.file_exists(PROFILE_PATH)
	if had_primary and not _rename_file(PROFILE_PATH, PROFILE_BACKUP_PATH):
		_remove_if_present(PROFILE_TEMP_PATH)
		return false
	if not _rename_file(PROFILE_TEMP_PATH, PROFILE_PATH):
		if had_primary:
			_rename_file(PROFILE_BACKUP_PATH, PROFILE_PATH)
		return false
	_remove_if_present(PROFILE_BACKUP_PATH)
	return true


func _recover_interrupted_write() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		_remove_if_present(PROFILE_TEMP_PATH)
		_remove_if_present(PROFILE_BACKUP_PATH)
		return
	if FileAccess.file_exists(PROFILE_BACKUP_PATH):
		_rename_file(PROFILE_BACKUP_PATH, PROFILE_PATH)
	_remove_if_present(PROFILE_TEMP_PATH)


func _rename_file(from_path: String, to_path: String) -> bool:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path),
	) == OK


func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
