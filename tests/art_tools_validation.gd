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
	var sprint_dust := player.get_node("%SprintDust") as SprintDustTrail
	assert(sprint_dust != null)
	assert(sprint_dust.get_active_puff_count() == 0)
	sprint_dust.update_trail(
		0.016,
		Vector3.ZERO,
		Vector3(4.5, 0.0, 0.0),
		true,
	)
	assert(sprint_dust.get_active_puff_count() == 0)
	sprint_dust.update_trail(
		0.016,
		Vector3(0.5, 0.0, 0.0),
		Vector3(4.5, 0.0, 0.0),
		true,
	)
	assert(sprint_dust.get_active_puff_count() == 1)
	var planted_puff_position: Vector3 = (
		sprint_dust.get_first_active_puff_position()
	)
	sprint_dust.update_trail(
		0.08,
		Vector3(0.75, 0.0, 0.0),
		Vector3(4.5, 0.0, 0.0),
		true,
	)
	assert(
		sprint_dust.get_first_active_puff_position()
		== planted_puff_position
	)
	sprint_dust.update_trail(
		0.08,
		Vector3(0.75, 0.0, 0.0),
		Vector3.ZERO,
		false,
	)
	assert(sprint_dust.get_active_puff_count() == 1)
	sprint_dust.clear_trail()
	assert(sprint_dust.get_active_puff_count() == 0)
	sprint_dust.emit_landing_burst(Vector3.ZERO, Vector3.FORWARD)
	assert(sprint_dust.get_active_puff_count() == 5)
	sprint_dust.update_trail(
		0.08,
		Vector3.ZERO,
		Vector3.ZERO,
		false,
	)
	assert(sprint_dust.get_active_puff_count() == 5)
	sprint_dust.clear_trail()
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
	assert(bool(game_ui.call("_can_start_virtual_mouse")))
	game_ui.call("_begin_virtual_mouse", 0)
	var virtual_cursor := game_ui.get_node(
		"%ControllerVirtualCursor"
	) as ControllerVirtualCursor
	assert(virtual_cursor.visible)
	assert(not player.is_camera_input_enabled())
	game_ui.call("_end_virtual_mouse")
	assert(not virtual_cursor.visible)
	assert(player.is_camera_input_enabled())
	var settings_panel := game_ui.get(
		"_pause_settings_panel"
	) as SettingsPanel
	var chat_dock_button := settings_panel.get_node("%ChatDock") as BubbleButton
	var chat_mode_button := settings_panel.get_node("%ChatMode") as BubbleButton
	var paint_dock_button := settings_panel.get_node("%PaintDock") as BubbleButton
	assert(chat_dock_button.neutral_size.x == chat_dock_button.neutral_size.y)
	assert(chat_mode_button.neutral_size.x == chat_mode_button.neutral_size.y)
	assert(paint_dock_button.neutral_size.x == paint_dock_button.neutral_size.y)
	assert(
		chat_dock_button.compact_minimum_size.x
		== chat_dock_button.compact_minimum_size.y
	)
	assert(
		chat_mode_button.compact_minimum_size.x
		== chat_mode_button.compact_minimum_size.y
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
	changed_docks.chat_mobile_mode = true
	changed_docks.paint_dock_right = false
	assert(settings_manager.apply_settings(changed_docks))
	await process_frame
	assert(chat_ui.is_docked_right())
	assert(chat_ui.is_mobile_mode())
	assert(not toolbar.is_docked_right())
	var chat_panel := chat_ui.get_node("ChatPanel") as PanelContainer
	var chat_height_button := chat_ui.get_node("ChatHeightButton") as Button
	var chat_status := chat_ui.find_child(
		"ChatStatus", true, false
	) as Label
	assert(chat_status != null)
	assert(
		chat_status.autowrap_mode
		== TextServer.AUTOWRAP_WORD_SMART
	)
	assert(is_zero_approx(chat_panel.position.y))
	assert(is_equal_approx(chat_panel.size.x, ChatUI.MOBILE_COMPACT_WIDTH))
	assert(not chat_height_button.visible)
	var reloaded_settings := PlayerSettingsManager.new()
	root.add_child(reloaded_settings)
	assert(reloaded_settings.load_settings())
	assert(reloaded_settings.current_settings.chat_dock_right)
	assert(reloaded_settings.current_settings.chat_mobile_mode)
	assert(not reloaded_settings.current_settings.paint_dock_right)
	reloaded_settings.queue_free()
	var default_docks: PlayerSettings = settings_manager.current_settings.copy()
	default_docks.chat_dock_right = false
	default_docks.chat_mobile_mode = false
	default_docks.paint_dock_right = true
	assert(settings_manager.apply_settings(default_docks))
	await process_frame
	chat_ui.call(
		"_set_status",
		(
			"Unknown command: /this-command-name-is-intentionally-long-"
			+ "enough-to-require-smart-character-wrapping"
		),
	)
	await process_frame
	assert(is_equal_approx(chat_panel.size.x, ChatUI.PANEL_WIDTH))
	assert(chat_status.size.x <= ChatUI.PANEL_WIDTH)
	chat_ui.call("_set_status", "")
	assert(not chat_ui.is_docked_right())
	assert(not chat_ui.is_mobile_mode())
	assert(toolbar.is_docked_right())
	assert(chat_height_button.visible)
	var select_button := InputEventJoypadButton.new()
	select_button.button_index = JOY_BUTTON_BACK
	select_button.pressed = true
	assert(bool(game_ui.call("_handle_controller_chat_controls", select_button)))
	await process_frame
	assert(chat_ui.is_open())
	assert(chat_panel.mouse_filter == Control.MOUSE_FILTER_STOP)
	var typed_chat_entry := chat_ui.find_child(
		"ChatEntry", true, false
	) as LineEdit
	assert(typed_chat_entry != null)
	assert(not typed_chat_entry.virtual_keyboard_enabled)
	var accept_button := InputEventJoypadButton.new()
	accept_button.button_index = JOY_BUTTON_A
	accept_button.pressed = true
	assert(bool(game_ui.call("_handle_controller_chat_controls", accept_button)))
	assert(typed_chat_entry.virtual_keyboard_enabled)
	await process_frame
	assert(typed_chat_entry.has_focus())
	var left_bumper := InputEventJoypadButton.new()
	left_bumper.button_index = JOY_BUTTON_LEFT_SHOULDER
	left_bumper.pressed = true
	assert(bool(game_ui.call("_handle_controller_chat_controls", left_bumper)))
	assert(not chat_ui.is_open())
	assert(chat_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(not typed_chat_entry.virtual_keyboard_enabled)
	assert(bool(game_ui.call("_handle_controller_chat_controls", left_bumper)))
	assert(not chat_ui.is_open())
	assert(not typed_chat_entry.virtual_keyboard_enabled)
	assert(bool(game_ui.call("_handle_controller_chat_controls", select_button)))
	assert(not chat_ui.is_open())
	assert(chat_ui.is_collapsed())
	assert(bool(game_ui.call("_handle_controller_chat_controls", select_button)))
	assert(chat_ui.is_open())
	chat_ui.refocus_gameplay()
	var quick_menu := game_ui.get_node(
		"%QuickRadialMenu"
	) as QuickRadialMenu
	var emote_menu := game_ui.get_node(
		"%EmoteRadialMenu"
	) as EmoteRadialMenu
	assert(quick_menu != null and emote_menu != null)
	assert(QuickRadialMenu.ACTIONS.size() == QuickRadialMenu.SECTOR_COUNT)
	assert(QuickRadialMenu.ACTIONS == [&"chat", &"freecam", &"hud"])
	game_ui.call("_on_quick_action_selected", &"freecam")
	assert(player.is_free_camera_active())
	var free_camera := player.get_active_gameplay_camera()
	assert(free_camera.name == &"FreeCamera")
	var free_camera_yaw_before: float = free_camera.global_rotation.y
	var mapping_manager := main.get(
		"_controller_mapping_manager"
	) as ControllerMappingManager
	var right_stick_motion := InputEventJoypadMotion.new()
	right_stick_motion.device = mapping_manager.get_active_device_id()
	right_stick_motion.axis = JOY_AXIS_RIGHT_X
	right_stick_motion.axis_value = 0.9
	Input.parse_input_event(right_stick_motion)
	await create_timer(0.1).timeout
	assert(
		absf(angle_difference(
			free_camera.global_rotation.y,
			free_camera_yaw_before,
		)) > 0.02
	)
	right_stick_motion.axis_value = 0.0
	Input.parse_input_event(right_stick_motion)
	await process_frame
	game_ui.call("_on_quick_action_selected", &"freecam")
	assert(not player.is_free_camera_active())
	game_ui.call("_on_quick_action_selected", &"hud")
	await process_frame
	assert(game_ui.is_gameplay_hud_hidden())
	assert(chat_ui.is_hud_hidden())
	assert(not (
		game_ui.get_node("%GameplayTransientHUD") as Control
	).visible)
	assert(not (
		game_ui.get_node("%ExperiencePresentation") as Control
	).visible)
	quick_menu.open_menu(true)
	assert(quick_menu.visible and quick_menu.is_open())
	quick_menu.close_menu()
	emote_menu.open_menu(true)
	assert(emote_menu.visible and emote_menu.is_open())
	emote_menu.close_menu()
	chat_ui.open_chat()
	await process_frame
	assert(chat_ui.is_open() and chat_panel.visible)
	chat_ui.refocus_gameplay()
	assert(chat_ui.is_hud_hidden())
	var cancel_button := InputEventJoypadButton.new()
	cancel_button.button_index = JOY_BUTTON_B
	cancel_button.pressed = true
	assert(not bool(main.call("_is_pause_open_request", cancel_button)))
	var start_button := InputEventJoypadButton.new()
	start_button.button_index = JOY_BUTTON_START
	start_button.pressed = true
	assert(bool(main.call("_is_pause_open_request", start_button)))
	var player_menu := game_ui.get_node("%PlayerMenu") as PlayerMenu
	player_menu.open_section(PlayerMenu.Section.PROFILE)
	for _frame: int in 12:
		await process_frame
	assert(game_ui.is_gameplay_hud_hidden())
	assert(player_menu.visible)
	assert(root.gui_get_focus_owner() is not LineEdit)
	player_menu.close_menu(PlayerMenu.CloseReason.SESSION_END)
	await process_frame
	game_ui.call("_on_quick_action_selected", &"hud")
	await process_frame
	assert(not game_ui.is_gameplay_hud_hidden())
	assert(not chat_ui.is_hud_hidden())
	assert(not service.can_activate())
	assert(not service.is_active() and not toolbar.visible)
	assert(player.bag.add_item(ArtShopStock.ART_KIT_ITEM_ID, 1))
	player.hotbar.select_slot(1)
	assert(player.hotbar.assign_item(0, ArtShopStock.ART_KIT_ITEM_ID))
	assert(not service.can_activate())
	var paint_key := InputEventKey.new()
	paint_key.physical_keycode = KEY_P
	paint_key.pressed = true
	assert(not service.handle_input(paint_key, true))
	assert(not service.is_active())
	player.hotbar.select_slot(0)
	await process_frame
	assert(service.is_active() and not service.is_placement_mode())
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
	assert(is_equal_approx(toolbar.size.x, SurfaceDrawingToolbar.TOOLBAR_WIDTH))
	assert(is_equal_approx(top_panel.size.x, SurfaceDrawingToolbar.TOOLBAR_WIDTH))
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
	assert(
		mode_button != null
		and eraser_button != null
		and undo_button != null
		and hide_button != null
		and restore_button != null
		and finalize_button != null
	)
	assert(toolbar.get_node_or_null("%CloseButton") == null)
	var expected_toolbar_icons: Dictionary[Button, String] = {
		mode_button: "/art/art_kit_marker.png",
		eraser_button: "/art/art_kit_eraser.png",
		hide_button: "/art/art_kit_grid_hidden_light.png",
		restore_button: "/art/art_kit_grid_restore_light.png",
		finalize_button: "/art/art_kit_grid_finish_light.png",
	}
	for icon_button: Button in expected_toolbar_icons:
		assert(icon_button.text.is_empty())
		assert(icon_button.icon != null)
		assert(
			icon_button.icon.resource_path.ends_with(
				expected_toolbar_icons[icon_button]
			)
		)
	for icon_button: Button in [
		eraser_button,
		undo_button,
		hide_button,
		restore_button,
		finalize_button,
	]:
		assert(icon_button.custom_minimum_size == Vector2(48, 44))
		assert(icon_button.get_theme_constant("icon_max_width") == 40)
		var icon_style := (
			icon_button.get_theme_stylebox("normal") as StyleBoxFlat
		)
		assert(is_equal_approx(icon_style.content_margin_left, 4.0))
		assert(is_equal_approx(icon_style.content_margin_top, 2.0))
	assert(mode_button.custom_minimum_size == Vector2(48, 48))
	assert(mode_button.get_theme_constant("icon_max_width") == 40)
	assert(mode_button.get_index() > finalize_button.get_index())
	assert(hide_button.button_group != null)
	assert(hide_button.button_group == restore_button.button_group)
	assert(hide_button.button_group == finalize_button.button_group)
	assert(hide_button.button_group.allow_unpress)
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
	var marker_mode_material := mode_button.material as ShaderMaterial
	assert(marker_mode_material != null)
	assert(
		marker_mode_material.shader.resource_path.ends_with(
			"/ui/art_kit_marker_icon.gdshader"
		)
	)
	assert(
		marker_mode_material.get_shader_parameter("marker_color")
		== SurfaceDrawingPalette.get_color(&"ocean_teal")
	)

	mode_button.pressed.emit()
	assert(service.is_placement_mode())
	assert(
		mode_button.icon.resource_path.ends_with(
			"/art/art_kit_grid_light.png"
		)
	)
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
		== NetworkSurfaceDrawingService.GuideAction.HIDE
	)
	assert(service.is_placement_mode())
	assert(not service.is_eraser_mode())
	assert(hide_button.button_pressed)
	hide_button.pressed.emit()
	assert(
		service.get_armed_guide_action()
		== NetworkSurfaceDrawingService.GuideAction.NONE
	)
	assert(not service.is_placement_mode() and service.is_eraser_mode())

	restore_button.pressed.emit()
	assert(
		service.get_armed_guide_action()
		== NetworkSurfaceDrawingService.GuideAction.RESTORE
	)
	finalize_button.pressed.emit()
	assert(
		service.get_armed_guide_action()
		== NetworkSurfaceDrawingService.GuideAction.FINALIZE
	)
	assert(not restore_button.button_pressed)
	assert(finalize_button.button_pressed)
	assert(service.handle_input(world_click, true))
	assert(
		service.get_armed_guide_action()
		== NetworkSurfaceDrawingService.GuideAction.FINALIZE
	)
	finalize_button.pressed.emit()
	assert(
		service.get_armed_guide_action()
		== NetworkSurfaceDrawingService.GuideAction.NONE
	)
	assert(not service.is_placement_mode() and service.is_eraser_mode())
	(color_buttons[&"ocean_teal"] as Button).pressed.emit()
	assert(not service.is_eraser_mode())
	undo_button.pressed.emit()
	assert(service.is_active())
	assert(not service.handle_input(paint_key, true))
	assert(service.is_active() and toolbar.visible)
	var fishing_spot := main.get_node("%FishingSpot") as FishingSpot
	await process_frame
	var held_art_kit_display := player.get("_held_art_kit_display") as Node3D
	var held_art_kit_sprite := player.get("_held_art_kit_sprite") as Sprite3D
	var pocket_animation_player := player.get(
		"_character_animation_player"
	) as AnimationPlayer
	var pocket_animation_name: StringName = player.get(
		"_pocket_visual_animation"
	)
	if (
		not held_art_kit_display.visible
		and pocket_animation_player != null
		and not pocket_animation_name.is_empty()
		and pocket_animation_player.has_animation(pocket_animation_name)
	):
		var pocket_animation: Animation = (
			pocket_animation_player.get_animation(pocket_animation_name)
		)
		await create_timer(pocket_animation.length * 0.55).timeout
	assert(held_art_kit_display.visible)
	assert(held_art_kit_sprite.visible and held_art_kit_sprite.texture != null)
	assert(held_art_kit_sprite.texture.resource_path.ends_with("/art/art_kit.png"))
	assert(is_zero_approx(angle_difference(
		held_art_kit_sprite.rotation.z,
		-PI * 0.5,
	)))
	assert(held_art_kit_sprite.flip_h)
	assert(not fishing_spot.has_signal(&"art_ui_toggle_requested"))
	assert(service.is_active() and toolbar.visible)
	assert(service.get_grid_size() == 128)
	assert(service.handle_input(world_click, true))
	assert(service.is_active() and toolbar.visible)
	var hotbar_ui := game_ui.get_node("%Hotbar") as HotbarUI
	var wheel_down := InputEventMouseButton.new()
	wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel_down.pressed = true
	assert(not service.handle_input(wheel_down, true))
	hotbar_ui._unhandled_input(wheel_down)
	await process_frame
	assert(player.hotbar.get_selected_slot() == 1)
	assert(not service.is_active() and not toolbar.visible)

	var number_one := InputEventKey.new()
	number_one.physical_keycode = KEY_1
	number_one.pressed = true
	assert(not service.handle_input(number_one, true))
	hotbar_ui._unhandled_input(number_one)
	await process_frame
	assert(service.is_active() and toolbar.visible)
	assert(player.hotbar.get_selected_slot() == 0)
	var number_two := InputEventKey.new()
	number_two.physical_keycode = KEY_2
	number_two.pressed = true
	assert(not service.handle_input(number_two, true))
	hotbar_ui._unhandled_input(number_two)
	await process_frame
	assert(player.hotbar.get_selected_slot() == 1)
	assert(not service.is_active() and not toolbar.visible)

	print("Art tools validation: PASS")
	var session := main.get_node("%NetworkSession") as NetworkSession
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()
