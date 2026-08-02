extends SceneTree

const MainScene = preload("res://main/main.tscn")
const TEST_PORT: int = 17983
const INITIAL_HOST_TIME: float = 19.75
const UPDATED_HOST_TIME: float = 20.75
const TIME_TOLERANCE_HOURS: float = 0.05


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
	push_error("World time multiplayer validation needs host or client mode.")
	quit(1)


func _run_host() -> void:
	var main: Node = await _create_initialized_main()
	var session := main.get_node("%NetworkSession") as NetworkSession
	var world_time := main.get_node("%WorldTimeService") as WorldTimeService
	var world_weather := (
		main.get_node("%WorldWeatherService") as WorldWeatherService
	)
	assert(session.start_private_host(TEST_PORT))
	world_time.synchronize_time(INITIAL_HOST_TIME)
	world_weather.apply_authoritative_snapshot(
		WorldWeatherService.Weather.RAINY, 300.0
	)
	assert(session.set_host_open(true))

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
		remote_peer_id, NetworkProtocol.WORLD_TIME_CAPABILITY
	))
	assert(session.peer_supports_capability(
		remote_peer_id, NetworkProtocol.WORLD_WEATHER_CAPABILITY
	))
	assert(world_time.get_phase() == WorldTimeService.Phase.DUSK)

	await create_timer(1.0).timeout
	world_time.synchronize_time(UPDATED_HOST_TIME)
	world_weather.apply_authoritative_snapshot(
		WorldWeatherService.Weather.FOGGY, 300.0
	)
	var disconnect_deadline: int = Time.get_ticks_msec() + 12000
	while (
		Time.get_ticks_msec() < disconnect_deadline
		and session.is_authenticated_peer(remote_peer_id)
	):
		await process_frame
	assert(not session.is_authenticated_peer(remote_peer_id))
	print("World time multiplayer host validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	await process_frame
	quit()


func _run_client() -> void:
	var main: Node = await _create_initialized_main()
	main.call(
		"_on_title_join_game_requested",
		"127.0.0.1:%d" % TEST_PORT,
	)
	var session := main.get_node("%NetworkSession") as NetworkSession
	var world_time := main.get_node("%WorldTimeService") as WorldTimeService
	var world_weather := (
		main.get_node("%WorldWeatherService") as WorldWeatherService
	)
	var join_deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < join_deadline:
		await process_frame
		if session.state == NetworkSession.State.VERIFYING_SERVER_IDENTITY:
			main.call("_confirm_server_trust")
		if session.is_joined_client() and bool(main.get("_gameplay_started")):
			break
	assert(session.is_joined_client())
	assert(session.supports_server_capability(
		NetworkProtocol.WORLD_TIME_CAPABILITY
	))
	assert(session.supports_server_capability(
		NetworkProtocol.WORLD_WEATHER_CAPABILITY
	))

	var initial_deadline: int = Time.get_ticks_msec() + 8000
	while (
		Time.get_ticks_msec() < initial_deadline
		and _wrapped_time_difference(
			world_time.get_time_hours(), INITIAL_HOST_TIME
		) > TIME_TOLERANCE_HOURS
	):
		await process_frame
	assert(_wrapped_time_difference(
		world_time.get_time_hours(), INITIAL_HOST_TIME
	) <= TIME_TOLERANCE_HOURS)
	assert(world_time.get_phase() == WorldTimeService.Phase.DUSK)
	var weather_deadline: int = Time.get_ticks_msec() + 8000
	while (
		Time.get_ticks_msec() < weather_deadline
		and not world_weather.is_raining()
	):
		await process_frame
	assert(world_weather.is_raining())
	var game_ui := main.get_node("%GameUI") as CanvasLayer
	var chat_ui := game_ui.get_node("%ChatUI") as Control
	var clock_panel := chat_ui.get_node("WorldClockPanel") as PanelContainer
	var clock_label := clock_panel.get_node("WorldClockLabel") as Label
	var weather_icon := chat_ui.get_node("WorldWeatherIcon") as WeatherIcon
	var chat_panel := chat_ui.get_node("ChatPanel") as PanelContainer
	assert(clock_panel.visible)
	assert(clock_label.text == world_time.get_clock_text())
	assert(clock_label.text.ends_with(" pm"))
	assert(weather_icon.visible)
	assert(weather_icon.get_weather() == WorldWeatherService.Weather.RAINY)
	assert(clock_panel.position.y + clock_panel.size.y < chat_panel.position.y)

	var update_deadline: int = Time.get_ticks_msec() + 10000
	while (
		Time.get_ticks_msec() < update_deadline
		and _wrapped_time_difference(
			world_time.get_time_hours(), UPDATED_HOST_TIME
		) > TIME_TOLERANCE_HOURS
	):
		await process_frame
	assert(_wrapped_time_difference(
		world_time.get_time_hours(), UPDATED_HOST_TIME
	) <= TIME_TOLERANCE_HOURS)
	assert(world_time.get_phase() == WorldTimeService.Phase.NIGHT)
	assert(clock_label.text == world_time.get_clock_text())
	var fog_deadline: int = Time.get_ticks_msec() + 8000
	while (
		Time.get_ticks_msec() < fog_deadline
		and not world_weather.is_foggy()
	):
		await process_frame
	assert(world_weather.is_foggy())
	assert(weather_icon.get_weather() == WorldWeatherService.Weather.FOGGY)
	chat_ui.call("set_dock_right", true)
	await process_frame
	assert(clock_panel.position.x > 1000.0)
	assert(weather_icon.position.x < clock_panel.position.x)
	chat_ui.call("set_dock_right", false)
	await process_frame
	assert(clock_panel.position.x < 20.0)
	assert(weather_icon.position.x > clock_panel.position.x)
	print("World time multiplayer client validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	await process_frame
	quit()


func _create_initialized_main() -> Node:
	root.size = Vector2i(1280, 720)
	var main := MainScene.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame
	if not bool(main.get("_application_initialized")):
		main.call("_activate_selected_data_path", "", true)
	for _frame: int in 8:
		await process_frame
	assert(bool(main.get("_application_initialized")))
	return main


func _wrapped_time_difference(left: float, right: float) -> float:
	var direct: float = absf(left - right)
	return minf(direct, WorldTimeService.HOURS_PER_DAY - direct)
