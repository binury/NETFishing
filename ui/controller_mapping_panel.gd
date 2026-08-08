class_name ControllerMappingPanel
extends Control

signal closed

const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const UtilityPageStyleType = preload("res://ui/utility_page_style.gd")
const CAPTURE_NEUTRAL_SECONDS: float = 0.22
const CANCEL_COMBO_HOLD_SECONDS: float = 1.25

var _mapping_manager: ControllerMappingManagerType
var _binding_buttons: Dictionary = {}
var _controller_label: Label
var _instruction_label: Label
var _progress_label: Label
var _auto_map_button: Button
var _reset_button: Button
var _close_button: Button
var _capturing_role: StringName = &""
var _auto_map_active: bool = false
var _auto_map_index: int = -1
var _auto_map_draft: Dictionary = {}
var _capture_device_id: int = 0
var _waiting_for_neutral: bool = false
var _neutral_elapsed: float = 0.0
var _cancel_left_bumper_pressed: bool = false
var _cancel_right_bumper_pressed: bool = false
var _cancel_combo_elapsed: float = 0.0


func _ready() -> void:
	set_process_input(true)
	set_process(true)
	_build_interface()
	hide()


func setup(mapping_manager: ControllerMappingManagerType) -> void:
	_mapping_manager = mapping_manager
	if not _mapping_manager.active_controller_changed.is_connected(
		_on_active_controller_changed
	):
		_mapping_manager.active_controller_changed.connect(
			_on_active_controller_changed
		)
	if not _mapping_manager.active_profile_changed.is_connected(
		_refresh_bindings
	):
		_mapping_manager.active_profile_changed.connect(_refresh_bindings)
	if not _mapping_manager.controller_input_observed.is_connected(
		_on_controller_input_observed
	):
		_mapping_manager.controller_input_observed.connect(
			_on_controller_input_observed
		)
	_refresh_bindings()


func open_panel() -> void:
	if _mapping_manager == null:
		return
	_cancel_capture()
	_mapping_manager.recalibrate_active_device()
	show()
	_refresh_bindings()
	_auto_map_button.grab_focus()


func is_open() -> bool:
	return visible


func is_capturing() -> bool:
	return visible and not _capturing_role.is_empty()


func request_back() -> void:
	if not visible:
		return
	if not _capturing_role.is_empty():
		_cancel_capture()
		return
	close_panel()


func close_panel() -> void:
	_cancel_capture()
	hide()
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or _mapping_manager == null:
		return
	if _capturing_role.is_empty():
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
		_progress_label.text = "controller mapping cancelled"
		return


func _process(delta: float) -> void:
	if (
		not visible
		or _mapping_manager == null
		or _capturing_role.is_empty()
	):
		return
	if _cancel_left_bumper_pressed and _cancel_right_bumper_pressed:
		_cancel_combo_elapsed += delta
		_progress_label.text = "keep holding both bumpers to cancel"
		if _cancel_combo_elapsed >= CANCEL_COMBO_HOLD_SECONDS:
			_cancel_capture()
			_progress_label.text = "controller mapping cancelled"
		return
	_cancel_combo_elapsed = 0.0
	if _waiting_for_neutral:
		if not _mapping_manager.are_capture_inputs_neutral(_capture_device_id):
			_neutral_elapsed = 0.0
			return
		_neutral_elapsed += delta
		if _neutral_elapsed < CAPTURE_NEUTRAL_SECONDS:
			return
		_waiting_for_neutral = false
		_neutral_elapsed = 0.0
		_refresh_capture_prompt()
		return
	var pressed_button: int = _mapping_manager.get_pressed_capture_button(
		_capture_device_id
	)
	if pressed_button < 0:
		return
	var button_event := InputEventJoypadButton.new()
	button_event.device = _capture_device_id
	button_event.button_index = pressed_button as JoyButton
	button_event.pressed = true
	_try_capture_event(button_event)


func _on_controller_input_observed(event: InputEvent) -> void:
	if not visible or _mapping_manager == null:
		return
	if _capturing_role.is_empty():
		return
	get_viewport().set_input_as_handled()
	var button_event := event as InputEventJoypadButton
	var motion_event := event as InputEventJoypadMotion
	var event_device: int = -1
	if button_event != null:
		event_device = button_event.device
	elif motion_event != null:
		event_device = motion_event.device
	else:
		return
	if event_device != _capture_device_id:
		return
	_track_cancel_combo_button(button_event)
	if _waiting_for_neutral:
		return
	_try_capture_event(event)


func _try_capture_event(event: InputEvent) -> void:
	var binding: Dictionary = _mapping_manager.binding_from_event(
		_capturing_role,
		event,
	)
	if binding.is_empty():
		return
	if not _mapping_manager.validate_binding(_capturing_role, binding):
		return
	_accept_captured_binding(binding)


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
	title.text = "controller mapping"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override(
		"font_color", UtilityPageStyleType.OCEAN_TEXT_PRIMARY
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(title)

	_controller_label = Label.new()
	_controller_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_controller_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_controller_label.add_theme_font_size_override("font_size", 15)
	_controller_label.add_theme_color_override(
		"font_color", UtilityPageStyleType.OCEAN_TEXT_SECONDARY
	)
	heading_row.add_child(_controller_label)

	_instruction_label = Label.new()
	_instruction_label.text = (
		"auto-map walks through NETfishing's controller actions. "
		+ "select any row afterward to override it; the mapped back "
		+ "control cancels capture."
	)
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_label.add_theme_font_size_override("font_size", 15)
	_instruction_label.add_theme_color_override(
		"font_color", UtilityPageStyleType.OCEAN_TEXT_SECONDARY
	)
	page.add_child(_instruction_label)

	_progress_label = Label.new()
	_progress_label.custom_minimum_size.y = 34.0
	_progress_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_progress_label.add_theme_font_size_override("font_size", 18)
	_progress_label.add_theme_color_override(
		"font_color", UtilityPageStyleType.OCEAN_TEXT_PRIMARY
	)
	page.add_child(_progress_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	var role_grid := GridContainer.new()
	role_grid.columns = 2
	role_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_grid.add_theme_constant_override("h_separation", 12)
	role_grid.add_theme_constant_override("v_separation", 7)
	scroll.add_child(role_grid)

	for role: StringName in ControllerMappingManagerType.ROLE_ORDER:
		var role_label := Label.new()
		role_label.text = ControllerMappingManagerType.ROLE_LABELS.get(
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
			"change " + str(ControllerMappingManagerType.ROLE_LABELS.get(
				role,
				str(role),
			))
		)
		UtilityPageStyleType.apply_compact_ocean_button(binding_button)
		binding_button.pressed.connect(_begin_manual_capture.bind(role))
		role_grid.add_child(binding_button)
		_binding_buttons[role] = binding_button

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 10)
	page.add_child(footer)

	_auto_map_button = Button.new()
	_auto_map_button.text = "auto-map controller"
	_auto_map_button.tooltip_text = (
		"walk through every input on a standard xbox-style controller"
	)
	UtilityPageStyleType.apply_ocean_button(_auto_map_button)
	_auto_map_button.pressed.connect(_begin_auto_map)
	footer.add_child(_auto_map_button)

	_reset_button = Button.new()
	_reset_button.text = "restore defaults"
	_reset_button.tooltip_text = "remove this controller's custom mapping"
	UtilityPageStyleType.apply_ocean_button(_reset_button)
	_reset_button.pressed.connect(_reset_mapping)
	footer.add_child(_reset_button)

	_close_button = Button.new()
	_close_button.text = "done"
	UtilityPageStyleType.apply_ocean_button(_close_button)
	_close_button.pressed.connect(close_panel)
	footer.add_child(_close_button)


func _begin_auto_map() -> void:
	if _mapping_manager == null:
		return
	_auto_map_active = true
	_auto_map_index = 0
	_auto_map_draft = {}
	_reset_cancel_combo()
	_capture_device_id = _mapping_manager.get_active_device_id()
	_set_capture_role(ControllerMappingManagerType.ROLE_ORDER[_auto_map_index])


func _begin_manual_capture(role: StringName) -> void:
	_auto_map_active = false
	_auto_map_index = -1
	_auto_map_draft.clear()
	_reset_cancel_combo()
	_capture_device_id = _mapping_manager.get_active_device_id()
	_set_capture_role(role)


func _set_capture_role(role: StringName) -> void:
	_capturing_role = role
	_waiting_for_neutral = true
	_neutral_elapsed = 0.0
	_set_action_buttons_disabled(true)
	_progress_label.text = "release all controller inputs"


func _refresh_capture_prompt() -> void:
	if _capturing_role.is_empty():
		return
	if _auto_map_active:
		_progress_label.text = (
			"step %d of %d: %s\n"
			+ "hold both bumpers for %.2f seconds to cancel"
		) % [
			_auto_map_index + 1,
			ControllerMappingManagerType.ROLE_ORDER.size(),
			_mapping_manager.get_role_prompt(_capturing_role),
			CANCEL_COMBO_HOLD_SECONDS,
		]
		return
	var input_instruction: String = "press any controller button"
	if _mapping_manager.role_expects_axis(_capturing_role):
		input_instruction = "move any controller axis"
	elif _mapping_manager.role_accepts_axis(_capturing_role):
		input_instruction = "press any button or move any controller axis"
	_progress_label.text = "%s for %s" % [
		input_instruction,
		_mapping_manager.get_role_label(_capturing_role),
	]


func _accept_captured_binding(binding: Dictionary) -> void:
	if _auto_map_active:
		_auto_map_draft[str(_capturing_role)] = binding.duplicate(true)
		_auto_map_index += 1
		if _auto_map_index < ControllerMappingManagerType.ROLE_ORDER.size():
			_set_capture_role(
				ControllerMappingManagerType.ROLE_ORDER[_auto_map_index]
			)
			return
		var saved: bool = _mapping_manager.replace_active_bindings(
			_auto_map_draft
		)
		_cancel_capture()
		_progress_label.text = (
			"controller mapped successfully"
			if saved else "could not save the controller mapping"
		)
		_refresh_bindings()
		return
	var role: StringName = _capturing_role
	var saved: bool = _mapping_manager.set_binding(role, binding)
	_cancel_capture()
	_progress_label.text = (
		"updated " + _mapping_manager.get_role_label(role)
		if saved else "could not save that controller input"
	)
	_refresh_bindings()

func _cancel_capture() -> void:
	_capturing_role = &""
	_auto_map_active = false
	_auto_map_index = -1
	_auto_map_draft.clear()
	_waiting_for_neutral = false
	_neutral_elapsed = 0.0
	_reset_cancel_combo()
	_set_action_buttons_disabled(false)
	if _progress_label != null:
		_progress_label.text = ""


func _track_cancel_combo_button(button_event: InputEventJoypadButton) -> void:
	if button_event == null:
		return
	match button_event.button_index:
		JOY_BUTTON_LEFT_SHOULDER:
			_cancel_left_bumper_pressed = button_event.pressed
		JOY_BUTTON_RIGHT_SHOULDER:
			_cancel_right_bumper_pressed = button_event.pressed
		_:
			return
	if not (
		_cancel_left_bumper_pressed and _cancel_right_bumper_pressed
	):
		_cancel_combo_elapsed = 0.0


func _reset_cancel_combo() -> void:
	_cancel_left_bumper_pressed = false
	_cancel_right_bumper_pressed = false
	_cancel_combo_elapsed = 0.0


func _set_action_buttons_disabled(disabled: bool) -> void:
	if _auto_map_button != null:
		_auto_map_button.disabled = disabled
	if _reset_button != null:
		_reset_button.disabled = disabled
	for button_value: Variant in _binding_buttons.values():
		var button := button_value as Button
		if button != null:
			button.disabled = disabled


func _reset_mapping() -> void:
	if _mapping_manager == null:
		return
	var reset: bool = _mapping_manager.reset_active_profile()
	_progress_label.text = (
		"restored the project controller defaults"
		if reset else "could not restore controller defaults"
	)
	_refresh_bindings()


func _refresh_bindings() -> void:
	if _mapping_manager == null or _controller_label == null:
		return
	_controller_label.text = _mapping_manager.get_active_controller_name()
	var bindings: Dictionary = _mapping_manager.get_active_bindings()
	for role: StringName in ControllerMappingManagerType.ROLE_ORDER:
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
	for other_role: StringName in ControllerMappingManagerType.ROLE_ORDER:
		if other_role == role:
			continue
		var raw_other: Variant = bindings.get(str(other_role), {})
		if typeof(raw_other) != TYPE_DICTIONARY:
			continue
		var other := raw_other as Dictionary
		if _bindings_conflict(role, binding, other_role, other):
			return other_role
	return &""


func _bindings_conflict(
	first_role: StringName,
	first: Dictionary,
	second_role: StringName,
	second: Dictionary,
) -> bool:
	var binding_kind: String = str(first.get("kind", ""))
	if binding_kind != str(second.get("kind", "")):
		return false
	if binding_kind == "button":
		return int(first.get("button", -1)) == int(
			second.get("button", -1)
		)
	if binding_kind != "axis":
		return false
	if int(first.get("axis", -1)) != int(second.get("axis", -1)):
		return false
	var opposite_trigger_halves: bool = (
		first_role in ControllerMappingManagerType.TRIGGER_ROLES
		and second_role in ControllerMappingManagerType.TRIGGER_ROLES
		and signf(float(first.get("direction", 0.0)))
			!= signf(float(second.get("direction", 0.0)))
	)
	return not opposite_trigger_halves


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


func _on_active_controller_changed(_controller_name: String) -> void:
	if not _capturing_role.is_empty():
		_cancel_capture()
	_refresh_bindings()
