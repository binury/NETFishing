class_name PlayersPage
extends Control

var _service: NetworkPlayerListService
var _header: Label
var _tabs: HBoxContainer
var _list: VBoxContainer
var _status: Label
var _current_tab := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UtilityPageStyle.apply_page(self)
	_build()


func setup(service: NetworkPlayerListService) -> void:
	_service = service
	_service.entries_changed.connect(_refresh)
	_service.moderation_finished.connect(func(_ok: bool, message: String) -> void:
		_status.text = message
		_refresh()
	)
	_refresh()


func activate() -> void:
	_refresh()
	UtilityPageStyle.animate_in(self)
	_focus_first()


func deactivate() -> void:
	_status.text = ""


func _build() -> void:
	var paper := PanelContainer.new()
	paper.position = Vector2(58, 128)
	paper.size = Vector2(1164, 476)
	add_child(paper)
	paper.add_theme_stylebox_override("panel", UtilityPageStyle.panel_style())
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	paper.add_child(root)
	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 27)
	_header.add_theme_color_override("font_color", Color("28251f"))
	root.add_child(_header)
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 10)
	root.add_child(_tabs)
	for index: int in 3:
		var button := Button.new()
		button.text = ["players", "relationships", "banned"][index]
		button.toggle_mode = true
		button.pressed.connect(_select_tab.bind(index))
		UtilityPageStyle.apply_button(button)
		_tabs.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(1080, 0)
	_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_list)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color("514535"))
	root.add_child(_status)


func _select_tab(index: int) -> void:
	if index == 2 and (_service == null or not _service.is_local_host()):
		return
	_current_tab = index
	_refresh()
	_focus_first()


func _refresh() -> void:
	if _service == null or _list == null:
		return
	_header.text = "Players\n%d / %d connected" % [
		_service.get_connected_count(), _service.get_max_players(),
	]
	for index: int in _tabs.get_child_count():
		var button := _tabs.get_child(index) as Button
		button.button_pressed = index == _current_tab
		button.visible = index != 2 or _service.is_local_host()
	for child: Node in _list.get_children():
		child.queue_free()
	match _current_tab:
		0:
			_build_active_rows()
		1:
			_build_relationship_rows()
		2:
			_build_ban_rows()


func _build_active_rows() -> void:
	var entries := _service.get_entries()
	if entries.is_empty():
		_add_empty("No authenticated players.")
		return
	for entry: PlayerListEntry in entries:
		var row := _make_row()
		var identity := Label.new()
		identity.custom_minimum_size.x = 515
		var markers: Array[String] = []
		if entry.is_host:
			markers.append("host")
		if entry.is_local_player:
			markers.append("You")
		identity.text = "%s%s · %s\n%s" % [
			entry.display_name,
			"  [%s]" % ", ".join(markers) if not markers.is_empty() else "",
			entry.compact_fingerprint,
			entry.continuity_state,
		]
		identity.tooltip_text = NetworkIdentityCrypto.format_fingerprint(
			entry.full_fingerprint
		)
		identity.add_theme_color_override(
			"font_color", UtilityPageStyle.INK
		)
		row.add_child(identity)
		var ping := Label.new()
		ping.custom_minimum_size.x = 80
		ping.text = (
			"Local" if entry.is_host
			else "%d ms" % entry.ping_to_host_ms
			if entry.ping_to_host_ms >= 0 else "—"
		)
		ping.add_theme_color_override("font_color", UtilityPageStyle.INK)
		row.add_child(ping)
		var mute := Button.new()
		mute.text = "unmute" if entry.muted else "mute"
		mute.disabled = entry.is_local_player
		mute.pressed.connect(_toggle_mute.bind(entry))
		UtilityPageStyle.apply_button(mute)
		row.add_child(mute)
		var block := Button.new()
		block.text = "block"
		block.disabled = entry.is_local_player
		block.pressed.connect(_confirm_block.bind(entry))
		UtilityPageStyle.apply_button(block)
		row.add_child(block)
		var kick := Button.new()
		kick.text = "kick"
		kick.disabled = not entry.can_kick
		kick.pressed.connect(_confirm_kick.bind(entry))
		UtilityPageStyle.apply_button(kick)
		row.add_child(kick)
		var ban := Button.new()
		ban.text = "ban"
		ban.disabled = not entry.can_ban
		ban.pressed.connect(_confirm_ban.bind(entry))
		UtilityPageStyle.apply_button(ban)
		row.add_child(ban)
		_list.add_child(row)


func _build_relationship_rows() -> void:
	var records := _service.get_relationships()
	if records.is_empty():
		_add_empty("No muted or blocked identities.")
		return
	for record: Dictionary in records:
		var row := _make_row()
		var label := Label.new()
		label.custom_minimum_size.x = 690
		var fingerprint := str(record["fingerprint"])
		label.text = "%s · %s    %s" % [
			str(record.get("last_known_display_name", "Player")),
			NetworkIdentityCrypto.compact_suffix(fingerprint),
			"Blocked" if bool(record.get("blocked", false)) else "Muted",
		]
		label.tooltip_text = NetworkIdentityCrypto.format_fingerprint(fingerprint)
		label.add_theme_color_override("font_color", UtilityPageStyle.INK)
		row.add_child(label)
		if bool(record.get("blocked", false)):
			var unblock := Button.new()
			unblock.text = "unblock"
			unblock.pressed.connect(func() -> void:
				_service.set_blocked(fingerprint, str(record["last_known_display_name"]), false)
			)
			UtilityPageStyle.apply_button(unblock)
			row.add_child(unblock)
		var unmute := Button.new()
		unmute.text = "unmute"
		unmute.disabled = bool(record.get("blocked", false))
		unmute.pressed.connect(func() -> void:
			_service.set_muted(fingerprint, str(record["last_known_display_name"]), false)
		)
		UtilityPageStyle.apply_button(unmute)
		row.add_child(unmute)
		_list.add_child(row)


func _build_ban_rows() -> void:
	var records := _service.get_bans()
	if records.is_empty():
		_add_empty("No banned identities.")
		return
	for record: Dictionary in records:
		var row := _make_row()
		var fingerprint := str(record["target_fingerprint"])
		var label := Label.new()
		label.custom_minimum_size.x = 830
		label.text = "%s · %s    banned %s" % [
			str(record.get("last_known_display_name", "Player")),
			NetworkIdentityCrypto.compact_suffix(fingerprint),
			Time.get_date_string_from_unix_time(int(record.get("banned_unix", 0))),
		]
		label.tooltip_text = NetworkIdentityCrypto.format_fingerprint(fingerprint)
		label.add_theme_color_override("font_color", UtilityPageStyle.INK)
		row.add_child(label)
		var unban := Button.new()
		unban.text = "unban"
		unban.pressed.connect(_confirm_unban.bind(fingerprint))
		UtilityPageStyle.apply_button(unban)
		row.add_child(unban)
		_list.add_child(row)


func _make_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 58
	row.add_theme_constant_override("separation", 8)
	row.add_theme_constant_override("outline_size", 1)
	return row


func _add_empty(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.y = 100
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", UtilityPageStyle.MUTED_INK)
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


func _focus_first() -> void:
	for child: Node in _tabs.get_children():
		if child is Button and child.visible and not child.disabled:
			child.grab_focus()
			return
