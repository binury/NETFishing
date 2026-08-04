extends SceneTree

const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const ControllerMappingPanelType = preload(
	"res://ui/controller_mapping_panel.gd"
)
const GameUIType = preload("res://ui/game_ui.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manager := ControllerMappingManagerType.new()
	root.add_child(manager)
	await process_frame
	var failure: String = _validate_manager(manager)
	if failure.is_empty():
		failure = _validate_auto_map(manager)
	if failure.is_empty():
		failure = _validate_virtual_mouse_bounds()
	if failure.is_empty():
		failure = _validate_controller_scroll_target()
	if failure.is_empty():
		print("controller mapping validation passed")
		quit(0)
		return
	push_error(failure)
	quit(1)


func _validate_manager(manager: ControllerMappingManagerType) -> String:
	var muos_mapping: String = (
		ControllerMappingManagerType.build_muos_controller_mapping(
			"19004ca6010000000100000000010000",
			"muOS-Keys",
		)
	)
	for expected_binding: String in [
		"a:b2",
		"b:b0",
		"x:b1",
		"y:b3",
		"leftshoulder:b6",
		"rightshoulder:b7",
		"lefttrigger:b8",
		"righttrigger:b9",
		"back:b10",
		"start:b11",
		"leftx:a0",
		"righty:a3",
	]:
		if expected_binding not in muos_mapping:
			return "muOS compatibility mapping omitted " + expected_binding
	if not muos_mapping.begins_with(
		"19004ca6010000000100000000010000,muOS-Keys,"
	):
		return "muOS compatibility mapping does not use the runtime guid"
	if not ControllerMappingManagerType.is_muos_controller_name(
		"muOS-Keys"
	):
		return "muOS controller name was not recognized"
	if ControllerMappingManagerType.is_muos_controller_name(
		"ordinary controller"
	):
		return "muOS mapping would affect unrelated controllers"
	if not ControllerMappingManagerType.should_install_muos_compatibility_mapping(
		"muOS-Keys",
		false,
	):
		return "unknown legacy muOS controller did not receive fallback mapping"
	if ControllerMappingManagerType.should_install_muos_compatibility_mapping(
		"muOS-Keys",
		true,
	):
		return "recognized muOS controller would override its SDL mapping"
	if ControllerMappingManagerType.should_install_muos_compatibility_mapping(
		"ordinary controller",
		false,
	):
		return "muOS fallback would affect an unrelated unknown controller"
	var defaults: Dictionary = manager.get_active_bindings()
	if defaults.size() != ControllerMappingManagerType.ROLE_ORDER.size():
		return "default mapping covers %d of %d controller roles: %s" % [
			defaults.size(),
			ControllerMappingManagerType.ROLE_ORDER.size(),
			str(defaults.keys()),
		]
	var trigger_button := InputEventJoypadButton.new()
	trigger_button.button_index = JOY_BUTTON_MISC1
	trigger_button.pressed = true
	var trigger_binding: Dictionary = manager.binding_from_event(
		ControllerMappingManagerType.ROLE_LT,
		trigger_button,
	)
	if str(trigger_binding.get("kind", "")) != "button":
		return "trigger role did not accept a button-backed handheld trigger"
	var trigger_motion := InputEventJoypadMotion.new()
	trigger_motion.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger_motion.axis_value = 1.0
	trigger_binding = manager.binding_from_event(
		ControllerMappingManagerType.ROLE_LT,
		trigger_motion,
	)
	if str(trigger_binding.get("kind", "")) != "axis":
		return "trigger role did not accept an axis-backed controller trigger"
	var stick_button := manager.binding_from_event(
		ControllerMappingManagerType.ROLE_RIGHT_STICK_X,
		trigger_button,
	)
	if not stick_button.is_empty():
		return "stick axis role accepted a button"
	var keyboard_events_before: int = _keyboard_event_count(&"jump")
	var custom: Dictionary = defaults.duplicate(true)
	custom[str(ControllerMappingManagerType.ROLE_A)] = {
		"kind": "button",
		"button": int(JOY_BUTTON_X),
	}
	custom[str(ControllerMappingManagerType.ROLE_LT)] = trigger_binding
	if not manager.replace_active_bindings(custom):
		return "valid custom mapping could not be saved"
	if not manager.has_custom_mapping():
		return "saved custom mapping did not become active"
	if _keyboard_event_count(&"jump") != keyboard_events_before:
		return "controller remapping changed keyboard bindings"
	if not FileAccess.file_exists(
		ControllerMappingManagerType.PROFILE_PATH
	):
		return "controller mapping was not stored device-locally"
	return ""


func _validate_auto_map(manager: ControllerMappingManagerType) -> String:
	var panel := ControllerMappingPanelType.new()
	root.add_child(panel)
	panel.setup(manager)
	panel.open_panel()
	panel._begin_auto_map()
	for role: StringName in ControllerMappingManagerType.ROLE_ORDER:
		panel._process(ControllerMappingPanelType.CAPTURE_NEUTRAL_SECONDS)
		var binding := (
			ControllerMappingManagerType.default_bindings()[str(role)]
			as Dictionary
		)
		if role == ControllerMappingManagerType.ROLE_B:
			binding = (
				ControllerMappingManagerType.default_bindings()[
					str(ControllerMappingManagerType.ROLE_A)
				] as Dictionary
			)
		if str(binding.get("kind", "")) == "button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(binding.get("button", -1))
			button.pressed = true
			manager.controller_input_observed.emit(button)
		else:
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(binding.get("axis", -1))
			motion.axis_value = float(binding.get("direction", -1.0))
			manager.controller_input_observed.emit(motion)
	if panel._auto_map_active:
		return "auto-map did not complete after every requested input"
	if not manager.has_custom_mapping():
		return "completed auto-map did not activate its profile"
	if panel._binding_buttons.size() != (
		ControllerMappingManagerType.ROLE_ORDER.size()
	):
		return "manual override list does not expose every mapped role"
	var conflict_button := panel._binding_buttons.get(
		ControllerMappingManagerType.ROLE_A
	) as Button
	var conflict_style := conflict_button.get_theme_stylebox(
		&"normal"
	) as StyleBoxFlat
	if (
		conflict_style == null
		or conflict_style.bg_color
			!= UtilityPageStyle.OCEAN_DANGER
	):
		return "duplicate controller bindings were not marked in red"
	panel._begin_manual_capture(ControllerMappingManagerType.ROLE_LT)
	panel._process(ControllerMappingPanelType.CAPTURE_NEUTRAL_SECONDS)
	if "left trigger" in panel._progress_label.text.to_lower():
		return "manual remapping still dictates a specific physical input"
	if "any button" not in panel._progress_label.text.to_lower():
		return "manual remapping does not request a generic controller input"
	panel._cancel_capture()
	panel._begin_auto_map()
	panel._process(ControllerMappingPanelType.CAPTURE_NEUTRAL_SECONDS)
	var held_left := InputEventJoypadMotion.new()
	held_left.axis = JOY_AXIS_LEFT_X
	held_left.axis_value = -1.0
	for _index: int in 4:
		manager.controller_input_observed.emit(held_left)
	if panel._auto_map_index != 0:
		return "auto-map accepted repeated analog motion without a neutral gate"
	var first_button := InputEventJoypadButton.new()
	first_button.button_index = JOY_BUTTON_A
	first_button.pressed = true
	manager.controller_input_observed.emit(first_button)
	if panel._auto_map_index != 1 or not panel._waiting_for_neutral:
		return "auto-map did not gate the next step after a captured input"
	manager.controller_input_observed.emit(first_button)
	if panel._auto_map_index != 1:
		return "held input advanced more than one auto-map step"
	panel._cancel_capture()
	return ""


func _validate_virtual_mouse_bounds() -> String:
	var window_size := Vector2(3840.0, 2160.0)
	var bounds: Rect2 = GameUIType.get_virtual_mouse_window_bounds(window_size)
	var expected_margin := Vector2(42.0, 42.0)
	if not bounds.position.is_equal_approx(expected_margin):
		return "4K virtual cursor minimum bounds are incorrect: %s" % bounds
	if not bounds.end.is_equal_approx(window_size - expected_margin):
		return "4K virtual cursor maximum bounds are incorrect: %s" % bounds
	return ""


func _validate_controller_scroll_target() -> String:
	var game_ui := GameUIType.new()
	var page := VBoxContainer.new()
	var scroll := ScrollContainer.new()
	var content := VBoxContainer.new()
	var button := Button.new()
	var footer_button := Button.new()
	root.add_child(page)
	page.add_child(scroll)
	scroll.add_child(content)
	content.add_child(button)
	page.add_child(footer_button)
	var target: ScrollContainer = game_ui._focused_scroll_container(button)
	if target != scroll:
		game_ui.free()
		page.free()
		return "focused menu content did not resolve its scroll container"
	target = game_ui._focused_scroll_container(footer_button)
	if target != scroll:
		game_ui.free()
		page.free()
		return "menu footer focus did not resolve the page's only scroll container"
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if game_ui._focused_scroll_container(button) != null:
		game_ui.free()
		page.free()
		return "controller scrolling ignored a disabled scroll container"
	game_ui.free()
	page.free()
	return ""


func _keyboard_event_count(action: StringName) -> int:
	var count: int = 0
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			count += 1
	return count
