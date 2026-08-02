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
	var chat_ui := game_ui.get_node("%ChatUI") as ChatUI
	assert(player != null and service != null and toolbar != null)
	assert(chat_ui != null)
	var settings_panel := game_ui.get(
		"_pause_settings_panel"
	) as SettingsPanel
	var chat_dock_button := settings_panel.get_node("%ChatDock") as BubbleButton
	var paint_dock_button := settings_panel.get_node("%PaintDock") as BubbleButton
	assert(chat_dock_button.neutral_size.x == chat_dock_button.neutral_size.y)
	assert(paint_dock_button.neutral_size.x == paint_dock_button.neutral_size.y)
	assert(
		chat_dock_button.compact_minimum_size.x
		== chat_dock_button.compact_minimum_size.y
	)
	assert(
		paint_dock_button.compact_minimum_size.x
		== paint_dock_button.compact_minimum_size.y
	)
	assert(not chat_ui.is_docked_right())
	assert(toolbar.is_docked_right())
	var settings_manager := main.get_node(
		"%PlayerSettingsManager"
	) as PlayerSettingsManager
	assert(settings_manager != null)
	var changed_docks: PlayerSettings = settings_manager.current_settings.copy()
	changed_docks.chat_dock_right = true
	changed_docks.paint_dock_right = false
	assert(settings_manager.apply_settings(changed_docks))
	await process_frame
	assert(chat_ui.is_docked_right())
	assert(not toolbar.is_docked_right())
	var reloaded_settings := PlayerSettingsManager.new()
	root.add_child(reloaded_settings)
	assert(reloaded_settings.load_settings())
	assert(reloaded_settings.current_settings.chat_dock_right)
	assert(not reloaded_settings.current_settings.paint_dock_right)
	reloaded_settings.queue_free()
	var default_docks: PlayerSettings = settings_manager.current_settings.copy()
	default_docks.chat_dock_right = false
	default_docks.paint_dock_right = true
	assert(settings_manager.apply_settings(default_docks))
	await process_frame
	assert(not chat_ui.is_docked_right())
	assert(toolbar.is_docked_right())
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
	var ui_root := game_ui.get_node("%UIRoot") as Control
	assert(toolbar.get_parent() == ui_root)
	assert(is_zero_approx(toolbar.position.y))
	assert(
		is_equal_approx(
			toolbar.get_global_rect().end.x,
			ui_root.get_global_rect().end.x,
		)
	)
	assert(toolbar.get_global_rect().end.x <= 1280.0)
	assert(toolbar.get_global_rect().end.y <= 720.0)
	var top_panel := toolbar.get_node("%TopPanel") as PanelContainer
	var color_panel := toolbar.get_node("%ColorPanel") as PanelContainer
	assert(top_panel.position.is_equal_approx(Vector2.ZERO))
	assert(color_panel.position.x > 0.0)
	assert(is_equal_approx(color_panel.get_rect().end.x, top_panel.get_rect().end.x))
	assert(color_panel.position.y < top_panel.get_rect().end.y)
	assert(color_panel.get_rect().end.y > top_panel.get_rect().end.y)
	var toolbar_origin: Vector2 = toolbar.get_global_rect().position
	var top_pointer := InputEventMouseMotion.new()
	top_pointer.position = toolbar_origin + Vector2(200.0, 24.0)
	assert(toolbar.owns_pointer_event(top_pointer))
	var rail_pointer := InputEventMouseMotion.new()
	rail_pointer.position = color_panel.get_global_rect().get_center()
	assert(toolbar.owns_pointer_event(rail_pointer))
	var empty_pointer := InputEventMouseMotion.new()
	empty_pointer.position = toolbar_origin + Vector2(200.0, 180.0)
	assert(not toolbar.owns_pointer_event(empty_pointer))

	var brush_option := toolbar.get_node("%BrushOption") as OptionButton
	var grid_option := toolbar.get_node("%GridOption") as OptionButton
	var mode_button := toolbar.get_node("%ModeButton") as Button
	var eraser_button := toolbar.get_node("%EraserButton") as Button
	var undo_button := toolbar.get_node("%UndoButton") as Button
	var hide_button := toolbar.get_node("%HideGuideButton") as Button
	var restore_button := toolbar.get_node("%RestoreGuideButton") as Button
	var finalize_button := toolbar.get_node("%FinalizeGuideButton") as Button
	var close_button := toolbar.get_node("%CloseButton") as Button
	assert(
		mode_button != null
		and eraser_button != null
		and undo_button != null
		and hide_button != null
		and restore_button != null
		and finalize_button != null
		and close_button != null
	)
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

	mode_button.pressed.emit()
	assert(not service.is_placement_mode())
	eraser_button.pressed.emit()
	assert(service.is_eraser_mode())
	assert(eraser_button.button_pressed)
	hide_button.pressed.emit()
	assert(service.is_placement_mode())
	assert(not service.is_eraser_mode())
	assert(
		service.get_armed_guide_action()
		== NetworkSurfaceDrawingService.GuideAction.HIDE
	)
	var world_click := InputEventMouseButton.new()
	world_click.button_index = MOUSE_BUTTON_LEFT
	world_click.pressed = true
	assert(service.handle_input(world_click, true))
	assert(
		service.get_armed_guide_action()
		== NetworkSurfaceDrawingService.GuideAction.NONE
	)
	assert(not service.is_placement_mode())
	assert(service.is_eraser_mode())

	restore_button.pressed.emit()
	assert(
		service.get_armed_guide_action()
		== NetworkSurfaceDrawingService.GuideAction.RESTORE
	)
	restore_button.pressed.emit()
	assert(
		service.get_armed_guide_action()
		== NetworkSurfaceDrawingService.GuideAction.NONE
	)
	assert(not service.is_placement_mode() and service.is_eraser_mode())
	finalize_button.pressed.emit()
	assert(
		service.get_armed_guide_action()
		== NetworkSurfaceDrawingService.GuideAction.FINALIZE
	)
	assert(service.handle_input(world_click, true))
	assert(not service.is_placement_mode() and service.is_eraser_mode())
	(color_buttons[&"ocean_teal"] as Button).pressed.emit()
	assert(not service.is_eraser_mode())
	undo_button.pressed.emit()
	assert(service.is_active())
	close_button.pressed.emit()
	assert(not service.is_active() and not toolbar.visible)

	assert(service.handle_input(paint_key, true))
	await process_frame
	assert(service.is_active() and toolbar.visible)

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
