extends SceneTree

const KeyboardMouseMappingManagerType = preload(
	"res://settings/keyboard_mouse_mapping_manager.gd"
)
const KeyboardMouseMappingPanelType = preload(
	"res://ui/keyboard_mouse_mapping_panel.gd"
)
const SettingsPanelScene = preload("res://ui/settings_panel.tscn")
const FishingSpotScene = preload("res://fishing/fishing_spot.tscn")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const CatchDifficultyProfileType = preload(
	"res://fishing/catch_difficulty_profile.gd"
)
const PlayerType = preload("res://player/player.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var manager := KeyboardMouseMappingManagerType.new()
	root.add_child(manager)
	await process_frame
	var defaults: Dictionary = manager.get_active_bindings()
	assert(
		defaults.size()
		== KeyboardMouseMappingManagerType.ROLE_ORDER.size()
	)
	assert(
		str(defaults[
			str(KeyboardMouseMappingManagerType.ROLE_PRIMARY_ACTION)
		].get("kind", "")) == "mouse_button"
	)
	assert(
		str(defaults[
			str(KeyboardMouseMappingManagerType.ROLE_ALTERNATE_REEL)
		].get("kind", "")) == "key"
	)
	assert(_has_physical_key(&"reel_alternate", KEY_QUOTELEFT))
	assert(_event_count(&"reel_alternate", true) == 0)
	assert(
		str(defaults[
			str(KeyboardMouseMappingManagerType.ROLE_CHAT)
		].get("kind", "")) == "key"
	)

	var joypad_events_before: int = _event_count(&"jump", true)
	var rebind_key := InputEventKey.new()
	rebind_key.physical_keycode = KEY_R
	rebind_key.pressed = true
	var jump_binding: Dictionary = manager.binding_from_event(rebind_key)
	assert(manager.validate_binding(jump_binding))
	assert(manager.set_binding(
		KeyboardMouseMappingManagerType.ROLE_JUMP,
		jump_binding,
	))
	assert(manager.has_custom_mapping())
	assert(FileAccess.file_exists(
		KeyboardMouseMappingManagerType.MAPPING_PATH
	))
	assert(_has_physical_key(&"jump", KEY_R))
	assert(_event_count(&"jump", true) == joypad_events_before)

	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_XBUTTON1
	mouse_event.pressed = true
	var mouse_binding: Dictionary = manager.binding_from_event(mouse_event)
	assert(manager.set_binding(
		KeyboardMouseMappingManagerType.ROLE_PRIMARY_ACTION,
		mouse_binding,
	))
	assert(_has_mouse_button(&"fish_primary", MOUSE_BUTTON_XBUTTON1))
	assert(not _has_mouse_button(&"fish_primary", MOUSE_BUTTON_LEFT))
	var alternate_reel_key := InputEventKey.new()
	alternate_reel_key.physical_keycode = KEY_G
	alternate_reel_key.pressed = true
	assert(manager.set_binding(
		KeyboardMouseMappingManagerType.ROLE_ALTERNATE_REEL,
		manager.binding_from_event(alternate_reel_key),
	))
	assert(_has_physical_key(&"reel_alternate", KEY_G))
	assert(_event_count(&"reel_alternate", true) == 0)

	var joypad_event := InputEventJoypadButton.new()
	joypad_event.button_index = JOY_BUTTON_A
	joypad_event.pressed = true
	assert(manager.binding_from_event(joypad_event).is_empty())

	var panel := KeyboardMouseMappingPanelType.new()
	root.add_child(panel)
	panel.setup(manager)
	panel.open_panel()
	await process_frame
	assert(_has_label_text(panel, "keyboard binds"))
	var scrolls: Array[Node] = panel.find_children(
		"", "ScrollContainer", true, false
	)
	assert(not scrolls.is_empty())
	assert((scrolls.front() as ScrollContainer).follow_focus)
	var first_binding := panel._binding_buttons.get(
		KeyboardMouseMappingManagerType.ROLE_ORDER.front()
	) as Button
	var last_binding := panel._binding_buttons.get(
		KeyboardMouseMappingManagerType.ROLE_ORDER.back()
	) as Button
	assert(first_binding.get_node(
		first_binding.focus_neighbor_top
	) == first_binding)
	assert(last_binding.get_node(
		last_binding.focus_neighbor_bottom
	) == panel._close_button)
	assert(panel._close_button.get_node(
		panel._close_button.focus_neighbor_top
	) == last_binding)
	panel._begin_capture(KeyboardMouseMappingManagerType.ROLE_INTERACT)
	var interact_key := InputEventKey.new()
	interact_key.physical_keycode = KEY_F
	interact_key.pressed = true
	panel._input(interact_key)
	assert(_has_physical_key(&"interact", KEY_F))
	assert(not panel.is_capturing())

	var settings_panel := SettingsPanelScene.instantiate() as SettingsPanel
	root.add_child(settings_panel)
	await process_frame
	var controller_bubble := settings_panel.get_node(
		"%ControllerMapping"
	) as Button
	var keyboard_bubble := settings_panel.get_node("%KeyboardMapping") as Button
	assert(controller_bubble.text == "controller binds")
	assert(keyboard_bubble.text == "keyboard binds")

	assert(manager.reset_mapping())
	assert(not manager.has_custom_mapping())
	assert(not FileAccess.file_exists(
		KeyboardMouseMappingManagerType.MAPPING_PATH
	))
	assert(_has_physical_key(&"jump", KEY_SPACE))
	assert(_has_mouse_button(&"fish_primary", MOUSE_BUTTON_LEFT))
	assert(_has_physical_key(&"reel_alternate", KEY_QUOTELEFT))
	assert(_event_count(&"reel_alternate", true) == 0)
	assert(_has_physical_key(&"open_chat", KEY_T))
	assert(_event_count(&"jump", true) == joypad_events_before)

	var legacy_bindings: Dictionary = manager.get_active_bindings()
	legacy_bindings.erase(str(
		KeyboardMouseMappingManagerType.ROLE_ALTERNATE_REEL
	))
	legacy_bindings[str(KeyboardMouseMappingManagerType.ROLE_JUMP)] = (
		manager.binding_from_event(rebind_key)
	)
	var legacy_file := FileAccess.open(
		KeyboardMouseMappingManagerType.MAPPING_PATH,
		FileAccess.WRITE,
	)
	assert(legacy_file != null)
	legacy_file.store_string(JSON.stringify({
		"format_version": KeyboardMouseMappingManagerType.LEGACY_FORMAT_VERSION,
		"bindings": legacy_bindings,
	}))
	legacy_file.close()
	var migrated_manager := KeyboardMouseMappingManagerType.new()
	root.add_child(migrated_manager)
	await process_frame
	assert(migrated_manager.has_custom_mapping())
	assert(_has_physical_key(&"jump", KEY_R))
	assert(_has_physical_key(&"reel_alternate", KEY_QUOTELEFT))
	assert(migrated_manager.reset_mapping())

	var fishing_spot := FishingSpotScene.instantiate() as FishingSpotType
	root.add_child(fishing_spot)
	await process_frame
	var local_player := PlayerType.new()
	fishing_spot.set("_local_player", local_player)
	fishing_spot.set("_gameplay_input_enabled", true)
	fishing_spot.state = FishingSpotType.FishingState.FIGHTING
	var catch_controller := fishing_spot.get_node("%CatchController")
	var catch_profile := CatchDifficultyProfileType.new()
	catch_profile.barrier_count_min = 0
	catch_profile.barrier_count_max = 0
	catch_controller.start_encounter(catch_profile, 1.0, 1)
	var alternate_echo := InputEventKey.new()
	alternate_echo.physical_keycode = KEY_QUOTELEFT
	alternate_echo.pressed = true
	alternate_echo.echo = true
	assert(alternate_echo.is_action(&"reel_alternate"))
	fishing_spot._unhandled_input(alternate_echo)
	assert(not bool(catch_controller.get("_reel_input_held")))
	var alternate_key_press := InputEventKey.new()
	alternate_key_press.physical_keycode = KEY_QUOTELEFT
	alternate_key_press.pressed = true
	assert(alternate_key_press.is_action(&"reel_alternate"))
	fishing_spot._unhandled_input(alternate_key_press)
	assert(bool(catch_controller.get("_reel_input_held")))
	catch_controller.set_reel_input(false)
	var alternate_press := InputEventAction.new()
	alternate_press.action = &"reel_alternate"
	alternate_press.pressed = true
	fishing_spot._unhandled_input(alternate_press)
	assert(bool(catch_controller.get("_reel_input_held")))
	var alternate_release := InputEventAction.new()
	alternate_release.action = &"reel_alternate"
	alternate_release.pressed = false
	fishing_spot._unhandled_input(alternate_release)
	assert(not bool(catch_controller.get("_reel_input_held")))
	fishing_spot.free()
	local_player.free()

	settings_panel.queue_free()
	panel.queue_free()
	migrated_manager.queue_free()
	manager.queue_free()
	print("Keyboard and mouse mapping validation: PASS")
	quit(0)


func _event_count(action: StringName, joypad: bool) -> int:
	var result: int = 0
	for event: InputEvent in InputMap.action_get_events(action):
		if joypad == (
			event is InputEventJoypadButton or event is InputEventJoypadMotion
		):
			result += 1
	return result


func _has_physical_key(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var key_event := event as InputEventKey
		if key_event != null and key_event.physical_keycode == key:
			return true
	return false


func _has_mouse_button(action: StringName, button: MouseButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		var mouse_event := event as InputEventMouseButton
		if mouse_event != null and mouse_event.button_index == button:
			return true
	return false


func _has_label_text(parent: Node, expected: String) -> bool:
	for node: Node in parent.find_children("", "Label", true, false):
		if (node as Label).text == expected:
			return true
	return false
