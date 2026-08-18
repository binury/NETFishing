extends SceneTree

const Catalog: ItemCatalog = preload("res://items/catalog/item_catalog.tres")
const Bluegill: FishData = preload("res://fish/species/bluegill/bluegill.tres")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := Node.new()
	root.add_child(state)
	var bag := PlayerBag.new()
	var catches := FishInventory.new()
	var storage_capacity := PlayerCoolerCapacity.new()
	var layout := PlayerInventoryLayout.new()
	var hotbar := PlayerHotbar.new()
	for node: Node in [bag, catches, storage_capacity, layout, hotbar]:
		state.add_child(node)
	bag.setup(Catalog)
	layout.setup(bag, catches, Catalog, storage_capacity)
	bag.set_inventory_layout(layout)
	catches.set_inventory_layout(layout)
	hotbar.setup(bag, Catalog, catches, layout)

	assert(bag.add_item(&"basic_fishing_rod", 1))
	assert(bag.add_item(&"coffee", 3))
	var fish_catch := _make_bluegill()
	assert(catches.add_catch(fish_catch))

	var inventory_grid := GeneralInventoryGrid.new()
	inventory_grid.set_slot_presentation(Vector2(78.0, 78.0), 10)
	root.add_child(inventory_grid)
	inventory_grid.setup(
		layout,
		bag,
		catches,
		hotbar,
		Catalog,
		PlayerInventoryLayout.InventoryContainer.INVENTORY,
	)
	var storage_grid := GeneralInventoryGrid.new()
	root.add_child(storage_grid)
	storage_grid.setup(
		layout,
		bag,
		catches,
		hotbar,
		Catalog,
		PlayerInventoryLayout.InventoryContainer.STORAGE,
	)
	await process_frame

	var inventory_slots: Array = inventory_grid.get("_slots")
	var storage_slots: Array = storage_grid.get("_slots")
	assert(inventory_slots.size() == 36)
	assert(inventory_grid.get_slots().size() == 9)
	assert(inventory_grid.custom_minimum_size == Vector2(782.0, 342.0))
	assert(storage_capacity.get_capacity() == 9)
	assert(storage_slots.size() == 72)
	assert(storage_grid.get_slots().size() == 9)
	assert((storage_slots[0] as Control).custom_minimum_size == Vector2(52.0, 52.0))
	assert((storage_slots[9] as GeneralInventorySlot).disabled)

	var coffee_slot := _find_slot(inventory_slots, &"coffee")
	assert(coffee_slot != null)
	(inventory_slots[7] as GeneralInventorySlot).call(
		"_drop_data",
		Vector2.ZERO,
		{"kind": "bag_item", "item_id": "coffee"},
	)
	assert(int(layout.get_entry(
		PlayerInventoryLayout.EntryKind.ITEM, &"coffee"
	).get("slot", -1)) == 7)
	assert(coffee_slot.entry_identity.is_empty())

	(storage_slots[0] as GeneralInventorySlot).call(
		"_drop_data",
		Vector2.ZERO,
		{"kind": "cooler_fish", "catch_id": String(fish_catch.catch_id)},
	)
	assert(layout.get_container(
		PlayerInventoryLayout.EntryKind.CATCH, fish_catch.catch_id
	) == PlayerInventoryLayout.InventoryContainer.STORAGE)

	assert(hotbar.assign_item(0, &"basic_fishing_rod"))
	assert(not layout.is_item_in_inventory(&"basic_fishing_rod"))
	(inventory_slots[8] as GeneralInventorySlot).call(
		"_drop_data",
		Vector2.ZERO,
		{"kind": "hotbar_slot", "slot_index": 0},
	)
	assert(hotbar.get_item_id(0).is_empty())
	assert(layout.is_item_in_inventory(&"basic_fishing_rod"))
	assert(int(layout.get_entry(
		PlayerInventoryLayout.EntryKind.ITEM, &"basic_fishing_rod"
	).get("slot", -1)) == 8)

	print("Inventory storage validation: PASS")
	state.free()
	inventory_grid.free()
	storage_grid.free()
	quit()


func _make_bluegill() -> FishCatch:
	var fish_catch := FishCatch.new()
	fish_catch.fish = Bluegill
	fish_catch.fish_id = Bluegill.id
	fish_catch.catch_id = &"bluegill:inventory_storage_test"
	fish_catch.weight_lb = Bluegill.get_minimum_weight()
	fish_catch.display_scale = Bluegill.get_display_scale_for_weight(
		fish_catch.weight_lb
	)
	fish_catch.sale_value = Bluegill.get_sale_value_for_weight(
		fish_catch.weight_lb
	)
	return fish_catch


func _find_slot(slots: Array, identity: StringName) -> GeneralInventorySlot:
	for candidate: Variant in slots:
		var slot := candidate as GeneralInventorySlot
		if slot != null and slot.entry_identity == identity:
			return slot
	return null
