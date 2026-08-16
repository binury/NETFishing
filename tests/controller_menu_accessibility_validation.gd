extends SceneTree

const JoinGamePageScene = preload(
	"res://ui/network/join_game_page.tscn"
)
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
const BagItemSpriteScene = preload(
	"res://ui/components/bubble_menu/bag_item_sprite.tscn"
)
const OwnedItemType = preload("res://items/owned_item.gd")
const PlayerHotbarType = preload("res://inventory/player_hotbar.gd")
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
	await _validate_join_game_navigation()
	await _validate_data_settings_navigation()
	await _validate_settings_adjustment_navigation()
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

	page.queue_free()
	await process_frame


func _validate_data_settings_navigation() -> void:
	var panel := SettingsPanelScene.instantiate() as Control
	root.add_child(panel)
	await process_frame
	panel.show()
	var data_page := panel.get_node("%DataPage") as SettingsBubblePage
	data_page.show_page(false)
	for _frame: int in 2:
		await process_frame
	var controls: Array[Control] = [
		panel.get_node("%OpenDataFolder") as Control,
		panel.get_node("%ChangeDataFolder") as Control,
		panel.get_node("%CopyPlayerFingerprint") as Control,
		panel.get_node("%ExportPlayerIdentity") as Control,
		panel.get_node("%ImportPlayerIdentity") as Control,
		panel.get_node("%ExportHostIdentity") as Control,
		panel.get_node("%ImportHostIdentity") as Control,
		panel.get_node("%DataBackButton") as Control,
	]
	for control: Control in controls:
		_expect(
			control.focus_mode == Control.FOCUS_ALL,
			"Data & Identity control %s is not controller-focusable."
			% control.name,
		)
	_assert_directionally_reachable(controls.front(), controls)
	panel.queue_free()
	await process_frame


func _validate_settings_adjustment_navigation() -> void:
	var panel := SettingsPanelScene.instantiate() as SettingsPanel
	root.add_child(panel)
	await process_frame
	panel.show()
	var sound_page := panel.get_node("%SoundPage") as SettingsBubblePage
	sound_page.show_page(false)
	for _frame: int in 2:
		await process_frame
	var environment := panel.get_node("%EnvironmentVolumeSlider") as HSlider
	var sound_back := panel.get_node("%SoundBackButton") as Button
	_assert_neighbor(
		environment,
		&"focus_neighbor_bottom",
		sound_back,
	)
	_assert_neighbor(sound_back, &"focus_neighbor_top", environment)
	sound_page.hide_page()

	var controls_page := panel.get_node("%ControlsPage") as SettingsBubblePage
	controls_page.show_page(false)
	for _frame: int in 2:
		await process_frame
	var parent := panel.get_node("%MouseValue") as Button
	var decrease := panel.get_node("%MouseDecrease") as Button
	var increase := panel.get_node("%MouseIncrease") as Button
	_expect(
		decrease.focus_mode == Control.FOCUS_NONE
		and increase.focus_mode == Control.FOCUS_NONE,
		"Sensitivity adjustment bubbles are reachable before their parent.",
	)
	parent.grab_focus()
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	panel.call("_input", accept)
	_expect(
		decrease.focus_mode == Control.FOCUS_ALL
		and increase.focus_mode == Control.FOCUS_ALL,
		"Selecting a sensitivity parent did not enter its adjustment zone.",
	)
	_assert_neighbor(parent, &"focus_neighbor_left", decrease)
	_assert_neighbor(parent, &"focus_neighbor_right", increase)
	panel.handle_back()
	for _frame: int in 2:
		await process_frame
	_expect(
		decrease.focus_mode == Control.FOCUS_NONE
		and increase.focus_mode == Control.FOCUS_NONE,
		"Leaving an adjustment zone did not hide its child controls.",
	)
	_expect(
		root.gui_get_focus_owner() == parent,
		"Leaving an adjustment zone did not restore its parent focus.",
	)
	panel.queue_free()
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
	menu.visible = true
	menu.call(
		"_show_section_immediate",
		PlayerMenuType.Section.COOLER,
	)
	menu.call("_set_content_interactive", true)
	menu.call("_enter_inventory_tabs_zone")
	for _frame: int in 2:
		await process_frame
	var cooler_tab := menu.get_node("%CoolerSubTab") as Button
	var equipment_tab := menu.get_node("%BagSubTab") as Button
	var items_tab := menu.get_node("%ItemsSubTab") as Button
	_expect(
		root.gui_get_focus_owner() == cooler_tab,
		"Inventory tab zone did not begin on the active Cooler tab.",
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
		menu.get("_current_section") == PlayerMenuType.Section.BAG,
		"Controller Right did not switch from Cooler to Equipment.",
	)
	_expect(
		menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.INVENTORY_TABS,
		"Changing Inventory tabs entered the item-content zone without A.",
	)
	_expect(
		root.gui_get_focus_owner() == equipment_tab,
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
		root.gui_get_focus_owner() == equipment_tab,
		"Controller Down escaped the Inventory tab zone before A.",
	)

	_expect(
		bool(menu.call("_handle_controller_ownership_input", right)),
		"Equipment-to-Items navigation did not consume controller Right.",
	)
	await _wait_for_player_menu_page_transition(menu)
	_expect(
		root.gui_get_focus_owner() == items_tab,
		"Items tab selection did not retain tab focus before A (focus=%s)."
		% root.gui_get_focus_owner(),
	)
	_expect(
		menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.INVENTORY_TABS,
		"Items tab selection changed controller zones before A.",
	)
	var left := InputEventAction.new()
	left.action = &"ui_left"
	left.pressed = true
	_expect(
		bool(menu.call("_handle_controller_ownership_input", left)),
		"Items-to-Equipment navigation did not consume controller Left.",
	)
	await _wait_for_player_menu_page_transition(menu)
	_expect(
		root.gui_get_focus_owner() == equipment_tab,
		"Returning to Equipment did not retain tab focus before A.",
	)

	# Add three representative equipment entries so entering the content zone
	# exercises the real five-column directional layout.
	var item_field := menu.get_node("%BagItemField") as Control
	var bag_nodes: Dictionary = menu.get("_bag_item_nodes")
	var owned_items: Array[OwnedItemType] = []
	for index: int in 3:
		var owned := OwnedItemType.new()
		owned.item_id = StringName("controller_test_item_%d" % index)
		owned_items.append(owned)
		var item_node := BagItemSpriteScene.instantiate() as Button
		item_node.set("item_id", owned.item_id)
		item_node.position = Vector2(60.0 + float(index) * 180.0, 40.0)
		item_field.add_child(item_node)
		bag_nodes[owned.item_id] = item_node
	menu.set("_sorted_bag_items", owned_items)
	menu.call("_set_content_interactive", true)
	menu.call("_configure_bag_item_focus")
	for item_node: Control in bag_nodes.values():
		_expect(
			item_node.focus_mode == Control.FOCUS_NONE,
			"Equipment content remained focusable while tabs owned the controller.",
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
	var first_item := bag_nodes[owned_items[0].item_id] as Control
	var second_item := bag_nodes[owned_items[1].item_id] as Control
	for item_node: Control in bag_nodes.values():
		_expect(
			item_node.focus_mode == Control.FOCUS_ALL,
			"Accepting Equipment did not enable its content focus zone.",
		)
	_expect(
		root.gui_get_focus_owner() == first_item,
		"Entering Equipment did not focus its first item.",
	)
	_expect(
		first_item.focus_neighbor_right == first_item.get_path_to(second_item),
		"Equipment items do not provide horizontal controller navigation.",
	)
	Input.parse_input_event(right)
	for _frame: int in 2:
		await process_frame
	_expect(
		root.gui_get_focus_owner() == second_item,
		"Controller Right did not move between Equipment items.",
	)
	right.pressed = false
	Input.parse_input_event(right)
	right.pressed = true
	_expect(
		bool(menu.call("consume_escape")),
		"Global player-menu Back did not consume Equipment contents.",
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
		bool(menu.call("_handle_controller_ownership_input", accept)),
		"Inventory tab zone did not re-enter Equipment contents.",
	)
	for _frame: int in 2:
		await process_frame

	var favorite := menu.get_node("%FavoriteBubble") as BaseButton
	var sell := menu.get_node("%SellBubble") as BaseButton
	var sell_all := menu.get_node("%SellAllBubble") as BaseButton
	for action: BaseButton in [favorite, sell, sell_all]:
		action.disabled = false
		action.focus_mode = Control.FOCUS_ALL
	var notepad_actions: Array[BaseButton] = [favorite, sell, sell_all]
	menu.call(
		"_configure_controller_notepad_action_focus",
		notepad_actions,
	)
	_expect(
		sell.get_node(sell.focus_neighbor_bottom) == sell_all,
		"Sell All is not reachable below Sell Fish in the notepad zone.",
	)
	_expect(
		sell_all.get_node(sell_all.focus_neighbor_top) == sell,
		"Sell All does not return to the upper notepad actions.",
	)
	menu.set(
		"_controller_ownership",
		PlayerMenuType.ControllerOwnership.NOTEPAD_ACTIONS,
	)
	menu.set("_controller_source_section", PlayerMenuType.Section.BAG)
	menu.set("_controller_source_identity", owned_items[1].item_id)
	menu.call("_apply_inventory_controller_zone_focus_modes")
	_expect(
		bool(menu.call("consume_escape")),
		"Global player-menu Back did not consume the Inventory notepad zone.",
	)
	_expect(
		menu.visible,
		"Global player-menu Back closed Inventory from its notepad zone.",
	)
	_expect(
		menu.get("_controller_ownership")
		== PlayerMenuType.ControllerOwnership.ITEM_LIST,
		"Global player-menu Back did not return the notepad to Inventory contents.",
	)
	for _frame: int in 2:
		await process_frame

	var hotbar := PlayerHotbarType.new()
	menu.set("_hotbar", hotbar)
	var hotbar_slots: Array[StringName] = []
	hotbar_slots.resize(PlayerHotbarType.SLOT_COUNT)
	hotbar_slots.fill(StringName())
	hotbar.set("_slots", hotbar_slots)
	var hotbar_fish_slots: Array[StringName] = []
	hotbar_fish_slots.resize(PlayerHotbarType.SLOT_COUNT)
	hotbar_fish_slots.fill(StringName())
	hotbar_fish_slots[0] = &"controller_test_fish"
	hotbar.set("_fish_slots", hotbar_fish_slots)
	var management_requests: Array[int] = [0]
	menu.controller_hotbar_management_requested.connect(
		func(_initial_slot: int) -> void:
			management_requests[0] += 1
	)
	var hotbar_owned := OwnedItemType.new()
	hotbar_owned.item_id = &"controller_hotbar_source"
	var hotbar_source := BagItemSpriteScene.instantiate() as Button
	hotbar_source.set("item_id", hotbar_owned.item_id)
	hotbar_source.position = Vector2(60.0, 40.0)
	item_field.add_child(hotbar_source)
	bag_nodes[hotbar_owned.item_id] = hotbar_source
	var hotbar_items: Array[OwnedItemType] = [hotbar_owned]
	menu.set("_sorted_bag_items", hotbar_items)
	menu.set(
		"_controller_ownership",
		PlayerMenuType.ControllerOwnership.ITEM_LIST,
	)
	menu.call("_apply_inventory_controller_zone_focus_modes")
	menu.call("_configure_bag_item_focus")
	hotbar_source.grab_focus()
	_expect(
		bool(menu.call("_handle_controller_ownership_input", down)),
		"Down from the final Equipment row did not enter the hotbar zone.",
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
		hotbar.get_fish_catch_id(0).is_empty(),
		"Controller A did not remove the selected fish hotbar assignment.",
	)
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
	hotbar.free()
	menu.queue_free()
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
		for path: NodePath in [
			current.focus_neighbor_left,
			current.focus_neighbor_right,
			current.focus_neighbor_top,
			current.focus_neighbor_bottom,
		]:
			var neighbor := current.get_node_or_null(path) as Control
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
