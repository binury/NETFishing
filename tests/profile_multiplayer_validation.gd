extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const AnimaleseVoiceType = preload("res://ui/animalese_voice.gd")
const TEST_PORT: int = 18144
const HOST_HISTORY_MESSAGE: String = "silent history replay"
const HOST_VOICE_MESSAGE: String = "remote voice playback"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_voice_distance_attenuation()
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("host"):
		await _run_host()
		return
	if arguments.has("client"):
		await _run_client()
		return
	push_error("Profile multiplayer validation needs host or client mode.")
	quit(1)


func _validate_voice_distance_attenuation() -> void:
	assert(is_zero_approx(
		ChatUI.animalese_volume_offset_db_for_distance(0.0)
	))
	assert(is_zero_approx(
		ChatUI.animalese_volume_offset_db_for_distance(4.0)
	))
	var middle_distance_volume := (
		ChatUI.animalese_volume_offset_db_for_distance(14.0)
	)
	assert(middle_distance_volume < 0.0)
	assert(middle_distance_volume > -80.0)
	assert(is_equal_approx(
		ChatUI.animalese_volume_offset_db_for_distance(24.0),
		-80.0,
	))


func _run_host() -> void:
	var main: Node = await _create_initialized_main()
	var session := main.get_node("%NetworkSession") as NetworkSession
	var profile := main.get_node(
		"%NetworkProfilePreferences"
	) as NetworkProfilePreferences
	assert(profile.set_profile_identity(
		profile.display_name,
		"deep",
		profile.speech_speed_id,
		profile.call_id,
		"robot",
	))
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(session.start_private_host(TEST_PORT))
	var local_avatar := main.get_node("%PlayerSpawnService").get_avatar(
		1
	) as Player
	assert(local_avatar != null)
	assert(local_avatar.get_animalese_voice_id() == "deep")
	assert(local_avatar.get_animalese_sample_set_id() == "robot")
	assert(save_manager.initialize_new_game())
	main.call("_enter_gameplay")
	for _frame: int in 4:
		await physics_frame
	assert(session.set_host_open(true))
	var chat_service := main.get_node(
		"%NetworkChatService"
	) as NetworkChatService
	assert(chat_service.send_local_message(
		HOST_HISTORY_MESSAGE,
		profile.voice_id,
		profile.sample_set_id,
	))
	var voice_messages: Array[Dictionary] = []
	chat_service.message_received.connect(func(message: Dictionary) -> void:
		if str(message.get("body", "")) == "voice profile sync":
			voice_messages.append(message)
	)
	var remote_peer_id: int = await _wait_for_remote_peer(session)
	assert(remote_peer_id > 1)
	var record := session.get_peer_record(remote_peer_id)
	assert(record != null)
	assert(
		NetworkProtocol.APPEARANCE_PREVIEW_CAPABILITY
		in record.capability_flags
	)
	var original: Dictionary = record.appearance_snapshot.duplicate(true)
	var changed: Dictionary = _changed_appearance(original)
	assert(changed != original)
	await _wait_for_remote_appearance(session, remote_peer_id, changed)
	await _wait_for_remote_appearance(session, remote_peer_id, original)
	await _wait_for_remote_appearance(session, remote_peer_id, changed)
	var avatar := main.get_node("%PlayerSpawnService").get_avatar(
		remote_peer_id
	) as Player
	assert(avatar != null)
	assert(avatar.appearance_snapshot == changed)
	assert(record.display_name != "NetworkProfileService")
	assert(chat_service.send_local_message(
		HOST_VOICE_MESSAGE,
		profile.voice_id,
		profile.sample_set_id,
	))
	var voice_message_deadline: int = Time.get_ticks_msec() + 8000
	while (
		Time.get_ticks_msec() < voice_message_deadline
		and voice_messages.is_empty()
	):
		await process_frame
	assert(not voice_messages.is_empty())
	assert(str(voice_messages[0].get("voice_id", "")) == "deep")
	assert(str(voice_messages[0].get("sample_set_id", "")) == "robot")
	var disconnect_deadline: int = Time.get_ticks_msec() + 8000
	while (
		Time.get_ticks_msec() < disconnect_deadline
		and session.is_authenticated_peer(remote_peer_id)
	):
		await process_frame
	assert(not session.is_authenticated_peer(remote_peer_id))
	print("Profile multiplayer host validation: PASS")
	await _session_cleanup(main, session)


func _run_client() -> void:
	var main: Node = await _create_initialized_main()
	var chat_ui := main.get_node("%GameUI").get_node("%ChatUI") as ChatUI
	var animalese := chat_ui.get("_animalese_voice") as AnimaleseVoiceType
	assert(animalese != null)
	var remote_voice_samples: Array[String] = []
	animalese.character_sample_played.connect(
		func(sample_set_id: String, _character: String) -> void:
			remote_voice_samples.append(sample_set_id)
	)
	main.call("_on_title_join_game_requested", "127.0.0.1:%d" % TEST_PORT)
	var session := main.get_node("%NetworkSession") as NetworkSession
	var join_deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < join_deadline:
		await process_frame
		if session.state == NetworkSession.State.VERIFYING_SERVER_IDENTITY:
			main.call("_confirm_server_trust")
		if session.is_joined_client() and bool(main.get("_gameplay_started")):
			break
	assert(session.is_joined_client())
	assert(session.supports_server_capability(
		NetworkProtocol.APPEARANCE_PREVIEW_CAPABILITY
	))
	var chat_service := main.get_node(
		"%NetworkChatService"
	) as NetworkChatService
	# Player-hosted rooms deliberately send no prior scrollback to joining or
	# reconnecting clients. Live messages sent after authentication still work.
	await create_timer(0.5).timeout
	assert(not chat_service.get_history().any(
		func(message: Dictionary) -> bool:
			return str(message.get("body", "")) == HOST_HISTORY_MESSAGE
	))
	assert(remote_voice_samples.is_empty())
	var service := main.get_node(
		"%NetworkProfileService"
	) as NetworkProfileService
	var original: Dictionary = service.get_persisted_appearance()
	var changed: Dictionary = _changed_appearance(original)
	assert(service.preview_appearance(changed))
	await create_timer(0.75).timeout
	service.restore_persisted_appearance()
	await create_timer(0.75).timeout
	assert(service.preview_appearance(changed))
	await create_timer(0.75).timeout
	var apply_results: Array = []
	service.apply_finished.connect(func(accepted: bool, message: String) -> void:
		apply_results.append([accepted, message])
	)
	assert(service.apply_profile(
		service.get_persisted_name(),
		changed,
		true,
		"deep",
		service.get_persisted_speech_speed_id(),
		service.get_persisted_call_id(),
		"robot",
	))
	var apply_deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < apply_deadline and apply_results.is_empty():
		await process_frame
	assert(not apply_results.is_empty())
	assert(bool(apply_results[0][0]))
	assert(service.get_persisted_appearance() == changed)
	assert(service.get_persisted_voice_id() == "deep")
	assert(service.get_persisted_sample_set_id() == "robot")
	assert(Dictionary(session.get("_local_appearance_snapshot")) == changed)
	var player := main.get_node("%PlayerSpawnService").get_local_player() as Player
	assert(player.get_animalese_voice_id() == "deep")
	assert(player.get_animalese_sample_set_id() == "robot")
	var host_voice_messages: Array[Dictionary] = []
	for message: Dictionary in chat_service.get_history():
		if str(message.get("body", "")) == HOST_VOICE_MESSAGE:
			host_voice_messages.append(message)
	var host_voice_deadline: int = Time.get_ticks_msec() + 8000
	while (
		Time.get_ticks_msec() < host_voice_deadline
		and (
			host_voice_messages.is_empty()
			or remote_voice_samples.is_empty()
		)
	):
		await process_frame
		for message: Dictionary in chat_service.get_history():
			if (
				str(message.get("body", "")) == HOST_VOICE_MESSAGE
				and message not in host_voice_messages
			):
				host_voice_messages.append(message)
	assert(not host_voice_messages.is_empty())
	assert(str(host_voice_messages[0].get("voice_id", "")) == "deep")
	assert(str(host_voice_messages[0].get("sample_set_id", "")) == "robot")
	assert(remote_voice_samples.has("robot"))
	var local_confirmations: Array[Dictionary] = []
	chat_service.local_message_confirmed.connect(
		func(message: Dictionary) -> void:
			if str(message.get("body", "")) == "voice profile sync":
				local_confirmations.append(message)
	)
	assert(chat_service.send_local_message(
		"voice profile sync",
		service.get_persisted_voice_id(),
		service.get_persisted_sample_set_id(),
	))
	var confirmation_deadline: int = Time.get_ticks_msec() + 8000
	while (
		Time.get_ticks_msec() < confirmation_deadline
		and local_confirmations.is_empty()
	):
		await process_frame
	assert(not local_confirmations.is_empty())
	assert(str(local_confirmations[0].get("voice_id", "")) == "deep")
	assert(str(local_confirmations[0].get("sample_set_id", "")) == "robot")
	print("Profile multiplayer client validation: PASS")
	await _session_cleanup(main, session)


func _changed_appearance(original: Dictionary) -> Dictionary:
	var changed := original.duplicate(true)
	for category_id: String in CharacterCustomizationCatalog.CATEGORY_IDS:
		if category_id in CharacterCustomizationCatalog.FUR_STYLE_IDS:
			continue
		var options: Array = CharacterCustomizationCatalog.options_for(category_id)
		for option: Dictionary in options:
			var option_id: Variant = option.get("id")
			if option_id != changed.get(category_id):
				changed[category_id] = option_id
				if CharacterCustomizationCatalog.validate_snapshot(changed):
					return changed
				changed[category_id] = original.get(category_id)
	assert(false, "No alternate appearance option is available.")
	return changed


func _wait_for_remote_appearance(
	session: NetworkSession,
	peer_id: int,
	expected: Dictionary,
) -> void:
	var deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var record := session.get_peer_record(peer_id)
		if record != null and record.appearance_snapshot == expected:
			return
	assert(false, "Timed out waiting for a remote appearance update.")


func _create_initialized_main() -> Node:
	root.size = Vector2i(1280, 720)
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame
	if not bool(main.get("_application_initialized")):
		main.call("_activate_selected_data_path", "", true)
	for _frame: int in 8:
		await process_frame
	assert(bool(main.get("_application_initialized")))
	return main


func _wait_for_remote_peer(session: NetworkSession) -> int:
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		for peer_id: int in session.get_authenticated_peer_ids():
			if peer_id != session.get_local_peer_id():
				return peer_id
	return 0


func _session_cleanup(main: Node, session: NetworkSession) -> void:
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()
