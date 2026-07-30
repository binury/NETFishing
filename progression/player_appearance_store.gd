class_name PlayerAppearanceStore
extends Node

const FORMAT_VERSION: int = 1
var _snapshot: Dictionary = CharacterCustomizationCatalog.default_snapshot()
var _loaded: bool = false
var _future_version: bool = false
var _profile_path := ""
var _expected_hash := ""
var _data_root: PlayerDataRoot


func configure_storage(path: String, data_root: PlayerDataRoot) -> void:
	_profile_path = path
	_data_root = data_root


func _temp_path() -> String:
	return _profile_path + ".tmp"


func _backup_path() -> String:
	return _profile_path + ".backup"


func load_preferences() -> bool:
	if _profile_path.is_empty():
		return false
	_recover_interrupted_write()
	if not FileAccess.file_exists(_profile_path):
		_snapshot = CharacterCustomizationCatalog.default_snapshot()
		_loaded = true
		return true
	var file := FileAccess.open(_profile_path, FileAccess.READ)
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
	_expected_hash = PortableFileGuard.hash_file(_profile_path)
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
	var bytes := JSON.stringify({
		"format_version": FORMAT_VERSION,
		"appearance": _snapshot,
	}, "\t").to_utf8_buffer()
	var result := PortableFileGuard.write_guarded(
		_profile_path, bytes, _expected_hash, _data_root.conflict_directory(),
		_data_root.device_id,
	)
	if bool(result.get("conflict", false)):
		_data_root.report_conflict(str(result.get("message", "")), str(result.get("conflict_path", "")))
	if bool(result.get("ok", false)):
		_expected_hash = str(result["hash"])
	return bool(result.get("ok", false))


func _recover_interrupted_write() -> void:
	if FileAccess.file_exists(_profile_path):
		_remove(_temp_path())
		return
	if FileAccess.file_exists(_backup_path()):
		_rename(_backup_path(), _profile_path)
	_remove(_temp_path())


func _recover_backup() -> bool:
	if not FileAccess.file_exists(_backup_path()):
		return false
	var primary_path := _profile_path
	var backup_path := _backup_path()
	var corrupt_path := "%s.corrupt.%d.json" % [_profile_path.get_basename(), int(Time.get_unix_time_from_system())]
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
