class_name JoinGamePage
extends Control

signal join_requested(endpoint: String)
signal back_requested

enum Mode {
	DIRECT,
	SAVED,
	RECENT,
}

const ADDRESS_FORMAT_HELP: String = (
	"Hostname, IPv4, or [IPv6]. Port 7777 is used when omitted."
)
const DIRECT_WORKFLOW_HELP: String = (
	"%s\nJoin Now connects once; Save Server stores this address locally."
	% ADDRESS_FORMAT_HELP
)

@onready var _address: LineEdit = %Address
@onready var _address_label: Label = %AddressLabel
@onready var _address_helper: Label = %AddressHelper
@onready var _name_edit: LineEdit = %NameEdit
@onready var _name_label: Label = %NameLabel
@onready var _name_helper: Label = %NameHelper
@onready var _server_list: ItemList = %ServerList
@onready var _details: Label = %Details
@onready var _direct_button: BubbleButton = %DirectButton
@onready var _saved_button: BubbleButton = %SavedButton
@onready var _recent_button: BubbleButton = %RecentButton
@onready var _join_button: BubbleButton = %JoinButton
@onready var _save_button: BubbleButton = %SaveButton
@onready var _edit_button: BubbleButton = %EditButton
@onready var _favorite_button: BubbleButton = %FavoriteButton
@onready var _delete_button: BubbleButton = %DeleteButton
@onready var _cancel_button: BubbleButton = %CancelButton
@onready var _back_button: BubbleButton = %BackButton
@onready var _open_close_button: BubbleButton = %OpenCloseButton
@onready var _status: Label = %Status
@onready var _session_summary: Label = %SessionSummary
@onready var _delete_confirmation: BubbleConfirmationPage = (
	%DeleteConfirmation
)

var _network_session: NetworkSession
var _saved_servers: SavedServerStore
var _gameplay_context: bool = false
var _mode: Mode = Mode.DIRECT
var _visible_entries: Array[SavedServerEntry] = []
var _selected_entry: SavedServerEntry
var _editing_entry_id: String = ""
var _name_entry_active: bool = false
var _delete_armed: bool = false


func _ready() -> void:
	_direct_button.pressed.connect(_set_mode.bind(Mode.DIRECT))
	_saved_button.pressed.connect(_set_mode.bind(Mode.SAVED))
	_recent_button.pressed.connect(_set_mode.bind(Mode.RECENT))
	_join_button.pressed.connect(_request_join)
	_save_button.pressed.connect(_on_save_pressed)
	_edit_button.pressed.connect(_on_edit_pressed)
	_favorite_button.pressed.connect(_on_favorite_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_open_close_button.pressed.connect(_on_open_close_pressed)
	_address.text_submitted.connect(func(_value: String) -> void:
		if _name_entry_active:
			_name_edit.grab_focus()
			_name_edit.select_all()
		else:
			_request_join()
	)
	_name_edit.text_submitted.connect(func(_value: String) -> void:
		_commit_name_entry()
	)
	_server_list.item_selected.connect(_on_list_item_selected)
	_server_list.item_activated.connect(func(_index: int) -> void:
		_request_join()
	)
	_delete_confirmation.confirmed.connect(_confirm_delete)
	_delete_confirmation.cancelled.connect(_cancel_delete)
	hide()


func setup(
	network_session: NetworkSession,
	saved_servers: SavedServerStore,
	gameplay_context: bool,
) -> void:
	_network_session = network_session
	_saved_servers = saved_servers
	_gameplay_context = gameplay_context
	if not _network_session.state_changed.is_connected(_on_state_changed):
		_network_session.state_changed.connect(_on_state_changed)
	if not _network_session.status_message_changed.is_connected(
		_on_status_message_changed
	):
		_network_session.status_message_changed.connect(
			_on_status_message_changed
		)
	if not _network_session.connection_error.is_connected(
		_on_connection_error
	):
		_network_session.connection_error.connect(_on_connection_error)
	if not _network_session.peer_count_changed.is_connected(
		_on_peer_count_changed
	):
		_network_session.peer_count_changed.connect(_on_peer_count_changed)
	if (
		_saved_servers != null
		and not _saved_servers.data_changed.is_connected(_on_store_changed)
	):
		_saved_servers.data_changed.connect(_on_store_changed)
	_refresh()


func open_page(preserved_endpoint: String = "") -> void:
	if not preserved_endpoint.is_empty():
		_address.text = preserved_endpoint
	elif _address.text.is_empty():
		_address.text = "127.0.0.1:7777"
	show()
	_set_mode(_mode)
	if _mode == Mode.DIRECT:
		_address.grab_focus()
		_address.select_all()


func close_page() -> void:
	_clear_edit_state()
	hide()
	get_viewport().gui_release_focus()


func get_endpoint_text() -> String:
	return _address.text


func set_status(message: String) -> void:
	_set_status(_friendly_connection_message(message), true)


func _set_mode(mode: Mode) -> void:
	_mode = mode
	_selected_entry = null
	_clear_edit_state()
	_refresh_entries()
	_refresh()
	if not is_visible_in_tree():
		return
	if mode == Mode.DIRECT:
		_address.grab_focus()
	else:
		_server_list.grab_focus()


func _request_join() -> void:
	if _network_session.state in [
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		_network_session.reset_failure()
	var endpoint_text: String = (
		_selected_entry.normalized_endpoint
		if _mode != Mode.DIRECT and _selected_entry != null
		else _address.text
	)
	var endpoint: ConnectionEndpoint = EndpointParser.parse(endpoint_text)
	if not endpoint.is_valid():
		_set_status(endpoint.error_message, true)
		return
	_set_status("Connecting…")
	_address.text = endpoint.normalized_display
	join_requested.emit(endpoint.normalized_display)


func _on_save_pressed() -> void:
	if _name_entry_active:
		_commit_name_entry()
		return
	var endpoint: ConnectionEndpoint = (
		_selected_entry.get_endpoint()
		if _mode == Mode.RECENT and _selected_entry != null
		else EndpointParser.parse(_address.text)
	)
	if not endpoint.is_valid():
		_set_status(endpoint.error_message, true)
		return
	var existing: SavedServerEntry = (
		_saved_servers.find_saved_by_endpoint(endpoint)
	)
	if existing != null:
		_set_status(
			"Already saved locally as “%s”." % existing.display_name,
			true,
		)
		_set_mode(Mode.SAVED)
		_select_entry_id(existing.entry_id)
		return
	_address.text = endpoint.normalized_display
	_name_edit.text = (
		_selected_entry.last_observed_server_name
		if _mode == Mode.RECENT
		and _selected_entry != null
		and not _selected_entry.last_observed_server_name.is_empty()
		else endpoint.host
	)
	_name_entry_active = true
	_name_edit.show()
	_save_button.text = "save"
	_name_edit.grab_focus()
	_name_edit.select_all()
	_refresh()


func _commit_name_entry() -> void:
	var endpoint := EndpointParser.parse(_address.text)
	if not endpoint.is_valid():
		_set_status(endpoint.error_message, true)
		return
	var saved: SavedServerEntry = _saved_servers.save_or_update_entry(
		_name_edit.text,
		endpoint,
		_editing_entry_id,
	)
	if saved == null:
		_set_status(
			"Could not save. Check the server name and address.",
			true,
		)
		return
	var was_editing: bool = not _editing_entry_id.is_empty()
	_set_status(
		"Server updated."
		if was_editing
		else "Saved locally as “%s”." % saved.display_name
	)
	_clear_edit_state()
	_mode = Mode.SAVED
	_refresh_entries()
	_select_entry_id(saved.entry_id)
	_refresh()


func _on_edit_pressed() -> void:
	if _selected_entry == null or _mode != Mode.SAVED:
		return
	_editing_entry_id = _selected_entry.entry_id
	_address.text = _selected_entry.normalized_endpoint
	_name_edit.text = _selected_entry.display_name
	_name_entry_active = true
	_name_edit.show()
	_save_button.text = "save"
	_name_edit.grab_focus()
	_name_edit.select_all()
	_refresh()


func _on_favorite_pressed() -> void:
	if _selected_entry == null or _mode != Mode.SAVED:
		return
	var entry_id: String = _selected_entry.entry_id
	_saved_servers.set_favorite(entry_id, not _selected_entry.favorite)
	_refresh_entries()
	_select_entry_id(entry_id)
	_refresh()


func _on_delete_pressed() -> void:
	if _selected_entry == null or _mode == Mode.DIRECT:
		return
	_delete_armed = true
	_delete_confirmation.configure(
		(
			"Remove this recent connection from this device?"
			if _mode == Mode.RECENT
			else "Delete this saved-server bookmark from this device?"
		),
		"remove" if _mode == Mode.RECENT else "delete",
		"cancel",
		BubbleConfirmationPage.InitialFocus.CANCEL,
	)
	_delete_confirmation.transition_in(0.18, func() -> void: pass)


func _confirm_delete() -> void:
	if _selected_entry == null or not _delete_armed:
		_cancel_delete()
		return
	var removed: bool = (
		_saved_servers.remove_recent_entry(_selected_entry.entry_id)
		if _mode == Mode.RECENT
		else _saved_servers.remove_saved_entry(_selected_entry.entry_id)
	)
	_set_status(
		(
			"Removed from recent connections."
			if _mode == Mode.RECENT
			else "Removed from saved servers."
		)
		if removed
		else "Could not remove the local entry.",
		not removed,
	)
	_selected_entry = null
	_delete_armed = false
	_refresh_entries()
	_refresh()
	_delete_confirmation.hide_page()


func _cancel_delete() -> void:
	_delete_armed = false
	_delete_confirmation.hide_page()
	_delete_button.grab_focus()


func _on_list_item_selected(index: int) -> void:
	if index < 0 or index >= _visible_entries.size():
		return
	_selected_entry = _visible_entries[index]
	_delete_armed = false
	_refresh()


func _select_entry_id(entry_id: String) -> void:
	for index: int in range(_visible_entries.size()):
		if _visible_entries[index].entry_id == entry_id:
			_server_list.select(index)
			_selected_entry = _visible_entries[index]
			return


func _refresh_entries() -> void:
	_visible_entries.clear()
	_server_list.clear()
	if _saved_servers == null or _mode == Mode.DIRECT:
		return
	_visible_entries = (
		_saved_servers.get_saved_entries()
		if _mode == Mode.SAVED
		else _saved_servers.get_recent_entries()
	)
	for entry: SavedServerEntry in _visible_entries:
		var prefix: String = "★ " if entry.favorite else ""
		var count: String = (
			"  —  %d / %d players"
			% [
				entry.last_observed_player_count,
				entry.last_observed_max_players,
			]
			if entry.last_observed_max_players > 0
			else ""
		)
		_server_list.add_item(
			"%s%s  —  %s%s"
			% [
				prefix,
				entry.display_name,
				entry.normalized_endpoint,
				count,
			]
		)


func _refresh() -> void:
	if not is_node_ready() or _network_session == null:
		return
	var connecting: bool = _network_session.state in [
		NetworkSession.State.CONNECTING,
		NetworkSession.State.AUTHENTICATING,
	]
	var direct: bool = _mode == Mode.DIRECT
	var selected: bool = _selected_entry != null
	_address.visible = direct or _name_entry_active
	_address_label.visible = _address.visible
	_address_helper.visible = _address.visible
	_address_helper.text = (
		ADDRESS_FORMAT_HELP if _name_entry_active else DIRECT_WORKFLOW_HELP
	)
	_address.editable = not connecting
	_name_edit.visible = _name_entry_active
	_name_label.visible = _name_entry_active
	_name_helper.visible = _name_entry_active
	_server_list.visible = not direct and not _name_entry_active
	_details.visible = not direct and not _name_entry_active
	_join_button.disabled = connecting or (not direct and not selected)
	_join_button.text = "join\nnow" if direct else "join"
	_save_button.visible = direct or _mode == Mode.RECENT or _name_entry_active
	_save_button.disabled = connecting or (
		_mode == Mode.RECENT and not selected and not _name_entry_active
	)
	_save_button.text = "save" if _name_entry_active else "save\nserver"
	_edit_button.visible = _mode == Mode.SAVED and selected
	_favorite_button.visible = _mode == Mode.SAVED and selected
	_favorite_button.text = (
		"unfavorite"
		if selected and _selected_entry.favorite
		else "favorite"
	)
	_delete_button.visible = not direct and selected
	_delete_button.text = "remove" if _mode == Mode.RECENT else "delete"
	_cancel_button.visible = connecting
	_open_close_button.visible = (
		_gameplay_context and _network_session.is_host()
	)
	if _open_close_button.visible:
		_open_close_button.text = (
			"close\ngame"
			if _network_session.is_open_host()
			else "open\ngame"
		)
	_session_summary.visible = (
		_gameplay_context
		and _network_session.state != NetworkSession.State.INACTIVE
	)
	if _session_summary.visible:
		_session_summary.text = "%d / %d players" % [
			_network_session.get_player_count(),
			_network_session.get_session_max_players(),
		]
	if not direct:
		if selected:
			_details.text = _format_entry_details(_selected_entry)
		elif _visible_entries.is_empty():
			_details.text = (
				"No saved servers yet."
				if _mode == Mode.SAVED
				else "No recent connections yet."
			)
		else:
			_details.text = "Select a server."
	var warning: String = (
		_saved_servers.get_recovery_warning()
		if _saved_servers != null
		else ""
	)
	if not warning.is_empty() and _status.text.is_empty():
		_status.text = warning


func _format_entry_details(entry: SavedServerEntry) -> String:
	var parts: Array[String] = []
	if _mode == Mode.SAVED:
		parts.append("Name: %s" % entry.display_name)
	parts.append("Address: %s" % entry.normalized_endpoint)
	if (
		not entry.last_observed_server_name.is_empty()
		and (
			_mode != Mode.SAVED
			or entry.last_observed_server_name != entry.display_name
		)
	):
		parts.append("Server name: %s" % entry.last_observed_server_name)
	if entry.last_observed_max_players > 0:
		parts.append(
			"Players: %d / %d"
			% [
				entry.last_observed_player_count,
				entry.last_observed_max_players,
			]
		)
	if entry.last_success_at_unix > 0:
		parts.append(
			"Last connected: %s"
			% Time.get_datetime_string_from_unix_time(
				entry.last_success_at_unix, true
			)
		)
	if not entry.last_result_code.is_empty():
		parts.append(
			"Last result: %s" % _format_result_code(entry.last_result_code)
		)
	return "\n".join(parts)


func _format_result_code(result_code: String) -> String:
	match result_code.strip_edges().to_upper():
		"SUCCESS":
			return "Connected successfully"
		"PROTOCOL_MISMATCH":
			return "Protocol versions did not match"
		"SERVER_FULL":
			return "Server was full"
		"CANCELLED":
			return "Connection cancelled"
		"TIMEOUT", "CONNECTION_FAILED", "SERVER_UNAVAILABLE":
			return "Could not reach the server"
		_:
			return "Connection was unsuccessful"


func _friendly_connection_message(message: String) -> String:
	var normalized: String = message.strip_edges().to_lower()
	if "protocol" in normalized and (
		"mismatch" in normalized or "version" in normalized
	):
		return "Protocol versions do not match."
	if "full" in normalized or "capacity" in normalized:
		return "Server is full."
	if "cancel" in normalized:
		return "Connection cancelled."
	if (
		"timeout" in normalized
		or "unavailable" in normalized
		or "refused" in normalized
		or "reach" in normalized
		or "failed" in normalized
	):
		return "Could not reach the server."
	return message


func _set_status(message: String, is_error: bool = false) -> void:
	_status.text = message
	_status.add_theme_color_override(
		"font_color",
		Color(0.45, 0.09, 0.08, 1.0)
		if is_error
		else Color(0.035, 0.145, 0.22, 1.0),
	)


func _clear_edit_state() -> void:
	_editing_entry_id = ""
	_name_entry_active = false
	_delete_armed = false
	if is_node_ready():
		_name_edit.hide()
		_delete_confirmation.hide_page()


func _on_cancel_pressed() -> void:
	if _network_session != null:
		_network_session.cancel_connection()
	_refresh()


func _on_back_pressed() -> void:
	if _name_entry_active or _delete_armed:
		_clear_edit_state()
		_refresh()
		return
	if (
		_network_session != null
		and _network_session.state in [
			NetworkSession.State.CONNECTING,
			NetworkSession.State.AUTHENTICATING,
		]
	):
		_network_session.cancel_connection()
	back_requested.emit()


func _on_open_close_pressed() -> void:
	if _network_session == null or not _network_session.is_host():
		return
	_network_session.set_host_open(not _network_session.is_open_host())
	_refresh()


func _on_state_changed(_state: NetworkSession.State) -> void:
	_refresh()


func _on_status_message_changed(message: String) -> void:
	_set_status(_friendly_connection_message(message))
	_refresh()


func _on_connection_error(message: String) -> void:
	_set_status(_friendly_connection_message(message), true)
	_refresh()


func _on_peer_count_changed(player_count: int, max_players: int) -> void:
	_session_summary.text = "%d / %d players" % [
		player_count,
		max_players,
	]


func _on_store_changed() -> void:
	var selected_id: String = (
		_selected_entry.entry_id if _selected_entry != null else ""
	)
	_refresh_entries()
	if not selected_id.is_empty():
		_select_entry_id(selected_id)
	_refresh()
