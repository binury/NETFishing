class_name ServerTrustStore
extends Node

const FORMAT_VERSION: int = 1
const STORE_PATH: String = "user://server_trust.json"
const TEMP_PATH: String = STORE_PATH + ".tmp"

enum Verification {
	FIRST_SEEN,
	MATCH,
	CHANGED,
}

var _records: Dictionary = {}
var _loaded: bool = false
var _write_blocked: bool = false


func verify(endpoint: ConnectionEndpoint, fingerprint: String) -> Verification:
	_ensure_loaded()
	if endpoint == null or not endpoint.is_valid():
		return Verification.CHANGED
	var record: Dictionary = _records.get(endpoint.normalized_display, {})
	if record.is_empty():
		return Verification.FIRST_SEEN
	return (
		Verification.MATCH
		if record.get("fingerprint") == fingerprint
		else Verification.CHANGED
	)


func get_record(endpoint: ConnectionEndpoint) -> Dictionary:
	_ensure_loaded()
	if endpoint == null:
		return {}
	return Dictionary(_records.get(endpoint.normalized_display, {})).duplicate(true)


func trust(
	endpoint: ConnectionEndpoint,
	fingerprint: String,
	server_name: String = "",
) -> bool:
	_ensure_loaded()
	if (
		endpoint == null
		or not endpoint.is_valid()
		or not NetworkIdentityCrypto.valid_fingerprint(fingerprint)
	):
		return false
	var now := int(Time.get_unix_time_from_system())
	var previous: Dictionary = _records.get(endpoint.normalized_display, {})
	_records[endpoint.normalized_display] = {
		"route_kind": "direct",
		"normalized_host": endpoint.host,
		"port": endpoint.port,
		"normalized_endpoint": endpoint.normalized_display,
		"fingerprint": fingerprint,
		"first_seen_unix": int(previous.get("first_seen_unix", now)),
		"last_seen_unix": now,
		"last_observed_server_name": server_name.left(80),
		"trust_state": "pinned",
	}
	return _save()


func touch(endpoint: ConnectionEndpoint) -> void:
	_ensure_loaded()
	if endpoint == null:
		return
	var record: Dictionary = _records.get(endpoint.normalized_display, {})
	if record.is_empty():
		return
	record["last_seen_unix"] = int(Time.get_unix_time_from_system())
	_save()


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(STORE_PATH):
		return
	var file := FileAccess.open(STORE_PATH, FileAccess.READ)
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
		var endpoint := str(record.get("normalized_endpoint", ""))
		var fingerprint := str(record.get("fingerprint", ""))
		if not endpoint.is_empty() and NetworkIdentityCrypto.valid_fingerprint(fingerprint):
			_records[endpoint] = record.duplicate(true)


func _save() -> bool:
	if _write_blocked:
		return false
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"format_version": FORMAT_VERSION,
		"records": _records.values(),
	}, "\t"))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok:
		return false
	if FileAccess.file_exists(STORE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(STORE_PATH))
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(TEMP_PATH),
		ProjectSettings.globalize_path(STORE_PATH),
	) == OK
