extends SceneTree

const MainScene = preload("res://main/main.tscn")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")


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
	push_error("Fishing multiplayer validation requires host or client mode.")
	quit(1)


func _run_host() -> void:
	var main: Node = await _create_initialized_main()
	assert(bool(main.call("_prepare_private_host")))
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(save_manager.initialize_new_game())
	main.call("_enter_gameplay")
	var session := main.get_node("%NetworkSession") as NetworkSession
	assert(session.set_host_open(true))
	var service := main.get_node(
		"%NetworkFishingService"
	) as NetworkFishingService

	var join_deadline: int = Time.get_ticks_msec() + 20000
	while (
		Time.get_ticks_msec() < join_deadline
		and session.get_authenticated_peer_ids().size() < 2
	):
		await process_frame
	assert(session.get_authenticated_peer_ids().size() == 2)
	var remote_peer_id: int = 0
	for peer_id: int in session.get_authenticated_peer_ids():
		if peer_id != session.get_local_peer_id():
			remote_peer_id = peer_id
			break
	assert(remote_peer_id > 1)
	var spawn_service := main.get_node(
		"%PlayerSpawnService"
	) as PlayerSpawnService
	var remote_avatar: Player = spawn_service.get_avatar(remote_peer_id)
	assert(remote_avatar != null)
	remote_avatar.global_position = Vector3(-0.5, 3.95, 2.1)
	var remote_visuals := remote_avatar.get_node("Visuals") as Node3D
	remote_visuals.rotation.y = PI * 0.5
	session.publish_authoritative_teleport(remote_peer_id)

	var saw_remote_attempt: bool = false
	var remote_presentation: RemoteFishingPresentation
	var attempt_deadline: int = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < attempt_deadline:
		await process_frame
		var attempts: Dictionary = service.get("_attempts")
		for peer_id: int in attempts:
			if peer_id == session.get_local_peer_id():
				continue
			var attempt: NetworkFishingAttempt = attempts[peer_id]
			assert(is_equal_approx(attempt.target.y, 2.51))
			assert(attempt.bobber_position.y <= 2.51 + 0.001)
			var presentations: Dictionary = service.get("_remote_presentations")
			remote_presentation = presentations.get(peer_id)
			assert(remote_presentation != null)
			var remote_bobber := remote_presentation.get(
				"_bobber"
			) as MeshInstance3D
			assert(remote_bobber.visible)
			saw_remote_attempt = true
		if saw_remote_attempt:
			break
	assert(saw_remote_attempt)
	var return_deadline: int = Time.get_ticks_msec() + 5000
	while (
		Time.get_ticks_msec() < return_deadline
		and service.has_peer_attempt(remote_peer_id)
	):
		await process_frame
	assert(not service.has_peer_attempt(remote_peer_id))
	assert(is_instance_valid(remote_presentation))
	assert(remote_presentation.get("_return_tween") != null)

	var completion_deadline: int = Time.get_ticks_msec() + 12000
	while (
		Time.get_ticks_msec() < completion_deadline
		and session.get_authenticated_peer_ids().size() == 2
	):
		await process_frame
	print("Fishing multiplayer host validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	await process_frame
	quit()


func _run_client() -> void:
	var main: Node = await _create_initialized_main()
	main.call("_on_title_join_game_requested", "127.0.0.1:7777")
	var session := main.get_node("%NetworkSession") as NetworkSession
	var joined: bool = false
	var join_deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < join_deadline:
		await process_frame
		if session.state == NetworkSession.State.VERIFYING_SERVER_IDENTITY:
			main.call("_confirm_server_trust")
		if session.is_joined_client() and bool(main.get("_gameplay_started")):
			joined = true
			break
	assert(joined)

	var service := main.get_node(
		"%NetworkFishingService"
	) as NetworkFishingService
	var fishing_spot := main.get_node("%FishingSpot") as FishingSpotType
	var player := main.get("_player") as Player
	var placement_deadline: int = Time.get_ticks_msec() + 5000
	while (
		Time.get_ticks_msec() < placement_deadline
		and player.global_position.distance_to(Vector3(-0.5, 3.95, 2.1))
			> 0.25
	):
		await physics_frame
	assert(player.global_position.distance_to(Vector3(-0.5, 3.95, 2.1)) <= 0.25)
	assert(player.get_facing_direction().dot(Vector3.LEFT) > 0.99)

	fishing_spot.call("_begin_aiming", player)
	assert(player.is_movement_enabled())
	fishing_spot.set("_cast_charge", 0.32)
	fishing_spot.call("_update_cast_charge", 0.0)
	var target: Vector3 = fishing_spot.get("_cast_target")
	assert(fishing_spot.is_target_fishable(target))
	assert(is_equal_approx(target.y, 2.51))
	fishing_spot.call("_confirm_cast")

	var accepted_deadline: int = Time.get_ticks_msec() + 6000
	while (
		Time.get_ticks_msec() < accepted_deadline
		and fishing_spot.state != FishingSpotType.FishingState.WAITING_FOR_BITE
	):
		await process_frame
	assert(fishing_spot.state == FishingSpotType.FishingState.WAITING_FOR_BITE)
	assert(service.has_local_attempt())
	fishing_spot.set("_withdrawal_input_held", true)
	fishing_spot.set("_network_primary_input_held", true)
	service.submit_local_input(true, true)

	var return_deadline: int = Time.get_ticks_msec() + 5000
	while (
		Time.get_ticks_msec() < return_deadline
		and fishing_spot.state != FishingSpotType.FishingState.RETURNING
	):
		await process_frame
	assert(fishing_spot.state == FishingSpotType.FishingState.RETURNING)
	var bobber := fishing_spot.get_node(
		"FishingPresentation/Bobber"
	) as MeshInstance3D
	assert(bobber.visible)

	var ready_deadline: int = Time.get_ticks_msec() + 3000
	while (
		Time.get_ticks_msec() < ready_deadline
		and fishing_spot.state != FishingSpotType.FishingState.READY
	):
		await process_frame
	assert(fishing_spot.state == FishingSpotType.FishingState.READY)
	assert(player.is_movement_enabled())
	assert(not bobber.visible)
	print("Fishing multiplayer client validation: PASS")
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
