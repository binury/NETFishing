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
	player_menu.free()
	print("Tackle order validation: PASS")
	quit()
