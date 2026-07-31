extends SceneTree

const FishCatchType = preload("res://fish/fish_catch.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")
const LogbookPageScene = preload("res://ui/logbook_page.tscn")
const CatalogResource: FishPoolType = preload(
	"res://fish/pools/test_water_pool.tres"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.has_environment("NETFISHING_TEST_CREATE_ROOT"):
		var data_root := PlayerDataRoot.new()
		root.add_child(data_root)
		var result: Dictionary = data_root.create_unbound_root(
			OS.get_environment("NETFISHING_TEST_CREATE_ROOT")
		)
		assert(bool(result.get("ok", false)))
		data_root.queue_free()
		print("Logbook portable test root: PASS")
		quit()
		return
	_validate_catalog()
	await _validate_page()
	print("Logbook validation: PASS")
	quit()


func _validate_catalog() -> void:
	var expected_ids: Array[StringName] = [
		&"bluegill", &"bass", &"carp", &"sunfish",
	]
	assert(LogbookCatalog.CATALOG_ORDER == expected_ids)
	for index: int in expected_ids.size():
		var fish := CatalogResource.get_fish_by_id(expected_ids[index])
		assert(fish != null)
		assert(
			LogbookCatalog.category_for(fish)
			== LogbookCatalog.Category.OTHER
		)
		assert(LogbookCatalog.catalog_number(fish.id) == index + 1)
	assert(
		LogbookCatalog.empty_state(LogbookCatalog.Category.FRESH_WATER)
		== "No freshwater catches cataloged yet."
	)
	assert(
		LogbookCatalog.empty_state(LogbookCatalog.Category.SALT_WATER)
		== "No saltwater catches cataloged yet."
	)


func _validate_page() -> void:
	var collection := CollectionLogType.new()
	var inventory := FishInventoryType.new()
	root.add_child(collection)
	root.add_child(inventory)
	var page := LogbookPageScene.instantiate() as LogbookPage
	root.add_child(page)
	await process_frame
	page.setup(collection, inventory, CatalogResource)
	page.activate()
	await process_frame

	var entries: Dictionary = page.get("_entry_buttons")
	assert(entries.size() == 4)
	for entry_value: Variant in entries.values():
		var entry := entry_value as Button
		assert(entry != null)
		assert(entry.text.contains("???"))
		assert(entry.tooltip_text.is_empty())
		assert(entry.icon == null)
		assert(entry.accessibility_name == "Unknown catalog entry")
		for fish in CatalogResource.candidates:
			assert(not entry.text.contains(fish.display_name))

	page.call(
		"_select_category", LogbookCatalog.Category.FRESH_WATER
	)
	await create_timer(0.25).timeout
	assert((page.get("_entry_buttons") as Dictionary).is_empty())
	assert(
		(page.get("_empty_state") as Label).text
		== "No freshwater catches cataloged yet."
	)
	page.call("_select_category", LogbookCatalog.Category.SALT_WATER)
	await create_timer(0.25).timeout
	assert((page.get("_entry_buttons") as Dictionary).is_empty())
	assert(
		(page.get("_empty_state") as Label).text
		== "No saltwater catches cataloged yet."
	)
	page.call("_select_category", LogbookCatalog.Category.OTHER)
	await create_timer(0.25).timeout

	var bluegill = CatalogResource.get_fish_by_id(&"bluegill")
	collection.mark_discovered(&"bluegill")
	await process_frame
	entries = page.get("_entry_buttons")
	var known := entries.get(&"bluegill") as Button
	assert(known != null)
	assert(known.text == bluegill.display_name)
	assert(known.icon == bluegill.display_texture)

	var fish_catch := FishCatchType.new()
	fish_catch.fish = bluegill
	fish_catch.fish_id = bluegill.id
	fish_catch.weight_lb = bluegill.get_minimum_weight()
	fish_catch.display_scale = bluegill.get_display_scale_for_weight(
		fish_catch.weight_lb
	)
	fish_catch.sale_value = bluegill.get_sale_value_for_weight(
		fish_catch.weight_lb
	)
	fish_catch.ensure_identity()
	inventory.add_catch(fish_catch)
	page.call("_select_entry", &"bluegill", &"bluegill")
	await process_frame
	assert(_detail_text(page).contains("number owned\n1"))
	assert(_detail_text(page).contains("number caught\nUnknown"))
	assert(_detail_text(page).contains("body of water\nUnknown"))
	assert(_detail_text(page).contains("catalog number\n#001"))

	inventory.remove_catch_by_id(fish_catch.catch_id)
	await process_frame
	assert(_detail_text(page).contains("number owned\n0"))
	page.queue_free()
	collection.queue_free()
	inventory.queue_free()


func _detail_text(page: LogbookPage) -> String:
	var values: PackedStringArray = []
	var detail_body := page.get("_detail_body") as VBoxContainer
	for node: Node in detail_body.find_children("*", "Label", true, false):
		values.append((node as Label).text)
	return "\n".join(values)
