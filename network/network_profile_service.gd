class_name NetworkProfileService
extends Node

const VoiceProfilesType = preload(
	"res://player/animalese_voice_profiles.gd"
)

signal conflict_result(
	request_id: String,
	has_conflict: bool,
	suggestions: PackedStringArray,
)
signal apply_finished(accepted: bool, message: String)
signal profile_snapshot_changed(
	peer_id: int,
	display_name: String,
	appearance: Dictionary,
)

var _session: NetworkSession
var _preferences: NetworkProfilePreferences
var _appearance_store: PlayerAppearanceStore
var _spawn_service: PlayerSpawnService
var _pending_apply: Dictionary[String, Dictionary] = {}
var _pending_voice_ids: Dictionary[String, String] = {}
var _pending_speech_speed_ids: Dictionary[String, String] = {}
var _pending_call_ids: Dictionary[String, String] = {}
var _host_pending_apply: Dictionary[String, Dictionary] = {}
var _latest_check_id: String = ""
var _latest_check_name: String = ""


func setup(
	session: NetworkSession,
	preferences: NetworkProfilePreferences,
	appearance_store: PlayerAppearanceStore,
	spawn_service: PlayerSpawnService,
) -> void:
	_session = session
	_preferences = preferences
	_appearance_store = appearance_store
	_spawn_service = spawn_service
	_appearance_store.load_preferences()
	_session.peer_authenticated.connect(_on_peer_authenticated)
	_session.peer_removed.connect(_on_peer_removed)
	_session.peer_display_name_changed.connect(_on_peer_display_name_changed)
	_session.join_authenticated.connect(_on_join_authenticated)
	_session.state_changed.connect(_on_session_state_changed)
	_apply_to_avatar(1, _appearance_store.get_snapshot())
	_apply_local_voice_to_avatar()


func get_persisted_name() -> String:
	return _preferences.display_name


func get_persisted_appearance() -> Dictionary:
	return _appearance_store.get_snapshot()


func get_persisted_voice_id() -> String:
	return _preferences.voice_id


func get_persisted_speech_speed_id() -> String:
	return _preferences.speech_speed_id


func get_persisted_call_id() -> String:
	return _preferences.call_id


func get_identity_fingerprint() -> String:
	return (
		_session.get_local_identity_fingerprint()
		if _session != null else ""
	)


func request_name_check(display_name: String) -> String:
	var request_id := _new_id()
	_latest_check_id = request_id
	var clean_name := display_name.strip_edges()
	_latest_check_name = clean_name
	if not NetworkProfilePreferences.is_valid_display_name(clean_name):
		conflict_result.emit(request_id, false, PackedStringArray())
		return request_id
	if _session == null or not _session.is_gameplay_session_active():
		conflict_result.emit(request_id, false, PackedStringArray())
	elif _session.is_host():
		var result := _make_conflict_result(
			_session.get_local_peer_id(), clean_name, request_id
		)
		_emit_conflict_result(result)
	elif _session.supports_server_capability(&"profile_v1"):
		submit_name_check.rpc_id(1, {
			"request_id": request_id,
			"session_id": _session.get_session_id(),
			"display_name": clean_name,
		})
	else:
		conflict_result.emit(request_id, false, PackedStringArray())
	return request_id


func apply_profile(
	display_name: String,
	appearance: Dictionary,
	use_anyway: bool,
	voice_id: String = VoiceProfilesType.DEFAULT_ID,
	speech_speed_id: String = VoiceProfilesType.DEFAULT_SPEED_ID,
	call_id: String = VoiceProfilesType.DEFAULT_CALL_ID,
) -> bool:
	var clean_name := display_name.strip_edges()
	if (
		not NetworkProfilePreferences.is_valid_display_name(clean_name)
		or not CharacterCustomizationCatalog.validate_snapshot(appearance)
		or not VoiceProfilesType.is_valid(voice_id)
		or not VoiceProfilesType.is_valid_speed(speech_speed_id)
		or not VoiceProfilesType.is_valid_call(call_id)
	):
		apply_finished.emit(false, "Check the player name and appearance choices.")
		return false
	var request_id := _new_id()
	var request := {
		"request_id": request_id,
		"session_id": _session.get_session_id() if _session != null else "",
		"display_name": clean_name,
		"appearance": appearance.duplicate(true),
		"use_anyway": use_anyway,
		"sender_fingerprint": _session.get_local_identity_fingerprint(),
	}
	request["sender_signature"] = _session.sign_local_action(
		"profile_update", NetworkProfileProtocol.signature_fields(request)
	)
	_pending_apply[request_id] = request
	_pending_voice_ids[request_id] = voice_id
	_pending_speech_speed_ids[request_id] = speech_speed_id
	_pending_call_ids[request_id] = call_id
	if _session == null or not _session.is_gameplay_session_active():
		_apply_local_result(request_id, true, "", false, PackedStringArray())
	elif _session.is_host():
		_process_apply_request(_session.get_local_peer_id(), request)
	elif _session.supports_server_capability(&"profile_v1"):
		submit_profile_apply.rpc_id(1, request)
	else:
		_apply_local_result(request_id, true, "", false, PackedStringArray())
	return true


@rpc("any_peer", "call_remote", "reliable", NetworkProfileProtocol.RELIABLE_CHANNEL)
func submit_name_check(data: Dictionary) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if (
		not _session.is_host()
		or not _session.is_authenticated_peer(sender_id)
		or not NetworkProfileProtocol.valid_check_request(data)
		or str(data["session_id"]) != _session.get_session_id()
	):
		return
	receive_name_check.rpc_id(
		sender_id,
		_make_conflict_result(sender_id, str(data["display_name"]), str(data["request_id"])),
	)


@rpc("authority", "call_remote", "reliable", NetworkProfileProtocol.RELIABLE_CHANNEL)
func receive_name_check(data: Dictionary) -> void:
	if (
		typeof(data.get("request_id")) != TYPE_STRING
		or typeof(data.get("has_conflict")) != TYPE_BOOL
		or typeof(data.get("suggestions")) != TYPE_ARRAY
	):
		return
	_emit_conflict_result(data)


@rpc("any_peer", "call_remote", "reliable", NetworkProfileProtocol.RELIABLE_CHANNEL)
func submit_profile_apply(data: Dictionary) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if (
		not _session.is_host()
		or not _session.is_authenticated_peer(sender_id)
		or not NetworkProfileProtocol.valid_apply_request(data)
		or str(data["session_id"]) != _session.get_session_id()
	):
		return
	var record := _session.get_peer_record(sender_id)
	if (
		record == null
		or record.identity_fingerprint != str(data["sender_fingerprint"])
		or not _session.verify_peer_action(
			sender_id,
			"profile_update",
			NetworkProfileProtocol.signature_fields(data),
			data["sender_signature"],
		)
	):
		return
	_process_apply_request(sender_id, data)


func _process_apply_request(peer_id: int, data: Dictionary) -> void:
	var display_name: String = str(data["display_name"]).strip_edges()
	var conflict: bool = _name_conflicts(peer_id, display_name)
	var accepted: bool = not conflict or bool(data["use_anyway"])
	var suggestions: PackedStringArray = (
		_make_suggestions(peer_id, display_name)
		if conflict
		else PackedStringArray()
	)
	if peer_id == _session.get_local_peer_id():
		_apply_local_result(
			str(data["request_id"]), accepted, "", conflict, suggestions
		)
	else:
		if accepted:
			_host_pending_apply[str(data["request_id"])] = {
				"peer_id": peer_id,
					"display_name": display_name,
				"appearance": Dictionary(data["appearance"]).duplicate(true),
				"authorization": {
					"request_id": data["request_id"],
					"session_id": data["session_id"],
					"sender_fingerprint": data["sender_fingerprint"],
					"sender_signature": data["sender_signature"],
					"use_anyway": data["use_anyway"],
				},
			}
		receive_profile_result.rpc_id(peer_id, {
			"request_id": data["request_id"],
			"accepted": accepted,
			"conflict": conflict,
			"suggestions": Array(suggestions),
			"message": "" if accepted else "That name is already in use in this game.",
		})


@rpc("any_peer", "call_remote", "reliable", NetworkProfileProtocol.RELIABLE_CHANNEL)
func confirm_profile_saved(request_id: String) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	var pending: Dictionary = _host_pending_apply.get(request_id, {})
	if (
		not _session.is_host()
		or pending.is_empty()
		or int(pending["peer_id"]) != sender_id
	):
		return
	_host_pending_apply.erase(request_id)
	var display_name: String = str(pending["display_name"])
	var appearance: Dictionary = Dictionary(pending["appearance"])
	_session.apply_canonical_profile(sender_id, display_name, appearance)
	var record: PeerRegistry.PeerRecord = _session.get_peer_record(sender_id)
	if record != null:
		record.profile_authorization = pending.get("authorization", {}).duplicate(true)
	_apply_to_avatar(sender_id, appearance)
	broadcast_profile_snapshot.rpc(
		sender_id,
		name,
		appearance,
		pending.get("authorization", {}),
	)


@rpc("authority", "call_remote", "reliable", NetworkProfileProtocol.RELIABLE_CHANNEL)
func receive_profile_result(data: Dictionary) -> void:
	if (
		typeof(data.get("request_id")) != TYPE_STRING
		or typeof(data.get("accepted")) != TYPE_BOOL
		or typeof(data.get("conflict")) != TYPE_BOOL
		or typeof(data.get("suggestions")) != TYPE_ARRAY
	):
		return
	var suggestions := PackedStringArray(data["suggestions"])
	_apply_local_result(
		str(data["request_id"]),
		bool(data["accepted"]),
		str(data.get("message", "")),
		bool(data["conflict"]),
		suggestions,
	)


func _apply_local_result(
	request_id: String,
	accepted: bool,
	message: String,
	conflict: bool,
	suggestions: PackedStringArray,
) -> void:
	var request: Dictionary = _pending_apply.get(request_id, {})
	if request.is_empty():
		return
	if not accepted:
		_pending_apply.erase(request_id)
		_pending_voice_ids.erase(request_id)
		_pending_speech_speed_ids.erase(request_id)
		_pending_call_ids.erase(request_id)
		conflict_result.emit(request_id, conflict, suggestions)
		apply_finished.emit(false, message)
		return
	var previous_name := _preferences.display_name
	var previous_voice_id := _preferences.voice_id
	var previous_speech_speed_id := _preferences.speech_speed_id
	var previous_call_id := _preferences.call_id
	var requested_voice_id: String = _pending_voice_ids.get(
		request_id,
		VoiceProfilesType.DEFAULT_ID,
	)
	var requested_speech_speed_id: String = _pending_speech_speed_ids.get(
		request_id,
		VoiceProfilesType.DEFAULT_SPEED_ID,
	)
	var requested_call_id: String = _pending_call_ids.get(
		request_id,
		VoiceProfilesType.DEFAULT_CALL_ID,
	)
	if not _preferences.set_profile_identity(
		str(request["display_name"]),
		requested_voice_id,
		requested_speech_speed_id,
		requested_call_id,
	):
		_pending_apply.erase(request_id)
		_pending_voice_ids.erase(request_id)
		_pending_speech_speed_ids.erase(request_id)
		_pending_call_ids.erase(request_id)
		apply_finished.emit(false, "Profile could not be saved.")
		return
	if not _appearance_store.save_snapshot(request["appearance"]):
		_preferences.set_profile_identity(
			previous_name,
			previous_voice_id,
			previous_speech_speed_id,
			previous_call_id,
		)
		_pending_apply.erase(request_id)
		_pending_voice_ids.erase(request_id)
		_pending_speech_speed_ids.erase(request_id)
		_pending_call_ids.erase(request_id)
		apply_finished.emit(false, "Profile could not be saved.")
		return
	_pending_apply.erase(request_id)
	_pending_voice_ids.erase(request_id)
	_pending_speech_speed_ids.erase(request_id)
	_pending_call_ids.erase(request_id)
	if _session != null and _session.is_gameplay_session_active():
		if _session.is_host():
			_session.apply_canonical_profile(
				_session.get_local_peer_id(),
				_preferences.display_name,
				_appearance_store.get_snapshot(),
			)
			var record := _session.get_peer_record(
				_session.get_local_peer_id()
			)
			if record != null:
				record.profile_authorization = request.duplicate(true)
			broadcast_profile_snapshot.rpc(
				_session.get_local_peer_id(),
				_preferences.display_name,
				_appearance_store.get_snapshot(),
				request,
			)
		elif _session.supports_server_capability(&"profile_v1"):
			confirm_profile_saved.rpc_id(1, request_id)
		elif _session.supports_server_capability(&"chat_v1"):
			_session.update_local_display_name(_preferences.display_name)
	_apply_to_avatar(
		_session.get_local_peer_id() if _session != null else 1,
		_appearance_store.get_snapshot(),
	)
	_apply_local_voice_to_avatar()
	apply_finished.emit(true, "Profile saved.")


@rpc("authority", "call_remote", "reliable", NetworkProfileProtocol.RELIABLE_CHANNEL)
func broadcast_profile_snapshot(
	peer_id: int,
	display_name: String,
	appearance: Dictionary,
	authorization: Dictionary = {},
) -> void:
	if (
		not NetworkProfilePreferences.is_valid_display_name(display_name)
		or not CharacterCustomizationCatalog.validate_snapshot(appearance)
	):
		return
	if not authorization.is_empty():
		var signed := authorization.duplicate(true)
		signed["display_name"] = display_name
		signed["appearance"] = appearance
		var record := _session.get_peer_record(peer_id)
		if (
			record == null
			or record.identity_fingerprint
				!= str(signed.get("sender_fingerprint", ""))
			or not _session.verify_peer_action(
				peer_id,
				"profile_update",
				NetworkProfileProtocol.signature_fields(signed),
				signed.get("sender_signature", PackedByteArray()),
			)
		):
			return
	_session.apply_canonical_profile(peer_id, display_name, appearance)
	_apply_to_avatar(peer_id, appearance)
	profile_snapshot_changed.emit(peer_id, display_name, appearance.duplicate(true))


func _on_peer_authenticated(peer_id: int, _display_name: String) -> void:
	if not _session.is_host():
		return
	for existing_id: int in _session.get_authenticated_peer_ids():
		var record := _session.get_peer_record(existing_id)
		if record == null:
			continue
		broadcast_profile_snapshot.rpc_id(
			peer_id,
			existing_id,
			record.display_name,
			record.appearance_snapshot,
			record.profile_authorization,
		)


func _on_join_authenticated() -> void:
	_apply_to_avatar(
		_session.get_local_peer_id(), _appearance_store.get_snapshot()
	)
	_apply_local_voice_to_avatar()


func _on_peer_removed(_peer_id: int) -> void:
	for request_id: String in _host_pending_apply.keys():
		if int(_host_pending_apply[request_id].get("peer_id", 0)) == _peer_id:
			_host_pending_apply.erase(request_id)
	call_deferred("_refresh_latest_check")


func _on_peer_display_name_changed(
	_peer_id: int,
	_display_name: String,
) -> void:
	call_deferred("_refresh_latest_check")


func _refresh_latest_check() -> void:
	if (
		_latest_check_name.is_empty()
		or _session == null
		or not _session.is_gameplay_session_active()
	):
		return
	var peer := multiplayer.multiplayer_peer
	if (
		_session.is_joined_client()
		and (
			peer == null
			or peer.get_connection_status()
			!= MultiplayerPeer.CONNECTION_CONNECTED
		)
	):
		return
	request_name_check(_latest_check_name)


func _on_session_state_changed(state: NetworkSession.State) -> void:
	if state == NetworkSession.State.INACTIVE:
		_pending_apply.clear()
		_pending_voice_ids.clear()
		_pending_speech_speed_ids.clear()
		_pending_call_ids.clear()
		_host_pending_apply.clear()
		_latest_check_id = ""
		_latest_check_name = ""


func _emit_conflict_result(data: Dictionary) -> void:
	var request_id := str(data["request_id"])
	if request_id != _latest_check_id:
		return
	conflict_result.emit(
		request_id,
		bool(data["has_conflict"]),
		PackedStringArray(data["suggestions"]),
	)


func _make_conflict_result(
	peer_id: int,
	display_name: String,
	request_id: String,
) -> Dictionary:
	var conflict := _name_conflicts(peer_id, display_name)
	return {
		"request_id": request_id,
		"has_conflict": conflict,
		"suggestions": Array(
			_make_suggestions(peer_id, display_name)
			if conflict else PackedStringArray()
		),
	}


func _name_conflicts(peer_id: int, display_name: String) -> bool:
	var normalized := display_name.strip_edges().to_lower()
	for other_id: int in _session.get_authenticated_peer_ids():
		if other_id == peer_id:
			continue
		var record := _session.get_peer_record(other_id)
		if record != null and record.display_name.strip_edges().to_lower() == normalized:
			return true
	return false


func _make_suggestions(peer_id: int, base_name: String) -> PackedStringArray:
	var result := PackedStringArray()
	var suffix := 2
	while result.size() < NetworkProfileProtocol.MAX_SUGGESTIONS and suffix < 1000:
		var suffix_text := " %d" % suffix
		var candidate := base_name.left(
			NetworkProtocol.MAX_DISPLAY_NAME_LENGTH - suffix_text.length()
		) + suffix_text
		if not _name_conflicts(peer_id, candidate) and candidate not in result:
			result.append(candidate)
		suffix += 1
	return result


func _apply_to_avatar(peer_id: int, appearance: Dictionary) -> void:
	if _spawn_service == null:
		return
	var avatar := _spawn_service.get_avatar(peer_id)
	if avatar != null:
		avatar.apply_appearance_snapshot(appearance)


func _apply_local_voice_to_avatar() -> void:
	if _spawn_service == null:
		return
	var local_peer_id := (
		_session.get_local_peer_id() if _session != null else 1
	)
	var avatar := _spawn_service.get_avatar(local_peer_id)
	if avatar != null:
		avatar.apply_animalese_voice_id(_preferences.voice_id)


func _new_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()
