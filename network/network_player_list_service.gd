class_name NetworkPlayerListService
extends Node

signal entries_changed
signal moderation_finished(success: bool, message: String)

var _session: NetworkSession
var _relationships: PlayerRelationshipStore
var _bans: HostBanStore
var _known: KnownPlayerStore
var _spawn: PlayerSpawnService
var _chat: NetworkChatService
var _mail: NetworkMailService
var _surface_drawing: NetworkSurfaceDrawingService
var _revision := 0
var _host_block_pairs: Dictionary[String, bool] = {}
var _peer_fingerprints: Dictionary[int, String] = {}
var _remote_bans: Array[Dictionary] = []
var _ban_snapshot_requested: bool = false
var _ban_snapshot_loaded: bool = false


func setup(
	session: NetworkSession,
	relationships: PlayerRelationshipStore,
	bans: HostBanStore,
	known: KnownPlayerStore,
	spawn: PlayerSpawnService,
	chat: NetworkChatService,
	mail: NetworkMailService,
) -> void:
	_session = session
	_relationships = relationships
	_bans = bans
	_known = known
	_spawn = spawn
	_chat = chat
	_mail = mail
	_session.peer_authenticated.connect(_on_peer_authenticated)
	_session.peer_removed.connect(_on_peer_removed)
	_session.peer_display_name_changed.connect(func(_id: int, _name: String) -> void: _changed())
	_session.peer_count_changed.connect(
		func(_count: int, _maximum: int) -> void: _sync_authenticated_peers()
	)
	_session.state_changed.connect(_on_session_state_changed)
	_session.operator_status_changed.connect(_on_operator_status_changed)
	_relationships.relationship_changed.connect(_on_relationship_changed)
	_bans.bans_changed.connect(_changed)
	_chat.set_relationship_store(_relationships)
	_mail.set_relationship_policy(self)
	for peer_id: int in _session.get_authenticated_peer_ids():
		_on_peer_authenticated(peer_id, "")


func get_entries() -> Array[PlayerListEntry]:
	var result: Array[PlayerListEntry] = []
	var local_id := _session.get_local_peer_id()
	for peer_id: int in _session.get_authenticated_peer_ids():
		var record := _session.get_peer_record(peer_id)
		if record == null or not record.identity_authenticated:
			continue
		var blocked := _relationships.is_blocked(record.identity_fingerprint)
		if blocked and peer_id != local_id:
			continue
		var entry := PlayerListEntry.new()
		entry.peer_id = peer_id
		entry.full_fingerprint = record.identity_fingerprint
		entry.compact_fingerprint = NetworkIdentityCrypto.compact_suffix(record.identity_fingerprint)
		entry.display_name = record.display_name
		entry.is_host = peer_id == 1
		entry.is_operator = _session.is_peer_operator(peer_id)
		entry.is_local_player = peer_id == local_id
		entry.continuity_state = _known.identity_status(record.identity_fingerprint, record.display_name)
		entry.ping_to_host_ms = _session.get_peer_rtt_ms(peer_id)
		entry.muted = _relationships.is_muted(record.identity_fingerprint)
		entry.blocked = blocked
		entry.can_kick = (
			_session.can_local_moderate()
			and peer_id != local_id
			and peer_id != 1
			and (_session.is_host() or not entry.is_operator)
		)
		entry.can_ban = entry.can_kick
		entry.can_manage_operator = (
			_session.can_manage_operators()
			and peer_id != local_id
			and peer_id != 1
		)
		entry.revision = _revision
		result.append(entry)
	result.sort_custom(_entry_before)
	return result


func get_connected_count() -> int:
	return _session.get_player_count()


func get_max_players() -> int:
	return _session.get_session_max_players()


func is_local_host() -> bool:
	return _session.is_host()


func is_local_moderator() -> bool:
	return _session.can_local_moderate()


func can_manage_operators() -> bool:
	return _session.can_manage_operators()


func is_open_host() -> bool:
	return _session.is_open_host()


func set_host_open(is_open: bool) -> bool:
	return _session.set_host_open(is_open)


func get_relationships() -> Array[Dictionary]:
	return _relationships.get_records()


func get_bans() -> Array[Dictionary]:
	if _session.is_host():
		return _bans.get_bans(_session.get_host_identity_fingerprint())
	if not _session.is_local_operator():
		return []
	_request_ban_snapshot()
	return _remote_bans.duplicate(true)


func set_surface_drawing_service(
	service: NetworkSurfaceDrawingService,
) -> void:
	_surface_drawing = service
	if (
		_surface_drawing != null
		and not _surface_drawing.session_artwork_changed.is_connected(
			_on_session_artwork_changed
		)
	):
		_surface_drawing.session_artwork_changed.connect(
			_on_session_artwork_changed
		)
	_changed()


func get_session_artwork_counts() -> Vector2i:
	if _surface_drawing == null:
		return Vector2i.ZERO
	return Vector2i(
		_surface_drawing.get_canvas_count(),
		_surface_drawing.get_painted_cell_count(),
	)


func reset_session_artwork() -> bool:
	if _session.is_host():
		return _reset_session_artwork_on_host()
	if not _session.is_local_operator():
		return false
	request_reset_session_artwork.rpc_id(1)
	return true


func set_muted(fingerprint: String, display_name: String, value: bool) -> bool:
	if fingerprint == _session.get_local_identity_fingerprint():
		return false
	return _relationships.set_muted(fingerprint, display_name, value)


func set_blocked(fingerprint: String, display_name: String, value: bool) -> bool:
	if fingerprint == _session.get_local_identity_fingerprint():
		return false
	return _relationships.set_blocked(fingerprint, display_name, value)


func kick(peer_id: int, fingerprint: String, revision: int) -> bool:
	if _session.is_host():
		return _kick_on_host(peer_id, fingerprint, revision, true)
	if not _session.is_local_operator():
		moderation_finished.emit(false, "Only the host or an operator can remove players.")
		return false
	request_kick.rpc_id(1, peer_id, fingerprint)
	return true


func ban(
	peer_id: int,
	fingerprint: String,
	display_name: String,
	revision: int,
) -> bool:
	if _session.is_host():
		return _ban_on_host(
			peer_id, fingerprint, display_name, revision, true
		)
	if not _session.is_local_operator():
		moderation_finished.emit(false, "Only the host or an operator can ban players.")
		return false
	request_ban.rpc_id(1, peer_id, fingerprint)
	return true


func unban(fingerprint: String) -> bool:
	if _session.is_host():
		var ok: bool = _bans.unban(
			_session.get_host_identity_fingerprint(), fingerprint
		)
		moderation_finished.emit(
			ok, "Player unbanned." if ok else "Ban could not be removed."
		)
		return ok
	if not _session.is_local_operator():
		moderation_finished.emit(false, "Only the host or an operator can remove bans.")
		return false
	request_unban.rpc_id(1, fingerprint)
	return true


func set_operator(
	peer_id: int,
	fingerprint: String,
	enabled: bool,
	revision: int,
) -> bool:
	if (
		not _session.can_manage_operators()
		or not _valid_moderation_target(
			peer_id, fingerprint, revision, true, true
		)
	):
		moderation_finished.emit(false, "That player is no longer connected.")
		return false
	var ok: bool = _session.set_peer_operator(peer_id, fingerprint, enabled)
	moderation_finished.emit(
		ok,
		("Player is now an operator." if enabled else "Operator access removed.")
		if ok
		else "Operator access could not be changed.",
	)
	return ok


@rpc("any_peer", "call_remote", "reliable", 0)
func request_kick(peer_id: int, fingerprint: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not _valid_operator_sender(sender_id):
		return
	var ok: bool = _kick_on_host(peer_id, fingerprint, -1, false)
	_send_moderation_result(
		sender_id, ok, "Player removed." if ok else "Player could not be removed."
	)


@rpc("any_peer", "call_remote", "reliable", 0)
func request_ban(peer_id: int, fingerprint: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not _valid_operator_sender(sender_id):
		return
	var record: PeerRegistry.PeerRecord = _session.get_peer_record(peer_id)
	var display_name: String = record.display_name if record != null else "Player"
	var ok: bool = _ban_on_host(
		peer_id, fingerprint, display_name, -1, false
	)
	_send_moderation_result(
		sender_id, ok, "Player banned." if ok else "Player could not be banned."
	)
	_send_ban_snapshot(sender_id)


@rpc("any_peer", "call_remote", "reliable", 0)
func request_unban(fingerprint: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		not _valid_operator_sender(sender_id)
		or not NetworkIdentityCrypto.valid_fingerprint(fingerprint)
	):
		return
	var ok: bool = _bans.unban(
		_session.get_host_identity_fingerprint(), fingerprint
	)
	_send_moderation_result(
		sender_id, ok, "Player unbanned." if ok else "Ban could not be removed."
	)
	_send_ban_snapshot(sender_id)


@rpc("any_peer", "call_remote", "reliable", 0)
func request_reset_session_artwork() -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not _valid_operator_sender(sender_id):
		return
	var ok: bool = _reset_session_artwork_on_host(false)
	_send_moderation_result(
		sender_id,
		ok,
		"Session artwork cleared."
		if ok
		else "Session artwork could not be cleared.",
	)


@rpc("any_peer", "call_remote", "reliable", 0)
func request_ban_snapshot() -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if _valid_operator_sender(sender_id):
		_send_ban_snapshot(sender_id)


@rpc("authority", "call_remote", "reliable", 0)
func receive_moderation_result(success: bool, message: String) -> void:
	if not _session.is_joined_client():
		return
	moderation_finished.emit(success, message.left(120))


@rpc("authority", "call_remote", "reliable", 0)
func receive_ban_snapshot(records: Array) -> void:
	if not _session.is_local_operator() or records.size() > HostBanStore.MAX_BANS:
		return
	var sanitized: Array[Dictionary] = []
	for value: Variant in records:
		if typeof(value) != TYPE_DICTIONARY:
			return
		var record: Dictionary = value
		var fingerprint: String = str(record.get("target_fingerprint", ""))
		var display_name: String = str(
			record.get("last_known_display_name", "Player")
		).strip_edges().left(NetworkProtocol.MAX_DISPLAY_NAME_LENGTH)
		if (
			not NetworkIdentityCrypto.valid_fingerprint(fingerprint)
			or display_name.is_empty()
			or typeof(record.get("banned_unix")) != TYPE_INT
		):
			return
		sanitized.append({
			"target_fingerprint": fingerprint,
			"last_known_display_name": display_name,
			"banned_unix": int(record["banned_unix"]),
		})
	_remote_bans = sanitized
	_ban_snapshot_requested = false
	_ban_snapshot_loaded = true
	_changed()


func is_locally_blocked(fingerprint: String) -> bool:
	return _relationships.is_blocked(fingerprint)


func pair_is_blocked(first: String, second: String) -> bool:
	if first.is_empty() or second.is_empty():
		return false
	return _host_block_pairs.has(_pair_key(first, second))


@rpc("any_peer", "call_remote", "reliable", 0)
func submit_block_policy(target_fingerprint: String, blocked: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _session.is_host() or not _session.is_authenticated_peer(sender):
		return
	var record := _session.get_peer_record(sender)
	if (
		record == null
		or not NetworkIdentityCrypto.valid_fingerprint(target_fingerprint)
		or record.identity_fingerprint == target_fingerprint
	):
		return
	_set_host_pair(record.identity_fingerprint, target_fingerprint, blocked)


func _on_relationship_changed(fingerprint: String) -> void:
	var blocked := _relationships.is_blocked(fingerprint)
	var avatar_peer := _peer_for_fingerprint(fingerprint)
	if avatar_peer > 0:
		_spawn.set_peer_presentation_visible(avatar_peer, not blocked)
	var local_fingerprint := _session.get_local_identity_fingerprint()
	if _session.is_host():
		_set_host_pair(local_fingerprint, fingerprint, blocked)
	elif _session.is_gameplay_session_active():
		submit_block_policy.rpc_id(1, fingerprint, blocked)
	_chat.refresh_relationship_filters()
	_mail.refresh_relationship_filters()
	_changed()


func _on_peer_authenticated(peer_id: int, _display_name: String) -> void:
	var record := _session.get_peer_record(peer_id)
	if record != null:
		_peer_fingerprints[peer_id] = record.identity_fingerprint
		var blocked := _relationships.is_blocked(record.identity_fingerprint)
		_spawn.set_peer_presentation_visible(peer_id, not blocked)
		if blocked and peer_id != _session.get_local_peer_id():
			var local_fingerprint := _session.get_local_identity_fingerprint()
			if _session.is_host():
				_set_host_pair(
					local_fingerprint, record.identity_fingerprint, true
				)
			else:
				submit_block_policy.rpc_id(
					1, record.identity_fingerprint, true
				)
	_changed()


func _sync_authenticated_peers() -> void:
	for peer_id: int in _session.get_authenticated_peer_ids():
		if not _peer_fingerprints.has(peer_id):
			_on_peer_authenticated(peer_id, "")
	_changed()


func _on_peer_removed(peer_id: int) -> void:
	var fingerprint := str(_peer_fingerprints.get(peer_id, ""))
	_peer_fingerprints.erase(peer_id)
	if _session.is_host() and not fingerprint.is_empty():
		for key: String in _host_block_pairs.keys():
			if fingerprint in key.split(":"):
				_host_block_pairs.erase(key)
	_changed()


func _on_session_state_changed(state: NetworkSession.State) -> void:
	if state in [
		NetworkSession.State.INACTIVE,
		NetworkSession.State.DISCONNECTING,
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		_host_block_pairs.clear()
		_peer_fingerprints.clear()
		_remote_bans.clear()
		_ban_snapshot_requested = false
		_ban_snapshot_loaded = false
	elif state == NetworkSession.State.JOINED_CLIENT:
		_request_ban_snapshot()
	_changed()


func _on_operator_status_changed(peer_id: int, enabled: bool) -> void:
	if peer_id == _session.get_local_peer_id():
		if enabled:
			_request_ban_snapshot()
		else:
			_remote_bans.clear()
			_ban_snapshot_requested = false
			_ban_snapshot_loaded = false
	_changed()


func _set_host_pair(first: String, second: String, blocked: bool) -> void:
	var key := _pair_key(first, second)
	if blocked:
		_host_block_pairs[key] = true
		_mail.cancel_unaccepted_between(first, second)
	else:
		_host_block_pairs.erase(key)


func _pair_key(first: String, second: String) -> String:
	return "%s:%s" % ([first, second] if first < second else [second, first])


func _peer_for_fingerprint(fingerprint: String) -> int:
	for peer_id: int in _session.get_authenticated_peer_ids():
		var record := _session.get_peer_record(peer_id)
		if record != null and record.identity_fingerprint == fingerprint:
			return peer_id
	return 0


func _valid_moderation_target(
	peer_id: int,
	fingerprint: String,
	revision: int,
	require_revision: bool,
	can_target_operator: bool,
) -> bool:
	if (
		not _session.is_host()
		or (require_revision and revision != _revision)
		or peer_id == 1
		or (not can_target_operator and _session.is_peer_operator(peer_id))
	):
		return false
	var record := _session.get_peer_record(peer_id)
	return record != null and record.identity_fingerprint == fingerprint


func _valid_operator_sender(peer_id: int) -> bool:
	return (
		_session.is_host()
		and peer_id > 1
		and _session.is_authenticated_peer(peer_id)
		and _session.is_peer_operator(peer_id)
	)


func _kick_on_host(
	peer_id: int,
	fingerprint: String,
	revision: int,
	local_host_request: bool,
) -> bool:
	if not _valid_moderation_target(
		peer_id,
		fingerprint,
		revision,
		local_host_request,
		local_host_request,
	):
		if local_host_request:
			moderation_finished.emit(false, "That player is no longer connected.")
		return false
	var ok: bool = _session.kick_authenticated_peer(peer_id, fingerprint)
	if local_host_request:
		moderation_finished.emit(
			ok, "Player removed." if ok else "Player could not be removed."
		)
	return ok


func _ban_on_host(
	peer_id: int,
	fingerprint: String,
	display_name: String,
	revision: int,
	local_host_request: bool,
) -> bool:
	if not _valid_moderation_target(
		peer_id,
		fingerprint,
		revision,
		local_host_request,
		local_host_request,
	):
		if local_host_request:
			moderation_finished.emit(false, "That player is no longer connected.")
		return false
	var record: PeerRegistry.PeerRecord = _session.get_peer_record(peer_id)
	var trusted_display_name: String = (
		record.display_name if record != null else display_name
	)
	var host_fingerprint: String = _session.get_host_identity_fingerprint()
	if not _bans.ban(host_fingerprint, fingerprint, trusted_display_name):
		if local_host_request:
			moderation_finished.emit(false, "Ban could not be saved.")
		return false
	var ok: bool = _session.kick_authenticated_peer(peer_id, fingerprint, true)
	if local_host_request:
		moderation_finished.emit(ok, "Player banned." if ok else "Ban saved.")
	return true


func _reset_session_artwork_on_host(
	emit_local_result: bool = true,
) -> bool:
	if not _session.is_host() or _surface_drawing == null:
		return false
	var ok: bool = _surface_drawing.clear_session_artwork()
	if emit_local_result:
		moderation_finished.emit(
			ok,
			"Session artwork cleared."
			if ok
			else "Session artwork could not be cleared.",
		)
	return ok


func _send_moderation_result(
	peer_id: int,
	success: bool,
	message: String,
) -> void:
	receive_moderation_result.rpc_id(peer_id, success, message.left(120))


func _send_ban_snapshot(peer_id: int) -> void:
	if not _valid_operator_sender(peer_id):
		return
	receive_ban_snapshot.rpc_id(
		peer_id,
		_bans.get_bans(_session.get_host_identity_fingerprint()),
	)


func _request_ban_snapshot() -> void:
	if (
		_session.is_local_operator()
		and not _ban_snapshot_requested
		and not _ban_snapshot_loaded
	):
		_ban_snapshot_requested = true
		request_ban_snapshot.rpc_id(1)


func _entry_before(a: PlayerListEntry, b: PlayerListEntry) -> bool:
	if a.is_host != b.is_host:
		return a.is_host
	if a.is_operator != b.is_operator:
		return a.is_operator
	if a.is_local_player != b.is_local_player:
		return a.is_local_player
	var compared := a.display_name.naturalnocasecmp_to(b.display_name)
	return compared < 0 if compared != 0 else a.full_fingerprint < b.full_fingerprint


func _changed() -> void:
	_revision += 1
	entries_changed.emit()


func _on_session_artwork_changed(
	_canvas_count: int,
	_painted_cell_count: int,
) -> void:
	_changed()
