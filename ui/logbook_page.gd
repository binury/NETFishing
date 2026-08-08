class_name LogbookPage
extends Control

const CollectionLogType = preload("res://collection/collection_log.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishQualityType = preload("res://fish/fish_quality.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const SILHOUETTE_SHADER: Shader = preload(
	"res://ui/logbook_silhouette.gdshader"
)
const OrganizerTabType = preload("res://ui/components/organizer_tab.gd")
const InventoryNotepadType = preload(
	"res://ui/components/inventory_notepad.gd"
)
const LogbookPortraitType = preload(
	"res://ui/components/logbook_portrait.gd"
)

const DETAIL_FADE_DURATION: float = 0.12
const CATEGORY_FADE_DURATION: float = UIMotion.UTILITY_EXIT_DURATION
const HANDWRITTEN_NUMERIC_SCALE: float = 0.8
const PORTRAIT_VIEW_MAX_SIZE := Vector2(860.0, 480.0)
const INK := Color("251b10")
const MUTED_INK := Color("6d5b45")
const LOGBOOK_ARTWORK: Texture2D = preload(
	"res://ui/assets/logbook/ui_logbook.png"
)
const SCROLL_UP_TEXTURE: Texture2D = preload(
	"res://ui/icons/pictograms/arrow_dark_up_full.png"
)
const SCROLL_DOWN_TEXTURE: Texture2D = preload(
	"res://ui/icons/pictograms/arrow_dark_down_full.png"
)
const LOGBOOK_ARTWORK_SOURCE_SIZE := Vector2(512.0, 247.0)
const LEFT_PAGE_CONTENT_RECT := Rect2(56.0, 26.0, 190.0, 198.0)
const RIGHT_PAGE_CONTENT_RECT := Rect2(267.0, 26.0, 210.0, 198.0)
const LOGBOOK_TAB_LEFT_INSET: float = 122.0
const PAGE_CONTENT_SCALE: float = 0.97
const CATALOG_PORTRAIT_SIZE := Vector2(78.0, 36.0)
const CATALOG_ENTRY_SIZE := Vector2(92.0, 92.0)
const CATALOG_ROW_STEP: float = 98.0
const CATALOG_SNAP_DELAY: float = 0.12
const DETAIL_PORTRAIT_SIZE := Vector2(160.0, 88.0)
const DETAIL_BOTTOM_INSET: float = 35.0

var _collection_log: CollectionLogType
var _inventory: FishInventoryType
var _catalog: FishPoolType
var _category: WaterType.Type = WaterType.Type.FRESH_WATER
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
var _snapping_catalog_scroll: bool = false
var _catalog_scroll_snap_timer: Timer

var _category_tabs: Array[Button] = []
var _catalog_scroll: ScrollContainer
var _catalog_grid: GridContainer
var _catalog_scroll_up_indicator: TextureRect
var _catalog_scroll_down_indicator: TextureRect
var _empty_state: Label
var _detail_body: VBoxContainer
var _detail_portrait_button: Button
var _portrait_overlay: Control
var _portrait_overlay_backdrop: Button
var _portrait_overlay_artwork: LogbookPortraitType


func _ready() -> void:
	_silhouette_material = ShaderMaterial.new()
	_silhouette_material.shader = SILHOUETTE_SHADER
	_build_interface()
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
	_hide_portrait_overlay(false)
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
	if _portrait_overlay != null and _portrait_overlay.visible:
		_portrait_overlay_backdrop.grab_focus()
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
	outer.add_theme_constant_override("margin_top", 85)
	outer.add_theme_constant_override("margin_right", 52)
	outer.add_theme_constant_override("margin_bottom", 18)
	add_child(outer)

	var stack := Control.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outer.add_child(stack)

	var tabs := HBoxContainer.new()
	# Align the first flange with the authored left paper edge.
	tabs.position = Vector2(LOGBOOK_TAB_LEFT_INSET, 37.0)
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

	var book := Control.new()
	book.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	book.offset_top = 50.0
	book.z_index = 20
	book.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(book)

	var artwork := TextureRect.new()
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	artwork.texture = LOGBOOK_ARTWORK
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_SCALE
	artwork.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	book.add_child(artwork)

	var left_page := Control.new()
	left_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_artwork_rect(left_page, LEFT_PAGE_CONTENT_RECT)
	book.add_child(left_page)
	var left_layout := VBoxContainer.new()
	left_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	left_layout.add_theme_constant_override("separation", 8)
	left_page.add_child(left_layout)
	_apply_page_content_scale(left_layout)
	var scroll_indicator_top_lane := Control.new()
	scroll_indicator_top_lane.custom_minimum_size.y = 20.0
	scroll_indicator_top_lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_layout.add_child(scroll_indicator_top_lane)
	_empty_state = _label("", 18)
	_empty_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_state.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_state.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_layout.add_child(_empty_state)
	var catalog_scroll_margin := MarginContainer.new()
	catalog_scroll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	catalog_scroll_margin.add_theme_constant_override("margin_left", 20)
	left_layout.add_child(catalog_scroll_margin)
	_catalog_scroll = ScrollContainer.new()
	_catalog_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_catalog_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	_catalog_scroll.scroll_vertical_custom_step = CATALOG_ROW_STEP
	catalog_scroll_margin.add_child(_catalog_scroll)
	_catalog_grid = GridContainer.new()
	_catalog_grid.columns = 4
	_catalog_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_catalog_grid.add_theme_constant_override("h_separation", 6)
	_catalog_grid.add_theme_constant_override("v_separation", 6)
	_catalog_scroll.add_child(_catalog_grid)
	var scroll_indicator_bottom_lane := Control.new()
	scroll_indicator_bottom_lane.custom_minimum_size.y = 32.0
	scroll_indicator_bottom_lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_layout.add_child(scroll_indicator_bottom_lane)
	_configure_catalog_scroll_bar()
	_catalog_scroll_up_indicator = _make_scroll_indicator(
		"CatalogScrollUpIndicator",
		SCROLL_UP_TEXTURE,
		true,
	)
	left_page.add_child(_catalog_scroll_up_indicator)
	_catalog_scroll_down_indicator = _make_scroll_indicator(
		"CatalogScrollDownIndicator",
		SCROLL_DOWN_TEXTURE,
		false,
	)
	left_page.add_child(_catalog_scroll_down_indicator)

	var right_page := Control.new()
	right_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_artwork_rect(right_page, RIGHT_PAGE_CONTENT_RECT)
	book.add_child(right_page)
	_detail_body = VBoxContainer.new()
	_detail_body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override("separation", 16)
	right_page.add_child(_detail_body)
	_apply_page_content_scale(_detail_body)
	_show_no_selection()
	_build_portrait_overlay()


func _apply_artwork_rect(control: Control, source_rect: Rect2) -> void:
	control.anchor_left = source_rect.position.x / LOGBOOK_ARTWORK_SOURCE_SIZE.x
	control.anchor_top = source_rect.position.y / LOGBOOK_ARTWORK_SOURCE_SIZE.y
	control.anchor_right = source_rect.end.x / LOGBOOK_ARTWORK_SOURCE_SIZE.x
	control.anchor_bottom = source_rect.end.y / LOGBOOK_ARTWORK_SOURCE_SIZE.y
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _apply_page_content_scale(control: Control) -> void:
	control.scale = Vector2.ONE * PAGE_CONTENT_SCALE
	control.resized.connect(_center_scaled_content.bind(control))
	_center_scaled_content.call_deferred(control)


func _center_scaled_content(control: Control) -> void:
	if is_instance_valid(control):
		control.pivot_offset = control.size * 0.5


func _configure_catalog_scroll_bar() -> void:
	_catalog_scroll_snap_timer = Timer.new()
	_catalog_scroll_snap_timer.one_shot = true
	_catalog_scroll_snap_timer.wait_time = CATALOG_SNAP_DELAY
	_catalog_scroll_snap_timer.timeout.connect(_snap_catalog_scroll_to_row)
	_catalog_scroll.add_child(_catalog_scroll_snap_timer)
	var scroll_bar: VScrollBar = _catalog_scroll.get_v_scroll_bar()
	scroll_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_bar.focus_mode = Control.FOCUS_NONE
	scroll_bar.self_modulate = Color.TRANSPARENT
	scroll_bar.custom_minimum_size.x = 0.0
	scroll_bar.add_theme_constant_override("scroll_size", 0)
	var empty_style := StyleBoxEmpty.new()
	for style_name: StringName in [
		&"scroll",
		&"scroll_focus",
		&"grabber",
		&"grabber_highlight",
		&"grabber_pressed",
	]:
		scroll_bar.add_theme_stylebox_override(style_name, empty_style)
	scroll_bar.changed.connect(_refresh_catalog_scroll_indicators)
	scroll_bar.value_changed.connect(_on_catalog_scroll_value_changed)


func _make_scroll_indicator(
	indicator_name: String,
	indicator_texture: Texture2D,
	at_top: bool,
) -> TextureRect:
	var indicator := TextureRect.new()
	indicator.name = indicator_name
	indicator.anchor_left = 0.5
	indicator.anchor_right = 0.5
	indicator.anchor_top = 0.0 if at_top else 1.0
	indicator.anchor_bottom = indicator.anchor_top
	indicator.offset_left = -14.0
	indicator.offset_right = 14.0
	indicator.offset_top = -8.0 if at_top else -35.0
	indicator.offset_bottom = 20.0 if at_top else -7.0
	indicator.z_index = 30
	indicator.texture = indicator_texture
	indicator.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	indicator.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	indicator.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.visible = false
	return indicator


func _on_catalog_scroll_value_changed(value: float) -> void:
	if _snapping_catalog_scroll:
		return
	_catalog_scroll_snap_timer.start()
	_refresh_catalog_scroll_indicators()


func _snap_catalog_scroll_to_row() -> void:
	var scroll_bar: VScrollBar = _catalog_scroll.get_v_scroll_bar()
	var value: float = scroll_bar.value
	var maximum_scroll: float = scroll_bar.max_value - scroll_bar.page
	var snapped_value: float = clampf(
		roundf(value / CATALOG_ROW_STEP) * CATALOG_ROW_STEP,
		scroll_bar.min_value,
		maximum_scroll,
	)
	if not is_equal_approx(value, snapped_value):
		_snapping_catalog_scroll = true
		_catalog_scroll.scroll_vertical = roundi(snapped_value)
		_snapping_catalog_scroll = false
	_refresh_catalog_scroll_indicators()


func _refresh_catalog_scroll_indicators() -> void:
	if (
		_catalog_scroll == null
		or _catalog_scroll_up_indicator == null
		or _catalog_scroll_down_indicator == null
	):
		return
	var scroll_bar: VScrollBar = _catalog_scroll.get_v_scroll_bar()
	var maximum_scroll: float = scroll_bar.max_value - scroll_bar.page
	var has_overflow: bool = (
		_catalog_scroll.visible
		and maximum_scroll > scroll_bar.min_value + 0.5
	)
	_catalog_scroll_up_indicator.visible = (
		has_overflow and scroll_bar.value > scroll_bar.min_value + 0.5
	)
	_catalog_scroll_down_indicator.visible = (
		has_overflow and scroll_bar.value < maximum_scroll - 0.5
	)


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
	_refresh_catalog_scroll_indicators.call_deferred()


func _make_entry(fish: FishDataType, discovered: bool) -> Button:
	var entry := Button.new()
	entry.custom_minimum_size = CATALOG_ENTRY_SIZE
	entry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	entry.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	entry.toggle_mode = true
	entry.add_theme_stylebox_override("normal", _entry_style(false))
	entry.add_theme_stylebox_override("hover", _entry_style(true))
	entry.add_theme_stylebox_override("hover_pressed", _entry_style(true))
	entry.add_theme_stylebox_override("focus", _entry_style(true))
	entry.add_theme_stylebox_override("pressed", _entry_style(true))
	entry.text = ""
	if not discovered:
		entry.tooltip_text = ""
		entry.accessibility_name = "Unknown catalog entry"
		_add_entry_content(entry, fish.display_texture, "???", true)
	else:
		entry.tooltip_text = fish.display_name
		entry.accessibility_name = fish.display_name
		_add_entry_content(
			entry, fish.display_texture, fish.display_name, false
		)
	return entry


func _add_entry_content(
	entry: Button,
	portrait: Texture2D,
	entry_name: String,
	unknown: bool,
) -> void:
	var content_margin := MarginContainer.new()
	content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_margin.add_theme_constant_override("margin_left", 5)
	content_margin.add_theme_constant_override("margin_top", 8)
	content_margin.add_theme_constant_override("margin_right", 5)
	content_margin.add_theme_constant_override("margin_bottom", 2)
	entry.add_child(content_margin)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 4)
	content_margin.add_child(content)

	var portrait_view := LogbookPortraitType.new()
	portrait_view.configure(
		portrait,
		CATALOG_PORTRAIT_SIZE,
		_silhouette_material if unknown else null,
	)
	content.add_child(portrait_view)

	var name_label := _label(_entry_label_text(entry_name), 16)
	name_label.custom_minimum_size.y = 38.0
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(name_label)


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
	var summary_margin := MarginContainer.new()
	summary_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_margins(summary_margin, 40, 0, 40, 0)
	_detail_body.add_child(summary_margin)
	var summary_columns := HBoxContainer.new()
	summary_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_columns.add_theme_constant_override("separation", 24)
	summary_margin.add_child(summary_columns)

	var portrait_column := VBoxContainer.new()
	portrait_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_column.size_flags_stretch_ratio = 1.0
	portrait_column.add_theme_constant_override("separation", 4)
	summary_columns.add_child(portrait_column)
	var title := _label(fish.display_name, 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_column.add_child(title)
	if fish.display_texture != null:
		_detail_portrait_button = Button.new()
		_detail_portrait_button.custom_minimum_size = DETAIL_PORTRAIT_SIZE
		_detail_portrait_button.size_flags_horizontal = (
			Control.SIZE_SHRINK_CENTER
		)
		_detail_portrait_button.clip_contents = true
		_detail_portrait_button.tooltip_text = "View larger artwork"
		_detail_portrait_button.accessibility_name = (
			"View larger artwork for %s" % fish.display_name
		)
		_detail_portrait_button.add_theme_stylebox_override(
			"normal", _portrait_button_style(false)
		)
		_detail_portrait_button.add_theme_stylebox_override(
			"hover", _portrait_button_style(true)
		)
		_detail_portrait_button.add_theme_stylebox_override(
			"focus", _portrait_button_style(true)
		)
		_detail_portrait_button.add_theme_stylebox_override(
			"pressed", _portrait_button_style(true)
		)
		_detail_portrait_button.pressed.connect(
			_show_portrait_overlay.bind(fish.display_texture)
		)
		portrait_column.add_child(_detail_portrait_button)
		var artwork_center := CenterContainer.new()
		artwork_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork_center.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)
		_detail_portrait_button.add_child(artwork_center)
		var artwork := LogbookPortraitType.new()
		artwork.configure(
			fish.display_texture,
			DETAIL_PORTRAIT_SIZE,
		)
		artwork_center.add_child(artwork)

	var facts_column := VBoxContainer.new()
	facts_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts_column.size_flags_stretch_ratio = 1.0
	facts_column.add_theme_constant_override("separation", 6)
	summary_columns.add_child(facts_column)
	var facts_heading := _field_label("fish facts", 16)
	facts_column.add_child(facts_heading)
	var facts := _label(LogbookCatalog.facts_for(fish.id), 16)
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts_column.add_child(facts)
	_detail_body.add_child(_build_quality_progress(fish.id))

	var stats_anchor := VBoxContainer.new()
	stats_anchor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_anchor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stats_anchor.alignment = BoxContainer.ALIGNMENT_END
	_detail_body.add_child(stats_anchor)
	var stats_columns := HBoxContainer.new()
	stats_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_columns.add_theme_constant_override("separation", 28)
	stats_anchor.add_child(stats_columns)
	var left_stats := _make_stats_column()
	var right_stats := _make_stats_column()
	stats_columns.add_child(left_stats)
	stats_columns.add_child(right_stats)
	_add_detail_row(
		left_stats,
		"catalog number",
		"#%03d" % catalog_number if catalog_number > 0 else "unknown",
	)
	_add_detail_row(
		left_stats,
		"body of water",
		WaterType.label(fish.get_primary_water_type()).to_lower(),
	)
	_add_detail_row(
		left_stats,
		"weight range",
		"%.2f–%.2f lb" % [
			fish.get_minimum_weight(),
			fish.get_maximum_weight(),
		],
	)
	_add_detail_row(left_stats, "number caught", "unknown")
	_add_detail_row(right_stats, "rarity", fish.get_rarity_name().to_lower())
	_add_detail_row(right_stats, "time of day", _availability_text(fish))
	_add_detail_row(
		right_stats,
		"value range",
		"%d–%d fish coin" % [
			FishQualityType.apply_sale_value(
				fish.sell_value_min,
				FishQualityType.Tier.BORING,
			),
			FishQualityType.apply_sale_value(
				fish.sell_value_max,
				FishQualityType.Tier.SHINY,
			),
		],
	)
	_add_detail_row(
		right_stats,
		"number owned",
		str(_inventory.get_count(fish.id) if _inventory != null else 0),
	)
	var bottom_inset := Control.new()
	bottom_inset.custom_minimum_size.y = DETAIL_BOTTOM_INSET
	bottom_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_anchor.add_child(bottom_inset)


func _build_quality_progress(fish_id: StringName) -> VBoxContainer:
	var quality_section := VBoxContainer.new()
	quality_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quality_section.add_theme_constant_override("separation", 6)
	var discovered_count: int = 0
	for quality: int in FishQualityType.TIER_COUNT:
		if _collection_log.has_discovered_quality(fish_id, quality):
			discovered_count += 1
	var heading := _field_label(
		"quality collection • %d / %d" % [
			discovered_count,
			FishQualityType.TIER_COUNT,
		],
		17,
	)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", MUTED_INK)
	quality_section.add_child(heading)
	var tiers := VBoxContainer.new()
	tiers.add_theme_constant_override("separation", 6)
	quality_section.add_child(tiers)
	for quality: int in FishQualityType.TIER_COUNT:
		var row: HBoxContainer
		if quality % 2 == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 28)
			tiers.add_child(row)
		else:
			row = tiers.get_child(tiers.get_child_count() - 1) as HBoxContainer
		var discovered: bool = _collection_log.has_discovered_quality(
			fish_id,
			quality,
		)
		var tier := HBoxContainer.new()
		tier.alignment = BoxContainer.ALIGNMENT_CENTER
		tier.add_theme_constant_override("separation", 5)
		var quality_color: Color = UIPalette.get_quality_color(quality)
		var dot := _label("●" if discovered else "○", 17)
		dot.add_theme_color_override("font_color", quality_color)
		dot.modulate.a = 1.0 if discovered else 0.48
		tier.add_child(dot)
		var tier_label := _label(FishQualityType.display_name(quality), 16)
		tier_label.add_theme_color_override(
			"font_color",
			INK if discovered else MUTED_INK,
		)
		tier_label.modulate.a = 1.0 if discovered else 0.58
		tier.tooltip_text = (
			"%s quality collected"
			if discovered
			else "%s quality not yet collected"
		) % FishQualityType.display_name(quality)
		tier.add_child(tier_label)
		row.add_child(tier)
	return quality_section


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


func _add_detail_row(
	parent: VBoxContainer,
	row_name: String,
	value: String,
) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var heading := _field_label(row_name, 14)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color", MUTED_INK)
	var content := _handwritten_value_label(value.to_lower(), 16)
	content.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(heading)
	row.add_child(content)
	parent.add_child(row)


func _make_stats_column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.0
	column.add_theme_constant_override("separation", 12)
	return column


func _availability_text(fish: FishDataType) -> String:
	if fish.availability == null:
		return "unknown"
	if fish.availability.allow_day and fish.availability.allow_night:
		return "day and night"
	if fish.availability.allow_day:
		return "day"
	if fish.availability.allow_night:
		return "night"
	return "unknown"


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
	_detail_portrait_button = null
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


func _unknown_selection_key(fish: FishDataType) -> StringName:
	var number: int = LogbookCatalog.catalog_number(fish.id)
	return StringName("unknown_%d" % number)


func _label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override(
		"font", InventoryNotepadType.HANDWRITTEN_FONT
	)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	return label


func _field_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	return label


func _handwritten_value_label(text: String, font_size: int) -> Label:
	var adjusted_size: int = font_size
	if _contains_ascii_digit(text):
		adjusted_size = roundi(
			float(font_size) * HANDWRITTEN_NUMERIC_SCALE
		)
	return _label(text, adjusted_size)


func _contains_ascii_digit(text: String) -> bool:
	for codepoint: int in text.to_utf32_buffer():
		if codepoint >= 48 and codepoint <= 57:
			return true
	return false


func _entry_label_text(entry_name: String) -> String:
	var split_index: int = entry_name.find(" ")
	if split_index < 0:
		return entry_name
	return (
		entry_name.substr(0, split_index)
		+ "\n"
		+ entry_name.substr(split_index + 1)
	)


func _build_portrait_overlay() -> void:
	_portrait_overlay = Control.new()
	_portrait_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_overlay.z_index = 500
	_portrait_overlay.visible = false
	_portrait_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_overlay)

	_portrait_overlay_backdrop = Button.new()
	_portrait_overlay_backdrop.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_portrait_overlay_backdrop.text = ""
	_portrait_overlay_backdrop.tooltip_text = "Return to logbook"
	_portrait_overlay_backdrop.accessibility_name = "Return to logbook"
	_portrait_overlay_backdrop.focus_neighbor_top = NodePath(".")
	_portrait_overlay_backdrop.focus_neighbor_bottom = NodePath(".")
	_portrait_overlay_backdrop.focus_neighbor_left = NodePath(".")
	_portrait_overlay_backdrop.focus_neighbor_right = NodePath(".")
	_portrait_overlay_backdrop.focus_next = NodePath(".")
	_portrait_overlay_backdrop.focus_previous = NodePath(".")
	var transparent_style := StyleBoxEmpty.new()
	for state: StringName in [
		&"normal", &"hover", &"focus", &"pressed", &"disabled",
	]:
		_portrait_overlay_backdrop.add_theme_stylebox_override(
			state, transparent_style
		)
	_portrait_overlay_backdrop.pressed.connect(_hide_portrait_overlay)
	_portrait_overlay_backdrop.gui_input.connect(
		_on_portrait_overlay_backdrop_input
	)
	_portrait_overlay.add_child(_portrait_overlay_backdrop)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_overlay.add_child(center)
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_theme_stylebox_override("panel", _portrait_view_style())
	center.add_child(card)
	var margin := MarginContainer.new()
	_set_margins(margin, 22, 22, 22, 22)
	card.add_child(margin)
	_portrait_overlay_artwork = LogbookPortraitType.new()
	margin.add_child(_portrait_overlay_artwork)


func _show_portrait_overlay(portrait_texture: Texture2D) -> void:
	if portrait_texture == null or _portrait_overlay == null:
		return
	_portrait_overlay_artwork.configure_fitted(
		portrait_texture,
		PORTRAIT_VIEW_MAX_SIZE,
	)
	_portrait_overlay.visible = true
	_portrait_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_portrait_overlay_backdrop.grab_focus()


func _hide_portrait_overlay(restore_focus: bool = true) -> void:
	if _portrait_overlay == null or not _portrait_overlay.visible:
		return
	_portrait_overlay.visible = false
	_portrait_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if (
		restore_focus
		and _detail_portrait_button != null
		and is_instance_valid(_detail_portrait_button)
		and _active
		and _interactive
	):
		_detail_portrait_button.grab_focus()


func _on_portrait_overlay_backdrop_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_hide_portrait_overlay()
		get_viewport().set_input_as_handled()


func _portrait_button_style(highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(1.0, 0.96, 0.86, 0.48)
		if highlighted
		else Color.TRANSPARENT
	)
	style.set_border_width_all(0)
	style.set_corner_radius_all(12)
	return style


func _portrait_view_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff5dc")
	style.set_border_width_all(0)
	style.set_corner_radius_all(18)
	return style


func _entry_style(highlighted: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("fff5dc") if highlighted else Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(51)
	style.content_margin_left = 5
	style.content_margin_top = 5
	style.content_margin_right = 5
	style.content_margin_bottom = 5
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
