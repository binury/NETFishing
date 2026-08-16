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
		failure = _validate_portmaster_launcher()
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
			"19000000010000000100000000010000",
			"muOS-Keys",
		)
	)
	for expected_binding: String in [
		"a:b0",
		"b:b1",
		"x:b3",
		"y:b2",
		"leftshoulder:b4",
		"rightshoulder:b5",
		"lefttrigger:b10",
		"righttrigger:b11",
		"back:b6",
		"start:b7",
		"guide:b8",
		"leftstick:b9",
		"rightstick:b12",
		"leftx:a0",
		"righty:a3",
	]:
		if expected_binding not in muos_mapping:
			return "muOS compatibility mapping omitted " + expected_binding
	if not muos_mapping.begins_with(
		"19000000010000000100000000010000,muOS-Keys,"
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
		return "recognized muOS controller would be replaced at runtime"
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
	if ControllerMappingManagerType.ROLE_LABELS.get(
		ControllerMappingManagerType.ROLE_RIGHT_STICK_CLICK, ""
	) != "sneak":
		return "right-stick click is not presented as sneak"
	if ControllerMappingManagerType.BUTTON_ACTION_ROLES.get(
		&"sneak", &""
	) != ControllerMappingManagerType.ROLE_RIGHT_STICK_CLICK:
		return "right-stick click is not assigned to the sneak action"
	if ControllerMappingManagerType.ROLE_LABELS.get(
		ControllerMappingManagerType.ROLE_Y, ""
	) != "interact / character call":
		return "Y does not present its contextual gameplay actions"
	if ControllerMappingManagerType.BUTTON_ACTION_ROLES.get(
		&"interact", &""
	) != ControllerMappingManagerType.ROLE_Y:
		return "Y is not assigned to the interact action"
	if ControllerMappingManagerType.BUTTON_ACTION_ROLES.get(
		&"character_call", &""
	) != ControllerMappingManagerType.ROLE_Y:
		return "Y is not assigned to the character-call action"
	if not _has_joy_button(&"character_call", JOY_BUTTON_Y):
		return "character call does not default to Y"
	if not _has_joy_button(&"interact", JOY_BUTTON_Y):
		return "interact does not default to Y"
	if not _has_joy_button(&"sneak", JOY_BUTTON_RIGHT_STICK):
		return "sneak does not default to right-stick click"
	var trigger_button := InputEventJoypadButton.new()
	trigger_button.device = manager.get_active_device_id()
	trigger_button.button_index = JOY_BUTTON_MISC1
	trigger_button.pressed = true
	var trigger_binding: Dictionary = manager.binding_from_event(
		ControllerMappingManagerType.ROLE_POINTER_MODIFIER,
		trigger_button,
	)
	if str(trigger_binding.get("kind", "")) != "button":
		return "trigger role did not accept a button-backed handheld trigger"
	var trigger_motion := InputEventJoypadMotion.new()
	trigger_motion.device = manager.get_active_device_id()
	trigger_motion.axis = JOY_AXIS_TRIGGER_RIGHT
	trigger_motion.axis_value = 1.0
	trigger_binding = manager.binding_from_event(
		ControllerMappingManagerType.ROLE_POINTER_MODIFIER,
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
	custom[str(ControllerMappingManagerType.ROLE_POINTER_MODIFIER)] = (
		trigger_binding
	)
	if not manager.replace_active_bindings(custom):
		return "valid custom mapping could not be saved"
	if not manager.has_custom_mapping():
		return "saved custom mapping did not become active"
	if _keyboard_event_count(&"jump") != keyboard_events_before:
		return "controller remapping changed keyboard bindings"
	var active_button := InputEventJoypadButton.new()
	active_button.device = manager.get_active_device_id()
	active_button.button_index = JOY_BUTTON_X
	active_button.pressed = true
	if not manager.event_matches_role(
		active_button,
		ControllerMappingManagerType.ROLE_A,
	):
		return "active controller event did not match its custom role"
	var inactive_button := active_button.duplicate() as InputEventJoypadButton
	inactive_button.device = manager.get_active_device_id() + 1
	if manager.event_matches_role(
		inactive_button,
		ControllerMappingManagerType.ROLE_A,
	):
		return "inactive controller event matched the active profile"
	var inactive_release := InputEventJoypadButton.new()
	inactive_release.device = manager.get_active_device_id() + 2
	inactive_release.button_index = JOY_BUTTON_A
	inactive_release.pressed = false
	var active_device_before_release: int = manager.get_active_device_id()
	manager._input(inactive_release)
	if manager.get_active_device_id() != active_device_before_release:
		return "inactive controller button release stole ownership"
	for event: InputEvent in InputMap.action_get_events(&"jump"):
		if (
			event is InputEventJoypadButton
			and event.device != manager.get_active_device_id()
		):
			return "custom InputMap event was not scoped to the active device"
	manager._axis_rest_by_device["4"] = {str(JOY_AXIS_LEFT_X): 0.0}
	var drift := InputEventJoypadMotion.new()
	drift.device = 4
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.12
	if manager._axis_motion_claims_device(drift):
		return "minor inactive-stick drift claimed controller ownership"
	manager._input(drift)
	if manager.get_active_device_id() != active_device_before_release:
		return "minor inactive-stick drift changed the active controller"
	drift.axis_value = 0.72
	if not manager._axis_motion_claims_device(drift):
		return "intentional inactive-stick motion did not claim ownership"
	manager._input(drift)
	if manager.get_active_device_id() != drift.device:
		return "intentional stick motion did not change controller ownership"
	for event: InputEvent in InputMap.action_get_events(&"jump"):
		if event is InputEventJoypadButton and event.device != drift.device:
			return "active-device change did not rescope InputMap events"
	manager._set_active_controller(active_device_before_release)
	manager._axis_rest_by_device["5"] = {str(JOY_AXIS_LEFT_X): 0.0}
	manager._on_joy_connection_changed(5, false)
	if manager._axis_rest_by_device.has("5"):
		return "disconnected controller retained stale axis calibration"
	if not FileAccess.file_exists(
		ControllerMappingManagerType.PROFILE_PATH
	):
		return "controller mapping was not stored device-locally"
	return ""


func _validate_portmaster_launcher() -> String:
	const launcher_path: String = "res://scripts/portmaster/NETfishing.sh"
	if not FileAccess.file_exists(launcher_path):
		return "PortMaster launcher template is missing"
	var launcher: String = FileAccess.get_file_as_string(launcher_path)
	for expected_fragment: String in [
		"19004ca6010000000100000000010000",
		"19000000010000000100000000010000",
		"a:b0,b:b1,x:b3,y:b2",
		"leftshoulder:b4,rightshoulder:b5",
		"lefttrigger:b10,righttrigger:b11",
		"guide:b8,start:b7,back:b6",
		"leftstick:b9",
		"rightstick:b12",
		"netfishing_controllerconfig=\"$GODOT_MUOS_MAPPING\"",
		"GPTOKEYB_CONFIG=\"$GAMEDIR/netfishing.gptk\"",
		"$GPTOKEYB \"NETfishing.aarch64\" -c \"$GPTOKEYB_CONFIG\" &",
		"pm_platform_helper \"$GAME_EXECUTABLE\"",
		"\"$GAME_LAUNCHER\"",
		"\"$CONTROLLER_MAPPING_FILE\"",
		"pm_finish",
	]:
		if expected_fragment not in launcher:
			return "PortMaster launcher omitted " + expected_fragment
	if "$'\\n'" in launcher:
		return "PortMaster launcher appends mappings across a Weston-unsafe newline"
	const game_launcher_path: String = (
		"res://scripts/portmaster/launch-netfishing.sh"
	)
	if not FileAccess.file_exists(game_launcher_path):
		return "PortMaster game launcher wrapper is missing"
	var game_launcher: String = FileAccess.get_file_as_string(
		game_launcher_path
	)
	for expected_fragment: String in [
		"SDL_GAMECONTROLLERCONFIG=\"$(<\"$CONTROLLER_MAPPING_FILE\")\"",
		"export SDL_GAMECONTROLLERCONFIG",
		"exec \"$@\"",
	]:
		if expected_fragment not in game_launcher:
			return "PortMaster game launcher omitted " + expected_fragment
	return ""


func _validate_auto_map(manager: ControllerMappingManagerType) -> String:
	if manager.get_role_prompt(ControllerMappingManagerType.ROLE_LT) != (
		"press or squeeze LT"
	):
		return "auto-map does not identify the LT control"
	if manager.get_role_prompt(ControllerMappingManagerType.ROLE_RT) != (
		"press or squeeze RT"
	):
		return "auto-map does not identify the RT control"
	var panel := ControllerMappingPanelType.new()
	root.add_child(panel)
	panel.setup(manager)
	panel.open_panel()
	var mapping_scrolls: Array[Node] = panel.find_children(
		"", "ScrollContainer", true, false
	)
	if mapping_scrolls.is_empty():
		return "controller mapper does not contain its mapping list"
	if not (mapping_scrolls[0] as ScrollContainer).follow_focus:
		return "controller mapper does not scroll to follow controller focus"
	var first_binding := panel._binding_buttons.get(
		ControllerMappingManagerType.ROLE_ORDER.front()
	) as Button
	var last_binding := panel._binding_buttons.get(
		ControllerMappingManagerType.ROLE_ORDER.back()
	) as Button
	if first_binding.get_node(first_binding.focus_neighbor_top) != first_binding:
		return "controller mapper loses focus above its first row"
	if last_binding.get_node(last_binding.focus_neighbor_bottom) != (
		panel._close_button
	):
		return "controller mapper cannot reach Done from its last row"
	if panel._close_button.get_node(
		panel._close_button.focus_neighbor_top
	) != last_binding:
		return "controller mapper cannot return from Done to its last row"
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
			button.device = manager.get_active_device_id()
			button.button_index = int(binding.get("button", -1))
			button.pressed = true
			manager.controller_input_observed.emit(button)
		else:
			var motion := InputEventJoypadMotion.new()
			motion.device = manager.get_active_device_id()
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
	manager.set_binding(
		ControllerMappingManagerType.ROLE_B,
		ControllerMappingManagerType.default_bindings()[
			str(ControllerMappingManagerType.ROLE_B)
		] as Dictionary,
	)
	panel._begin_manual_capture(
		ControllerMappingManagerType.ROLE_POINTER_MODIFIER
	)
	panel._process(ControllerMappingPanelType.CAPTURE_NEUTRAL_SECONDS)
	if "left trigger" in panel._progress_label.text.to_lower():
		return "manual remapping still dictates a specific physical input"
	if "any button" not in panel._progress_label.text.to_lower():
		return "manual remapping does not request a generic controller input"
	panel._cancel_capture()
	panel._begin_auto_map()
	panel._process(ControllerMappingPanelType.CAPTURE_NEUTRAL_SECONDS)
	var lone_button := InputEventJoypadButton.new()
	lone_button.device = manager.get_active_device_id()
	lone_button.button_index = JOY_BUTTON_B
	lone_button.pressed = true
	manager.controller_input_observed.emit(lone_button)
	if not panel._auto_map_active or panel._auto_map_index != 1:
		return "a single controller button cancelled auto-map"
	panel._cancel_capture()
	panel._begin_auto_map()
	panel._process(ControllerMappingPanelType.CAPTURE_NEUTRAL_SECONDS)
	var left_bumper := InputEventJoypadButton.new()
	left_bumper.device = manager.get_active_device_id()
	left_bumper.button_index = JOY_BUTTON_LEFT_SHOULDER
	left_bumper.pressed = true
	manager.controller_input_observed.emit(left_bumper)
	var right_bumper := InputEventJoypadButton.new()
	right_bumper.device = manager.get_active_device_id()
	right_bumper.button_index = JOY_BUTTON_RIGHT_SHOULDER
	right_bumper.pressed = true
	manager.controller_input_observed.emit(right_bumper)
	panel._process(ControllerMappingPanelType.CANCEL_COMBO_HOLD_SECONDS - 0.01)
	if not panel._auto_map_active:
		return "bumper combo cancelled auto-map before the hold threshold"
	panel._process(0.02)
	if panel._auto_map_active or panel.is_capturing():
		return "sustained bumper combo did not cancel auto-map"
	panel._begin_auto_map()
	panel._process(ControllerMappingPanelType.CAPTURE_NEUTRAL_SECONDS)
	var held_left := InputEventJoypadMotion.new()
	held_left.device = manager.get_active_device_id()
	held_left.axis = JOY_AXIS_LEFT_X
	held_left.axis_value = -1.0
	for _index: int in 4:
		manager.controller_input_observed.emit(held_left)
	if panel._auto_map_index != 0:
		return "auto-map accepted repeated analog motion without a neutral gate"
	var first_button := InputEventJoypadButton.new()
	first_button.device = manager.get_active_device_id()
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


func _has_joy_button(action: StringName, button_index: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var button := event as InputEventJoypadButton
		if button != null and button.button_index == button_index:
			return true
	return false
