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

	var join_deadline: int = Time.get_ticks_msec() + 60000
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
	assert(remote_avatar.bag.get_quantity(&"worms") == 0)
	remote_avatar.global_position = Vector3(-0.5, 3.95, 2.1)
	var remote_visuals := remote_avatar.get_node("Visuals") as Node3D
	remote_visuals.rotation.y = PI * 0.5
	session.publish_authoritative_teleport(remote_peer_id)
	var aiming_deadline: int = Time.get_ticks_msec() + 15000
	while (
		Time.get_ticks_msec() < aiming_deadline
		and int(remote_avatar.get("_fishing_visual_phase"))
			!= Player.FishingVisualPhase.CASTING
	):
		await process_frame
	assert(
		int(remote_avatar.get("_fishing_visual_phase"))
		== Player.FishingVisualPhase.CASTING
	)
	var remote_position_error := (
		remote_avatar.global_position - Vector3(-0.5, 3.95, 2.1)
	)
	remote_position_error.y = 0.0
	assert(
		remote_position_error.length() <= 0.25,
		"remote casting position drifted: %s" % remote_avatar.global_position
	)
	assert(
		remote_avatar.get_facing_direction().dot(Vector3.LEFT) > 0.99,
		"remote casting facing drifted: %s"
		% remote_avatar.get_facing_direction()
	)

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
			assert(attempt.target.is_finite())
			assert(attempt.bobber_position.distance_to(attempt.target) <= 0.001)
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
	assert(
		int(remote_avatar.get("_fishing_visual_phase"))
		in [
			Player.FishingVisualPhase.RELEASE,
			Player.FishingVisualPhase.FISHING,
		]
	)
	var sitting_deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < sitting_deadline and not remote_avatar.is_sitting():
		await process_frame
	assert(remote_avatar.is_sitting())
	var fishing_deadline: int = Time.get_ticks_msec() + 5000
	while (
		Time.get_ticks_msec() < fishing_deadline
		and int(remote_avatar.get("_fishing_visual_phase"))
			!= Player.FishingVisualPhase.FISHING
	):
		await process_frame
	assert(
		int(remote_avatar.get("_fishing_visual_phase"))
		== Player.FishingVisualPhase.FISHING
	)
	var remote_animation_player := remote_avatar.get_node(
		"Visuals/CharacterRig/AnimationPlayer"
	) as AnimationPlayer
	var return_deadline: int = Time.get_ticks_msec() + 5000
	while (
		Time.get_ticks_msec() < return_deadline
		and service.has_peer_attempt(remote_peer_id)
	):
		await process_frame
	assert(not service.has_peer_attempt(remote_peer_id))
	assert(
		int(remote_avatar.get("_fishing_visual_phase"))
		== Player.FishingVisualPhase.RETRACT
	)
	var retract_animation_deadline: int = Time.get_ticks_msec() + 3000
	while (
		Time.get_ticks_msec() < retract_animation_deadline
		and remote_animation_player.current_animation != &"retract_sit"
	):
		await process_frame
	assert(remote_animation_player.current_animation == &"retract_sit")

	print("Fishing multiplayer host validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
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
	var cast_rejections: Array[String] = []
	service.local_cast_rejected.connect(
		func(message: String) -> void:
			cast_rejections.append(message)
	)
	var fishing_spot := main.get_node("%FishingSpot") as FishingSpotType
	var player := main.get("_player") as Player
	var item_catalog := main.get("item_catalog") as ItemCatalog
	var worms: ItemData = item_catalog.get_item_by_id(&"worms")
	if player.bag.get_quantity(&"worms") == 0:
		assert(player.bag.add_item(&"worms", 1))
	assert(player.equip_bait(worms))
	var worms_before_cast: int = player.bag.get_quantity(&"worms")
	var character_animation_player := player.get_node(
		"Visuals/CharacterRig/AnimationPlayer"
	) as AnimationPlayer
	assert(character_animation_player.has_animation(&"retract_sit"))
	var placement_deadline: int = Time.get_ticks_msec() + 5000
	while (
		Time.get_ticks_msec() < placement_deadline
		and player.global_position.distance_to(Vector3(-0.5, 3.95, 2.1))
			> 0.25
	):
		await physics_frame
	assert(player.global_position.distance_to(Vector3(-0.5, 3.95, 2.1)) <= 0.25)
	assert(player.get_facing_direction().dot(Vector3.LEFT) > 0.99)

	player.set_casting_visual()
	assert(
		int(player.get("_fishing_visual_phase"))
		== Player.FishingVisualPhase.CASTING
	)
	for _frame: int in 30:
		await physics_frame
	player.set_fishing_visual(false)
	player.call("_set_sitting", true, true)
	assert(player.is_sitting())
	for _frame: int in 15:
		await physics_frame
	fishing_spot.call("_begin_aiming", player)
	assert(player.is_movement_enabled())
	assert(
		int(player.get("_fishing_visual_phase"))
		== Player.FishingVisualPhase.CASTING
	)
	var cast_charge: float = 0.0
	var target: Vector3 = Vector3.ZERO
	var cast_origin: Vector3 = fishing_spot.get("_cast_origin_position")
	for charge_step: int in range(1, 21):
		var candidate_charge := float(charge_step) / 20.0
		fishing_spot.set("_cast_charge", candidate_charge)
		fishing_spot.call("_update_cast_charge", 0.0)
		var candidate_target: Vector3 = fishing_spot.get("_cast_target")
		var candidate_surface := fishing_spot.get(
			"_aim_surface_sample"
		) as FishingSurfaceSample
		if (
			candidate_surface.is_fishable()
			and fishing_spot.is_cast_path_clear(cast_origin, candidate_target)
		):
			cast_charge = candidate_charge
			target = candidate_target
			break
	assert(cast_charge > 0.0, "no clear fishable test target was found")
	var evidence: Dictionary = fishing_spot.call("_build_network_evidence")
	fishing_spot.set("state", FishingSpotType.FishingState.CASTING)
	player.set_movement_enabled(false)
	player.set_release_visual()
	assert(
		int(player.get("_fishing_visual_phase"))
		== Player.FishingVisualPhase.RELEASE
	)
	assert(
		not service.request_local_cast(
			cast_origin,
			target,
			cast_charge,
			evidence,
		).is_empty()
	)

	var accepted_deadline: int = Time.get_ticks_msec() + 6000
	while (
		Time.get_ticks_msec() < accepted_deadline
		and fishing_spot.state != FishingSpotType.FishingState.WAITING_FOR_BITE
	):
		await process_frame
	assert(
		fishing_spot.state == FishingSpotType.FishingState.WAITING_FOR_BITE,
		(
			"cast acceptance timed out: state=%s local_attempt=%s target=%s "
			+ "rejections=%s"
		) % [
			fishing_spot.state,
			service.has_local_attempt(),
			target,
			cast_rejections,
		]
	)
	assert(service.has_local_attempt())
	assert(player.bag.get_quantity(&"worms") == worms_before_cast - 1)
	var fishing_deadline: int = Time.get_ticks_msec() + 5000
	while (
		Time.get_ticks_msec() < fishing_deadline
		and int(player.get("_fishing_visual_phase"))
			!= Player.FishingVisualPhase.FISHING
	):
		await process_frame
	assert(
		int(player.get("_fishing_visual_phase"))
		== Player.FishingVisualPhase.FISHING
	)
	for _frame: int in 30:
		await physics_frame
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
	assert(
		int(player.get("_fishing_visual_phase"))
		== Player.FishingVisualPhase.RETRACT
	)
	var retract_animation_deadline: int = Time.get_ticks_msec() + 3000
	while (
		Time.get_ticks_msec() < retract_animation_deadline
		and character_animation_player.current_animation != &"retract_sit"
	):
		await process_frame
	assert(character_animation_player.current_animation == &"retract_sit")
	var bobber := fishing_spot.get_node(
		"FishingPresentation/Bobber"
	) as MeshInstance3D
	assert(bobber.visible)
	while not player.is_retract_visual_complete():
		assert(fishing_spot.state == FishingSpotType.FishingState.RETURNING)
		await process_frame

	var ready_deadline: int = Time.get_ticks_msec() + 3000
	while (
		Time.get_ticks_msec() < ready_deadline
		and fishing_spot.state != FishingSpotType.FishingState.READY
	):
		await process_frame
	assert(fishing_spot.state == FishingSpotType.FishingState.READY)
	assert(player.is_movement_enabled())
	assert(not bobber.visible)
	var host_observation_deadline: int = Time.get_ticks_msec() + 2000
	while Time.get_ticks_msec() < host_observation_deadline:
		await process_frame
	print("Fishing multiplayer client validation: PASS")
	var host_completion_deadline: int = Time.get_ticks_msec() + 10000
	while (
		Time.get_ticks_msec() < host_completion_deadline
		and session.is_joined_client()
	):
		await process_frame
	if session.is_joined_client():
		session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
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
