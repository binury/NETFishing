class_name SavedServerStore
extends Node

const FORMAT_VERSION: int = 1
const MAX_SAVED_ENTRIES: int = 100
const MAX_RECENT_ENTRIES: int = 20
const MAX_DISPLAY_NAME_LENGTH: int = 80

signal data_changed
signal recovery_warning_changed(message: String)

var _saved_entries: Array[Dictionary] = []
var _recent_entries: Array[Dictionary] = []
var _loaded: bool = false
var _recovery_warning: String = ""
var _write_blocked: bool = false
var _store_path := ""
var _expected_hash := ""
var _data_root: PlayerDataRoot


func configure_storage(path: String, data_root: PlayerDataRoot) -> void:
	_store_path = path
	_data_root = data_root


func _temp_path() -> String:
	return _store_path + ".tmp"


func _backup_path() -> String:
	return _store_path + ".backup"


func get_saved_entries() -> Array[SavedServerEntry]:
	_ensure_loaded()
	var result: Array[SavedServerEntry] = []
	for data: Dictionary in _saved_entries:
		result.append(SavedServerEntry.from_dictionary(
			data, SavedServerEntry.Kind.SAVED
		))
	result.sort_custom(_sort_saved_entries)
	return result


func get_recent_entries() -> Array[SavedServerEntry]:
	_ensure_loaded()
	var result: Array[SavedServerEntry] = []
	for data: Dictionary in _recent_entries:
		result.append(SavedServerEntry.from_dictionary(
			data, SavedServerEntry.Kind.RECENT
		))
	result.sort_custom(func(a: SavedServerEntry, b: SavedServerEntry) -> bool:
		return a.last_success_at_unix > b.last_success_at_unix
	)
	return result


func list_entries() -> Array[Dictionary]:
	_ensure_loaded()
	return _saved_entries.duplicate(true)


func get_recovery_warning() -> String:
	_ensure_loaded()
	return _recovery_warning


func find_saved_by_endpoint(
	endpoint: ConnectionEndpoint,
) -> SavedServerEntry:
	_ensure_loaded()
	if endpoint == null or not endpoint.is_valid():
		return null
	for data: Dictionary in _saved_entries:
		if data.get("normalized_endpoint", "") == endpoint.normalized_display:
			return SavedServerEntry.from_dictionary(
				data, SavedServerEntry.Kind.SAVED
			)
	return null


func find_by_normalized_endpoint(value: String) -> Dictionary:
	var endpoint := EndpointParser.parse(value)
	var entry: SavedServerEntry = find_saved_by_endpoint(endpoint)
	return entry.to_dictionary() if entry != null else {}


func save_or_update_entry(
	display_name: String,
	endpoint: ConnectionEndpoint,
	entry_id: String = "",
) -> SavedServerEntry:
	_ensure_loaded()
	var clean_name: String = display_name.strip_edges()
	if (
		endpoint == null
		or not endpoint.is_valid()
		or clean_name.is_empty()
		or clean_name.length() > MAX_DISPLAY_NAME_LENGTH
	):
		return null
	var now: int = int(Time.get_unix_time_from_system())
	var target: Dictionary = {}
	for data: Dictionary in _saved_entries:
		if not entry_id.is_empty() and data.get("entry_id", "") == entry_id:
			target = data
			break
	for data: Dictionary in _saved_entries:
		if (
			data.get("normalized_endpoint", "") == endpoint.normalized_display
			and data != target
		):
			return null
	if target.is_empty():
		if _saved_entries.size() >= MAX_SAVED_ENTRIES:
			return null
		target = _make_entry(endpoint, SavedServerEntry.Kind.SAVED)
		_saved_entries.append(target)
	target["display_name"] = clean_name
	target["host"] = endpoint.host
	target["normalized_host"] = endpoint.host
	target["port"] = endpoint.port
	target["normalized_endpoint"] = endpoint.normalized_display
	target["updated_at_unix"] = now
	if not _save_atomic():
		return null
	data_changed.emit()
	return SavedServerEntry.from_dictionary(
		target, SavedServerEntry.Kind.SAVED
	)


func save_entry(display_name: String, endpoint: ConnectionEndpoint) -> bool:
	return save_or_update_entry(display_name, endpoint) != null


func remove_saved_entry(entry_id: String) -> bool:
	_ensure_loaded()
	for index: int in range(_saved_entries.size()):
		if _saved_entries[index].get("entry_id", "") == entry_id:
			_saved_entries.remove_at(index)
			if not _save_atomic():
				return false
			data_changed.emit()
			return true
	return false


func remove_entry(entry_id: String) -> bool:
	return remove_saved_entry(entry_id)


func set_favorite(entry_id: String, favorite: bool) -> bool:
	_ensure_loaded()
	for data: Dictionary in _saved_entries:
		if data.get("entry_id", "") == entry_id:
			data["favorite"] = favorite
			data["updated_at_unix"] = int(Time.get_unix_time_from_system())
			if not _save_atomic():
				return false
			data_changed.emit()
			return true
	return false


func record_successful_connection(
	endpoint: ConnectionEndpoint,
	observed_max_players: int,
	server_name: String = "",
	protocol_version: int = 0,
	player_count: int = 0,
) -> bool:
	_ensure_loaded()
	if endpoint == null or not endpoint.is_valid():
		return false
	var now: int = int(Time.get_unix_time_from_system())
	for data: Dictionary in _saved_entries:
		if data.get("normalized_endpoint", "") == endpoint.normalized_display:
			_apply_result_metadata(
				data, now, "SUCCESS", server_name, protocol_version,
				player_count, observed_max_players
			)
	var recent: Dictionary = {}
	for data: Dictionary in _recent_entries:
		if data.get("normalized_endpoint", "") == endpoint.normalized_display:
			recent = data
			break
	if recent.is_empty():
		recent = _make_entry(endpoint, SavedServerEntry.Kind.RECENT)
		_recent_entries.append(recent)
	recent["display_name"] = (
		server_name if not server_name.is_empty() else endpoint.normalized_display
	)
	_apply_result_metadata(
		recent, now, "SUCCESS", server_name, protocol_version,
		player_count, observed_max_players
	)
	_recent_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("last_success_at_unix", 0)) > int(
			b.get("last_success_at_unix", 0)
		)
	)
	if _recent_entries.size() > MAX_RECENT_ENTRIES:
		_recent_entries.resize(MAX_RECENT_ENTRIES)
	if not _save_atomic():
		return false
	data_changed.emit()
	return true


func record_connection_failure(
	endpoint: ConnectionEndpoint,
	result_code: String,
) -> bool:
	_ensure_loaded()
	if endpoint == null or not endpoint.is_valid():
		return false
	for data: Dictionary in _saved_entries:
		if data.get("normalized_endpoint", "") == endpoint.normalized_display:
			data["last_result_code"] = result_code.left(48)
			data["updated_at_unix"] = int(Time.get_unix_time_from_system())
			if not _save_atomic():
				return false
			data_changed.emit()
			break
	return true


func remove_recent_entry(entry_id: String) -> bool:
	_ensure_loaded()
	for index: int in range(_recent_entries.size()):
		if _recent_entries[index].get("entry_id", "") == entry_id:
			_recent_entries.remove_at(index)
			if not _save_atomic():
				return false
			data_changed.emit()
			return true
	return false


func clear_recent_entries() -> bool:
	_ensure_loaded()
	if _recent_entries.is_empty():
		return true
	_recent_entries.clear()
	if not _save_atomic():
		return false
	data_changed.emit()
	return true


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_recover_interrupted_write()
	if _store_path.is_empty() or not FileAccess.file_exists(_store_path):
		return
	var data: Dictionary = _read_store(_store_path)
	if data.is_empty() and FileAccess.file_exists(_backup_path()):
		data = _read_store(_backup_path())
		if not data.is_empty():
			_set_warning("Recovered saved servers from the local backup.")
	if data.is_empty():
		if FileAccess.file_exists(_store_path):
			_set_warning(
				"Saved servers could not be read. Direct connection is still available."
			)
		return
	if data.get("format_version") != FORMAT_VERSION:
		_write_blocked = true
		_set_warning(
			"Saved servers use a newer format. Direct connection is still available."
		)
		return
	_load_collection(data.get("saved_entries", data.get("entries", [])), true)
	_load_collection(data.get("recent_entries", []), false)
	_expected_hash = PortableFileGuard.hash_file(_store_path)


func _load_collection(raw: Variant, is_saved: bool) -> void:
	if typeof(raw) != TYPE_ARRAY:
		_set_warning("Some saved-server data was unavailable.")
		return
	var target: Array[Dictionary] = (
		_saved_entries if is_saved else _recent_entries
	)
	var seen: Dictionary[String, bool] = {}
	for value: Variant in raw:
		if typeof(value) != TYPE_DICTIONARY:
			_set_warning("Some malformed server entries were skipped.")
			continue
		var validated: Dictionary = _validate_entry(value, is_saved)
		if validated.is_empty():
			_set_warning("Some malformed server entries were skipped.")
			continue
		var identity: String = validated["normalized_endpoint"]
		if seen.has(identity):
			continue
		seen[identity] = true
		target.append(validated)
		if target.size() >= (
			MAX_SAVED_ENTRIES if is_saved else MAX_RECENT_ENTRIES
		):
			break


func _validate_entry(value: Dictionary, is_saved: bool) -> Dictionary:
	if (
		typeof(value.get("entry_id")) != TYPE_STRING
		or str(value.get("entry_id", "")).is_empty()
		or typeof(value.get("host")) != TYPE_STRING
	):
		return {}
	var stored_host: String = str(value.get("host", ""))
	var stored_port: int = int(value.get("port", 0))
	var endpoint_text: String = (
		"[%s]:%d" % [stored_host, stored_port]
		if stored_host.contains(":")
		else "%s:%d" % [stored_host, stored_port]
	)
	var endpoint := EndpointParser.parse(endpoint_text)
	if not endpoint.is_valid():
		return {}
	var display_name: String = str(
		value.get("display_name", "")
	).strip_edges()
	if is_saved and (
		display_name.is_empty()
		or display_name.length() > MAX_DISPLAY_NAME_LENGTH
	):
		return {}
	var result: Dictionary = _make_entry(
		endpoint,
		SavedServerEntry.Kind.SAVED if is_saved else SavedServerEntry.Kind.RECENT
	)
	for key: String in result:
		if value.has(key) and typeof(value[key]) == typeof(result[key]):
			result[key] = value[key]
	result["host"] = endpoint.host
	result["normalized_host"] = endpoint.host
	result["port"] = endpoint.port
	result["normalized_endpoint"] = endpoint.normalized_display
	return result


func _make_entry(
	endpoint: ConnectionEndpoint,
	kind: SavedServerEntry.Kind,
) -> Dictionary:
	var now: int = int(Time.get_unix_time_from_system())
	return {
		"entry_id": Crypto.new().generate_random_bytes(16).hex_encode(),
		"display_name": endpoint.host,
		"route_kind": "DIRECT",
		"host": endpoint.host,
		"normalized_host": endpoint.host,
		"port": endpoint.port,
		"normalized_endpoint": endpoint.normalized_display,
		"favorite": false,
		"created_at_unix": now,
		"updated_at_unix": now,
		"last_success_at_unix": 0,
		"last_result_code": "",
		"last_observed_server_name": "",
		"last_observed_protocol_version": 0,
		"last_observed_player_count": 0,
		"last_observed_max_players": 0,
		"entry_kind": int(kind),
	}


func _apply_result_metadata(
	data: Dictionary,
	now: int,
	result_code: String,
	server_name: String,
	protocol_version: int,
	player_count: int,
	max_players: int,
) -> void:
	data["last_success_at_unix"] = now
	data["updated_at_unix"] = now
	data["last_result_code"] = result_code
	data["last_observed_server_name"] = server_name.left(80)
	data["last_observed_protocol_version"] = maxi(protocol_version, 0)
	data["last_observed_player_count"] = maxi(player_count, 0)
	data["last_observed_max_players"] = maxi(max_players, 0)


func _sort_saved_entries(
	a: SavedServerEntry,
	b: SavedServerEntry,
) -> bool:
	if a.favorite != b.favorite:
		return a.favorite
	if a.last_success_at_unix != b.last_success_at_unix:
		return a.last_success_at_unix > b.last_success_at_unix
	var name_compare: int = a.display_name.naturalnocasecmp_to(b.display_name)
	if name_compare != 0:
		return name_compare < 0
	return a.entry_id < b.entry_id


func _save_atomic() -> bool:
	if _write_blocked:
		return false
	var bytes := JSON.stringify({
		"format_version": FORMAT_VERSION,
		"saved_entries": _saved_entries,
		"recent_entries": _recent_entries,
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


func _read_store(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()
	return json.data if error == OK and typeof(json.data) == TYPE_DICTIONARY else {}


func _recover_interrupted_write() -> void:
	if FileAccess.file_exists(_store_path):
		_remove_if_present(_temp_path())
		return
	if FileAccess.file_exists(_backup_path()):
		_rename(_backup_path(), _store_path)
		_set_warning("Recovered saved servers after an interrupted write.")
	_remove_if_present(_temp_path())


func _set_warning(message: String) -> void:
	if _recovery_warning.is_empty():
		_recovery_warning = message
	recovery_warning_changed.emit(_recovery_warning)


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
