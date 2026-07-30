class_name HostBanStore
extends Node

signal bans_changed

const FORMAT_VERSION := 1
const MAX_BANS := 500

var _namespaces: Dictionary = {}
var _loaded := false
var _write_blocked := false
var _store_path := ""
var _expected_hash := ""
var _data_root: PlayerDataRoot


func configure_storage(path: String, data_root: PlayerDataRoot) -> void:
	_store_path = path
	_data_root = data_root


func is_banned(host_fingerprint: String, target_fingerprint: String) -> bool:
	_ensure_loaded()
	return Dictionary(_namespaces.get(host_fingerprint, {})).has(target_fingerprint)


func ban(
	host_fingerprint: String,
	target_fingerprint: String,
	display_name: String,
) -> bool:
	if (
		not NetworkIdentityCrypto.valid_fingerprint(host_fingerprint)
		or not NetworkIdentityCrypto.valid_fingerprint(target_fingerprint)
		or not NetworkProfilePreferences.is_valid_display_name(display_name)
	):
		return false
	_ensure_loaded()
	if _write_blocked:
		return false
	var previous_namespace: Dictionary = Dictionary(
		_namespaces.get(host_fingerprint, {})
	).duplicate(true)
	var records: Dictionary = _namespaces.get(host_fingerprint, {})
	records[target_fingerprint] = {
		"host_fingerprint": host_fingerprint,
		"target_fingerprint": target_fingerprint,
		"last_known_display_name": display_name,
		"banned_unix": int(Time.get_unix_time_from_system()),
		"reason": "host_ban",
	}
	while records.size() > MAX_BANS:
		records.erase(records.keys().front())
	_namespaces[host_fingerprint] = records
	if not _save():
		_namespaces[host_fingerprint] = previous_namespace
		return false
	bans_changed.emit()
	return true


func unban(host_fingerprint: String, target_fingerprint: String) -> bool:
	_ensure_loaded()
	if _write_blocked:
		return false
	var previous_namespace: Dictionary = Dictionary(
		_namespaces.get(host_fingerprint, {})
	).duplicate(true)
	var records: Dictionary = _namespaces.get(host_fingerprint, {})
	records.erase(target_fingerprint)
	_namespaces[host_fingerprint] = records
	if not _save():
		_namespaces[host_fingerprint] = previous_namespace
		return false
	bans_changed.emit()
	return true


func get_bans(host_fingerprint: String) -> Array[Dictionary]:
	_ensure_loaded()
	var result: Array[Dictionary] = []
	for value: Dictionary in Dictionary(_namespaces.get(host_fingerprint, {})).values():
		result.append(value.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["last_known_display_name"]).naturalnocasecmp_to(
			str(b["last_known_display_name"])
		) < 0
	)
	return result


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
		var host := str(record.get("host_fingerprint", ""))
		var target := str(record.get("target_fingerprint", ""))
		if not NetworkIdentityCrypto.valid_fingerprint(host) or not NetworkIdentityCrypto.valid_fingerprint(target):
			continue
		var records: Dictionary = _namespaces.get(host, {})
		records[target] = record.duplicate(true)
		_namespaces[host] = records
	_expected_hash = PortableFileGuard.hash_file(_store_path)


func _save() -> bool:
	var values: Array = []
	for records: Dictionary in _namespaces.values():
		values.append_array(records.values())
	var bytes := JSON.stringify({
		"format_version": FORMAT_VERSION,
		"records": values,
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
