extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const TEST_PORT: int = 18136


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
	assert(bool(main.call("_prepare_private_host")))
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(save_manager.initialize_new_game())
	main.call("_enter_gameplay")
	await physics_frame
	await physics_frame

	var player := main.get("_player") as Player
	var service := main.get_node(
		"%NetworkSurfaceDrawingService"
	) as NetworkSurfaceDrawingService
	var game_ui := main.get_node("%GameUI") as GameUI
	var toolbar := game_ui.get_node(
		"%SurfaceDrawingToolbar"
	) as SurfaceDrawingToolbar
	assert(player != null and service != null and toolbar != null)
	assert(not service.can_activate())
	assert(not service.is_active() and not toolbar.visible)
	assert(player.bag.add_item(ArtShopStock.ART_KIT_ITEM_ID, 1))
	assert(service.can_activate())

	var paint_key := InputEventKey.new()
	paint_key.physical_keycode = KEY_P
	paint_key.pressed = true
	assert(service.handle_input(paint_key, true))
	await process_frame
	assert(service.is_active() and service.is_placement_mode())
	assert(toolbar.visible)
	assert(toolbar.position.is_equal_approx(Vector2(18.0, 18.0)))
	assert(toolbar.get_global_rect().end.x <= 1280.0)
	assert(toolbar.get_global_rect().end.y <= 720.0)

	var brush_option := toolbar.get_node("%BrushOption") as OptionButton
	var grid_option := toolbar.get_node("%GridOption") as OptionButton
	assert(brush_option.item_count == 4)
	assert(grid_option.item_count == 4)
	assert(not brush_option.get_popup().is_item_disabled(0))
	assert(brush_option.get_popup().is_item_disabled(1))
	assert(not grid_option.get_popup().is_item_disabled(0))
	assert(grid_option.get_popup().is_item_disabled(1))
	var color_buttons: Dictionary = toolbar.get("_color_buttons")
	assert(color_buttons.size() == SurfaceDrawingPalette.COLORS.size())
	assert(not (color_buttons[&"chalk_white"] as Button).disabled)
	assert((color_buttons[&"ocean_teal"] as Button).disabled)

	for product_id: StringName in [
		&"marker_ocean_teal", &"brush_4x", &"grid_128x",
	]:
		assert(player.art_unlocks.unlock_product(product_id))
	await process_frame
	assert(not (color_buttons[&"ocean_teal"] as Button).disabled)
	assert(not brush_option.get_popup().is_item_disabled(3))
	assert(not grid_option.get_popup().is_item_disabled(3))
	assert(service.set_color_id(&"ocean_teal"))
	assert(service.set_brush_size(4))
	assert(service.set_grid_size(128))
	assert(service.get_color_id() == &"ocean_teal")
	assert(service.get_brush_size() == 4)
	assert(service.get_grid_size() == 128)

	assert(service.handle_input(paint_key, true))
	await process_frame
	assert(not service.is_active() and not toolbar.visible)
	assert(player.hotbar.assign_item(0, ArtShopStock.ART_KIT_ITEM_ID))
	var fishing_spot := main.get_node("%FishingSpot") as FishingSpot
	fishing_spot.art_ui_toggle_requested.emit()
	await process_frame
	assert(service.is_active() and toolbar.visible)
	assert(service.get_grid_size() == 128)

	print("Art tools validation: PASS")
	var session := main.get_node("%NetworkSession") as NetworkSession
	session.disconnect_session("")
	main.queue_free()
	await process_frame
	quit()
