class_name PlayerRelationshipStore
extends Node

signal relationship_changed(fingerprint: String)

const FORMAT_VERSION := 1
const MAX_RECORDS := 500

var _records: Dictionary = {}
var _loaded := false
var _write_blocked := false
var _store_path := ""
var _expected_hash := ""
var _data_root: PlayerDataRoot


func configure_storage(path: String, data_root: PlayerDataRoot) -> void:
	_store_path = path
	_data_root = data_root


func is_muted(fingerprint: String) -> bool:
	_ensure_loaded()
	return bool(_records.get(fingerprint, {}).get("muted", false))


func is_blocked(fingerprint: String) -> bool:
	_ensure_loaded()
	return bool(_records.get(fingerprint, {}).get("blocked", false))


func set_muted(fingerprint: String, display_name: String, value: bool) -> bool:
	if not _valid_target(fingerprint, display_name):
		return false
	_ensure_loaded()
	var record := _record(fingerprint, display_name)
	record["muted"] = value or bool(record.get("blocked", false))
	return _commit(fingerprint, record)


func set_blocked(fingerprint: String, display_name: String, value: bool) -> bool:
	if not _valid_target(fingerprint, display_name):
		return false
	_ensure_loaded()
	var record := _record(fingerprint, display_name)
	record["blocked"] = value
	if value:
		record["muted"] = true
	return _commit(fingerprint, record)


func get_records() -> Array[Dictionary]:
	_ensure_loaded()
	var result: Array[Dictionary] = []
	for value: Dictionary in _records.values():
		if bool(value.get("muted", false)) or bool(value.get("blocked", false)):
			result.append(value.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("last_known_display_name", "")).naturalnocasecmp_to(
			str(b.get("last_known_display_name", ""))
		) < 0
	)
	return result


func _record(fingerprint: String, display_name: String) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	var record: Dictionary = _records.get(fingerprint, {
		"fingerprint": fingerprint,
		"created_unix": now,
		"muted": false,
		"blocked": false,
	})
	record["last_known_display_name"] = display_name
	record["updated_unix"] = now
	return record


func _commit(fingerprint: String, record: Dictionary) -> bool:
	if _write_blocked:
		return false
	var previous: Dictionary = _records.duplicate(true)
	if not bool(record["muted"]) and not bool(record["blocked"]):
		_records.erase(fingerprint)
	else:
		_records[fingerprint] = record
	while _records.size() > MAX_RECORDS:
		_records.erase(_records.keys().front())
	if not _save():
		_records = previous
		return false
	relationship_changed.emit(fingerprint)
	return true


func _valid_target(fingerprint: String, display_name: String) -> bool:
	return (
		NetworkIdentityCrypto.valid_fingerprint(fingerprint)
		and NetworkProfilePreferences.is_valid_display_name(display_name)
	)


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
	for value: Variant in data.get("records", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = value
		var fingerprint := str(record.get("fingerprint", ""))
		if not NetworkIdentityCrypto.valid_fingerprint(fingerprint):
			continue
		record["blocked"] = bool(record.get("blocked", false))
		record["muted"] = bool(record.get("muted", false)) or record["blocked"]
		_records[fingerprint] = record.duplicate(true)
	_expected_hash = PortableFileGuard.hash_file(_store_path)


func _save() -> bool:
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
