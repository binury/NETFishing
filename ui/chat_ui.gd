class_name ChatUI
extends Control

const INPUT_OWNER: StringName = &"chat"
const RECENT_SECONDS: float = 8.0
const SPEECH_SECONDS: float = 6.0
const DRAFT_SAVE_DELAY: float = 0.4
const IDLE_ALPHA: float = 0.58
const PANEL_POSITION := Vector2(30, 376)
const PANEL_SIZE := Vector2(390, 250)

var _service: NetworkChatService
var _session: NetworkSession
var _spawn: PlayerSpawnService
var _player: Player
var _fishing_spot: FishingSpot
var _settings: PlayerSettingsManager
var _history: Label
var _entry: LineEdit
var _status: Label
var _panel: PanelContainer
var _collapse_button: Button
var _unread_indicator: Label
var _hint: Label
var _speech_layer: Control
var _speech: Dictionary[int, Dictionary] = {}
var _draft_save_timer: Timer
var _opacity_tween: Tween
var _opened: bool = false
var _available: bool = false
var _collapsed: bool = false
var _panel_hovered: bool = false
var _collapsed_has_unread: bool = false
var _last_message_time: float = -INF
var _target_alpha: float = -1.0
var _send_pending: bool = false
var _pending_send_body: String = ""
var _prior_movement: bool = true
var _prior_camera: bool = true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	set_process(true)


func setup(
	service: NetworkChatService,
	session: NetworkSession,
	spawn: PlayerSpawnService,
	player: Player,
	fishing_spot: FishingSpot,
	settings: PlayerSettingsManager,
) -> void:
	_service = service
	_session = session
	_spawn = spawn
	_player = player
	_fishing_spot = fishing_spot
	_settings = settings
	_service.message_received.connect(_on_message)
	_service.local_message_confirmed.connect(_on_local_message_confirmed)
	_service.history_replaced.connect(_on_history)
	_service.send_rejected.connect(_on_rejected)
	_session.peer_removed.connect(_on_peer_removed)
	_entry.text = _settings.current_settings.chat_draft
	_entry.caret_column = _entry.text.length()
	_set_collapsed(_settings.current_settings.chat_collapsed, false)
	_refresh_history()


func open_chat() -> void:
	if (
		_opened or not _available or _service == null
		or not _session.is_gameplay_session_active()
	):
		return
	_set_collapsed(false)
	_opened = true
	_prior_movement = _player.is_movement_enabled()
	_prior_camera = _player.is_camera_input_enabled()
	_player.set_movement_enabled(false)
	_player.set_camera_input_enabled(false)
	_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, true)
	# Clear the last authoritative input immediately. Merely disabling local
	# prediction would let a remote host continue the last held movement.
	_session.submit_neutral_local_movement()
	_entry.show()
	_entry.grab_focus()
	_hint.hide()
	_update_panel_opacity(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func set_available(value: bool) -> void:
	_available = value
	if not value:
		_send_pending = false
		_pending_send_body = ""
		_entry.editable = true
		close_chat()
	_flush_draft()
	_refresh_visibility()


func close_chat() -> void:
	if not _opened:
		return
	_opened = false
	_entry.release_focus()
	_entry.hide()
	_player.set_movement_enabled(_prior_movement)
	_player.set_camera_input_enabled(_prior_camera)
	_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, false)
	_flush_draft()
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
	_update_panel_opacity()
	_update_speech()


func _exit_tree() -> void:
	_flush_draft()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.position = PANEL_POSITION
	_panel.size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _chat_panel_style())
	_panel.mouse_entered.connect(func() -> void:
		_panel_hovered = true
		_update_panel_opacity(true)
	)
	_panel.mouse_exited.connect(func() -> void:
		_panel_hovered = false
		_update_panel_opacity(true)
	)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_panel.add_child(box)
	_history = Label.new()
	_history.custom_minimum_size = Vector2(360, 158)
	_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_history.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_history.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_history.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	_history.add_theme_color_override("font_color", UtilityPageStyle.LIGHT_TEXT)
	box.add_child(_history)
	_status = Label.new()
	_status.custom_minimum_size = Vector2(360, 20)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	_status.add_theme_color_override("font_color", Color("ffd6a1"))
	box.add_child(_status)
	_entry = LineEdit.new()
	_entry.placeholder_text = "type a message…"
	_entry.max_length = NetworkChatProtocol.MAX_VISIBLE_CHARACTERS
	_entry.text_submitted.connect(func(_value: String) -> void: _send())
	_entry.text_changed.connect(_on_draft_changed)
	UtilityPageStyle.apply_line_edit(_entry)
	box.add_child(_entry)
	_entry.hide()
	_collapse_button = Button.new()
	_collapse_button.position = Vector2(2, PANEL_POSITION.y + 101)
	_collapse_button.size = Vector2(34, 48)
	_collapse_button.tooltip_text = "Collapse chat"
	_collapse_button.pressed.connect(func() -> void:
		_set_collapsed(not _collapsed)
	)
	_collapse_button.focus_entered.connect(func() -> void:
		_update_panel_opacity(true)
	)
	UtilityPageStyle.apply_button(_collapse_button)
	add_child(_collapse_button)
	_unread_indicator = Label.new()
	_unread_indicator.text = "•"
	_unread_indicator.position = Vector2(8, PANEL_POSITION.y + 86)
	_unread_indicator.size = Vector2(22, 20)
	_unread_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unread_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unread_indicator.add_theme_font_override(
		"font", UtilityPageStyle.TuffyFont
	)
	_unread_indicator.add_theme_font_size_override("font_size", 20)
	_unread_indicator.add_theme_color_override("font_color", Color("ffe08a"))
	add_child(_unread_indicator)
	_hint = Label.new()
	_hint.text = "Press Enter to chat"
	_hint.position = Vector2(30, 655)
	_hint.size = Vector2(260, 28)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	_hint.add_theme_color_override(
		"font_color", Color(0.94, 0.91, 0.80, 0.72)
	)
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 2)
	add_child(_hint)
	_speech_layer = Control.new()
	_speech_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_speech_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_speech_layer)
	_draft_save_timer = Timer.new()
	_draft_save_timer.one_shot = true
	_draft_save_timer.wait_time = DRAFT_SAVE_DELAY
	_draft_save_timer.timeout.connect(_flush_draft)
	add_child(_draft_save_timer)
	_panel.hide()
	_collapse_button.hide()
	_unread_indicator.hide()
	_hint.hide()


func _chat_panel_style() -> StyleBoxFlat:
	var style := UtilityPageStyle.button_style(Color(0.025, 0.13, 0.19, 0.94))
	style.border_color = Color(0.75, 0.84, 0.74, 0.66)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _speech_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UtilityPageStyle.PAPER_ALT, 0.96)
	style.border_color = Color(UtilityPageStyle.BORDER, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0, 0, 0, 0.32)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2, 3)
	return style


func _send() -> void:
	if _send_pending:
		return
	var body := _entry.text
	_send_pending = true
	_pending_send_body = NetworkChatProtocol.sanitize_body(body)
	_entry.editable = false
	if not _service.send_local_message(body):
		_send_pending = false
		_pending_send_body = ""
		_entry.editable = true
	elif _send_pending:
		_status.text = "Sending…"


func _on_local_message_confirmed(message: Dictionary) -> void:
	if (
		not _send_pending
		or str(message.get("body", "")) != _pending_send_body
	):
		return
	_send_pending = false
	_pending_send_body = ""
	_entry.editable = true
	_entry.clear()
	_status.text = ""
	_flush_draft()
	close_chat()


func _on_message(message: Dictionary) -> void:
	_last_message_time = Time.get_ticks_msec() / 1000.0
	_refresh_history()
	if _collapsed:
		_collapsed_has_unread = true
		_unread_indicator.show()
	_update_panel_opacity(true)
	if int(message["kind"]) != NetworkChatProtocol.Kind.PLAYER:
		return
	var peer_id: int = message["sender_peer_id"]
	_on_peer_removed(peer_id)
	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.custom_minimum_size = Vector2(270, 0)
	bubble.size = Vector2(270, 72)
	bubble.add_theme_stylebox_override("panel", _speech_panel_style())
	var label := Label.new()
	label.text = str(message["body"]).left(120)
	label.custom_minimum_size = Vector2(246, 46)
	label.size = Vector2(246, 62)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	label.add_theme_color_override("font_color", UtilityPageStyle.INK)
	bubble.add_child(label)
	_speech_layer.add_child(bubble)
	_speech[peer_id] = {
		"bubble": bubble,
		"expires": Time.get_ticks_msec() / 1000.0 + SPEECH_SECONDS,
		"fingerprint": str(message.get("sender_fingerprint", "")),
	}


func _on_history(messages: Array) -> void:
	for peer_id: int in _speech.keys():
		var state: Dictionary = _speech[peer_id]
		if (
			messages.is_empty()
			or _service.is_sender_filtered(
				str(state.get("fingerprint", ""))
			)
		):
			_on_peer_removed(peer_id)
	_refresh_history()


func _on_rejected(message: String) -> void:
	_send_pending = false
	_pending_send_body = ""
	_entry.editable = true
	_status.text = message
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
		_collapse_button.hide()
		_unread_indicator.hide()
		_hint.hide()
		return
	_collapse_button.show()
	_panel.visible = not _collapsed
	_unread_indicator.visible = _collapsed and _collapsed_has_unread
	_hint.visible = not _opened


func _set_collapsed(value: bool, persist: bool = true) -> void:
	_collapsed = value
	_collapse_button.text = "›" if _collapsed else "‹"
	_collapse_button.tooltip_text = (
		"Expand chat" if _collapsed else "Collapse chat"
	)
	if not _collapsed:
		_collapsed_has_unread = false
		_unread_indicator.hide()
	if persist and _settings != null:
		_settings.update_chat_preferences(_entry.text, _collapsed)
		_draft_save_timer.start()
	_refresh_visibility()


func _update_panel_opacity(immediate_recheck: bool = false) -> void:
	if _panel == null or _collapsed or not _available:
		return
	var recent := (
		Time.get_ticks_msec() / 1000.0 - _last_message_time < RECENT_SECONDS
	)
	var focus_owner := get_viewport().gui_get_focus_owner()
	var wants_full := (
		_opened or recent or _panel_hovered
		or focus_owner == _collapse_button
		or focus_owner == _entry
	)
	var desired := 1.0 if wants_full else IDLE_ALPHA
	if not immediate_recheck and is_equal_approx(desired, _target_alpha):
		return
	_target_alpha = desired
	if _opacity_tween != null and _opacity_tween.is_valid():
		_opacity_tween.kill()
	_opacity_tween = create_tween()
	_opacity_tween.tween_property(
		_panel, "modulate:a", desired, 0.18
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_speech() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	for peer_id: int in _speech.keys():
		var state: Dictionary = _speech[peer_id]
		var bubble := state.get("bubble") as PanelContainer
		if bubble == null or now >= float(state.get("expires", 0.0)):
			if bubble != null:
				bubble.queue_free()
			_speech.erase(peer_id)
			continue
		var avatar := _spawn.get_avatar(peer_id)
		var camera := _player.get_gameplay_camera()
		if avatar == null or camera == null:
			bubble.hide()
			continue
		var world_position := avatar.get_chat_anchor_position()
		if camera.is_position_behind(world_position):
			bubble.hide()
			continue
		var screen_position := camera.unproject_position(world_position)
		var viewport_size := get_viewport_rect().size
		if (
			screen_position.x < -80.0
			or screen_position.x > viewport_size.x + 80.0
			or screen_position.y < -80.0
			or screen_position.y > viewport_size.y + 80.0
		):
			bubble.hide()
			continue
		var desired := screen_position - Vector2(
			bubble.size.x * 0.5, bubble.size.y + 8.0
		)
		bubble.position = Vector2(
			clampf(desired.x, 8.0, viewport_size.x - bubble.size.x - 8.0),
			clampf(desired.y, 8.0, viewport_size.y - bubble.size.y - 8.0),
		)
		bubble.show()


func _on_draft_changed(_value: String) -> void:
	if _settings == null:
		return
	_settings.update_chat_preferences(_entry.text, _collapsed)
	_draft_save_timer.start()


func _flush_draft() -> void:
	if _settings == null or _entry == null:
		return
	_settings.update_chat_preferences(_entry.text, _collapsed)
	_settings.save_chat_preferences()


func _on_peer_removed(peer_id: int) -> void:
	var state: Dictionary = _speech.get(peer_id, {})
	var bubble := state.get("bubble") as PanelContainer
	if bubble != null:
		bubble.queue_free()
	_speech.erase(peer_id)
