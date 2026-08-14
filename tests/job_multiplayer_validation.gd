extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const TEST_PORT: int = 18139


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
	push_error("Job multiplayer validation needs host or client mode.")
	quit(1)


func _run_host() -> void:
	var main: Node = await _create_initialized_main()
	var session := main.get_node("%NetworkSession") as NetworkSession
	var jobs := main.get_node("%PlayerJobService") as PlayerJobService
	assert(session.start_dedicated_host(TEST_PORT, 8, "127.0.0.1"))
	jobs.begin_progression_session()
	await process_frame
	assert(session.set_host_open(true))
	assert(session.is_dedicated_host())
	var host_board: Dictionary = jobs.get_host_board_network_data()
	assert(PlayerJobService.validate_board(host_board))

	var remote_peer_id: int = 0
	var join_deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < join_deadline and remote_peer_id == 0:
		await process_frame
		for peer_id: int in session.get_authenticated_peer_ids():
			if peer_id != session.get_local_peer_id():
				remote_peer_id = peer_id
				break
	assert(remote_peer_id > 1)
	assert(session.peer_supports_capability(
		remote_peer_id, NetworkProtocol.JOBS_CAPABILITY
	))

	var disconnect_deadline: int = Time.get_ticks_msec() + 12000
	while (
		Time.get_ticks_msec() < disconnect_deadline
		and session.is_authenticated_peer(remote_peer_id)
	):
		await process_frame
	assert(not session.is_authenticated_peer(remote_peer_id))
	print("Job multiplayer host validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()


func _run_client() -> void:
	var main: Node = await _create_initialized_main()
	main.call(
		"_on_title_join_game_requested",
		"127.0.0.1:%d" % TEST_PORT,
	)
	var session := main.get_node("%NetworkSession") as NetworkSession
	var jobs := main.get_node("%PlayerJobService") as PlayerJobService
	var weather := main.get_node("%WorldWeatherService") as WorldWeatherService
	var join_deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < join_deadline:
		await process_frame
		if session.state == NetworkSession.State.VERIFYING_SERVER_IDENTITY:
			main.call("_confirm_server_trust")
		if (
			session.is_joined_client()
			and bool(main.get("_gameplay_started"))
			and not jobs.get_plan_id().is_empty()
		):
			break
	assert(session.is_joined_client())
	assert(session.supports_server_capability(NetworkProtocol.JOBS_CAPABILITY))
	assert(not jobs.get_plan_id().is_empty())
	assert(jobs.get_daily_jobs().size() == JobCatalog.DAILY_JOB_COUNT)
	assert(jobs.get_forecast().size() == JobCatalog.WEATHER_SEGMENT_COUNT)
	var preserved_plan_id: String = jobs.get_plan_id()
	jobs.clear_remote_board()
	assert(not jobs.has_active_board())
	assert(jobs.get_plan_id() == preserved_plan_id)
	var retry_deadline: int = Time.get_ticks_msec() + 5000
	while (
		Time.get_ticks_msec() < retry_deadline
		and not jobs.has_active_board()
	):
		await process_frame
	assert(jobs.has_active_board())
	assert(jobs.get_plan_id() == preserved_plan_id)
	assert(jobs.get_daily_jobs().size() == JobCatalog.DAILY_JOB_COUNT)
	assert(jobs.get_forecast().size() == JobCatalog.WEATHER_SEGMENT_COUNT)
	assert(weather.get_daily_plan_id().is_empty())
	var game_ui := main.get_node("%GameUI") as GameUI
	var player_menu := game_ui.get("_player_menu") as PlayerMenu
	player_menu.call("_show_section_immediate", PlayerMenu.Section.NET)
	assert((player_menu.get_node("%TheNetPage") as TheNetPage).visible)
	print("Job multiplayer client validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()


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
