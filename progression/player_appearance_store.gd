class_name PlayerAppearanceStore
extends Node

const FORMAT_VERSION: int = 1
const PROFILE_PATH: String = "user://player_appearance.json"
const TEMP_PATH: String = "user://player_appearance.json.tmp"
const BACKUP_PATH: String = "user://player_appearance.json.backup"

var _snapshot: Dictionary = CharacterCustomizationCatalog.default_snapshot()
var _loaded: bool = false
var _future_version: bool = false


func load_preferences() -> bool:
	_recover_interrupted_write()
	if not FileAccess.file_exists(PROFILE_PATH):
		_snapshot = CharacterCustomizationCatalog.default_snapshot()
		_loaded = true
		return true
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	file.close()
	if error != OK or typeof(json.data) != TYPE_DICTIONARY:
		return _recover_backup()
	var data: Dictionary = json.data
	if typeof(data.get("format_version")) not in [TYPE_INT, TYPE_FLOAT]:
		return _recover_backup()
	var version := int(data["format_version"])
	if version > FORMAT_VERSION:
		_future_version = true
		_loaded = false
		return false
	if version != FORMAT_VERSION or typeof(data.get("appearance")) != TYPE_DICTIONARY:
		return _recover_backup()
	_snapshot = CharacterCustomizationCatalog.sanitized_snapshot(data["appearance"])
	_loaded = true
	return true


func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)


func save_snapshot(value: Dictionary) -> bool:
	if _future_version or not CharacterCustomizationCatalog.validate_snapshot(value):
		return false
	var previous := _snapshot.duplicate(true)
	_snapshot = value.duplicate(true)
	if _save_atomic():
		_loaded = true
		return true
	_snapshot = previous
	return false


func is_loaded() -> bool:
	return _loaded


func _save_atomic() -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"format_version": FORMAT_VERSION,
		"appearance": _snapshot,
	}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		_remove(TEMP_PATH)
		return false
	_remove(BACKUP_PATH)
	var had_primary := FileAccess.file_exists(PROFILE_PATH)
	if had_primary and not _rename(PROFILE_PATH, BACKUP_PATH):
		_remove(TEMP_PATH)
		return false
	if not _rename(TEMP_PATH, PROFILE_PATH):
		if had_primary:
			_rename(BACKUP_PATH, PROFILE_PATH)
		return false
	_remove(BACKUP_PATH)
	return true


func _recover_interrupted_write() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		_remove(TEMP_PATH)
		return
	if FileAccess.file_exists(BACKUP_PATH):
		_rename(BACKUP_PATH, PROFILE_PATH)
	_remove(TEMP_PATH)


func _recover_backup() -> bool:
	if not FileAccess.file_exists(BACKUP_PATH):
		return false
	var primary_path := ProjectSettings.globalize_path(PROFILE_PATH)
	var backup_path := ProjectSettings.globalize_path(BACKUP_PATH)
	var corrupt_path := ProjectSettings.globalize_path(
		"user://player_appearance.corrupt.%d.json"
		% int(Time.get_unix_time_from_system())
	)
	DirAccess.rename_absolute(primary_path, corrupt_path)
	if DirAccess.rename_absolute(backup_path, primary_path) != OK:
		return false
	return load_preferences()


func _rename(from_path: String, to_path: String) -> bool:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path),
	) == OK


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
