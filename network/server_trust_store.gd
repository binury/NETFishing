class_name ServerTrustStore
extends Node

const FORMAT_VERSION: int = 1
enum Verification {
	FIRST_SEEN,
	MATCH,
	CHANGED,
}

var _records: Dictionary = {}
var _loaded: bool = false
var _write_blocked: bool = false
var _store_path := ""
var _expected_hash := ""
var _data_root: PlayerDataRoot


func configure_storage(path: String, data_root: PlayerDataRoot) -> void:
	_store_path = path
	_data_root = data_root


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
		var endpoint := str(record.get("normalized_endpoint", ""))
		var fingerprint := str(record.get("fingerprint", ""))
		if not endpoint.is_empty() and NetworkIdentityCrypto.valid_fingerprint(fingerprint):
			_records[endpoint] = record.duplicate(true)
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
