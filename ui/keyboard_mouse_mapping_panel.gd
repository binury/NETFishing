class_name KeyboardMouseMappingPanel
extends Control

signal closed

const KeyboardMouseMappingManagerType = preload(
	"res://settings/keyboard_mouse_mapping_manager.gd"
)
const UtilityPageStyleType = preload("res://ui/utility_page_style.gd")

var _mapping_manager: KeyboardMouseMappingManagerType
var _binding_buttons: Dictionary = {}
var _progress_label: Label
var _mapping_scroll: ScrollContainer
var _reset_button: Button
var _close_button: Button
var _capturing_role: StringName = &""


func _ready() -> void:
	set_process_input(true)
	_build_interface()
	hide()


func setup(mapping_manager: KeyboardMouseMappingManagerType) -> void:
	_mapping_manager = mapping_manager
	if not _mapping_manager.mapping_changed.is_connected(_refresh_bindings):
		_mapping_manager.mapping_changed.connect(_refresh_bindings)
	_refresh_bindings()


func open_panel() -> void:
	if _mapping_manager == null:
		return
	_cancel_capture()
	show()
	_refresh_bindings()
	var first_button := _binding_buttons.get(
		KeyboardMouseMappingManagerType.ROLE_ORDER.front()
	) as Button
	if first_button != null:
		first_button.grab_focus()


func is_open() -> bool:
	return visible


func is_capturing() -> bool:
	return visible and not _capturing_role.is_empty()


func request_back() -> void:
	if not visible:
		return
	if not _capturing_role.is_empty():
		_cancel_capture()
		_progress_label.text = "keyboard binding cancelled"
		return
	close_panel()


func close_panel() -> void:
	_cancel_capture()
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or _mapping_manager == null or _capturing_role.is_empty():
		return
	var key_event := event as InputEventKey
	if (
		key_event != null
		and key_event.pressed
		and not key_event.echo
		and key_event.keycode == KEY_ESCAPE
	):
		get_viewport().set_input_as_handled()
		_cancel_capture()
		_progress_label.text = "keyboard binding cancelled"
		return
	var binding: Dictionary = _mapping_manager.binding_from_event(event)
	if binding.is_empty():
		return
	get_viewport().set_input_as_handled()
	var role: StringName = _capturing_role
	var saved: bool = _mapping_manager.set_binding(role, binding)
	_cancel_capture()
	_progress_label.text = (
		"updated " + _mapping_manager.get_role_label(role)
		if saved else "could not save that keyboard binding"
	)
	_refresh_bindings()


func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	UtilityPageStyleType.apply_page(self)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 18.0
	frame.offset_top = 18.0
	frame.offset_right = -18.0
	frame.offset_bottom = -18.0
	frame.add_theme_stylebox_override(
		"panel",
		UtilityPageStyleType.rounded_style(
			UtilityPageStyleType.OCEAN_PANEL_DEEP,
			20,
		),
	)
	add_child(frame)

	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", 24)
	outer_margin.add_theme_constant_override("margin_top", 20)
	outer_margin.add_theme_constant_override("margin_right", 24)
	outer_margin.add_theme_constant_override("margin_bottom", 20)
	frame.add_child(outer_margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	outer_margin.add_child(page)

	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 12)
	page.add_child(heading_row)

	var title := Label.new()
	title.text = "keyboard binds"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override(
		"font_color", UtilityPageStyleType.OCEAN_TEXT_PRIMARY
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(title)

	var device_label := Label.new()
	device_label.text = "mouse + keyboard"
	device_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	device_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	device_label.add_theme_font_size_override("font_size", 15)
	device_label.add_theme_color_override(
		"font_color", UtilityPageStyleType.OCEAN_TEXT_SECONDARY
	)
	heading_row.add_child(device_label)

	var instruction_label := Label.new()
	instruction_label.text = (
		"select a row, then press a keyboard key or mouse button. "
		+ "duplicate bindings are marked in red."
	)
	instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction_label.add_theme_font_size_override("font_size", 15)
	instruction_label.add_theme_color_override(
		"font_color", UtilityPageStyleType.OCEAN_TEXT_SECONDARY
	)
	page.add_child(instruction_label)

	_progress_label = Label.new()
	_progress_label.custom_minimum_size.y = 34.0
	_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 18)
	_progress_label.add_theme_color_override(
		"font_color", UtilityPageStyleType.OCEAN_TEXT_PRIMARY
	)
	page.add_child(_progress_label)

	_mapping_scroll = ScrollContainer.new()
	_mapping_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mapping_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mapping_scroll.follow_focus = true
	page.add_child(_mapping_scroll)

	var role_grid := GridContainer.new()
	role_grid.columns = 2
	role_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_grid.add_theme_constant_override("h_separation", 12)
	role_grid.add_theme_constant_override("v_separation", 7)
	_mapping_scroll.add_child(role_grid)

	for role: StringName in KeyboardMouseMappingManagerType.ROLE_ORDER:
		var role_label := Label.new()
		role_label.text = KeyboardMouseMappingManagerType.ROLE_LABELS.get(
			role,
			str(role),
		)
		role_label.custom_minimum_size = Vector2(330.0, 42.0)
		role_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		role_label.add_theme_font_size_override("font_size", 16)
		role_label.add_theme_color_override(
			"font_color", UtilityPageStyleType.OCEAN_TEXT_PRIMARY
		)
		role_grid.add_child(role_label)

		var binding_button := Button.new()
		binding_button.custom_minimum_size = Vector2(210.0, 42.0)
		binding_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		binding_button.focus_mode = Control.FOCUS_ALL
		binding_button.tooltip_text = (
			"change " + _mapping_manager_label(role)
		)
		UtilityPageStyleType.apply_compact_ocean_button(binding_button)
		binding_button.pressed.connect(_begin_capture.bind(role))
		role_grid.add_child(binding_button)
		_binding_buttons[role] = binding_button

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 10)
	page.add_child(footer)

	_reset_button = Button.new()
	_reset_button.text = "restore defaults"
	_reset_button.tooltip_text = "restore the project keyboard defaults"
	UtilityPageStyleType.apply_ocean_button(_reset_button)
	_reset_button.pressed.connect(_reset_mapping)
	footer.add_child(_reset_button)

	_close_button = Button.new()
	_close_button.text = "done"
	UtilityPageStyleType.apply_ocean_button(_close_button)
	_close_button.pressed.connect(close_panel)
	footer.add_child(_close_button)
	_configure_mapping_navigation()


func _configure_mapping_navigation() -> void:
	var buttons: Array[Button] = []
	for role: StringName in KeyboardMouseMappingManagerType.ROLE_ORDER:
		var binding_button := _binding_buttons.get(role) as Button
		if binding_button != null:
			buttons.append(binding_button)
	if buttons.is_empty():
		return
	for index: int in buttons.size():
		var button: Button = buttons[index]
		var previous: Control = buttons[index - 1] if index > 0 else button
		var next: Control = (
			buttons[index + 1]
			if index < buttons.size() - 1
			else _close_button
		)
		_set_focus_neighbors(button, button, button, previous, next)
		button.focus_previous = button.get_path_to(previous)
		button.focus_next = button.get_path_to(next)
	var last_button: Button = buttons.back()
	_set_focus_neighbors(
		_reset_button,
		_reset_button,
		_close_button,
		last_button,
		_reset_button,
	)
	_set_focus_neighbors(
		_close_button,
		_reset_button,
		_close_button,
		last_button,
		_close_button,
	)
	_close_button.focus_previous = _close_button.get_path_to(last_button)
	_close_button.focus_next = _close_button.get_path_to(_reset_button)


func _set_focus_neighbors(
	control: Control,
	left: Control,
	right: Control,
	top: Control,
	bottom: Control,
) -> void:
	control.focus_neighbor_left = control.get_path_to(left)
	control.focus_neighbor_right = control.get_path_to(right)
	control.focus_neighbor_top = control.get_path_to(top)
	control.focus_neighbor_bottom = control.get_path_to(bottom)


func _mapping_manager_label(role: StringName) -> String:
	if _mapping_manager == null:
		return str(
			KeyboardMouseMappingManagerType.ROLE_LABELS.get(role, str(role))
		)
	return _mapping_manager.get_role_label(role)


func _begin_capture(role: StringName) -> void:
	if _mapping_manager == null:
		return
	_capturing_role = role
	_set_action_buttons_disabled(true)
	_progress_label.text = (
		"press a key or mouse button for "
		+ _mapping_manager.get_role_label(role)
		+ " • escape cancels"
	)


func _cancel_capture() -> void:
	_capturing_role = &""
	_set_action_buttons_disabled(false)
	if _progress_label != null:
		_progress_label.text = ""


func _set_action_buttons_disabled(disabled: bool) -> void:
	if _reset_button != null:
		_reset_button.disabled = disabled
	if _close_button != null:
		_close_button.disabled = disabled
	for button_value: Variant in _binding_buttons.values():
		var button := button_value as Button
		if button != null:
			button.disabled = disabled


func _reset_mapping() -> void:
	if _mapping_manager == null:
		return
	var reset: bool = _mapping_manager.reset_mapping()
	_progress_label.text = (
		"restored the project keyboard defaults"
		if reset else "could not restore keyboard defaults"
	)
	_refresh_bindings()


func _refresh_bindings() -> void:
	if _mapping_manager == null or _reset_button == null:
		return
	var bindings: Dictionary = _mapping_manager.get_active_bindings()
	for role: StringName in KeyboardMouseMappingManagerType.ROLE_ORDER:
		var button := _binding_buttons.get(role) as Button
		if button == null:
			continue
		var raw_binding: Variant = bindings.get(str(role), {})
		button.text = (
			_mapping_manager.binding_label(raw_binding as Dictionary)
			if typeof(raw_binding) == TYPE_DICTIONARY else "unmapped"
		)
		var conflict_role: StringName = _find_binding_conflict(
			role,
			raw_binding as Dictionary,
			bindings,
		)
		_apply_binding_button_style(button, not conflict_role.is_empty())
		button.tooltip_text = (
			"warning: also assigned to "
			+ _mapping_manager.get_role_label(conflict_role)
			if not conflict_role.is_empty()
			else "change " + _mapping_manager.get_role_label(role)
		)
	_reset_button.disabled = not _mapping_manager.has_custom_mapping()


func _find_binding_conflict(
	role: StringName,
	binding: Dictionary,
	bindings: Dictionary,
) -> StringName:
	if binding.is_empty():
		return &""
	for other_role: StringName in KeyboardMouseMappingManagerType.ROLE_ORDER:
		if other_role == role:
			continue
		var raw_other: Variant = bindings.get(str(other_role), {})
		if typeof(raw_other) != TYPE_DICTIONARY:
			continue
		if KeyboardMouseMappingManagerType.bindings_conflict(
			binding,
			raw_other as Dictionary,
		):
			return other_role
	return &""


func _apply_binding_button_style(button: Button, has_conflict: bool) -> void:
	UtilityPageStyleType.apply_compact_ocean_button(button)
	if not has_conflict:
		return
	var colors: Dictionary = {
		&"normal": UtilityPageStyleType.OCEAN_DANGER,
		&"hover": UtilityPageStyleType.OCEAN_DANGER.lightened(0.12),
		&"pressed": UtilityPageStyleType.OCEAN_DANGER.darkened(0.12),
		&"focus": UtilityPageStyleType.OCEAN_DANGER.lightened(0.12),
	}
	for state: StringName in colors:
		var style := UtilityPageStyleType.ocean_button_style(
			colors[state] as Color
		)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 4.0
		style.content_margin_bottom = 4.0
		button.add_theme_stylebox_override(state, style)
