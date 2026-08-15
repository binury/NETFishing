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
const ProfilePageType = preload("res://ui/profile_page.gd")
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
	await _validate_mail_navigation()
	await _validate_profile_confirmation_focus()
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
	page.queue_free()
	await process_frame


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
