extends SceneTree

const MainScene = preload("res://main/main.tscn")
const FishCatchType = preload("res://fish/fish_catch.gd")

var _sale_result: Array[Variant] = []
var _shop_result: Array[Variant] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("host"):
		await _run_multiplayer_host()
		return
	if arguments.has("client"):
		await _run_multiplayer_client()
		return
	root.size = Vector2i(1280, 720)
	var main := MainScene.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame
	if not bool(main.get("_application_initialized")):
		# Use the same activation path as the real setup dialog so no modal is
		# left above the gameplay SubViewport during pointer validation.
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

	var player := main.get("_player") as Player
	var catalog := main.get("fish_catalog") as FishPool
	var sale_service := main.get_node("%NetworkSaleService") as NetworkSaleService
	var shop_service := main.get_node("%NetworkShopService") as NetworkShopService
	var session := main.get_node("%NetworkSession") as NetworkSession
	var reservations := (
		main.get_node("%PlayerAssetReservationService")
		as PlayerAssetReservationService
	)
	var pelican := (
		main.get("_test_world") as TestWorld
	).get_pelican_convenience_landmark()
	assert(player != null)
	assert(catalog != null and catalog.candidates.size() == 8)
	assert(sale_service != null)
	assert(shop_service != null)
	assert(session != null and session.is_host())
	assert(reservations != null)
	assert(pelican != null)
	sale_service.local_sale_finished.connect(_on_sale_finished)
	shop_service.local_purchase_finished.connect(_on_shop_finished)
	player.global_position = pelican.global_position
	await process_frame

	_test_each_species(player, catalog, sale_service)
	_test_multi_sale(player, catalog, sale_service)
	_test_reservations(player, catalog, sale_service, reservations)
	_test_rejection_cleanup(player, catalog, sale_service, pelican)
	await _test_player_menu_sale(main, player, catalog, sale_service, pelican)

	assert(session.set_host_open(true))
	assert(session.state == NetworkSession.State.OPEN_HOST)
	var open_catch := _make_catch(catalog.candidates.front())
	player.inventory.add_catch(open_catch)
	_assert_sale(player, sale_service, [open_catch.catch_id], true)
	assert(session.set_host_open(false))

	await _test_host_shop_purchase(main, player, shop_service)
	assert(not sale_service.is_local_sale_pending())
	assert(not shop_service.is_local_purchase_pending())

	print("Economy regression validation: PASS")
	session.disconnect_session("Economy validation complete.")
	main.queue_free()
	await process_frame
	quit()


func _run_multiplayer_host() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node = await _create_initialized_main()
	assert(bool(main.call("_prepare_private_host")))
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(save_manager.initialize_new_game())
	main.call("_enter_gameplay")
	var session := main.get_node("%NetworkSession") as NetworkSession
	assert(session.set_host_open(true))
	var client_connected := false
	var connection_deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < connection_deadline:
		await process_frame
		if session.get_authenticated_peer_ids().size() >= 2:
			client_connected = true
			break
	assert(client_connected)
	var remote_peer_id := 0
	for authenticated_peer_id: int in session.get_authenticated_peer_ids():
		if authenticated_peer_id != 1:
			remote_peer_id = authenticated_peer_id
			break
	assert(remote_peer_id > 1)
	var spawn_service := main.get("_player_spawn_service") as PlayerSpawnService
	var remote_avatar := spawn_service.get_avatar(remote_peer_id)
	var pelican := (
		main.get("_test_world") as TestWorld
	).get_pelican_convenience_landmark()
	assert(remote_avatar != null and pelican != null)
	# The client cannot teleport its authoritative avatar. Place the host-owned
	# test avatar at each interaction so this fixture validates the remote
	# transaction path without conflating it with the movement suite.
	remote_avatar.global_position = pelican.global_position
	await create_timer(5.0).timeout
	var interaction := main.get("_shop_interaction") as FishingShopInteraction
	assert(interaction != null)
	remote_avatar.global_position = interaction.global_position
	var completion_deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < completion_deadline:
		await process_frame
		if session.get_authenticated_peer_ids().size() < 2:
			break
	print("Economy multiplayer host validation: PASS")
	session.disconnect_session("Economy host validation complete.")
	main.queue_free()
	await process_frame
	quit()


func _run_multiplayer_client() -> void:
	root.size = Vector2i(1280, 720)
	var main: Node = await _create_initialized_main()
	main.call("_on_title_join_game_requested", "127.0.0.1:7777")
	var session := main.get_node("%NetworkSession") as NetworkSession
	var joined := false
	var join_deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < join_deadline:
		await process_frame
		if session.state == NetworkSession.State.VERIFYING_SERVER_IDENTITY:
			main.call("_confirm_server_trust")
		if session.is_joined_client() and bool(main.get("_gameplay_started")):
			joined = true
			break
	assert(joined)
	var player := main.get("_player") as Player
	var catalog := main.get("fish_catalog") as FishPool
	var sale_service := main.get_node("%NetworkSaleService") as NetworkSaleService
	var shop_service := main.get_node("%NetworkShopService") as NetworkShopService
	sale_service.local_sale_finished.connect(_on_sale_finished)
	shop_service.local_purchase_finished.connect(_on_shop_finished)
	var pelican := (
		main.get("_test_world") as TestWorld
	).get_pelican_convenience_landmark()
	player.global_position = pelican.global_position
	var catch_ids: Array[StringName] = []
	for fish: FishData in catalog.candidates:
		var fish_catch := _make_catch(fish)
		player.inventory.add_catch(fish_catch)
		catch_ids.append(fish_catch.catch_id)
	await create_timer(1.0).timeout
	_sale_result.clear()
	assert(not sale_service.request_local_sale(catch_ids).is_empty())
	var sale_deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < sale_deadline:
		await process_frame
		if not _sale_result.is_empty():
			break
	print("Client sale result: ", _sale_result)
	assert(not _sale_result.is_empty() and bool(_sale_result[1]))
	for catch_id: StringName in catch_ids:
		assert(not player.inventory.contains_catch_id(catch_id))
	assert(not sale_service.is_local_sale_pending())

	var interaction := main.get("_shop_interaction") as FishingShopInteraction
	player.global_position = interaction.global_position
	await create_timer(5.5).timeout
	assert(player.wallet.credit(100))
	_shop_result.clear()
	assert(not shop_service.request_supply(&"coffee").is_empty())
	var shop_deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < shop_deadline:
		await process_frame
		if not _shop_result.is_empty():
			break
	print("Client shop result: ", _shop_result)
	assert(not _shop_result.is_empty() and bool(_shop_result[1]))
	assert(not shop_service.is_local_purchase_pending())
	print("Economy multiplayer client validation: PASS")
	session.disconnect_session("Economy client validation complete.")
	main.queue_free()
	await process_frame
	quit()


func _create_initialized_main() -> Node:
	var main := MainScene.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame
	if not bool(main.get("_application_initialized")):
		main.call("_activate_selected_data_path", "", true)
	for _frame: int in 8:
		await process_frame
	assert(bool(main.get("_application_initialized")))
	return main


func _test_each_species(
	player: Player,
	catalog: FishPool,
	sale_service: NetworkSaleService,
) -> void:
	for fish: FishData in catalog.candidates:
		assert(fish != null)
		var fish_catch := _make_catch(fish)
		player.inventory.add_catch(fish_catch)
		_assert_sale(player, sale_service, [fish_catch.catch_id], true)


func _test_multi_sale(
	player: Player,
	catalog: FishPool,
	sale_service: NetworkSaleService,
) -> void:
	var catches: Array[FishCatch] = [
		_make_catch(catalog.candidates[0]),
		_make_catch(catalog.candidates[1]),
		_make_catch(catalog.candidates[2]),
	]
	var catch_ids: Array[StringName] = []
	for fish_catch: FishCatch in catches:
		player.inventory.add_catch(fish_catch)
		catch_ids.append(fish_catch.catch_id)
	_assert_sale(player, sale_service, catch_ids, true)


func _test_reservations(
	player: Player,
	catalog: FishPool,
	sale_service: NetworkSaleService,
	reservations: PlayerAssetReservationService,
) -> void:
	var reserved := _make_catch(catalog.candidates[3])
	var unreserved := _make_catch(catalog.candidates[4])
	player.inventory.add_catch(reserved)
	player.inventory.add_catch(unreserved)
	var reservation_id := "economy-test-reservation"
	assert(reservations.reserve(reservation_id, {
		"type": PlayerAssetReservationService.AttachmentType.FISH,
		"catch_id": str(reserved.catch_id),
		"catch": reserved.to_network_dict(),
	}))
	_assert_sale(player, sale_service, [reserved.catch_id], false, false)
	_assert_sale(
		player,
		sale_service,
		[reserved.catch_id, unreserved.catch_id],
		false,
		false,
	)
	assert(player.inventory.contains_catch_id(reserved.catch_id))
	assert(player.inventory.contains_catch_id(unreserved.catch_id))
	assert(reservations.release(reservation_id))
	_assert_sale(
		player,
		sale_service,
		[reserved.catch_id, unreserved.catch_id],
		true,
	)


func _test_rejection_cleanup(
	player: Player,
	catalog: FishPool,
	sale_service: NetworkSaleService,
	pelican: Node3D,
) -> void:
	var fish_catch := _make_catch(catalog.candidates[5])
	player.inventory.add_catch(fish_catch)
	player.global_position = pelican.global_position + Vector3(20.0, 0.0, 0.0)
	_assert_sale(player, sale_service, [fish_catch.catch_id], false)
	assert(player.inventory.contains_catch_id(fish_catch.catch_id))
	assert(not sale_service.is_local_sale_pending())
	player.global_position = pelican.global_position
	_assert_sale(player, sale_service, [fish_catch.catch_id], true)


func _test_player_menu_sale(
	main: Node,
	player: Player,
	catalog: FishPool,
	sale_service: NetworkSaleService,
	pelican: Node3D,
) -> void:
	player.global_position = pelican.global_position
	var game_ui := main.get_node("%GameUI") as GameUI
	var player_menu := game_ui.get_node("%PlayerMenu") as PlayerMenu
	var fish_catch := _make_catch(catalog.candidates[6])
	player.inventory.add_catch(fish_catch)
	player_menu.open_menu()
	await create_timer(2.2).timeout
	player_menu.call("_on_catch_card_pressed", fish_catch.catch_id)
	await process_frame
	var sell_action := player_menu.get_node("%SellBubble") as Button
	var confirmation := player_menu.get_node("%SaleConfirmation") as Control
	var confirm_button := player_menu.get_node("%ConfirmSaleButton") as Button
	assert(sell_action.visible and not sell_action.disabled)
	assert(sell_action.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(sell_action.focus_mode == Control.FOCUS_ALL)
	sell_action.pressed.emit()
	await process_frame
	assert(confirmation.visible)
	assert(confirm_button.visible and not confirm_button.disabled)
	_sale_result.clear()
	confirm_button.pressed.emit()
	await process_frame
	assert(not _sale_result.is_empty() and bool(_sale_result[1]))
	assert(not player.inventory.contains_catch_id(fish_catch.catch_id))
	assert(not sale_service.is_local_sale_pending())
	player_menu.close_menu()
	await create_timer(2.2).timeout
	assert(not player_menu.visible)
	player_menu.open_menu()
	await create_timer(2.2).timeout
	assert(player_menu.visible)
	assert(
		not sell_action.disabled
		or player.inventory.get_all_catches().is_empty()
	)
	player_menu.close_menu()
	await create_timer(2.2).timeout


func _test_host_shop_purchase(
	main: Node,
	player: Player,
	shop_service: NetworkShopService,
) -> void:
	var interaction := main.get("_shop_interaction") as FishingShopInteraction
	assert(interaction != null)
	player.global_position = interaction.global_position
	for _frame: int in 4:
		await physics_frame
	assert(interaction.is_avatar_in_range(player))
	var quantity_before: int = player.bag.get_quantity(&"coffee")
	_shop_result.clear()
	var request_id: String = shop_service.request_supply(&"coffee")
	assert(not request_id.is_empty())
	assert(not _shop_result.is_empty() and bool(_shop_result[1]))
	assert(player.bag.get_quantity(&"coffee") == quantity_before + 1)
	assert(not shop_service.is_local_purchase_pending())


func _assert_sale(
	player: Player,
	sale_service: NetworkSaleService,
	catch_ids: Array[StringName],
	expected_success: bool,
	expect_request_id: bool = true,
) -> void:
	var balance_before: int = player.wallet.get_balance()
	_sale_result.clear()
	var request_id: String = sale_service.request_local_sale(catch_ids)
	assert((not request_id.is_empty()) == expect_request_id)
	assert(not _sale_result.is_empty())
	assert(bool(_sale_result[1]) == expected_success)
	assert(not sale_service.is_local_sale_pending())
	if expected_success:
		assert(player.wallet.get_balance() > balance_before)
		for catch_id: StringName in catch_ids:
			assert(not player.inventory.contains_catch_id(catch_id))
	else:
		assert(player.wallet.get_balance() == balance_before)
		for catch_id: StringName in catch_ids:
			assert(player.inventory.contains_catch_id(catch_id))


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
	_sale_result = [request_id, accepted, message, catch_ids, payout]


func _on_shop_finished(
	request_id: String,
	accepted: bool,
	message: String,
	product_id: StringName,
	category: int,
	quantity: int,
	total_cost: int,
) -> void:
	_shop_result = [
		request_id,
		accepted,
		message,
		product_id,
		category,
		quantity,
		total_cost,
	]
