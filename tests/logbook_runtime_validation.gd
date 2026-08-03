extends SceneTree

const MainScene = preload("res://main/main.tscn")
const FishCatchType = preload("res://fish/fish_catch.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MainScene.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame
	if not bool(main.get("_application_initialized")):
		main.call("_activate_selected_data_path", "", true)
	for _frame: int in 8:
		await process_frame
	assert(bool(main.get("_application_initialized")))
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(save_manager.initialize_new_game())
	main.call("_enter_gameplay")
	for _frame: int in 8:
		await process_frame
	assert(bool(main.get("_gameplay_started")))
	_validate_save_round_trip(main, save_manager)
	var player := main.get("_player") as Player
	var no_catches: Array[FishCatch] = []
	var no_discoveries: Array[StringName] = []
	assert(player.inventory.replace_all_catches(no_catches, 1))
	assert(player.collection_log.replace_discovered_ids(no_discoveries))

	var game_ui := main.get_node("%GameUI") as GameUI
	var player_menu := game_ui.get_node("%PlayerMenu") as PlayerMenu
	var logbook := player_menu.get_node("%CatalogLogbook") as LogbookPage
	var backdrop := main.get_node("%PlayerMenuBackdrop") as ColorRect
	var hotbar := game_ui.get_node("%Hotbar") as Control

	var shortcut := InputEventKey.new()
	shortcut.pressed = true
	shortcut.physical_keycode = KEY_L
	assert(bool(player_menu.call("_handle_direct_page_shortcut", shortcut)))
	await create_timer(2.2).timeout
	assert(player_menu.visible)
	assert(logbook.visible)
	assert(backdrop.visible)
	assert(not bool(game_ui.get("_player_menu_hotbar_visible")))
	assert(not hotbar.visible)

	var entry_buttons: Dictionary = logbook.get("_entry_buttons")
	assert(entry_buttons.size() == 7)
	await _capture_if_requested("-unknown")
	logbook.call(
		"_select_category", WaterType.Type.FRESH_WATER
	)
	await create_timer(0.25).timeout
	assert((logbook.get("_entry_buttons") as Dictionary).size() == 7)
	await _capture_if_requested("-fresh")
	logbook.call("_select_category", WaterType.Type.SALT_WATER)
	await create_timer(0.25).timeout
	assert((logbook.get("_entry_buttons") as Dictionary).size() == 12)
	logbook.call("_select_category", WaterType.Type.FRESH_WATER)
	await create_timer(0.25).timeout
	assert((logbook.get("_entry_buttons") as Dictionary).size() == 7)
	player.collection_log.mark_discovered(&"bluegill")
	await process_frame
	logbook.call("_select_entry", &"bluegill", &"bluegill")
	await create_timer(0.2).timeout
	await _capture_if_requested("-known")

	assert(bool(player_menu.call("_handle_direct_page_shortcut", shortcut)))
	await create_timer(2.2).timeout
	assert(not player_menu.visible)

	assert(bool(player_menu.call("_handle_direct_page_shortcut", shortcut)))
	await create_timer(2.2).timeout
	player_menu.call(
		"_show_section_immediate", PlayerMenu.Section.PROFILE
	)
	await process_frame
	assert(not bool(
		player_menu.call("_handle_direct_page_shortcut", shortcut)
	))
	assert(player_menu.visible)
	player_menu.close_menu(PlayerMenu.CloseReason.TEARDOWN, false)

	print(
		"Logbook runtime validation: PASS at %dx%d"
		% [root.size.x, root.size.y]
	)
	main.queue_free()
	await process_frame
	quit()


func _validate_save_round_trip(
	main: Node,
	save_manager: PlayerSaveManager,
) -> void:
	var player := main.get("_player") as Player
	var catalog := main.get("fish_catalog") as FishPool
	assert(catalog != null)
	assert(catalog.candidates.size() == 19)
	for index: int in 4:
		_add_test_catch(player, catalog.candidates[index])
	assert(save_manager.save_now())
	var no_catches: Array[FishCatch] = []
	var no_discoveries: Array[StringName] = []
	assert(player.inventory.replace_all_catches(no_catches, 1))
	assert(player.collection_log.replace_discovered_ids(no_discoveries))
	assert(save_manager.load_player_data())
	assert(player.inventory.get_all_catches().size() == 4)
	for index: int in 4:
		var original_fish: FishData = catalog.candidates[index]
		assert(player.inventory.get_count(original_fish.id) == 1)
		assert(player.collection_log.has_discovered(original_fish.id))

	for index: int in range(4, catalog.candidates.size()):
		_add_test_catch(player, catalog.candidates[index])
	assert(save_manager.save_now())
	assert(player.inventory.replace_all_catches(no_catches, 1))
	assert(player.collection_log.replace_discovered_ids(no_discoveries))
	assert(save_manager.load_player_data())
	assert(player.inventory.get_all_catches().size() == 19)
	for fish: FishData in catalog.candidates:
		assert(player.inventory.get_count(fish.id) == 1)
		assert(player.collection_log.has_discovered(fish.id))
	for fish_id: StringName in [
		&"catfish_blue",
		&"catfish_channel",
		&"catfish_flathead",
		&"catfish_white",
	]:
		var fish_catch: FishCatch = (
			player.inventory.get_catches_by_fish_id(fish_id).front()
		)
		player.begin_catch_showcase(fish_catch)
		var catch_sprite := player.get_node(
			"%CatchSprite"
		) as Sprite3D
		assert(catch_sprite.texture == fish_catch.fish.display_texture)
		player.end_catch_showcase(Callable(), true)


func _add_test_catch(player: Player, fish: FishData) -> void:
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
	player.collection_log.mark_discovered(fish.id)


func _capture_if_requested(suffix: String) -> void:
	if not OS.has_environment("NETFISHING_LOGBOOK_CAPTURE"):
		return
	await process_frame
	await process_frame
	var image: Image = root.get_texture().get_image()
	var path: String = (
		OS.get_environment("NETFISHING_LOGBOOK_CAPTURE")
		+ suffix
		+ ".png"
	)
	assert(image.save_png(path) == OK)
