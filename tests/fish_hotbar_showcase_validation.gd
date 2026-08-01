extends SceneTree

const MainScene = preload("res://main/main.tscn")
const FishCatchType = preload("res://fish/fish_catch.gd")
const FishDataType = preload("res://fish/fish_data.gd")
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
	var session := main.get_node("%NetworkSession") as NetworkSession
	assert(session.start_private_host(17977))
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(save_manager.initialize_new_game())
	main.call("_enter_gameplay")
	for _frame: int in 8:
		await process_frame

	var player := main.get("_player") as Player
	var fish_catalog := main.get("fish_catalog") as FishPool
	var service := main.get_node(
		"%NetworkFishShowcaseService"
	) as NetworkFishShowcaseService
	var fishing_spot := main.get_node("%FishingSpot") as FishingSpotType
	assert(player != null and fish_catalog != null and service != null)
	var fish: FishDataType = fish_catalog.get_fish_by_id(&"bluegill")
	assert(fish != null)
	var fish_catch := FishCatchType.new()
	fish_catch.fish = fish
	fish_catch.fish_id = fish.id
	fish_catch.weight_lb = fish.get_minimum_weight()
	fish_catch.display_scale = fish.get_display_scale_for_weight(
		fish_catch.weight_lb
	)
	fish_catch.sale_value = fish.get_sale_value_for_weight(
		fish_catch.weight_lb
	)
	fish_catch.ensure_identity()
	player.inventory.add_catch(fish_catch)
	var game_ui := main.get_node("%GameUI") as GameUI
	var hotbar_ui := game_ui.get_node("%Hotbar") as HotbarUI
	assert(hotbar_ui != null)
	hotbar_ui.set_drag_enabled(true)
	var slots: Array = hotbar_ui.get("_slots")
	var fish_payload: Dictionary = {
		"kind": "cooler_fish",
		"catch_id": String(fish_catch.catch_id),
	}
	assert(slots.size() == PlayerHotbar.SLOT_COUNT)
	assert(bool(slots[1].call("_can_drop_data", Vector2.ZERO, fish_payload)))
	slots[1].call("_drop_data", Vector2.ZERO, fish_payload)
	assert(player.hotbar.get_fish_catch_id(1) == fish_catch.catch_id)
	assert(player.hotbar.select_slot(1))
	assert(
		player.hotbar.get_selected_assignment_kind()
		== PlayerHotbar.AssignmentKind.FISH
	)
	assert(player.hotbar.get_selected_fish_catch_id() == fish_catch.catch_id)
	assert(player.hotbar.get_selected_item_id().is_empty())

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	fishing_spot.call("_unhandled_input", press)
	await process_frame
	assert(service.is_local_showcase_visible())
	assert(service.get_local_showcase_catch_id() == fish_catch.catch_id)
	assert((player.get_node("%HeldFishDisplay") as Node3D).visible)
	fishing_spot.call("_unhandled_input", press)
	await process_frame
	assert(not service.is_local_showcase_visible())
	assert(not (player.get_node("%HeldFishDisplay") as Node3D).visible)

	assert(save_manager.save_now())
	var save_path: String = str(save_manager.get("_save_path"))
	var save_file := FileAccess.open(save_path, FileAccess.READ)
	assert(save_file != null)
	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	save_file.close()
	assert(typeof(parsed) == TYPE_DICTIONARY)
	var hotbar_data: Dictionary = (parsed as Dictionary)["hotbar"]
	assert(typeof(hotbar_data.get("fish_slots")) == TYPE_ARRAY)
	assert(str((hotbar_data["fish_slots"] as Array)[1]) == fish_catch.catch_id)
	assert(int((parsed as Dictionary)["save_version"]) == 4)

	assert(player.hotbar.clear_slot(1))
	assert(save_manager.load_player_data())
	assert(player.hotbar.get_fish_catch_id(1) == fish_catch.catch_id)
	assert(player.hotbar.get_selected_slot() == 1)
	assert(not service.is_local_showcase_visible())
	assert(service.toggle_selected_fish())
	assert(service.is_local_showcase_visible())
	assert(player.inventory.remove_catch_by_id(fish_catch.catch_id) != null)
	await process_frame
	assert(player.hotbar.get_fish_catch_id(1).is_empty())
	assert(not service.is_local_showcase_visible())
	assert(not (player.get_node("%HeldFishDisplay") as Node3D).visible)

	var valid_state: Dictionary = {
		"session_id": "session",
		"owner_peer_id": 2,
		"visible": true,
		"fish_id": String(fish.id),
		"weight_lb": fish.get_minimum_weight(),
		"display_scale": fish.get_display_scale_for_weight(
			fish.get_minimum_weight()
		),
		"revision": 1,
	}
	assert(NetworkFishShowcaseProtocol.validate_state(valid_state))
	var invalid_state: Dictionary = valid_state.duplicate(true)
	invalid_state["display_scale"] = 1000.0
	assert(not NetworkFishShowcaseProtocol.validate_state(invalid_state))
	assert(NetworkProtocol.PROTOCOL_VERSION == 3)
	assert(NetworkProtocol.ENET_CHANNEL_COUNT == 10)
	assert(
		NetworkFishShowcaseProtocol.CAPABILITY
		== &"fish_showcase_v1"
	)

	print("Fish hotbar showcase validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	await process_frame
	quit()
