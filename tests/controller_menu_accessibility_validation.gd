extends SceneTree

const JoinGamePageScene = preload(
	"res://ui/network/join_game_page.tscn"
)
const TitleScreenScene = preload("res://ui/title_screen.tscn")
const PauseMenuScene = preload("res://ui/pause_menu.tscn")
const SettingsPanelScene = preload("res://ui/settings_panel.tscn")
const BubbleConfirmationScene = preload(
	"res://ui/components/bubble_menu/bubble_confirmation_page.tscn"
)
const TitleConfirmationScene = preload(
	"res://ui/title_confirmation_bubble_page.tscn"
)
const MailPageType = preload("res://ui/mail_page.gd")
const LogbookPageType = preload("res://ui/logbook_page.gd")
const ProfilePageType = preload("res://ui/profile_page.gd")
const VoiceProfilesType = preload(
	"res://player/animalese_voice_profiles.gd"
)
const PlayerMenuScene = preload("res://ui/player_menu.tscn")
const PlayerMenuType = preload("res://ui/player_menu.gd")
const PlayerHotbarType = preload("res://inventory/player_hotbar.gd")
const ItemCatalogResource: ItemCatalog = preload(
	"res://items/catalog/item_catalog.tres"
)
const PlayersPageType = preload("res://ui/players_page.gd")
const TheNetPageType = preload("res://ui/the_net_page.gd")
const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const DialogControllerNavigationType = preload(
	"res://ui/file_dialog_controller_navigation.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await _validate_primary_menu_navigation()
	await _validate_join_game_navigation()
	await _validate_data_settings_navigation()
	await _validate_settings_adjustment_navigation()
	await _validate_settings_presentation_requires_apply()
	await _validate_mail_navigation()
	await _validate_profile_confirmation_focus()
	await _validate_profile_voice_navigation()
	await _validate_inventory_tab_zone_transitions()
	await _validate_player_menu_nested_controller_back()
	await _validate_confirmation_dialog_navigation()
	await _validate_bubble_confirmation_navigation()
	_validate_mapping_capture_contract()
	if _failures.is_empty():
		print("Controller menu accessibility validation: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _validate_primary_menu_navigation() -> void:
	var title := TitleScreenScene.instantiate() as Control
	root.add_child(title)
	await process_frame
	(title.get_node("%ButtonCenter") as Control).show()
	(title.get_node("%BubbleField") as Control).show()
	title.call("_update_title_layout")
	title.call("_set_title_bubbles_interactive", true)
	var title_controls: Array[Control] = []
	for candidate: Variant in title.call("_get_title_buttons"):
		var control := candidate as Control
		if control is BaseButton:
			(control as BaseButton).disabled = false
		title_controls.append(control)
	_expect(
		title_controls.size() == 7,
		"Title menu does not expose all seven primary actions.",
	)
	_assert_directionally_reachable(title_controls.front(), title_controls)
	title.queue_free()
	await process_frame

	var pause := PauseMenuScene.instantiate() as Control
	root.add_child(pause)
	pause.show()
	var root_page := pause.get_node("%RootPage") as Control
	root_page.call("show_page", false)
	for _frame: int in 2:
		await process_frame
	var pause_controls: Array[Control] = [
		pause.get_node("%ResumeButton") as Control,
		pause.get_node("%SaveButton") as Control,
		pause.get_node("%JoinGameButton") as Control,
		pause.get_node("%SettingsButton") as Control,
		pause.get_node("%ReturnToTitleButton") as Control,
		pause.get_node("%ResetProgressButton") as Control,
		pause.get_node("%QuitButton") as Control,
	]
	_assert_directionally_reachable(pause_controls.front(), pause_controls)
	pause.queue_free()
	await process_frame


func _validate_join_game_navigation() -> void:
	var page := JoinGamePageScene.instantiate() as Control
	root.add_child(page)
	await process_frame
	page.show()
	var discover := page.get_node("%DiscoverButton") as Button
	var direct := page.get_node("%DirectButton") as Button
	var saved := page.get_node("%SavedButton") as Button
	var recent := page.get_node("%RecentButton") as Button
	var address := page.get_node("%Address") as LineEdit
	var name_edit := page.get_node("%NameEdit") as LineEdit
	var server_list := page.get_node("%ServerList") as ItemList
	var refresh := page.get_node("%RefreshButton") as Button
	var join := page.get_node("%JoinButton") as Button
	var save := page.get_node("%SaveButton") as Button
	var edit := page.get_node("%EditButton") as Button
	var favorite := page.get_node("%FavoriteButton") as Button
	var delete := page.get_node("%DeleteButton") as Button
	var cancel := page.get_node("%CancelButton") as Button
	var back := page.get_node("%BackButton") as Button
	var modes: Array[Control] = [discover, direct, saved, recent]

	address.hide()
	name_edit.hide()
	server_list.show()
	_set_button_state(refresh, true)
	_set_button_state(join, true)
	_set_button_state(save, false)
	_set_button_state(edit, false)
	_set_button_state(favorite, false)
	_set_button_state(delete, false)
	_set_button_state(cancel, false)
	_set_button_state(back, true)
	page.set("_mode", 0)
	page.call("_configure_controller_navigation")
	await process_frame
	_assert_neighbor(discover, &"focus_neighbor_bottom", server_list)
	_assert_neighbor(server_list, &"focus_neighbor_top", discover)
	_assert_neighbor(server_list, &"focus_neighbor_bottom", refresh)
	_assert_neighbor(refresh, &"focus_neighbor_right", join)
	_assert_neighbor(back, &"focus_neighbor_left", join)
	var discover_controls: Array[Control] = modes.duplicate()
	discover_controls.append_array([server_list, refresh, join, back])
	_assert_directionally_reachable(discover, discover_controls)
	var rooms: Array[Dictionary] = [
		{
			"room_id": "controller-default-room",
			"room_name": "Controller default room",
			"current_players": 1,
			"max_players": 8,
		},
		{
			"room_id": "controller-second-room",
			"room_name": "Controller second room",
			"current_players": 2,
			"max_players": 8,
		},
	]
	page.call("_on_discovery_rooms_updated", rooms)
	_expect(
		int(page.get("_selected_discovery_index")) == 0,
		"Discovery should select its first room as soon as results arrive.",
	)
	_expect(
		server_list.is_selected(0),
		"Discovery's visible cursor and selected room should agree immediately.",
	)

	address.show()
	address.editable = true
	server_list.hide()
	_set_button_state(refresh, false)
	_set_button_state(join, true)
	_set_button_state(save, true)
	page.set("_mode", 1)
	page.call("_configure_controller_navigation")
	await process_frame
	_assert_neighbor(direct, &"focus_neighbor_bottom", address)
	_assert_neighbor(address, &"focus_neighbor_top", direct)
	_assert_neighbor(address, &"focus_neighbor_bottom", join)
	var direct_controls: Array[Control] = modes.duplicate()
	direct_controls.append_array([address, join, save, back])
	_assert_directionally_reachable(direct, direct_controls)

	name_edit.show()
	name_edit.editable = true
	page.set("_name_entry_active", true)
	page.call("_configure_controller_navigation")
	await process_frame
	_assert_neighbor(address, &"focus_neighbor_bottom", name_edit)
	_assert_neighbor(name_edit, &"focus_neighbor_top", address)
	page.call("request_back")
	_expect(
		not bool(page.get("_name_entry_active")),
		"Join-game Back should leave the server-name edit substate.",
	)
	_expect(
		page.visible,
		"Join-game Back should not close the browser from an edit substate.",
	)
	await process_frame

	var saved_entries: Array[SavedServerEntry] = []
	server_list.clear()
	for index: int in 3:
		var entry := SavedServerEntry.new()
		entry.entry_id = "controller-saved-%d" % index
		entry.display_name = "Saved server %d" % index
		saved_entries.append(entry)
		server_list.add_item(entry.display_name)
	page.set("_mode", 2)
	page.set("_visible_entries", saved_entries)
	server_list.show()
	page.call("_configure_controller_navigation")
	page.call("_restore_entry_selection_and_focus", 1)
	await process_frame
	_expect(
		server_list.is_selected(1)
		and root.gui_get_focus_owner() == server_list,
		"Saved-server refresh did not restore the same list position.",
	)
	saved_entries.remove_at(1)
	server_list.remove_item(1)
	page.set("_visible_entries", saved_entries)
	page.call("_restore_entry_selection_and_focus", 1)
	await process_frame
	_expect(
		server_list.is_selected(1)
		and (
			page.get("_selected_entry") as SavedServerEntry
		).entry_id == "controller-saved-2",
		"Deleting a saved server did not select the row that replaced it.",
	)
	saved_entries.clear()
	server_list.clear()
	page.set("_visible_entries", saved_entries)
	page.call("_restore_entry_selection_and_focus", 0)
	await process_frame
	_expect(
		root.gui_get_focus_owner() == saved,
		"An empty saved-server list did not return focus to its mode tab.",
	)

	page.queue_free()
	await process_frame


func _validate_data_settings_navigation() -> void:
	var main_source: String = FileAccess.get_file_as_string("res://main/main.gd")
	var data_root_source: String = FileAccess.get_file_as_string(
		"res://network/player_data_root.gd"
	)
	var settings_source: String = FileAccess.get_file_as_string(
		"res://ui/settings_panel.gd"
	)
	_expect(
		not main_source.contains("OS.shell_open")
		and not main_source.contains(
			"status_changed.connect(_on_data_root_status)"
		)
		and not data_root_source.contains("OS.shell_open")
		and settings_source.count("OS.shell_open") == 1,
		(
			"Opening the data folder is not owned exclusively by the Settings "
			+ "Data action."
		),
	)
	var panel := SettingsPanelScene.instantiate() as SettingsPanel
	root.add_child(panel)
	await process_frame
	panel.show()
	for _frame: int in 2:
		await process_frame
	var data_tab := panel.get_node("%DataTab") as Button
	var open_data_folder := panel.get_node("%OpenDataFolder") as Button
	var content_panel := panel.get_node("%ContentPanel") as PanelContainer
	var tab_overlap: float = (
		data_tab.get_global_rect().end.y
		- content_panel.get_global_rect().position.y
	)
	_expect(
		is_equal_approx(tab_overlap, data_tab.size.y * 0.5),
		"Settings content does not cover the lower half of its organizer tabs.",
	)
	var open_activation := {"count": 0}
	open_data_folder.pressed.connect(func() -> void:
		open_activation["count"] = int(open_activation["count"]) + 1
	)
	data_tab.grab_focus()
	var accept_press := InputEventJoypadButton.new()
	accept_press.button_index = JOY_BUTTON_A
	accept_press.pressed = true
	Input.parse_input_event(accept_press)
	await process_frame
	var accept_release := InputEventJoypadButton.new()
	accept_release.button_index = JOY_BUTTON_A
	accept_release.pressed = false
	Input.parse_input_event(accept_release)
	for _frame: int in 2:
		await process_frame
	_expect(
		panel.get_active_page_id() == &"data",
		"Selecting the Data tab did not open the Data page.",
	)
	_expect(
		int(open_activation["count"]) == 0,
		"Selecting the Data tab also activated Open Data Folder.",
	)
	_expect(
		root.gui_get_focus_owner() == data_tab,
		"Selecting the Data tab transferred focus into its actions.",
	)
	open_data_folder.grab_focus()
	_expect(
		root.gui_get_focus_owner() == open_data_folder,
		"Open Data Folder did not accept controller focus.",
	)
	_expect(
		not open_data_folder.disabled,
		"Open Data Folder is unexpectedly disabled.",
	)
	var action_press := InputEventJoypadButton.new()
	action_press.button_index = JOY_BUTTON_A
	action_press.pressed = true
	Input.parse_input_event(action_press)
	await process_frame
	var action_release := InputEventJoypadButton.new()
	action_release.button_index = JOY_BUTTON_A
	action_release.pressed = false
	Input.parse_input_event(action_release)
	for _frame: int in 2:
		await process_frame
	_expect(
		int(open_activation["count"]) == 1,
		(
			"Explicitly accepting Open Data Folder pressed it %d times."
			% int(open_activation["count"])
		),
	)
	_expect(
		panel.find_children(
			"*", "ConfirmationDialog", true, false
		).is_empty(),
		"Open Data Folder left a controller-activatable dialog behind.",
	)
	var change_data_folder := panel.get_node("%ChangeDataFolder") as Button
	var export_progression := panel.get_node("%ExportProgression") as Button
	var import_progression := panel.get_node("%ImportProgression") as Button
	var copy_fingerprint := panel.get_node("%CopyPlayerFingerprint") as Button
	var export_player := panel.get_node("%ExportPlayerIdentity") as Button
	var import_player := panel.get_node("%ImportPlayerIdentity") as Button
	var export_host := panel.get_node("%ExportHostIdentity") as Button
	var import_host := panel.get_node("%ImportHostIdentity") as Button
	var controls: Array[Control] = [
		data_tab,
		open_data_folder,
		change_data_folder,
		export_progression,
		import_progression,
		copy_fingerprint,
		export_player,
		import_player,
		export_host,
		import_host,
		panel.get_node("%ApplySettingsButton") as Control,
		panel.get_node("%SettingsBackButton") as Control,
	]
	for control: Control in controls:
		_expect(
			control.focus_mode == Control.FOCUS_ALL,
			"Data & Identity control %s is not controller-focusable."
			% control.name,
		)
	_assert_neighbor(data_tab, &"focus_neighbor_bottom", open_data_folder)
	_assert_neighbor(
		open_data_folder,
		&"focus_neighbor_right",
		change_data_folder,
	)
	_assert_neighbor(
		open_data_folder,
		&"focus_neighbor_bottom",
		export_progression,
	)
	_assert_neighbor(
		change_data_folder,
		&"focus_neighbor_left",
		open_data_folder,
	)
	_assert_neighbor(
		change_data_folder,
		&"focus_neighbor_bottom",
		import_progression,
	)
	_assert_neighbor(
		export_progression,
		&"focus_neighbor_top",
		open_data_folder,
	)
	_assert_neighbor(
		export_progression,
		&"focus_neighbor_right",
		import_progression,
	)
	_assert_neighbor(
		export_progression,
		&"focus_neighbor_bottom",
		copy_fingerprint,
	)
	_assert_neighbor(
		import_progression,
		&"focus_neighbor_top",
		change_data_folder,
	)
	_assert_neighbor(
		import_progression,
		&"focus_neighbor_left",
		export_progression,
	)
	_assert_neighbor(
		import_progression,
		&"focus_neighbor_bottom",
		copy_fingerprint,
	)
	_assert_neighbor(
		copy_fingerprint,
		&"focus_neighbor_top",
		export_progression,
	)
	_assert_neighbor(
		copy_fingerprint,
		&"focus_neighbor_bottom",
		export_player,
	)
	_assert_neighbor(export_player, &"focus_neighbor_right", import_player)
	_assert_neighbor(export_player, &"focus_neighbor_bottom", export_host)
	_assert_neighbor(import_player, &"focus_neighbor_left", export_player)
	_assert_neighbor(import_player, &"focus_neighbor_bottom", import_host)
	_assert_neighbor(export_host, &"focus_neighbor_top", export_player)
	_assert_neighbor(export_host, &"focus_neighbor_right", import_host)
	_assert_neighbor(import_host, &"focus_neighbor_top", import_player)
	_assert_neighbor(import_host, &"focus_neighbor_left", export_host)
	_assert_directionally_reachable(controls.front(), controls)
	await process_frame
	open_data_folder.grab_focus()
	panel.call("_select_page", &"sound", true)
	_expect(
		panel.get_active_page_id() == &"sound",
		"Settings did not leave the Data page.",
	)
	_expect(
		root.gui_get_focus_owner() == panel.get_node("%SoundTab"),
		"Leaving Data retained focus on a hidden Data action.",
	)
	var sound_down: Control = (
		(panel.get_node("%SoundTab") as Control).find_valid_focus_neighbor(
			SIDE_BOTTOM
		)
	)
	_expect(
		sound_down != null and not panel.get_node("%DataPage").is_ancestor_of(
			sound_down
		),
		"Sound navigation still pointed into the hidden Data page.",
	)
	var hidden_data_activation_count: int = int(open_activation["count"])
	Input.parse_input_event(action_press)
	await process_frame
	Input.parse_input_event(action_release)
	for _frame: int in 2:
		await process_frame
	_expect(
		int(open_activation["count"]) == hidden_data_activation_count,
		"Controller A activated Open Data Folder from another settings page.",
	)
	open_data_folder.pressed.emit()
	await process_frame
	_expect(
		panel.find_children(
			"*", "ConfirmationDialog", true, false
		).is_empty(),
		"A hidden Data action created a folder dialog.",
	)
	panel.call("_select_page", &"data", true)
	await process_frame
	copy_fingerprint.grab_focus()
	var feedback := panel.get_node("%SettingsFeedback") as Label
	feedback.text = "activation boundary intact"
	open_data_folder.pressed.emit()
	await process_frame
	_expect(
		feedback.text == "activation boundary intact",
		(
			"Open Data Folder crossed its activation boundary without owning "
			+ "controller focus."
		),
	)
	panel.hide()
	await process_frame
	var hidden_focus_owner: Control = root.gui_get_focus_owner()
	_expect(
		hidden_focus_owner == null
		or not panel.is_ancestor_of(hidden_focus_owner),
		"Hiding Settings retained focus on one of its controls.",
	)
	_expect(
		panel.find_children("*", "BubbleButton", true, false).is_empty(),
		"Settings children still contain bubble controls.",
	)
	panel.queue_free()
	await process_frame


func _validate_settings_adjustment_navigation() -> void:
	var panel := SettingsPanelScene.instantiate() as SettingsPanel
	root.add_child(panel)
	await process_frame
	panel.show()
	panel.call("_select_page", &"sound", false)
	for _frame: int in 2:
		await process_frame
	var sound_controls: Array[Control] = [
		panel.get_node("%SoundTab") as Control,
		panel.get_node("%MasterVolumeSlider") as Control,
		panel.get_node("%MusicVolumeSlider") as Control,
		panel.get_node("%EffectsVolumeSlider") as Control,
		panel.get_node("%EnvironmentVolumeSlider") as Control,
		panel.get_node("%ApplySettingsButton") as Control,
		panel.get_node("%SettingsBackButton") as Control,
	]
	_assert_directionally_reachable(sound_controls.front(), sound_controls)
	panel.call("_select_page", &"controls", false)
	for _frame: int in 2:
		await process_frame
	var mouse_slider := panel.get_node("%MouseSensitivitySlider") as HSlider
	var controller_slider := panel.get_node(
		"%ControllerSensitivitySlider"
	) as HSlider
	var on_screen_keyboard := panel.get_node(
		"%OnScreenKeyboardToggle"
	) as Button
	var controller_binds := panel.get_node("%ControllerMapping") as Button
	var keyboard_binds := panel.get_node("%KeyboardMapping") as Button
	_expect(
		mouse_slider.focus_mode == Control.FOCUS_ALL
		and controller_slider.focus_mode == Control.FOCUS_ALL,
		"Standard sensitivity sliders are not controller-focusable.",
	)
	_expect(
		is_equal_approx(mouse_slider.step, 0.0005)
		and is_equal_approx(controller_slider.step, 0.1),
		"Sensitivity sliders do not retain their authored increments.",
	)
	_assert_neighbor(
		on_screen_keyboard,
		&"focus_neighbor_bottom",
		controller_binds,
	)
	_assert_neighbor(
		controller_binds,
		&"focus_neighbor_top",
		on_screen_keyboard,
	)
	_assert_neighbor(
		controller_binds,
		&"focus_neighbor_right",
		keyboard_binds,
	)
	_assert_neighbor(
		keyboard_binds,
		&"focus_neighbor_top",
		on_screen_keyboard,
	)
	_assert_neighbor(
		keyboard_binds,
		&"focus_neighbor_left",
		controller_binds,
	)
	var control_inputs: Array[Control] = [
		panel.get_node("%ControlsTab") as Control,
		mouse_slider,
		controller_slider,
		panel.get_node("%InvertYToggle") as Control,
		on_screen_keyboard,
		controller_binds,
		keyboard_binds,
		panel.get_node("%ApplySettingsButton") as Control,
		panel.get_node("%SettingsBackButton") as Control,
	]
	_assert_directionally_reachable(control_inputs.front(), control_inputs)
	panel.queue_free()
	await process_frame


func _validate_settings_presentation_requires_apply() -> void:
	var panel := SettingsPanelScene.instantiate() as SettingsPanel
	var settings_manager := PlayerSettingsManager.new()
	root.add_child(settings_manager)
	root.add_child(panel)
	await process_frame
	panel.open_panel(settings_manager)
	await process_frame
	var chat_dock := panel.get_node("%ChatDockSelector") as OptionButton
	var chat_mode := panel.get_node("%ChatModeSelector") as OptionButton
	var paint_dock := panel.get_node("%PaintDockSelector") as OptionButton
	chat_dock.select(1)
	chat_dock.item_selected.emit(1)
	chat_mode.select(1)
	chat_mode.item_selected.emit(1)
	paint_dock.select(0)
	paint_dock.item_selected.emit(0)
	_expect(
		not settings_manager.current_settings.chat_dock_right
		and not settings_manager.current_settings.chat_mobile_mode
		and settings_manager.current_settings.paint_dock_right
		and not settings_manager.current_settings.presentation_layout_customized,
		(
			"Navigating presentation choices changed saved docking settings "
			+ "before Apply."
		),
	)
	panel.call("_apply_settings")
	_expect(
		settings_manager.current_settings.chat_dock_right
		and settings_manager.current_settings.chat_mobile_mode
		and not settings_manager.current_settings.paint_dock_right
		and settings_manager.current_settings.presentation_layout_customized,
		"Applying deliberate presentation choices did not retain them.",
	)
	panel.close_panel(true)
	panel.queue_free()
	settings_manager.queue_free()
	await process_frame


func _validate_mail_navigation() -> void:
	var page := MailPageType.new() as Control
	root.add_child(page)
	await process_frame
	page.call("activate")
	page.call("set_interactive", true)
	var inbox_list := page.get("_inbox_list") as VBoxContainer
	var entry := Button.new()
	entry.text = "test letter"
	entry.custom_minimum_size = Vector2(1008.0, 54.0)
	inbox_list.add_child(entry)
	await process_frame
	page.call("_refresh_controller_navigation")
	var archive_view := page.get("_archive_view_button") as Button
	var send_mail := page.get("_send_mail_button") as Button
	_assert_neighbor(
		archive_view, &"focus_neighbor_right", send_mail
	)
	_assert_neighbor(archive_view, &"focus_neighbor_bottom", entry)
	_assert_neighbor(send_mail, &"focus_neighbor_bottom", entry)
	_assert_neighbor(entry, &"focus_neighbor_top", archive_view)
	_assert_directionally_reachable(
		archive_view, [archive_view, send_mail, entry]
	)

	var inbox := page.get("_inbox") as Control
	var compose := page.get("_compose") as Control
	var letter := page.get("_letter") as Control
	inbox.hide()
	compose.hide()
	letter.show()
	var accept := page.get("_accept") as Button
	var decline := page.get("_decline") as Button
	var close := page.get("_letter_close") as Button
	var archive := page.get("_archive") as Button
	var delete := page.get("_delete") as Button
	accept.show()
	decline.show()
	delete.disabled = false
	page.call("_refresh_controller_navigation")
	_assert_neighbor(accept, &"focus_neighbor_bottom", decline)
	_assert_neighbor(decline, &"focus_neighbor_bottom", delete)
	_assert_neighbor(delete, &"focus_neighbor_left", archive)
	_assert_neighbor(archive, &"focus_neighbor_left", close)
	_assert_neighbor(close, &"focus_neighbor_top", close)
	_assert_directionally_reachable(
		accept, [accept, decline, close, archive, delete]
	)
	page.queue_free()
	await process_frame


func _validate_profile_confirmation_focus() -> void:
	var page := ProfilePageType.new() as Control
	root.add_child(page)
	await process_frame
	page.call("activate")
	page.call("set_interactive", true)
	page.call("reset_controller_zone")
	var suggestions := page.get("_suggestions") as HBoxContainer
	var suggestion := Button.new()
	suggestion.text = "alternate name"
	suggestions.add_child(suggestion)
	page.call("_apply_controller_zone_focus")
	var account_controls: Array[Control] = []
	for item: Variant in page.call("_account_controller_controls"):
		account_controls.append(item as Control)
	var preview := page.get("_preview") as Control
	var reset_view := page.get("_reset_view_button") as Button
	var reset_view_hint := page.get("_reset_view_controller_hint") as Label
	_expect(
		suggestion in account_controls,
		"Profile name-conflict choices are outside the account zone.",
	)
	_expect(
		suggestion.focus_mode == Control.FOCUS_ALL,
		"Profile name-conflict choices are not controller-focusable.",
	)
	_expect(
		preview.focus_mode == Control.FOCUS_NONE,
		"The profile preview must not take controller focus.",
	)
	_expect(
		reset_view.focus_mode == Control.FOCUS_NONE,
		"The profile reset-view button must not take controller focus.",
	)
	_expect(
		reset_view_hint != null
		and reset_view_hint.text == "Reset View: RS"
		and reset_view_hint.focus_mode == Control.FOCUS_NONE,
		"The profile preview does not present its right-stick reset hint.",
	)
	preview.set("_camera_yaw", 1.0)
	preview.set("_camera_pitch", 0.4)
	preview.set("_camera_distance", 2.5)
	var reset_view_event := InputEventJoypadButton.new()
	reset_view_event.button_index = JOY_BUTTON_RIGHT_STICK
	reset_view_event.pressed = true
	_expect(
		bool(page.call("handle_controller_input", reset_view_event)),
		"Profile customization did not consume right-stick reset.",
	)
	_expect(
		is_equal_approx(float(preview.get("_camera_yaw")), 0.0)
		and is_equal_approx(
			float(preview.get("_camera_pitch")),
			ProfilePreview.DEFAULT_CAMERA_PITCH,
		)
		and is_equal_approx(
			float(preview.get("_camera_distance")),
			ProfilePreview.DEFAULT_CAMERA_DISTANCE,
		),
		"Right-stick click did not restore the default profile preview view.",
	)
	page.call("_show_confirmation", "defaults")
	var confirmation := page.get("_discard_confirmation") as Control
	var confirm := page.get("_confirmation_confirm") as Button
	var keep_editing := page.get("_keep_editing_button") as Button
	_expect(confirmation.visible, "The profile confirmation did not open.")
	_expect(
		confirm.focus_mode == Control.FOCUS_ALL,
		"The profile confirmation action is not controller-focusable.",
	)
	_expect(
		keep_editing.focus_mode == Control.FOCUS_ALL,
		"The profile confirmation cancel action is not controller-focusable.",
	)
	for control: Control in account_controls:
		_expect(
			control.focus_mode == Control.FOCUS_NONE,
			"Profile confirmation leaked focus to %s." % control.name,
		)
	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	_expect(
		bool(page.call("handle_controller_input", cancel_event)),
		"Profile confirmation did not consume controller Back.",
	)
	_expect(
		not confirmation.visible,
		"Controller Back did not close the profile confirmation.",
	)
	for control: Control in account_controls:
		_expect(
			control.focus_mode == Control.FOCUS_ALL,
			"Profile account focus was not restored after confirmation.",
		)
	page.call("_enter_controller_customization")
	for _frame: int in 2:
		await process_frame
	var categories: Array[Control] = []
	var category_list := page.get("_category_list") as VBoxContainer
	for item: Variant in page.call("_controls_under", category_list):
		categories.append(item as Control)
	var initial_category_focus := root.gui_get_focus_owner() as Control
	_expect(
		initial_category_focus in categories,
		"Customize did not focus the appearance feature list.",
	)
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	Input.parse_input_event(down)
	for _frame: int in 2:
		await process_frame
	var next_category_focus := root.gui_get_focus_owner() as Control
	_expect(
		next_category_focus in categories,
		"Moving down dropped focus from the appearance feature list.",
	)
	_expect(
		next_category_focus != initial_category_focus,
		"Moving down did not advance through appearance features.",
	)
	down.pressed = false
	Input.parse_input_event(down)
	var accept_event := InputEventAction.new()
	accept_event.action = &"ui_accept"
	accept_event.pressed = true
	_expect(
		bool(page.call("handle_controller_input", accept_event)),
		"Appearance feature selection did not consume controller Accept.",
	)
	for _frame: int in 3:
		await process_frame
	var option_groups: Array = page.call("_controller_option_groups")
	var option_controls: Array[Control] = []
	if not option_groups.is_empty():
		for item: Variant in option_groups.front():
			var option_control := item as Control
			if option_control != null:
				option_controls.append(option_control)
	_expect(
		root.gui_get_focus_owner() in option_controls,
		"Selecting an appearance feature did not focus its options.",
	)
	var rebuilt_option := root.gui_get_focus_owner() as BaseButton
	if rebuilt_option != null:
		rebuilt_option.pressed.emit()
		for _frame: int in 3:
			await process_frame
		option_groups = page.call("_controller_option_groups")
		option_controls.clear()
		if not option_groups.is_empty():
			for item: Variant in option_groups.front():
				var option_control := item as Control
				if option_control != null:
					option_controls.append(option_control)
		_expect(
			root.gui_get_focus_owner() in option_controls,
			"Rebuilding appearance options dropped controller focus.",
		)
	root.gui_release_focus()
	var controller_down := InputEventJoypadButton.new()
	controller_down.button_index = JOY_BUTTON_DPAD_DOWN
	controller_down.pressed = true
	page.call("handle_controller_input", controller_down)
	_expect(
		root.gui_get_focus_owner() in option_controls,
		"Appearance options did not recover a lost controller focus owner.",
	)
	var cancel_options := InputEventAction.new()
	cancel_options.action = &"ui_cancel"
	cancel_options.pressed = true
	_expect(
		bool(page.call("handle_controller_input", cancel_options)),
		"Appearance options did not consume controller Back.",
	)
	for _frame: int in 2:
		await process_frame
	_expect(
		root.gui_get_focus_owner() in categories,
		"Controller Back did not return to the appearance feature list.",
	)
	page.queue_free()
	await process_frame


func _validate_profile_voice_navigation() -> void:
	var page := ProfilePageType.new() as Control
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(page)
	await process_frame
	page.call("activate")
	page.call("set_interactive", true)
	page.call("_select_category", "voice")
	await process_frame
	page.set(
		"_controller_zone",
		ProfilePageType.ControllerZone.OPTIONS,
	)
	page.set("_controller_option_depth", 0)
	page.call("_apply_controller_zone_focus")
	page.call("_focus_controller_zone")
	await process_frame
	var sample_grid := page.find_child(
		"VoiceSampleSetGrid", true, false
	) as GridContainer
	var pitch_grid := page.find_child(
		"VoicePitchGrid", true, false
	) as GridContainer
	var speed_grid := page.find_child(
		"VoiceSpeedGrid", true, false
	) as GridContainer
	var call_grid := page.find_child(
		"VoiceCallGrid", true, false
	) as GridContainer
	_expect(
		is_instance_valid(sample_grid)
		and is_instance_valid(pitch_grid)
		and is_instance_valid(speed_grid)
		and is_instance_valid(call_grid),
		"The voice page is missing a settings section.",
	)
	if (
		not is_instance_valid(sample_grid)
		or not is_instance_valid(pitch_grid)
		or not is_instance_valid(speed_grid)
		or not is_instance_valid(call_grid)
	):
		page.queue_free()
		await process_frame
		return
	var sample_buttons: Array[Control] = []
	for item: Variant in page.call("_controls_under", sample_grid):
		sample_buttons.append(item as Control)
	_expect(
		sample_buttons.size() == 3,
		"The voice-set row must expose kat, robot, and kim.",
	)
	if sample_buttons.size() != 3:
		page.queue_free()
		await process_frame
		return
	var kat_button := sample_grid.get_node("VoiceSet_kat") as Button
	var robot_button := sample_grid.get_node("VoiceSet_robot") as Button
	var kim_button := sample_grid.get_node("VoiceSet_kim") as Button
	_expect(kat_button.text == "kat", "The default voice set is not labeled kat.")
	_expect(robot_button.text == "robot", "The tone voice set is not labeled robot.")
	_expect(kim_button.text == "kim", "The kim voice set is not labeled kim.")
	_expect(kat_button.button_pressed, "The kat voice set is not selected by default.")
	var option_controls: Array[Control] = []
	var option_groups: Array = page.call("_controller_option_groups")
	for item: Variant in option_groups[0]:
		option_controls.append(item as Control)
	_expect(
		option_controls.size()
		== (
			VoiceProfilesType.SAMPLE_SET_OPTIONS.size()
			+ VoiceProfilesType.OPTIONS.size()
			+ VoiceProfilesType.SPEED_OPTIONS.size()
			+ VoiceProfilesType.CALL_OPTIONS.size()
		),
		"The controller voice zone does not contain every voice setting.",
	)
	_assert_directionally_reachable(kat_button, option_controls)
	var kat_down := kat_button.get_node_or_null(
		kat_button.focus_neighbor_bottom
	) as Control
	_expect(
		kat_down != null and pitch_grid.is_ancestor_of(kat_down),
		"Down from the voice-set row does not enter the pitch row.",
	)
	if OS.has_environment("NETFISHING_PROFILE_VOICE_CAPTURE"):
		await RenderingServer.frame_post_draw
		var capture := root.get_viewport().get_texture().get_image()
		_expect(
			capture.save_png(OS.get_environment(
				"NETFISHING_PROFILE_VOICE_CAPTURE"
			)) == OK,
			"The profile voice-page capture could not be saved.",
		)
	robot_button.grab_focus()
	robot_button.button_pressed = true
	robot_button.pressed.emit()
	await process_frame
	_expect(
		root.gui_get_focus_owner() == robot_button,
		"Selecting robot moved controller focus out of the voice-set row.",
	)
	_expect(
		str(page.get("_draft_sample_set_id")) == "robot",
		"Selecting robot did not update the profile draft.",
	)
	kim_button.grab_focus()
	kim_button.button_pressed = true
	kim_button.pressed.emit()
	await process_frame
	_expect(
		root.gui_get_focus_owner() == kim_button,
		"Selecting kim moved controller focus out of the voice-set row.",
	)
	_expect(
		str(page.get("_draft_sample_set_id")) == "kim",
		"Selecting kim did not update the profile draft.",
	)
	var category_controls: Array[Control] = []
	for item: Variant in page.call(
		"_controls_under", page.get("_category_list")
	):
		category_controls.append(item as Control)
	for category_control: Control in category_controls:
		_expect(
			category_control.focus_mode == Control.FOCUS_NONE,
			"The voice options zone leaked focus into profile categories.",
		)
	page.queue_free()
	await process_frame


func _validate_player_menu_nested_controller_back() -> void:
	var menu := PlayerMenuScene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	menu.visible = true
	menu.set("_current_section", PlayerMenuType.Section.PROFILE)
	var profile_page := menu.get("_profile_page") as Control
	profile_page.call("activate")
	profile_page.call("set_interactive", true)
	profile_page.call("_enter_controller_customization")
	for _frame: int in 2:
		await process_frame
	var categories: Array[Control] = []
	var category_list := profile_page.get(
		"_category_list"
	) as VBoxContainer
	for item: Variant in profile_page.call(
		"_controls_under", category_list
	):
		categories.append(item as Control)
	var initial_focus := root.gui_get_focus_owner() as Control
	menu.call("_reserve_visible_secondary_navigation")
	await process_frame
	_expect(
		root.gui_get_focus_owner() in categories,
		"Player-menu focus reservation disabled appearance features.",
	)
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	Input.parse_input_event(down)
	for _frame: int in 2:
		await process_frame
	_expect(
		root.gui_get_focus_owner() in categories,
		"Player-menu Down dropped appearance feature focus.",
	)
	_expect(
		root.gui_get_focus_owner() != initial_focus,
		"Player-menu Down did not advance appearance feature focus.",
	)
	down.pressed = false
	Input.parse_input_event(down)
	_expect(
		bool(menu.call("consume_escape")),
		"Global player-menu Back did not consume the Profile category zone.",
	)
	_expect(
		menu.visible,
		"Global player-menu Back closed Profile from a nested zone.",
	)
	_expect(
		int(profile_page.get("_controller_zone"))
		== ProfilePageType.ControllerZone.ACCOUNT,
		"Global player-menu Back did not return Profile to its account zone.",
	)

	var logbook_page := menu.get("_catalog_logbook") as Control
	logbook_page.set("_active", true)
	logbook_page.set("_interactive", true)
	logbook_page.set(
		"_controller_zone",
		LogbookPageType.ControllerZone.DETAILS,
	)
	menu.set("_current_section", PlayerMenuType.Section.LOGBOOK)
	_expect(
		bool(menu.call("consume_escape")),
		"Global player-menu Back did not consume the Logbook detail zone.",
	)
	_expect(
		menu.visible,
		"Global player-menu Back closed Logbook from a nested zone.",
	)
	_expect(
		int(logbook_page.get("_controller_zone"))
		== LogbookPageType.ControllerZone.ENTRIES,
		"Global player-menu Back did not return Logbook to creature selection.",
	)

	var net_page := menu.get("_the_net_page") as Control
	net_page.set("_active", true)
	net_page.set("_interactive", true)
	net_page.set(
		"_controller_zone",
		TheNetPageType.ControllerZone.CLAIMS,
	)
	menu.set("_current_section", PlayerMenuType.Section.NET)
	_expect(
		bool(menu.call("consume_escape")),
		"Global player-menu Back did not consume the Fishnet claims zone.",
	)
	_expect(
		menu.visible,
		"Global player-menu Back closed Fishnet from a nested zone.",
	)
	_expect(
		int(net_page.get("_controller_zone"))
		== TheNetPageType.ControllerZone.TABS,
		"Global player-menu Back did not return Fishnet to its tabs.",
	)

	var mail_page := menu.get("_mail_page") as Control
	mail_page.set("_active", true)
	mail_page.set("_interactive", true)
	(mail_page.get("_inbox") as Control).hide()
	(mail_page.get("_compose") as Control).show()
	(mail_page.get("_letter") as Control).hide()
	menu.set("_current_section", PlayerMenuType.Section.MAIL)
	_expect(
		bool(menu.call("consume_escape")),
		"Global player-menu Back did not consume the Mail compose zone.",
	)
	_expect(
		menu.visible,
		"Global player-menu Back closed Mail while composing.",
	)
	_expect(
		(mail_page.get("_inbox") as Control).visible,
		"Global player-menu Back did not return Mail to the inbox.",
	)

	var mapping_manager := ControllerMappingManagerType.new()
	var bindings: Dictionary = ControllerMappingManagerType.default_bindings()
	bindings[str(ControllerMappingManagerType.ROLE_B)] = {
		"kind": "button",
		"button": int(JOY_BUTTON_Y),
	}
	mapping_manager.set("_profiles", {
		"default": {
			"controller_name": "controller",
			"bindings": bindings,
		},
	})
	menu.call("setup_controller_mapping", mapping_manager)
	var players_page := menu.get("_players_page") as Control
	players_page.set("_active", true)
	players_page.set("_interactive", true)
	players_page.set(
		"_controller_zone", PlayersPageType.ControllerZone.BODY
	)
	menu.set("_current_section", PlayerMenuType.Section.PLAYERS)
	_expect(
		bool(menu.call("consume_escape")),
		"Global player-menu Back did not consume the Online body zone.",
	)
	_expect(
		menu.visible,
		"Global player-menu Back closed Online from its body zone.",
	)
	_expect(
		int(players_page.get("_controller_zone"))
		== PlayersPageType.ControllerZone.TABS,
		"Global player-menu Back did not return Online to its tabs.",
	)
	players_page.set(
		"_controller_zone", PlayersPageType.ControllerZone.BODY
	)
	var mapped_back := InputEventJoypadButton.new()
	mapped_back.device = 0
	mapped_back.button_index = JOY_BUTTON_Y
	mapped_back.pressed = true
	_expect(
		bool(menu.call(
			"_handle_controller_ownership_input", mapped_back
		)),
		"Player menu did not consume a mapped controller Back press.",
	)
	_expect(
		int(players_page.get("_controller_zone"))
		== PlayersPageType.ControllerZone.TABS,
		"Mapped controller Back skipped the previous player-page zone.",
	)
	menu.queue_free()
	await process_frame
	mapping_manager.free()


func _validate_inventory_tab_zone_transitions() -> void:
	var menu := PlayerMenuScene.instantiate() as Control
	root.add_child(menu)
	await process_frame
	var inventory_state := Node.new()
	root.add_child(inventory_state)
	var bag := PlayerBag.new()
	var catches := FishInventory.new()
	var storage_capacity := PlayerCoolerCapacity.new()
	var layout := PlayerInventoryLayout.new()
	var hotbar := PlayerHotbarType.new()
	for node: Node in [bag, catches, storage_capacity, layout, hotbar]:
		inventory_state.add_child(node)
	bag.setup(ItemCatalogResource)
	layout.setup(bag, catches, ItemCatalogResource, storage_capacity)
	assert(layout.restore_backpack_level(1))
	bag.set_inventory_layout(layout)
	catches.set_inventory_layout(layout)
	hotbar.setup(bag, ItemCatalogResource, catches, layout)
	assert(bag.add_item(&"basic_fishing_rod", 1))
	assert(bag.add_item(&"coffee", 1))
	assert(bag.add_item(&"worms", 1))
	assert(layout.move_entry(
		PlayerInventoryLayout.EntryKind.ITEM,
		&"basic_fishing_rod",
		PlayerInventoryLayout.InventoryContainer.INVENTORY,
		9,
	))
	assert(hotbar.assign_item(0, &"coffee"))
	menu.set("_bag", bag)
	menu.set("_inventory", catches)
	menu.set("_hotbar", hotbar)
	menu.set("_inventory_layout", layout)
	menu.set("_item_catalog", ItemCatalogResource)
	var inventory_grid := menu.get("_general_inventory_grid") as GeneralInventoryGrid
	inventory_grid.setup(
		layout,
		bag,
		catches,
		hotbar,
		ItemCatalogResource,
		PlayerInventoryLayout.InventoryContainer.INVENTORY,
	)
	menu.visible = true
	menu.call(
		"_show_section_immediate",
		PlayerMenuType.Section.BAG,
	)
	menu.call("_set_content_interactive", true)
	menu.call("_enter_inventory_tabs_zone")
	for _frame: int in 2:
		await process_frame
	var inventory_tab := menu.get_node("%BagSubTab") as Button
	var tackle_tab := menu.get_node("%TackleSubTab") as Button
	_expect(
		root.gui_get_focus_owner() == inventory_tab,
		"Inventory tab zone did not begin on the unified Inventory tab.",
	)
	_expect(inventory_tab.text == "Inventory", "Unified tab is not labelled Inventory.")
	_expect(
		not (menu.get_node("%CoolerSubTab") as Button).visible
		and not (menu.get_node("%ItemsSubTab") as Button).visible,
		"Legacy Cooler or Items tabs remain visible.",
	)

	var right := InputEventAction.new()
	right.action = &"ui_right"
	right.pressed = true
	_expect(
		bool(menu.call("_handle_controller_ownership_input", right)),
		"Inventory tab zone did not consume controller Right.",
	)
	await _wait_for_player_menu_page_transition(menu)
	_expect(
		menu.get("_current_section") == PlayerMenuType.Section.TACKLE_BOX,
		"Controller Right did not switch from Inventory to Tackle.",
	)
	_expect(
		menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.INVENTORY_TABS,
		"Changing Inventory tabs entered the item-content zone without A.",
	)
	_expect(
		root.gui_get_focus_owner() == tackle_tab,
		"Changing Inventory tabs did not keep focus on the selected tab.",
	)
	var down := InputEventAction.new()
	down.action = &"ui_down"
	down.pressed = true
	_expect(
		bool(menu.call("_handle_controller_ownership_input", down)),
		"Inventory tab zone did not consume controller Down.",
	)
	await process_frame
	_expect(
		root.gui_get_focus_owner() == tackle_tab,
		"Controller Down escaped the Inventory tab zone before A.",
	)
	var left := InputEventAction.new()
	left.action = &"ui_left"
	left.pressed = true
	_expect(
		bool(menu.call("_handle_controller_ownership_input", left)),
		"Tackle-to-Inventory navigation did not consume controller Left.",
	)
	_expect(
		menu.get("_current_section") == PlayerMenuType.Section.BAG
		or bool(menu.get("_page_transitioning")),
		"Tackle-to-Inventory input did not start the Inventory transition.",
	)
	await _wait_for_player_menu_page_transition(menu)
	_expect(
		root.gui_get_focus_owner() == inventory_tab,
		"Returning to Inventory did not retain tab focus before A.",
	)
	menu.call("_set_content_interactive", true)
	menu.call("_configure_bag_item_focus")
	var active_slots := inventory_grid.get_slots()
	for slot: GeneralInventorySlot in active_slots:
		_expect(
			slot.focus_mode == Control.FOCUS_NONE,
			"Inventory slots remained focusable while tabs owned the controller.",
		)

	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	_expect(
		bool(menu.call("_handle_controller_ownership_input", accept)),
		"Inventory tab zone did not consume controller A.",
	)
	_expect(
		menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.ITEM_LIST,
		"Controller A did not explicitly enter Inventory contents.",
	)
	for _frame: int in 2:
		await process_frame
	_expect(
		menu.get("_current_section") == PlayerMenuType.Section.BAG,
		"Entering Inventory contents changed section to %s."
		% menu.get("_current_section"),
	)
	var first_item := active_slots[0] as Control
	var second_item := active_slots[1] as Control
	for slot: GeneralInventorySlot in active_slots:
		_expect(
			slot.focus_mode == Control.FOCUS_ALL,
			"Accepting Inventory did not enable its content focus zone.",
		)
	_expect(
		root.gui_get_focus_owner() == first_item,
		"Entering Inventory did not focus its first slot.",
	)
	_expect(
		first_item.focus_neighbor_right == first_item.get_path_to(second_item),
		"Inventory slots do not provide horizontal controller navigation.",
	)
	Input.parse_input_event(right)
	for _frame: int in 2:
		await process_frame
	_expect(
		menu.get("_current_section") == PlayerMenuType.Section.BAG,
		"Inventory slot navigation changed section to %s."
		% menu.get("_current_section"),
	)
	_expect(
		root.gui_get_focus_owner() == second_item,
		"Controller Right did not move between Inventory slots.",
	)
	var right_release := InputEventAction.new()
	right_release.action = &"ui_right"
	right_release.pressed = false
	Input.parse_input_event(right_release)
	_expect(
		bool(menu.call("consume_escape")),
		"Global player-menu Back did not consume Inventory contents.",
	)
	_expect(
		menu.visible,
		"Global player-menu Back closed Inventory from its content zone.",
	)
	_expect(
		menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.INVENTORY_TABS,
		"Global player-menu Back did not return Inventory contents to tabs.",
	)
	for _frame: int in 2:
		await process_frame
	_expect(
		menu.get("_current_section") == PlayerMenuType.Section.BAG,
		"Returning from Inventory contents changed section to %s."
		% menu.get("_current_section"),
	)
	_expect(
		bool(menu.call("_handle_controller_ownership_input", accept)),
		"Inventory tab zone did not re-enter Inventory contents.",
	)
	for _frame: int in 2:
		await process_frame
	var notepad_source := active_slots[9]
	notepad_source.grab_focus()
	var context_press := InputEventJoypadButton.new()
	context_press.button_index = JOY_BUTTON_Y
	context_press.pressed = true
	_expect(
		bool(menu.call(
			"_handle_controller_ownership_input", context_press
		)),
		"Controller Y did not open the selected Inventory notepad.",
	)
	_expect(
		menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.NOTEPAD_ACTIONS,
		"Inventory notepad did not become the active controller zone.",
	)
	_expect(
		(menu.get_node("%BagDetailConstellation") as Control).visible,
		"Inventory notepad remained hidden after controller Y.",
	)
	_expect(
		bool(menu.call("consume_escape")),
		"Controller B did not close the Inventory notepad.",
	)
	_expect(
		not (menu.get_node("%BagDetailConstellation") as Control).visible
		and menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.ITEM_LIST,
		"Closing the Inventory notepad did not restore the item zone.",
	)
	for _frame: int in 2:
		await process_frame
	var accept_release := InputEventJoypadButton.new()
	accept_release.button_index = JOY_BUTTON_A
	accept_release.pressed = false
	notepad_source.grab_focus()
	menu.call("_handle_controller_ownership_input", accept)
	menu.call("_handle_controller_ownership_input", accept_release)
	_expect(
		str(menu.get("_inventory_move_identity")) == "basic_fishing_rod",
		"Controller A did not pick up the focused Inventory item.",
	)
	var move_target := active_slots[10]
	move_target.grab_focus()
	menu.call("_handle_controller_ownership_input", accept)
	menu.call("_handle_controller_ownership_input", accept_release)
	_expect(
		layout.get_key_at(
			PlayerInventoryLayout.InventoryContainer.INVENTORY, 10
		) == PlayerInventoryLayout.item_key(&"basic_fishing_rod"),
		"Controller A did not place the picked-up item in its target slot.",
	)
	var management_requests: Array[int] = [0]
	menu.controller_hotbar_management_requested.connect(
		func(_initial_slot: int) -> void:
			management_requests[0] += 1
	)
	menu.set(
		"_controller_ownership",
		PlayerMenuType.ControllerOwnership.ITEM_LIST,
	)
	menu.call("_apply_inventory_controller_zone_focus_modes")
	menu.call("_configure_bag_item_focus")
	var hotbar_source := active_slots[10]
	_expect(
		menu.get("_current_section") == PlayerMenuType.Section.BAG,
		"Hotbar navigation test left the unified Inventory section (%s)."
		% menu.get("_current_section"),
	)
	_expect(
		hotbar_source.focus_mode == Control.FOCUS_ALL,
		"Final active Inventory row was not controller-focusable.",
	)
	hotbar_source.grab_focus()
	_expect(
		root.gui_get_focus_owner() == hotbar_source,
		"Final Inventory row did not accept controller focus before Hotbar entry.",
	)
	_expect(
		bool(menu.call("_controller_focus_is_on_last_inventory_row")),
		"Focused Inventory slot was not recognized as part of the final row.",
	)
	_expect(
		bool(menu.call("_handle_controller_ownership_input", down)),
		"Down from the final Inventory row did not enter the hotbar zone.",
	)
	_expect(
		menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.HOTBAR_MANAGEMENT,
		"Equipment-to-hotbar navigation did not transfer controller ownership.",
	)
	_expect(
		management_requests[0] == 1,
		"Equipment-to-hotbar navigation did not open hotbar management.",
	)
	var up := InputEventAction.new()
	up.action = &"ui_up"
	up.pressed = true
	_expect(
		bool(menu.call("_handle_controller_ownership_input", up)),
		"Up from hotbar management was not consumed.",
	)
	_expect(
		menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.ITEM_LIST,
		"Up from hotbar management did not return to Inventory contents.",
	)
	for _frame: int in 2:
		await process_frame
	_expect(
		root.gui_get_focus_owner() == hotbar_source,
		"Up from hotbar management did not restore the source item focus.",
	)
	_expect(
		bool(menu.call("_handle_controller_ownership_input", down)),
		"Inventory contents could not re-enter hotbar management.",
	)
	_expect(
		management_requests[0] == 2,
		"Re-entering the hotbar did not reopen hotbar management.",
	)
	_expect(
		bool(menu.call("_handle_controller_ownership_input", accept)),
		"Hotbar management did not consume controller A.",
	)
	_expect(
		hotbar.get_item_id(0).is_empty(),
		"Controller A did not return the selected hotbar item to Inventory.",
	)
	_expect(layout.is_item_in_inventory(&"coffee"), "Cleared hotbar item was lost.")
	_expect(
		bool(menu.call("consume_escape")),
		"Global player-menu Back did not consume hotbar management.",
	)
	_expect(
		menu.visible,
		"Global player-menu Back closed Inventory from hotbar management.",
	)
	_expect(
		menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.ITEM_LIST,
		"Global player-menu Back did not return the hotbar to Inventory contents.",
	)
	for _frame: int in 2:
		await process_frame

	menu.call("_show_section_immediate", PlayerMenuType.Section.TACKLE_BOX)
	menu.call("_set_content_interactive", true)
	menu.set(
		"_controller_ownership",
		PlayerMenuType.ControllerOwnership.ITEM_LIST,
	)
	menu.call("_apply_inventory_controller_zone_focus_modes")
	menu.call("_configure_tackle_item_focus")
	for _frame: int in 2:
		await process_frame
	var tackle_buttons: Dictionary = menu.get("_tackle_item_buttons")
	var worms_button := tackle_buttons.get(&"worms") as Button
	_expect(worms_button != null, "Tackle test could not find unlocked worms.")
	if worms_button != null:
		worms_button.grab_focus()
		menu.call("_handle_controller_ownership_input", accept)
		menu.call("_handle_controller_ownership_input", accept_release)
		_expect(
			StringName(menu.get("_selected_tackle_item_id")).is_empty(),
			"Controller A still activates a bait or lure inventory action.",
		)
		_expect(
			not (menu.get_node("%TackleDetailPanel") as Control).visible,
			"Controller A opened the tackle notepad reserved for Y.",
		)
		_expect(
			bool(menu.call(
				"_handle_controller_ownership_input", context_press
			)),
			"Controller Y did not open the bait/lure equip notepad.",
		)
		_expect(
			menu.get("_controller_ownership")
			== PlayerMenuType.ControllerOwnership.NOTEPAD_ACTIONS,
			"Tackle notepad did not take controller ownership after Y.",
		)
		_expect(
			(menu.get_node("%TackleDetailPanel") as Control).visible,
			"Controller Y left the bait/lure equip notepad hidden.",
		)
	menu.queue_free()
	inventory_state.queue_free()
	await process_frame


func _wait_for_player_menu_page_transition(menu: Control) -> void:
	var frames_waited: int = 0
	while bool(menu.get("_page_transitioning")) and frames_waited < 120:
		await process_frame
		frames_waited += 1
	# Same-section Equipment/Items changes do not tween, but they restore the
	# active tab focus with a deferred call just like completed page changes.
	for _frame: int in 2:
		await process_frame
	_expect(
		not bool(menu.get("_page_transitioning")),
		"Inventory page transition did not finish within 120 frames.",
	)


func _validate_mapping_capture_contract() -> void:
	var title_source: String = FileAccess.get_file_as_string(
		"res://ui/title_screen.gd"
	)
	var game_ui_source: String = FileAccess.get_file_as_string(
		"res://ui/game_ui.gd"
	)
	var chat_source: String = FileAccess.get_file_as_string(
		"res://ui/chat_ui.gd"
	)
	var main_source: String = FileAccess.get_file_as_string(
		"res://main/main.gd"
	)
	_expect(
		title_source.contains(
			"_settings_panel.is_input_mapping_capturing()"
		),
		"Title input does not respect every active binding capture.",
	)
	_expect(
		game_ui_source.contains("or is_input_mapping_capturing()"),
		"Controller menu scrolling does not respect every binding capture.",
	)
	_expect(
		chat_source.contains("func _configure_controller_focus()"),
		"Chat does not author controller routes for its exterior controls.",
	)
	_expect(
		chat_source.contains(
			"Control.FOCUS_ALL if _opened else Control.FOCUS_NONE"
		),
		"Passive chat controls can steal world controller focus.",
	)
	_expect(
		main_source.contains("func _configure_popup_dialog("),
		"Runtime popup dialogs do not receive authored controller routes.",
	)


func _validate_confirmation_dialog_navigation() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.ok_button_text = "continue"
	var fields := VBoxContainer.new()
	var first := LineEdit.new()
	first.placeholder_text = "passphrase"
	first.custom_minimum_size = Vector2(420.0, 42.0)
	fields.add_child(first)
	var second := LineEdit.new()
	second.placeholder_text = "confirm passphrase"
	second.custom_minimum_size = Vector2(420.0, 42.0)
	fields.add_child(second)
	dialog.add_child(fields)
	root.add_child(dialog)
	dialog.popup_centered(Vector2i(560, 300))
	for _frame: int in 2:
		await process_frame
	DialogControllerNavigationType.configure_scope(dialog, first)
	await process_frame
	var controls: Array[Control] = (
		DialogControllerNavigationType.interactive_controls(dialog)
	)
	_expect(
		controls.has(first) and controls.has(second),
		"Confirmation-dialog text fields are not controller reachable.",
	)
	_expect(
		controls.has(dialog.get_ok_button())
		and controls.has(dialog.get_cancel_button()),
		"Confirmation-dialog actions are not controller reachable.",
	)
	_assert_directionally_reachable(first, controls)
	_expect(
		dialog.gui_get_focus_owner() == first,
		"Confirmation dialog did not focus its requested entry control.",
	)
	dialog.hide()
	await process_frame
	root.gui_release_focus()
	dialog.popup_centered(Vector2i(560, 300))
	await process_frame
	DialogControllerNavigationType.configure_scope(dialog, first)
	await process_frame
	_expect(
		dialog.gui_get_focus_owner() == first,
		"A reopened dialog did not restore controller focus.",
	)
	dialog.queue_free()
	await process_frame


func _validate_bubble_confirmation_navigation() -> void:
	for scene: PackedScene in [
		BubbleConfirmationScene,
		TitleConfirmationScene,
	]:
		var page := scene.instantiate() as Control
		root.add_child(page)
		await process_frame
		page.show()
		page.call("_set_interactive", true)
		var confirm := page.get_node("BubbleCluster/ConfirmButton") as Button
		var cancel := page.get_node("BubbleCluster/CancelButton") as Button
		_assert_neighbor(confirm, &"focus_neighbor_left", cancel)
		_assert_neighbor(confirm, &"focus_neighbor_right", cancel)
		_assert_neighbor(confirm, &"focus_neighbor_top", confirm)
		_assert_neighbor(confirm, &"focus_neighbor_bottom", confirm)
		_assert_neighbor(cancel, &"focus_neighbor_left", confirm)
		_assert_neighbor(cancel, &"focus_neighbor_right", confirm)
		_assert_neighbor(cancel, &"focus_neighbor_top", cancel)
		_assert_neighbor(cancel, &"focus_neighbor_bottom", cancel)
		page.queue_free()
		await process_frame
func _set_button_state(button: Button, shown: bool) -> void:
	button.visible = shown
	button.disabled = false


func _assert_neighbor(
	origin: Control,
	property: StringName,
	expected: Control,
) -> void:
	var path: NodePath = origin.get(property)
	_expect(
		not path.is_empty(),
		"%s has no %s neighbor." % [origin.name, property],
	)
	if path.is_empty():
		return
	var actual := origin.get_node_or_null(path) as Control
	_expect(
		actual == expected,
		"%s points %s to %s instead of %s."
		% [
			origin.name,
			property,
			actual.name if actual != null else "nothing",
			expected.name,
		],
	)


func _assert_directionally_reachable(
	start: Control,
	controls: Array[Control],
) -> void:
	var expected: Dictionary[int, bool] = {}
	for control: Control in controls:
		expected[control.get_instance_id()] = true
	var visited: Dictionary[int, bool] = {start.get_instance_id(): true}
	var pending: Array[Control] = [start]
	while not pending.is_empty():
		var current: Control = pending.pop_front()
		for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			var neighbor: Control = current.find_valid_focus_neighbor(side)
			if (
				neighbor == null
				or not expected.has(neighbor.get_instance_id())
				or visited.has(neighbor.get_instance_id())
			):
				continue
			visited[neighbor.get_instance_id()] = true
			pending.append(neighbor)
	_expect(
		visited.size() == expected.size(),
		"Only %d of %d controls are directionally reachable from %s."
		% [visited.size(), expected.size(), start.name],
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
