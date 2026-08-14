class_name BubbleHotbarSlot
extends Button

signal item_hovered(slot_index: int, item_id: StringName)
signal item_hover_ended(slot_index: int)
signal item_drag_started
signal item_drag_finished

const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const PlayerHotbarType = preload("res://inventory/player_hotbar.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishCatchType = preload("res://fish/fish_catch.gd")
const FishQualityType = preload("res://fish/fish_quality.gd")

const SELECTED_SCALE: float = 1.12
const HOVER_SCALE: float = 1.025
const MAXIMUM_SCALE: float = 1.14
const SELECTED_LIFT: float = 4.0
const HOVER_LIFT: float = 0.75
const PRESENTATION_RESPONSE: float = 18.0
const IDLE_AMPLITUDE: float = 1.0
const IDLE_PERIOD: float = 6.0
const DEFORMATION_PERIOD: float = 6.8
const DEFORMATION_PHASE_MULTIPLIER: float = 1.37
const DEFORMATION_X_AMPLITUDE: float = 0.009
const DEFORMATION_Y_AMPLITUDE: float = 0.007

@export_range(0, PlayerHotbarType.SLOT_COUNT - 1, 1) var slot_index: int = 0
@export_group("Authored Layout")
@export var desktop_size: Vector2 = Vector2(78.0, 78.0)
@export var compact_size: Vector2 = Vector2(54.0, 54.0)
@export var desktop_anchor: Vector2 = Vector2.ZERO
@export var compact_anchor: Vector2 = Vector2.ZERO
@export_group("Motion")
@export_range(0.0, TAU, 0.01) var motion_phase: float = 0.0
@export_group("Style")
@export var profile: BubbleMenuProfile

@onready var _item_icon: TextureRect = %ItemIcon
@onready var _quantity_label: Label = %QuantityLabel

var _hotbar: PlayerHotbarType
var _bag: PlayerBagType
var _catalog: ItemCatalogType
var _fish_inventory: FishInventoryType
var _drag_enabled: bool = false
var _drag_in_progress: bool = false
var _selected: bool = false
var _hovered: bool = false
var _empty: bool = true
var _selection_amount: float = 0.0
var _hover_amount: float = 0.0
var _base_position: Vector2 = Vector2.ZERO
var _presented_size: Vector2 = Vector2.ZERO
var _compact: bool = false
var _presentation_initialized: bool = false
var _controller_preview_active: bool = false
var _controller_preview_texture: Texture2D


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	toggle_mode = false
	pressed.connect(_select_slot)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_update_pivot)
	_update_pivot()
	_apply_style()


func setup(
	hotbar: PlayerHotbarType,
	bag: PlayerBagType,
	catalog: ItemCatalogType,
	fish_inventory: FishInventoryType,
) -> void:
	_hotbar = hotbar
	_bag = bag
	_catalog = catalog
	_fish_inventory = fish_inventory
	refresh()


func apply_layout(compact: bool) -> void:
	_compact = compact
	_presented_size = compact_size if compact else desktop_size
	var center: Vector2 = compact_anchor if compact else desktop_anchor
	custom_minimum_size = _presented_size
	size = _presented_size
	_base_position = center - _presented_size * 0.5
	_update_content_layout()
	_update_pivot()
	_apply_style()
	if not _presentation_initialized:
		_selection_amount = 1.0 if _selected else 0.0
		_hover_amount = 1.0 if _hovered else 0.0
		_presentation_initialized = true


func advance_presentation(delta: float, elapsed: float) -> void:
	var response_weight: float = 1.0 - exp(-PRESENTATION_RESPONSE * delta)
	_selection_amount = lerpf(
		_selection_amount,
		1.0 if _selected else 0.0,
		response_weight
	)
	_hover_amount = lerpf(
		_hover_amount,
		1.0 if _hovered else 0.0,
		response_weight
	)
	var idle_offset: float = sin(
		elapsed / IDLE_PERIOD * TAU + motion_phase
	) * IDLE_AMPLITUDE
	var lift: float = (
		_selection_amount * SELECTED_LIFT
		+ _hover_amount * HOVER_LIFT
	)
	position = _base_position + Vector2(0.0, idle_offset - lift)
	var presentation_scale: float = minf(
		MAXIMUM_SCALE,
		1.0
		+ _selection_amount * (SELECTED_SCALE - 1.0)
		+ _hover_amount * (HOVER_SCALE - 1.0)
	)
	var breath: float = sin(
		elapsed / DEFORMATION_PERIOD * TAU
		+ motion_phase * DEFORMATION_PHASE_MULTIPLIER
	)
	var deformation := Vector2(
		1.0 + breath * DEFORMATION_X_AMPLITUDE,
		1.0 - breath * DEFORMATION_Y_AMPLITUDE
	)
	scale = deformation * presentation_scale


func set_drag_enabled(enabled: bool) -> void:
	_drag_enabled = enabled
	mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if enabled
		else Control.MOUSE_FILTER_IGNORE
	)
	if not enabled:
		_hovered = false


func set_controller_placement_preview(
	active: bool,
	texture: Texture2D,
) -> void:
	_controller_preview_active = active
	_controller_preview_texture = texture
	refresh()


func refresh() -> void:
	if _hotbar == null:
		return
	var item_id: StringName = _hotbar.get_item_id(slot_index)
	var catch_id: StringName = _hotbar.get_fish_catch_id(slot_index)
	var item: ItemDataType = (
		_catalog.get_item_by_id(item_id)
		if _catalog != null and not item_id.is_empty()
		else null
	)
	var fish_catch: FishCatchType = (
		_fish_inventory.get_catch_by_id(catch_id)
		if _fish_inventory != null and not catch_id.is_empty()
		else null
	)
	var assigned_texture: Texture2D = (
		fish_catch.fish.display_texture
		if fish_catch != null
		else item.icon if item != null else null
	)
	_item_icon.texture = (
		_controller_preview_texture
		if _controller_preview_active
		else assigned_texture
	)
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
	_quantity_label.text = quantity_text
	_quantity_label.visible = (
		not _controller_preview_active and not quantity_text.is_empty()
	)
	tooltip_text = (
		"%s · %.1f lb" % [
			FishQualityType.qualified_name(
				fish_catch.fish.display_name,
				fish_catch.quality,
			),
			fish_catch.weight_lb,
		]
		if fish_catch != null
		else item.display_name if item != null else "empty hotbar slot"
	)
	var was_selected: bool = _selected
	var was_empty: bool = _empty
	_selected = slot_index == _hotbar.get_selected_slot()
	_empty = (
		not _controller_preview_active
		and item == null
		and fish_catch == null
	)
	if was_selected != _selected or was_empty != _empty:
		_apply_style()


func _update_content_layout() -> void:
	if not is_node_ready():
		return
	if _compact:
		_item_icon.position = Vector2(11.0, 11.0)
		_item_icon.size = Vector2(34.0, 34.0)
		_quantity_label.position = Vector2(25.0, 35.0)
		_quantity_label.size = Vector2(25.0, 17.0)
		_quantity_label.add_theme_font_size_override("font_size", 10)
	else:
		_item_icon.position = Vector2(17.0, 16.0)
		_item_icon.size = Vector2(46.0, 46.0)
		_quantity_label.position = Vector2(39.0, 54.0)
		_quantity_label.size = Vector2(32.0, 20.0)
		_quantity_label.add_theme_font_size_override("font_size", 12)


func _apply_style() -> void:
	if profile == null:
		return
	var normal_fill: Color = profile.normal_fill
	normal_fill.a = 1.0
	var selected_fill: Color = normal_fill
	if _controller_preview_active:
		selected_fill = normal_fill.lightened(0.22)
	elif _selected:
		selected_fill = normal_fill.lightened(0.12)
	add_theme_stylebox_override(
		"normal",
		_make_style(
			selected_fill,
			5 if _selected else 2,
			0.38 if _selected else 0.20,
		)
	)
	add_theme_stylebox_override(
		"hover",
		_make_style(
			selected_fill.lightened(0.055),
			5 if _selected else 3,
			0.40 if _selected else 0.29,
		)
	)
	add_theme_stylebox_override(
		"pressed",
		_make_style(
			selected_fill.lightened(0.085),
			6,
			0.44,
		)
	)
	add_theme_stylebox_override(
		"focus",
		get_theme_stylebox("normal")
	)
	add_theme_stylebox_override(
		"disabled",
		_make_style(
			normal_fill,
			1,
			0.12,
		)
	)
	add_theme_color_override("font_color", profile.text_color)
	add_theme_color_override("font_hover_color", profile.text_hover_color)
	add_theme_color_override("font_pressed_color", profile.text_pressed_color)
	add_theme_color_override("font_disabled_color", profile.text_disabled_color)


func _make_style(
	fill_color: Color,
	shadow_size: int,
	shadow_alpha: float,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.set_border_width_all(0)
	var radius: int = ceili(maxf(_presented_size.x, _presented_size.y) * 0.5)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = Color(0.015, 0.06, 0.09, shadow_alpha)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _has_point(point: Vector2) -> bool:
	var radius: Vector2 = size * 0.5
	if radius.x <= 0.0 or radius.y <= 0.0:
		return false
	var normalized: Vector2 = (point - radius) / radius
	return normalized.length_squared() <= 1.0


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
	var catch_id: StringName = _hotbar.get_fish_catch_id(slot_index)
	if item_id.is_empty() and catch_id.is_empty():
		return null
	var item: ItemDataType = _catalog.get_item_by_id(item_id)
	var fish_catch: FishCatchType = (
		_fish_inventory.get_catch_by_id(catch_id)
		if _fish_inventory != null and not catch_id.is_empty()
		else null
	)
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(44.0, 44.0)
	preview.texture = (
		fish_catch.fish.display_texture
		if fish_catch != null
		else item.icon if item != null else null
	)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	_drag_in_progress = true
	item_drag_started.emit()
	return {
		"kind": "hotbar_slot",
		"slot_index": slot_index,
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
	if kind == "bag_item":
		var item_id: StringName = StringName(str(payload.get("item_id", "")))
		if _bag == null or not _bag.owns_item(item_id) or _catalog == null:
			return false
		var item: ItemDataType = _catalog.get_item_by_id(item_id)
		return item != null and item.is_available() and item.hotbar_allowed
	if kind == "cooler_fish":
		var catch_id: StringName = StringName(str(payload.get("catch_id", "")))
		return (
			_fish_inventory != null
			and _fish_inventory.contains_catch_id(catch_id)
		)
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(Vector2.ZERO, data) or _hotbar == null:
		return
	var payload: Dictionary = data
	if str(payload.get("kind", "")) == "hotbar_slot":
		_hotbar.swap_slots(int(payload["slot_index"]), slot_index)
	elif str(payload.get("kind", "")) == "cooler_fish":
		_hotbar.assign_fish(
			slot_index,
			StringName(str(payload["catch_id"])),
		)
	else:
		_hotbar.assign_item(
			slot_index,
			StringName(str(payload["item_id"]))
		)


func _select_slot() -> void:
	if _hotbar != null:
		_hotbar.select_slot(slot_index)
		refresh()


func _on_mouse_entered() -> void:
	_hovered = true
	if _hotbar != null:
		var identity: StringName = _hotbar.get_item_id(slot_index)
		if identity.is_empty():
			identity = _hotbar.get_fish_catch_id(slot_index)
		item_hovered.emit(slot_index, identity)


func _on_mouse_exited() -> void:
	_hovered = false
	item_hover_ended.emit(slot_index)


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _drag_in_progress:
		_drag_in_progress = false
		item_drag_finished.emit()
