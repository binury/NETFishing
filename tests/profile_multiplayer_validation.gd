extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const TEST_PORT: int = 18144


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("host"):
		await _run_host()
		return
	if arguments.has("client"):
		await _run_client()
		return
	push_error("Profile multiplayer validation needs host or client mode.")
	quit(1)


func _run_host() -> void:
	var main: Node = await _create_initialized_main()
	var session := main.get_node("%NetworkSession") as NetworkSession
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(session.start_private_host(TEST_PORT))
	assert(save_manager.initialize_new_game())
	main.call("_enter_gameplay")
	for _frame: int in 4:
		await physics_frame
	assert(session.set_host_open(true))
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
		service.get_persisted_voice_id(),
		service.get_persisted_speech_speed_id(),
		service.get_persisted_call_id(),
	))
	var apply_deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < apply_deadline and apply_results.is_empty():
		await process_frame
	assert(not apply_results.is_empty())
	assert(bool(apply_results[0][0]))
	assert(service.get_persisted_appearance() == changed)
	assert(Dictionary(session.get("_local_appearance_snapshot")) == changed)
	await create_timer(0.75).timeout
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
