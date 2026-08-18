class_name NetworkWorldTimeService
extends Node

const SYNC_INTERVAL_SECONDS: float = 5.0
const MAX_SESSION_ID_LENGTH: int = 96

var _session: NetworkSession
var _world_time: WorldTimeService
var _sync_elapsed: float = 0.0
var _sequence: int = 0
var _last_received_sequence: int = -1
var _active_session_id: String = ""


func setup(session: NetworkSession, world_time: WorldTimeService) -> void:
	_session = session
	_world_time = world_time
	_session.state_changed.connect(_on_session_state_changed)
	_session.peer_authenticated.connect(_on_peer_authenticated)
	if not _world_time.authoritative_time_set.is_connected(
		_on_authoritative_time_set
	):
		_world_time.authoritative_time_set.connect(
			_on_authoritative_time_set
		)
	set_process(true)


func _process(delta: float) -> void:
	if _session == null or _world_time == null or not _session.is_host():
		return
	_sync_elapsed += delta
	if _sync_elapsed < SYNC_INTERVAL_SECONDS:
		return
	_sync_elapsed = 0.0
	_broadcast_snapshot()


func _on_session_state_changed(state: NetworkSession.State) -> void:
	if _world_time == null or _session == null:
		return
	if state in [NetworkSession.State.PRIVATE_HOST, NetworkSession.State.OPEN_HOST]:
		if _active_session_id != _session.get_session_id():
			_active_session_id = _session.get_session_id()
			_sequence = 0
			_last_received_sequence = -1
			_sync_elapsed = 0.0
			_world_time.begin_authoritative_session()
		return
	if state == NetworkSession.State.JOINED_CLIENT:
		_active_session_id = _session.get_session_id()
		_last_received_sequence = -1
		_sync_elapsed = 0.0
		if _session.supports_server_capability(
			NetworkProtocol.WORLD_TIME_CAPABILITY
		):
			_world_time.begin_remote_session()
		else:
			_world_time.end_session()
		return
	if state in [
		NetworkSession.State.INACTIVE,
		NetworkSession.State.DISCONNECTING,
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		_active_session_id = ""
		_sequence = 0
		_last_received_sequence = -1
		_sync_elapsed = 0.0
		_world_time.end_session()


func _on_peer_authenticated(peer_id: int, _display_name: String) -> void:
	if (
		_session == null
		or not _session.is_host()
		or not _session.peer_supports_capability(
			peer_id, NetworkProtocol.WORLD_TIME_CAPABILITY
		)
	):
		return
	_send_snapshot(peer_id)


func _on_authoritative_time_set(_time_hours: float) -> void:
	if _session == null or not _session.is_host():
		return
	_sync_elapsed = 0.0
	_broadcast_snapshot()


func _broadcast_snapshot() -> void:
	if _session == null or not _session.is_host():
		return
	for peer_id: int in _session.get_authenticated_peer_ids():
		if peer_id == _session.get_local_peer_id():
			continue
		if _session.peer_supports_capability(
			peer_id, NetworkProtocol.WORLD_TIME_CAPABILITY
		):
			_send_snapshot(peer_id)


func _send_snapshot(peer_id: int) -> void:
	_sequence += 1
	receive_world_time_snapshot.rpc_id(peer_id, {
		"session_id": _session.get_session_id(),
		"time_hours": _world_time.get_time_hours(),
		"sequence": _sequence,
	})


@rpc("authority", "call_remote", "reliable", 0)
func receive_world_time_snapshot(data: Dictionary) -> void:
	if (
		_session == null
		or _world_time == null
		or not _session.is_joined_client()
		or not _session.supports_server_capability(
			NetworkProtocol.WORLD_TIME_CAPABILITY
		)
		or not validate_snapshot(data)
		or str(data["session_id"]) != _session.get_session_id()
	):
		return
	var sequence: int = int(data["sequence"])
	if sequence <= _last_received_sequence:
		return
	_last_received_sequence = sequence
	_world_time.synchronize_time(float(data["time_hours"]))


static func validate_snapshot(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	return (
		typeof(value.get("session_id")) == TYPE_STRING
		and not str(value["session_id"]).is_empty()
		and str(value["session_id"]).length() <= MAX_SESSION_ID_LENGTH
		and typeof(value.get("time_hours")) in [TYPE_FLOAT, TYPE_INT]
		and is_finite(float(value["time_hours"]))
		and float(value["time_hours"]) >= 0.0
		and float(value["time_hours"]) < WorldTimeService.HOURS_PER_DAY
		and typeof(value.get("sequence")) == TYPE_INT
		and int(value["sequence"]) >= 0
	)
