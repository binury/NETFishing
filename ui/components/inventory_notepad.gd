class_name InventoryNotepad
extends PanelContainer

const PAPER_COLOR := Color(0.93, 0.885, 0.73, 1.0)
const BORDER_COLOR := Color(0.22, 0.19, 0.15, 1.0)
const INK_COLOR := Color(0.16, 0.16, 0.14, 1.0)
const BINDING_COLOR := Color(0.31, 0.27, 0.20, 0.80)
const RULE_COLOR := Color(0.44, 0.36, 0.24, 0.34)
const CONTENT_MARGIN_LEFT := 18.0
const CONTENT_MARGIN_TOP := 98.0
const CONTENT_MARGIN_RIGHT := 18.0
const CONTENT_MARGIN_BOTTOM := 16.0

@export var title_text := "notes"
@export var inset_content := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	add_theme_stylebox_override("panel", make_paper_style(inset_content))
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var font: Font = UtilityPageStyle.TuffyFont
	draw_string(
		font,
		Vector2(28.0, 25.0),
		"●   ●   ●   ●",
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 56.0,
		20,
		BINDING_COLOR,
	)
	draw_string(
		font,
		Vector2(20.0, 58.0),
		title_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 40.0,
		20,
		INK_COLOR,
	)
	draw_line(
		Vector2(18.0, 87.0),
		Vector2(size.x - 18.0, 87.0),
		RULE_COLOR,
		2.0,
	)


static func make_paper_style(with_content_margins: bool = true) -> StyleBoxFlat:
	var paper := StyleBoxFlat.new()
	paper.bg_color = PAPER_COLOR
	paper.border_color = BORDER_COLOR
	paper.set_border_width_all(4)
	paper.corner_radius_top_left = 9
	paper.corner_radius_top_right = 7
	paper.corner_radius_bottom_right = 11
	paper.corner_radius_bottom_left = 8
	paper.shadow_color = Color(0.10, 0.08, 0.06, 0.46)
	paper.shadow_size = 4
	paper.shadow_offset = Vector2(3.0, 4.0)
	if with_content_margins:
		paper.content_margin_left = CONTENT_MARGIN_LEFT
		paper.content_margin_top = CONTENT_MARGIN_TOP
		paper.content_margin_right = CONTENT_MARGIN_RIGHT
		paper.content_margin_bottom = CONTENT_MARGIN_BOTTOM
	return paper
