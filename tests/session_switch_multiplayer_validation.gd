extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const FIRST_HOST_PORT: int = 18142
const SECOND_HOST_PORT: int = 18143
const WAIT_SECONDS: int = 20


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("first_host"):
		await _run_host(FIRST_HOST_PORT, "first")
		return
	if arguments.has("second_host"):
		await _run_host(SECOND_HOST_PORT, "second")
		return
	if arguments.has("client"):
		await _run_client()
		return
	push_error(
		"Session switch multiplayer validation needs first_host, "
		+ "second_host, or client mode."
	)
	quit(1)


func _run_host(port: int, label: String) -> void:
	var main: Node = await _create_initialized_main()
	var session := main.get_node("%NetworkSession") as NetworkSession
	assert(session.start_dedicated_host(port, 8, "127.0.0.1"))
	assert(session.set_host_open(true))
	var remote_peer_id: int = await _wait_for_remote_peer(session)
	assert(remote_peer_id > 1)
	var disconnect_deadline: int = (
		Time.get_ticks_msec() + WAIT_SECONDS * 1000
	)
	while (
		Time.get_ticks_msec() < disconnect_deadline
		and session.is_authenticated_peer(remote_peer_id)
	):
		await process_frame
	assert(not session.is_authenticated_peer(remote_peer_id))
	print("Session switch %s host validation: PASS" % label)
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()


func _run_client() -> void:
	var main: Node = await _create_initialized_main()
	var session := main.get_node("%NetworkSession") as NetworkSession
	main.call(
		"_on_title_join_game_requested",
		"127.0.0.1:%d" % FIRST_HOST_PORT,
	)
	await _wait_for_join(main, session, FIRST_HOST_PORT)
	var game_ui := main.get("_game_ui") as GameUI
	var pause_menu := game_ui.get_pause_menu()
	var join_page := pause_menu.get_node("%JoinGamePage") as JoinGamePage
	var discovery := main.get_node("%DiscoveryClient") as DiscoveryClient
	pause_menu.show()
	(pause_menu.get_node("%RootPage") as Control).hide()
	join_page.open_page()
	join_page.set("_mode", JoinGamePage.Mode.DISCOVER)
	var rooms: Array[Dictionary] = [{
		"room_id": "deferred-public-room",
		"room_name": "Deferred public room",
		"address": "127.0.0.1",
		"port": SECOND_HOST_PORT,
		"current_players": 0,
		"max_players": 8,
	}]
	join_page.set("_discovery_rooms", rooms)
	join_page.set("_selected_discovery_index", 0)
	assert(bool(join_page.get("_gameplay_context")))
	assert(
		str(
			(join_page.call("_selected_discovery_room") as Dictionary).get(
				"room_id", ""
			)
		) == "deferred-public-room"
	)
	join_page.call("_request_join")
	assert(not bool(discovery.get("_join_request_in_flight")))
	assert(
		str(
			(join_page.get("_pending_confirmation_room") as Dictionary).get(
				"room_id", ""
			)
		) == "deferred-public-room"
	)
	assert(
		int(pause_menu.get("_confirmation_action"))
		== PauseMenu.ConfirmationAction.JOIN_ANOTHER
	)
	join_page.cancel_pending_join_confirmation()
	(pause_menu.get_node("%ConfirmationPage") as Control).hide()
	pause_menu.set("_confirmation_action", PauseMenu.ConfirmationAction.NONE)
	pause_menu.set("_confirmation_returns_to_join_game", false)
	join_page.open_page("127.0.0.1:%d" % SECOND_HOST_PORT)
	join_page.set("_mode", JoinGamePage.Mode.DIRECT)
	join_page.call("_request_join")
	assert(
		int(pause_menu.get("_confirmation_action"))
		== PauseMenu.ConfirmationAction.JOIN_ANOTHER
	)
	assert(not join_page.visible)
	assert((pause_menu.get_node("%ConfirmationPage") as Control).visible)
	pause_menu.call(
		"_finish_confirmation_accept",
		PauseMenu.ConfirmationAction.JOIN_ANOTHER,
	)
	await _wait_for_join(main, session, SECOND_HOST_PORT)
	assert(bool(main.get("_gameplay_started")))
	print("Session switch multiplayer client validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()


func _wait_for_join(
	main: Node,
	session: NetworkSession,
	expected_port: int,
) -> void:
	var deadline: int = Time.get_ticks_msec() + WAIT_SECONDS * 1000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if session.state == NetworkSession.State.VERIFYING_SERVER_IDENTITY:
			main.call("_confirm_server_trust")
		var endpoint: ConnectionEndpoint = session.get_current_endpoint()
		if (
			session.is_joined_client()
			and bool(main.get("_gameplay_started"))
			and endpoint != null
			and endpoint.port == expected_port
		):
			return
	assert(false, "Timed out joining UDP %d." % expected_port)


func _wait_for_remote_peer(session: NetworkSession) -> int:
	var deadline: int = Time.get_ticks_msec() + WAIT_SECONDS * 1000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		for peer_id: int in session.get_authenticated_peer_ids():
			if peer_id > 1:
				return peer_id
	return 0


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
