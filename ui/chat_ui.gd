class_name ChatUI
extends Control

const INPUT_OWNER: StringName = &"chat"
const COMPACT_SECONDS: float = 8.0
const SPEECH_SECONDS: float = 6.0

var _service: NetworkChatService
var _session: NetworkSession
var _spawn: PlayerSpawnService
var _player: Player
var _fishing_spot: FishingSpot
var _history: Label
var _entry: LineEdit
var _chat_button: Button
var _panel: PanelContainer
var _speech_layer: Control
var _speech: Dictionary[int, Dictionary] = {}
var _opened: bool = false
var _available: bool = false
var _last_message_time: float = -INF
var _prior_movement: bool = true
var _prior_camera: bool = true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func setup(
	service: NetworkChatService,
	session: NetworkSession,
	spawn: PlayerSpawnService,
	player: Player,
	fishing_spot: FishingSpot,
) -> void:
	_service = service
	_session = session
	_spawn = spawn
	_player = player
	_fishing_spot = fishing_spot
	_service.message_received.connect(_on_message)
	_service.history_replaced.connect(_on_history)
	_service.send_rejected.connect(_on_rejected)
	_session.peer_removed.connect(_on_peer_removed)
	_refresh_history()


func open_chat() -> void:
	if (
		_opened or not _available or _service == null
		or not _session.is_gameplay_session_active()
	):
		return
	_opened = true
	_prior_movement = _player.is_movement_enabled()
	_prior_camera = _player.is_camera_input_enabled()
	_player.set_movement_enabled(false)
	_player.set_camera_input_enabled(false)
	_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, true)
	# Send the host a zeroed frame immediately so it cannot keep applying the
	# last movement state while this LineEdit owns keyboard input.
	_session.submit_neutral_local_movement()
	_panel.show()
	_entry.show()
	_entry.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_available(value: bool) -> void:
	_available = value
	_chat_button.visible = value
	if not value:
		close_chat()


func close_chat() -> void:
	if not _opened:
		return
	_opened = false
	_entry.release_focus()
	_entry.hide()
	_player.set_movement_enabled(_prior_movement)
	_player.set_camera_input_enabled(_prior_camera)
	_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, false)
	_refresh_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			if _opened:
				_send()
			elif (
				_available
				and get_viewport().gui_get_focus_owner() is not LineEdit
			):
				open_chat()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_T and not _opened and _available:
			open_chat()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _opened:
			close_chat()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_refresh_visibility()
	var now := Time.get_ticks_msec() / 1000.0
	for peer_id: int in _speech.keys():
		var state: Dictionary = _speech[peer_id]
		var label := state.get("label") as Label
		if label == null or now >= float(state.get("expires", 0.0)):
			if label != null:
				label.queue_free()
			_speech.erase(peer_id)
			continue
		var avatar := _spawn.get_avatar(peer_id)
		var camera := _player.get_gameplay_camera()
		if avatar == null or camera == null:
			label.hide()
			continue
		var world_position := avatar.get_body_center_position() + Vector3.UP * 1.2
		if camera.is_position_behind(world_position):
			label.hide()
			continue
		var screen_position := camera.unproject_position(world_position)
		label.position = screen_position - Vector2(label.size.x * 0.5, 42.0)
		label.show()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = Vector2(18, 390)
	_panel.size = Vector2(390, 240)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	_history = Label.new()
	_history.custom_minimum_size = Vector2(360, 150)
	_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_history.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_history.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_history)
	_entry = LineEdit.new()
	_entry.placeholder_text = "type a message…"
	_entry.max_length = NetworkChatProtocol.MAX_VISIBLE_CHARACTERS
	_entry.text_submitted.connect(func(_value: String) -> void: _send())
	_entry.hide()
	box.add_child(_entry)
	_chat_button = Button.new()
	_chat_button.text = "chat"
	_chat_button.position = Vector2(18, 570)
	_chat_button.size = Vector2(76, 54)
	_chat_button.pressed.connect(open_chat)
	add_child(_chat_button)
	_speech_layer = Control.new()
	_speech_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_speech_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_speech_layer)
	_panel.hide()


func _send() -> void:
	var body := _entry.text
	if _service.send_local_message(body):
		_entry.clear()
		close_chat()


func _on_message(message: Dictionary) -> void:
	_last_message_time = Time.get_ticks_msec() / 1000.0
	_refresh_history()
	if int(message["kind"]) != NetworkChatProtocol.Kind.PLAYER:
		return
	var peer_id: int = message["sender_peer_id"]
	_on_peer_removed(peer_id)
	var label := Label.new()
	label.text = "%s: %s" % [
		str(message["sender_display_name"]), str(message["body"]).left(120),
	]
	label.custom_minimum_size = Vector2(80, 34)
	label.size = Vector2(280, 70)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech_layer.add_child(label)
	_speech[peer_id] = {
		"label": label,
		"expires": Time.get_ticks_msec() / 1000.0 + SPEECH_SECONDS,
		"fingerprint": str(message.get("sender_fingerprint", "")),
	}


func _on_history(_messages: Array) -> void:
	for peer_id: int in _speech.keys():
		var state: Dictionary = _speech[peer_id]
		if (
			_messages.is_empty()
			or _service.is_sender_filtered(
				str(state.get("fingerprint", ""))
			)
		):
			_on_peer_removed(peer_id)
	_refresh_history()


func _on_rejected(message: String) -> void:
	_entry.placeholder_text = message
	if not _opened:
		open_chat()


func _refresh_history() -> void:
	if _service == null:
		return
	var lines: Array[String] = []
	var messages := _service.get_history()
	var start := maxi(0, messages.size() - 8)
	for message: Dictionary in messages.slice(start):
		if int(message["kind"]) == NetworkChatProtocol.Kind.SYSTEM:
			lines.append("• %s" % str(message["body"]))
		else:
			lines.append("%s: %s" % [
				str(message["sender_display_name"]), str(message["body"]),
			])
	_history.text = "\n".join(lines)


func _refresh_visibility() -> void:
	if not _available:
		_panel.hide()
		return
	if _opened:
		_panel.show()
		return
	var recent := (
		Time.get_ticks_msec() / 1000.0 - _last_message_time
		< COMPACT_SECONDS
	)
	_panel.visible = recent and _service != null and not _service.get_history().is_empty()


func _on_peer_removed(peer_id: int) -> void:
	var state: Dictionary = _speech.get(peer_id, {})
	var label := state.get("label") as Label
	if label != null:
		label.queue_free()
	_speech.erase(peer_id)
