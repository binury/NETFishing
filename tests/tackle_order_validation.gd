extends SceneTree

const Catalog: ItemCatalog = preload("res://items/catalog/item_catalog.tres")
const PlayerMenuType = preload("res://ui/player_menu.gd")

const EXPECTED_BAIT_ORDER: Array[StringName] = [
	&"worms",
	&"snails",
	&"shrimp",
	&"squid_chunks",
	&"whole_sardine",
	&"whole_anchovy",
	&"luminous_roe",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player_menu := PlayerMenuType.new() as PlayerMenu
	player_menu.set("_item_catalog", Catalog)
	var tackle_items: Array[OwnedItem] = []
	for item_id: StringName in [
		&"luminous_roe",
		&"whole_anchovy",
		&"shrimp",
		&"snails",
		&"whole_sardine",
		&"squid_chunks",
		&"worms",
	]:
		var owned := OwnedItem.new()
		owned.item_id = item_id
		owned.quantity = 1
		tackle_items.append(owned)
	tackle_items.sort_custom(
		func(first: OwnedItem, second: OwnedItem) -> bool:
			return bool(player_menu.call(
				"_sort_tackle_items", first, second
			))
	)
	var sorted_ids: Array[StringName] = []
	for owned: OwnedItem in tackle_items:
		sorted_ids.append(owned.item_id)
	assert(sorted_ids == EXPECTED_BAIT_ORDER)
	var bag := PlayerBag.new()
	bag.setup(Catalog)
	assert(bag.add_item(&"worms", 1))
	assert(bag.add_item(&"shrimp", 1))
	var worms_slot: int = bag.get_storage_slot(&"worms")
	var shrimp_slot: int = bag.get_storage_slot(&"shrimp")
	assert(worms_slot >= 0 and shrimp_slot >= 0 and worms_slot != shrimp_slot)
	assert(bag.move_item_to_storage_slot(&"worms", shrimp_slot))
	assert(bag.get_storage_slot(&"worms") == shrimp_slot)
	assert(bag.get_storage_slot(&"shrimp") == worms_slot)
	bag.free()
	player_menu.free()
	print("Tackle order validation: PASS")
	quit()
