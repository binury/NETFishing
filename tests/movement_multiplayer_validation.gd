extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const TEST_PORT: int = 18141


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
	push_error("Movement multiplayer validation needs host or client mode.")
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
	var player := main.get("_player") as Player
	player.configure_network_remote(true)
	player.apply_authoritative_network_input(_movement_input(1, true))
	await create_timer(2.5).timeout
	player.apply_authoritative_network_input(_movement_input(2, false))
	await create_timer(2.5).timeout
	player.apply_authoritative_network_input(_movement_input(3, false, false))
	var disconnect_deadline: int = Time.get_ticks_msec() + 8000
	while (
		Time.get_ticks_msec() < disconnect_deadline
		and session.is_authenticated_peer(remote_peer_id)
	):
		await process_frame
	assert(not session.is_authenticated_peer(remote_peer_id))
	print("Movement multiplayer host validation: PASS")
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
	var join_deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < join_deadline:
		await process_frame
		if session.state == NetworkSession.State.VERIFYING_SERVER_IDENTITY:
			main.call("_confirm_server_trust")
		if session.is_joined_client() and bool(main.get("_gameplay_started")):
			break
	assert(session.is_joined_client())
	var spawn_service := main.get_node(
		"%PlayerSpawnService"
	) as PlayerSpawnService
	var host_avatar: Player = spawn_service.get_avatar(1)
	assert(host_avatar != null)
	var animation_player := host_avatar.get_node(
		"Visuals/CharacterRig/AnimationPlayer"
	) as AnimationPlayer
	var sprint_dust := host_avatar.get_node("%SprintDust") as SprintDustTrail
	var saw_running: bool = false
	var saw_walking: bool = false
	var saw_animation_advance: bool = false
	var saw_dust: bool = false
	var previous_animation: StringName = &""
	var previous_animation_position: float = -1.0
	var observation_deadline: int = Time.get_ticks_msec() + 7000
	while Time.get_ticks_msec() < observation_deadline:
		await process_frame
		var current_animation: StringName = animation_player.current_animation
		saw_running = saw_running or current_animation.begins_with("running")
		saw_walking = saw_walking or current_animation.begins_with("walking")
		var current_position: float = (
			animation_player.current_animation_position
		)
		if (
			current_animation == previous_animation
			and previous_animation_position >= 0.0
			and absf(current_position - previous_animation_position) > 0.001
		):
			saw_animation_advance = true
		previous_animation = current_animation
		previous_animation_position = current_position
		saw_dust = saw_dust or sprint_dust.get_active_puff_count() > 0
		if saw_running and saw_walking and saw_animation_advance and saw_dust:
			break
	assert(saw_running)
	assert(saw_walking)
	assert(saw_animation_advance)
	assert(saw_dust)
	print("Movement multiplayer client validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()


func _movement_input(
	sequence: int,
	sprinting: bool,
	moving: bool = true,
) -> Dictionary:
	return {
		"sequence": sequence,
		"axis": [0.0, -1.0] if moving else [0.0, 0.0],
		"camera_yaw": 0.0,
		"jump": false,
		"sprint": sprinting,
		"sneak": false,
		"slow_walk": false,
		"sitting": false,
		"casting": false,
		"animation_action": (
			NetworkPlayerAnimationProtocol.make_action_state()
		),
	}


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
