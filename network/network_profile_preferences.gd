class_name NetworkProfilePreferences
extends Node

const FORMAT_VERSION: int = 1
const PROFILE_PATH: String = "user://network_profile.json"
const TEMP_PATH: String = "user://network_profile.json.tmp"
const BACKUP_PATH: String = "user://network_profile.json.backup"

var profile_id: String = ""
var display_name: String = "Player"
var created_at_unix: int = 0


func load_or_create() -> bool:
	_recover_interrupted_write()
	if FileAccess.file_exists(PROFILE_PATH):
		if _load_existing():
			return true
		var corrupt_path: String = (
			"user://network_profile.corrupt.%d.json"
			% int(Time.get_unix_time_from_system())
		)
		if not _rename(PROFILE_PATH, corrupt_path):
			push_warning("Invalid network profile was preserved and not overwritten.")
			return false
	profile_id = Crypto.new().generate_random_bytes(16).hex_encode()
	if profile_id.is_empty():
		profile_id = "%d-%d" % [
			int(Time.get_unix_time_from_system()),
			Time.get_ticks_usec(),
		]
	display_name = "Player"
	created_at_unix = int(Time.get_unix_time_from_system())
	return _save_atomic()


func _load_existing() -> bool:
	var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()
	if error != OK or typeof(json.data) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = json.data
	if (
		data.get("format_version") != FORMAT_VERSION
		or typeof(data.get("profile_id")) != TYPE_STRING
		or typeof(data.get("display_name")) != TYPE_STRING
		or typeof(data.get("created_at_unix")) not in [TYPE_INT, TYPE_FLOAT]
	):
		return false
	var loaded_id: String = data["profile_id"]
	var loaded_name: String = data["display_name"]
	if (
		loaded_id.is_empty()
		or loaded_id.length() > NetworkProtocol.MAX_PROFILE_ID_LENGTH
		or loaded_name.is_empty()
		or loaded_name.length() > NetworkProtocol.MAX_DISPLAY_NAME_LENGTH
	):
		return false
	profile_id = loaded_id
	display_name = loaded_name
	created_at_unix = int(data["created_at_unix"])
	return true


func _save_atomic() -> bool:
	var data: Dictionary = {
		"format_version": FORMAT_VERSION,
		"profile_id": profile_id,
		"display_name": display_name,
		"created_at_unix": created_at_unix,
	}
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		_remove_if_present(TEMP_PATH)
		return false
	_remove_if_present(BACKUP_PATH)
	var had_primary: bool = FileAccess.file_exists(PROFILE_PATH)
	if had_primary and not _rename(PROFILE_PATH, BACKUP_PATH):
		_remove_if_present(TEMP_PATH)
		return false
	if not _rename(TEMP_PATH, PROFILE_PATH):
		if had_primary:
			_rename(BACKUP_PATH, PROFILE_PATH)
		return false
	_remove_if_present(BACKUP_PATH)
	return true


func _recover_interrupted_write() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		_remove_if_present(TEMP_PATH)
		_remove_if_present(BACKUP_PATH)
		return
	if FileAccess.file_exists(BACKUP_PATH):
		_rename(BACKUP_PATH, PROFILE_PATH)
	_remove_if_present(TEMP_PATH)


func _rename(from_path: String, to_path: String) -> bool:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path)
	) == OK


func _remove_if_present(path: String) -> bool:
	return (
		not FileAccess.file_exists(path)
		or DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
	)
