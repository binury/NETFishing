extends SceneTree

const FishCatchType = preload("res://fish/fish_catch.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const LogbookPageScene = preload("res://ui/logbook_page.tscn")
const CatalogResource: FishPoolType = preload(
	"res://fish/pools/fish_catalog.tres"
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
		&"bluegill",
		&"bass",
		&"carp",
		&"sunfish",
		&"catfish_blue",
		&"catfish_channel",
		&"catfish_flathead",
		&"catfish_white",
	]
	assert(LogbookCatalog.CATALOG_ORDER == expected_ids)
	for index: int in expected_ids.size():
		var fish := CatalogResource.get_fish_by_id(expected_ids[index])
		assert(fish != null)
		var expected_category: WaterType.Type = (
			WaterType.Type.SALT_WATER
			if expected_ids[index] in [&"bass", &"sunfish"]
			else WaterType.Type.FRESH_WATER
		)
		assert(
			LogbookCatalog.category_for(fish)
			== expected_category
		)
		assert(LogbookCatalog.catalog_number(fish.id) == index + 1)
	assert(
		LogbookCatalog.empty_state(WaterType.Type.SALT_WATER)
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

	var shared_material: Material
	var silhouette_count: int = 0
	for category: WaterType.Type in [
		WaterType.Type.FRESH_WATER,
		WaterType.Type.SALT_WATER,
	]:
		page.call("_select_category", category)
		await create_timer(0.25).timeout
		var entries: Dictionary = page.get("_entry_buttons")
		assert(entries.size() == (6 if category == WaterType.Type.FRESH_WATER else 2))
		for fish: FishDataType in LogbookCatalog.ordered_species(
			CatalogResource.candidates
		):
			if LogbookCatalog.category_for(fish) != category:
				continue
			var unknown_key := StringName(
				"unknown_%d" % LogbookCatalog.catalog_number(fish.id)
			)
			var entry := entries.get(unknown_key) as Button
			assert(entry != null)
			assert(entry.text.is_empty())
			assert(entry.tooltip_text.is_empty())
			assert(entry.icon == null)
			assert(entry.accessibility_name == "Unknown catalog entry")
			assert(_has_visible_unknown_name(entry))
			var portrait := _find_unknown_portrait(entry)
			assert(portrait != null)
			assert(portrait.texture == fish.display_texture)
			assert(
				portrait.expand_mode
				== TextureRect.EXPAND_IGNORE_SIZE
			)
			assert(
				portrait.stretch_mode
				== TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			)
			assert(portrait.material is ShaderMaterial)
			if shared_material == null:
				shared_material = portrait.material
			else:
				assert(portrait.material == shared_material)
			assert(_texture_has_transparency(portrait.texture))
			silhouette_count += 1
			for candidate: FishDataType in CatalogResource.candidates:
				assert(not entry.text.contains(candidate.display_name))
				assert(
					not entry.tooltip_text.contains(
						candidate.display_name
					)
				)
				assert(
					not entry.accessibility_name.contains(
						candidate.display_name
					)
				)
	assert(silhouette_count == 8)

	page.call("_select_category", WaterType.Type.OTHER)
	await create_timer(0.25).timeout
	assert((page.get("_entry_buttons") as Dictionary).is_empty())
	assert(
		(page.get("_empty_state") as Label).text
		== "No entries available."
	)
	page.call("_select_category", WaterType.Type.FRESH_WATER)
	await create_timer(0.25).timeout

	var bluegill = CatalogResource.get_fish_by_id(&"bluegill")
	page.call("_select_entry", &"unknown_1", StringName())
	assert(
		(page.get("_entry_buttons") as Dictionary)
		.get(&"unknown_1") != null
	)
	collection.mark_discovered(&"bluegill")
	await process_frame
	var entries: Dictionary = page.get("_entry_buttons")
	var known := entries.get(&"bluegill") as Button
	assert(known != null)
	assert(known.text == bluegill.display_name)
	assert(known.icon == bluegill.display_texture)
	assert(_find_unknown_portrait(known) == null)
	assert(known.button_pressed)

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
	assert(_detail_text(page).contains("body of water\nFresh Water"))
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


func _find_unknown_portrait(entry: Button) -> TextureRect:
	var pending: Array[Node] = [entry]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is TextureRect:
			return node as TextureRect
		pending.append_array(node.get_children())
	return null


func _has_visible_unknown_name(entry: Button) -> bool:
	var pending: Array[Node] = [entry]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Label and (node as Label).text == "???":
			return true
		pending.append_array(node.get_children())
	return false


func _texture_has_transparency(texture: Texture2D) -> bool:
	var image: Image = texture.get_image()
	return image != null and image.detect_alpha() != Image.ALPHA_NONE
