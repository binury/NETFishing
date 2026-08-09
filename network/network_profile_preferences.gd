class_name NetworkProfilePreferences
extends Node

const FORMAT_VERSION: int = 1
const VoiceProfilesType = preload(
	"res://player/animalese_voice_profiles.gd"
)
var profile_id: String = ""
var display_name: String = "Player"
var voice_id: String = VoiceProfilesType.DEFAULT_ID
var speech_speed_id: String = VoiceProfilesType.DEFAULT_SPEED_ID
var call_id: String = VoiceProfilesType.DEFAULT_CALL_ID
var created_at_unix: int = 0
var _profile_path := ""
var _expected_hash := ""
var _data_root: PlayerDataRoot
var _future_version := false


func configure_storage(path: String, data_root: PlayerDataRoot) -> void:
	_profile_path = path
	_data_root = data_root


func _temp_path() -> String:
	return _profile_path + ".tmp"


func _backup_path() -> String:
	return _profile_path + ".backup"


func load_or_create() -> bool:
	if _profile_path.is_empty():
		return false
	_recover_interrupted_write()
	if FileAccess.file_exists(_profile_path):
		if _load_existing():
			_expected_hash = PortableFileGuard.hash_file(_profile_path)
			return true
		if _future_version:
			return false
		var corrupt_path: String = (
			"%s.corrupt.%d.json"
			% [_profile_path.get_basename(), int(Time.get_unix_time_from_system())]
		)
		if not _rename(_profile_path, corrupt_path):
			push_warning("Invalid network profile was preserved and not overwritten.")
			return false
	profile_id = Crypto.new().generate_random_bytes(16).hex_encode()
	if profile_id.is_empty():
		profile_id = "%d-%d" % [
			int(Time.get_unix_time_from_system()),
			Time.get_ticks_usec(),
		]
	display_name = "Player"
	voice_id = VoiceProfilesType.DEFAULT_ID
	speech_speed_id = VoiceProfilesType.DEFAULT_SPEED_ID
	call_id = VoiceProfilesType.DEFAULT_CALL_ID
	created_at_unix = int(Time.get_unix_time_from_system())
	return _save_atomic()


func set_display_name(value: String) -> bool:
	return set_profile_identity(value, voice_id, speech_speed_id, call_id)


func set_profile_identity(
	value: String,
	selected_voice_id: String,
	selected_speech_speed_id: String,
	selected_call_id: String,
) -> bool:
	var clean_name: String = value.strip_edges()
	if (
		not is_valid_display_name(clean_name)
		or not VoiceProfilesType.is_valid(selected_voice_id)
		or not VoiceProfilesType.is_valid_speed(selected_speech_speed_id)
		or not VoiceProfilesType.is_valid_call(selected_call_id)
	):
		return false
	var previous_name: String = display_name
	var previous_voice_id: String = voice_id
	var previous_speech_speed_id: String = speech_speed_id
	var previous_call_id: String = call_id
	display_name = clean_name
	voice_id = selected_voice_id
	speech_speed_id = selected_speech_speed_id
	call_id = selected_call_id
	if _save_atomic():
		return true
	display_name = previous_name
	voice_id = previous_voice_id
	speech_speed_id = previous_speech_speed_id
	call_id = previous_call_id
	return false


static func is_valid_display_name(value: String) -> bool:
	var clean_name := value.strip_edges()
	if clean_name.is_empty() or clean_name.length() > 24:
		return false
	for index: int in clean_name.length():
		var codepoint: int = clean_name.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			return false
	return true


func _load_existing() -> bool:
	var file := FileAccess.open(_profile_path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()
	if error != OK or typeof(json.data) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = json.data
	if (
		typeof(data.get("format_version")) in [TYPE_INT, TYPE_FLOAT]
		and int(data.get("format_version")) > FORMAT_VERSION
	):
		_future_version = true
		return false
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
	voice_id = VoiceProfilesType.sanitized_id(
		str(data.get("voice_id", VoiceProfilesType.DEFAULT_ID))
	)
	speech_speed_id = VoiceProfilesType.sanitized_speed_id(
		str(data.get("speech_speed_id", VoiceProfilesType.DEFAULT_SPEED_ID))
	)
	call_id = VoiceProfilesType.sanitized_call_id(
		str(data.get("call_id", VoiceProfilesType.DEFAULT_CALL_ID))
	)
	created_at_unix = int(data["created_at_unix"])
	return true


func _save_atomic() -> bool:
	var data: Dictionary = {
		"format_version": FORMAT_VERSION,
		"profile_id": profile_id,
		"display_name": display_name,
		"voice_id": voice_id,
		"speech_speed_id": speech_speed_id,
		"call_id": call_id,
		"created_at_unix": created_at_unix,
	}
	var result := PortableFileGuard.write_guarded(
		_profile_path,
		JSON.stringify(data, "\t").to_utf8_buffer(),
		_expected_hash,
		_data_root.conflict_directory(),
		_data_root.device_id,
	)
	if bool(result.get("conflict", false)):
		_data_root.report_conflict(
			str(result.get("message", "")),
			str(result.get("conflict_path", "")),
		)
	if bool(result.get("ok", false)):
		_expected_hash = str(result["hash"])
	return bool(result.get("ok", false))


func _recover_interrupted_write() -> void:
	if FileAccess.file_exists(_profile_path):
		_remove_if_present(_temp_path())
		_remove_if_present(_backup_path())
		return
	if FileAccess.file_exists(_backup_path()):
		_rename(_backup_path(), _profile_path)
	_remove_if_present(_temp_path())


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
