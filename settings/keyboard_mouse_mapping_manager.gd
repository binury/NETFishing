class_name KeyboardMouseMappingManager
extends Node

signal mapping_changed

const FORMAT_VERSION: int = 1
const MAPPING_PATH: String = "user://keyboard_mouse_bindings.json"
const MAPPING_TEMP_PATH: String = "user://keyboard_mouse_bindings.json.tmp"
const MAPPING_BACKUP_PATH: String = (
	"user://keyboard_mouse_bindings.json.backup"
)
const MAX_MAPPING_BYTES: int = 256 * 1024

const ROLE_MOVE_FORWARD: StringName = &"move_forward"
const ROLE_MOVE_BACKWARD: StringName = &"move_backward"
const ROLE_MOVE_LEFT: StringName = &"move_left"
const ROLE_MOVE_RIGHT: StringName = &"move_right"
const ROLE_SPRINT: StringName = &"sprint"
const ROLE_JUMP: StringName = &"jump"
const ROLE_SNEAK: StringName = &"sneak"
const ROLE_SLOW_WALK: StringName = &"slow_walk"
const ROLE_INTERACT: StringName = &"interact"
const ROLE_PRIMARY_ACTION: StringName = &"fish_primary"
const ROLE_CAMERA_DRAG: StringName = &"camera_drag"
const ROLE_CAMERA_ZOOM_IN: StringName = &"camera_zoom_in"
const ROLE_CAMERA_ZOOM_OUT: StringName = &"camera_zoom_out"
const ROLE_PLAYER_MENU: StringName = &"open_backpack"
const ROLE_TACKLE_BOX: StringName = &"open_tacklebox"
const ROLE_PROP_BOOK: StringName = &"open_props"
const ROLE_EMOTE_WHEEL: StringName = &"open_emotes"
const ROLE_CHARACTER_CALL: StringName = &"character_call"
const ROLE_CHAT: StringName = &"open_chat"
const ROLE_FREE_CAMERA: StringName = &"toggle_free_camera"
const ROLE_HIDE_HUD: StringName = &"toggle_hud"
const ROLE_MENU_ACCEPT: StringName = &"ui_accept"
const ROLE_MENU_BACK: StringName = &"ui_cancel"

const ROLE_ORDER: Array[StringName] = [
	ROLE_MOVE_FORWARD,
	ROLE_MOVE_BACKWARD,
	ROLE_MOVE_LEFT,
	ROLE_MOVE_RIGHT,
	ROLE_SPRINT,
	ROLE_JUMP,
	ROLE_SNEAK,
	ROLE_SLOW_WALK,
	ROLE_INTERACT,
	ROLE_PRIMARY_ACTION,
	ROLE_CAMERA_DRAG,
	ROLE_CAMERA_ZOOM_IN,
	ROLE_CAMERA_ZOOM_OUT,
	ROLE_PLAYER_MENU,
	ROLE_TACKLE_BOX,
	ROLE_PROP_BOOK,
	ROLE_EMOTE_WHEEL,
	ROLE_CHARACTER_CALL,
	ROLE_CHAT,
	ROLE_FREE_CAMERA,
	ROLE_HIDE_HUD,
	&"hotbar_1",
	&"hotbar_2",
	&"hotbar_3",
	&"hotbar_4",
	&"hotbar_5",
	&"hotbar_6",
	&"hotbar_7",
	&"hotbar_8",
	&"hotbar_9",
	ROLE_MENU_ACCEPT,
	ROLE_MENU_BACK,
]

const ROLE_LABELS: Dictionary = {
	ROLE_MOVE_FORWARD: "move forward",
	ROLE_MOVE_BACKWARD: "move backward",
	ROLE_MOVE_LEFT: "move left",
	ROLE_MOVE_RIGHT: "move right",
	ROLE_SPRINT: "sprint",
	ROLE_JUMP: "jump",
	ROLE_SNEAK: "sneak",
	ROLE_SLOW_WALK: "slow walk",
	ROLE_INTERACT: "interact",
	ROLE_PRIMARY_ACTION: "primary action",
	ROLE_CAMERA_DRAG: "rotate camera",
	ROLE_CAMERA_ZOOM_IN: "camera zoom in",
	ROLE_CAMERA_ZOOM_OUT: "camera zoom out",
	ROLE_PLAYER_MENU: "player menu",
	ROLE_TACKLE_BOX: "tackle box",
	ROLE_PROP_BOOK: "prop book",
	ROLE_EMOTE_WHEEL: "emote wheel",
	ROLE_CHARACTER_CALL: "character call",
	ROLE_CHAT: "chat",
	ROLE_FREE_CAMERA: "free camera",
	ROLE_HIDE_HUD: "hide hud",
	&"hotbar_1": "hotbar 1",
	&"hotbar_2": "hotbar 2",
	&"hotbar_3": "hotbar 3",
	&"hotbar_4": "hotbar 4",
	&"hotbar_5": "hotbar 5",
	&"hotbar_6": "hotbar 6",
	&"hotbar_7": "hotbar 7",
	&"hotbar_8": "hotbar 8",
	&"hotbar_9": "hotbar 9",
	ROLE_MENU_ACCEPT: "menu accept",
	ROLE_MENU_BACK: "menu back / pause",
}

var _default_events: Dictionary = {}
var _default_bindings: Dictionary = {}
var _bindings: Dictionary = {}


func _ready() -> void:
	_capture_project_defaults()
	load_mapping()
	_apply_active_mapping()


func load_mapping() -> bool:
	_recover_interrupted_write()
	if not FileAccess.file_exists(MAPPING_PATH):
		_bindings = {}
		return true
	var file := FileAccess.open(MAPPING_PATH, FileAccess.READ)
	if file == null:
		_bindings = {}
		return false
	if file.get_length() > MAX_MAPPING_BYTES:
		file.close()
		push_warning("Keyboard bindings are too large; using defaults.")
		_bindings = {}
		return false
	var json := JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()
	if error != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_warning("Keyboard bindings are malformed; using defaults.")
		_bindings = {}
		return false
	var data := json.data as Dictionary
	if int(data.get("format_version", -1)) != FORMAT_VERSION:
		push_warning("Keyboard binding version is unsupported; using defaults.")
		_bindings = {}
		return false
	var raw_bindings: Variant = data.get("bindings", {})
	if (
		typeof(raw_bindings) != TYPE_DICTIONARY
		or not _validate_complete_bindings(raw_bindings as Dictionary)
	):
		push_warning("Keyboard bindings are incomplete; using defaults.")
		_bindings = {}
		return false
	_bindings = (raw_bindings as Dictionary).duplicate(true)
	return true


func has_custom_mapping() -> bool:
	return not _bindings.is_empty()


func get_active_bindings() -> Dictionary:
	if has_custom_mapping():
		return _bindings.duplicate(true)
	return _default_bindings.duplicate(true)


func get_role_label(role: StringName) -> String:
	return str(ROLE_LABELS.get(role, str(role).replace("_", " ")))


func binding_from_event(event: InputEvent) -> Dictionary:
	var key_event := event as InputEventKey
	if key_event != null:
		if not key_event.pressed or key_event.echo:
			return {}
		if key_event.keycode in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
			return {}
		if key_event.keycode == KEY_NONE and (
			key_event.physical_keycode == KEY_NONE
		):
			return {}
		return {
			"kind": "key",
			"keycode": int(key_event.keycode),
			"physical_keycode": int(key_event.physical_keycode),
			"alt": key_event.alt_pressed,
			"shift": key_event.shift_pressed,
			"ctrl": key_event.ctrl_pressed,
			"meta": key_event.meta_pressed,
			"location": int(key_event.location),
		}
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null or not mouse_event.pressed:
		return {}
	return {
		"kind": "mouse_button",
		"button": int(mouse_event.button_index),
	}


func validate_binding(binding: Dictionary) -> bool:
	var kind: String = str(binding.get("kind", ""))
	if kind == "mouse_button":
		var button: int = int(binding.get("button", 0))
		return (
			button >= int(MOUSE_BUTTON_LEFT)
			and button <= int(MOUSE_BUTTON_XBUTTON2)
		)
	if kind != "key":
		return false
	var keycode: int = int(binding.get("keycode", int(KEY_NONE)))
	var physical_keycode: int = int(
		binding.get("physical_keycode", int(KEY_NONE))
	)
	if keycode == int(KEY_NONE) and physical_keycode == int(KEY_NONE):
		return false
	for modifier: String in ["alt", "shift", "ctrl", "meta"]:
		if typeof(binding.get(modifier, false)) != TYPE_BOOL:
			return false
	return true


func set_binding(role: StringName, binding: Dictionary) -> bool:
	if role not in ROLE_ORDER or not validate_binding(binding):
		return false
	var updated: Dictionary = get_active_bindings()
	updated[str(role)] = binding.duplicate(true)
	return replace_active_bindings(updated)


func replace_active_bindings(bindings: Dictionary) -> bool:
	if not _validate_complete_bindings(bindings):
		return false
	var previous: Dictionary = _bindings.duplicate(true)
	_bindings = bindings.duplicate(true)
	if not _save_mapping():
		_bindings = previous
		return false
	_apply_active_mapping()
	mapping_changed.emit()
	return true


func reset_mapping() -> bool:
	var previous: Dictionary = _bindings.duplicate(true)
	_bindings = {}
	if not _remove_if_present(MAPPING_PATH):
		_bindings = previous
		return false
	_remove_if_present(MAPPING_TEMP_PATH)
	_remove_if_present(MAPPING_BACKUP_PATH)
	_restore_project_defaults()
	mapping_changed.emit()
	return true


func binding_label(binding: Dictionary) -> String:
	if str(binding.get("kind", "")) == "mouse_button":
		return _mouse_button_label(int(binding.get("button", 0)))
	if str(binding.get("kind", "")) != "key":
		return "unmapped"
	var event := _event_from_binding(binding) as InputEventKey
	if event == null:
		return "unmapped"
	var label: String = event.as_text_physical_keycode()
	if label.is_empty():
		label = event.as_text_keycode()
	return label.to_lower() if not label.is_empty() else "unknown key"


static func bindings_conflict(first: Dictionary, second: Dictionary) -> bool:
	if str(first.get("kind", "")) != str(second.get("kind", "")):
		return false
	if str(first.get("kind", "")) == "mouse_button":
		return int(first.get("button", 0)) == int(second.get("button", 0))
	if str(first.get("kind", "")) != "key":
		return false
	return (
		int(first.get("keycode", 0)) == int(second.get("keycode", 0))
		and int(first.get("physical_keycode", 0))
			== int(second.get("physical_keycode", 0))
		and bool(first.get("alt", false)) == bool(second.get("alt", false))
		and bool(first.get("shift", false)) == bool(second.get("shift", false))
		and bool(first.get("ctrl", false)) == bool(second.get("ctrl", false))
		and bool(first.get("meta", false)) == bool(second.get("meta", false))
	)


func _capture_project_defaults() -> void:
	_default_events.clear()
	_default_bindings.clear()
	for role: StringName in ROLE_ORDER:
		var action: StringName = role
		var events: Array[InputEvent] = []
		if InputMap.has_action(action):
			for event: InputEvent in InputMap.action_get_events(action):
				if not _is_keyboard_mouse_event(event):
					continue
				events.append(event.duplicate())
				if not _default_bindings.has(str(role)):
					var binding: Dictionary = binding_from_event(
						_pressed_copy(event)
					)
					if not binding.is_empty():
						_default_bindings[str(role)] = binding
		_default_events[action] = events


func _validate_complete_bindings(bindings: Dictionary) -> bool:
	for role: StringName in ROLE_ORDER:
		var raw_binding: Variant = bindings.get(str(role), {})
		if (
			typeof(raw_binding) != TYPE_DICTIONARY
			or not validate_binding(raw_binding as Dictionary)
		):
			return false
	return true


func _apply_active_mapping() -> void:
	if not has_custom_mapping():
		_restore_project_defaults()
		return
	_remove_managed_keyboard_mouse_events()
	for role: StringName in ROLE_ORDER:
		var binding: Variant = _bindings.get(str(role), {})
		if typeof(binding) != TYPE_DICTIONARY:
			continue
		var event: InputEvent = _event_from_binding(binding as Dictionary)
		if event != null:
			InputMap.action_add_event(role, event)


func _restore_project_defaults() -> void:
	_remove_managed_keyboard_mouse_events()
	for action_value: Variant in _default_events:
		var action: StringName = StringName(action_value)
		for event: InputEvent in _default_events[action]:
			InputMap.action_add_event(action, event.duplicate())


func _remove_managed_keyboard_mouse_events() -> void:
	for action: StringName in ROLE_ORDER:
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if _is_keyboard_mouse_event(event):
				InputMap.action_erase_event(action, event)


func _event_from_binding(binding: Dictionary) -> InputEvent:
	if not validate_binding(binding):
		return null
	if str(binding.get("kind", "")) == "mouse_button":
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = int(binding.get("button", 0)) as MouseButton
		return mouse_event
	var key_event := InputEventKey.new()
	key_event.keycode = int(binding.get("keycode", 0)) as Key
	key_event.physical_keycode = int(
		binding.get("physical_keycode", 0)
	) as Key
	key_event.alt_pressed = bool(binding.get("alt", false))
	key_event.shift_pressed = bool(binding.get("shift", false))
	key_event.ctrl_pressed = bool(binding.get("ctrl", false))
	key_event.meta_pressed = bool(binding.get("meta", false))
	key_event.location = int(binding.get("location", 0)) as KeyLocation
	return key_event


static func _pressed_copy(event: InputEvent) -> InputEvent:
	var result: InputEvent = event.duplicate()
	if result is InputEventKey:
		(result as InputEventKey).pressed = true
	elif result is InputEventMouseButton:
		(result as InputEventMouseButton).pressed = true
	return result


static func _is_keyboard_mouse_event(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton


static func _mouse_button_label(button: int) -> String:
	var labels: Dictionary = {
		int(MOUSE_BUTTON_LEFT): "mouse left",
		int(MOUSE_BUTTON_RIGHT): "mouse right",
		int(MOUSE_BUTTON_MIDDLE): "mouse middle",
		int(MOUSE_BUTTON_WHEEL_UP): "wheel up",
		int(MOUSE_BUTTON_WHEEL_DOWN): "wheel down",
		int(MOUSE_BUTTON_WHEEL_LEFT): "wheel left",
		int(MOUSE_BUTTON_WHEEL_RIGHT): "wheel right",
		int(MOUSE_BUTTON_XBUTTON1): "mouse 4",
		int(MOUSE_BUTTON_XBUTTON2): "mouse 5",
	}
	return str(labels.get(button, "mouse %d" % button))


func _save_mapping() -> bool:
	var file := FileAccess.open(MAPPING_TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"format_version": FORMAT_VERSION,
		"bindings": _bindings,
	}, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		_remove_if_present(MAPPING_TEMP_PATH)
		return false
	_remove_if_present(MAPPING_BACKUP_PATH)
	var had_primary: bool = FileAccess.file_exists(MAPPING_PATH)
	if had_primary and not _rename_file(MAPPING_PATH, MAPPING_BACKUP_PATH):
		_remove_if_present(MAPPING_TEMP_PATH)
		return false
	if not _rename_file(MAPPING_TEMP_PATH, MAPPING_PATH):
		if had_primary:
			_rename_file(MAPPING_BACKUP_PATH, MAPPING_PATH)
		return false
	_remove_if_present(MAPPING_BACKUP_PATH)
	return true


func _recover_interrupted_write() -> void:
	if FileAccess.file_exists(MAPPING_PATH):
		_remove_if_present(MAPPING_TEMP_PATH)
		_remove_if_present(MAPPING_BACKUP_PATH)
		return
	if FileAccess.file_exists(MAPPING_BACKUP_PATH):
		_rename_file(MAPPING_BACKUP_PATH, MAPPING_PATH)
	_remove_if_present(MAPPING_TEMP_PATH)


static func _rename_file(from_path: String, to_path: String) -> bool:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path),
	) == OK


static func _remove_if_present(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(
		ProjectSettings.globalize_path(path)
	) == OK
