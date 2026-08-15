class_name NotepadInkChoice
extends Control

signal item_selected(index: int)

@export var ink_color := Color(0.19, 0.16, 0.12, 1.0)
@export_range(0.0, 16.0, 0.25) var outline_padding: float = 3.0:
	set(value):
		outline_padding = value
		if is_node_ready():
			_ink_outline.padding = outline_padding
			_ink_outline.queue_redraw()
@export var outline_outsets := Vector4.ZERO:
	set(value):
		outline_outsets = value
		if is_node_ready():
			_apply_outline_geometry()

@onready var _ink_outline: NotepadInkOutline = %InkOutline
@onready var _displayed_value: Label = %DisplayedValue
@onready var _choice_panel: Control = %ChoicePanel
@onready var _choice_buttons: Array[Button] = [
	%CatchOrderChoice,
	%NameChoice,
	%RarityChoice,
]

var disabled: bool = false:
	set(value):
		disabled = value
		if is_node_ready():
			_apply_interaction_state()
var _items: Array[String] = []
var _item_ids: Array[int] = []
var _selected_index: int = 0
var _hovered: bool = false
var _focused: bool = false
var _opened_with_mouse: bool = false


func _ready() -> void:
	_ink_outline.padding = outline_padding
	_apply_outline_geometry()
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_set_focused.bind(true))
	focus_exited.connect(_set_focused.bind(false))
	gui_input.connect(_on_display_gui_input)
	for index: int in _choice_buttons.size():
		var button: Button = _choice_buttons[index]
		button.pressed.connect(_select_index.bind(index))
		button.gui_input.connect(_on_choice_gui_input.bind(index))
	_choice_panel.hide()
	_apply_paper_style()
	_apply_interaction_state()


func add_item(item_text: String, item_id: int = -1) -> void:
	if _items.size() >= _choice_buttons.size():
		return
	var index: int = _items.size()
	_items.append(item_text)
	_item_ids.append(item_id if item_id >= 0 else index)
	_choice_buttons[index].text = item_text
	_choice_buttons[index].show()
	if index == _selected_index:
		_displayed_value.text = item_text


func select(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	_selected_index = index
	_displayed_value.text = _items[index]


func get_selected_id() -> int:
	if _selected_index < 0 or _selected_index >= _item_ids.size():
		return -1
	return _item_ids[_selected_index]


func refresh_ink_state() -> void:
	_refresh_ink()


func set_choice_font_size(font_size: int) -> void:
	_displayed_value.add_theme_font_size_override("font_size", font_size)
	for button: Button in _choice_buttons:
		button.add_theme_font_size_override("font_size", font_size)


func close_choices() -> void:
	if not _choice_panel.visible:
		return
	_choice_panel.hide()
	if _opened_with_mouse:
		_opened_with_mouse = false
		if has_focus():
			release_focus()
	_refresh_ink()


func _apply_outline_geometry() -> void:
	_ink_outline.offset_left = -outline_outsets.x
	_ink_outline.offset_top = -outline_outsets.y
	_ink_outline.offset_right = outline_outsets.z
	_ink_outline.offset_bottom = outline_outsets.w
	_ink_outline.queue_redraw()


func _draw() -> void:
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


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event.is_action_pressed("ui_accept"):
		_open_choices(false)
		accept_event()
	elif event.is_action_pressed("ui_cancel") and _choice_panel.visible:
		close_choices()
		accept_event()


func _input(event: InputEvent) -> void:
	if not _choice_panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close_choices()
		get_viewport().set_input_as_handled()
		return
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		var mouse_position: Vector2 = event.position
		if (
			not get_global_rect().has_point(mouse_position)
			and not _choice_panel.get_global_rect().has_point(mouse_position)
		):
			close_choices()


func _on_display_gui_input(event: InputEvent) -> void:
	if (
		not disabled
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_open_choices(true)
		accept_event()


func _on_choice_gui_input(event: InputEvent, index: int) -> void:
	if event.is_action_pressed("ui_cancel"):
		close_choices()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_choice_buttons[maxi(index - 1, 0)].grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_choice_buttons[mini(
			index + 1, _choice_buttons.size() - 1
		)].grab_focus()
		get_viewport().set_input_as_handled()


func _open_choices(from_mouse: bool) -> void:
	if disabled or _choice_panel.visible:
		return
	_opened_with_mouse = from_mouse
	_choice_panel.show()
	_choice_panel.move_to_front()
	if not from_mouse:
		_choice_buttons[_selected_index].grab_focus()
	_refresh_ink()


func _select_index(index: int) -> void:
	if disabled or index < 0 or index >= _items.size():
		return
	select(index)
	close_choices()
	item_selected.emit(get_selected_id())


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


func _apply_interaction_state() -> void:
	_displayed_value.modulate.a = 0.42 if disabled else 1.0
	focus_mode = Control.FOCUS_NONE if disabled else Control.FOCUS_ALL
	mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
		if disabled
		else Control.MOUSE_FILTER_STOP
	)
	for button: Button in _choice_buttons:
		button.disabled = disabled
	if disabled:
		close_choices()
	_refresh_ink()


func _apply_paper_style() -> void:
	var empty := StyleBoxEmpty.new()
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.82, 0.775, 0.63, 1.0)
	hover.set_border_width_all(0)
	hover.set_corner_radius_all(0)
	hover.anti_aliasing = false
	_displayed_value.add_theme_color_override("font_color", ink_color)
	for button: Button in _choice_buttons:
		for state: StringName in [
			&"normal",
			&"disabled",
		]:
			button.add_theme_stylebox_override(state, empty)
		for state: StringName in [
			&"hover",
			&"pressed",
			&"focus",
		]:
			button.add_theme_stylebox_override(state, hover)
		button.add_theme_color_override("font_color", ink_color)
		button.add_theme_color_override(
			"font_hover_color",
			ink_color.darkened(0.08),
		)
		button.add_theme_color_override(
			"font_focus_color",
			ink_color.darkened(0.08),
		)
		button.add_theme_color_override(
			"font_pressed_color",
			ink_color.darkened(0.14),
		)
