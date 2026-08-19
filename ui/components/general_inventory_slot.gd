class_name GeneralInventorySlot
extends Button

signal entry_selected(kind: int, identity: StringName)
signal entry_moved
signal context_requested(slot: GeneralInventorySlot)
signal context_changed(slot: GeneralInventorySlot, text: String, active: bool)

const ItemDataType = preload("res://items/item_data.gd")
const LOCK_ICON: Texture2D = preload("res://ui/icons/pictograms/lock_light.png")

var slot_index: int = -1
var container: int = -1
var entry_kind: int = -1
var entry_identity: StringName
var _locked: bool = false

var _layout: PlayerInventoryLayout
var _bag: PlayerBag
var _fish_inventory: FishInventory
var _hotbar: PlayerHotbar
var _item_catalog: ItemCatalog
var _icon: TextureRect
var _quantity: Label
var _presentation_size := Vector2(52.0, 52.0)
var _context_text: String = ""
var _context_hovered: bool = false
var _context_focused: bool = false
var _staged: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pressed.connect(_on_pressed)
	focus_entered.connect(_set_context_focused.bind(true))
	focus_exited.connect(_set_context_focused.bind(false))
	mouse_entered.connect(_set_context_hovered.bind(true))
	mouse_exited.connect(_set_context_hovered.bind(false))
	gui_input.connect(_on_gui_input)
	_icon = TextureRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_quantity = Label.new()
	_quantity.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quantity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_quantity.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	_quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_quantity)
	_apply_presentation()


func set_presentation_size(presentation_size: Vector2) -> void:
	_presentation_size = presentation_size
	custom_minimum_size = presentation_size
	if is_node_ready():
		_apply_presentation()


func configure(
	new_slot_index: int,
	new_container: int,
	is_locked: bool,
	layout: PlayerInventoryLayout,
	bag: PlayerBag,
	fish_inventory: FishInventory,
	hotbar: PlayerHotbar,
	item_catalog: ItemCatalog,
) -> void:
	slot_index = new_slot_index
	container = new_container
	_locked = is_locked
	_layout = layout
	_bag = bag
	_fish_inventory = fish_inventory
	_hotbar = hotbar
	_item_catalog = item_catalog
	name = "InventorySlot%d" % slot_index
	refresh()


func set_locked(is_locked: bool) -> void:
	if _locked == is_locked:
		return
	_locked = is_locked
	refresh()


func refresh() -> void:
	call_deferred("_update_context_presence")
	entry_kind = -1
	entry_identity = StringName()
	_context_text = ""
	_icon.texture = null
	_quantity.text = ""
	disabled = _locked
	_apply_icon_geometry()
	if _locked:
		_icon.texture = LOCK_ICON
		_icon.modulate = Color(UtilityPageStyle.OCEAN_DISABLED, 0.18)
		var storage_slot := (
			container == PlayerInventoryLayout.InventoryContainer.STORAGE
		)
		_context_text = (
			"locked storage slot" if storage_slot else "locked backpack slot"
		)
		tooltip_text = ""
		accessibility_name = "%s %d" % [_context_text, slot_index + 1]
		return
	_icon.modulate = Color.WHITE
	_context_text = "empty slot"
	tooltip_text = ""
	accessibility_name = "empty %s slot %d" % [
		"storage"
		if container == PlayerInventoryLayout.InventoryContainer.STORAGE
		else "inventory",
		slot_index + 1,
	]
	if _layout == null:
		return
	var entry := _layout.get_entry_at(container, slot_index)
	if entry.is_empty():
		return
	entry_kind = int(entry.get("kind", -1))
	entry_identity = StringName(str(entry.get("identity", "")))
	if entry_kind == PlayerInventoryLayout.EntryKind.ITEM:
		var item: ItemDataType = (
			_item_catalog.get_item_by_id(entry_identity)
			if _item_catalog != null else null
		)
		if item == null:
			return
		_icon.texture = item.icon
		var quantity := _bag.get_quantity(entry_identity) if _bag != null else 0
		_quantity.text = "×%d" % quantity if quantity > 1 else ""
		_context_text = _item_context_text(item, quantity)
		accessibility_name = "%s, slot %d" % [item.display_name, slot_index + 1]
	elif entry_kind == PlayerInventoryLayout.EntryKind.CATCH:
		var fish_catch = (
			_fish_inventory.get_catch_by_id(entry_identity)
			if _fish_inventory != null else null
		)
		if fish_catch == null:
			return
		_icon.texture = fish_catch.fish.display_texture
		_context_text = _catch_context_text(fish_catch)
		var catch_name: String = FishQuality.qualified_name(
			fish_catch.fish.display_name, fish_catch.quality
		)
		accessibility_name = "%s, slot %d" % [catch_name, slot_index + 1]


func _on_pressed() -> void:
	if _locked:
		return
	entry_selected.emit(entry_kind, entry_identity)


func _on_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event != null
		and mouse_event.button_index == MOUSE_BUTTON_RIGHT
		and mouse_event.pressed
		and not _locked
		and not entry_identity.is_empty()
	):
		context_requested.emit(self)
		accept_event()


func _set_context_hovered(active: bool) -> void:
	_context_hovered = active
	_update_context_presence()


func _set_context_focused(active: bool) -> void:
	_context_focused = active
	_update_context_presence()


func _update_context_presence() -> void:
	if _locked or entry_identity.is_empty():
		context_changed.emit(self, "", false)
		return
	var active: bool = _context_hovered or _context_focused
	context_changed.emit(self, _context_text if active else "", active)


func set_move_source(active: bool) -> void:
	modulate = Color(1.0, 1.0, 1.0, 0.42) if active else Color.WHITE


func set_staged(active: bool) -> void:
	if _staged == active:
		return
	_staged = active
	_apply_style()


func _item_context_text(item: ItemDataType, quantity: int) -> String:
	var lines: Array[String] = [item.display_name]
	lines.append("%s • quantity %d" % [item.get_category_name(), quantity])
	if item.equippable:
		lines.append("equippable")
	elif item.usable:
		lines.append("usable")
	if not item.description.strip_edges().is_empty():
		lines.append(item.description.strip_edges())
	return "\n".join(lines)


func _catch_context_text(fish_catch: FishCatch) -> String:
	var catch_name: String = FishQuality.qualified_name(
		fish_catch.fish.display_name,
		fish_catch.quality,
	)
	return "%s\n%0.2f lb • value %d" % [
		catch_name,
		fish_catch.weight_lb,
		fish_catch.sale_value,
	]


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _locked or entry_identity.is_empty() or _icon.texture == null:
		return null
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(56.0, 56.0)
	preview.texture = _icon.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	if entry_kind == PlayerInventoryLayout.EntryKind.CATCH:
		return {
			"kind": "cooler_fish",
			"catch_id": String(entry_identity),
		}
	return {
		"kind": "bag_item",
		"item_id": String(entry_identity),
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if _locked or typeof(data) != TYPE_DICTIONARY or _layout == null:
		return false
	var kind := str((data as Dictionary).get("kind", ""))
	return kind in ["bag_item", "cooler_fish", "hotbar_slot"]


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(Vector2.ZERO, data):
		return
	var payload := data as Dictionary
	var payload_kind := str(payload.get("kind", ""))
	var moved: bool = false
	if payload_kind == "hotbar_slot":
		moved = (
			_hotbar != null
			and _hotbar.move_slot_to_container(
				int(payload.get("slot_index", -1)),
				container,
				slot_index,
			)
		)
	else:
		var kind := (
			PlayerInventoryLayout.EntryKind.CATCH
			if payload_kind == "cooler_fish"
			else PlayerInventoryLayout.EntryKind.ITEM
		)
		var identity := StringName(str(
			payload.get(
				"catch_id" if payload_kind == "cooler_fish" else "item_id",
				"",
			)
		))
		moved = _layout.move_entry(kind, identity, container, slot_index)
	if moved:
		entry_moved.emit()


func _apply_style() -> void:
	var radius: int = roundi(minf(_presentation_size.x, _presentation_size.y) * 0.5)
	var normal := UtilityPageStyle.rounded_style(
		Color(
			UtilityPageStyle.OCEAN_SELECTED
			if _staged else UtilityPageStyle.OCEAN_FIELD,
			0.92 if _staged else 0.88,
		),
		radius,
	)
	var hover := UtilityPageStyle.rounded_style(
		Color(UtilityPageStyle.OCEAN_SELECTED, 0.92), radius
	)
	var locked := UtilityPageStyle.rounded_style(
		Color(UtilityPageStyle.OCEAN_FIELD, 0.38), radius
	)
	for state: StringName in [&"normal", &"pressed"]:
		add_theme_stylebox_override(state, normal)
	add_theme_stylebox_override("disabled", locked)
	for state: StringName in [&"hover", &"focus"]:
		add_theme_stylebox_override(state, hover)


func _apply_presentation() -> void:
	_apply_icon_geometry()
	var is_large: bool = _presentation_size.x >= 70.0
	var quantity_width: float = 42.0 if is_large else 34.0
	var quantity_height: float = 20.0 if is_large else 17.0
	_quantity.position = Vector2(
		-quantity_width - (8.0 if is_large else 5.0),
		-quantity_height - (6.0 if is_large else 4.0),
	)
	_quantity.size = Vector2(quantity_width, quantity_height)
	_quantity.add_theme_font_size_override("font_size", 14 if is_large else 11)
	_apply_style()


func _apply_icon_geometry() -> void:
	var is_large: bool = _presentation_size.x >= 70.0
	var margin: float
	if _locked:
		var lock_size: float = 24.0 if is_large else 18.0
		margin = maxf(
			(_presentation_size.x - lock_size) * 0.5,
			0.0,
		)
	else:
		margin = 10.0 if is_large else 7.0
	_icon.offset_left = margin
	_icon.offset_top = margin
	_icon.offset_right = -margin
	_icon.offset_bottom = -margin
