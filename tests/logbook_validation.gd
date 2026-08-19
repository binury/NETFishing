extends SceneTree

const FishCatchType = preload("res://fish/fish_catch.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishQualityType = preload("res://fish/fish_quality.gd")
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
	assert(CatalogResource.candidates.size() == 316)
	var ordered := LogbookCatalog.ordered_species(CatalogResource.candidates)
	assert(ordered.size() == 63)
	var previous_number: int = 0
	var catalog_numbers: Dictionary[int, bool] = {}
	for fish: FishDataType in CatalogResource.candidates:
		assert(fish != null)
		assert(fish.catalog_number > 0)
		assert(not catalog_numbers.has(fish.catalog_number))
		catalog_numbers[fish.catalog_number] = true
		assert(not LogbookCatalog.facts_for(fish).is_empty())
		assert(
			LogbookCatalog.facts_for(fish)
			== LogbookCatalog.facts_for(fish).to_lower()
		)
		assert(LogbookCatalog.facts_for(fish) != "unknown")
	for fish: FishDataType in ordered:
		assert(fish.active)
		assert(fish.catalog_number > previous_number)
		assert(LogbookCatalog.catalog_number(fish) == fish.catalog_number)
		previous_number = fish.catalog_number
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
	page.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	page.size = Vector2(1280.0, 720.0)
	await process_frame
	page.setup(collection, inventory, CatalogResource)
	page.activate()
	await process_frame
	assert(
		page.get("_category") == LogbookCatalog.Category.FRESH_WATER
	)
	assert((page.get("_catalog_grid") as GridContainer).columns == 4)
	var catalog_scroll := page.get("_catalog_scroll") as ScrollContainer
	assert(catalog_scroll != null and catalog_scroll.follow_focus)
	page.call(
		"_set_controller_zone",
		LogbookPage.ControllerZone.ENTRIES,
	)
	for _frame: int in 2:
		await process_frame
	var initial_entries: Array = (
		page.get("_entry_buttons") as Dictionary
	).values()
	assert(initial_entries.size() > 4)
	var final_entry := initial_entries.back() as Button
	final_entry.grab_focus()
	for _frame: int in 3:
		await process_frame
	assert(catalog_scroll.scroll_vertical > 0)
	page.reset_controller_zone()
	for _frame: int in 2:
		await process_frame
	var category_tabs: Array = page.get("_category_tabs") as Array
	var category_tab_categories: Array = (
		page.get("_category_tab_categories") as Array
	)
	assert(category_tab_categories == [
		LogbookCatalog.Category.FRESH_WATER,
		LogbookCatalog.Category.SALT_WATER,
		LogbookCatalog.Category.SHELLFISH,
		LogbookCatalog.Category.OTHER,
	])
	assert(category_tabs.size() == category_tab_categories.size())
	assert(
		LogbookCatalog.category_label(LogbookCatalog.Category.OTHER)
		== "Insects"
	)
	for tab_node: Variant in category_tabs:
		var category_tab := tab_node as Button
		assert(category_tab.size == LogbookPage.LOGBOOK_TAB_SIZE)
		var text_width: float = UtilityPageStyle.TuffyFont.get_string_size(
			category_tab.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			OrganizerTab.FONT_SIZE,
		).x
		assert(
			text_width + LogbookPage.LOGBOOK_TAB_TEXT_SIDE_INSET * 2.0
			<= category_tab.size.x
		)
	assert(
		(category_tabs[0] as Button).get_parent().position.x
		== LogbookPage.LOGBOOK_TAB_LEFT_INSET
	)
	var initial_detail_body := page.get("_detail_body") as VBoxContainer
	assert(not initial_detail_body.get_parent() is ScrollContainer)
	assert(
		page.call("_entry_label_text", "flathead catfish")
		== "flathead\ncatfish"
	)

	var shared_material: Material
	var silhouette_count: int = 0
	for category: LogbookCatalog.Category in [
		LogbookCatalog.Category.FRESH_WATER,
		LogbookCatalog.Category.SALT_WATER,
	]:
		page.call("_select_category", category)
		await create_timer(0.25).timeout
		var entries: Dictionary = page.get("_entry_buttons")
		assert(
			entries.size()
			== (26 if category == LogbookCatalog.Category.FRESH_WATER else 34)
		)
		for fish: FishDataType in LogbookCatalog.ordered_species(
			CatalogResource.candidates
		):
			if LogbookCatalog.category_for(fish) != category:
				continue
			var unknown_key := StringName(
				"unknown_%d" % LogbookCatalog.catalog_number(fish)
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
	assert(silhouette_count == 60)

	page.call("_select_category", LogbookCatalog.Category.SHELLFISH)
	await create_timer(0.25).timeout
	assert((page.get("_entry_buttons") as Dictionary).size() == 2)
	assert(
		(page.get("_entry_buttons") as Dictionary).has(&"unknown_3906")
	)
	assert(
		(page.get("_entry_buttons") as Dictionary).has(&"unknown_6406")
	)
	page.call("_select_category", LogbookCatalog.Category.OTHER)
	await create_timer(0.25).timeout
	assert((page.get("_entry_buttons") as Dictionary).size() == 1)
	assert(
		(page.get("_entry_buttons") as Dictionary).has(&"unknown_8001")
	)
	page.call("_select_category", LogbookCatalog.Category.FRESH_WATER)
	await create_timer(0.25).timeout

	var bluegill = CatalogResource.get_fish_by_id(&"bluegill")
	var bluegill_unknown := StringName(
		"unknown_%d" % bluegill.catalog_number
	)
	page.call("_select_entry", bluegill_unknown, StringName())
	assert(
		(page.get("_entry_buttons") as Dictionary)
		.get(bluegill_unknown) != null
	)
	collection.mark_discovered(&"bluegill")
	collection.mark_quality_discovered(
		&"bluegill",
		FishQualityType.Tier.BORING,
	)
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
	assert(not _detail_text(page).contains("number owned"))
	assert(_detail_text(page).contains("number caught\nunknown"))
	assert(_detail_text(page).contains("body of water\nfresh water"))
	assert(
		_detail_text(page).contains(
			"catalog number\n#%03d" % bluegill.catalog_number
		)
	)
	assert(_detail_text(page).contains("fish facts\n"))
	assert(_detail_text(page).contains(LogbookCatalog.facts_for(bluegill)))
	_validate_detail_field_fonts(page)
	_validate_handwritten_numeric_scale(page)
	_validate_detail_content_bounds(page)
	var detail_buttons: Array = page.get("_detail_buttons") as Array
	assert(detail_buttons.size() == 4)
	var portrait_detail := detail_buttons[0] as Button
	var facts_detail := detail_buttons[1] as Button
	var quality_detail := detail_buttons[2] as Button
	var stats_detail := detail_buttons[3] as Button
	assert(
		portrait_detail.get_node(portrait_detail.focus_neighbor_right)
		== facts_detail
	)
	assert(
		portrait_detail.get_node(portrait_detail.focus_neighbor_bottom)
		== quality_detail
	)
	assert(
		facts_detail.get_node(facts_detail.focus_neighbor_left)
		== portrait_detail
	)
	assert(
		facts_detail.get_node(facts_detail.focus_neighbor_bottom)
		== quality_detail
	)
	assert(
		quality_detail.get_node(quality_detail.focus_neighbor_bottom)
		== stats_detail
	)
	assert(
		stats_detail.get_node(stats_detail.focus_neighbor_top)
		== quality_detail
	)
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
		overlay_artwork.custom_minimum_size.x
		<= LogbookPage.PORTRAIT_VIEW_MAX_SIZE.x
		and overlay_artwork.custom_minimum_size.y
		<= LogbookPage.PORTRAIT_VIEW_MAX_SIZE.y
	)
	var overlay_card := _find_overlay_card(portrait_overlay)
	assert(overlay_card != null)
	assert(overlay_card.size == LogbookPage.DETAIL_OVERLAY_CARD_SIZE)
	assert(is_equal_approx(overlay_card.size.aspect(), 4.0 / 3.0))
	(page.get("_portrait_overlay_backdrop") as Button).pressed.emit()
	await process_frame
	assert(not portrait_overlay.visible)
	detail_buttons = page.get("_detail_buttons") as Array
	assert(detail_buttons.size() == 4)
	facts_detail = detail_buttons[1] as Button
	facts_detail.pressed.emit()
	await process_frame
	var overlay_text := page.get("_portrait_overlay_text") as Label
	assert(overlay_text.visible)
	assert(
		overlay_text.get_theme_font_size("font_size")
		== LogbookPage.DETAIL_OVERLAY_TEXT_FONT_SIZE
	)
	assert(
		overlay_text.horizontal_alignment
		== HORIZONTAL_ALIGNMENT_LEFT
	)
	assert(
		overlay_text.get_theme_font("font")
		== UtilityPageStyle.TuffyFont
	)
	(page.get("_portrait_overlay_backdrop") as Button).pressed.emit()
	await process_frame

	quality_detail.pressed.emit()
	await process_frame
	var quality_view := page.get("_portrait_overlay_quality_view") as Control
	assert(quality_view.visible)
	var quality_text: String = _descendant_label_text(quality_view)
	for quality: int in FishQualityType.TIER_COUNT:
		assert(quality_text.contains(FishQualityType.display_name(quality)))
	assert(quality_text.contains("●"))
	assert(quality_text.contains("○"))
	_validate_overlay_fonts(quality_view)
	(page.get("_portrait_overlay_backdrop") as Button).pressed.emit()
	await process_frame

	stats_detail.pressed.emit()
	await process_frame
	var stats_view := page.get("_portrait_overlay_stats_view") as Control
	assert(stats_view.visible)
	var stats_text: String = _descendant_label_text(stats_view)
	assert(stats_text.contains("catalog number"))
	assert(stats_text.contains("seasons"))
	assert(not stats_text.contains("number owned"))
	_validate_overlay_fonts(stats_view)
	(page.get("_portrait_overlay_backdrop") as Button).pressed.emit()
	await process_frame

	inventory.remove_catch_by_id(fish_catch.catch_id)
	await process_frame
	assert(not _detail_text(page).contains("number owned"))
	page.queue_free()
	collection.queue_free()
	inventory.queue_free()


func _detail_text(page: LogbookPage) -> String:
	var values: PackedStringArray = []
	var detail_body := page.get("_detail_body") as VBoxContainer
	for node: Node in detail_body.find_children("*", "Label", true, false):
		values.append((node as Label).text)
	return "\n".join(values)


func _descendant_label_text(parent: Node) -> String:
	var values: PackedStringArray = []
	for node: Node in parent.find_children("*", "Label", true, false):
		values.append((node as Label).text)
	return "\n".join(values)


func _validate_overlay_fonts(parent: Node) -> void:
	for node: Node in parent.find_children("*", "Label", true, false):
		assert(
			(node as Label).get_theme_font("font")
			== UtilityPageStyle.TuffyFont
		)


func _validate_detail_content_bounds(page: LogbookPage) -> void:
	var detail_body := page.get("_detail_body") as VBoxContainer
	var page_rect: Rect2 = (detail_body.get_parent() as Control).get_global_rect()
	for node: Node in detail_body.find_children("*", "Label", true, false):
		var label := node as Label
		var label_rect: Rect2 = label.get_global_rect()
		assert(
			label_rect.position.y >= page_rect.position.y - 0.5,
			"Label starts above logbook page: %s %s vs %s"
			% [label.text, label_rect, page_rect],
		)
		assert(
			label_rect.end.y <= page_rect.end.y + 0.5,
			"Label ends below logbook page: %s %s vs %s"
			% [label.text, label_rect, page_rect],
		)


func _find_overlay_card(parent: Node) -> PanelContainer:
	for node: Node in parent.find_children(
		"*", "PanelContainer", true, false
	):
		var panel := node as PanelContainer
		if panel.custom_minimum_size == LogbookPage.DETAIL_OVERLAY_CARD_SIZE:
			return panel
	return null


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
			"seasons",
			"weight range",
			"value range",
			"number caught",
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
		"seasons",
		"weight range",
		"value range",
		"number caught",
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
		elif label.text.begins_with("#"):
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
