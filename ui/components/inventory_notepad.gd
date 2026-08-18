class_name InventoryNotepad
extends PanelContainer

const INK_COLOR := Color(0.16, 0.16, 0.14, 1.0)
const CONTENT_MARGIN_LEFT := 18.0
const CONTENT_MARGIN_TOP := 98.0
const CONTENT_MARGIN_RIGHT := 18.0
const CONTENT_MARGIN_BOTTOM := 16.0
# Retained for the Logbook's separate handwritten presentation. Inventory
# notepads deliberately prioritize legibility with Tuffy.
const HANDWRITTEN_FONT: Font = preload("res://ui/fonts/seattle_avenue.otf")
const NOTEPAD_FONT: Font = preload("res://ui/fonts/Tuffy_Bold.otf")
const NOTEPAD_TEXTURE: Texture2D = preload("res://art/ui/ui_notepad.png")
const NOTEPAD_CANONICAL_OVERSCAN: float = 1.2
const NOTEPAD_ART_OFFSET := Vector2(10.0, 20.0)

@export var title_text := "notes"
@export var inset_content := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	apply_handwritten_to(self)
	add_theme_stylebox_override("panel", make_layout_style(inset_content))
	resized.connect(queue_redraw)
	queue_redraw()


static func apply_handwritten_to(root: Control) -> void:
	root.add_theme_font_override("font", NOTEPAD_FONT)
	for descendant: Node in root.find_children("*", "Control", true, false):
		var control := descendant as Control
		control.add_theme_font_override(
			"font", NOTEPAD_FONT
		)
		if control is Label:
			control.add_theme_color_override("font_color", INK_COLOR)


func _draw() -> void:
	draw_texture_rect(NOTEPAD_TEXTURE, get_art_rect(), false)

	var font: Font = NOTEPAD_FONT
	draw_string(
		font,
		Vector2(20.0, 58.0),
		title_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 40.0,
		20,
		INK_COLOR,
	)


func get_art_rect() -> Rect2:
	return get_art_rect_for_host(size)


static func get_art_rect_for_host(host_size: Vector2) -> Rect2:
	# Source pixels establish the artwork aspect ratio and sampling quality. The
	# canonical host rect, not the source dimensions, owns its displayed size.
	var source_size: Vector2 = NOTEPAD_TEXTURE.get_size()
	if (
		host_size.x <= 0.0
		or host_size.y <= 0.0
		or source_size.x <= 0.0
		or source_size.y <= 0.0
	):
		return Rect2()
	var fit_scale: float = minf(
		host_size.x / source_size.x,
		host_size.y / source_size.y,
	)
	var rendered_size: Vector2 = (
		source_size * fit_scale * NOTEPAD_CANONICAL_OVERSCAN
	)
	return Rect2(
		(host_size - rendered_size) * 0.5 + NOTEPAD_ART_OFFSET,
		rendered_size,
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
