class_name LogbookPage
extends Control

const CollectionLogType = preload("res://collection/collection_log.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const SILHOUETTE_SHADER: Shader = preload(
	"res://ui/logbook_silhouette.gdshader"
)
const OrganizerTabType = preload("res://ui/components/organizer_tab.gd")

const DETAIL_FADE_DURATION: float = 0.12
const CATEGORY_FADE_DURATION: float = UIMotion.UTILITY_EXIT_DURATION
const INK := Color("251b10")
const MUTED_INK := Color("6d5b45")
const PAPER := Color("f2e6c9")
const PAPER_DARK := Color("e8d7b4")
const LOGBOOK_TAB_LEFT_INSET: float = 34.0

var _collection_log: CollectionLogType
var _inventory: FishInventoryType
var _catalog: FishPoolType
var _category: WaterType.Type = WaterType.Type.OTHER
var _selected_id: StringName
var _selected_entry_key: StringName
var _active: bool = false
var _interactive: bool = false
var _entry_buttons: Dictionary[StringName, Button] = {}
var _detail_generation: int = 0
var _detail_tween: Tween
var _category_generation: int = 0
var _category_tween: Tween
var _silhouette_material: ShaderMaterial

var _category_tabs: Array[Button] = []
var _catalog_scroll: ScrollContainer
var _catalog_grid: GridContainer
var _empty_state: Label
var _detail_body: VBoxContainer


func _ready() -> void:
	_silhouette_material = ShaderMaterial.new()
	_silhouette_material.shader = SILHOUETTE_SHADER
	_build_interface()
	resized.connect(_update_responsive_layout)
	_update_responsive_layout()
	set_interactive(false)


func setup(
	collection_log: CollectionLogType,
	inventory: FishInventoryType,
	catalog: FishPoolType,
) -> void:
	_collection_log = collection_log
	_inventory = inventory
	_catalog = catalog
	if not _collection_log.fish_discovered.is_connected(
		_on_fish_discovered
	):
		_collection_log.fish_discovered.connect(_on_fish_discovered)
	if not _collection_log.collection_changed.is_connected(
		_on_collection_changed
	):
		_collection_log.collection_changed.connect(_on_collection_changed)
	if not _inventory.catches_changed.is_connected(_on_inventory_changed):
		_inventory.catches_changed.connect(_on_inventory_changed)
	_refresh_catalog()


func activate() -> void:
	_active = true
	set_interactive(true)
	_refresh_catalog()
	_animate_tab_entry()


func deactivate() -> void:
	_active = false
	set_interactive(false)
	_settle_tabs_for_close()
	_cancel_detail_tween()
	_cancel_category_tween()


func set_interactive(value: bool) -> void:
	_interactive = value and _active
	mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if _interactive
		else Control.MOUSE_FILTER_IGNORE
	)
	for tab: Button in _category_tabs:
		tab.focus_mode = (
			Control.FOCUS_ALL if _interactive else Control.FOCUS_NONE
		)
		tab.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if _interactive and not tab.button_pressed
			else Control.MOUSE_FILTER_IGNORE
		)
	for entry: Button in _entry_buttons.values():
		entry.focus_mode = (
			Control.FOCUS_ALL if _interactive else Control.FOCUS_NONE
		)
		entry.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if _interactive
			else Control.MOUSE_FILTER_IGNORE
		)


func focus_initial() -> void:
	if not _active or not _interactive:
		return
	var selected := _entry_buttons.get(_selected_id) as Button
	if selected != null:
		selected.grab_focus()
	elif not _entry_buttons.is_empty():
		var first := _entry_buttons.values().front() as Button
		first.grab_focus()
	else:
		_category_tabs[int(_category)].grab_focus()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer.add_theme_constant_override("margin_left", 52)
	outer.add_theme_constant_override("margin_top", 116)
	outer.add_theme_constant_override("margin_right", 52)
	outer.add_theme_constant_override("margin_bottom", 18)
	add_child(outer)

	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(stack)

	var tabs := HBoxContainer.new()
	# The 26 px page corner plus 8 px clearance keeps the flange behind
	# the straight portion of the spread.
	tabs.position = Vector2(LOGBOOK_TAB_LEFT_INSET, 20.0)
	tabs.size = Vector2(384.0, 38.0)
	tabs.z_index = 10
	tabs.mouse_filter = Control.MOUSE_FILTER_PASS
	tabs.add_theme_constant_override("separation", 6)
	stack.add_child(tabs)
	for category: WaterType.Type in [
		WaterType.Type.FRESH_WATER,
		WaterType.Type.SALT_WATER,
		WaterType.Type.OTHER,
	]:
		var tab := OrganizerTabType.new()
		tab.custom_minimum_size = Vector2(124, 38)
		tab.toggle_mode = true
		tab.text = LogbookCatalog.category_label(category)
		tab.palette_index = int(category)
		tab.set_selected(category == _category, false)
		tab.pressed.connect(_select_category.bind(category))
		tabs.add_child(tab)
		_category_tabs.append(tab)
	_configure_category_focus()

	var book := HBoxContainer.new()
	book.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	book.offset_top = 50.0
	book.z_index = 20
	book.add_theme_constant_override("separation", 12)
	stack.add_child(book)

	var left_page := PanelContainer.new()
	left_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_page.size_flags_stretch_ratio = 1.12
	left_page.add_theme_stylebox_override(
		"panel", _paper_style(PAPER, true)
	)
	book.add_child(left_page)
	var left_margin := MarginContainer.new()
	_set_margins(left_margin, 18, 16, 18, 16)
	left_page.add_child(left_margin)
	var left_layout := VBoxContainer.new()
	left_layout.add_theme_constant_override("separation", 8)
	left_margin.add_child(left_layout)
	var heading := _label("catch catalog", 25)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_layout.add_child(heading)
	_empty_state = _label("", 18)
	_empty_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_state.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_layout.add_child(_empty_state)
	_catalog_scroll = ScrollContainer.new()
	_catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_catalog_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	left_layout.add_child(_catalog_scroll)
	_catalog_grid = GridContainer.new()
	_catalog_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_grid.add_theme_constant_override("h_separation", 8)
	_catalog_grid.add_theme_constant_override("v_separation", 8)
	_catalog_scroll.add_child(_catalog_grid)

	var gutter := ColorRect.new()
	gutter.custom_minimum_size.x = 10
	gutter.color = Color("795f3f")
	gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(gutter)

	var right_page := PanelContainer.new()
	right_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_page.add_theme_stylebox_override(
		"panel", _paper_style(PAPER_DARK, false)
	)
	book.add_child(right_page)
	var right_margin := MarginContainer.new()
	_set_margins(right_margin, 22, 16, 22, 16)
	right_page.add_child(right_margin)
	var details_scroll := ScrollContainer.new()
	details_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	right_margin.add_child(details_scroll)
	_detail_body = VBoxContainer.new()
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override("separation", 8)
	details_scroll.add_child(_detail_body)
	_show_no_selection()


func _refresh_catalog() -> void:
	if not is_node_ready():
		return
	var preserved_selection: StringName = _selected_id
	var preserved_entry_key: StringName = _selected_entry_key
	_clear_entries()
	var species: Array[FishDataType] = []
	if _catalog != null:
		species = LogbookCatalog.ordered_species(_catalog.candidates)
	for fish: FishDataType in species:
		if LogbookCatalog.category_for(fish) != _category:
			continue
		var discovered: bool = _collection_log.has_discovered(fish.id)
		var entry: Button = _make_entry(fish, discovered)
		var selection_key: StringName = (
			fish.id if discovered else _unknown_selection_key(fish)
		)
		_entry_buttons[selection_key] = entry
		entry.pressed.connect(
			_select_entry.bind(
				selection_key,
				fish.id if discovered else StringName(),
			)
		)
		entry.focus_entered.connect(
			_select_entry.bind(
				selection_key,
				fish.id if discovered else StringName(),
			)
		)
		_catalog_grid.add_child(entry)
	_empty_state.text = LogbookCatalog.empty_state(_category)
	_empty_state.visible = _entry_buttons.is_empty()
	_catalog_scroll.visible = not _entry_buttons.is_empty()
	if (
		not preserved_selection.is_empty()
		and _entry_buttons.has(preserved_selection)
	):
		_selected_id = preserved_selection
		_selected_entry_key = preserved_selection
	elif _entry_buttons.has(preserved_entry_key):
		_selected_id = StringName()
		_selected_entry_key = preserved_entry_key
	else:
		_selected_id = StringName()
		_selected_entry_key = StringName()
	_refresh_selection_styles()
	_refresh_details(false)
	set_interactive(_interactive)


func _make_entry(fish: FishDataType, discovered: bool) -> Button:
	var entry := Button.new()
	entry.custom_minimum_size = Vector2(220, 138)
	entry.toggle_mode = true
	entry.clip_text = true
	entry.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	entry.add_theme_font_size_override("font_size", 17)
	entry.add_theme_color_override("font_color", INK)
	entry.add_theme_color_override("font_focus_color", INK)
	entry.add_theme_color_override("font_hover_color", INK)
	entry.add_theme_stylebox_override("normal", _entry_style(false))
	entry.add_theme_stylebox_override("hover", _entry_style(true))
	entry.add_theme_stylebox_override("focus", _entry_style(true))
	entry.add_theme_stylebox_override("pressed", _entry_style(true))
	if not discovered:
		entry.text = ""
		entry.tooltip_text = ""
		entry.accessibility_name = "Unknown catalog entry"
		_add_unknown_entry_content(entry, fish.display_texture)
	else:
		entry.text = fish.display_name
		entry.icon = fish.display_texture
		entry.add_theme_constant_override("icon_max_width", 118)
		entry.expand_icon = true
		entry.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		entry.tooltip_text = fish.display_name
		entry.accessibility_name = fish.display_name
	return entry


func _add_unknown_entry_content(
	entry: Button,
	portrait: Texture2D,
) -> void:
	var content_margin := MarginContainer.new()
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 7)
	content_margin.add_theme_constant_override("margin_top", 7)
	content_margin.add_theme_constant_override("margin_right", 7)
	content_margin.add_theme_constant_override("margin_bottom", 7)
	entry.add_child(content_margin)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 2)
	content_margin.add_child(content)

	var portrait_view := TextureRect.new()
	portrait_view.custom_minimum_size = Vector2(0.0, 64.0)
	portrait_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_view.texture = portrait
	portrait_view.material = _silhouette_material
	content.add_child(portrait_view)

	var unknown_name := Label.new()
	unknown_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unknown_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	unknown_name.text = "???"
	unknown_name.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	unknown_name.add_theme_font_size_override("font_size", 18)
	unknown_name.add_theme_color_override("font_color", INK)
	content.add_child(unknown_name)

	var discovery_hint := Label.new()
	discovery_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discovery_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	discovery_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	discovery_hint.text = "Catch this creature to learn more."
	discovery_hint.add_theme_font_override(
		"font", UtilityPageStyle.TuffyFont
	)
	discovery_hint.add_theme_font_size_override("font_size", 12)
	discovery_hint.add_theme_color_override("font_color", MUTED_INK)
	content.add_child(discovery_hint)


func _select_category(category: WaterType.Type) -> void:
	if category == _category:
		return
	_category = category
	_selected_id = StringName()
	_selected_entry_key = StringName()
	for index: int in _category_tabs.size():
		(_category_tabs[index] as OrganizerTabType).set_selected(
			index == int(_category)
		)
	_begin_category_transition()


func _configure_category_focus() -> void:
	for index: int in _category_tabs.size():
		var tab: Button = _category_tabs[index]
		tab.focus_neighbor_left = tab.get_path_to(
			_category_tabs[maxi(index - 1, 0)]
		)
		tab.focus_neighbor_right = tab.get_path_to(
			_category_tabs[mini(index + 1, _category_tabs.size() - 1)]
		)


func _animate_tab_entry() -> void:
	for index: int in _category_tabs.size():
		(_category_tabs[index] as OrganizerTabType).animate_entrance(
			float(index) * 0.025
		)


func _settle_tabs_for_close() -> void:
	for tab: OrganizerTabType in _category_tabs:
		tab.settle_for_close()


func _begin_category_transition() -> void:
	_cancel_category_tween()
	_category_generation += 1
	var generation: int = _category_generation
	var restore_interactive: bool = _interactive
	set_interactive(false)
	_category_tween = create_tween()
	_category_tween.tween_method(
		_set_category_content_alpha,
		1.0,
		0.0,
		CATEGORY_FADE_DURATION * 0.5,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_category_tween.tween_callback(
		func() -> void:
			if generation != _category_generation:
				return
			_refresh_catalog()
			_set_category_content_alpha(0.0)
	)
	_category_tween.tween_method(
		_set_category_content_alpha,
		0.0,
		1.0,
		CATEGORY_FADE_DURATION * 0.5,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_category_tween.finished.connect(
		func() -> void:
			if generation != _category_generation:
				return
			_category_tween = null
			_set_category_content_alpha(1.0)
			set_interactive(restore_interactive)
			focus_initial(),
		CONNECT_ONE_SHOT,
	)


func _cancel_category_tween() -> void:
	_category_generation += 1
	if _category_tween != null:
		_category_tween.kill()
		_category_tween = null
	_set_category_content_alpha(1.0)


func _set_category_content_alpha(alpha: float) -> void:
	if _catalog_scroll != null:
		_catalog_scroll.modulate.a = alpha
	if _empty_state != null:
		_empty_state.modulate.a = alpha
	if _detail_body != null:
		_detail_body.modulate.a = alpha


func _select_entry(entry_key: StringName, fish_id: StringName) -> void:
	if fish_id.is_empty():
		_selected_id = StringName()
		_selected_entry_key = entry_key
		_refresh_selection_styles()
		_show_unknown()
		return
	if (
		_collection_log == null
		or not _collection_log.has_discovered(fish_id)
	):
		return
	_selected_id = fish_id
	_selected_entry_key = entry_key
	_refresh_selection_styles()
	_refresh_details(true)


func _refresh_details(animate: bool) -> void:
	if _selected_id.is_empty():
		_show_no_selection()
		return
	if (
		_collection_log == null
		or not _collection_log.has_discovered(_selected_id)
	):
		_show_unknown()
		return
	var fish: FishDataType = (
		_catalog.get_fish_by_id(_selected_id)
		if _catalog != null
		else null
	)
	if fish == null:
		_show_no_selection()
		return
	var rebuild: Callable = _build_known_details.bind(fish)
	if animate:
		_crossfade_details(rebuild)
	else:
		rebuild.call()


func _build_known_details(fish: FishDataType) -> void:
	_clear_details()
	var catalog_number: int = LogbookCatalog.catalog_number(fish.id)
	var title := _label(fish.display_name, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_body.add_child(title)
	if fish.display_texture != null:
		var artwork := TextureRect.new()
		artwork.custom_minimum_size = Vector2(0, 150)
		artwork.texture = fish.display_texture
		artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_detail_body.add_child(artwork)
	_add_detail_row(
		"catalog number",
		"#%03d" % catalog_number if catalog_number > 0 else "Unknown",
	)
	_add_detail_row("rarity", fish.get_rarity_name())
	_add_detail_row("body of water", WaterType.label(fish.get_primary_water_type()))
	_add_detail_row("time of day", _availability_text(fish))
	_add_detail_row(
		"weight range",
		"%.2f–%.2f lb" % [
			fish.get_minimum_weight(),
			fish.get_maximum_weight(),
		],
	)
	_add_detail_row(
		"value range",
		"%d–%d fish coin" % [
			fish.sell_value_min,
			fish.sell_value_max,
		],
	)
	_add_detail_row("number caught", "Unknown")
	_add_detail_row(
		"number owned",
		str(_inventory.get_count(fish.id) if _inventory != null else 0),
	)
	_add_detail_row("facts", "Unknown")


func _show_no_selection() -> void:
	_clear_details()
	var instruction := _label("Select an entry to read its catch record.", 21)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instruction.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_body.add_child(instruction)


func _show_unknown() -> void:
	_clear_details()
	var unknown := _label("???", 34)
	unknown.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_body.add_child(unknown)
	var instruction := _label("Catch this creature to learn more.", 20)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_body.add_child(instruction)


func _add_detail_row(row_name: String, value: String) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 1)
	var heading := _label(row_name, 15)
	heading.add_theme_color_override("font_color", MUTED_INK)
	var content := _label(value, 20)
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(heading)
	row.add_child(content)
	_detail_body.add_child(row)


func _availability_text(fish: FishDataType) -> String:
	if fish.availability == null:
		return "Unknown"
	if fish.availability.allow_day and fish.availability.allow_night:
		return "day and night"
	if fish.availability.allow_day:
		return "day"
	if fish.availability.allow_night:
		return "night"
	return "Unknown"


func _crossfade_details(rebuild: Callable) -> void:
	_cancel_detail_tween()
	_detail_generation += 1
	var generation: int = _detail_generation
	_detail_tween = create_tween()
	_detail_tween.tween_property(
		_detail_body, "modulate:a", 0.0, DETAIL_FADE_DURATION * 0.5
	)
	_detail_tween.tween_callback(
		func() -> void:
			if generation == _detail_generation:
				rebuild.call()
	)
	_detail_tween.tween_property(
		_detail_body, "modulate:a", 1.0, DETAIL_FADE_DURATION * 0.5
	)
	_detail_tween.finished.connect(
		func() -> void:
			if generation == _detail_generation:
				_detail_tween = null,
		CONNECT_ONE_SHOT,
	)


func _cancel_detail_tween() -> void:
	_detail_generation += 1
	if _detail_tween != null:
		_detail_tween.kill()
		_detail_tween = null
	if _detail_body != null:
		_detail_body.modulate.a = 1.0


func _clear_entries() -> void:
	for child: Node in _catalog_grid.get_children():
		_catalog_grid.remove_child(child)
		child.queue_free()
	_entry_buttons.clear()


func _clear_details() -> void:
	for child: Node in _detail_body.get_children():
		_detail_body.remove_child(child)
		child.queue_free()


func _refresh_selection_styles() -> void:
	for fish_id: StringName in _entry_buttons:
		_entry_buttons[fish_id].button_pressed = (
			fish_id == _selected_entry_key
		)


func _on_fish_discovered(fish_id: StringName) -> void:
	if _catalog == null:
		return
	var fish: FishDataType = _catalog.get_fish_by_id(fish_id)
	if fish == null:
		return
	if _selected_entry_key == _unknown_selection_key(fish):
		_selected_id = fish_id
		_selected_entry_key = fish_id
	_refresh_catalog()


func _on_collection_changed() -> void:
	_refresh_catalog()


func _on_inventory_changed() -> void:
	_refresh_details(false)


func _update_responsive_layout() -> void:
	if _catalog_grid == null:
		return
	_catalog_grid.columns = 1 if size.x < 900.0 else 2


func _unknown_selection_key(fish: FishDataType) -> StringName:
	var number: int = LogbookCatalog.catalog_number(fish.id)
	return StringName("unknown_%d" % number)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	return label


func _paper_style(color: Color, left: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("9b7a4f")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 26 if left else 6
	style.corner_radius_bottom_left = 32 if left else 6
	style.corner_radius_top_right = 6 if left else 28
	style.corner_radius_bottom_right = 6 if left else 34
	return style


func _entry_style(selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff5dc") if selected else Color("eadcbd")
	style.border_color = Color("247a8b") if selected else Color("9b7a4f")
	style.set_border_width_all(3 if selected else 2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_top = 8
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	return style


func _set_margins(
	container: MarginContainer,
	left: int,
	top: int,
	right: int,
	bottom: int,
) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_bottom", bottom)
