class_name NetworkJobService
extends Node

const MAX_SESSION_ID_LENGTH: int = 96
const BOARD_REQUEST_INTERVAL_SECONDS: float = 1.5

var _session: NetworkSession
var _jobs: PlayerJobService
var _sequence: int = 0
var _last_received_sequence: int = -1
var _board_request_accumulator: float = 0.0


func setup(session: NetworkSession, jobs: PlayerJobService) -> void:
	_session = session
	_jobs = jobs
	_session.state_changed.connect(_on_session_state_changed)
	_session.peer_authenticated.connect(_on_peer_authenticated)
	_jobs.board_changed.connect(_on_board_changed)
	set_process(true)


func _process(delta: float) -> void:
	if (
		_session == null
		or _jobs == null
		or not _session.is_joined_client()
		or not _session.supports_server_capability(
			NetworkProtocol.JOBS_CAPABILITY
		)
		or _jobs.has_active_board()
	):
		_board_request_accumulator = 0.0
		return
	_board_request_accumulator += delta
	if _board_request_accumulator < BOARD_REQUEST_INTERVAL_SECONDS:
		return
	_board_request_accumulator = 0.0
	_request_remote_board()


func _on_session_state_changed(state: NetworkSession.State) -> void:
	_sequence = 0
	_last_received_sequence = -1
	_board_request_accumulator = 0.0
	if state == NetworkSession.State.JOINED_CLIENT:
		if _session.supports_server_capability(NetworkProtocol.JOBS_CAPABILITY):
			_request_remote_board()
		else:
			_jobs.clear_remote_board()
	elif state in [
		NetworkSession.State.INACTIVE,
		NetworkSession.State.DISCONNECTING,
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		_jobs.clear_remote_board()


func _on_peer_authenticated(peer_id: int, _display_name: String) -> void:
	if (
		_session == null
		or not _session.is_host()
		or not _session.peer_supports_capability(
			peer_id, NetworkProtocol.JOBS_CAPABILITY
		)
	):
		return
	_send_board(peer_id)


func _on_board_changed() -> void:
	if _session == null or not _session.is_host():
		return
	for peer_id: int in _session.get_authenticated_peer_ids():
		if (
			peer_id != _session.get_local_peer_id()
			and _session.peer_supports_capability(
				peer_id, NetworkProtocol.JOBS_CAPABILITY
			)
		):
			_send_board(peer_id)


func _send_board(peer_id: int) -> void:
	var board: Dictionary = _jobs.get_host_board_network_data()
	if board.is_empty() or not PlayerJobService.validate_board(board):
		return
	_sequence += 1
	receive_job_board.rpc_id(peer_id, {
		"session_id": _session.get_session_id(),
		"sequence": _sequence,
		"board": board,
	})


func _request_remote_board() -> void:
	if (
		_session != null
		and _session.is_joined_client()
		and _session.supports_server_capability(
			NetworkProtocol.JOBS_CAPABILITY
		)
	):
		request_job_board.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable", 0)
func request_job_board() -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		_session == null
		or not _session.is_host()
		or sender_id <= 1
		or not _session.is_authenticated_peer(sender_id)
		or not _session.peer_supports_capability(
			sender_id, NetworkProtocol.JOBS_CAPABILITY
		)
	):
		return
	_send_board(sender_id)


@rpc("authority", "call_remote", "reliable", 0)
func receive_job_board(data: Dictionary) -> void:
	if (
		_session == null
		or _jobs == null
		or not _session.is_joined_client()
		or not _session.supports_server_capability(NetworkProtocol.JOBS_CAPABILITY)
		or not validate_snapshot(data)
		or str(data.get("session_id", "")) != _session.get_session_id()
	):
		return
	var sequence: int = int(data.get("sequence", -1))
	if sequence <= _last_received_sequence:
		return
	var board: Dictionary = data.get("board", {})
	if _jobs.apply_remote_board(board):
		_last_received_sequence = sequence
		_board_request_accumulator = 0.0


static func validate_snapshot(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = value
	return (
		typeof(data.get("session_id")) == TYPE_STRING
		and not str(data.get("session_id", "")).is_empty()
		and str(data.get("session_id", "")).length() <= MAX_SESSION_ID_LENGTH
		and typeof(data.get("sequence")) == TYPE_INT
		and int(data.get("sequence", -1)) >= 0
		and PlayerJobService.validate_board(data.get("board"))
	)
