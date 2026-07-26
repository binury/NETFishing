class_name ItemDragSource
extends Button

var item_id: StringName
var item_icon: Texture2D
var item_name: String


func setup(
	new_item_id: StringName,
	new_item_name: String,
	new_icon: Texture2D,
) -> void:
	item_id = new_item_id
	item_name = new_item_name
	item_icon = new_icon


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id.is_empty() or disabled:
		return null
	set_drag_preview(_create_drag_preview())
	return {
		"kind": "bag_item",
		"item_id": String(item_id),
	}


func _create_drag_preview() -> Control:
	var preview := VBoxContainer.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_theme_constant_override("separation", 2)
	var texture := TextureRect.new()
	texture.custom_minimum_size = Vector2(44, 44)
	texture.texture = item_icon
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(texture)
	var label := Label.new()
	label.text = item_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	preview.add_child(label)
	return preview
