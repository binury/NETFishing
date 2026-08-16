class_name BagStorageSlot
extends Button

signal bag_item_dropped(item_id: StringName, slot_index: int)

var storage_slot_index: int = -1
var _preview: TextureRect


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	toggle_mode = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_style()
	_preview = TextureRect.new()
	_preview.name = "PlacementPreview"
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_preview.offset_left = 8.0
	_preview.offset_top = 7.0
	_preview.offset_right = -8.0
	_preview.offset_bottom = -7.0
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.visible = false
	add_child(_preview)


func configure(slot_index: int) -> void:
	storage_slot_index = slot_index
	name = "BagStorageSlot%d" % slot_index
	accessibility_name = "storage slot %d" % (slot_index + 1)


func set_placement_preview(texture: Texture2D, active: bool) -> void:
	if _preview == null:
		return
	_preview.texture = texture
	_preview.visible = active and texture != null
	z_index = 2 if _preview.visible else 0


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		typeof(data) == TYPE_DICTIONARY
		and str((data as Dictionary).get("kind", "")) == "bag_item"
		and not str((data as Dictionary).get("item_id", "")).is_empty()
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(Vector2.ZERO, data):
		return
	bag_item_dropped.emit(
		StringName(str((data as Dictionary)["item_id"])),
		storage_slot_index,
	)


func _apply_style() -> void:
	var normal := UtilityPageStyle.rounded_style(
		Color(UtilityPageStyle.OCEAN_FIELD, 0.72),
		14,
	)
	var hover := UtilityPageStyle.rounded_style(
		Color(UtilityPageStyle.OCEAN_SELECTED, 0.68),
		14,
	)
	for state: StringName in [&"normal", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(state, normal)
	add_theme_stylebox_override(&"hover", hover)
