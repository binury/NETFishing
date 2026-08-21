extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const TEST_PORT: int = 18155
const TEST_SEED: int = 86421357


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
	push_error("World layout multiplayer validation needs host or client mode.")
	quit(1)


func _run_host() -> void:
	var main: Node = await _create_initialized_main()
	var session := main.get_node("%NetworkSession") as NetworkSession
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(bool(main.call(
		"_apply_world",
		WorldLayout.STARTER_ISLAND,
		TEST_SEED,
		true,
	)))
	assert(bool(main.call(
		"_prepare_host_world",
		WorldLayout.STARTER_ISLAND,
		TEST_SEED,
	)))
	assert(save_manager.initialize_new_game(
		TEST_SEED,
		WorldLayout.STARTER_ISLAND,
	))
	assert(session.start_private_host(TEST_PORT))
	main.call("_enter_gameplay")
	assert(session.set_host_open(true))
	var remote_peer_id: int = await _wait_for_remote_peer(session)
	assert(remote_peer_id > 1)
	assert(session.peer_supports_capability(
		remote_peer_id,
		NetworkProtocol.WORLD_LAYOUT_CAPABILITY,
	))
	var disconnect_deadline: int = Time.get_ticks_msec() + 12000
	while (
		Time.get_ticks_msec() < disconnect_deadline
		and session.is_authenticated_peer(remote_peer_id)
	):
		await process_frame
	assert(not session.is_authenticated_peer(remote_peer_id))
	print("World layout multiplayer host validation: PASS")
	await _cleanup(main, session)


func _run_client() -> void:
	var main: Node = await _create_initialized_main()
	main.call(
		"_on_title_join_game_requested",
		"127.0.0.1:%d" % TEST_PORT,
	)
	var session := main.get_node("%NetworkSession") as NetworkSession
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if session.state == NetworkSession.State.VERIFYING_SERVER_IDENTITY:
			main.call("_confirm_server_trust")
		if session.is_joined_client() and bool(main.get("_gameplay_started")):
			break
	assert(session.is_joined_client())
	assert(session.supports_server_capability(
		NetworkProtocol.WORLD_LAYOUT_CAPABILITY
	))
	var metadata: Dictionary = session.get_last_server_metadata()
	assert(str(metadata.get("world_layout", "")) == String(
		WorldLayout.STARTER_ISLAND
	))
	assert(int(metadata.get("world_seed", 0)) == TEST_SEED)
	var world := main.get("_test_world") as TestWorld
	assert(world.get_world_layout() == WorldLayout.STARTER_ISLAND)
	assert(world.get_generation_seed() == TEST_SEED)
	assert(world.get_node_or_null("Regions/StarterIslandRegion") != null)
	assert(world.get_fishing_shop() != null)
	assert(world.get_player_storage() != null)
	print("World layout multiplayer client validation: PASS")
	await _cleanup(main, session)


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


func _cleanup(main: Node, session: NetworkSession) -> void:
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()
