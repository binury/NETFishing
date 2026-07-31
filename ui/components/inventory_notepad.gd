class_name InventoryNotepad
extends PanelContainer

const INK_COLOR := Color(0.16, 0.16, 0.14, 1.0)
const CONTENT_MARGIN_LEFT := 18.0
const CONTENT_MARGIN_TOP := 98.0
const CONTENT_MARGIN_RIGHT := 18.0
const CONTENT_MARGIN_BOTTOM := 16.0
const HANDWRITTEN_FONT: Font = preload("res://ui/fonts/seattle_avenue.otf")
const NOTEPAD_TEXTURE: Texture2D = preload("res://art/ui/ui_notepad.png")
const NOTEPAD_ART_SCALE := 1.1

@export var title_text := "notes"
@export var inset_content := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	apply_handwritten_to(self)
	add_theme_stylebox_override("panel", make_layout_style(inset_content))
	resized.connect(queue_redraw)
	queue_redraw()


static func apply_handwritten_to(root: Control) -> void:
	root.add_theme_font_override("font", HANDWRITTEN_FONT)
	for descendant: Node in root.find_children("*", "Control", true, false):
		var control := descendant as Control
		control.add_theme_font_override(
			"font", HANDWRITTEN_FONT
		)
		if control is Label:
			control.add_theme_color_override("font_color", INK_COLOR)


func _draw() -> void:
	var texture_size := NOTEPAD_TEXTURE.get_size()
	var uniform_scale := minf(
		size.x / texture_size.x,
		size.y / texture_size.y,
	) * NOTEPAD_ART_SCALE
	var rendered_size := texture_size * uniform_scale
	var rendered_rect := Rect2(
		(size - rendered_size) * 0.5,
		rendered_size,
	)
	draw_texture_rect(NOTEPAD_TEXTURE, rendered_rect, false)

	var font: Font = HANDWRITTEN_FONT
	draw_string(
		font,
		Vector2(20.0, 58.0),
		title_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 40.0,
		20,
		INK_COLOR,
	)


static func make_layout_style(with_content_margins: bool = true) -> StyleBoxFlat:
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color.TRANSPARENT
	if with_content_margins:
		paper.content_margin_left = CONTENT_MARGIN_LEFT
		paper.content_margin_top = CONTENT_MARGIN_TOP
		paper.content_margin_right = CONTENT_MARGIN_RIGHT
		paper.content_margin_bottom = CONTENT_MARGIN_BOTTOM
	return paper
