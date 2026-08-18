class_name ShopSaleTraySlot
extends Button

signal remove_requested(key: String)
signal drop_requested(payload: Dictionary)

var entry_key: String = ""
var _icon: TextureRect
var _quantity: Label


func _ready() -> void:
	custom_minimum_size = GeneralInventoryGrid.DEFAULT_SLOT_SIZE
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pressed.connect(func() -> void: remove_requested.emit(entry_key))
	_icon = TextureRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 6.0
	_icon.offset_top = 4.0
	_icon.offset_right = -6.0
	_icon.offset_bottom = -4.0
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_quantity = Label.new()
	_quantity.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_quantity.position = Vector2(-34.0, -20.0)
	_quantity.size = Vector2(30.0, 16.0)
	_quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_quantity)
	var normal := UtilityPageStyle.rounded_style(
		Color(UtilityPageStyle.OCEAN_FIELD, 0.96), 26
	)
	var hover := UtilityPageStyle.rounded_style(
		Color(UtilityPageStyle.OCEAN_SELECTED, 0.96), 26
	)
	for state: StringName in [&"normal", &"pressed", &"disabled"]:
		add_theme_stylebox_override(state, normal)
	for state: StringName in [&"hover", &"focus"]:
		add_theme_stylebox_override(state, hover)


func configure(
	key: String,
	icon: Texture2D,
	label: String,
	quantity: int = 1,
) -> void:
	entry_key = key
	_icon.texture = icon
	_quantity.text = "×%d" % quantity if quantity > 1 else ""
	tooltip_text = "%s · select to remove" % label
	accessibility_name = tooltip_text


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return (
		typeof(data) == TYPE_DICTIONARY
		and str((data as Dictionary).get("kind", "")) in [
			"bag_item", "cooler_fish"
		]
	)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(Vector2.ZERO, data):
		drop_requested.emit((data as Dictionary).duplicate(true))
