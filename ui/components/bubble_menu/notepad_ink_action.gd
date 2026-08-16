class_name NotepadInkAction
extends Button

@export var ink_color := Color(0.19, 0.16, 0.12, 1.0)
@export var disabled_ink_color := Color(0.31, 0.28, 0.23, 0.46)
@export var allow_persistent_mark: bool = false:
	set(value):
		allow_persistent_mark = value
		if not allow_persistent_mark:
			persistent_mark = false
@export var persistent_mark: bool = false:
	set(value):
		persistent_mark = value and allow_persistent_mark
		_refresh_ink()

@onready var _ink_outline: NotepadInkOutline = %InkOutline

var _hovered: bool = false
var _pressed: bool = false


func _ready() -> void:
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	button_down.connect(_set_pressed.bind(true))
	button_up.connect(_set_pressed.bind(false))
	gui_input.connect(_on_gui_input)
	_apply_paper_style()
	_refresh_ink()


func refresh_ink_state() -> void:
	_apply_text_color()
	_refresh_ink()


func _set_hovered(value: bool) -> void:
	_hovered = value
	_refresh_ink()


func _set_pressed(value: bool) -> void:
	_pressed = value
	_refresh_ink()


func _on_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		call_deferred("_finish_mouse_activation")


func _finish_mouse_activation() -> void:
	_pressed = false
	if has_focus():
		release_focus()
	_refresh_ink()


func _refresh_ink() -> void:
	if not is_node_ready():
		return
	var strength: float = 0.0
	if not disabled:
		if persistent_mark:
			strength = 0.78
		if _hovered:
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
	add_theme_color_override("font_focus_color", color)
	add_theme_color_override("font_pressed_color", color.darkened(0.16))
	add_theme_color_override("font_disabled_color", disabled_ink_color)
