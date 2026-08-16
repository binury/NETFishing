class_name OnScreenKeyboard
extends Control

const ControllerFocusNavigationType = preload(
	"res://ui/controller_focus_navigation.gd"
)
const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const CHECK_ICON: Texture2D = preload(
	"res://ui/icons/pictograms/check_mark_dark.png"
)
const CHARACTER_KEY_SIZE: Vector2 = Vector2(96.0, 72.0)
const CHARACTER_FONT_SIZE: int = 34
const CANONICAL_WINDOW_SIZE: Vector2 = Vector2(1280.0, 720.0)
const TRIGGER_PRESS_THRESHOLD: float = 0.55
const TRIGGER_RELEASE_THRESHOLD: float = 0.25
const CARET_BLINK_INTERVAL: float = 0.5
const CARET_GLYPH: String = "▌"

signal text_submitted(value: String)

enum Page {
	LOWER,
	UPPER,
	SYMBOLS,
}

var _enabled: bool = false
var _controller_mapping_manager: ControllerMappingManagerType
var _page: Page = Page.LOWER
var _target: Control
var _target_virtual_keyboard_enabled: bool = true
var _buffer: String = ""
var _buffer_caret: int = 0
var _caret_blink_elapsed: float = 0.0
var _caret_visible: bool = true
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
	set_process(true)


func _process(delta: float) -> void:
	if not visible:
		return
	_caret_blink_elapsed += delta
	if _caret_blink_elapsed < CARET_BLINK_INTERVAL:
		return
	_caret_blink_elapsed = fmod(
		_caret_blink_elapsed,
		CARET_BLINK_INTERVAL,
	)
	_caret_visible = not _caret_visible
	_refresh_preview()


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not _is_available_for_controller() and visible:
		_close_keyboard(false)


func is_enabled() -> bool:
	return _is_available_for_controller()


func is_open() -> bool:
	return visible


func setup_controller_mapping(
	mapping_manager: ControllerMappingManagerType,
) -> void:
	_controller_mapping_manager = mapping_manager


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
		if joy_motion != null:
			if not _handle_trigger_shortcut(joy_motion):
				_move_key_focus(_controller_direction(event))
			get_viewport().set_input_as_handled()
			return
		var joy_button := event as InputEventJoypadButton
		if joy_button != null:
			if joy_button.pressed:
				# Resolve the automapper's logical roles before raw button numbers.
				# Handheld mappings do not necessarily report their labeled A/B/X
				# buttons using Godot's matching physical button constants.
				if _event_matches_role(
					event,
					ControllerMappingManagerType.ROLE_X,
					JOY_BUTTON_X,
				):
					_backspace()
				elif _event_matches_role(
					event,
					ControllerMappingManagerType.ROLE_LB,
					JOY_BUTTON_LEFT_SHOULDER,
				):
					_set_page(wrapi(int(_page) - 1, 0, Page.size()))
				elif _event_matches_role(
					event,
					ControllerMappingManagerType.ROLE_RB,
					JOY_BUTTON_RIGHT_SHOULDER,
				):
					_set_page(wrapi(int(_page) + 1, 0, Page.size()))
				elif _event_matches_role(
					event,
					ControllerMappingManagerType.ROLE_A,
					JOY_BUTTON_A,
				):
					_activate_focused_key()
				elif _event_matches_role(
					event,
					ControllerMappingManagerType.ROLE_B,
					JOY_BUTTON_B,
				):
					_close_keyboard(true)
				else:
					_move_key_focus(_controller_direction(event))
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
			not _event_matches_role(
				event,
				ControllerMappingManagerType.ROLE_A,
				JOY_BUTTON_A,
			)
			and (
				_controller_mapping_manager != null
				or not event.is_action_pressed(&"ui_accept")
			)
		)
	):
		return
	if request_for_focused_control():
		get_viewport().set_input_as_handled()


func _event_matches_role(
	event: InputEvent,
	role: StringName,
	fallback_button: JoyButton,
) -> bool:
	if _controller_mapping_manager != null:
		return _controller_mapping_manager.event_matches_role(event, role)
	var button := event as InputEventJoypadButton
	return button != null and button.button_index == fallback_button


func _is_available_for_controller() -> bool:
	return should_enable_for_controller(
		_enabled,
		DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD),
		OS.get_name(),
	)


static func should_enable_for_controller(
	preference_enabled: bool,
	native_virtual_keyboard_available: bool,
	platform_name: String = "",
) -> bool:
	# Desktop display backends can advertise native virtual-keyboard support
	# without presenting one for controller focus. Only Android delegates to
	# that platform keyboard by default.
	var resolved_platform: String = (
		OS.get_name() if platform_name.is_empty() else platform_name
	)
	return (
		preference_enabled
		or resolved_platform != "Android"
		or not native_virtual_keyboard_available
	)


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
	_buffer_caret = _buffer.length()
	_set_target_caret(_buffer_caret)
	_page = Page.LOWER
	_attach_to_target_window(control)
	show()
	_reset_caret_blink()
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
	_left_trigger_pressed = false
	_right_trigger_pressed = false
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
	_buffer_caret = clampi(
		_get_caret_column() + direction,
		0,
		_buffer.length(),
	)
	_set_target_caret(_buffer_caret)
	_reset_caret_blink()
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
	return clampi(_buffer_caret, 0, _buffer.length())


func _set_target_text(caret: int) -> void:
	_buffer_caret = clampi(caret, 0, _buffer.length())
	if _target is LineEdit:
		var line_edit := _target as LineEdit
		line_edit.text = _buffer
		line_edit.text_changed.emit(_buffer)
	elif _target is TextEdit:
		var text_edit := _target as TextEdit
		text_edit.text = _buffer
		text_edit.text_changed.emit()
	_set_target_caret(_buffer_caret)
	_reset_caret_blink()
	_refresh_preview()


func _set_target_caret(caret: int) -> void:
	if _target is LineEdit:
		(_target as LineEdit).caret_column = caret
	elif _target is TextEdit:
		var text_edit := _target as TextEdit
		var text_before_caret: String = _buffer.substr(0, caret)
		var caret_line: int = text_before_caret.count("\n")
		var last_newline: int = text_before_caret.rfind("\n")
		var caret_column: int = (
			caret if last_newline < 0 else caret - last_newline - 1
		)
		text_edit.set_caret_line(caret_line)
		text_edit.set_caret_column(caret_column)


func _reset_caret_blink() -> void:
	_caret_blink_elapsed = 0.0
	_caret_visible = true


func _refresh_preview() -> void:
	if _preview == null:
		return
	var displayed_text: String = _buffer
	if _target is LineEdit and (_target as LineEdit).secret:
		displayed_text = "*".repeat(_buffer.length())
	var caret: int = clampi(_get_caret_column(), 0, displayed_text.length())
	var caret_glyph: String = CARET_GLYPH if _caret_visible else ""
	_preview.text = displayed_text.insert(caret, caret_glyph)


func _controller_direction(event: InputEvent) -> Vector2:
	if event.is_action_pressed(&"ui_up"):
		return Vector2.UP
	if event.is_action_pressed(&"ui_down"):
		return Vector2.DOWN
	if event.is_action_pressed(&"ui_left"):
		return Vector2.LEFT
	if event.is_action_pressed(&"ui_right"):
		return Vector2.RIGHT
	return Vector2.ZERO


func _move_key_focus(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not is_ancestor_of(focused):
		_focus_first_key()
		return
	var neighbor_path := NodePath()
	if direction == Vector2.UP:
		neighbor_path = focused.focus_neighbor_top
	elif direction == Vector2.DOWN:
		neighbor_path = focused.focus_neighbor_bottom
	elif direction == Vector2.LEFT:
		neighbor_path = focused.focus_neighbor_left
	elif direction == Vector2.RIGHT:
		neighbor_path = focused.focus_neighbor_right
	if neighbor_path.is_empty():
		return
	var neighbor := focused.get_node_or_null(neighbor_path) as Control
	if ControllerFocusNavigationType.is_focusable(neighbor):
		neighbor.grab_focus()


func _activate_focused_key() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or not is_ancestor_of(focused):
		_focus_first_key()
		focused = get_viewport().gui_get_focus_owner()
	var button := focused as BaseButton
	if button != null and not button.disabled:
		button.pressed.emit()


func _focus_first_key() -> void:
	if not _key_buttons.is_empty():
		_key_buttons[0].grab_focus()


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
