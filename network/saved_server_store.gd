class_name SavedServerStore
extends Node

const FORMAT_VERSION: int = 1
const STORE_PATH: String = "user://saved_servers.json"
const TEMP_PATH: String = "user://saved_servers.json.tmp"
const BACKUP_PATH: String = "user://saved_servers.json.backup"
const MAX_ENTRIES: int = 100

var _entries: Array[Dictionary] = []
var _loaded: bool = false


func list_entries() -> Array[Dictionary]:
	_ensure_loaded()
	return _entries.duplicate(true)


func find_by_normalized_endpoint(value: String) -> Dictionary:
	_ensure_loaded()
	for entry: Dictionary in _entries:
		if entry.get("normalized_endpoint", "") == value:
			return entry.duplicate(true)
	return {}


func save_entry(
	display_name: String,
	endpoint: ConnectionEndpoint,
) -> bool:
	_ensure_loaded()
	if (
		endpoint == null
		or not endpoint.is_valid()
		or display_name.strip_edges().is_empty()
		or display_name.length() > 80
	):
		return false
	var now: int = int(Time.get_unix_time_from_system())
	for entry: Dictionary in _entries:
		if entry.get("normalized_endpoint", "") == endpoint.normalized_display:
			entry["display_name"] = display_name.strip_edges()
			entry["host"] = endpoint.host
			entry["port"] = endpoint.port
			entry["updated_at_unix"] = now
			return _save_atomic()
	if _entries.size() >= MAX_ENTRIES:
		return false
	_entries.append({
		"entry_id": Crypto.new().generate_random_bytes(16).hex_encode(),
		"display_name": display_name.strip_edges(),
		"route_kind": "DIRECT",
		"host": endpoint.host,
		"port": endpoint.port,
		"normalized_endpoint": endpoint.normalized_display,
		"favorite": false,
		"created_at_unix": now,
		"updated_at_unix": now,
		"last_success_at_unix": 0,
		"last_observed_max_players": 0,
	})
	return _save_atomic()


func remove_entry(entry_id: String) -> bool:
	_ensure_loaded()
	for index: int in range(_entries.size()):
		if _entries[index].get("entry_id", "") == entry_id:
			_entries.remove_at(index)
			return _save_atomic()
	return false


func record_successful_connection(
	endpoint: ConnectionEndpoint,
	observed_max_players: int,
) -> bool:
	_ensure_loaded()
	if endpoint == null or not endpoint.is_valid():
		return false
	for entry: Dictionary in _entries:
		if entry.get("normalized_endpoint", "") == endpoint.normalized_display:
			entry["last_success_at_unix"] = int(Time.get_unix_time_from_system())
			entry["last_observed_max_players"] = maxi(observed_max_players, 0)
			entry["updated_at_unix"] = int(Time.get_unix_time_from_system())
			return _save_atomic()
	# Successful manual connections are deliberately not auto-saved.
	return true


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_recover_interrupted_write()
	if not FileAccess.file_exists(STORE_PATH):
		return
	var file := FileAccess.open(STORE_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()
	if error != OK or typeof(json.data) != TYPE_DICTIONARY:
		return
	var data: Dictionary = json.data
	if data.get("format_version") != FORMAT_VERSION:
		return
	var raw_entries: Variant = data.get("entries")
	if typeof(raw_entries) != TYPE_ARRAY:
		return
	var seen: Dictionary[String, bool] = {}
	for value: Variant in raw_entries:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = value
		var stored_host: String = str(entry.get("host", ""))
		var stored_port: int = int(entry.get("port", 0))
		var endpoint_text: String = (
			"[%s]:%d" % [stored_host, stored_port]
			if stored_host.contains(":")
			else "%s:%d" % [stored_host, stored_port]
		)
		var endpoint: ConnectionEndpoint = EndpointParser.parse(endpoint_text)
		if (
			not endpoint.is_valid()
			or seen.has(endpoint.normalized_display)
			or typeof(entry.get("entry_id")) != TYPE_STRING
			or typeof(entry.get("display_name")) != TYPE_STRING
		):
			continue
		entry["normalized_endpoint"] = endpoint.normalized_display
		seen[endpoint.normalized_display] = true
		_entries.append(entry.duplicate(true))
		if _entries.size() >= MAX_ENTRIES:
			break


func _save_atomic() -> bool:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"format_version": FORMAT_VERSION,
		"entries": _entries,
	}, "\t"))
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		_remove_if_present(TEMP_PATH)
		return false
	_remove_if_present(BACKUP_PATH)
	var had_primary: bool = FileAccess.file_exists(STORE_PATH)
	if had_primary and not _rename(STORE_PATH, BACKUP_PATH):
		_remove_if_present(TEMP_PATH)
		return false
	if not _rename(TEMP_PATH, STORE_PATH):
		if had_primary:
			_rename(BACKUP_PATH, STORE_PATH)
		return false
	_remove_if_present(BACKUP_PATH)
	return true


func _recover_interrupted_write() -> void:
	if FileAccess.file_exists(STORE_PATH):
		_remove_if_present(TEMP_PATH)
		_remove_if_present(BACKUP_PATH)
		return
	if FileAccess.file_exists(BACKUP_PATH):
		_rename(BACKUP_PATH, STORE_PATH)
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
