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
	assert(player != null)
	assert(catalog != null and catalog.candidates.size() == 53)
	assert(sale_service != null)
	assert(shop_service != null)
	assert(session != null and session.is_host())
	assert(reservations != null)
	sale_service.local_sale_finished.connect(_on_sale_finished)
	shop_service.local_purchase_finished.connect(_on_shop_finished)
	await process_frame

	_test_each_species(player, catalog, sale_service)
	_test_multi_sale(player, catalog, sale_service)
	_test_reservations(player, catalog, sale_service, reservations)
	_test_anywhere_sale(player, catalog, sale_service)
	await _test_player_menu_sale(main, player, catalog, sale_service)
	await _test_host_shop_sale(main, player, catalog, sale_service)

	assert(session.set_host_open(true))
	assert(session.state == NetworkSession.State.OPEN_HOST)
	var open_catch := _make_catch(catalog.candidates.front())
	player.inventory.add_catch(open_catch)
	_assert_sale(player, sale_service, [open_catch.catch_id], true)
	assert(session.set_host_open(false))

	await _test_host_shop_purchase(main, player, shop_service)
	await _test_host_art_shop_purchase(main, player, shop_service)
	await _test_fishing_shop_sale_ui(
		main, player, catalog, sale_service, reservations
	)
	assert(not sale_service.is_local_sale_pending())
	assert(not shop_service.is_local_purchase_pending())

	print("Economy regression validation: PASS")
	session.disconnect_session("Economy validation complete.")
	main.queue_free()
	for _frame: int in 4:
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
	assert(remote_avatar != null)
	# Pelican sales are available from the Cooler anywhere. The host-owned
	# avatar only moves when the later Fishing Shop purchase needs proximity.
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
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
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
	var shop_catch := _make_catch(catalog.candidates.front())
	player.inventory.add_catch(shop_catch)
	var shop_sale_balance_before: int = player.wallet.get_balance()
	_sale_result.clear()
	assert(not sale_service.request_local_sale(
		[shop_catch.catch_id],
		NetworkSaleService.MAIN_SHOP_BUYER_ID,
	).is_empty())
	var shop_sale_deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < shop_sale_deadline:
		await process_frame
		if not _sale_result.is_empty():
			break
	print("Client shop sale result: ", _sale_result)
	assert(not _sale_result.is_empty() and bool(_sale_result[1]))
	assert(not player.inventory.contains_catch_id(shop_catch.catch_id))
	assert(
		player.wallet.get_balance()
		== shop_sale_balance_before + shop_catch.sale_value
	)
	assert(not sale_service.is_local_sale_pending())

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
	var required_art_balance: int = (
		ArtShopStock.ART_KIT_PRICE + ArtShopStock.UPGRADE_PRICE
	)
	if player.wallet.get_balance() < required_art_balance:
		assert(player.wallet.credit(
			required_art_balance - player.wallet.get_balance()
		))
	_shop_result.clear()
	assert(not shop_service.request_art_kit().is_empty())
	while _shop_result.is_empty():
		await process_frame
	assert(bool(_shop_result[1]))
	_shop_result.clear()
	assert(not shop_service.request_art_upgrade(&"grid_32x").is_empty())
	while _shop_result.is_empty():
		await process_frame
	assert(bool(_shop_result[1]))
	assert(player.bag.owns_item(ArtShopStock.ART_KIT_ITEM_ID))
	assert(player.art_unlocks.is_grid_size_unlocked(32))
	print("Economy multiplayer client validation: PASS")
	session.disconnect_session("Economy client validation complete.")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
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


func _test_anywhere_sale(
	player: Player,
	catalog: FishPool,
	sale_service: NetworkSaleService,
) -> void:
	var fish_catch := _make_catch(catalog.candidates[5])
	player.inventory.add_catch(fish_catch)
	# The spawn point is intentionally far from the Pelican landmark. Discounted
	# Pelican sales are a convenience action and do not require proximity.
	player.global_position = Vector3(0.0, 3.95, 13.0)
	_assert_sale(player, sale_service, [fish_catch.catch_id], true)


func _test_host_shop_sale(
	main: Node,
	player: Player,
	catalog: FishPool,
	sale_service: NetworkSaleService,
) -> void:
	var interaction := main.get("_shop_interaction") as FishingShopInteraction
	assert(interaction != null)
	var out_of_range_catch := _make_catch(catalog.candidates[6])
	player.inventory.add_catch(out_of_range_catch)
	player.global_position = Vector3(0.0, 3.95, 13.0)
	for _frame: int in 4:
		await physics_frame
	_assert_sale(
		player,
		sale_service,
		[out_of_range_catch.catch_id],
		false,
		true,
		NetworkSaleService.MAIN_SHOP_BUYER_ID,
	)
	player.global_position = interaction.global_position
	for _frame: int in 4:
		await physics_frame
	assert(interaction.is_avatar_in_range(player))
	var balance_before: int = player.wallet.get_balance()
	_assert_sale(
		player,
		sale_service,
		[out_of_range_catch.catch_id],
		true,
		true,
		NetworkSaleService.MAIN_SHOP_BUYER_ID,
	)
	assert(
		player.wallet.get_balance()
		== balance_before + out_of_range_catch.sale_value
	)
	var species_ids: Array[StringName] = []
	var expected_payout: int = 0
	for fish: FishData in catalog.candidates:
		var fish_catch := _make_catch(fish)
		player.inventory.add_catch(fish_catch)
		species_ids.append(fish_catch.catch_id)
		expected_payout += fish_catch.sale_value
	var species_balance_before: int = player.wallet.get_balance()
	_assert_sale(
		player,
		sale_service,
		species_ids,
		true,
		true,
		NetworkSaleService.MAIN_SHOP_BUYER_ID,
	)
	assert(
		player.wallet.get_balance()
		== species_balance_before + expected_payout
	)


func _test_player_menu_sale(
	main: Node,
	player: Player,
	catalog: FishPool,
	sale_service: NetworkSaleService,
) -> void:
	var game_ui := main.get_node("%GameUI") as GameUI
	var player_menu := game_ui.get_node("%PlayerMenu") as PlayerMenu
	var fish_catch := _make_catch(catalog.candidates[6])
	player.inventory.add_catch(fish_catch)
	player.global_position = Vector3(0.0, 3.95, 13.0)
	player_menu.open_menu()
	await create_timer(2.2).timeout
	player_menu.call("_on_catch_card_pressed", fish_catch.catch_id)
	await process_frame
	var sell_action := player_menu.get_node("%SellBubble") as Button
	var confirmation := player_menu.get_node("%SaleConfirmation") as Control
	var confirm_button := player_menu.get_node("%ConfirmSaleButton") as Button
	var ui_viewport := main.get_node(
		"UIPresentation/UIViewport"
	) as SubViewport
	assert(sell_action.visible and not sell_action.disabled)
	assert(sell_action.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert(sell_action.focus_mode == Control.FOCUS_ALL)
	assert(ui_viewport != null)
	await _activate_pointer_control(sell_action, ui_viewport)
	await process_frame
	assert(confirmation.visible)
	assert(confirm_button.visible and not confirm_button.disabled)
	assert(
		confirmation.z_index
		> (player_menu.get_node("%CoolerOuterWall") as Control).z_index
	)
	_sale_result.clear()
	await _activate_pointer_control(confirm_button, ui_viewport)
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


func _activate_pointer_control(
	control: Control,
	ui_viewport: SubViewport,
) -> void:
	var presenter := ui_viewport.get_parent() as SubViewportContainer
	assert(presenter != null)
	var local_center: Vector2 = control.get_global_transform_with_canvas() * (
		control.size * 0.5
	)
	var center: Vector2 = presenter.position + local_center * presenter.scale
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.push_input(motion, true)
	await process_frame
	assert(ui_viewport.gui_get_hovered_control() == control)
	for is_pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = center
		click.global_position = center
		click.pressed = is_pressed
		root.push_input(click, true)
		await process_frame


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


func _test_host_art_shop_purchase(
	main: Node,
	player: Player,
	shop_service: NetworkShopService,
) -> void:
	var interaction := main.get("_shop_interaction") as FishingShopInteraction
	assert(interaction != null)
	player.global_position = interaction.global_position
	for _frame: int in 4:
		await physics_frame
	var required_balance: int = (
		ArtShopStock.ART_KIT_PRICE + ArtShopStock.UPGRADE_PRICE * 3
	)
	if player.wallet.get_balance() < required_balance:
		assert(player.wallet.credit(required_balance - player.wallet.get_balance()))
	_shop_result.clear()
	assert(not shop_service.request_art_kit().is_empty())
	assert(not _shop_result.is_empty() and bool(_shop_result[1]))
	assert(player.bag.owns_item(ArtShopStock.ART_KIT_ITEM_ID))
	var item_catalog := main.get("item_catalog") as ItemCatalog
	assert(item_catalog != null)
	var art_item: ItemData = item_catalog.get_item_by_id(
		ArtShopStock.ART_KIT_ITEM_ID
	)
	assert(art_item != null and art_item.hotbar_allowed and art_item.equippable)
	assert(art_item.icon != null)
	assert(art_item.icon.resource_path.ends_with("/art/art_kit.png"))
	assert(player.hotbar.assign_item(0, ArtShopStock.ART_KIT_ITEM_ID))
	for product_id: StringName in [
		&"marker_ocean_teal", &"brush_2x", &"grid_32x",
	]:
		_shop_result.clear()
		assert(not shop_service.request_art_upgrade(product_id).is_empty())
		assert(not _shop_result.is_empty() and bool(_shop_result[1]))
		assert(player.art_unlocks.owns_product(product_id))
	assert(not shop_service.is_local_purchase_pending())


func _test_fishing_shop_sale_ui(
	main: Node,
	player: Player,
	catalog: FishPool,
	sale_service: NetworkSaleService,
	reservations: PlayerAssetReservationService,
) -> void:
	var interaction := main.get("_shop_interaction") as FishingShopInteraction
	var game_ui := main.get_node("%GameUI") as GameUI
	var shop := game_ui.get_node("%FishingShop") as FishingShop
	var player_menu := game_ui.get_node("%PlayerMenu") as PlayerMenu
	var shop_backdrop := main.get_node("%ShopBackdrop") as ColorRect
	var ui_viewport := main.get_node(
		"UIPresentation/UIViewport"
	) as SubViewport
	assert(
		interaction != null
		and shop != null
		and player_menu != null
		and shop_backdrop != null
		and ui_viewport != null
	)
	player.global_position = interaction.global_position
	for _frame: int in 4:
		await physics_frame
	var fish_catch := _make_catch(catalog.candidates[7])
	var reserved_catch := _make_catch(catalog.candidates[6])
	player.inventory.add_catch(fish_catch)
	player.inventory.add_catch(reserved_catch)
	var reservation_id := "shop-ui-reservation"
	assert(reservations.reserve(reservation_id, {
		"type": PlayerAssetReservationService.AttachmentType.FISH,
		"catch_id": str(reserved_catch.catch_id),
		"catch": reserved_catch.to_network_dict(),
	}))
	var balance_before: int = player.wallet.get_balance()
	assert(shop.open_shop())
	await process_frame
	assert(shop_backdrop.visible)
	assert(shop_backdrop.material is ShaderMaterial)
	assert(shop.has_node("InputBlocker") and not shop.has_node("Dimmer"))
	var shop_panel := shop.get_node("%ShopPanel") as PanelContainer
	assert(shop_panel != null and shop_panel.size == Vector2(980.0, 600.0))
	var shop_panel_style := shop_panel.get_theme_stylebox("panel") as StyleBoxFlat
	assert(shop_panel_style != null)
	assert(shop_panel_style.corner_radius_top_left == 24)
	var upgrade_grid := shop.get_node("%UpgradeGrid") as GridContainer
	assert(upgrade_grid != null and upgrade_grid.columns == 3)
	assert((shop.get_node("%Upgrades") as Control).visible)
	assert(not (shop.get_node("%Supplies") as Control).visible)
	for upgrade_name: String in [
		"ReelPurchase", "BarrierPurchase", "CoolerPurchase"
	]:
		var upgrade_button := shop.get_node("%%%s" % upgrade_name) as Button
		assert(upgrade_button != null)
		assert(upgrade_button.size == Vector2(144.0, 144.0))
		assert(upgrade_button.text.is_empty())
		assert(upgrade_button.icon != null)
		assert(upgrade_button.tooltip_text.contains("level"))
	assert(not shop.has_node("%ReelLevel"))
	assert(not shop.has_node("%BarrierEffect"))
	assert(not shop.has_node("%CoolerLevel"))
	var balance_coin := shop.get_node(
		"ShopPanel/Margin/Layout/Header/BalanceDisplay/CoinIcon"
	) as TextureRect
	assert(balance_coin != null and balance_coin.texture != null)
	assert(
		balance_coin.texture.resource_path.ends_with(
			"/shop/32_currency.png"
		)
	)
	for cost_name: String in ["ReelCost", "BarrierCost", "CoolerCost"]:
		var cost_display := shop.get_node("%%%s" % cost_name) as CurrencyAmount
		assert(cost_display != null)
		var cost_icon := cost_display.get_node("Icon") as TextureRect
		assert(cost_icon != null and cost_icon.texture != null)
		assert(
			cost_icon.texture.resource_path.ends_with(
				"/shop/32_currency.png"
			)
		)
	assert(not shop.has_node("ShopPanel/Margin/Layout/ModeTabs"))
	var shop_tabs: Array = shop.get("_shop_tabs") as Array
	assert(shop_tabs.size() == 6)
	var art_supplies_tab := shop_tabs[4] as Button
	assert(art_supplies_tab != null and art_supplies_tab.text == "Art Supplies")
	var sell_mode := shop_tabs[5] as Button
	assert(sell_mode != null and sell_mode.text == "Sell Fish")
	await _activate_pointer_control(art_supplies_tab, ui_viewport)
	await process_frame
	var stock_sections: Array[String] = []
	for child: Node in shop.get_node("%SuppliesList").get_children():
		if child is Label:
			stock_sections.append((child as Label).text)
	assert(stock_sections == ["art kit", "markers", "brushes", "grids"])
	var marker_icons := shop.find_children(
		"MarkerIcon", "TextureRect", true, false
	)
	assert(marker_icons.size() == ArtShopStock.MARKER_PRODUCTS.size())
	for index: int in marker_icons.size():
		var marker_icon := marker_icons[index] as TextureRect
		var marker_material := marker_icon.material as ShaderMaterial
		var product_id: StringName = ArtShopStock.MARKER_PRODUCTS[index]
		var color_id: StringName = PlayerArtUnlocks.color_id_for_product(
			product_id
		)
		assert(marker_icon.texture.resource_path.ends_with("art_kit_marker.png"))
		assert(marker_material != null)
		assert(
			marker_material.get_shader_parameter("marker_color")
			== SurfaceDrawingPalette.get_color(color_id)
		)
	var price_bubbles := shop.find_children(
		"PriceBubble", "PanelContainer", true, false
	)
	assert(not price_bubbles.is_empty())
	for price_bubble: Node in price_bubbles:
		var currency_icon := price_bubble.find_child(
			"CurrencyIcon", true, false
		) as TextureRect
		assert(currency_icon != null and currency_icon.texture != null)
		assert(
			currency_icon.texture.resource_path.ends_with(
				"/shop/32_currency.png"
			)
		)
	await _activate_pointer_control(sell_mode, ui_viewport)
	await process_frame
	assert(shop.visible and not player_menu.visible)
	assert(not shop.has_node("ShopPanel/Margin/Layout/Body/FishSales"))
	assert((shop.get_node("%ShopCoolerPage") as Control).visible)
	assert((shop.get_node("%ShopPanel") as Control).visible)
	assert(not (shop.get_node("ShopPanel/Margin/Layout/Body") as Control).visible)
	assert(not (shop.get_node("%Feedback") as Control).visible)
	var mounted_cooler := player_menu.get("_cooler_page") as Control
	assert(mounted_cooler != null and mounted_cooler.visible)
	assert(
		mounted_cooler.get_parent() == shop.get_node("%ShopCoolerMount")
	)
	var cooler_outer_wall := player_menu.get("_cooler_outer_wall") as Control
	var water_surface := player_menu.get("_cooler_water_surface") as ColorRect
	assert(cooler_outer_wall != null and cooler_outer_wall.visible)
	assert(water_surface.visible and water_surface.material is ShaderMaterial)
	var cooler_sort_option := player_menu.get("_cooler_sort_option") as Control
	await _activate_pointer_control(cooler_sort_option, ui_viewport)
	var cooler_choice_panel := cooler_sort_option.get("_choice_panel") as Control
	assert(cooler_choice_panel.visible)
	cooler_sort_option.call("close_choices")
	assert(
		StringName(
			(player_menu.get("_sale_buyer_override") as FishBuyerProfile).id
		) == NetworkSaleService.MAIN_SHOP_BUYER_ID
	)
	var fish_nodes: Dictionary = player_menu.get("_fish_nodes")
	var fish_button := fish_nodes.get(fish_catch.catch_id) as Button
	var reserved_button := fish_nodes.get(reserved_catch.catch_id) as Button
	assert(fish_button != null and fish_button.visible)
	assert(reserved_button != null and reserved_button.visible)
	await _activate_pointer_control(fish_button, ui_viewport)
	var sell_button := player_menu.get("_sell_bubble") as Button
	assert(sell_button.visible and not sell_button.disabled)
	await _activate_pointer_control(sell_button, ui_viewport)
	await process_frame
	var confirmation := player_menu.get("_sale_confirmation") as Control
	var confirm_button := player_menu.get("_confirm_sale_button") as Button
	assert(confirmation.visible)
	assert(
		confirmation.z_index
		> cooler_outer_wall.z_index
	)
	_sale_result.clear()
	await _activate_pointer_control(confirm_button, ui_viewport)
	await process_frame
	assert(not _sale_result.is_empty() and bool(_sale_result[1]))
	assert(not player.inventory.contains_catch_id(fish_catch.catch_id))
	assert(player.wallet.get_balance() == balance_before + fish_catch.sale_value)
	assert(not sale_service.is_local_sale_pending())
	assert(reservations.release(reservation_id))
	await _activate_pointer_control(shop_tabs[0] as Button, ui_viewport)
	await process_frame
	assert(shop.visible and (shop.get_node("%ShopPanel") as Control).visible)
	assert(not (shop.get_node("%ShopCoolerPage") as Control).visible)
	assert(not player_menu.is_shop_cooler_mounted())
	shop.close_shop()
	await shop.menu_visibility_changed
	assert(not shop.visible)


func _assert_sale(
	player: Player,
	sale_service: NetworkSaleService,
	catch_ids: Array[StringName],
	expected_success: bool,
	expect_request_id: bool = true,
	buyer_id: StringName = NetworkSaleService.PELICAN_BUYER_ID,
) -> void:
	var balance_before: int = player.wallet.get_balance()
	_sale_result.clear()
	var request_id: String = sale_service.request_local_sale(
		catch_ids, buyer_id
	)
	assert((not request_id.is_empty()) == expect_request_id)
	assert(not _sale_result.is_empty())
	assert(bool(_sale_result[1]) == expected_success)
	assert(not sale_service.is_local_sale_pending())
	if expected_success:
		var payout: int = int(_sale_result[4])
		assert(payout >= 0)
		assert(player.wallet.get_balance() == balance_before + payout)
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
