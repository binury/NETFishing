class_name KnownPlayerStore
extends Node

const FORMAT_VERSION: int = 1
const MAX_RECORDS: int = 500

var _records: Dictionary = {}
var _loaded: bool = false
var _write_blocked: bool = false
var _store_path := ""
var _expected_hash := ""
var _data_root: PlayerDataRoot


func configure_storage(path: String, data_root: PlayerDataRoot) -> void:
	_store_path = path
	_data_root = data_root


func observe(fingerprint: String, display_name: String) -> String:
	_ensure_loaded()
	if (
		not NetworkIdentityCrypto.valid_fingerprint(fingerprint)
		or not NetworkProfilePreferences.is_valid_display_name(display_name)
	):
		return ""
	var now := int(Time.get_unix_time_from_system())
	var status := "New identity"
	var record: Dictionary = _records.get(fingerprint, {})
	if not record.is_empty():
		status = "Known player"
	else:
		for value: Dictionary in _records.values():
			if str(value.get("last_known_display_name", "")).nocasecmp_to(display_name) == 0:
				status = "New identity using a familiar name"
				break
		record = {
			"fingerprint": fingerprint,
			"first_seen_unix": now,
			"locally_verified": false,
		}
	record["last_known_display_name"] = display_name
	record["last_seen_unix"] = now
	_records[fingerprint] = record
	_bound_records()
	_save()
	return status


func get_record(fingerprint: String) -> Dictionary:
	_ensure_loaded()
	return Dictionary(_records.get(fingerprint, {})).duplicate(true)


func identity_status(fingerprint: String, display_name: String) -> String:
	_ensure_loaded()
	var record: Dictionary = _records.get(fingerprint, {})
	if not record.is_empty():
		return "Known player"
	for value: Dictionary in _records.values():
		if str(value.get("last_known_display_name", "")).nocasecmp_to(display_name) == 0:
			return "New identity using a familiar name"
	return "New identity"


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if _store_path.is_empty() or not FileAccess.file_exists(_store_path):
		return
	var file := FileAccess.open(_store_path, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	var data: Dictionary = json.data
	if data.get("format_version") != FORMAT_VERSION:
		_write_blocked = true
		return
	if typeof(data.get("records")) != TYPE_ARRAY:
		return
	for value: Variant in data["records"]:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = value
		var fingerprint := str(record.get("fingerprint", ""))
		if NetworkIdentityCrypto.valid_fingerprint(fingerprint):
			_records[fingerprint] = record.duplicate(true)
	_expected_hash = PortableFileGuard.hash_file(_store_path)


func _save() -> bool:
	if _write_blocked:
		return false
	var bytes := JSON.stringify({
		"format_version": FORMAT_VERSION,
		"records": _records.values(),
	}, "\t").to_utf8_buffer()
	var result := PortableFileGuard.write_guarded(
		_store_path, bytes, _expected_hash, _data_root.conflict_directory(),
		_data_root.device_id,
	)
	if bool(result.get("conflict", false)):
		_data_root.report_conflict(str(result.get("message", "")), str(result.get("conflict_path", "")))
	if bool(result.get("ok", false)):
		_expected_hash = str(result["hash"])
	return bool(result.get("ok", false))


func _bound_records() -> void:
	while _records.size() > MAX_RECORDS:
		var oldest_key := ""
		var oldest_time := 9223372036854775807
		for key: String in _records:
			var seen := int(_records[key].get("last_seen_unix", 0))
			if seen < oldest_time:
				oldest_time = seen
				oldest_key = key
		_records.erase(oldest_key)
