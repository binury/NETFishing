extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const TEST_PORT: int = 18152
const PREJOIN_MESSAGE: String = "private prejoin message"
const LIVE_MESSAGE: String = "live message after join"


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
	push_error("Chat privacy validation needs host or client mode.")
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
	var chat_service := main.get_node(
		"%NetworkChatService"
	) as NetworkChatService
	assert(chat_service.send_local_message(PREJOIN_MESSAGE))
	var remote_peer_id: int = await _wait_for_remote_peer(session)
	assert(remote_peer_id > 1)
	await create_timer(1.0).timeout
	assert(chat_service.send_local_message(LIVE_MESSAGE))
	var disconnect_deadline: int = Time.get_ticks_msec() + 8000
	while (
		Time.get_ticks_msec() < disconnect_deadline
		and session.is_authenticated_peer(remote_peer_id)
	):
		await process_frame
	assert(not session.is_authenticated_peer(remote_peer_id))
	print("Chat privacy multiplayer host validation: PASS")
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
	var chat_service := main.get_node(
		"%NetworkChatService"
	) as NetworkChatService
	await create_timer(0.5).timeout
	assert(not _history_contains(chat_service, PREJOIN_MESSAGE))
	var live_deadline: int = Time.get_ticks_msec() + 8000
	while (
		Time.get_ticks_msec() < live_deadline
		and not _history_contains(chat_service, LIVE_MESSAGE)
	):
		await process_frame
	assert(_history_contains(chat_service, LIVE_MESSAGE))
	assert(not _history_contains(chat_service, PREJOIN_MESSAGE))
	print("Chat privacy multiplayer client validation: PASS")
	await _session_cleanup(main, session)


func _history_contains(service: NetworkChatService, body: String) -> bool:
	return service.get_history().any(
		func(message: Dictionary) -> bool:
			return str(message.get("body", "")) == body
	)


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
