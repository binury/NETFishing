class_name NetworkSession
extends Node

const DEFAULT_PORT: int = 7777
const DEFAULT_SESSION_MAX_PLAYERS: int = 8
const DEFAULT_TRANSPORT_MAX_CLIENTS: int = 31
const CONNECTION_TIMEOUT_SECONDS: float = 10.0
const AUTHENTICATION_TIMEOUT_SECONDS: float = 8.0
const INPUT_INTERVAL: float = 1.0 / 25.0
const SNAPSHOT_INTERVAL: float = 1.0 / 15.0

signal state_changed(state: State)
signal status_message_changed(message: String)
signal connection_error(message: String)
signal peer_authenticated(peer_id: int, display_name: String)
signal peer_removed(peer_id: int)
signal host_openness_changed(is_open: bool)
signal peer_count_changed(player_count: int, max_players: int)
signal peer_display_name_changed(peer_id: int, display_name: String)
signal peer_profile_changed(
	peer_id: int,
	display_name: String,
	appearance: Dictionary,
)
signal join_authenticated
signal server_lost
signal remote_recovery_requested(peer_id: int, entry_position: Vector3)

enum State {
	INACTIVE,
	STARTING_PRIVATE_HOST,
	PRIVATE_HOST,
	OPEN_HOST,
	CONNECTING,
	AUTHENTICATING,
	JOINED_CLIENT,
	DISCONNECTING,
	CONNECTION_FAILED,
	SERVER_LOST,
}

@export_range(2, 128, 1) var session_max_players: int = (
	DEFAULT_SESSION_MAX_PLAYERS
)
@export_range(1, 256, 1) var transport_max_clients: int = (
	DEFAULT_TRANSPORT_MAX_CLIENTS
)

var state: State = State.INACTIVE
var _transport: DirectEnetTransport
var _profile: NetworkProfilePreferences
var _saved_servers: SavedServerStore
var _spawn_service: PlayerSpawnService
var _registry := PeerRegistry.new()
var _pending_authentication: Dictionary[int, float] = {}
var _session_id: String = ""
var _operation_generation: int = 0
var _connection_deadline: float = 0.0
var _client_nonce: String = ""
var _current_route: ConnectionRoute
var _input_sequence: int = 0
var _input_accumulator: float = 0.0
var _snapshot_accumulator: float = 0.0
var _last_server_max_players: int = DEFAULT_SESSION_MAX_PLAYERS
var _last_server_player_count: int = 0
var _last_server_display_name: String = ""
var _last_server_protocol_version: int = 0
var _server_capabilities: PackedStringArray = PackedStringArray()
var _profile_ready: bool = false
var _local_appearance_snapshot: Dictionary = (
	CharacterCustomizationCatalog.default_snapshot()
)


func _ready() -> void:
	transport_max_clients = maxi(
		transport_max_clients,
		session_max_players - 1
	)
	_connect_multiplayer_signals()


func setup(
	profile: NetworkProfilePreferences,
	saved_servers: SavedServerStore,
	spawn_service: PlayerSpawnService,
) -> void:
	_profile = profile
	_saved_servers = saved_servers
	_spawn_service = spawn_service
	if _profile != null:
		_profile_ready = _profile.load_or_create()


func start_private_host(port: int = DEFAULT_PORT) -> bool:
	if (
		state != State.INACTIVE
		or not _profile_ready
		or _profile == null
		or _spawn_service == null
	):
		return false
	if port < 1 or port > 65535:
		_fail("The hosting port must be from 1 to 65535.")
		return false
	_operation_generation += 1
	_set_state(State.STARTING_PRIVATE_HOST, "Starting private game...")
	_replace_transport()
	var error: Error = _transport.start_host(
		port,
		transport_max_clients,
	)
	if error != OK:
		_fail("Could not start a private game on UDP port %d." % port)
		return false
	var peer: MultiplayerPeer = _transport.get_multiplayer_peer()
	peer.refuse_new_connections = true
	multiplayer.multiplayer_peer = peer
	_session_id = Crypto.new().generate_random_bytes(16).hex_encode()
	_registry.clear()
	_registry.add_peer(
		1,
		_profile.profile_id,
		_profile.display_name,
		NetworkProtocol.PROTOCOL_VERSION
	)
	_registry.update_appearance(1, _local_appearance_snapshot)
	_spawn_service.clear_remote_players()
	_spawn_service.register_local_player(1)
	var host_avatar := _spawn_service.get_avatar(1)
	if host_avatar != null:
		host_avatar.apply_appearance_snapshot(_local_appearance_snapshot)
	_set_state(State.PRIVATE_HOST, "Private game • UDP %d" % port)
	host_openness_changed.emit(false)
	_emit_peer_count()
	return true


func join_direct(endpoint_text: String) -> bool:
	if (
		state != State.INACTIVE
		or not _profile_ready
		or _profile == null
		or _spawn_service == null
	):
		return false
	var endpoint: ConnectionEndpoint = EndpointParser.parse(endpoint_text)
	if not endpoint.is_valid():
		_fail(endpoint.error_message)
		return false
	_operation_generation += 1
	var generation: int = _operation_generation
	_current_route = ConnectionRoute.direct(endpoint)
	_set_state(
		State.CONNECTING,
		"Connecting to %s..." % endpoint.normalized_display
	)
	_replace_transport()
	var error: Error = _transport.connect_to_route(_current_route)
	if error != OK:
		_fail("Could not begin the direct connection.")
		return false
	multiplayer.multiplayer_peer = _transport.get_multiplayer_peer()
	_connection_deadline = (
		Time.get_ticks_msec() / 1000.0 + CONNECTION_TIMEOUT_SECONDS
	)
	# The generation is checked by the process timeout and all state-gated
	# multiplayer callbacks.
	if generation != _operation_generation:
		return false
	return true


func cancel_connection() -> void:
	if state not in [State.CONNECTING, State.AUTHENTICATING]:
		return
	_operation_generation += 1
	_teardown_peer()
	_set_state(State.INACTIVE, "Connection cancelled.")


func reset_failure() -> void:
	if state not in [State.CONNECTION_FAILED, State.SERVER_LOST]:
		return
	_teardown_peer()
	_set_state(State.INACTIVE, "Ready for a direct connection.")


func disconnect_session(message: String = "Disconnected.") -> void:
	if state == State.INACTIVE:
		return
	if state in [State.CONNECTION_FAILED, State.SERVER_LOST]:
		_teardown_peer()
		_set_state(State.INACTIVE, message)
		return
	_operation_generation += 1
	_set_state(State.DISCONNECTING, "Disconnecting...")
	_teardown_peer()
	_set_state(State.INACTIVE, message)


func set_host_open(is_open: bool) -> bool:
	if state not in [State.PRIVATE_HOST, State.OPEN_HOST]:
		return false
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer == null:
		return false
	peer.refuse_new_connections = not is_open
	_set_state(
		State.OPEN_HOST if is_open else State.PRIVATE_HOST,
		(
			"Open game • %d / %d players"
			if is_open
			else "Private game • %d / %d players"
		) % [_registry.size(), session_max_players]
	)
	host_openness_changed.emit(is_open)
	return true


func is_host() -> bool:
	return state in [State.PRIVATE_HOST, State.OPEN_HOST]


func is_open_host() -> bool:
	return state == State.OPEN_HOST


func is_joined_client() -> bool:
	return state == State.JOINED_CLIENT


func get_player_count() -> int:
	return _registry.size()


func get_session_max_players() -> int:
	return session_max_players


func get_current_route_display() -> String:
	return (
		_current_route.display_description
		if _current_route != null
		else _transport.get_route_description() if _transport != null else ""
	)


func get_current_endpoint() -> ConnectionEndpoint:
	return (
		_current_route.direct_endpoint
		if _current_route != null
		and _current_route.kind == ConnectionRoute.Kind.DIRECT
		else null
	)


func get_last_server_metadata() -> Dictionary:
	return {
		"server_display_name": _last_server_display_name,
		"protocol_version": _last_server_protocol_version,
		"player_count": _last_server_player_count,
		"max_players": _last_server_max_players,
	}


func can_use_host_gameplay() -> bool:
	return is_host()


func is_gameplay_session_active() -> bool:
	return state in [State.PRIVATE_HOST, State.OPEN_HOST, State.JOINED_CLIENT]


func is_authenticated_peer(peer_id: int) -> bool:
	return _registry.has_peer(peer_id)


func get_session_id() -> String:
	return _session_id


func get_operation_generation() -> int:
	return _operation_generation


func supports_server_capability(capability: StringName) -> bool:
	if is_host():
		return str(capability) in PackedStringArray([
			"movement_v1", "fishing_v1", "sale_v1", "shop_v1",
			"item_use_v1", "equipment_v1", "chat_v1",
			"mail_v1",
			"profile_v1",
		])
	return str(capability) in _server_capabilities


func get_peer_record(peer_id: int) -> PeerRegistry.PeerRecord:
	return _registry.get_peer(peer_id)


func get_authenticated_peer_ids() -> Array[int]:
	return _registry.get_peer_ids()


func update_local_display_name(value: String) -> bool:
	if _profile == null or not _profile.set_display_name(value):
		return false
	var peer_id := get_local_peer_id()
	if is_host():
		_apply_display_name(peer_id, _profile.display_name)
		receive_display_name.rpc(peer_id, _profile.display_name)
	elif is_joined_client() and supports_server_capability(&"chat_v1"):
		submit_display_name.rpc_id(1, _profile.display_name)
	return true


func set_local_appearance_snapshot(snapshot: Dictionary) -> void:
	if CharacterCustomizationCatalog.validate_snapshot(snapshot):
		_local_appearance_snapshot = snapshot.duplicate(true)
		var local_id := get_local_peer_id()
		if local_id > 0:
			_registry.update_appearance(local_id, _local_appearance_snapshot)


func apply_canonical_profile(
	peer_id: int,
	display_name: String,
	appearance: Dictionary,
) -> bool:
	if (
		not NetworkProfilePreferences.is_valid_display_name(display_name)
		or not CharacterCustomizationCatalog.validate_snapshot(appearance)
	):
		return false
	var name_changed := _registry.update_display_name(peer_id, display_name)
	var appearance_changed := _registry.update_appearance(peer_id, appearance)
	if name_changed:
		peer_display_name_changed.emit(peer_id, display_name)
	if name_changed and appearance_changed:
		peer_profile_changed.emit(peer_id, display_name, appearance.duplicate(true))
	return name_changed and appearance_changed


@rpc("any_peer", "call_remote", "reliable", 0)
func submit_display_name(value: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if (
		is_host()
		and is_authenticated_peer(sender_id)
		and NetworkProfilePreferences.is_valid_display_name(value)
	):
		_apply_display_name(sender_id, value.strip_edges())
		receive_display_name.rpc(sender_id, value.strip_edges())


@rpc("authority", "call_remote", "reliable", 0)
func receive_display_name(peer_id: int, value: String) -> void:
	if NetworkProfilePreferences.is_valid_display_name(value):
		_apply_display_name(peer_id, value.strip_edges())


func _apply_display_name(peer_id: int, value: String) -> void:
	if _registry.update_display_name(peer_id, value):
		peer_display_name_changed.emit(peer_id, value)


func get_local_peer_id() -> int:
	return multiplayer.get_unique_id() if is_gameplay_session_active() else 0


func _process(delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	if (
		state in [State.CONNECTING, State.AUTHENTICATING]
		and _connection_deadline > 0.0
		and now >= _connection_deadline
	):
		_fail("Connection timed out.")
		_teardown_peer()
		return
	if is_host():
		_expire_pending_authentication(now)
	if state not in [State.OPEN_HOST, State.PRIVATE_HOST, State.JOINED_CLIENT]:
		return
	_input_accumulator += delta
	_snapshot_accumulator += delta
	if state == State.JOINED_CLIENT and _input_accumulator >= INPUT_INTERVAL:
		_input_accumulator = fmod(_input_accumulator, INPUT_INTERVAL)
		_send_local_input()
	if is_host() and _snapshot_accumulator >= SNAPSHOT_INTERVAL:
		_snapshot_accumulator = fmod(_snapshot_accumulator, SNAPSHOT_INTERVAL)
		_broadcast_movement_snapshots()


func _connect_multiplayer_signals() -> void:
	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.connected_to_server.is_connected(
		_on_connected_to_server
	):
		multiplayer.connected_to_server.connect(_on_connected_to_server)
	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
	if not multiplayer.server_disconnected.is_connected(
		_on_server_disconnected
	):
		multiplayer.server_disconnected.connect(_on_server_disconnected)


func _replace_transport() -> void:
	if _transport != null:
		_transport.disconnect_transport()
		_transport.queue_free()
	_transport = DirectEnetTransport.new()
	add_child(_transport)
	_transport.transport_error.connect(connection_error.emit)


func _on_peer_connected(peer_id: int) -> void:
	if not is_host():
		return
	if state != State.OPEN_HOST:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	_pending_authentication[peer_id] = (
		Time.get_ticks_msec() / 1000.0 + AUTHENTICATION_TIMEOUT_SECONDS
	)


func _on_connected_to_server() -> void:
	if state != State.CONNECTING:
		return
	_set_state(State.AUTHENTICATING, "Authenticating...")
	_client_nonce = Crypto.new().generate_random_bytes(16).hex_encode()
	var hello: Dictionary = NetworkProtocol.make_client_hello(
		_profile.profile_id,
		_profile.display_name,
		_client_nonce,
		_local_appearance_snapshot,
	)
	submit_client_hello.rpc_id(1, hello)


func _on_connection_failed() -> void:
	if state not in [State.CONNECTING, State.AUTHENTICATING]:
		return
	_teardown_peer()
	_fail("Could not connect. The server may be private, unavailable, or unreachable.")


func _on_server_disconnected() -> void:
	if state in [State.INACTIVE, State.DISCONNECTING]:
		return
	_operation_generation += 1
	_teardown_peer()
	_set_state(State.SERVER_LOST, "The server connection was lost.")
	server_lost.emit()
	connection_error.emit("The server connection was lost.")


func _on_peer_disconnected(peer_id: int) -> void:
	_pending_authentication.erase(peer_id)
	if _registry.has_peer(peer_id):
		_registry.remove_peer(peer_id)
		_spawn_service.remove_peer(peer_id)
		if is_host():
			receive_peer_despawn.rpc(peer_id)
		peer_removed.emit(peer_id)
		_emit_peer_count()


@rpc("any_peer", "call_remote", "reliable", 0)
func submit_client_hello(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not is_host() or sender_id <= 1 or not _pending_authentication.has(sender_id):
		return
	var validation_error: String = NetworkProtocol.validate_client_hello(data)
	if not validation_error.is_empty():
		_reject_peer(
			sender_id,
			NetworkProtocol.RejectionCode.MALFORMED_HANDSHAKE
		)
		return
	if int(data["protocol_version"]) != NetworkProtocol.PROTOCOL_VERSION:
		_reject_peer(
			sender_id,
			NetworkProtocol.RejectionCode.PROTOCOL_MISMATCH
		)
		return
	if _registry.size() >= session_max_players:
		_reject_peer(sender_id, NetworkProtocol.RejectionCode.SERVER_FULL)
		return
	var profile_id: String = data["local_profile_id"]
	if _registry.has_profile(profile_id):
		_reject_peer(
			sender_id,
			NetworkProtocol.RejectionCode.DUPLICATE_PROFILE
		)
		return
	var display_name: String = data["display_name"]
	if not NetworkProfilePreferences.is_valid_display_name(display_name):
		_reject_peer(
			sender_id,
			NetworkProtocol.RejectionCode.MALFORMED_HANDSHAKE
		)
		return
	if not _registry.add_peer(
		sender_id,
		profile_id,
		display_name,
		NetworkProtocol.PROTOCOL_VERSION
	):
		_reject_peer(
			sender_id,
			NetworkProtocol.RejectionCode.MALFORMED_HANDSHAKE
		)
		return
	var submitted_appearance := CharacterCustomizationCatalog.sanitized_snapshot(
		data["cosmetic_snapshot"]
	)
	_registry.update_appearance(sender_id, submitted_appearance)
	_pending_authentication.erase(sender_id)
	var spawn_index: int = _registry.get_peer_ids().find(sender_id)
	var spawn_transform: Transform3D = (
		_spawn_service.get_spawn_transform_for_index(spawn_index)
	)
	_spawn_service.spawn_remote_player(sender_id, spawn_transform, true)
	receive_server_hello.rpc_id(
		sender_id,
		NetworkProtocol.make_server_hello(
			true,
			NetworkProtocol.RejectionCode.NONE,
			_session_id,
			sender_id,
			_registry.size(),
			session_max_players
		)
	)
	receive_spawn_list.rpc_id(sender_id, _build_spawn_list())
	receive_peer_spawn.rpc(
		_make_spawn_entry(sender_id, display_name, spawn_transform)
	)
	peer_authenticated.emit(sender_id, display_name)
	_emit_peer_count()


func _reject_peer(
	peer_id: int,
	code: NetworkProtocol.RejectionCode,
) -> void:
	receive_server_hello.rpc_id(
		peer_id,
		NetworkProtocol.make_server_hello(
			false,
			code,
			_session_id,
			peer_id,
			_registry.size(),
			session_max_players
		)
	)
	_pending_authentication.erase(peer_id)
	call_deferred("_disconnect_rejected_peer", peer_id)


func _disconnect_rejected_peer(peer_id: int) -> void:
	if (
		is_host()
		and multiplayer.multiplayer_peer != null
		and multiplayer.multiplayer_peer.get_connection_status()
		== MultiplayerPeer.CONNECTION_CONNECTED
	):
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


@rpc("authority", "call_remote", "reliable", 0)
func receive_server_hello(data: Dictionary) -> void:
	if state != State.AUTHENTICATING:
		return
	if (
		typeof(data.get("accepted")) != TYPE_BOOL
		or typeof(data.get("protocol_version")) != TYPE_INT
		or typeof(data.get("rejection_code")) != TYPE_INT
	):
		_teardown_peer()
		_fail("The server sent an invalid handshake response.")
		return
	if not bool(data["accepted"]):
		var message: String = NetworkProtocol.rejection_text(
			int(data["rejection_code"])
		)
		_teardown_peer()
		_fail(message)
		return
	if int(data["protocol_version"]) != NetworkProtocol.PROTOCOL_VERSION:
		_teardown_peer()
		_fail("The server uses a different network protocol.")
		return
	_session_id = str(data.get("session_id", ""))
	_last_server_max_players = int(data.get(
		"max_players",
		DEFAULT_SESSION_MAX_PLAYERS
	))
	_last_server_player_count = int(data.get("player_count", 1))
	_last_server_display_name = str(data.get("server_display_name", ""))
	_last_server_protocol_version = int(data.get(
		"protocol_version", NetworkProtocol.PROTOCOL_VERSION
	))
	_server_capabilities = PackedStringArray()
	var advertised_capabilities: Variant = data.get(
		"capability_flags", PackedStringArray()
	)
	if typeof(advertised_capabilities) in [
		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY
	]:
		for value: Variant in advertised_capabilities:
			if typeof(value) in [TYPE_STRING, TYPE_STRING_NAME]:
				_server_capabilities.append(str(value))
	var local_peer_id: int = multiplayer.get_unique_id()
	_registry.clear()
	_registry.add_peer(
		local_peer_id,
		_profile.profile_id,
		_profile.display_name,
		NetworkProtocol.PROTOCOL_VERSION
	)
	_registry.update_appearance(local_peer_id, _local_appearance_snapshot)
	_spawn_service.clear_remote_players()
	_spawn_service.register_local_player(local_peer_id)
	var local_avatar := _spawn_service.get_avatar(local_peer_id)
	if local_avatar != null:
		local_avatar.apply_appearance_snapshot(_local_appearance_snapshot)
	_connection_deadline = 0.0
	_set_state(
		State.JOINED_CLIENT,
		"Connected • %d / %d players" % [
			int(data.get("player_count", 1)),
			_last_server_max_players,
		]
	)
	join_authenticated.emit()


@rpc("authority", "call_remote", "reliable", 0)
func receive_spawn_list(entries: Array) -> void:
	if state != State.JOINED_CLIENT:
		return
	for value: Variant in entries:
		if typeof(value) == TYPE_DICTIONARY:
			_apply_spawn_entry(value)
	_emit_peer_count()


@rpc("authority", "call_remote", "reliable", 0)
func receive_peer_spawn(entry: Dictionary) -> void:
	if state != State.JOINED_CLIENT:
		return
	_apply_spawn_entry(entry)
	_emit_peer_count()


@rpc("authority", "call_remote", "reliable", 0)
func receive_peer_despawn(peer_id: int) -> void:
	if state != State.JOINED_CLIENT:
		return
	_registry.remove_peer(peer_id)
	_spawn_service.remove_peer(peer_id)
	peer_removed.emit(peer_id)
	_emit_peer_count()


func _apply_spawn_entry(entry: Dictionary) -> void:
	if (
		typeof(entry.get("peer_id")) != TYPE_INT
		or typeof(entry.get("profile_id")) != TYPE_STRING
		or typeof(entry.get("display_name")) != TYPE_STRING
		or typeof(entry.get("position")) != TYPE_ARRAY
		or typeof(entry.get("yaw")) not in [TYPE_FLOAT, TYPE_INT]
	):
		return
	var peer_id: int = entry["peer_id"]
	if peer_id == multiplayer.get_unique_id():
		var own_position: Array = entry["position"]
		if own_position.size() == 3:
			var own_avatar: Player = _spawn_service.get_avatar(peer_id)
			if own_avatar != null:
				var own_snapshot: Dictionary = own_avatar.make_network_snapshot(
					peer_id
				)
				own_snapshot["position"] = own_position
				own_snapshot["visual_yaw"] = float(entry["yaw"])
				own_avatar.apply_network_teleport(own_snapshot)
		return
	if not _registry.has_peer(peer_id):
		_registry.add_peer(
			peer_id,
			entry["profile_id"],
			entry["display_name"],
			NetworkProtocol.PROTOCOL_VERSION
		)
	if typeof(entry.get("appearance")) == TYPE_DICTIONARY:
		var appearance := CharacterCustomizationCatalog.sanitized_snapshot(
			entry["appearance"]
		)
		_registry.update_appearance(peer_id, appearance)
	var transform: Transform3D = _spawn_service.get_spawn_transform_for_index(0)
	var position: Array = entry["position"]
	if position.size() != 3:
		return
	transform.origin = Vector3(
		float(position[0]),
		float(position[1]),
		float(position[2])
	)
	transform.basis = Basis(Vector3.UP, float(entry["yaw"]))
	var avatar := _spawn_service.spawn_remote_player(peer_id, transform, false)
	var record := _registry.get_peer(peer_id)
	if avatar != null and record != null:
		avatar.apply_appearance_snapshot(record.appearance_snapshot)


func _build_spawn_list() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for peer_id: int in _registry.get_peer_ids():
		var record: PeerRegistry.PeerRecord = _registry.get_peer(peer_id)
		var avatar: Player = _spawn_service.get_avatar(peer_id)
		if record != null and avatar != null:
			entries.append(_make_spawn_entry(
				peer_id,
				record.display_name,
				avatar.global_transform
			))
	return entries


func _make_spawn_entry(
	peer_id: int,
	display_name: String,
	transform: Transform3D,
) -> Dictionary:
	var record: PeerRegistry.PeerRecord = _registry.get_peer(peer_id)
	return {
		"peer_id": peer_id,
		"profile_id": record.profile_id if record != null else "",
		"display_name": display_name,
		"position": [
			transform.origin.x,
			transform.origin.y,
			transform.origin.z,
		],
		"yaw": transform.basis.get_euler().y,
		"appearance": (
			record.appearance_snapshot.duplicate(true)
			if record != null
			else CharacterCustomizationCatalog.default_snapshot()
		),
	}


func _send_local_input() -> void:
	var peer_id: int = multiplayer.get_unique_id()
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	if avatar == null:
		return
	_input_sequence += 1
	var input: Dictionary = avatar.capture_network_input(_input_sequence)
	submit_movement_input.rpc_id(1, input)


@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func submit_movement_input(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not is_host() or not _registry.has_peer(sender_id):
		return
	var avatar: Player = _spawn_service.get_avatar(sender_id)
	if avatar == null or not _is_valid_movement_input(data):
		return
	avatar.apply_authoritative_network_input(data)


func _is_valid_movement_input(data: Dictionary) -> bool:
	if (
		typeof(data.get("sequence")) != TYPE_INT
		or typeof(data.get("axis")) != TYPE_ARRAY
		or typeof(data.get("jump")) != TYPE_BOOL
		or typeof(data.get("sprint")) != TYPE_BOOL
		or typeof(data.get("sneak")) != TYPE_BOOL
		or typeof(data.get("slow_walk")) != TYPE_BOOL
		or typeof(data.get("camera_yaw")) not in [TYPE_FLOAT, TYPE_INT]
	):
		return false
	var axis: Array = data["axis"]
	if axis.size() != 2:
		return false
	var x: float = float(axis[0])
	var y: float = float(axis[1])
	var camera_yaw: float = float(data["camera_yaw"])
	return (
		is_finite(x)
		and is_finite(y)
		and is_finite(camera_yaw)
		and absf(x) <= 1.01
		and absf(y) <= 1.01
		and absf(camera_yaw) <= TAU * 100.0
	)


func _broadcast_movement_snapshots() -> void:
	var snapshots: Array[Dictionary] = []
	for peer_id: int in _registry.get_peer_ids():
		var avatar: Player = _spawn_service.get_avatar(peer_id)
		if avatar == null:
			continue
		snapshots.append(avatar.make_network_snapshot(peer_id))
	receive_movement_snapshots.rpc(snapshots)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_movement_snapshots(snapshots: Array) -> void:
	if state != State.JOINED_CLIENT:
		return
	var local_peer_id: int = multiplayer.get_unique_id()
	for value: Variant in snapshots:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var snapshot: Dictionary = value
		if typeof(snapshot.get("peer_id")) != TYPE_INT:
			continue
		var peer_id: int = snapshot["peer_id"]
		var avatar: Player = _spawn_service.get_avatar(peer_id)
		if avatar == null:
			continue
		if peer_id == local_peer_id:
			avatar.apply_local_prediction_correction(snapshot)
		else:
			avatar.push_network_snapshot(snapshot)


func publish_authoritative_teleport(peer_id: int) -> void:
	if not is_host():
		return
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	if avatar == null:
		return
	receive_authoritative_teleport.rpc(
		avatar.make_network_snapshot(peer_id)
	)


func request_safe_respawn(entry_position: Vector3) -> void:
	if not entry_position.is_finite():
		return
	if is_host():
		remote_recovery_requested.emit(1, entry_position)
	elif state == State.JOINED_CLIENT:
		submit_safe_respawn_request.rpc_id(
			1,
			[entry_position.x, entry_position.y, entry_position.z]
		)


@rpc("any_peer", "call_remote", "reliable", 0)
func submit_safe_respawn_request(position_data: Array) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		not is_host()
		or not _registry.has_peer(sender_id)
		or position_data.size() != 3
	):
		return
	var entry_position := Vector3(
		float(position_data[0]),
		float(position_data[1]),
		float(position_data[2])
	)
	if not entry_position.is_finite():
		return
	remote_recovery_requested.emit(sender_id, entry_position)


@rpc("authority", "call_remote", "reliable", 0)
func receive_authoritative_teleport(snapshot: Dictionary) -> void:
	if state != State.JOINED_CLIENT:
		return
	var peer_id: int = int(snapshot.get("peer_id", 0))
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	if avatar != null:
		avatar.apply_network_teleport(snapshot)


func _expire_pending_authentication(now: float) -> void:
	for peer_id: int in _pending_authentication.keys():
		if now >= float(_pending_authentication[peer_id]):
			_reject_peer(
				peer_id,
				NetworkProtocol.RejectionCode.AUTHENTICATION_TIMEOUT
			)


func _emit_peer_count() -> void:
	peer_count_changed.emit(_registry.size(), session_max_players)


func _set_state(new_state: State, message: String) -> void:
	if not _is_transition_allowed(state, new_state):
		push_warning(
			"Rejected invalid network state transition %s -> %s."
			% [State.keys()[state], State.keys()[new_state]]
		)
		return
	state = new_state
	state_changed.emit(state)
	status_message_changed.emit(message)


func _is_transition_allowed(from_state: State, to_state: State) -> bool:
	if from_state == to_state:
		return true
	var allowed: Dictionary[State, Array] = {
		State.INACTIVE: [
			State.STARTING_PRIVATE_HOST,
			State.CONNECTING,
			State.CONNECTION_FAILED,
		],
		State.STARTING_PRIVATE_HOST: [
			State.PRIVATE_HOST,
			State.CONNECTION_FAILED,
			State.DISCONNECTING,
		],
		State.PRIVATE_HOST: [
			State.OPEN_HOST,
			State.DISCONNECTING,
		],
		State.OPEN_HOST: [
			State.PRIVATE_HOST,
			State.DISCONNECTING,
		],
		State.CONNECTING: [
			State.AUTHENTICATING,
			State.CONNECTION_FAILED,
			State.DISCONNECTING,
			State.INACTIVE,
		],
		State.AUTHENTICATING: [
			State.JOINED_CLIENT,
			State.CONNECTION_FAILED,
			State.DISCONNECTING,
			State.INACTIVE,
		],
		State.JOINED_CLIENT: [
			State.DISCONNECTING,
			State.SERVER_LOST,
		],
		State.DISCONNECTING: [
			State.INACTIVE,
			State.CONNECTING,
		],
		State.CONNECTION_FAILED: [
			State.INACTIVE,
			State.CONNECTING,
			State.DISCONNECTING,
		],
		State.SERVER_LOST: [
			State.INACTIVE,
			State.CONNECTING,
			State.DISCONNECTING,
		],
	}
	return to_state in allowed.get(from_state, [])


func _fail(message: String) -> void:
	_set_state(State.CONNECTION_FAILED, message)
	connection_error.emit(message)


func _teardown_peer() -> void:
	_pending_authentication.clear()
	_registry.clear()
	if _spawn_service != null:
		_spawn_service.clear_remote_players()
	if _transport != null:
		_transport.disconnect_transport()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_connection_deadline = 0.0
	_input_accumulator = 0.0
	_snapshot_accumulator = 0.0
	_server_capabilities = PackedStringArray()
