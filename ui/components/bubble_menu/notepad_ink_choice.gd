class_name NotepadInkChoice
extends OptionButton

@export var ink_color := Color(0.19, 0.16, 0.12, 1.0)

@onready var _ink_outline: NotepadInkOutline = %InkOutline

var _hovered: bool = false
var _focused: bool = false


func _ready() -> void:
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_set_focused.bind(true))
	focus_exited.connect(_set_focused.bind(false))
	_apply_paper_style()
	_style_popup()
	queue_redraw()


func refresh_ink_state() -> void:
	_refresh_ink()


func _draw() -> void:
	var chevron_x: float = size.x - 13.0
	var chevron_y: float = size.y * 0.5 - 1.0
	var chevron := PackedVector2Array([
		Vector2(chevron_x - 4.0, chevron_y - 2.0),
		Vector2(chevron_x, chevron_y + 2.0),
		Vector2(chevron_x + 4.0, chevron_y - 2.5),
	])
	draw_polyline(chevron, ink_color, 1.8, true)
	var underline_y: float = size.y - 5.0
	var underline := PackedVector2Array([
		Vector2(7.0, underline_y),
		Vector2(size.x * 0.34, underline_y + 0.7),
		Vector2(size.x * 0.68, underline_y - 0.5),
		Vector2(size.x - 8.0, underline_y + 0.2),
	])
	var underline_color: Color = ink_color
	underline_color.a = 0.48
	draw_polyline(underline, underline_color, 1.1, true)


func _set_hovered(value: bool) -> void:
	_hovered = value
	_refresh_ink()


func _set_focused(value: bool) -> void:
	_focused = value
	_refresh_ink()


func _refresh_ink() -> void:
	if is_node_ready():
		_ink_outline.set_mark_strength(
			0.88 if (_hovered or _focused) and not disabled else 0.0
		)


func _apply_paper_style() -> void:
	var empty := StyleBoxEmpty.new()
	for state: StringName in [
		&"normal",
		&"hover",
		&"pressed",
		&"focus",
		&"disabled",
	]:
		add_theme_stylebox_override(state, empty)
	var empty_arrow := ImageTexture.new()
	add_theme_icon_override("arrow", empty_arrow)
	add_theme_color_override("font_color", ink_color)
	add_theme_color_override("font_hover_color", ink_color.darkened(0.08))
	add_theme_color_override("font_focus_color", ink_color.darkened(0.08))
	add_theme_color_override("font_pressed_color", ink_color.darkened(0.14))
	add_theme_color_override("font_disabled_color", Color(ink_color, 0.42))


func _style_popup() -> void:
	var popup: PopupMenu = get_popup()
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.93, 0.885, 0.73, 1.0)
	paper.border_color = Color(0.22, 0.19, 0.15, 1.0)
	paper.set_border_width_all(2)
	paper.set_corner_radius_all(5)
	var hover_paper := paper.duplicate() as StyleBoxFlat
	hover_paper.bg_color = Color(0.82, 0.775, 0.63, 1.0)
	hover_paper.border_color = Color(0.30, 0.26, 0.20, 0.62)
	hover_paper.set_border_width_all(1)
	popup.add_theme_stylebox_override("panel", paper)
	popup.add_theme_stylebox_override("hover", hover_paper)
	popup.add_theme_stylebox_override("separator", StyleBoxEmpty.new())
	popup.add_theme_color_override("font_color", ink_color)
	popup.add_theme_color_override("font_hover_color", ink_color.darkened(0.08))
	popup.add_theme_color_override(
		"font_separator_color",
		Color(ink_color, 0.56),
	)
	var empty_mark := ImageTexture.new()
	for icon_name: StringName in [
		&"checked",
		&"unchecked",
		&"radio_checked",
		&"radio_unchecked",
		&"checked_disabled",
		&"unchecked_disabled",
		&"radio_checked_disabled",
		&"radio_unchecked_disabled",
	]:
		popup.add_theme_icon_override(icon_name, empty_mark)
