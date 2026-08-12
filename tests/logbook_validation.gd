extends SceneTree

const FishCatchType = preload("res://fish/fish_catch.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const LogbookPortraitType = preload(
	"res://ui/components/logbook_portrait.gd"
)
const InventoryNotepadType = preload(
	"res://ui/components/inventory_notepad.gd"
)
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
		&"tuna_albacore",
		&"tuna_bigeye",
		&"tuna_bluefin",
		&"tuna_skipjack",
		&"tuna_yellowfin",
		&"goby_round",
		&"salmon_atlantic",
		&"salmon_chum",
		&"salmon_coho",
		&"salmon_pink",
		&"salmon_sockeye",
		&"anchovy_european",
		&"anchovy_northern",
		&"chub_european",
		&"chub_flame",
		&"chub_lake",
		&"goldfish",
		&"goldfish_bubbleeye",
		&"grouper_gulf",
		&"grouper_red",
		&"mackerel_atlantic",
		&"mackerel_cero",
		&"mackerel_chub",
		&"mackerel_king",
		&"mackerel_spanish",
		&"marlin_black",
		&"marlin_blue",
		&"marlin_white",
		&"pomfret_black",
		&"pomfret_chinese",
		&"pomfret_golden",
		&"pomfret_white",
		&"sailfish",
		&"sauger",
		&"saugeye",
		&"snapper_lane",
		&"snapper_mangrove",
		&"snapper_mutton",
		&"snapper_red",
		&"swordfish",
		&"trout_cutthroat",
		&"trout_golden",
		&"trout_rainbow",
		&"trout_steelhead",
		&"walleye",
	]
	assert(LogbookCatalog.CATALOG_ORDER == expected_ids)
	for index: int in expected_ids.size():
		var fish := CatalogResource.get_fish_by_id(expected_ids[index])
		assert(fish != null)
		assert(not LogbookCatalog.facts_for(fish.id).is_empty())
		assert(
			LogbookCatalog.facts_for(fish.id)
			== LogbookCatalog.facts_for(fish.id).to_lower()
		)
		if LogbookCatalog.FISH_FACTS.has(fish.id):
			assert(LogbookCatalog.facts_for(fish.id) != "unknown")
		else:
			assert(LogbookCatalog.facts_for(fish.id) == "unknown")
		var expected_category: WaterType.Type = (
			WaterType.Type.SALT_WATER
			if expected_ids[index] in [
				&"bass",
				&"sunfish",
				&"tuna_albacore",
				&"tuna_bigeye",
				&"tuna_bluefin",
				&"tuna_skipjack",
				&"tuna_yellowfin",
				&"salmon_atlantic",
				&"salmon_chum",
				&"salmon_coho",
				&"salmon_pink",
				&"salmon_sockeye",
				&"anchovy_european",
				&"anchovy_northern",
				&"grouper_gulf",
				&"grouper_red",
				&"mackerel_atlantic",
				&"mackerel_cero",
				&"mackerel_chub",
				&"mackerel_king",
				&"mackerel_spanish",
				&"marlin_black",
				&"marlin_blue",
				&"marlin_white",
				&"pomfret_black",
				&"pomfret_chinese",
				&"pomfret_golden",
				&"pomfret_white",
				&"sailfish",
				&"snapper_lane",
				&"snapper_mangrove",
				&"snapper_mutton",
				&"snapper_red",
				&"swordfish",
			]
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
	assert(page.get("_category") == WaterType.Type.FRESH_WATER)
	assert((page.get("_catalog_grid") as GridContainer).columns == 4)
	var initial_detail_body := page.get("_detail_body") as VBoxContainer
	assert(not initial_detail_body.get_parent() is ScrollContainer)
	assert(
		page.call("_entry_label_text", "flathead catfish")
		== "flathead\ncatfish"
	)

	var shared_material: Material
	var silhouette_count: int = 0
	for category: WaterType.Type in [
		WaterType.Type.FRESH_WATER,
		WaterType.Type.SALT_WATER,
	]:
		page.call("_select_category", category)
		await create_timer(0.25).timeout
		var entries: Dictionary = page.get("_entry_buttons")
		assert(entries.size() == (19 if category == WaterType.Type.FRESH_WATER else 34))
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
			var portrait: LogbookPortraitType = _find_portrait(entry)
			assert(portrait != null)
			assert(portrait.source_texture == fish.display_texture)
			assert(
				portrait.custom_minimum_size
				== LogbookPage.CATALOG_PORTRAIT_SIZE
			)
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
	assert(silhouette_count == 53)

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
	assert(known.custom_minimum_size.x == known.custom_minimum_size.y)
	_validate_entry_bubble_styles(known)
	assert(known.text.is_empty())
	assert(known.icon == null)
	assert(_has_visible_name(known, bluegill.display_name))
	var known_portrait: LogbookPortraitType = _find_portrait(known)
	assert(known_portrait != null)
	assert(known_portrait.source_texture == bluegill.display_texture)
	assert(known_portrait.material == null)
	assert(known.button_pressed)
	_validate_handwritten_logbook_font(page)

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
	assert(_detail_text(page).contains("number caught\nunknown"))
	assert(_detail_text(page).contains("body of water\nfresh water"))
	assert(_detail_text(page).contains("catalog number\n#001"))
	assert(_detail_text(page).contains("fish facts\n"))
	assert(_detail_text(page).contains(LogbookCatalog.facts_for(&"bluegill")))
	_validate_detail_field_fonts(page)
	_validate_handwritten_numeric_scale(page)
	var portrait_button := page.get("_detail_portrait_button") as Button
	assert(portrait_button != null)
	portrait_button.pressed.emit()
	await process_frame
	var portrait_overlay := page.get("_portrait_overlay") as Control
	assert(portrait_overlay.visible)
	var overlay_artwork := (
		page.get("_portrait_overlay_artwork") as LogbookPortraitType
	)
	assert(overlay_artwork.source_texture == bluegill.display_texture)
	assert(
		overlay_artwork.custom_minimum_size.x <= 860.0
		and overlay_artwork.custom_minimum_size.y <= 480.0
	)
	(page.get("_portrait_overlay_backdrop") as Button).pressed.emit()
	await process_frame
	assert(not portrait_overlay.visible)

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


func _find_portrait(entry: Button) -> LogbookPortraitType:
	var pending: Array[Node] = [entry]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is LogbookPortraitType:
			return node as LogbookPortraitType
		pending.append_array(node.get_children())
	return null


func _has_visible_unknown_name(entry: Button) -> bool:
	return _has_visible_name(entry, "???")


func _has_visible_name(entry: Button, expected_name: String) -> bool:
	var pending: Array[Node] = [entry]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Label and (node as Label).text == expected_name:
			return true
		pending.append_array(node.get_children())
	return false


func _validate_handwritten_logbook_font(page: LogbookPage) -> void:
	var detail_body := page.get("_detail_body") as VBoxContainer
	for node: Node in detail_body.find_children("*", "Label", true, false):
		var label := node as Label
		if label.text.begins_with("quality collection"):
			continue
		if label.text in [
			"fish facts",
			"catalog number",
			"rarity",
			"body of water",
			"time of day",
			"weight range",
			"value range",
			"number caught",
			"number owned",
		]:
			continue
		assert(
			label.get_theme_font("font")
			== InventoryNotepadType.HANDWRITTEN_FONT
		)


func _validate_detail_field_fonts(page: LogbookPage) -> void:
	var detail_body := page.get("_detail_body") as VBoxContainer
	var field_names: Array[String] = [
		"fish facts",
		"catalog number",
		"rarity",
		"body of water",
		"time of day",
		"weight range",
		"value range",
		"number caught",
		"number owned",
	]
	for node: Node in detail_body.find_children("*", "Label", true, false):
		var label := node as Label
		if label.text.begins_with("quality collection"):
			assert(label.get_theme_font("font") == UtilityPageStyle.TuffyFont)
			continue
		if label.text not in field_names:
			continue
		assert(label.get_theme_font("font") == UtilityPageStyle.TuffyFont)
		if label.text != "fish facts":
			assert(
				label.horizontal_alignment
				== HORIZONTAL_ALIGNMENT_CENTER
			)


func _validate_handwritten_numeric_scale(page: LogbookPage) -> void:
	var detail_body := page.get("_detail_body") as VBoxContainer
	var text_value: Label
	var numeric_value: Label
	for node: Node in detail_body.find_children("*", "Label", true, false):
		var label := node as Label
		if label.text == "common":
			text_value = label
		elif label.text == "#001":
			numeric_value = label
	assert(text_value != null)
	assert(numeric_value != null)
	assert(
		numeric_value.get_theme_font_size("font_size")
		< text_value.get_theme_font_size("font_size")
	)


func _validate_entry_bubble_styles(entry: Button) -> void:
	var normal := entry.get_theme_stylebox("normal") as StyleBoxFlat
	var hover := entry.get_theme_stylebox("hover") as StyleBoxFlat
	var pressed := entry.get_theme_stylebox("pressed") as StyleBoxFlat
	assert(normal != null)
	assert(hover != null)
	assert(pressed != null)
	assert(is_zero_approx(normal.bg_color.a))
	assert(hover.bg_color.a > 0.0)
	assert(pressed.bg_color.a > 0.0)
	assert(hover.border_width_left == 0)
	assert(pressed.border_width_left == 0)
	assert(hover.corner_radius_top_left == 51)


func _texture_has_transparency(texture: Texture2D) -> bool:
	var image: Image = texture.get_image()
	return image != null and image.detect_alpha() != Image.ALPHA_NONE
