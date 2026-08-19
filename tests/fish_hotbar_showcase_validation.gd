extends SceneTree

const MainScene = preload("res://main/main.tscn")
const FishCatchType = preload("res://fish/fish_catch.gd")
const FishDataType = preload("res://fish/fish_data.gd")


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
	var world_time := main.get_node("%WorldTimeService") as WorldTimeService
	var world_weather := (
		main.get_node("%WorldWeatherService") as WorldWeatherService
	)
	world_time.synchronize_time(19.75)
	assert(player.experience.award_experience(125))
	var fish_catalog := main.get("fish_catalog") as FishPool
	var service := main.get_node(
		"%NetworkFishShowcaseService"
	) as NetworkFishShowcaseService
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
	fish_catch.quality = FishQuality.Tier.EXCEPTIONAL
	fish_catch.sale_value = FishQuality.apply_sale_value(
		fish.get_sale_value_for_weight(fish_catch.weight_lb),
		fish_catch.quality,
	)
	fish_catch.ensure_identity()
	player.inventory.add_catch(fish_catch)
	player.collection_log.mark_quality_discovered(
		fish_catch.fish_id,
		fish_catch.quality,
	)
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

	assert(service.is_local_showcase_visible())
	assert(service.get_local_showcase_catch_id() == fish_catch.catch_id)
	await _wait_for_held_fish_visibility(player, true)
	assert(service.toggle_selected_fish())
	await process_frame
	assert(not service.is_local_showcase_visible())
	await _wait_for_held_fish_visibility(player, false)
	var saved_weather: WorldWeatherService.Weather = (
		world_weather.get_persistent_weather()
	)
	var saved_weather_seconds: float = (
		world_weather.get_persistent_seconds_remaining()
	)
	var saved_time_hours: float = world_time.get_persistent_time_hours()

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
	assert(int((parsed as Dictionary)["save_version"]) == 8)
	assert(
		int((parsed as Dictionary)["experience"]["total_experience"])
		== 125
	)
	assert(absf(
		float((parsed as Dictionary)["world"]["time_hours"]) - saved_time_hours
	) < 0.01)
	assert(
		int((parsed as Dictionary)["world"]["weather"])
		== int(saved_weather)
	)
	assert(absf(
		float(
			(parsed as Dictionary)["world"][
				"weather_seconds_remaining"
			]
		) - saved_weather_seconds
	) < 0.1)
	var saved_catches: Array = (parsed as Dictionary)["inventory"]["catches"]
	assert(int((saved_catches[0] as Dictionary)["quality"]) == fish_catch.quality)
	var saved_masks: Dictionary = (
		(parsed as Dictionary)["collection"]["discovered_quality_masks"]
	)
	assert(
		int(saved_masks[String(fish.id)])
		== FishQuality.bit_for(FishQuality.Tier.EXCEPTIONAL)
	)

	assert(player.hotbar.clear_slot(1))
	assert(player.experience.restore_total_experience(0))
	world_time.synchronize_time(8.0)
	world_weather.clear_daily_plan()
	world_weather.apply_authoritative_snapshot(
		WorldWeatherService.Weather.FOGGY,
		10.0,
	)
	assert(save_manager.load_player_data())
	assert(player.experience.get_total_experience() == 125)
	# Loading a save must not replace the active RTC-authoritative clock.
	assert(absf(world_time.get_time_hours() - 8.0) < 0.01)
	assert(world_weather.get_persistent_weather() == saved_weather)
	assert(absf(
		world_weather.get_persistent_seconds_remaining()
		- saved_weather_seconds
	) < 2.0)
	assert(player.experience.get_level() == 2)
	assert(player.hotbar.get_fish_catch_id(1) == fish_catch.catch_id)
	assert(player.hotbar.get_selected_slot() == 1)
	assert(
		player.collection_log.has_discovered_quality(
			fish.id,
			FishQuality.Tier.EXCEPTIONAL,
		)
	)
	assert(service.is_local_showcase_visible())
	await _wait_for_held_fish_visibility(player, true)
	assert(player.inventory.remove_catch_by_id(fish_catch.catch_id) != null)
	await process_frame
	assert(player.hotbar.get_fish_catch_id(1).is_empty())
	assert(not service.is_local_showcase_visible())
	await _wait_for_held_fish_visibility(player, false)

	var valid_state: Dictionary = {
		"session_id": "session",
		"owner_peer_id": 2,
		"visible": true,
		"fish_id": String(fish.id),
		"weight_lb": fish.get_minimum_weight(),
		"display_scale": fish.get_display_scale_for_weight(
			fish.get_minimum_weight()
		),
		"quality": FishQuality.Tier.BORING,
		"revision": 1,
	}
	assert(NetworkFishShowcaseProtocol.validate_state(valid_state))
	var invalid_state: Dictionary = valid_state.duplicate(true)
	invalid_state["display_scale"] = 1000.0
	assert(not NetworkFishShowcaseProtocol.validate_state(invalid_state))
	assert(NetworkProtocol.PROTOCOL_VERSION == 8)
	assert(NetworkProtocol.ENET_CHANNEL_COUNT == 10)
	assert(
		NetworkProtocol.FISH_QUALITY_CAPABILITY
		== "fish_quality_v1"
	)
	assert(
		NetworkFishShowcaseProtocol.CAPABILITY
		== &"fish_showcase_v1"
	)

	print("Fish hotbar showcase validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()


func _wait_for_held_fish_visibility(
	player: Player,
	expected_visible: bool,
) -> void:
	var held_fish_display := player.get("_held_fish_display") as Node3D
	assert(held_fish_display != null)
	var deadline_msec: int = Time.get_ticks_msec() + 2000
	while (
		held_fish_display.visible != expected_visible
		and Time.get_ticks_msec() < deadline_msec
	):
		await process_frame
	assert(
		held_fish_display.visible == expected_visible,
		"Held fish display did not become %s within the timeout."
		% expected_visible,
	)
