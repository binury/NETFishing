class_name JoinGamePage
extends Control

signal join_requested(endpoint: String)
signal back_requested

@onready var _address: LineEdit = %Address
@onready var _join_button: BubbleButton = %JoinButton
@onready var _cancel_button: BubbleButton = %CancelButton
@onready var _back_button: BubbleButton = %BackButton
@onready var _open_close_button: BubbleButton = %OpenCloseButton
@onready var _status: Label = %Status
@onready var _session_summary: Label = %SessionSummary

var _network_session: NetworkSession
var _saved_servers: SavedServerStore
var _gameplay_context: bool = false


func _ready() -> void:
	_join_button.pressed.connect(_on_join_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_back_button.pressed.connect(_on_back_pressed)
	_open_close_button.pressed.connect(_on_open_close_pressed)
	_address.text_submitted.connect(_on_address_submitted)
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
	_refresh()


func open_page(preserved_endpoint: String = "") -> void:
	if not preserved_endpoint.is_empty():
		_address.text = preserved_endpoint
	elif _address.text.is_empty():
		_address.text = "127.0.0.1:7777"
	show()
	_refresh()
	_address.grab_focus()
	_address.select_all()


func close_page() -> void:
	hide()
	get_viewport().gui_release_focus()


func get_endpoint_text() -> String:
	return _address.text


func set_status(message: String) -> void:
	_status.text = message


func _on_join_pressed() -> void:
	_request_join()


func _on_address_submitted(_value: String) -> void:
	_request_join()


func _request_join() -> void:
	if _network_session.state in [
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		_network_session.reset_failure()
	var endpoint: ConnectionEndpoint = EndpointParser.parse(_address.text)
	if not endpoint.is_valid():
		_status.text = endpoint.error_message
		return
	_address.text = endpoint.normalized_display
	join_requested.emit(endpoint.normalized_display)


func _on_cancel_pressed() -> void:
	if _network_session != null:
		_network_session.cancel_connection()
	_refresh()


func _on_back_pressed() -> void:
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
	_status.text = message
	_refresh()


func _on_connection_error(message: String) -> void:
	_status.text = message
	_refresh()


func _on_peer_count_changed(player_count: int, max_players: int) -> void:
	_session_summary.text = "%d / %d players" % [
		player_count,
		max_players,
	]


func _refresh() -> void:
	if not is_node_ready() or _network_session == null:
		return
	var connecting: bool = _network_session.state in [
		NetworkSession.State.CONNECTING,
		NetworkSession.State.AUTHENTICATING,
	]
	_address.editable = not connecting
	_join_button.disabled = connecting
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
