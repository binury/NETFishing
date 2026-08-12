extends SceneTree

const MainScene = preload("res://main/main.tscn")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	assert(bool(main.call("_prepare_private_host")))
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(save_manager.initialize_new_game())
	main.call("_enter_gameplay")
	for _frame: int in 8:
		await process_frame

	var session := main.get_node("%NetworkSession") as NetworkSession
	var service := main.get_node(
		"%NetworkFishingService"
	) as NetworkFishingService
	var fishing_spot := main.get_node("%FishingSpot") as FishingSpotType
	var player := main.get("_player") as Player
	assert(session.is_host())
	assert(not session.is_open_host())
	assert(service != null and fishing_spot != null and player != null)
	assert(player.hotbar.get_selected_item_id() == &"basic_fishing_rod")
	var pond := main.get_node(
		"TestWorld/Regions/StarterIslandRegion/WaterBodies/Pond"
	) as Node3D
	var pond_region := pond.get_node("FishingRegion") as FishableWaterRegion
	assert(pond != null and pond_region != null)
	var pond_surface_y: float = pond_region.get_surface_height()

	player.global_position = pond.global_position + Vector3(8.9, 1.44, 0.0)
	var visuals := player.get_node("Visuals") as Node3D
	visuals.rotation.y = PI * 0.5
	for _frame: int in 4:
		await physics_frame
	assert(player.get_facing_direction().dot(Vector3.LEFT) > 0.99)

	fishing_spot.call("_begin_aiming", player)
	assert(fishing_spot.state == FishingSpotType.FishingState.AIMING_CAST)
	assert(player.is_movement_enabled())
	fishing_spot.set("_cast_charge", 0.32)
	fishing_spot.call("_update_cast_charge", 0.0)
	var aimed_target: Vector3 = fishing_spot.get("_cast_target")
	assert(aimed_target.x < player.global_position.x - 0.85)
	assert(is_equal_approx(aimed_target.y, pond_surface_y))
	assert(fishing_spot.is_target_fishable(aimed_target))
	fishing_spot.call("_confirm_cast")
	assert(fishing_spot.state == FishingSpotType.FishingState.CASTING)
	assert(not player.is_movement_enabled())

	var wait_deadline: int = Time.get_ticks_msec() + 4000
	while (
		Time.get_ticks_msec() < wait_deadline
		and fishing_spot.state != FishingSpotType.FishingState.WAITING_FOR_BITE
	):
		await process_frame
	assert(fishing_spot.state == FishingSpotType.FishingState.WAITING_FOR_BITE)
	assert(service.has_local_attempt())
	var attempts: Dictionary = service.get("_attempts")
	var attempt: NetworkFishingAttempt = attempts.get(session.get_local_peer_id())
	assert(attempt != null)
	assert(is_equal_approx(attempt.target.y, pond_surface_y))
	assert(attempt.bobber_position.is_equal_approx(attempt.target))

	fishing_spot.set("_withdrawal_input_held", true)
	fishing_spot.set("_network_primary_input_held", true)
	service.submit_local_input(true, true)
	var return_deadline: int = Time.get_ticks_msec() + 4000
	while (
		Time.get_ticks_msec() < return_deadline
		and fishing_spot.state != FishingSpotType.FishingState.RETURNING
	):
		await process_frame
	assert(fishing_spot.state == FishingSpotType.FishingState.RETURNING)
	assert(not service.has_local_attempt())
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

	# A private host rolls and retains the authoritative catch before the fight
	# so its quality can scale the same barriers clients receive in snapshots.
	fishing_spot.call("_begin_aiming", player)
	fishing_spot.set("_cast_charge", 0.32)
	fishing_spot.call("_update_cast_charge", 0.0)
	fishing_spot.call("_confirm_cast")
	var second_wait_deadline: int = Time.get_ticks_msec() + 4000
	while (
		Time.get_ticks_msec() < second_wait_deadline
		and fishing_spot.state != FishingSpotType.FishingState.WAITING_FOR_BITE
	):
		await process_frame
	assert(fishing_spot.state == FishingSpotType.FishingState.WAITING_FOR_BITE)
	attempts = service.get("_attempts")
	attempt = attempts.get(session.get_local_peer_id())
	assert(attempt != null)
	service.call("_start_bite", attempt)
	await process_frame
	assert(attempt.phase == NetworkFishingAttempt.Phase.FIGHTING)
	var catalog: FishPool = main.get("fish_catalog") as FishPool
	assert(catalog != null)
	var fish: FishData = catalog.get_fish_by_id(attempt.fish_id)
	var fish_catch := FishCatch.from_network_dict(
		attempt.catch_payload,
		fish,
	)
	assert(fish_catch != null and fish_catch.is_valid())
	var reference_controller := CatchController.new()
	root.add_child(reference_controller)
	reference_controller.start_authoritative_encounter(
		fish.catch_profile,
		attempt.reel_speed,
		attempt.barrier_damage,
		attempt.encounter_seed,
		fish_catch.quality,
		int(fish.rarity),
		fish.get_weight_percentile(fish_catch.weight_lb),
	)
	var quality_barriers: Array = attempt.controller.get("_barriers")
	var reference_barriers: Array = reference_controller.get("_barriers")
	assert(quality_barriers.size() == reference_barriers.size())
	for barrier_index: int in quality_barriers.size():
		var quality_barrier: RefCounted = quality_barriers[barrier_index]
		var reference_barrier: RefCounted = reference_barriers[barrier_index]
		assert(
			is_equal_approx(
				float(quality_barrier.get("position")),
				float(reference_barrier.get("position")),
			)
		)
		assert(
			int(quality_barrier.get("maximum_health"))
			== int(reference_barrier.get("maximum_health"))
		)
		assert(
			int(quality_barrier.get("maximum_health"))
			>= FishQuality.BARRIER_HEALTH_MINIMUMS[fish_catch.quality]
		)
		assert(
			int(quality_barrier.get("maximum_health"))
			<= FishQuality.BARRIER_HEALTH_MAXIMUMS[fish_catch.quality]
		)
	reference_controller.queue_free()
	service.call("_cancel_attempt", session.get_local_peer_id(), "")
	await process_frame
	assert(not service.has_local_attempt())

	print("Fishing authority validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()
