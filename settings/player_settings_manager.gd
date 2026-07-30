class_name PlayerSettingsManager
extends Node

const SETTINGS_VERSION: int = 1
const SETTINGS_PATH: String = "user://player_settings.json"
const TEMP_PATH: String = "user://player_settings.json.tmp"
const BACKUP_PATH: String = "user://player_settings.json.backup"

signal settings_changed(settings: PlayerSettings)

var current_settings: PlayerSettings = PlayerSettings.new()
var _is_dirty: bool = false


func load_settings() -> bool:
	_recover_interrupted_write()
	if not FileAccess.file_exists(SETTINGS_PATH):
		current_settings = PlayerSettings.new()
		emit_signal("settings_changed", current_settings)
		return true
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		push_warning("Unable to open player settings; using defaults.")
		current_settings = PlayerSettings.new()
		emit_signal("settings_changed", current_settings)
		return false
	var json := JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()
	if error != OK or typeof(json.data) != TYPE_DICTIONARY:
		return _use_defaults_after_corruption("Player settings JSON is malformed.")
	var data: Dictionary = json.data
	if _read_integer(data.get("settings_version"), -1) != SETTINGS_VERSION:
		return _use_defaults_after_corruption("Player settings version is unsupported.")
	if (
		typeof(data.get("accessibility")) != TYPE_DICTIONARY
		or typeof(data.get("camera")) != TYPE_DICTIONARY
	):
		return _use_defaults_after_corruption("Player settings structure is invalid.")
	var accessibility: Dictionary = data["accessibility"]
	var camera: Dictionary = data["camera"]
	var presentation: Dictionary = {}
	if typeof(data.get("presentation")) == TYPE_DICTIONARY:
		presentation = data["presentation"]
	if (
		typeof(accessibility.get("auto_click_enabled")) != TYPE_BOOL
		or typeof(camera.get("invert_vertical")) != TYPE_BOOL
		or (
			accessibility.has("use_readable_interface_font")
			and typeof(accessibility["use_readable_interface_font"]) != TYPE_BOOL
		)
		or (
			presentation.has("chat_draft")
			and typeof(presentation["chat_draft"]) != TYPE_STRING
		)
		or (
			presentation.has("chat_collapsed")
			and typeof(presentation["chat_collapsed"]) != TYPE_BOOL
		)
	):
		return _use_defaults_after_corruption("Player settings values are invalid.")
	var loaded := PlayerSettings.new()
	loaded.auto_click_enabled = accessibility["auto_click_enabled"]
	loaded.use_readable_interface_font = bool(
		accessibility.get("use_readable_interface_font", false)
	)
	loaded.auto_click_interval = _read_float(
		accessibility.get("auto_click_interval"),
		-1.0
	)
	loaded.mouse_camera_sensitivity = _read_float(
		camera.get("mouse_sensitivity"),
		-1.0
	)
	loaded.controller_camera_sensitivity = _read_float(
		camera.get("controller_sensitivity"),
		-1.0
	)
	loaded.invert_camera_y = camera["invert_vertical"]
	loaded.world_pixel_size = _read_clamped_integer(
		presentation.get(
			"world_pixel_size",
			PlayerSettings.DEFAULT_WORLD_PIXEL_SIZE
		),
		PlayerSettings.MIN_WORLD_PIXEL_SIZE,
		PlayerSettings.MAX_WORLD_PIXEL_SIZE,
		PlayerSettings.DEFAULT_WORLD_PIXEL_SIZE
	)
	loaded.ui_pixel_size = _read_clamped_integer(
		presentation.get(
			"ui_pixel_size",
			PlayerSettings.DEFAULT_UI_PIXEL_SIZE
		),
		PlayerSettings.MIN_UI_PIXEL_SIZE,
		PlayerSettings.MAX_UI_PIXEL_SIZE,
		PlayerSettings.DEFAULT_UI_PIXEL_SIZE
	)
	loaded.chat_draft = str(presentation.get("chat_draft", "")).left(
		PlayerSettings.MAX_CHAT_DRAFT_CHARACTERS
	)
	loaded.chat_collapsed = bool(presentation.get("chat_collapsed", false))
	if not loaded.is_valid():
		return _use_defaults_after_corruption("Player settings values are invalid.")
	current_settings = loaded
	_is_dirty = false
	emit_signal("settings_changed", current_settings)
	return true


func apply_settings(settings: PlayerSettings) -> bool:
	if settings == null or not settings.is_valid():
		return false
	var previous: PlayerSettings = current_settings
	current_settings = settings.copy()
	_is_dirty = true
	if not save_now():
		current_settings = previous
		return false
	emit_signal("settings_changed", current_settings)
	return true


func apply_pixelation(world_pixel_size: int, ui_pixel_size: int) -> bool:
	var edited: PlayerSettings = current_settings.copy()
	edited.world_pixel_size = clampi(
		world_pixel_size,
		PlayerSettings.MIN_WORLD_PIXEL_SIZE,
		PlayerSettings.MAX_WORLD_PIXEL_SIZE
	)
	edited.ui_pixel_size = clampi(
		ui_pixel_size,
		PlayerSettings.MIN_UI_PIXEL_SIZE,
		PlayerSettings.MAX_UI_PIXEL_SIZE
	)
	return apply_settings(edited)


func update_chat_preferences(draft: String, collapsed: bool) -> void:
	var clean_draft := draft.left(PlayerSettings.MAX_CHAT_DRAFT_CHARACTERS)
	if (
		current_settings.chat_draft == clean_draft
		and current_settings.chat_collapsed == collapsed
	):
		return
	current_settings.chat_draft = clean_draft
	current_settings.chat_collapsed = collapsed
	_is_dirty = true


func save_chat_preferences() -> bool:
	return save_if_dirty()


func save_now() -> bool:
	if current_settings == null or not current_settings.is_valid():
		return false
	var data: Dictionary = {
		"settings_version": SETTINGS_VERSION,
		"accessibility": {
			"auto_click_enabled": current_settings.auto_click_enabled,
			"auto_click_interval": current_settings.auto_click_interval,
			"use_readable_interface_font": (
				current_settings.use_readable_interface_font
			),
		},
		"camera": {
			"mouse_sensitivity": current_settings.mouse_camera_sensitivity,
			"controller_sensitivity": current_settings.controller_camera_sensitivity,
			"invert_vertical": current_settings.invert_camera_y,
		},
		"presentation": {
			"world_pixel_size": current_settings.world_pixel_size,
			"ui_pixel_size": current_settings.ui_pixel_size,
			"chat_draft": current_settings.chat_draft,
			"chat_collapsed": current_settings.chat_collapsed,
		},
	}
	if current_settings.chat_draft.is_empty():
		(data["presentation"] as Dictionary).erase("chat_draft")
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		_remove_if_present(TEMP_PATH)
		return false
	var had_primary: bool = FileAccess.file_exists(SETTINGS_PATH)
	_remove_if_present(BACKUP_PATH)
	if had_primary and not _rename_file(SETTINGS_PATH, BACKUP_PATH):
		_remove_if_present(TEMP_PATH)
		return false
	if not _rename_file(TEMP_PATH, SETTINGS_PATH):
		if had_primary:
			_rename_file(BACKUP_PATH, SETTINGS_PATH)
		return false
	_remove_if_present(BACKUP_PATH)
	_is_dirty = false
	return true


func save_if_dirty() -> bool:
	return not _is_dirty or save_now()


func _exit_tree() -> void:
	save_if_dirty()


func _use_defaults_after_corruption(message: String) -> bool:
	push_warning(message)
	current_settings = PlayerSettings.new()
	_is_dirty = false
	emit_signal("settings_changed", current_settings)
	return false


func _recover_interrupted_write() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		_remove_if_present(TEMP_PATH)
		_remove_if_present(BACKUP_PATH)
		return
	if FileAccess.file_exists(BACKUP_PATH):
		_rename_file(BACKUP_PATH, SETTINGS_PATH)
	_remove_if_present(TEMP_PATH)


func _read_integer(value: Variant, fallback: int) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	if typeof(value) == TYPE_FLOAT and is_equal_approx(value, round(value)):
		return int(round(value))
	return fallback


func _read_float(value: Variant, fallback: float) -> float:
	if typeof(value) not in [TYPE_FLOAT, TYPE_INT]:
		return fallback
	var result: float = float(value)
	return result if is_finite(result) else fallback


func _read_clamped_integer(
	value: Variant,
	minimum: int,
	maximum: int,
	fallback: int,
) -> int:
	var result: int = _read_integer(value, fallback)
	return clampi(result, minimum, maximum)


func _rename_file(from_path: String, to_path: String) -> bool:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path)
	) == OK


func _remove_if_present(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(
		ProjectSettings.globalize_path(path)
	) == OK
