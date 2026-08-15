class_name OnScreenKeyboard
extends Control

const ControllerFocusNavigationType = preload(
	"res://ui/controller_focus_navigation.gd"
)
const CHECK_ICON: Texture2D = preload(
	"res://ui/icons/pictograms/check_mark_dark.png"
)
const CHARACTER_KEY_SIZE: Vector2 = Vector2(96.0, 72.0)
const CHARACTER_FONT_SIZE: int = 34
const CANONICAL_WINDOW_SIZE: Vector2 = Vector2(1280.0, 720.0)
const TRIGGER_PRESS_THRESHOLD: float = 0.55
const TRIGGER_RELEASE_THRESHOLD: float = 0.25

signal text_submitted(value: String)

enum Page {
	LOWER,
	UPPER,
	SYMBOLS,
}

var _enabled: bool = false
var _page: Page = Page.LOWER
var _target: Control
var _target_virtual_keyboard_enabled: bool = true
var _buffer: String = ""
var _preview: Label
var _page_buttons: Array[Button] = []
var _keys_host: VBoxContainer
var _key_buttons: Array[Button] = []
var _caret_left_button: Button
var _caret_right_button: Button
var _backspace_button: Button
var _space_button: Button
var _check_button: Button
var _left_trigger_pressed: bool = false
var _right_trigger_pressed: bool = false
var _portable_host_parent: Node
var _portable_host_index: int = -1
var _portable_target_window: Window
var _portable_target_window_size: Vector2i
var _portable_target_window_position: Vector2i


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_interface()
	hide()
	set_process_input(true)


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _is_available_for_controller() and visible:
		_close_keyboard(false)


func is_enabled() -> bool:
	return _is_available_for_controller()


func is_open() -> bool:
	return visible


func request_for_focused_control() -> bool:
	return request_for_control(get_viewport().gui_get_focus_owner())


func request_for_control(control: Control = null) -> bool:
	if (
		not _is_available_for_controller()
		or visible
		or not _can_edit(control)
	):
		return false
	_open_for(control)
	return true


func _input(event: InputEvent) -> void:
	if not _is_available_for_controller():
		return
	if visible:
		var joy_motion := event as InputEventJoypadMotion
		if joy_motion != null and _handle_trigger_shortcut(joy_motion):
			get_viewport().set_input_as_handled()
			return
		var joy_button := event as InputEventJoypadButton
		if joy_button != null and joy_button.pressed:
			if joy_button.button_index == JOY_BUTTON_X:
				_backspace()
				get_viewport().set_input_as_handled()
				return
			if joy_button.button_index == JOY_BUTTON_LEFT_SHOULDER:
				_close_keyboard(false)
				get_viewport().set_input_as_handled()
				return
			if joy_button.button_index == JOY_BUTTON_RIGHT_SHOULDER:
				_set_page(wrapi(int(_page) + 1, 0, Page.size()))
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed(&"ui_cancel"):
			_close_keyboard(true)
			get_viewport().set_input_as_handled()
		return
	var joy_event := event as InputEventJoypadButton
	if (
		joy_event == null
		or not joy_event.pressed
		or (
			joy_event.button_index != JOY_BUTTON_A
			and not event.is_action_pressed(&"ui_accept")
		)
	):
		return
	if request_for_focused_control():
		get_viewport().set_input_as_handled()


func _is_available_for_controller() -> bool:
	return should_enable_for_controller(
		_enabled,
		DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD),
	)


static func should_enable_for_controller(
	preference_enabled: bool,
	native_virtual_keyboard_available: bool,
) -> bool:
	# A controller user must always have one viable text-entry path. Android
	# and any future display backend with native support can keep using the
	# platform keyboard unless the in-game keyboard is explicitly requested.
	return preference_enabled or not native_virtual_keyboard_available


func _can_edit(control: Control) -> bool:
	if control is LineEdit:
		return (control as LineEdit).editable
	if control is TextEdit:
		return (control as TextEdit).editable
	return false


func _open_for(control: Control) -> void:
	_target = control
	_target_virtual_keyboard_enabled = bool(
		_target.get("virtual_keyboard_enabled")
	)
	_target.set("virtual_keyboard_enabled", false)
	_buffer = str(_target.get("text"))
	_page = Page.LOWER
	_attach_to_target_window(control)
	show()
	_refresh_preview()
	_rebuild_keys()


func _close_keyboard(restore_focus: bool) -> void:
	var prior_target: Control = _target
	if is_instance_valid(prior_target):
		prior_target.set(
			"virtual_keyboard_enabled",
			_target_virtual_keyboard_enabled
		)
	hide()
	get_viewport().gui_release_focus()
	_restore_portable_host()
	_target = null
	if restore_focus and is_instance_valid(prior_target):
		prior_target.grab_focus()


func _attach_to_target_window(control: Control) -> void:
	var target_window: Window = control.get_window()
	if target_window == null or target_window == get_window():
		return
	_portable_host_parent = get_parent()
	_portable_host_index = get_index()
	_portable_target_window = target_window
	_portable_target_window_size = target_window.size
	_portable_target_window_position = target_window.position
	var parent_window := target_window.get_parent() as Window
	if parent_window != null:
		target_window.size = parent_window.size
		target_window.position = parent_window.position
	reparent(target_window, false)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 0.0
	anchor_bottom = 0.0
	size = CANONICAL_WINDOW_SIZE
	var available: Vector2 = Vector2(target_window.size)
	var fit_scale: float = minf(
		available.x / CANONICAL_WINDOW_SIZE.x,
		available.y / CANONICAL_WINDOW_SIZE.y,
	)
	scale = Vector2.ONE * maxf(fit_scale, 0.01)
	position = (available - CANONICAL_WINDOW_SIZE * fit_scale) * 0.5


func _restore_portable_host() -> void:
	if _portable_host_parent == null:
		return
	var original_parent: Node = _portable_host_parent
	var original_index: int = _portable_host_index
	var target_window: Window = _portable_target_window
	_portable_host_parent = null
	_portable_host_index = -1
	_portable_target_window = null
	reparent(original_parent, false)
	if original_index >= 0:
		original_parent.move_child(
			self,
			mini(original_index, original_parent.get_child_count() - 1),
		)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scale = Vector2.ONE
	if target_window != null and is_instance_valid(target_window):
		target_window.size = _portable_target_window_size
		target_window.position = _portable_target_window_position


func _submit() -> void:
	var submitted_target: Control = _target
	var submitted_text: String = _buffer
	_close_keyboard(false)
	if submitted_target is LineEdit:
		(submitted_target as LineEdit).text_submitted.emit(submitted_text)
	elif submitted_target is TextEdit:
		(submitted_target as TextEdit).text_changed.emit()
	text_submitted.emit(submitted_text)


func _type_character(character: String) -> void:
	if not is_instance_valid(_target):
		_close_keyboard(false)
		return
	var caret: int = _get_caret_column()
	var next_text: String = (
		_buffer.substr(0, caret)
		+ character
		+ _buffer.substr(caret)
	)
	if _target is LineEdit:
		var line_edit := _target as LineEdit
		if line_edit.max_length > 0 and next_text.length() > line_edit.max_length:
			return
	_buffer = next_text
	_set_target_text(caret + character.length())


func _type_space() -> void:
	_type_character(" ")


func _backspace() -> void:
	if not is_instance_valid(_target) or _buffer.is_empty():
		return
	var caret: int = _get_caret_column()
	if caret <= 0:
		return
	_buffer = _buffer.erase(caret - 1, 1)
	_set_target_text(caret - 1)


func _move_caret(direction: int) -> void:
	if not is_instance_valid(_target):
		_close_keyboard(false)
		return
	var caret: int = clampi(
		_get_caret_column() + direction,
		0,
		_buffer.length(),
	)
	if _target is LineEdit:
		(_target as LineEdit).caret_column = caret
	elif _target is TextEdit:
		(_target as TextEdit).set_caret_column(caret)
	_refresh_preview()


func _handle_trigger_shortcut(event: InputEventJoypadMotion) -> bool:
	if event.axis == JOY_AXIS_TRIGGER_LEFT:
		if event.axis_value <= TRIGGER_RELEASE_THRESHOLD:
			_left_trigger_pressed = false
		elif (
			event.axis_value >= TRIGGER_PRESS_THRESHOLD
			and not _left_trigger_pressed
		):
			_left_trigger_pressed = true
			_move_caret(-1)
			return true
	elif event.axis == JOY_AXIS_TRIGGER_RIGHT:
		if event.axis_value <= TRIGGER_RELEASE_THRESHOLD:
			_right_trigger_pressed = false
		elif (
			event.axis_value >= TRIGGER_PRESS_THRESHOLD
			and not _right_trigger_pressed
		):
			_right_trigger_pressed = true
			_move_caret(1)
			return true
	return false


func _get_caret_column() -> int:
	if _target is LineEdit:
		return clampi(
			(_target as LineEdit).caret_column,
			0,
			_buffer.length()
		)
	return _buffer.length()


func _set_target_text(caret: int) -> void:
	if _target is LineEdit:
		var line_edit := _target as LineEdit
		line_edit.text = _buffer
		line_edit.caret_column = caret
		line_edit.text_changed.emit(_buffer)
	elif _target is TextEdit:
		var text_edit := _target as TextEdit
		text_edit.text = _buffer
		text_edit.text_changed.emit()
	_refresh_preview()


func _refresh_preview() -> void:
	if _preview == null:
		return
	var displayed_text: String = _buffer
	if _target is LineEdit and (_target as LineEdit).secret:
		displayed_text = "*".repeat(_buffer.length())
	var caret: int = clampi(_get_caret_column(), 0, displayed_text.length())
	_preview.text = displayed_text.insert(caret, "|")


func _set_page(page_index: int) -> void:
	_page = page_index as Page
	_rebuild_keys()


func _rebuild_keys() -> void:
	for child: Node in _keys_host.get_children():
		_keys_host.remove_child(child)
		child.queue_free()
	_key_buttons.clear()
	var rows: Array = _rows_for_page()
	for row_value: Variant in rows:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_theme_constant_override("separation", 10)
		_keys_host.add_child(row)
		for character_value: Variant in row_value as Array:
			var character: String = str(character_value)
			var key_button: Button = _make_button(character, CHARACTER_KEY_SIZE)
			key_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			key_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			key_button.add_theme_font_size_override(
				"font_size", CHARACTER_FONT_SIZE
			)
			key_button.pressed.connect(_type_character.bind(character))
			row.add_child(key_button)
			_key_buttons.append(key_button)
	for index: int in _page_buttons.size():
		_page_buttons[index].button_pressed = index == int(_page)
	call_deferred("_configure_key_focus")


func _configure_key_focus() -> void:
	var focus_controls: Array[Control] = []
	for button: Button in _key_buttons:
		focus_controls.append(button)
	for button: Button in [
		_caret_left_button,
		_caret_right_button,
		_backspace_button,
		_space_button,
		_check_button,
	]:
		focus_controls.append(button)
	ControllerFocusNavigationType.configure_spatial_neighbors(focus_controls)
	if not _key_buttons.is_empty():
		_key_buttons[0].grab_focus()


func _rows_for_page() -> Array:
	match _page:
		Page.UPPER:
			return [
				["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
				["A", "S", "D", "F", "G", "H", "J", "K", "L"],
				["Z", "X", "C", "V", "B", "N", "M"],
			]
		Page.SYMBOLS:
			return [
				["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
				["!", "@", "#", "$", "%", "^", "&", "*", "(", ")"],
				["-", "_", "=", "+", "[", "]", "{", "}"],
				[".", ",", "?", "/", ":", ";", "'", "\""]
			]
		_:
			return [
				["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
				["a", "s", "d", "f", "g", "h", "j", "k", "l"],
				["z", "x", "c", "v", "b", "n", "m"],
			]


func _build_interface() -> void:
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.012, 0.075, 0.105, 0.82)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	var screen_margin := MarginContainer.new()
	screen_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [
		&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"
	]:
		screen_margin.add_theme_constant_override(side, 14)
	add_child(screen_margin)
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(
		"panel",
		_make_style(Color(0.075, 0.27, 0.34, 0.98), 18, 4)
	)
	screen_margin.add_child(panel)
	var margin := MarginContainer.new()
	for side: StringName in [&"margin_left", &"margin_top", &"margin_right", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(0.0, 86.0)
	preview_panel.add_theme_stylebox_override(
		"panel",
		_make_style(Color(0.82, 0.94, 0.95, 1.0), 10, 2)
	)
	layout.add_child(preview_panel)
	_preview = Label.new()
	_preview.add_theme_color_override("font_color", Color(0.025, 0.12, 0.17, 1.0))
	_preview.add_theme_font_size_override("font_size", 30)
	_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_preview.add_theme_constant_override("outline_size", 0)
	preview_panel.add_child(_preview)
	var page_row := HBoxContainer.new()
	page_row.alignment = BoxContainer.ALIGNMENT_CENTER
	page_row.add_theme_constant_override("separation", 12)
	layout.add_child(page_row)
	for page_name: String in ["lower", "upper", "symbols"]:
		var page_button: Button = _make_button(page_name, Vector2(150.0, 44.0))
		page_button.toggle_mode = true
		page_button.focus_mode = Control.FOCUS_NONE
		page_button.pressed.connect(_set_page.bind(_page_buttons.size()))
		page_row.add_child(page_button)
		_page_buttons.append(page_button)
	_keys_host = VBoxContainer.new()
	_keys_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_keys_host.alignment = BoxContainer.ALIGNMENT_CENTER
	_keys_host.add_theme_constant_override("separation", 12)
	layout.add_child(_keys_host)
	var utility_row := HBoxContainer.new()
	utility_row.alignment = BoxContainer.ALIGNMENT_CENTER
	utility_row.add_theme_constant_override("separation", 12)
	layout.add_child(utility_row)
	_caret_left_button = _make_button("LT <", Vector2(118.0, 64.0))
	_caret_left_button.tooltip_text = "move text cursor left"
	_caret_left_button.pressed.connect(_move_caret.bind(-1))
	utility_row.add_child(_caret_left_button)
	_caret_right_button = _make_button("> RT", Vector2(118.0, 64.0))
	_caret_right_button.tooltip_text = "move text cursor right"
	_caret_right_button.pressed.connect(_move_caret.bind(1))
	utility_row.add_child(_caret_right_button)
	_backspace_button = _make_button("backspace X", Vector2(180.0, 64.0))
	_backspace_button.pressed.connect(_backspace)
	utility_row.add_child(_backspace_button)
	_space_button = _make_button("space", Vector2(350.0, 64.0))
	_space_button.size_flags_stretch_ratio = 4.0
	_space_button.pressed.connect(_type_space)
	utility_row.add_child(_space_button)
	_check_button = _make_button("", Vector2(92.0, 64.0))
	_check_button.icon = CHECK_ICON
	_check_button.expand_icon = true
	_check_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_check_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_check_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_check_button.tooltip_text = "submit"
	_check_button.accessibility_name = "submit text"
	_check_button.add_theme_constant_override("icon_max_width", 42)
	_check_button.pressed.connect(_submit)
	utility_row.add_child(_check_button)
	_rebuild_keys()


func _make_button(label: String, minimum_size: Vector2) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = minimum_size
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.025, 0.12, 0.17, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.025, 0.12, 0.17, 1.0))
	button.add_theme_color_override("font_focus_color", Color(0.025, 0.12, 0.17, 1.0))
	button.add_theme_stylebox_override(
		"normal",
		_make_style(Color(0.72, 0.88, 0.91, 1.0), 10, 2)
	)
	button.add_theme_stylebox_override(
		"hover",
		_make_style(Color(0.87, 0.96, 0.96, 1.0), 10, 3)
	)
	button.add_theme_stylebox_override("focus", button.get_theme_stylebox("hover"))
	button.add_theme_stylebox_override(
		"pressed",
		_make_style(Color(0.44, 0.72, 0.77, 1.0), 10, 3)
	)
	return button


func _make_style(color: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.025, 0.12, 0.17, 1.0)
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
