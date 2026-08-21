class_name PlayerStorage
extends Control

const INPUT_OWNER: StringName = &"player_storage"

signal menu_visibility_changed(is_open: bool)

var _player: Player
var _fishing_spot: FishingSpot
var _interaction: PlayerStorageInteraction
var _layout: PlayerInventoryLayout
var _inventory_grid: GeneralInventoryGrid
var _storage_grid: GeneralInventoryGrid
var _inventory_count: Label
var _storage_count: Label
var _feedback: Label
var _prior_movement_enabled: bool = true
var _prior_camera_enabled: bool = true
var _prior_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	UtilityPageStyle.apply_page(self)
	_build_ui()
	hide()


func setup(
	player: Player,
	fishing_spot: FishingSpot,
	interaction: PlayerStorageInteraction,
	layout: PlayerInventoryLayout,
	bag: PlayerBag,
	fish_inventory: FishInventory,
	hotbar: PlayerHotbar,
	item_catalog: ItemCatalog,
) -> void:
	_player = player
	_fishing_spot = fishing_spot
	_interaction = interaction
	_layout = layout
	_inventory_grid.setup(
		layout,
		bag,
		fish_inventory,
		hotbar,
		item_catalog,
		PlayerInventoryLayout.InventoryContainer.INVENTORY,
	)
	_storage_grid.setup(
		layout,
		bag,
		fish_inventory,
		hotbar,
		item_catalog,
		PlayerInventoryLayout.InventoryContainer.STORAGE,
	)
	_inventory_grid.entry_selected.connect(
		_on_entry_selected.bind(
			PlayerInventoryLayout.InventoryContainer.STORAGE
		)
	)
	_storage_grid.entry_selected.connect(
		_on_entry_selected.bind(
			PlayerInventoryLayout.InventoryContainer.INVENTORY
		)
	)
	if _layout != null and not _layout.layout_changed.is_connected(_refresh):
		_layout.layout_changed.connect(_refresh)
	_refresh()


func set_world_interaction(interaction: PlayerStorageInteraction) -> void:
	_interaction = interaction


func open_storage() -> bool:
	if (
		visible
		or _player == null
		or _interaction == null
		or not _interaction.is_local_player_in_range()
		or _fishing_spot == null
		or not _fishing_spot.can_open_fishing_shop()
	):
		return false
	_prior_movement_enabled = _player.is_movement_enabled()
	_prior_camera_enabled = _player.is_camera_input_enabled()
	_prior_mouse_mode = Input.mouse_mode
	_player.set_movement_enabled(false)
	_player.set_camera_input_enabled(false)
	_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_feedback.text = "select an item to move it · drag to choose a slot"
	_refresh()
	show()
	call_deferred("_focus_first_slot")
	menu_visibility_changed.emit(true)
	return true


func close_storage(restore_controls: bool = true) -> void:
	if not visible:
		return
	var viewport := get_viewport()
	if viewport != null:
		viewport.gui_release_focus()
	hide()
	if _fishing_spot != null:
		_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, false)
	if restore_controls and _player != null:
		_player.set_movement_enabled(_prior_movement_enabled)
		_player.set_camera_input_enabled(_prior_camera_enabled)
	Input.mouse_mode = _prior_mouse_mode
	menu_visibility_changed.emit(false)


func close_for_range_exit() -> void:
	close_storage()


func close_for_water_recovery() -> void:
	close_storage(false)


func close_for_session_end() -> void:
	close_storage(false)


func consume_escape() -> bool:
	if not visible:
		return false
	close_storage()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	close_storage()
	get_viewport().set_input_as_handled()


func _on_entry_selected(
	kind: int,
	identity: StringName,
	target_container: int,
) -> void:
	if kind < 0 or identity.is_empty() or _layout == null:
		return
	if _layout.move_entry_to_first_free(kind, identity, target_container):
		_feedback.text = (
			"moved to storage"
			if target_container == PlayerInventoryLayout.InventoryContainer.STORAGE
			else "moved to inventory"
		)
	else:
		_feedback.text = (
			"storage is full"
			if target_container == PlayerInventoryLayout.InventoryContainer.STORAGE
			else "inventory is full"
		)


func _refresh() -> void:
	if _layout == null:
		return
	_inventory_grid.refresh()
	_storage_grid.refresh()
	_inventory_count.text = "%d / %d" % [
		_layout.get_inventory_count(),
		_layout.get_inventory_capacity(),
	]
	_storage_count.text = "%d / %d" % [
		_layout.get_storage_count(),
		_layout.get_storage_capacity(),
	]
	call_deferred("_connect_grid_focus")


func _focus_first_slot() -> void:
	var slot := _inventory_grid.get_first_occupied_slot()
	if slot == null:
		slot = _storage_grid.get_first_occupied_slot()
	if slot != null:
		slot.grab_focus()


func _connect_grid_focus() -> void:
	var inventory_slots := _inventory_grid.get_slots()
	var storage_slots := _storage_grid.get_slots()
	if inventory_slots.is_empty() or storage_slots.is_empty():
		return
	var row_count := mini(
		ceili(
			float(inventory_slots.size())
			/ float(PlayerInventoryLayout.INVENTORY_COLUMNS)
		),
		ceili(
			float(storage_slots.size())
			/ float(PlayerInventoryLayout.INVENTORY_COLUMNS)
		),
	)
	for row: int in row_count:
		var inventory_index := mini(
			row * PlayerInventoryLayout.INVENTORY_COLUMNS
			+ PlayerInventoryLayout.INVENTORY_COLUMNS - 1,
			inventory_slots.size() - 1,
		)
		var storage_index := mini(
			row * PlayerInventoryLayout.INVENTORY_COLUMNS,
			storage_slots.size() - 1,
		)
		inventory_slots[inventory_index].focus_neighbor_right = (
			inventory_slots[inventory_index].get_path_to(storage_slots[storage_index])
		)
		storage_slots[storage_index].focus_neighbor_left = (
			storage_slots[storage_index].get_path_to(inventory_slots[inventory_index])
		)


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 82
	mouse_filter = Control.MOUSE_FILTER_STOP
	var blocker := ColorRect.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.color = Color(0.02, 0.08, 0.10, 0.55)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(blocker)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-580.0, -310.0)
	panel.size = Vector2(1160.0, 620.0)
	panel.add_theme_stylebox_override(
		"panel",
		UtilityPageStyle.rounded_style(UtilityPageStyle.OCEAN_PANEL_DEEP, 22),
	)
	add_child(panel)
	var outer := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		outer.add_theme_constant_override(side, 20)
	panel.add_child(outer)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	outer.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var title := Label.new()
	title.text = "private storage"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = "Close storage"
	close.custom_minimum_size = Vector2(48.0, 48.0)
	close.flat = true
	close.add_theme_font_size_override("font_size", 30)
	close.pressed.connect(close_storage)
	header.add_child(close)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 18)
	layout.add_child(columns)
	var inventory_column := _build_column(columns, "inventory")
	_inventory_count = inventory_column["count"]
	_inventory_grid = GeneralInventoryGrid.new()
	(inventory_column["scroll"] as ScrollContainer).add_child(_inventory_grid)
	var storage_column := _build_column(columns, "storage")
	_storage_count = storage_column["count"]
	_storage_grid = GeneralInventoryGrid.new()
	(storage_column["scroll"] as ScrollContainer).add_child(_storage_grid)

	_feedback = Label.new()
	_feedback.text = "select an item to move it · drag to choose a slot"
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	layout.add_child(_feedback)


func _build_column(parent: HBoxContainer, title_text: String) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(550.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		UtilityPageStyle.rounded_style(UtilityPageStyle.OCEAN_PANEL_MID, 16),
	)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 22)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var count := Label.new()
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	header.add_child(count)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	return {"count": count, "scroll": scroll}
