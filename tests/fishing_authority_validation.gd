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

	player.global_position = Vector3(-0.5, 3.95, 2.1)
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
	assert(aimed_target.x < -1.35)
	assert(is_equal_approx(aimed_target.y, 2.51))
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
	assert(is_equal_approx(attempt.target.y, 2.51))
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

	print("Fishing authority validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	await process_frame
	quit()
