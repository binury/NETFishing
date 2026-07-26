class_name HotbarSlot
extends Button

signal item_hovered(slot_index: int, item_id: StringName)
signal item_hover_ended(slot_index: int)
signal item_drag_started
signal item_drag_finished

const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const PlayerHotbarType = preload("res://inventory/player_hotbar.gd")

var slot_index: int = 0
var _hotbar: PlayerHotbarType
var _bag: PlayerBagType
var _catalog: ItemCatalogType
var _drag_enabled: bool = false
var _drag_in_progress: bool = false
var _slot_number_label: Label
var _quantity_label: Label


func setup(
	index: int,
	hotbar: PlayerHotbarType,
	bag: PlayerBagType,
	catalog: ItemCatalogType,
) -> void:
	slot_index = index
	_hotbar = hotbar
	_bag = bag
	_catalog = catalog
	custom_minimum_size = Vector2(50, 50)
	expand_icon = true
	focus_mode = Control.FOCUS_ALL
	_slot_number_label = _create_corner_label(str(slot_index + 1))
	_quantity_label = _create_corner_label("", true)
	pressed.connect(_select_slot)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	refresh()


func set_drag_enabled(enabled: bool) -> void:
	_drag_enabled = enabled
	mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if enabled
		else Control.MOUSE_FILTER_IGNORE
	)


func refresh() -> void:
	if _hotbar == null:
		return
	var item_id: StringName = _hotbar.get_item_id(slot_index)
	var item: ItemDataType = (
		_catalog.get_item_by_id(item_id)
		if _catalog != null and not item_id.is_empty()
		else null
	)
	icon = item.icon if item != null else null
	var quantity: int = (
		_bag.get_quantity(item_id)
		if _bag != null and not item_id.is_empty()
		else 0
	)
	var quantity_text: String = (
		"×%d" % quantity
		if item != null and item.stackable and quantity > 1
		else ""
	)
	text = ""
	_quantity_label.text = quantity_text
	_quantity_label.visible = not quantity_text.is_empty()
	tooltip_text = (
		item.display_name if item != null else "Empty hotbar slot"
	)
	button_pressed = slot_index == _hotbar.get_selected_slot()


func _create_corner_label(
	label_text: String,
	bottom_right: bool = false,
) -> Label:
	var label := Label.new()
	label.text = label_text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", UIPalette.TEXT)
	if bottom_right:
		label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		label.position = Vector2(-22.0, -20.0)
	else:
		label.position = Vector2(5.0, 2.0)
	add_child(label)
	return label


func _gui_input(event: InputEvent) -> void:
	if (
		_drag_enabled
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
		and _hotbar != null
	):
		_hotbar.clear_slot(slot_index)
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not _drag_enabled or _hotbar == null:
		return null
	var item_id: StringName = _hotbar.get_item_id(slot_index)
	if item_id.is_empty():
		return null
	var item: ItemDataType = _catalog.get_item_by_id(item_id)
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(44, 44)
	preview.texture = item.icon if item != null else null
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	_drag_in_progress = true
	item_drag_started.emit()
	return {
		"kind": "hotbar_slot",
		"slot_index": slot_index,
		"item_id": String(item_id),
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not _drag_enabled or typeof(data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = data
	var kind: String = str(payload.get("kind", ""))
	if kind == "hotbar_slot":
		var source_index: int = int(payload.get("slot_index", -1))
		return (
			source_index >= 0
			and source_index < PlayerHotbarType.SLOT_COUNT
			and source_index != slot_index
		)
	if kind != "bag_item":
		return false
	var item_id: StringName = StringName(str(payload.get("item_id", "")))
	if _bag == null or not _bag.owns_item(item_id) or _catalog == null:
		return false
	var item: ItemDataType = _catalog.get_item_by_id(item_id)
	return item != null and item.is_valid() and item.hotbar_allowed


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(Vector2.ZERO, data) or _hotbar == null:
		return
	var payload: Dictionary = data
	if str(payload.get("kind", "")) == "hotbar_slot":
		_hotbar.swap_slots(int(payload["slot_index"]), slot_index)
	else:
		_hotbar.assign_item(
			slot_index,
			StringName(str(payload["item_id"]))
		)


func _select_slot() -> void:
	if _hotbar != null:
		_hotbar.select_slot(slot_index)


func _on_mouse_entered() -> void:
	if _hotbar != null:
		item_hovered.emit(slot_index, _hotbar.get_item_id(slot_index))


func _on_mouse_exited() -> void:
	item_hover_ended.emit(slot_index)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drag_in_progress:
		_drag_in_progress = false
		item_drag_finished.emit()
