class_name DiscoveryClient
extends Node

signal rooms_updated(rooms: Array[Dictionary])
signal browse_status_changed(message: String, is_error: bool)
signal host_settings_changed(room_name: String, discoverable: bool)
signal host_status_changed(message: String, is_error: bool)
signal public_join_prepared(endpoint: String)
signal public_join_status_changed(message: String, is_error: bool)

const BASE_URL_SETTING: String = "network/discovery/base_url"
const BASE_URL_ENVIRONMENT: String = "NETFISHING_DISCOVERY_URL"
const SETTINGS_PATH: String = "user://network_discovery.cfg"
const DEFAULT_ROOM_NAME: String = "NETfishing Room"
const MAX_ROOM_NAME_LENGTH: int = 48
const HEARTBEAT_INTERVAL_SECONDS: float = 15.0
const REQUEST_TIMEOUT_SECONDS: float = 8.0
const TRAVERSAL_POLL_INTERVAL_SECONDS: float = 1.0
const JOIN_PROBE_INTERVAL_SECONDS: float = 0.35
const TRAVERSAL_PACKET_PREFIX: String = "NETFISHING_TRAVERSAL_V1 "
const UPNP_MAPPING_DURATION_SECONDS: int = 3600

enum HostRequestKind {
	NONE,
	CREATE,
	UPDATE,
	DELETE,
}

var _session: NetworkSession
var _base_url: String = ""
var _room_name: String = DEFAULT_ROOM_NAME
var _discoverable: bool = false
var _host_status_message: String = ""
var _host_status_is_error: bool = false
var _lease_room_id: String = ""
var _lease_token: String = ""
var _host_request_kind: HostRequestKind = HostRequestKind.NONE
var _host_request_in_flight: bool = false
var _host_sync_queued: bool = false
var _browse_request_in_flight: bool = false
var _host_request: HTTPRequest
var _browse_request: HTTPRequest
var _heartbeat: Timer
var _traversal_request: HTTPRequest
var _join_request: HTTPRequest
var _traversal_timer: Timer
var _join_probe_timer: Timer
var _host_verified: bool = false
var _traversal_host: String = ""
var _traversal_port: int = 0
var _host_verification_token: String = ""
var _join_request_in_flight: bool = false
var _pending_join_endpoint: String = ""
var _pending_join_token: String = ""
var _pending_join_room_id: String = ""
var _upnp_thread: Thread
var _upnp_mapping_in_progress: bool = false
var _upnp: UPNP
var _upnp_mapped_port: int = 0


func _ready() -> void:
	_host_request = HTTPRequest.new()
	_host_request.name = "HostLeaseRequest"
	_host_request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(_host_request)
	_host_request.request_completed.connect(_on_host_request_completed)

	_browse_request = HTTPRequest.new()
	_browse_request.name = "RoomBrowseRequest"
	_browse_request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(_browse_request)
	_browse_request.request_completed.connect(_on_browse_request_completed)

	_traversal_request = HTTPRequest.new()
	_traversal_request.name = "HostTraversalRequest"
	_traversal_request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(_traversal_request)
	_traversal_request.request_completed.connect(
		_on_traversal_request_completed
	)

	_join_request = HTTPRequest.new()
	_join_request.name = "PublicJoinPreparationRequest"
	_join_request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(_join_request)
	_join_request.request_completed.connect(_on_join_request_completed)

	_heartbeat = Timer.new()
	_heartbeat.name = "HostLeaseHeartbeat"
	_heartbeat.wait_time = HEARTBEAT_INTERVAL_SECONDS
	_heartbeat.one_shot = false
	add_child(_heartbeat)
	_heartbeat.timeout.connect(_synchronize_host_lease)
	_traversal_timer = Timer.new()
	_traversal_timer.name = "HostTraversalPoll"
	_traversal_timer.wait_time = TRAVERSAL_POLL_INTERVAL_SECONDS
	_traversal_timer.one_shot = false
	add_child(_traversal_timer)
	_traversal_timer.timeout.connect(_on_traversal_timer_timeout)

	_join_probe_timer = Timer.new()
	_join_probe_timer.name = "PublicJoinTraversalProbe"
	_join_probe_timer.wait_time = JOIN_PROBE_INTERVAL_SECONDS
	_join_probe_timer.one_shot = false
	add_child(_join_probe_timer)
	_join_probe_timer.timeout.connect(_send_pending_join_probe)
	_load_settings()
	_base_url = _configured_base_url()


func setup(session: NetworkSession) -> void:
	_session = session
	_session.set_session_display_name(_room_name)
	if not _session.state_changed.is_connected(_on_session_state_changed):
		_session.state_changed.connect(_on_session_state_changed)
	if not _session.peer_count_changed.is_connected(_on_peer_count_changed):
		_session.peer_count_changed.connect(_on_peer_count_changed)
	if not _session.host_openness_changed.is_connected(_on_host_openness_changed):
		_session.host_openness_changed.connect(_on_host_openness_changed)
	host_settings_changed.emit(_room_name, _discoverable)
	if not is_configured():
		_set_host_status("Room discovery is not configured in this build.", true)
	elif _session.is_open_host():
		_set_host_status("Room is open but unlisted.", false)
	else:
		_set_host_status("Open the game before listing it publicly.", false)


func is_configured() -> bool:
	return not _base_url.is_empty()


func get_base_url() -> String:
	return _base_url


func set_base_url_override(value: String) -> bool:
	var normalized: String = value.strip_edges()
	while normalized.ends_with("/"):
		normalized = normalized.left(normalized.length() - 1)
	if not normalized.is_empty() and not (
		normalized.begins_with("https://")
		or normalized.begins_with("http://")
	):
		return false
	_base_url = normalized
	return true


func get_room_name() -> String:
	return _room_name


func is_discoverable() -> bool:
	return _discoverable


func get_host_status_message() -> String:
	return _host_status_message


func host_status_is_error() -> bool:
	return _host_status_is_error


func set_room_name(value: String) -> bool:
	var cleaned: String = _sanitize_room_name(value)
	if cleaned.is_empty():
		_set_host_status("Room name cannot be empty.", true)
		return false
	if cleaned == _room_name:
		return true
	_room_name = cleaned
	_save_settings()
	if _session != null:
		_session.set_session_display_name(_room_name)
	host_settings_changed.emit(_room_name, _discoverable)
	if _discoverable:
		_synchronize_host_lease()
	return true


func set_discoverable(enabled: bool) -> bool:
	if enabled and (
		_session == null
		or not _session.is_open_host()
		or not is_configured()
	):
		_set_host_status(
			"Open the game before enabling discovery."
			if is_configured()
			else "Room discovery is not configured in this build.",
			true,
		)
		return false
	if _discoverable == enabled:
		return true
	_discoverable = enabled
	host_settings_changed.emit(_room_name, _discoverable)
	if enabled:
		_heartbeat.start()
		_set_host_status("Opening public room…", false)
		if _session.is_dedicated_host():
			_synchronize_host_lease()
		else:
			_begin_upnp_mapping(_session.get_host_port())
	else:
		_heartbeat.stop()
		_traversal_timer.stop()
		_remove_host_lease()
		_begin_upnp_cleanup()
		_set_host_status("Room is open but unlisted.", false)
	return true


func is_public_join_preparing() -> bool:
	return _join_request_in_flight


func prepare_public_join(room: Dictionary) -> bool:
	if _join_request_in_flight or _session == null or not is_configured():
		return false
	var endpoint: String = room_endpoint(room)
	var room_id: String = str(room.get("room_id", "")).strip_edges()
	if endpoint.is_empty() or room_id.is_empty():
		return false
	_pending_join_endpoint = endpoint
	_pending_join_room_id = room_id
	_pending_join_token = ""
	var url: String = "%s/v1/rooms/%s/join-attempts" % [
		_base_url,
		room_id.uri_encode(),
	]
	var error: Error = _join_request.request(
		url,
		PackedStringArray(),
		HTTPClient.METHOD_POST,
		"",
	)
	if error != OK:
		_clear_pending_join()
		return false
	_join_request_in_flight = true
	public_join_status_changed.emit("Opening a route to the room…", false)
	return true


func request_rooms() -> bool:
	if not is_configured():
		rooms_updated.emit([])
		browse_status_changed.emit(
			"Public room discovery is not configured in this build.", true
		)
		return false
	if _browse_request_in_flight:
		return true
	var game_version: String = str(
		ProjectSettings.get_setting("application/config/version", "unknown")
	)
	var url: String = "%s/v1/rooms?game_version=%s&protocol_version=%d" % [
		_base_url,
		game_version.uri_encode(),
		NetworkProtocol.PROTOCOL_VERSION,
	]
	var error: Error = _browse_request.request(url)
	if error != OK:
		rooms_updated.emit([])
		browse_status_changed.emit("Could not request public rooms.", true)
		return false
	_browse_request_in_flight = true
	browse_status_changed.emit("Looking for public rooms…", false)
	return true


func room_endpoint(room: Dictionary) -> String:
	var address: String = str(room.get("address", "")).strip_edges()
	var port: int = int(room.get("port", 0))
	if address.is_empty() or port < 1 or port > 65535:
		return ""
	if ":" in address and not address.begins_with("["):
		address = "[%s]" % address
	return "%s:%d" % [address, port]


func _configured_base_url() -> String:
	var value: String = OS.get_environment(BASE_URL_ENVIRONMENT).strip_edges()
	if value.is_empty():
		value = str(ProjectSettings.get_setting(BASE_URL_SETTING, "")).strip_edges()
	while value.ends_with("/"):
		value = value.left(value.length() - 1)
	if not value.is_empty() and not (
		value.begins_with("https://") or value.begins_with("http://")
	):
		push_warning("Ignored invalid NETfishing discovery URL.")
		return ""
	return value


func _synchronize_host_lease() -> void:
	if not _should_advertise():
		if not _lease_room_id.is_empty():
			_remove_host_lease()
		return
	if _host_request_in_flight:
		_host_sync_queued = true
		return
	var method: HTTPClient.Method = HTTPClient.METHOD_POST
	var url: String = "%s/v1/rooms" % _base_url
	var headers := PackedStringArray(["Content-Type: application/json"])
	_host_request_kind = HostRequestKind.CREATE
	if not _lease_room_id.is_empty():
		method = HTTPClient.METHOD_PUT
		url = "%s/v1/rooms/%s" % [_base_url, _lease_room_id.uri_encode()]
		headers.append("Authorization: Bearer %s" % _lease_token)
		_host_request_kind = HostRequestKind.UPDATE
	_start_host_request(url, headers, method, JSON.stringify(_host_payload()))


func _remove_host_lease() -> void:
	if _lease_room_id.is_empty():
		return
	if _host_request_in_flight:
		_host_sync_queued = true
		return
	var url: String = "%s/v1/rooms/%s" % [
		_base_url, _lease_room_id.uri_encode()
	]
	var headers := PackedStringArray([
		"Authorization: Bearer %s" % _lease_token,
	])
	_host_request_kind = HostRequestKind.DELETE
	_start_host_request(url, headers, HTTPClient.METHOD_DELETE, "")


func _start_host_request(
	url: String,
	headers: PackedStringArray,
	method: HTTPClient.Method,
	body: String,
) -> void:
	var error: Error = _host_request.request(url, headers, method, body)
	if error != OK:
		_host_request_kind = HostRequestKind.NONE
		_set_host_status("Could not contact room discovery.", true)
		return
	_host_request_in_flight = true


func _host_payload() -> Dictionary:
	return {
		"room_name": _room_name,
		"port": _session.get_host_port(),
		"current_players": _session.get_player_count(),
		"max_players": _session.get_session_max_players(),
		"game_version": str(
			ProjectSettings.get_setting("application/config/version", "unknown")
		),
		"protocol_version": NetworkProtocol.PROTOCOL_VERSION,
	}


func _should_advertise() -> bool:
	return (
		_discoverable
		and is_configured()
		and _session != null
		and _session.is_open_host()
		and not _upnp_mapping_in_progress
	)


func _on_host_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	var completed_kind: HostRequestKind = _host_request_kind
	_host_request_kind = HostRequestKind.NONE
	_host_request_in_flight = false
	var response: Dictionary = _parse_response_dictionary(body)
	var transport_ok: bool = result == HTTPRequest.RESULT_SUCCESS
	match completed_kind:
		HostRequestKind.CREATE:
			if transport_ok and response_code == HTTPClient.RESPONSE_CREATED:
				var room: Dictionary = response.get("room", {})
				_lease_room_id = str(room.get("room_id", ""))
				_lease_token = str(response.get("lease_token", ""))
				if _lease_room_id.is_empty() or _lease_token.is_empty():
					_clear_lease()
					_set_host_status("Discovery returned an invalid lease.", true)
				else:
					_apply_traversal_response(response)
					_host_verified = bool(room.get("verified", false))
					_traversal_timer.start()
					_send_host_verification_probe()
					_set_host_status("Checking the public route…", false)
			else:
				_set_host_status(_request_failure(response), true)
		HostRequestKind.UPDATE:
			if transport_ok and response_code == HTTPClient.RESPONSE_OK:
				var room: Dictionary = response.get("room", {})
				_host_verified = bool(room.get("verified", false))
				_set_host_status(
					"Room is listed publicly."
					if _host_verified
					else "Checking the public route…",
					false,
				)
			elif response_code in [
				HTTPClient.RESPONSE_UNAUTHORIZED,
				HTTPClient.RESPONSE_NOT_FOUND,
			]:
				_clear_lease()
				_host_sync_queued = true
			else:
				_set_host_status(_request_failure(response), true)
		HostRequestKind.DELETE:
			_clear_lease()
			if response_code not in [
				HTTPClient.RESPONSE_NO_CONTENT,
				HTTPClient.RESPONSE_NOT_FOUND,
			] and transport_ok:
				_set_host_status(_request_failure(response), true)
		_:
			pass
	if not _should_advertise() and not _lease_room_id.is_empty():
		_host_sync_queued = true
	if _host_sync_queued:
		_host_sync_queued = false
		call_deferred("_synchronize_host_lease")


func _on_join_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	_join_request_in_flight = false
	var response: Dictionary = _parse_response_dictionary(body)
	if (
		result != HTTPRequest.RESULT_SUCCESS
		or response_code != HTTPClient.RESPONSE_CREATED
	):
		public_join_status_changed.emit(_request_failure(response), true)
		_clear_pending_join()
		return
	_pending_join_token = str(response.get("join_token", ""))
	_apply_traversal_response(response)
	if (
		_pending_join_token.is_empty()
		or _traversal_host.is_empty()
		or _traversal_port < 1
	):
		public_join_status_changed.emit(
			"Discovery returned an invalid traversal route.", true
		)
		_clear_pending_join()
		return
	public_join_status_changed.emit("Connecting…", false)
	public_join_prepared.emit(_pending_join_endpoint)


func _on_traversal_timer_timeout() -> void:
	if not _should_advertise() or _lease_room_id.is_empty():
		_traversal_timer.stop()
		return
	if not _host_verified:
		_send_host_verification_probe()
		_synchronize_host_lease()
		return
	if _traversal_request.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var url: String = "%s/v1/rooms/%s/join-attempts" % [
		_base_url,
		_lease_room_id.uri_encode(),
	]
	var headers := PackedStringArray([
		"Authorization: Bearer %s" % _lease_token,
	])
	var error: Error = _traversal_request.request(url, headers)
	if error != OK:
		_set_host_status("Could not check incoming public connections.", true)


func _on_traversal_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != HTTPClient.RESPONSE_OK:
		return
	var response: Dictionary = _parse_response_dictionary(body)
	var endpoints: Variant = response.get("endpoints", [])
	if typeof(endpoints) != TYPE_ARRAY:
		return
	for value: Variant in endpoints:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var endpoint: Dictionary = value
		var address: String = str(endpoint.get("address", ""))
		var port: int = int(endpoint.get("port", 0))
		if address.is_empty() or port < 1 or port > 65535:
			continue
		var punch: PackedByteArray = "NETFISHING_PUNCH_V1".to_utf8_buffer()
		for _attempt: int in 3:
			_session.send_traversal_packet(address, port, punch)


func _apply_traversal_response(response: Dictionary) -> void:
	var traversal: Variant = response.get("traversal", {})
	if typeof(traversal) != TYPE_DICTIONARY:
		return
	var details: Dictionary = traversal
	_traversal_host = str(details.get("host", "")).strip_edges()
	_traversal_port = int(details.get("port", 0))
	_host_verification_token = str(
		details.get("verification_token", "")
	)


func _send_host_verification_probe() -> void:
	if (
		_session == null
		or _lease_room_id.is_empty()
		or _host_verification_token.is_empty()
	):
		return
	_send_traversal_probe({
		"kind": "host",
		"room_id": _lease_room_id,
		"token": _host_verification_token,
	})


func _send_pending_join_probe() -> void:
	if (
		_session == null
		or _pending_join_token.is_empty()
		or _session.state not in [
			NetworkSession.State.CONNECTING,
			NetworkSession.State.AUTHENTICATING,
		]
	):
		_join_probe_timer.stop()
		return
	_send_traversal_probe({
		"kind": "join",
		"room_id": _pending_join_room_id,
		"token": _pending_join_token,
	})


func _send_traversal_probe(payload: Dictionary) -> void:
	if _traversal_host.is_empty() or _traversal_port < 1:
		return
	var packet: PackedByteArray = (
		TRAVERSAL_PACKET_PREFIX + JSON.stringify(payload)
	).to_utf8_buffer()
	_session.send_traversal_packet(_traversal_host, _traversal_port, packet)


func _begin_upnp_mapping(port: int) -> void:
	if _upnp_mapping_in_progress or port < 1:
		_synchronize_host_lease()
		return
	_upnp_mapping_in_progress = true
	_upnp_thread = Thread.new()
	var error: Error = _upnp_thread.start(
		_configure_upnp_mapping.bind(port)
	)
	if error != OK:
		_upnp_thread = null
		_upnp_mapping_in_progress = false
		_synchronize_host_lease()


func _configure_upnp_mapping(port: int) -> Dictionary:
	var upnp := UPNP.new()
	var discovery_result: int = upnp.discover()
	if discovery_result != UPNP.UPNP_RESULT_SUCCESS:
		return {"success": false, "upnp": upnp, "port": port}
	var mapping_result: int = upnp.add_port_mapping(
		port,
		port,
		"NETfishing",
		"UDP",
		UPNP_MAPPING_DURATION_SECONDS,
	)
	if mapping_result == UPNP.UPNP_RESULT_ONLY_PERMANENT_LEASE_SUPPORTED:
		mapping_result = upnp.add_port_mapping(
			port, port, "NETfishing", "UDP", 0
		)
	return {
		"success": mapping_result == UPNP.UPNP_RESULT_SUCCESS,
		"upnp": upnp,
		"port": port,
	}


func _process(_delta: float) -> void:
	if _upnp_thread == null or _upnp_thread.is_alive():
		return
	var result: Variant = _upnp_thread.wait_to_finish()
	_upnp_thread = null
	_upnp_mapping_in_progress = false
	if typeof(result) == TYPE_DICTIONARY:
		var details: Dictionary = result
		if bool(details.get("success", false)):
			_upnp = details.get("upnp") as UPNP
			_upnp_mapped_port = int(details.get("port", 0))
	if not _discoverable:
		_begin_upnp_cleanup()
		return
	_synchronize_host_lease()


func _begin_upnp_cleanup() -> void:
	if _upnp == null or _upnp_mapped_port < 1:
		return
	_upnp.delete_port_mapping(_upnp_mapped_port, "UDP")
	_upnp = null
	_upnp_mapped_port = 0


func _on_browse_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	_browse_request_in_flight = false
	var response: Dictionary = _parse_response_dictionary(body)
	if result != HTTPRequest.RESULT_SUCCESS or response_code != HTTPClient.RESPONSE_OK:
		rooms_updated.emit([])
		browse_status_changed.emit(_request_failure(response), true)
		return
	var raw_rooms: Variant = response.get("rooms", [])
	if typeof(raw_rooms) != TYPE_ARRAY:
		rooms_updated.emit([])
		browse_status_changed.emit("Discovery returned an invalid room list.", true)
		return
	var rooms: Array[Dictionary] = []
	for value: Variant in raw_rooms:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = value
		if _valid_public_room(room):
			rooms.append(room.duplicate(true))
	rooms_updated.emit(rooms)
	browse_status_changed.emit(
		"No public rooms are available."
		if rooms.is_empty()
		else "%d public room%s found." % [rooms.size(), "" if rooms.size() == 1 else "s"],
		false,
	)


func _valid_public_room(room: Dictionary) -> bool:
	var expected_version: String = str(
		ProjectSettings.get_setting("application/config/version", "unknown")
	)
	return (
		typeof(room.get("room_id")) == TYPE_STRING
		and typeof(room.get("room_name")) == TYPE_STRING
		and typeof(room.get("address")) == TYPE_STRING
		and typeof(room.get("game_version")) == TYPE_STRING
		and str(room.get("game_version")) == expected_version
		and _valid_json_integer(room.get("port"), 1, 65535)
		and _valid_json_integer(room.get("current_players"), 0, 128)
		and _valid_json_integer(room.get("max_players"), 1, 128)
		and int(room["current_players"]) <= int(room["max_players"])
		and _valid_json_integer(
			room.get("protocol_version"),
			NetworkProtocol.PROTOCOL_VERSION,
			NetworkProtocol.PROTOCOL_VERSION,
		)
	)


func _valid_json_integer(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= minimum and int(value) <= maximum
	if typeof(value) != TYPE_FLOAT:
		return false
	var number: float = float(value)
	return (
		is_finite(number)
		and number == floor(number)
		and number >= float(minimum)
		and number <= float(maximum)
	)


func _parse_response_dictionary(body: PackedByteArray) -> Dictionary:
	if body.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _request_failure(response: Dictionary) -> String:
	var error: Variant = response.get("error", {})
	if typeof(error) == TYPE_DICTIONARY:
		var message: String = str((error as Dictionary).get("message", "")).strip_edges()
		if not message.is_empty():
			return message
	return "Room discovery is temporarily unavailable."


func _on_session_state_changed(state: NetworkSession.State) -> void:
	if state == NetworkSession.State.CONNECTING and not _pending_join_token.is_empty():
		_join_probe_timer.start()
		call_deferred("_send_pending_join_probe")
	elif state in [
		NetworkSession.State.JOINED_CLIENT,
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
		NetworkSession.State.INACTIVE,
	]:
		_join_probe_timer.stop()
		_clear_pending_join()
	if state == NetworkSession.State.OPEN_HOST:
		if _discoverable:
			_heartbeat.start()
			_synchronize_host_lease()
		else:
			_set_host_status("Room is open but unlisted.", false)
		return
	if state in [
		NetworkSession.State.PRIVATE_HOST,
		NetworkSession.State.INACTIVE,
		NetworkSession.State.DISCONNECTING,
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		if _discoverable:
			_discoverable = false
			host_settings_changed.emit(_room_name, false)
			_heartbeat.stop()
			_remove_host_lease()
		if state == NetworkSession.State.PRIVATE_HOST:
			_set_host_status("Open the game before listing it publicly.", false)


func _on_host_openness_changed(is_open: bool) -> void:
	if not is_open and _discoverable:
		set_discoverable(false)


func _on_peer_count_changed(_player_count: int, _max_players: int) -> void:
	if _discoverable:
		_synchronize_host_lease()


func _clear_lease() -> void:
	_lease_room_id = ""
	_lease_token = ""
	_host_verified = false
	_host_verification_token = ""
	_traversal_timer.stop()


func _clear_pending_join() -> void:
	_pending_join_endpoint = ""
	_pending_join_token = ""
	_pending_join_room_id = ""
	_join_probe_timer.stop()


func _exit_tree() -> void:
	if _upnp_thread != null:
		var result: Variant = _upnp_thread.wait_to_finish()
		_upnp_thread = null
		if typeof(result) == TYPE_DICTIONARY:
			var details: Dictionary = result
			if bool(details.get("success", false)):
				_upnp = details.get("upnp") as UPNP
				_upnp_mapped_port = int(details.get("port", 0))
	_begin_upnp_cleanup()


func _set_host_status(message: String, is_error: bool) -> void:
	_host_status_message = message
	_host_status_is_error = is_error
	host_status_changed.emit(message, is_error)


func _sanitize_room_name(value: String) -> String:
	var cleaned: String = value.strip_edges().replace("\n", " ").replace("\r", " ")
	cleaned = cleaned.replace("\t", " ")
	while "  " in cleaned:
		cleaned = cleaned.replace("  ", " ")
	return cleaned.left(MAX_ROOM_NAME_LENGTH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var saved_name: String = _sanitize_room_name(
			str(config.get_value("host", "room_name", DEFAULT_ROOM_NAME))
		)
		if not saved_name.is_empty():
			_room_name = saved_name


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("host", "room_name", _room_name)
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save the local NETfishing room name.")
