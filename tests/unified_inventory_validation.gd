extends SceneTree

const ItemCatalogResource: ItemCatalog = preload(
	"res://items/catalog/item_catalog.tres"
)
const Bluegill: FishData = preload(
	"res://fish/species/bluegill/bluegill.tres"
)
const MainShopBuyer: FishBuyerProfile = preload(
	"res://economy/buyers/main_fishing_shop.tres"
)
const FishCatalogResource: FishPool = preload(
	"res://fish/pools/fish_catalog.tres"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := Node.new()
	get_root().add_child(root)
	var bag := PlayerBag.new()
	var catches := FishInventory.new()
	var capacity := PlayerCoolerCapacity.new()
	var layout := PlayerInventoryLayout.new()
	var hotbar := PlayerHotbar.new()
	for node: Node in [bag, catches, capacity, layout, hotbar]:
		root.add_child(node)
	bag.setup(ItemCatalogResource)
	layout.setup(bag, catches, ItemCatalogResource, capacity)
	bag.set_inventory_layout(layout)
	catches.set_inventory_layout(layout)
	hotbar.setup(bag, ItemCatalogResource, catches, layout)
	assert(PlayerInventoryLayout.INVENTORY_CAPACITIES == [9, 18, 27, 36])
	assert(PlayerCoolerCapacity.CAPACITIES == [9, 18, 27, 36, 45, 54, 63, 72])

	assert(bag.add_item(&"coffee", 3))
	assert(layout.get_inventory_count() == 1)
	assert(layout.get_inventory_capacity() == 9)
	assert(layout.get_hotbar_count() == 0)
	assert(hotbar.assign_item(2, &"coffee"))
	assert(layout.get_inventory_count() == 0)
	assert(layout.get_hotbar_count() == 1)
	assert(
		layout.get_container(PlayerInventoryLayout.EntryKind.ITEM, &"coffee")
		== PlayerInventoryLayout.InventoryContainer.HOTBAR
	)
	assert(hotbar.clear_slot(2))
	assert(layout.get_inventory_count() == 1)
	assert(layout.get_hotbar_count() == 0)

	var fish_catch := FishCatch.new()
	fish_catch.fish = Bluegill
	fish_catch.fish_id = Bluegill.id
	fish_catch.catch_id = &"bluegill:unified_inventory_test"
	fish_catch.weight_lb = Bluegill.get_minimum_weight()
	fish_catch.display_scale = Bluegill.get_display_scale_for_weight(
		fish_catch.weight_lb
	)
	fish_catch.sale_value = Bluegill.get_sale_value_for_weight(
		fish_catch.weight_lb
	)
	assert(catches.add_catch(fish_catch))
	assert(layout.get_inventory_count() == 2)
	assert(layout.move_entry_to_first_free(
		PlayerInventoryLayout.EntryKind.CATCH,
		fish_catch.catch_id,
		PlayerInventoryLayout.InventoryContainer.STORAGE,
	))
	assert(layout.get_inventory_count() == 1)
	assert(layout.get_storage_count() == 1)
	assert(layout.get_storage_capacity() == 9)
	var inventory_grid := GeneralInventoryGrid.new()
	root.add_child(inventory_grid)
	inventory_grid.set_slot_presentation(Vector2(78.0, 78.0), 10)
	inventory_grid.setup(
		layout,
		bag,
		catches,
		hotbar,
		ItemCatalogResource,
		PlayerInventoryLayout.InventoryContainer.INVENTORY,
	)
	var all_inventory_slots: Array = inventory_grid.get("_slots")
	assert(all_inventory_slots.size() == 36)
	assert(inventory_grid.get_slots().size() == 9)
	for slot_index: int in all_inventory_slots.size():
		var slot := all_inventory_slots[slot_index] as GeneralInventorySlot
		assert(slot.custom_minimum_size == Vector2(78.0, 78.0))
		assert(slot.disabled == (slot_index >= 9))
		assert(slot.tooltip_text.is_empty())
		var normal := slot.get_theme_stylebox("normal") as StyleBoxFlat
		assert(normal != null and normal.corner_radius_top_left == 39)
	var locked_slot := all_inventory_slots[9] as GeneralInventorySlot
	var locked_icon := locked_slot.get("_icon") as TextureRect
	assert(locked_icon != null)
	assert(is_equal_approx(locked_icon.size.x, 24.0))
	assert(is_equal_approx(locked_icon.size.y, 24.0))
	assert(is_equal_approx(locked_icon.modulate.a, 0.18))
	var staged_slot := all_inventory_slots[0] as GeneralInventorySlot
	staged_slot.set_staged(true)
	assert(
		(staged_slot.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
		== Color(UtilityPageStyle.OCEAN_SELECTED, 0.92)
	)
	staged_slot.set_staged(false)
	var sale_tray_slot := ShopSaleTraySlot.new()
	root.add_child(sale_tray_slot)
	assert(
		sale_tray_slot.custom_minimum_size
		== GeneralInventoryGrid.DEFAULT_SLOT_SIZE
	)
	var sale_tray_style := sale_tray_slot.get_theme_stylebox(
		"normal"
	) as StyleBoxFlat
	assert(sale_tray_style != null)
	assert(sale_tray_style.corner_radius_top_left == 26)
	var wallet := PlayerWallet.new()
	root.add_child(wallet)
	assert(wallet.restore_balance(15000))
	assert(layout.get_next_backpack_cost() == 1500)
	assert(layout.purchase_backpack(wallet))
	assert(layout.get_inventory_capacity() == 18)
	assert(inventory_grid.get_slots().size() == 18)
	assert(layout.get_next_backpack_cost() == 4500)
	assert(layout.purchase_backpack(wallet))
	assert(layout.get_inventory_capacity() == 27)
	assert(inventory_grid.get_slots().size() == 27)
	assert(layout.get_next_backpack_cost() == 9000)
	assert(layout.purchase_backpack(wallet))
	assert(layout.get_inventory_capacity() == 36)
	assert(inventory_grid.get_slots().size() == 36)
	assert(layout.get_next_backpack_cost() == -1)
	var storage_grid := GeneralInventoryGrid.new()
	root.add_child(storage_grid)
	storage_grid.setup(
		layout,
		bag,
		catches,
		hotbar,
		ItemCatalogResource,
		PlayerInventoryLayout.InventoryContainer.STORAGE,
	)
	var all_storage_slots: Array = storage_grid.get("_slots")
	assert(all_storage_slots.size() == 72)
	assert(storage_grid.get_slots().size() == 9)
	assert(
		(all_storage_slots[9] as GeneralInventorySlot).accessibility_name
		== "locked storage slot 10"
	)
	var storage_wallet := PlayerWallet.new()
	root.add_child(storage_wallet)
	assert(storage_wallet.restore_balance(9500))
	for expected_capacity: int in [18, 27, 36, 45, 54, 63, 72]:
		assert(capacity.purchase(storage_wallet))
		assert(layout.get_storage_capacity() == expected_capacity)
		assert(storage_grid.get_slots().size() == expected_capacity)
	assert(capacity.get_next_capacity() == -1)
	assert(capacity.get_next_cost() == -1)

	var saved := layout.to_save_data()
	assert(layout.move_entry_to_first_free(
		PlayerInventoryLayout.EntryKind.ITEM,
		&"coffee",
		PlayerInventoryLayout.InventoryContainer.STORAGE,
	))
	assert(layout.restore_from_save_data(saved))
	assert(layout.is_item_in_inventory(&"coffee"))
	assert(
		layout.get_container(
			PlayerInventoryLayout.EntryKind.CATCH,
			fish_catch.catch_id,
		) == PlayerInventoryLayout.InventoryContainer.STORAGE
	)

	var network_sale := NetworkSaleService.new()
	var session := NetworkSession.new()
	root.add_child(session)
	root.add_child(network_sale)
	network_sale.set("_session", session)
	network_sale.set("_item_catalog", ItemCatalogResource)
	network_sale.set("_fish_catalog", FishCatalogResource)
	var result: Dictionary = network_sale.call(
		"_build_authoritative_result",
		1,
		"mixed_sale_test",
		[],
		[{"item_id": "coffee", "quantity": 2}],
		MainShopBuyer,
	)
	assert(bool(result.get("accepted", false)))
	assert(int(result.get("payout", -1)) == 20)
	assert((result.get("items", []) as Array).size() == 1)

	print("Unified inventory validation: PASS")
	root.free()
	quit()
