class_name PlayersPage
extends Control

const TOGGLE_STATE_COLOR := Color("c3dfe6")
const DialogControllerNavigationType = preload(
	"res://ui/file_dialog_controller_navigation.gd"
)

enum ControllerZone {
	TABS,
	BODY,
}

var _service: NetworkPlayerListService
var _discovery: DiscoveryClient
var _count_label: Label
var _tabs: HBoxContainer
var _list: VBoxContainer
var _status: Label
var _host_settings_panel: PanelContainer
var _room_name_edit: LineEdit
var _online_toggle: Button
var _online_state_label: Label
var _discoverable_toggle: Button
var _discoverable_state_label: Label
var _host_discovery_status: Label
var _current_tab := 0
var _active: bool = false
var _interactive: bool = false
var _controller_zone: ControllerZone = ControllerZone.TABS


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UtilityPageStyle.apply_page(self)
	_build()


func setup(
	service: NetworkPlayerListService,
	discovery: DiscoveryClient,
) -> void:
	_service = service
	_discovery = discovery
	_service.entries_changed.connect(_refresh)
	_service.moderation_finished.connect(func(_ok: bool, message: String) -> void:
		_status.text = message
		_refresh()
	)
	if _discovery != null:
		_discovery.host_settings_changed.connect(
			_on_host_settings_changed
		)
		_discovery.host_status_changed.connect(_on_host_status_changed)
	_refresh()


func activate() -> void:
	_active = true
	_refresh()
	reset_controller_zone()


func deactivate() -> void:
	_active = false
	_status.text = ""
	set_interactive(false)


func set_interactive(interactive: bool) -> void:
	_interactive = interactive and _active
	var body_controls: Array[Control] = _body_controls()
	for index: int in _tabs.get_child_count():
		var tab := _tabs.get_child(index) as Button
		if tab != null:
			tab.focus_mode = (
				Control.FOCUS_ALL
				if _interactive
				and _controller_zone == ControllerZone.TABS
				and tab.visible
				else Control.FOCUS_NONE
			)
	for control: Control in body_controls:
		var button := control as BaseButton
		control.focus_mode = (
			Control.FOCUS_ALL
			if _interactive
			and _controller_zone == ControllerZone.BODY
			and (button == null or not button.disabled)
			else Control.FOCUS_NONE
		)
	ControllerFocusNavigation.configure_spatial_neighbors(body_controls)


func reset_controller_zone() -> void:
	_controller_zone = ControllerZone.TABS
	set_interactive(_interactive)
	call_deferred("_focus_controller_zone")


func handle_controller_input(event: InputEvent) -> bool:
	if not _active or not _interactive:
		return false
	if event.is_action_pressed("ui_cancel"):
		if _controller_zone == ControllerZone.BODY:
			_controller_zone = ControllerZone.TABS
			set_interactive(_interactive)
			call_deferred("_focus_controller_zone")
			return true
		return false
	if _controller_zone == ControllerZone.TABS:
		var direction: int = 0
		if event.is_action_pressed("ui_left"):
			direction = -1
		elif event.is_action_pressed("ui_right"):
			direction = 1
		if direction != 0:
			_select_adjacent_controller_tab(direction)
			return true
		if event.is_action_pressed("ui_accept"):
			if not _body_controls().is_empty():
				_controller_zone = ControllerZone.BODY
				set_interactive(_interactive)
				call_deferred("_focus_controller_zone")
			return true
	return false


func _select_adjacent_controller_tab(direction: int) -> void:
	var available: Array[int] = []
	for index: int in _tabs.get_child_count():
		var tab := _tabs.get_child(index) as Button
		if tab != null and tab.visible:
			available.append(index)
	var current_position: int = available.find(_current_tab)
	var target_position: int = clampi(
		current_position + direction,
		0,
		available.size() - 1,
	)
	if target_position != current_position:
		_select_tab(available[target_position])


func _focus_controller_zone() -> void:
	if not _interactive:
		return
	if _controller_zone == ControllerZone.TABS:
		var tab := _tabs.get_child(_current_tab) as Button
		if tab != null and tab.visible:
			tab.grab_focus()
		return
	_focus_first()


func _body_controls() -> Array[Control]:
	var controls: Array[Control] = []
	_collect_focusable_player_controls(self, controls)
	return controls


func _build() -> void:
	var margin: MarginContainer = UtilityPageStyle.build_laptop_screen(self)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 9)
	margin.add_child(root)
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 16)
	root.add_child(tab_row)
	_tabs = HBoxContainer.new()
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tabs.add_theme_constant_override("separation", 10)
	tab_row.add_child(_tabs)
	for index: int in 3:
		var button := Button.new()
		button.text = ["players", "relationships", "banned"][index]
		button.toggle_mode = true
		button.pressed.connect(_select_tab.bind(index))
		UtilityPageStyle.apply_ocean_button(button)
		_tabs.add_child(button)
	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 17)
	_count_label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tab_row.add_child(_count_label)
	_build_host_settings(root)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(
		UtilityPageStyle.LAPTOP_CONTENT_SIZE.x,
		0.0,
	)
	_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_list)
	_status = Label.new()
	_status.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	root.add_child(_status)


func _build_host_settings(root: VBoxContainer) -> void:
	_host_settings_panel = PanelContainer.new()
	_host_settings_panel.add_theme_stylebox_override(
		"panel", UtilityPageStyle.row_style(false)
	)
	root.add_child(_host_settings_panel)
	var settings := VBoxContainer.new()
	settings.custom_minimum_size.y = 104.0
	settings.add_theme_constant_override("separation", 8)
	_host_settings_panel.add_child(settings)
	var identity_row := HBoxContainer.new()
	identity_row.add_theme_constant_override("separation", 10)
	settings.add_child(identity_row)
	var label := Label.new()
	label.text = "room name"
	label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	identity_row.add_child(label)
	_room_name_edit = LineEdit.new()
	_room_name_edit.custom_minimum_size = Vector2(0.0, 42.0)
	_room_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_room_name_edit.max_length = DiscoveryClient.MAX_ROOM_NAME_LENGTH
	_room_name_edit.placeholder_text = "Player Name's Server"
	UtilityPageStyle.apply_ocean_line_edit(_room_name_edit)
	_room_name_edit.text_submitted.connect(
		func(_value: String) -> void: _commit_room_name()
	)
	_room_name_edit.focus_exited.connect(_commit_room_name)
	identity_row.add_child(_room_name_edit)
	var access_row := HBoxContainer.new()
	access_row.add_theme_constant_override("separation", 10)
	settings.add_child(access_row)
	_online_toggle = _build_host_toggle("online", access_row)
	_online_state_label = _online_toggle.get_node("StateBadge/State") as Label
	_online_toggle.pressed.connect(_on_online_pressed)
	_discoverable_toggle = _build_host_toggle("discovery", access_row)
	_discoverable_state_label = (
		_discoverable_toggle.get_node("StateBadge/State") as Label
	)
	_discoverable_toggle.pressed.connect(_on_discoverable_pressed)
	_host_discovery_status = Label.new()
	_host_discovery_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host_discovery_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_host_discovery_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_host_discovery_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_host_discovery_status.add_theme_font_size_override("font_size", 14)
	_host_discovery_status.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	access_row.add_child(_host_discovery_status)


func _build_host_toggle(label_text: String, row: HBoxContainer) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(140.0, 46.0)
	button.text = label_text
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.clip_contents = false
	UtilityPageStyle.apply_ocean_button(button)
	row.add_child(button)
	var badge := PanelContainer.new()
	badge.name = "StateBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 2
	button.add_child(badge)
	badge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	badge.offset_left = -39.0
	badge.offset_top = -12.0
	badge.offset_right = 39.0
	badge.offset_bottom = 12.0
	var state_label := Label.new()
	state_label.name = "State"
	state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	state_label.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	state_label.add_theme_font_size_override("font_size", 15)
	state_label.add_theme_color_override("font_color", TOGGLE_STATE_COLOR)
	badge.add_child(state_label)
	return button


func _set_host_toggle_state(
	button: Button,
	state_label: Label,
	state_text: String,
	enabled: bool,
) -> void:
	state_label.text = state_text
	var badge := state_label.get_parent() as PanelContainer
	badge.add_theme_stylebox_override(
		"panel",
		UtilityPageStyle.rounded_style(
			UtilityPageStyle.OCEAN_SELECTED
			if enabled
			else UtilityPageStyle.OCEAN_FIELD,
			12,
		),
	)
	button.queue_redraw()


func _select_tab(index: int) -> void:
	if index == 2 and (_service == null or not _service.is_local_moderator()):
		return
	_current_tab = index
	_refresh()
	call_deferred("_focus_controller_zone")


func _refresh() -> void:
	if _service == null or _list == null:
		return
	_count_label.text = "%d / %d connected" % [
		_service.get_connected_count(), _service.get_max_players(),
	]
	if _current_tab == 2 and not _service.is_local_moderator():
		_current_tab = 0
	for index: int in _tabs.get_child_count():
		var button := _tabs.get_child(index) as Button
		button.button_pressed = index == _current_tab
		button.visible = index != 2 or _service.is_local_moderator()
	_refresh_host_settings()
	for child: Node in _list.get_children():
		child.queue_free()
	match _current_tab:
		0:
			_build_active_rows()
		1:
			_build_relationship_rows()
		2:
			_build_ban_rows()
	if _controller_zone == ControllerZone.BODY and _body_controls().is_empty():
		_controller_zone = ControllerZone.TABS
	set_interactive(_interactive)


func _refresh_host_settings() -> void:
	if _host_settings_panel == null:
		return
	var host_visible: bool = _service.is_local_host() and _current_tab == 0
	_host_settings_panel.visible = host_visible
	if not host_visible or _discovery == null:
		return
	if not _room_name_edit.has_focus():
		_room_name_edit.text = _discovery.get_room_name()
	var is_open: bool = _service.is_open_host()
	var is_discoverable: bool = _discovery.is_discoverable()
	_set_host_toggle_state(
		_online_toggle,
		_online_state_label,
		"OPEN" if is_open else "CLOSED",
		is_open,
	)
	_set_host_toggle_state(
		_discoverable_toggle,
		_discoverable_state_label,
		"ON" if is_discoverable else "OFF",
		is_discoverable,
	)
	_online_toggle.disabled = not _service.is_local_host()
	_online_toggle.tooltip_text = (
		"Close this game to new connections."
		if is_open
		else "Open this game so other players can connect."
	)
	var can_publish: bool = (
		_service.is_local_host()
		and _discovery.is_configured()
		and is_open
	)
	_discoverable_toggle.disabled = not can_publish
	_discoverable_toggle.tooltip_text = (
		"Stop advertising this game in the public room browser."
		if is_discoverable
		else "Advertise this open game in the public room browser."
		if can_publish
		else "Open the game before enabling discovery."
		if _discovery.is_configured()
		else "Room discovery is not configured in this build."
	)
	_on_host_status_changed(
		_discovery.get_host_status_message(),
		_discovery.host_status_is_error(),
	)


func _commit_room_name() -> void:
	if _discovery == null:
		return
	if not _discovery.set_room_name(_room_name_edit.text):
		_room_name_edit.text = _discovery.get_room_name()
	else:
		_room_name_edit.text = _discovery.get_room_name()


func _on_online_pressed() -> void:
	if _service == null or not _service.is_local_host():
		return
	_service.set_host_open(not _service.is_open_host())
	_refresh_host_settings()


func _on_discoverable_pressed() -> void:
	if _discovery == null:
		return
	_discovery.set_discoverable(not _discovery.is_discoverable())
	_refresh_host_settings()


func _on_host_settings_changed(
	room_name: String,
	discoverable: bool,
) -> void:
	if _room_name_edit != null and not _room_name_edit.has_focus():
		_room_name_edit.text = room_name
	if _discoverable_state_label != null:
		_set_host_toggle_state(
			_discoverable_toggle,
			_discoverable_state_label,
			"ON" if discoverable else "OFF",
			discoverable,
		)
	_refresh_host_settings()


func _on_host_status_changed(message: String, is_error: bool) -> void:
	if _host_discovery_status == null:
		return
	var tooltip_only: bool = message in [
		"Open the game before listing it publicly.",
		"Open the game before enabling discovery.",
	]
	_host_discovery_status.text = "" if tooltip_only else message
	_host_discovery_status.visible = not _host_discovery_status.text.is_empty()
	_host_discovery_status.add_theme_color_override(
		"font_color",
		UtilityPageStyle.OCEAN_DANGER
		if is_error
		else UtilityPageStyle.OCEAN_TEXT_SECONDARY,
	)


func _build_active_rows() -> void:
	if _service.is_local_moderator():
		_build_session_artwork_controls()
	var entries := _service.get_entries()
	if entries.is_empty():
		_add_empty("No authenticated players.")
		return
	for entry: PlayerListEntry in entries:
		var row := _make_row()
		var identity := Label.new()
		identity.custom_minimum_size.x = 250
		identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var markers: Array[String] = []
		if entry.is_host:
			markers.append("host")
		if entry.is_operator:
			markers.append("operator")
		if entry.is_local_player:
			markers.append("You")
		identity.text = "%s%s · %s\n%s" % [
			entry.display_name,
			"  [%s]" % ", ".join(markers) if not markers.is_empty() else "",
			entry.compact_fingerprint,
			entry.continuity_state,
		]
		identity.tooltip_text = "Full identity fingerprint:\n%s" % (
			entry.full_fingerprint
		)
		identity.add_theme_color_override(
			"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
		)
		row.add_child(identity)
		var ping := Label.new()
		ping.custom_minimum_size.x = 60
		ping.text = (
			"Local" if entry.is_host
			else "%d ms" % entry.ping_to_host_ms
			if entry.ping_to_host_ms >= 0 else "—"
		)
		ping.add_theme_color_override(
			"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
		)
		row.add_child(ping)
		var mute := Button.new()
		mute.text = "unmute" if entry.muted else "mute"
		mute.disabled = entry.is_local_player
		mute.pressed.connect(_toggle_mute.bind(entry))
		UtilityPageStyle.apply_compact_ocean_button(mute)
		row.add_child(mute)
		var block := Button.new()
		block.text = "block"
		block.disabled = entry.is_local_player
		block.pressed.connect(_confirm_block.bind(entry))
		UtilityPageStyle.apply_compact_ocean_button(block)
		row.add_child(block)
		if entry.can_manage_operator:
			var operator := Button.new()
			operator.text = "deop" if entry.is_operator else "op"
			operator.pressed.connect(_confirm_operator.bind(entry))
			UtilityPageStyle.apply_compact_ocean_button(operator)
			row.add_child(operator)
		var kick := Button.new()
		kick.text = "kick"
		kick.disabled = not entry.can_kick
		kick.pressed.connect(_confirm_kick.bind(entry))
		UtilityPageStyle.apply_compact_ocean_button(kick)
		row.add_child(kick)
		var ban := Button.new()
		ban.text = "ban"
		ban.disabled = not entry.can_ban
		ban.pressed.connect(_confirm_ban.bind(entry))
		UtilityPageStyle.apply_compact_ocean_button(ban)
		row.add_child(ban)


func _build_session_artwork_controls() -> void:
	var counts: Vector2i = _service.get_session_artwork_counts()
	var row := _make_row()
	var label := Label.new()
	label.custom_minimum_size.x = 600
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text = "session artwork · %d layers · %d painted pixels" % [
		counts.x, counts.y,
	]
	label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	row.add_child(label)
	var reset := Button.new()
	reset.text = "reset paint"
	reset.disabled = counts.x == 0
	reset.tooltip_text = "Clears all shared artwork from this session."
	reset.pressed.connect(func() -> void:
		_confirm(
			"Clear all shared paint from this session?\nThis cannot be undone.",
			_service.reset_session_artwork,
		)
	)
	UtilityPageStyle.apply_compact_ocean_button(reset)
	row.add_child(reset)


func _build_relationship_rows() -> void:
	var records := _service.get_relationships()
	if records.is_empty():
		_add_empty("No muted or blocked identities.")
		return
	for record: Dictionary in records:
		var row := _make_row()
		var label := Label.new()
		label.custom_minimum_size.x = 560
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fingerprint := str(record["fingerprint"])
		label.text = "%s · %s    %s" % [
			str(record.get("last_known_display_name", "Player")),
			NetworkIdentityCrypto.compact_suffix(fingerprint),
			"Blocked" if bool(record.get("blocked", false)) else "Muted",
		]
		label.tooltip_text = NetworkIdentityCrypto.format_fingerprint(fingerprint)
		label.add_theme_color_override(
			"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
		)
		row.add_child(label)
		if bool(record.get("blocked", false)):
			var unblock := Button.new()
			unblock.text = "unblock"
			unblock.pressed.connect(func() -> void:
				_service.set_blocked(fingerprint, str(record["last_known_display_name"]), false)
			)
			UtilityPageStyle.apply_compact_ocean_button(unblock)
			row.add_child(unblock)
		var unmute := Button.new()
		unmute.text = "unmute"
		unmute.disabled = bool(record.get("blocked", false))
		unmute.pressed.connect(func() -> void:
			_service.set_muted(fingerprint, str(record["last_known_display_name"]), false)
		)
		UtilityPageStyle.apply_compact_ocean_button(unmute)
		row.add_child(unmute)


func _build_ban_rows() -> void:
	var records := _service.get_bans()
	if records.is_empty():
		_add_empty("No banned identities.")
		return
	for record: Dictionary in records:
		var row := _make_row()
		var fingerprint := str(record["target_fingerprint"])
		var label := Label.new()
		label.custom_minimum_size.x = 600
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.text = "%s · %s    banned %s" % [
			str(record.get("last_known_display_name", "Player")),
			NetworkIdentityCrypto.compact_suffix(fingerprint),
			Time.get_date_string_from_unix_time(int(record.get("banned_unix", 0))),
		]
		label.tooltip_text = NetworkIdentityCrypto.format_fingerprint(fingerprint)
		label.add_theme_color_override(
			"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
		)
		row.add_child(label)
		var unban := Button.new()
		unban.text = "unban"
		unban.pressed.connect(_confirm_unban.bind(fingerprint))
		UtilityPageStyle.apply_compact_ocean_button(unban)
		row.add_child(unban)


func _make_row() -> HBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel", UtilityPageStyle.row_style(false)
	)
	_list.add_child(panel)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 58
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	return row


func _add_empty(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.y = 100
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_SECONDARY
	)
	_list.add_child(label)


func _toggle_mute(entry: PlayerListEntry) -> void:
	_service.set_muted(entry.full_fingerprint, entry.display_name, not entry.muted)


func _confirm_block(entry: PlayerListEntry) -> void:
	_confirm(
		"Block %s?\nTheir local social and visual presentation will be hidden."
			% entry.display_name,
		func() -> void:
			_service.set_blocked(entry.full_fingerprint, entry.display_name, true)
	)


func _confirm_kick(entry: PlayerListEntry) -> void:
	_confirm("Remove %s from this session?" % entry.display_name, func() -> void:
		_service.kick(entry.peer_id, entry.full_fingerprint, entry.revision)
	)


func _confirm_ban(entry: PlayerListEntry) -> void:
	_confirm("Ban %s · %s from this server?" % [
		entry.display_name, entry.compact_fingerprint,
	], func() -> void:
		_service.ban(
			entry.peer_id, entry.full_fingerprint, entry.display_name, entry.revision
		)
	)


func _confirm_operator(entry: PlayerListEntry) -> void:
	var enabled: bool = not entry.is_operator
	_confirm(
		(
			"Grant operator access to %s for this room session?"
			if enabled
			else "Remove operator access from %s?"
		) % entry.display_name,
		func() -> void:
			_service.set_operator(
				entry.peer_id,
				entry.full_fingerprint,
				enabled,
				entry.revision,
			)
	)


func _confirm_unban(fingerprint: String) -> void:
	_confirm("Unban %s?" % NetworkIdentityCrypto.compact_suffix(fingerprint), func() -> void:
		_service.unban(fingerprint)
	)


func _confirm(text: String, action: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = text
	dialog.ok_button_text = "confirm"
	dialog.canceled.connect(dialog.queue_free)
	dialog.confirmed.connect(func() -> void:
		action.call()
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered(Vector2i(520, 220))
	_configure_confirmation_dialog.call_deferred(dialog)


func _configure_confirmation_dialog(dialog: ConfirmationDialog) -> void:
	if dialog != null and is_instance_valid(dialog) and dialog.visible:
		DialogControllerNavigationType.configure_scope(
			dialog, dialog.get_cancel_button()
		)


func _focus_first() -> void:
	var candidates: Array[Control] = []
	_collect_focusable_player_controls(self, candidates)
	candidates = candidates.filter(func(control: Control) -> bool:
		return control.focus_mode != Control.FOCUS_NONE
	)
	if candidates.is_empty():
		return
	candidates.sort_custom(func(first: Control, second: Control) -> bool:
		if not is_equal_approx(first.global_position.y, second.global_position.y):
			return first.global_position.y < second.global_position.y
		return first.global_position.x < second.global_position.x
	)
	candidates[0].grab_focus()


func _collect_focusable_player_controls(
	root: Node,
	output: Array[Control],
) -> void:
	for child: Node in root.get_children():
		if child == _tabs:
			continue
		var control := child as Control
		if control != null and not control.is_visible_in_tree():
			continue
		if (
			control != null
			and (control is BaseButton or control is LineEdit)
		):
			output.append(control)
		_collect_focusable_player_controls(child, output)
