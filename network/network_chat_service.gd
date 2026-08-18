class_name NetworkChatService
extends Node

const BURST_COUNT: int = 3
const WINDOW_COUNT: int = 5
const WINDOW_SECONDS: float = 10.0
const CALL_COOLDOWN_MILLISECONDS: int = 180
const CALL_PITCH_VARIANTS: Array[float] = [
	0.96,
	1.03,
	0.985,
	1.055,
	1.0,
	0.975,
	1.04,
]
const VoiceProfilesType = preload(
	"res://player/animalese_voice_profiles.gd"
)

signal message_received(message: Dictionary)
signal local_message_confirmed(message: Dictionary)
signal send_rejected(message: String)
signal history_replaced(messages: Array[Dictionary])
signal character_call_received(
	peer_id: int,
	call_id: String,
	pitch_scale: float,
)

var _session: NetworkSession
var _history: Array[Dictionary] = []
var _seen_messages: Dictionary[String, bool] = {}
var _request_ledgers: Dictionary[int, Dictionary] = {}
var _rate_times: Dictionary[int, Array] = {}
var _last_call_msec: Dictionary[int, int] = {}
var _call_variant_indices: Dictionary[int, int] = {}
var _sequence: int = 0
var _peer_names: Dictionary[int, String] = {}
var _relationships: PlayerRelationshipStore


func setup(session: NetworkSession) -> void:
	_session = session
	_session.peer_authenticated.connect(_on_peer_authenticated)
	_session.peer_removed.connect(_on_peer_removed)
	_session.state_changed.connect(_on_session_state_changed)
	_session.peer_display_name_changed.connect(
		func(peer_id: int, display_name: String) -> void:
			_peer_names[peer_id] = display_name
	)


func set_relationship_store(store: PlayerRelationshipStore) -> void:
	_relationships = store


func refresh_relationship_filters() -> void:
	history_replaced.emit(get_history())


func is_sender_filtered(fingerprint: String) -> bool:
	return (
		_relationships != null
		and _relationships.is_muted(fingerprint)
	)


func send_local_message(
	body: String,
	voice_id: String = VoiceProfilesType.DEFAULT_ID,
	sample_set_id: String = VoiceProfilesType.DEFAULT_SAMPLE_SET_ID,
) -> bool:
	if (
		_session == null
		or not _session.is_gameplay_session_active()
		or (
			not _session.is_host()
			and not _session.supports_server_capability(
				NetworkChatProtocol.CAPABILITY
			)
		)
	):
		send_rejected.emit("Chat is unavailable.")
		return false
	var clean := NetworkChatProtocol.sanitize_body(body)
	if clean.is_empty():
		send_rejected.emit("Message is empty or too long.")
		return false
	var request := {
		"request_id": _new_id("chat_request"),
		"session_id": _session.get_session_id(),
		"body": clean,
		"sender_fingerprint": _session.get_local_identity_fingerprint(),
		"voice_id": VoiceProfilesType.sanitized_id(voice_id),
		"sample_set_id": VoiceProfilesType.sanitized_sample_set_id(
			sample_set_id
		),
	}
	request["sender_signature"] = _session.sign_local_action(
		"chat_send", NetworkChatProtocol.signature_fields(request)
	)
	if _session.is_host():
		_handle_request(_session.get_local_peer_id(), request)
	else:
		submit_chat_message.rpc_id(1, request)
	return true


func send_local_character_call(call_id: String) -> bool:
	if (
		_session == null
		or not _session.is_gameplay_session_active()
		or not VoiceProfilesType.is_valid_call(call_id)
		or (
			not _session.is_host()
			and not _session.supports_server_capability(
				NetworkChatProtocol.CAPABILITY
			)
		)
	):
		return false
	var request := {
		"request_id": _new_id("character_call"),
		"session_id": _session.get_session_id(),
		"call_id": call_id,
		"sender_fingerprint": _session.get_local_identity_fingerprint(),
	}
	request["sender_signature"] = _session.sign_local_action(
		"character_call", _character_call_signature_fields(request)
	)
	if _session.is_host():
		_handle_character_call(_session.get_local_peer_id(), request)
	else:
		submit_character_call.rpc_id(1, request)
	return true


@rpc("any_peer", "call_remote", "reliable", NetworkChatProtocol.RELIABLE_CHANNEL)
func submit_character_call(data: Dictionary) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender_id):
		_handle_character_call(sender_id, data)


func _handle_character_call(peer_id: int, data: Dictionary) -> void:
	if (
		typeof(data.get("request_id")) != TYPE_STRING
		or str(data["request_id"]).is_empty()
		or str(data["request_id"]).length() > 64
		or typeof(data.get("session_id")) != TYPE_STRING
		or str(data["session_id"]) != _session.get_session_id()
		or typeof(data.get("call_id")) != TYPE_STRING
		or not VoiceProfilesType.is_valid_call(str(data["call_id"]))
		or typeof(data.get("sender_fingerprint")) != TYPE_STRING
		or typeof(data.get("sender_signature")) != TYPE_PACKED_BYTE_ARRAY
	):
		return
	var record := _session.get_peer_record(peer_id)
	if (
		record == null
		or record.identity_fingerprint != str(data["sender_fingerprint"])
		or not _session.verify_peer_action(
			peer_id,
			"character_call",
			_character_call_signature_fields(data),
			data["sender_signature"],
		)
		or not _consume_character_call_rate(peer_id)
	):
		return
	var pitch_scale: float = _next_character_call_pitch(peer_id)
	_apply_character_call(peer_id, str(data["call_id"]), pitch_scale)
	receive_character_call.rpc(
		peer_id,
		str(data["call_id"]),
		pitch_scale,
	)


@rpc("authority", "call_remote", "reliable", NetworkChatProtocol.RELIABLE_CHANNEL)
func receive_character_call(
	peer_id: int,
	call_id: String,
	pitch_scale: float,
) -> void:
	_apply_character_call(peer_id, call_id, pitch_scale)


func _apply_character_call(
	peer_id: int,
	call_id: String,
	pitch_scale: float,
) -> void:
	if (
		not VoiceProfilesType.is_valid_call(call_id)
		or pitch_scale < 0.9
		or pitch_scale > 1.1
		or _session == null
		or not _session.is_gameplay_session_active()
	):
		return
	var record := _session.get_peer_record(peer_id)
	if record == null or is_sender_filtered(record.identity_fingerprint):
		return
	character_call_received.emit(peer_id, call_id, pitch_scale)


func _next_character_call_pitch(peer_id: int) -> float:
	var variant_index: int = _call_variant_indices.get(peer_id, 0)
	var pitch_scale: float = CALL_PITCH_VARIANTS[
		variant_index % CALL_PITCH_VARIANTS.size()
	]
	_call_variant_indices[peer_id] = variant_index + 1
	return pitch_scale


func _consume_character_call_rate(peer_id: int) -> bool:
	var now_msec: int = Time.get_ticks_msec()
	var last_msec: int = _last_call_msec.get(
		peer_id, now_msec - CALL_COOLDOWN_MILLISECONDS
	)
	if now_msec - last_msec < CALL_COOLDOWN_MILLISECONDS:
		return false
	_last_call_msec[peer_id] = now_msec
	return true


func _character_call_signature_fields(data: Dictionary) -> Array:
	return [
		str(data.get("session_id", "")),
		str(data.get("request_id", "")),
		str(data.get("sender_fingerprint", "")),
		str(data.get("call_id", "")),
	]


func broadcast_system_message(body: String) -> bool:
	if _session == null or not _session.is_host():
		return false
	var clean := NetworkChatProtocol.sanitize_body(body)
	if clean.is_empty():
		return false
	_broadcast(_make_message(
		NetworkChatProtocol.Kind.SYSTEM,
		0,
		"",
		clean,
	))
	return true


func get_history() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for message: Dictionary in _history:
		if _message_is_visible(message):
			result.append(message.duplicate(true))
	return result


@rpc("any_peer", "call_remote", "reliable", NetworkChatProtocol.RELIABLE_CHANNEL)
func submit_chat_message(data: Dictionary) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender_id):
		_handle_request(sender_id, data)


func _handle_request(peer_id: int, data: Dictionary) -> void:
	if (
		not NetworkChatProtocol.validate_request(data)
		or str(data["session_id"]) != _session.get_session_id()
	):
		_send_rejection(peer_id, "Message could not be sent.")
		return
	var record := _session.get_peer_record(peer_id)
	if (
		record == null
		or record.identity_fingerprint != str(data["sender_fingerprint"])
		or not _session.verify_peer_action(
			peer_id,
			"chat_send",
			NetworkChatProtocol.signature_fields(data),
			data["sender_signature"],
		)
	):
		_send_rejection(peer_id, "Message identity could not be verified.")
		return
	var request_id: String = data["request_id"]
	var ledger: Dictionary = _request_ledgers.get(peer_id, {})
	if ledger.has(request_id):
		_send_message(peer_id, ledger[request_id])
		return
	if not _consume_rate(peer_id):
		_send_rejection(peer_id, "Slow down.")
		return
	var message := _make_message(
		NetworkChatProtocol.Kind.PLAYER,
		peer_id,
		record.display_name,
		NetworkChatProtocol.sanitize_body(data["body"]),
		VoiceProfilesType.sanitized_id(str(data.get(
			"voice_id", VoiceProfilesType.DEFAULT_ID
		))),
		VoiceProfilesType.sanitized_sample_set_id(str(data.get(
			"sample_set_id", VoiceProfilesType.DEFAULT_SAMPLE_SET_ID
		))),
	)
	message["request_id"] = request_id
	message["sender_fingerprint"] = data["sender_fingerprint"]
	message["sender_signature"] = data["sender_signature"]
	ledger[request_id] = message.duplicate(true)
	while ledger.size() > 64:
		ledger.erase(ledger.keys().front())
	_request_ledgers[peer_id] = ledger
	_broadcast(message)


func _make_message(
	kind: int,
	peer_id: int,
	display_name: String,
	body: String,
	voice_id: String = VoiceProfilesType.DEFAULT_ID,
	sample_set_id: String = VoiceProfilesType.DEFAULT_SAMPLE_SET_ID,
) -> Dictionary:
	_sequence += 1
	var message := {
		"message_id": _new_id("chat"),
		"request_id": _new_id("chat_system"),
		"session_id": _session.get_session_id(),
		"sequence": _sequence,
		"kind": kind,
		"sender_peer_id": peer_id,
		"sender_display_name": display_name.left(24),
		"body": body,
		"sender_fingerprint": _session.get_host_identity_fingerprint(),
		"voice_id": VoiceProfilesType.sanitized_id(voice_id),
		"sample_set_id": VoiceProfilesType.sanitized_sample_set_id(
			sample_set_id
		),
	}
	if kind == NetworkChatProtocol.Kind.SYSTEM:
		message["sender_signature"] = _session.sign_host_action(
			"chat_system", NetworkChatProtocol.signature_fields(message)
		)
	return message


func _broadcast(message: Dictionary) -> void:
	_apply_message(message)
	receive_chat_message.rpc(message)


func _send_message(peer_id: int, message: Dictionary) -> void:
	if peer_id == _session.get_local_peer_id():
		_apply_message(message)
	else:
		receive_chat_message.rpc_id(peer_id, message)


@rpc("authority", "call_remote", "reliable", NetworkChatProtocol.RELIABLE_CHANNEL)
func receive_chat_message(data: Dictionary) -> void:
	_apply_message(data)


func _apply_message(
	data: Dictionary,
	emit_live_signals: bool = true,
) -> void:
	if (
		not NetworkChatProtocol.validate_message(data)
		or str(data["session_id"]) != _session.get_session_id()
		or _seen_messages.has(str(data["message_id"]))
	):
		return
	var kind := int(data["kind"])
	var valid_signature := false
	if kind == NetworkChatProtocol.Kind.SYSTEM:
		valid_signature = _session.verify_host_action(
			"chat_system",
			NetworkChatProtocol.signature_fields(data),
			data["sender_signature"],
		)
	else:
		var sender_id := int(data["sender_peer_id"])
		var record := _session.get_peer_record(sender_id)
		valid_signature = (
			record != null
			and record.identity_fingerprint == str(data["sender_fingerprint"])
			and _session.verify_peer_action(
				sender_id,
				"chat_send",
				NetworkChatProtocol.signature_fields(data),
				data["sender_signature"],
			)
		)
	if not valid_signature:
		return
	_seen_messages[data["message_id"]] = true
	var stored_message := data.duplicate(true)
	# Suppression is immutable for this received copy. Relationship changes
	# later must never resurrect text that was hidden on arrival.
	stored_message["locally_suppressed"] = (
		kind == NetworkChatProtocol.Kind.PLAYER
		and is_sender_filtered(str(data.get("sender_fingerprint", "")))
	)
	_history.append(stored_message)
	while _history.size() > NetworkChatProtocol.MAX_HISTORY:
		_history.pop_front()
	if emit_live_signals and _message_is_visible(stored_message):
		message_received.emit(stored_message.duplicate(true))
		if (
			kind == NetworkChatProtocol.Kind.PLAYER
			and int(stored_message["sender_peer_id"])
				== _session.get_local_peer_id()
		):
			local_message_confirmed.emit(stored_message.duplicate(true))


func _send_rejection(peer_id: int, message: String) -> void:
	if peer_id == _session.get_local_peer_id():
		send_rejected.emit(message)
	else:
		receive_chat_rejection.rpc_id(peer_id, message.left(80))


@rpc("authority", "call_remote", "reliable", NetworkChatProtocol.RELIABLE_CHANNEL)
func receive_chat_rejection(message: String) -> void:
	send_rejected.emit(message.left(80))


func _on_peer_authenticated(peer_id: int, display_name: String) -> void:
	if not _session.is_host():
		return
	_peer_names[peer_id] = display_name
	var start := maxi(0, _history.size() - NetworkChatProtocol.LATE_JOIN_HISTORY)
	receive_chat_history.rpc_id(peer_id, _history.slice(start))
	_broadcast(_make_message(
		NetworkChatProtocol.Kind.SYSTEM, 0, "", "%s joined." % display_name
	))


func _on_peer_removed(peer_id: int) -> void:
	_request_ledgers.erase(peer_id)
	_rate_times.erase(peer_id)
	_last_call_msec.erase(peer_id)
	_call_variant_indices.erase(peer_id)
	if not _session.is_host():
		return
	var display_name: String = _peer_names.get(peer_id, "Player")
	_peer_names.erase(peer_id)
	_broadcast(_make_message(
		NetworkChatProtocol.Kind.SYSTEM, 0, "", "%s left." % display_name
	))


@rpc("authority", "call_remote", "reliable", NetworkChatProtocol.RELIABLE_CHANNEL)
func receive_chat_history(values: Array) -> void:
	if values.size() > NetworkChatProtocol.LATE_JOIN_HISTORY:
		return
	_history.clear()
	_seen_messages.clear()
	for value: Variant in values:
		if NetworkChatProtocol.validate_message(value):
			# Late-join history belongs in the scrollback, but it is not a live
			# event. In particular, do not recreate speech bubbles or replay
			# animalese for every stored player message when joining a room.
			_apply_message(value, false)
	history_replaced.emit(get_history())


func _message_is_visible(message: Dictionary) -> bool:
	if bool(message.get("locally_suppressed", false)):
		return false
	if int(message.get("kind", -1)) == NetworkChatProtocol.Kind.SYSTEM:
		return true
	return true


func _consume_rate(peer_id: int) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var times: Array = _rate_times.get(peer_id, [])
	while not times.is_empty() and now - float(times.front()) > WINDOW_SECONDS:
		times.pop_front()
	var recent_burst := 0
	for value: Variant in times:
		if now - float(value) <= 1.0:
			recent_burst += 1
	if recent_burst >= BURST_COUNT or times.size() >= WINDOW_COUNT:
		_rate_times[peer_id] = times
		return false
	times.append(now)
	_rate_times[peer_id] = times
	return true


func _on_session_state_changed(state: NetworkSession.State) -> void:
	if state in [
		NetworkSession.State.INACTIVE,
		NetworkSession.State.DISCONNECTING,
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		_history.clear()
		_seen_messages.clear()
		_request_ledgers.clear()
		_rate_times.clear()
		_last_call_msec.clear()
		_call_variant_indices.clear()
		_peer_names.clear()
		_sequence = 0
		history_replaced.emit([])


func _new_id(prefix: String) -> String:
	return "%s:%s" % [
		prefix, Crypto.new().generate_random_bytes(16).hex_encode(),
	]
