class_name NotepadInkAction
extends Button

@export var ink_color := Color(0.19, 0.16, 0.12, 1.0)
@export var disabled_ink_color := Color(0.31, 0.28, 0.23, 0.46)
@export var persistent_mark: bool = false:
	set(value):
		persistent_mark = value
		_refresh_ink()

@onready var _ink_outline: NotepadInkOutline = %InkOutline

var _hovered: bool = false
var _focused: bool = false
var _pressed: bool = false


func _ready() -> void:
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_set_focused.bind(true))
	focus_exited.connect(_set_focused.bind(false))
	button_down.connect(_set_pressed.bind(true))
	button_up.connect(_set_pressed.bind(false))
	_apply_paper_style()
	_refresh_ink()


func refresh_ink_state() -> void:
	_apply_text_color()
	_refresh_ink()


func _set_hovered(value: bool) -> void:
	_hovered = value
	_refresh_ink()


func _set_focused(value: bool) -> void:
	_focused = value
	_refresh_ink()


func _set_pressed(value: bool) -> void:
	_pressed = value
	_refresh_ink()


func _refresh_ink() -> void:
	if not is_node_ready():
		return
	var strength: float = 0.0
	if not disabled:
		if persistent_mark:
			strength = 0.78
		if _hovered or _focused:
			strength = maxf(strength, 0.92)
		if _pressed:
			strength = 1.0
	_ink_outline.set_mark_strength(strength)


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
	_apply_text_color()


func _apply_text_color() -> void:
	var color: Color = disabled_ink_color if disabled else ink_color
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_hover_color", color.darkened(0.08))
	add_theme_color_override("font_focus_color", color.darkened(0.08))
	add_theme_color_override("font_pressed_color", color.darkened(0.16))
	add_theme_color_override("font_disabled_color", disabled_ink_color)
