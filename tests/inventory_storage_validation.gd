extends SceneTree

const BagItemSpriteType = preload(
	"res://ui/components/bubble_menu/bag_item_sprite.gd"
)
const BagStorageSlotType = preload(
	"res://ui/components/bubble_menu/bag_storage_slot.gd"
)
const Catalog: ItemCatalog = preload(
	"res://items/catalog/item_catalog.tres"
)
const OwnedItemType = preload("res://items/owned_item.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const PlayerHotbarType = preload("res://inventory/player_hotbar.gd")
const PlayerMenuScene = preload("res://ui/player_menu.tscn")
const PlayerMenuType = preload("res://ui/player_menu.gd")

const EQUIPMENT_IDS: Array[StringName] = [
	&"basic_fishing_rod",
	&"art_kit",
	&"crab_net",
	&"magnet",
]
const ITEM_IDS: Array[StringName] = [
	&"coffee",
	&"energy_drink",
	&"snack",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var bag := PlayerBagType.new()
	bag.setup(Catalog)
	for item_id: StringName in EQUIPMENT_IDS + ITEM_IDS:
		assert(bag.add_item(item_id))
	for index: int in EQUIPMENT_IDS.size():
		assert(bag.get_storage_slot(EQUIPMENT_IDS[index]) == index)
	for index: int in ITEM_IDS.size():
		assert(bag.get_storage_slot(ITEM_IDS[index]) == index)

	assert(bag.move_item_to_storage_slot(&"basic_fishing_rod", 14))
	assert(bag.get_storage_slot(&"basic_fishing_rod") == 14)
	assert(bag.move_item_to_storage_slot(&"crab_net", 14))
	assert(bag.get_storage_slot(&"crab_net") == 14)
	assert(bag.get_storage_slot(&"basic_fishing_rod") == 2)
	var saved_record: Dictionary = bag.get_owned_item(
		&"crab_net"
	).to_save_dict()
	assert(int(saved_record.get("storage_slot", -1)) == 14)

	var legacy_equipment := OwnedItemType.new()
	legacy_equipment.item_id = &"basic_fishing_rod"
	var legacy_item := OwnedItemType.new()
	legacy_item.item_id = &"coffee"
	var legacy_records: Array[OwnedItemType] = [
		legacy_equipment,
		legacy_item,
	]
	var legacy_bag := PlayerBagType.new()
	legacy_bag.setup(Catalog)
	assert(legacy_bag.replace_all_items(legacy_records))
	assert(legacy_bag.get_storage_slot(&"basic_fishing_rod") == 0)
	assert(legacy_bag.get_storage_slot(&"coffee") == 0)
	legacy_bag.free()

	var menu := PlayerMenuScene.instantiate() as PlayerMenu
	root.add_child(menu)
	await process_frame
	menu.set("_bag", bag)
	var hotbar := PlayerHotbarType.new()
	hotbar.setup(bag, Catalog)
	menu.set("_hotbar", hotbar)
	menu.set("_item_catalog", Catalog)
	menu.set("_bag_view", PlayerMenuType.BagView.EQUIPMENT)
	menu.visible = true
	menu.call("_show_section_immediate", PlayerMenuType.Section.BAG)
	menu.call("_set_content_interactive", true)
	menu.call("_refresh_bag")
	await process_frame
	_validate_grid(menu, EQUIPMENT_IDS.size())

	var item_nodes: Dictionary = menu.get("_bag_item_nodes")
	var crab_node := item_nodes.get(&"crab_net") as BagItemSpriteType
	assert(crab_node != null)
	menu.set(
		"_controller_ownership",
		PlayerMenuType.ControllerOwnership.ITEM_LIST,
	)
	menu.call("_apply_inventory_controller_zone_focus_modes")
	crab_node.grab_focus()
	assert(bool(menu.call("_try_begin_controller_storage_placement")))
	await process_frame
	assert(
		menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.STORAGE_PLACEMENT
	)
	var slots: Array = menu.get("_bag_slot_nodes")
	var bottom_slot := slots[12] as BagStorageSlotType
	bottom_slot.grab_focus()
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	assert(bool(menu.call("_handle_controller_ownership_input", down)))
	assert(
		menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.HOTBAR_PLACEMENT
	)
	var up := InputEventAction.new()
	up.action = &"ui_up"
	up.pressed = true
	assert(bool(menu.call("_handle_controller_ownership_input", up)))
	assert(
		menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.STORAGE_PLACEMENT
	)
	await process_frame
	assert(root.gui_get_focus_owner() == bottom_slot)
	assert(StringName(menu.get("_controller_storage_identity")) == &"crab_net")
	var target_slot := slots[7] as BagStorageSlotType
	target_slot.grab_focus()
	menu.call("_confirm_controller_storage_placement")
	await process_frame
	assert(bag.get_storage_slot(&"crab_net") == 7)
	assert(
		menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.ITEM_LIST
	)

	menu.call("_show_bag_view", PlayerMenuType.BagView.CONSUMABLES)
	await process_frame
	_validate_grid(menu, ITEM_IDS.size())
	menu.call("_on_bag_item_dropped", &"coffee", 12)
	await process_frame
	assert(bag.get_storage_slot(&"coffee") == 12)

	menu.queue_free()
	hotbar.free()
	bag.free()
	await process_frame
	print("Inventory storage validation: PASS")
	quit()


func _validate_grid(menu: PlayerMenu, expected_items: int) -> void:
	var slots: Array = menu.get("_bag_slot_nodes")
	assert(slots.size() == PlayerBagType.MIN_STORAGE_SLOT_COUNT)
	var seen_positions: Dictionary[Vector2, bool] = {}
	for index: int in slots.size():
		var slot := slots[index] as BagStorageSlotType
		assert(slot != null)
		assert(slot.storage_slot_index == index)
		assert(not seen_positions.has(slot.position))
		seen_positions[slot.position] = true
		var normal := slot.get_theme_stylebox("normal") as StyleBoxFlat
		assert(normal != null)
		assert(normal.bg_color.a >= 0.7)
	assert((slots[1] as Control).position.x > (slots[0] as Control).position.x)
	assert((slots[5] as Control).position.y > (slots[0] as Control).position.y)
	var item_nodes := menu.get("_bag_item_nodes") as Dictionary
	assert(
		item_nodes.size() == expected_items,
		"expected %d visible bag items, found %d: %s" % [
			expected_items,
			item_nodes.size(),
			str(item_nodes.keys()),
		],
	)
