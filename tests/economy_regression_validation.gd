extends SceneTree

const MainScene = preload("res://main/main.tscn")
const FishCatchType = preload("res://fish/fish_catch.gd")

var _finished: Array[Variant] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main := MainScene.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame
	if not bool(main.get("_application_initialized")):
		var data_root := main.get_node("%PlayerDataRoot") as PlayerDataRoot
		assert(data_root.select_new_root("", true))
		main.call("_configure_portable_stores")
		main.call("_initialize_after_data_root")
	for _frame: int in 8:
		await process_frame
	assert(bool(main.get("_application_initialized")))
	assert(bool(main.call("_prepare_private_host")))
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(save_manager.initialize_new_game())
	main.call("_enter_gameplay")
	for _frame: int in 8:
		await process_frame

	var player := main.get("_player") as Player
	var catalog := main.get("fish_catalog") as FishPool
	var sale_service := main.get_node("%NetworkSaleService") as NetworkSaleService
	var pelican := (
		main.get("_test_world") as TestWorld
	).get_pelican_convenience_landmark()
	assert(player != null)
	assert(catalog != null)
	assert(sale_service != null)
	assert(pelican != null)
	player.global_position = pelican.global_position
	await process_frame

	var initial_balance: int = player.wallet.get_balance()
	var fish_catch: FishCatch = _make_catch(catalog.candidates.front())
	player.inventory.add_catch(fish_catch)
	assert(player.inventory.contains_catch_id(fish_catch.catch_id))
	sale_service.local_sale_finished.connect(_on_sale_finished)
	var request_id: String = sale_service.request_local_sale(
		[fish_catch.catch_id]
	)
	assert(not request_id.is_empty())
	assert(not _finished.is_empty())
	assert(bool(_finished[1]))
	assert(not player.inventory.contains_catch_id(fish_catch.catch_id))
	assert(player.wallet.get_balance() > initial_balance)
	assert(not sale_service.is_local_sale_pending())

	var ui_catch: FishCatch = _make_catch(catalog.candidates.front())
	player.inventory.add_catch(ui_catch)
	var game_ui := main.get_node("%GameUI") as GameUI
	var player_menu := game_ui.get_node("%PlayerMenu") as PlayerMenu
	player_menu.open_menu()
	await create_timer(2.2).timeout
	player_menu.call("_on_catch_card_pressed", ui_catch.catch_id)
	await process_frame
	var sell_action := player_menu.get_node("%SellBubble") as Button
	var confirmation := player_menu.get_node("%SaleConfirmation") as Control
	var confirm_button := player_menu.get_node("%ConfirmSaleButton") as Button
	assert(sell_action.visible and not sell_action.disabled)
	var ui_root := sell_action.get_viewport().get_node("GameUI/UIRoot") as Control
	var sell_screen_center: Vector2 = (
		ui_root.position
		+ sell_action.get_global_rect().get_center() * ui_root.scale
	)
	Input.warp_mouse(sell_screen_center)
	await process_frame
	print(
		"Sale rect/mouse/filter/tree: ",
		sell_action.get_global_rect(),
		" screen center: ",
		sell_screen_center,
		" / ",
		sell_action.get_viewport().get_mouse_position(),
		" / ",
		sell_action.mouse_filter,
		" / ",
		sell_action.is_visible_in_tree(),
		" hovered: ",
		sell_action.get_viewport().gui_get_hovered_control().get_path()
		if sell_action.get_viewport().gui_get_hovered_control() != null
		else "none",
	)
	_click_control(sell_action, sell_screen_center)
	for _frame: int in 3:
		await process_frame
	assert(confirmation.visible)
	assert(confirm_button.visible and not confirm_button.disabled)
	_finished.clear()
	var confirm_screen_center: Vector2 = (
		ui_root.position
		+ confirm_button.get_global_rect().get_center() * ui_root.scale
	)
	Input.warp_mouse(confirm_screen_center)
	await process_frame
	_click_control(confirm_button, confirm_screen_center)
	for _frame: int in 3:
		await process_frame
	assert(not _finished.is_empty() and bool(_finished[1]))
	assert(not player.inventory.contains_catch_id(ui_catch.catch_id))
	assert(not sale_service.is_local_sale_pending())

	print("Economy regression validation: PASS")
	main.queue_free()
	await process_frame
	quit()


func _make_catch(fish: FishData) -> FishCatch:
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
	return fish_catch


func _on_sale_finished(
	request_id: String,
	accepted: bool,
	message: String,
	catch_ids: Array[StringName],
	payout: int,
) -> void:
	_finished = [request_id, accepted, message, catch_ids, payout]


func _click_control(control: Control, center: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	control.get_viewport().push_input(motion)
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.pressed = true
	pressed.position = center
	pressed.global_position = center
	control.get_viewport().push_input(pressed)
	var released := InputEventMouseButton.new()
	released.button_index = MOUSE_BUTTON_LEFT
	released.pressed = false
	released.position = center
	released.global_position = center
	control.get_viewport().push_input(released)
