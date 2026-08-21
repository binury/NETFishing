extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const TEST_PORT: int = 18142


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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

	var session := main.get_node("%NetworkSession") as NetworkSession
	assert(session.start_private_host(TEST_PORT))
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(save_manager.initialize_new_game())
	main.call("_enter_gameplay")
	for _frame: int in 8:
		await process_frame

	var player := main.get("_player") as Player
	var fishing_spot := main.get_node("%FishingSpot") as FishingSpot
	var catalog := main.get("fish_catalog") as FishPool
	assert(player != null and fishing_spot != null and catalog != null)
	fishing_spot.minimum_showcase_duration = 0.15
	assert(player.bag.add_item(&"crab_net"))
	assert(player.hotbar.assign_item(0, &"crab_net"))
	assert(player.hotbar.select_slot(0))
	await process_frame
	assert(player.hotbar.get_selected_item_id() == &"crab_net")
	assert(bool(player.get("_active_item_is_net")))

	var crab: FishData = catalog.get_fish_by_id(&"crab_brown")
	assert(crab != null and crab.is_selectable())
	var crab_catch := FishCatch.new()
	crab_catch.fish = crab
	crab_catch.fish_id = crab.id
	crab_catch.weight_lb = crab.get_minimum_weight()
	crab_catch.display_scale = crab.get_display_scale_for_weight(
		crab_catch.weight_lb
	)
	crab_catch.sale_value = crab.get_sale_value_for_weight(
		crab_catch.weight_lb
	)
	crab_catch.ensure_identity()
	player.inventory.add_catch(crab_catch)
	player.collection_log.mark_discovered(crab.id)

	assert(fishing_spot.present_external_catch(crab_catch))
	assert(fishing_spot.state == FishingSpot.FishingState.SHOWING_CATCH)
	assert(not player.is_movement_enabled())
	# Network attempt cleanup may restore the base movement flag before the
	# presentation finishes. The showcase owns a separate local-input lock.
	player.set_movement_enabled(true)
	assert(not bool(player.call("_is_movement_input_enabled")))
	assert(not bool(player.call("_is_camera_input_enabled")))
	Input.action_release("fish_primary")
	await process_frame
	assert(not bool(fishing_spot.get("_put_away_press_armed")))

	var pocket_event := InputEventAction.new()
	pocket_event.action = &"fish_primary"
	pocket_event.pressed = true
	Input.parse_input_event(pocket_event)
	await process_frame
	assert(fishing_spot.get("_pending_catch") == crab_catch)
	Input.action_release("fish_primary")
	await create_timer(0.2).timeout
	await process_frame
	assert(bool(fishing_spot.get("_put_away_press_armed")))
	Input.parse_input_event(pocket_event)
	await process_frame
	assert(fishing_spot.get("_pending_catch") == null)

	var pocket_deadline: int = Time.get_ticks_msec() + 6000
	while (
		Time.get_ticks_msec() < pocket_deadline
		and fishing_spot.state != FishingSpot.FishingState.READY
	):
		await process_frame
	assert(fishing_spot.state == FishingSpot.FishingState.READY)
	assert(player.is_movement_enabled())
	assert(bool(player.call("_is_movement_input_enabled")))
	assert(bool(player.call("_is_camera_input_enabled")))
	assert(player.inventory.contains_catch_id(crab_catch.catch_id))
	assert(bool(player.get("_active_item_is_net")))
	print("Gathering showcase validation: PASS")

	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()
