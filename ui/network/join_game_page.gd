class_name JoinGamePage
extends Control

signal join_requested(endpoint: String)
signal join_confirmation_requested(endpoint: String)
signal back_requested

enum Mode {
	DISCOVER,
	DIRECT,
	SAVED,
	RECENT,
}

const DISCOVERY_REFRESH_SECONDS: float = 8.0
const ControllerFocusNavigationType = preload(
	"res://ui/controller_focus_navigation.gd"
)

const ADDRESS_FORMAT_HELP: String = (
	"Hostname, IPv4, or [IPv6]. Port 7777 is used when omitted; "
	+ "include the port shown by a host when it differs."
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
@onready var _discover_button: Button = %DiscoverButton
@onready var _direct_button: Button = %DirectButton
@onready var _saved_button: Button = %SavedButton
@onready var _recent_button: Button = %RecentButton
@onready var _join_button: Button = %JoinButton
@onready var _refresh_button: Button = %RefreshButton
@onready var _save_button: Button = %SaveButton
@onready var _edit_button: Button = %EditButton
@onready var _favorite_button: Button = %FavoriteButton
@onready var _delete_button: Button = %DeleteButton
@onready var _cancel_button: Button = %CancelButton
@onready var _back_button: Button = %BackButton
@onready var _status: Label = %Status
@onready var _session_summary: Label = %SessionSummary
@onready var _delete_confirmation: BubbleConfirmationPage = (
	%DeleteConfirmation
)

var _network_session: NetworkSession
var _saved_servers: SavedServerStore
var _server_trust: ServerTrustStore
var _discovery: DiscoveryClient
var _gameplay_context: bool = false
var _mode: Mode = Mode.DISCOVER
var _visible_entries: Array[SavedServerEntry] = []
var _selected_entry: SavedServerEntry
var _discovery_rooms: Array[Dictionary] = []
var _selected_discovery_index: int = -1
var _discovery_refresh_timer: Timer
var _editing_entry_id: String = ""
var _name_entry_active: bool = false
var _delete_armed: bool = false
var _connection_error_latched: bool = false
var _pending_confirmation_endpoint: String = ""
var _pending_confirmation_room: Dictionary = {}


func _ready() -> void:
	UtilityPageStyle.apply_page(self)
	var paper := get_node("Paper") as PanelContainer
	paper.add_theme_stylebox_override(
		"panel", UtilityPageStyle.panel_style()
	)
	for button: BaseButton in [
		_discover_button, _direct_button, _saved_button, _recent_button,
		_refresh_button, _join_button,
		_save_button, _edit_button, _favorite_button, _delete_button,
		_cancel_button, _back_button,
	]:
		UtilityPageStyle.apply_ocean_button(button)
	UtilityPageStyle.apply_ocean_line_edit(_address)
	UtilityPageStyle.apply_ocean_line_edit(_name_edit)
	_discover_button.pressed.connect(_set_mode.bind(Mode.DISCOVER))
	_direct_button.pressed.connect(_set_mode.bind(Mode.DIRECT))
	_saved_button.pressed.connect(_set_mode.bind(Mode.SAVED))
	_recent_button.pressed.connect(_set_mode.bind(Mode.RECENT))
	_refresh_button.pressed.connect(_request_discovery_refresh)
	_join_button.pressed.connect(_request_join)
	_save_button.pressed.connect(_on_save_pressed)
	_edit_button.pressed.connect(_on_edit_pressed)
	_favorite_button.pressed.connect(_on_favorite_pressed)
	_delete_button.pressed.connect(_on_delete_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_address.text_submitted.connect(func(_value: String) -> void:
		if _name_entry_active:
			_focus_control(_name_edit, true)
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
	_discovery_refresh_timer = Timer.new()
	_discovery_refresh_timer.wait_time = DISCOVERY_REFRESH_SECONDS
	_discovery_refresh_timer.one_shot = false
	_discovery_refresh_timer.timeout.connect(_request_discovery_refresh)
	add_child(_discovery_refresh_timer)
	hide()


func setup(
	network_session: NetworkSession,
	saved_servers: SavedServerStore,
	gameplay_context: bool,
	server_trust: ServerTrustStore = null,
	discovery: DiscoveryClient = null,
) -> void:
	_network_session = network_session
	_saved_servers = saved_servers
	_gameplay_context = gameplay_context
	_server_trust = server_trust
	_discovery = discovery
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
	if _discovery != null:
		if not _discovery.rooms_updated.is_connected(
			_on_discovery_rooms_updated
		):
			_discovery.rooms_updated.connect(_on_discovery_rooms_updated)
		if not _discovery.browse_status_changed.is_connected(
			_on_discovery_status_changed
		):
			_discovery.browse_status_changed.connect(
				_on_discovery_status_changed
			)
		if not _discovery.public_join_prepared.is_connected(
			_on_public_join_prepared
		):
			_discovery.public_join_prepared.connect(
				_on_public_join_prepared
			)
		if not _discovery.public_join_status_changed.is_connected(
			_on_public_join_status_changed
		):
			_discovery.public_join_status_changed.connect(
				_on_public_join_status_changed
			)
	_refresh()


func open_page(preserved_endpoint: String = "") -> void:
	if not preserved_endpoint.is_empty():
		_address.text = preserved_endpoint
	elif _address.text.is_empty():
		_address.text = "127.0.0.1:7777"
	show()
	UtilityPageStyle.animate_in(self)
	_set_mode(_mode, false)
	if _mode == Mode.DIRECT:
		_address.select_all()


func close_page() -> void:
	cancel_pending_join_confirmation()
	hide_for_join_confirmation()


func request_back() -> void:
	_on_back_pressed()


func hide_for_join_confirmation() -> void:
	_clear_edit_state()
	_discovery_refresh_timer.stop()
	hide()
	var current_viewport: Viewport = get_viewport()
	if current_viewport != null:
		current_viewport.gui_release_focus()


func get_endpoint_text() -> String:
	return _address.text


func set_status(message: String) -> void:
	_connection_error_latched = true
	_set_status(_friendly_connection_message(message), true)


func cancel_pending_join_confirmation() -> void:
	_pending_confirmation_endpoint = ""
	_pending_confirmation_room.clear()


func confirm_pending_join() -> bool:
	if _pending_confirmation_endpoint.is_empty():
		_set_status("No server is waiting to be joined.", true)
		return false
	var endpoint_text: String = _pending_confirmation_endpoint
	var room: Dictionary = _pending_confirmation_room.duplicate(true)
	cancel_pending_join_confirmation()
	if not room.is_empty():
		if _discovery == null or not _discovery.prepare_public_join(room):
			_set_status("Could not prepare the public connection.", true)
			return false
		return true
	_set_status("Connecting…")
	join_requested.emit(endpoint_text)
	return true


func _set_mode(mode: Mode, clear_connection_error: bool = true) -> void:
	if clear_connection_error:
		_connection_error_latched = false
	_mode = mode
	_selected_entry = null
	_selected_discovery_index = -1
	_clear_edit_state()
	_refresh_entries()
	if mode == Mode.DISCOVER and not _discovery_rooms.is_empty():
		_select_discovery_index(0)
	_refresh()
	if mode == Mode.DISCOVER:
		_discovery_refresh_timer.start()
		_request_discovery_refresh()
	else:
		_discovery_refresh_timer.stop()
	if not is_visible_in_tree():
		return
	_defer_focus_control(_address if mode == Mode.DIRECT else _server_list)


func _request_join() -> void:
	_connection_error_latched = false
	if _network_session.state in [
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		_network_session.reset_failure()
	var endpoint_text: String = _address.text
	var discovery_room: Dictionary = {}
	if _mode == Mode.DISCOVER:
		var room: Dictionary = _selected_discovery_room()
		if _discovery != null and _discovery.is_own_room(room):
			_set_status("You are already hosting this room.", true)
			return
		if _discovery_room_is_full(room):
			_set_status("That room is full.", true)
			return
		if _discovery == null:
			_set_status("Could not prepare the public connection.", true)
			return
		endpoint_text = _discovery.room_endpoint(room)
		discovery_room = room.duplicate(true)
	elif _mode != Mode.DIRECT and _selected_entry != null:
		endpoint_text = _selected_entry.normalized_endpoint
	var endpoint: ConnectionEndpoint = EndpointParser.parse(endpoint_text)
	if not endpoint.is_valid():
		_set_status(endpoint.error_message, true)
		return
	if _gameplay_context:
		_pending_confirmation_endpoint = endpoint.normalized_display
		_pending_confirmation_room = discovery_room
		join_confirmation_requested.emit(endpoint.normalized_display)
		return
	if not discovery_room.is_empty():
		if not _discovery.prepare_public_join(discovery_room):
			_set_status("Could not prepare the public connection.", true)
		return
	_set_status("Connecting…")
	_address.text = endpoint.normalized_display
	join_requested.emit(endpoint.normalized_display)


func _on_public_join_prepared(endpoint_text: String) -> void:
	if _mode != Mode.DISCOVER or not is_visible_in_tree():
		return
	var endpoint: ConnectionEndpoint = EndpointParser.parse(endpoint_text)
	if not endpoint.is_valid():
		_set_status("Discovery returned an invalid room address.", true)
		return
	_address.text = endpoint.normalized_display
	_set_status("Connecting…")
	join_requested.emit(endpoint.normalized_display)


func _on_public_join_status_changed(message: String, is_error: bool) -> void:
	if _mode == Mode.DISCOVER and is_visible_in_tree():
		if is_error:
			_connection_error_latched = true
		elif _connection_error_latched:
			return
		_set_status(message, is_error)
		_refresh()


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
		_restore_entry_selection_and_focus(0, existing.entry_id)
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
	_refresh()
	_defer_focus_control(_name_edit, true)


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
	_restore_entry_selection_and_focus(0, saved.entry_id)


func _on_edit_pressed() -> void:
	if _selected_entry == null or _mode != Mode.SAVED:
		return
	_editing_entry_id = _selected_entry.entry_id
	_address.text = _selected_entry.normalized_endpoint
	_name_edit.text = _selected_entry.display_name
	_name_entry_active = true
	_name_edit.show()
	_save_button.text = "save"
	_refresh()
	_defer_focus_control(_name_edit, true)


func _on_favorite_pressed() -> void:
	if _selected_entry == null or _mode != Mode.SAVED:
		return
	var entry_id: String = _selected_entry.entry_id
	_saved_servers.set_favorite(entry_id, not _selected_entry.favorite)
	_refresh_entries()
	_restore_entry_selection_and_focus(0, entry_id)


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
	var removed_index: int = _visible_entries.find(_selected_entry)
	var selected_id: String = _selected_entry.entry_id
	var removed: bool = (
		_saved_servers.remove_recent_entry(selected_id)
		if _mode == Mode.RECENT
		else _saved_servers.remove_saved_entry(selected_id)
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
	_delete_armed = false
	_delete_confirmation.hide_page()
	_refresh_entries()
	_restore_entry_selection_and_focus(
		maxi(removed_index, 0),
		"" if removed else selected_id,
	)


func _cancel_delete() -> void:
	_delete_armed = false
	_delete_confirmation.hide_page()
	_defer_focus_control(_delete_button)


func _on_list_item_selected(index: int) -> void:
	if _mode == Mode.DISCOVER:
		if not _select_discovery_index(index):
			return
		_refresh()
		return
	if index < 0 or index >= _visible_entries.size():
		return
	_selected_entry = _visible_entries[index]
	_delete_armed = false
	_refresh()


func _select_entry_id(entry_id: String) -> bool:
	for index: int in range(_visible_entries.size()):
		if _visible_entries[index].entry_id == entry_id:
			return _select_entry_index(index)
	return false


func _select_entry_index(index: int) -> bool:
	if index < 0 or index >= _visible_entries.size():
		return false
	_server_list.select(index)
	_server_list.ensure_current_is_visible()
	_selected_entry = _visible_entries[index]
	return true


func _restore_entry_selection_and_focus(
	preferred_index: int,
	preferred_id: String = "",
) -> void:
	var selected: bool = (
		not preferred_id.is_empty() and _select_entry_id(preferred_id)
	)
	if not selected and not _visible_entries.is_empty():
		selected = _select_entry_index(
			clampi(preferred_index, 0, _visible_entries.size() - 1)
		)
	if not selected:
		_selected_entry = null
		_server_list.deselect_all()
	_refresh()
	_defer_focus_control(
		_server_list if selected else _current_mode_button()
	)


func _current_mode_button() -> Button:
	match _mode:
		Mode.DIRECT:
			return _direct_button
		Mode.SAVED:
			return _saved_button
		Mode.RECENT:
			return _recent_button
	return _discover_button


func _select_discovery_index(index: int) -> bool:
	if index < 0 or index >= _discovery_rooms.size():
		return false
	_selected_discovery_index = index
	_selected_entry = null
	_server_list.select(index)
	return true


func _refresh_entries() -> void:
	_visible_entries.clear()
	_server_list.clear()
	if _mode == Mode.DISCOVER:
		for room: Dictionary in _discovery_rooms:
			var player_count: int = int(room.get("current_players", 0))
			var maximum: int = int(room.get("max_players", 0))
			var own_room: bool = (
				_discovery != null and _discovery.is_own_room(room)
			)
			_server_list.add_item(
				"%s  —  %d / %d players%s%s" % [
					str(room.get("room_name", "Public room")),
					player_count,
					maximum,
					"  —  full" if player_count >= maximum else "",
					"  —  your room" if own_room else "",
				]
			)
		return
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
	] or (_discovery != null and _discovery.is_public_join_preparing())
	var direct: bool = _mode == Mode.DIRECT
	var discovery_mode: bool = _mode == Mode.DISCOVER
	var selected: bool = (
		_selected_discovery_index >= 0
		if discovery_mode
		else _selected_entry != null
	)
	_discover_button.button_pressed = discovery_mode
	_direct_button.button_pressed = direct
	_saved_button.button_pressed = _mode == Mode.SAVED
	_recent_button.button_pressed = _mode == Mode.RECENT
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
	_join_button.disabled = (
		connecting
		or (not direct and not selected)
		or (
			discovery_mode
			and selected
			and _discovery_room_is_full(_selected_discovery_room())
		)
		or (
			discovery_mode
			and selected
			and _discovery != null
			and _discovery.is_own_room(_selected_discovery_room())
		)
	)
	_join_button.text = "join\nnow" if direct else "join"
	_refresh_button.visible = discovery_mode and not _name_entry_active
	_save_button.visible = (
		direct or _mode == Mode.RECENT or _name_entry_active
	)
	_save_button.disabled = connecting or (
		_mode == Mode.RECENT and not selected and not _name_entry_active
	)
	_save_button.text = "save" if _name_entry_active else "save\nserver"
	_edit_button.visible = _mode == Mode.SAVED and selected
	_favorite_button.visible = _mode == Mode.SAVED and selected
	_favorite_button.text = (
		"unfavorite"
		if _mode == Mode.SAVED
		and _selected_entry != null
		and _selected_entry.favorite
		else "favorite"
	)
	_delete_button.visible = (
		_mode in [Mode.SAVED, Mode.RECENT] and selected
	)
	_delete_button.text = "remove" if _mode == Mode.RECENT else "delete"
	_cancel_button.visible = connecting
	_session_summary.visible = (
		_gameplay_context
		and _network_session.state != NetworkSession.State.INACTIVE
	)
	if _session_summary.visible:
		_session_summary.text = (
			"UDP %d • %d / %d players"
			% [
				_network_session.get_host_port(),
				_network_session.get_player_count(),
				_network_session.get_session_max_players(),
			]
			if _network_session.is_host()
			else "%d / %d players" % [
				_network_session.get_player_count(),
				_network_session.get_session_max_players(),
			]
		)
	if not direct:
		if selected:
			_details.text = (
				_format_discovery_details(_selected_discovery_room())
				if discovery_mode
				else _format_entry_details(_selected_entry)
			)
		elif (
			_discovery_rooms.is_empty()
			if discovery_mode
			else _visible_entries.is_empty()
		):
			_details.text = (
				"No public rooms are available."
				if discovery_mode
				else "No saved servers yet."
				if _mode == Mode.SAVED
				else "No recent connections yet."
			)
		else:
			_details.text = "Select a server."
	var warning: String = (
		_saved_servers.get_recovery_warning()
		if _saved_servers != null and not discovery_mode
		else ""
	)
	if not warning.is_empty() and _status.text.is_empty():
		_status.text = warning
	_configure_controller_navigation()


func _configure_controller_navigation() -> void:
	var mode_buttons: Array[Control] = [
		_discover_button,
		_direct_button,
		_saved_button,
		_recent_button,
	]
	var content_controls: Array[Control] = []
	for control: Control in [_address, _name_edit, _server_list]:
		if _controller_focus_eligible(control):
			content_controls.append(control)
	var action_controls: Array[Control] = []
	for control: Control in [
		_refresh_button,
		_join_button,
		_save_button,
		_edit_button,
		_favorite_button,
		_delete_button,
		_cancel_button,
		_back_button,
	]:
		if _controller_focus_eligible(control):
			action_controls.append(control)
	var all_controls: Array[Control] = []
	all_controls.append_array(mode_buttons)
	all_controls.append_array(content_controls)
	all_controls.append_array(action_controls)
	for control: Control in all_controls:
		control.focus_mode = Control.FOCUS_ALL
	for control: Control in [
		_address,
		_name_edit,
		_server_list,
		_refresh_button,
		_join_button,
		_save_button,
		_edit_button,
		_favorite_button,
		_delete_button,
		_cancel_button,
		_back_button,
	]:
		if control not in all_controls:
			control.focus_mode = Control.FOCUS_NONE
	var primary_content: Control = (
		content_controls.front()
		if not content_controls.is_empty()
		else action_controls.front()
		if not action_controls.is_empty()
		else _back_button
	)
	for index: int in mode_buttons.size():
		var mode_button: Control = mode_buttons[index]
		_set_controller_neighbors(
			mode_button,
			mode_buttons[maxi(index - 1, 0)],
			mode_buttons[mini(index + 1, mode_buttons.size() - 1)],
			mode_button,
			primary_content,
		)
	for index: int in content_controls.size():
		var content: Control = content_controls[index]
		var above: Control = (
			content_controls[index - 1]
			if index > 0
			else mode_buttons[int(_mode)]
		)
		var below: Control = (
			content_controls[index + 1]
			if index < content_controls.size() - 1
			else action_controls.front()
			if not action_controls.is_empty()
			else content
		)
		_set_controller_neighbors(content, content, content, above, below)
	for index: int in action_controls.size():
		var action: Control = action_controls[index]
		_set_controller_neighbors(
			action,
			action_controls[maxi(index - 1, 0)],
			action_controls[mini(index + 1, action_controls.size() - 1)],
			content_controls.back()
			if not content_controls.is_empty()
			else mode_buttons[int(_mode)],
			action,
		)
	ControllerFocusNavigationType.configure_traversal(all_controls)
	_recover_controller_focus(all_controls, primary_content)


func _controller_focus_eligible(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	var button := control as BaseButton
	if button != null and button.disabled:
		return false
	var line_edit := control as LineEdit
	return line_edit == null or line_edit.editable


func _focus_control(control: Control, select_all: bool = false) -> void:
	if (
		control == null
		or not is_instance_valid(control)
		or not control.is_inside_tree()
		or not control.is_visible_in_tree()
		or control.focus_mode not in [Control.FOCUS_CLICK, Control.FOCUS_ALL]
	):
		return
	var button := control as BaseButton
	if button != null and button.disabled:
		return
	var line_edit := control as LineEdit
	if line_edit != null and not line_edit.editable:
		return
	control.grab_focus()
	if select_all and line_edit != null:
		line_edit.select_all()


func _defer_focus_control(control: Control, select_all: bool = false) -> void:
	_focus_control.call_deferred(control, select_all)


func _set_controller_neighbors(
	control: Control,
	left: Control,
	right: Control,
	top: Control,
	bottom: Control,
) -> void:
	control.focus_neighbor_left = control.get_path_to(left)
	control.focus_neighbor_right = control.get_path_to(right)
	control.focus_neighbor_top = control.get_path_to(top)
	control.focus_neighbor_bottom = control.get_path_to(bottom)


func _recover_controller_focus(
	controls: Array[Control],
	fallback: Control,
) -> void:
	if not is_visible_in_tree():
		return
	var owner: Control = get_viewport().gui_get_focus_owner()
	if owner != null and owner in controls:
		return
	if owner != null and _delete_confirmation.is_ancestor_of(owner):
		return
	if fallback != null:
		_defer_focus_control(fallback)


func _format_entry_details(entry: SavedServerEntry) -> String:
	var parts: Array[String] = []
	if _mode == Mode.SAVED:
		parts.append("Name: %s" % entry.display_name)
	parts.append("Address: %s" % entry.normalized_endpoint)
	if _server_trust != null:
		var trust := _server_trust.get_record(entry.get_endpoint())
		if trust.is_empty():
			parts.append("Host identity: Not verified yet")
		else:
			parts.append(
				"Host identity: %s"
				% NetworkIdentityCrypto.format_fingerprint(
					str(trust.get("fingerprint", ""))
				)
			)
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


func _format_discovery_details(room: Dictionary) -> String:
	if room.is_empty():
		return "Select a public room."
	var lines: Array[String] = [
		"Room: %s" % str(room.get("room_name", "Public room")),
		"Players: %d / %d" % [
			int(room.get("current_players", 0)),
			int(room.get("max_players", 0)),
		],
		"Connection: %s" % (
			_discovery.room_endpoint(room) if _discovery != null else "—"
		),
		"Direct UDP connection • ping is measured after joining",
	]
	if _discovery != null and _discovery.is_own_room(room):
		lines.append("This is the room you are currently hosting.")
	return "\n".join(lines)


func _selected_discovery_room() -> Dictionary:
	if (
		_selected_discovery_index < 0
		or _selected_discovery_index >= _discovery_rooms.size()
	):
		return {}
	return _discovery_rooms[_selected_discovery_index]


func _discovery_room_is_full(room: Dictionary) -> bool:
	if room.is_empty():
		return false
	return int(room.get("current_players", 0)) >= int(room.get("max_players", 0))


func _request_discovery_refresh() -> void:
	if (
		_discovery == null
		or _mode != Mode.DISCOVER
		or not is_visible_in_tree()
	):
		return
	_discovery.request_rooms()


func _on_discovery_rooms_updated(rooms: Array[Dictionary]) -> void:
	var selected_id: String = str(
		_selected_discovery_room().get("room_id", "")
	)
	_discovery_rooms = rooms.duplicate(true)
	_selected_discovery_index = -1
	if _mode == Mode.DISCOVER:
		_refresh_entries()
		if not selected_id.is_empty():
			for index: int in _discovery_rooms.size():
				if str(_discovery_rooms[index].get("room_id", "")) == selected_id:
					_select_discovery_index(index)
					break
		if _selected_discovery_index < 0 and not _discovery_rooms.is_empty():
			_select_discovery_index(0)
		_refresh()


func _on_discovery_status_changed(message: String, is_error: bool) -> void:
	if (
		_mode == Mode.DISCOVER
		and is_visible_in_tree()
		and not _connection_error_latched
	):
		_set_status(message, is_error)


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
		or "timed out" in normalized
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
		UtilityPageStyle.OCEAN_DANGER
		if is_error
		else UtilityPageStyle.OCEAN_TEXT_PRIMARY,
	)


func _clear_edit_state() -> void:
	_editing_entry_id = ""
	_name_entry_active = false
	_delete_armed = false
	if is_node_ready():
		_name_edit.hide()
		_delete_confirmation.hide_page()


func _on_cancel_pressed() -> void:
	_connection_error_latched = false
	if _network_session != null:
		_network_session.cancel_connection()
	_refresh()


func _on_back_pressed() -> void:
	if _delete_armed or _delete_confirmation.visible:
		_cancel_delete()
		return
	if _name_entry_active:
		_clear_edit_state()
		_refresh()
		var content: Control = _address if _mode == Mode.DIRECT else _server_list
		_defer_focus_control(content)
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


func _on_state_changed(_state: NetworkSession.State) -> void:
	_refresh()


func _on_status_message_changed(message: String) -> void:
	if _connection_error_latched:
		return
	_set_status(_friendly_connection_message(message))
	_refresh()


func _on_connection_error(message: String) -> void:
	_connection_error_latched = true
	_set_status(_friendly_connection_message(message), true)
	_refresh()


func _on_peer_count_changed(player_count: int, max_players: int) -> void:
	_session_summary.text = "%d / %d players" % [
		player_count,
		max_players,
	]


func _on_store_changed() -> void:
	var selected_index: int = _visible_entries.find(_selected_entry)
	var selected_id: String = (
		_selected_entry.entry_id if _selected_entry != null else ""
	)
	_refresh_entries()
	_selected_entry = null
	if (
		not selected_id.is_empty()
		and not _select_entry_id(selected_id)
		and not _visible_entries.is_empty()
	):
		_select_entry_index(
			clampi(maxi(selected_index, 0), 0, _visible_entries.size() - 1)
		)
	_refresh()
