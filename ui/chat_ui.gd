class_name ChatUI
extends Control

const INPUT_OWNER: StringName = &"chat"
const RECENT_SECONDS: float = 8.0
const SPEECH_SECONDS: float = 6.0
const DRAFT_SAVE_DELAY: float = 0.4
const IDLE_ALPHA: float = 0.58
const ORIGINAL_PANEL_WIDTH: float = 390.0
const PANEL_WIDTH: float = ORIGINAL_PANEL_WIDTH * 0.85
const COMPACT_HEIGHT: float = 250.0
const BOTTOM_MARGIN: float = 94.0
const MIN_TOP_MARGIN: float = 24.0
const MIN_HISTORY_HEIGHT: float = 92.0
const HISTORY_FONT_SIZE: int = 17
const INPUT_FONT_SIZE: int = 23
const HINT_FONT_SIZE: int = 12
const HISTORY_INPUT_GAP: int = 8
const HANDLE_SIZE := Vector2(34, 42)
const HANDLE_GAP: float = 6.0
const COLLAPSED_REVEAL_WIDTH: float = 8.0
const HINT_EDGE_MARGIN: float = 4.0

enum PresentationState {
	COLLAPSED,
	COMPACT,
	EXPANDED,
}

signal text_entry_ownership_changed(active: bool)

var _service: NetworkChatService
var _session: NetworkSession
var _spawn: PlayerSpawnService
var _player: Player
var _fishing_spot: FishingSpot
var _settings: PlayerSettingsManager
var _history: RichTextLabel
var _entry: LineEdit
var _status: Label
var _panel: PanelContainer
var _collapse_button: Button
var _height_button: Button
var _unread_indicator: Label
var _hint: Label
var _speech_layer: Control
var _speech: Dictionary[int, Dictionary] = {}
var _draft_save_timer: Timer
var _opacity_tween: Tween
var _height_tween: Tween
var _opened: bool = false
var _available: bool = false
var _presentation_state := PresentationState.COMPACT
var _visible_state_before_collapse := PresentationState.COMPACT
var _panel_hovered: bool = false
var _collapsed_has_unread: bool = false
var _last_message_time: float = -INF
var _target_alpha: float = -1.0
var _send_pending: bool = false
var _pending_send_body: String = ""
var _prior_movement: bool = true
var _prior_camera: bool = true
var _output_scale: float = 1.0
var _dock_right: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	resized.connect(_on_viewport_resized)
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
	set_dock_right(_settings.current_settings.chat_dock_right)
	_service.message_received.connect(_on_message)
	_service.local_message_confirmed.connect(_on_local_message_confirmed)
	_service.history_replaced.connect(_on_history)
	_service.send_rejected.connect(_on_rejected)
	_session.peer_removed.connect(_on_peer_removed)
	_entry.text = _settings.current_settings.chat_draft
	_entry.caret_column = _entry.text.length()
	_set_presentation_state(
		PresentationState.COLLAPSED
		if _settings.current_settings.chat_collapsed
		else PresentationState.COMPACT,
		false,
		false,
	)
	_refresh_history()


func open_chat() -> void:
	if (
		_opened or not _available or _service == null
		or not _session.is_gameplay_session_active()
	):
		return
	if _presentation_state == PresentationState.COLLAPSED:
		_set_presentation_state(_visible_state_before_collapse, true, true)
	_opened = true
	text_entry_ownership_changed.emit(true)
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
	text_entry_ownership_changed.emit(false)
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
	_panel.name = "ChatPanel"
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
	box.add_theme_constant_override("separation", HISTORY_INPUT_GAP)
	_panel.add_child(box)
	_history = RichTextLabel.new()
	_history.name = "ChatHistory"
	_history.custom_minimum_size = Vector2(0, MIN_HISTORY_HEIGHT)
	_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_history.fit_content = false
	_history.scroll_active = true
	_history.scroll_following = false
	_history.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_history.mouse_filter = Control.MOUSE_FILTER_STOP
	_history.add_theme_font_override("normal_font", UtilityPageStyle.TuffyFont)
	_history.add_theme_font_size_override("normal_font_size", HISTORY_FONT_SIZE)
	_history.add_theme_color_override("default_color", UtilityPageStyle.LIGHT_TEXT)
	_history.add_theme_stylebox_override("normal", _borderless_style(Color.TRANSPARENT))
	box.add_child(_history)
	_status = Label.new()
	_status.custom_minimum_size = Vector2(0, 20)
	_status.hide()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	_status.add_theme_color_override("font_color", Color("ffd6a1"))
	box.add_child(_status)
	_entry = LineEdit.new()
	_entry.name = "ChatEntry"
	_entry.placeholder_text = "type a message…"
	_entry.max_length = NetworkChatProtocol.MAX_VISIBLE_CHARACTERS
	_entry.text_submitted.connect(func(_value: String) -> void: _send())
	_entry.text_changed.connect(_on_draft_changed)
	UtilityPageStyle.apply_ocean_line_edit(_entry)
	_entry.add_theme_font_size_override("font_size", INPUT_FONT_SIZE)
	box.add_child(_entry)
	_entry.hide()
	_collapse_button = Button.new()
	_collapse_button.name = "ChatCollapseButton"
	_collapse_button.size = HANDLE_SIZE
	_collapse_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_collapse_button.focus_mode = Control.FOCUS_ALL
	_collapse_button.z_index = 3
	_collapse_button.tooltip_text = "Collapse chat"
	_collapse_button.pressed.connect(func() -> void:
		if _presentation_state == PresentationState.COLLAPSED:
			_set_presentation_state(
				_visible_state_before_collapse,
				true,
				true,
			)
		else:
			if _opened:
				close_chat()
			_set_presentation_state(PresentationState.COLLAPSED, true, true)
	)
	_collapse_button.focus_entered.connect(func() -> void:
		_update_panel_opacity(true)
	)
	_collapse_button.mouse_entered.connect(_on_exterior_handle_entered)
	_collapse_button.mouse_exited.connect(_on_exterior_handle_exited)
	_apply_flat_chat_button(_collapse_button)
	add_child(_collapse_button)
	_height_button = Button.new()
	_height_button.name = "ChatHeightButton"
	_height_button.size = HANDLE_SIZE
	_height_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_height_button.focus_mode = Control.FOCUS_ALL
	_height_button.z_index = 3
	_height_button.pressed.connect(func() -> void:
		if _presentation_state == PresentationState.COLLAPSED:
			_visible_state_before_collapse = (
				PresentationState.COMPACT
				if _visible_state_before_collapse == PresentationState.EXPANDED
				else PresentationState.EXPANDED
			)
			_refresh_handle_labels(PresentationState.COLLAPSED)
			_layout_presentation(true)
			return
		_set_presentation_state(
			PresentationState.COMPACT
			if _presentation_state == PresentationState.EXPANDED
			else PresentationState.EXPANDED,
			true,
			true,
		)
	)
	_height_button.focus_entered.connect(func() -> void:
		_update_panel_opacity(true)
	)
	_height_button.mouse_entered.connect(_on_exterior_handle_entered)
	_height_button.mouse_exited.connect(_on_exterior_handle_exited)
	_apply_flat_chat_button(_height_button)
	add_child(_height_button)
	_unread_indicator = Label.new()
	_unread_indicator.name = "ChatUnreadIndicator"
	_unread_indicator.text = "•"
	_unread_indicator.size = Vector2(22, 20)
	_unread_indicator.z_index = 4
	_unread_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unread_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unread_indicator.add_theme_font_override(
		"font", UtilityPageStyle.TuffyFont
	)
	_unread_indicator.add_theme_font_size_override("font_size", 20)
	_unread_indicator.add_theme_color_override("font_color", Color("ffe08a"))
	add_child(_unread_indicator)
	_hint = Label.new()
	_hint.name = "ChatHint"
	_hint.text = "Press Enter to chat"
	_hint.size = Vector2(180, 18)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	_hint.add_theme_font_size_override("font_size", HINT_FONT_SIZE)
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
	_height_button.hide()
	_unread_indicator.hide()
	_hint.hide()
	_layout_presentation(false)


func _chat_panel_style() -> StyleBoxFlat:
	var style := _borderless_style(Color(0.025, 0.13, 0.19, 0.94))
	style.corner_radius_top_left = 10 if _dock_right else 0
	style.corner_radius_bottom_left = 10 if _dock_right else 0
	style.corner_radius_top_right = 0 if _dock_right else 10
	style.corner_radius_bottom_right = 0 if _dock_right else 10
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _borderless_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(0)
	return style


func _flat_chat_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	style.anti_aliasing = false
	style.shadow_size = 0
	style.shadow_color = Color.TRANSPARENT
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _apply_flat_chat_button(button: Button) -> void:
	button.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	button.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_color_override(
		"font_disabled_color",
		Color(UtilityPageStyle.OCEAN_TEXT_SECONDARY, 0.52),
	)
	button.add_theme_stylebox_override(
		"normal", _flat_chat_button_style(UtilityPageStyle.OCEAN_BUTTON)
	)
	button.add_theme_stylebox_override(
		"hover", _flat_chat_button_style(UtilityPageStyle.OCEAN_BUTTON_HOVER)
	)
	button.add_theme_stylebox_override(
		"pressed", _flat_chat_button_style(UtilityPageStyle.OCEAN_SELECTED)
	)
	button.add_theme_stylebox_override(
		"hover_pressed",
		_flat_chat_button_style(UtilityPageStyle.OCEAN_SELECTED),
	)
	button.add_theme_stylebox_override(
		"focus", _flat_chat_button_style(UtilityPageStyle.OCEAN_SELECTED)
	)
	button.add_theme_stylebox_override(
		"disabled", _flat_chat_button_style(UtilityPageStyle.OCEAN_DISABLED)
	)


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
		_set_status("Sending…")


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
	_set_status("")
	_flush_draft()
	close_chat()


func _on_message(message: Dictionary) -> void:
	_last_message_time = Time.get_ticks_msec() / 1000.0
	_refresh_history()
	if _presentation_state == PresentationState.COLLAPSED:
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
	_set_status(message)
	if not _opened:
		open_chat()


func _refresh_history() -> void:
	if _service == null:
		return
	var scroll_state := _capture_history_scroll()
	var lines: Array[String] = []
	var messages := _service.get_history()
	for message: Dictionary in messages:
		if int(message["kind"]) == NetworkChatProtocol.Kind.SYSTEM:
			lines.append("• %s" % str(message["body"]))
		else:
			lines.append("%s: %s" % [
				str(message["sender_display_name"]), str(message["body"]),
			])
	_history.text = "\n".join(lines)
	_restore_history_scroll.call_deferred(scroll_state)


func _refresh_visibility() -> void:
	if not _available:
		_panel.hide()
		_collapse_button.hide()
		_height_button.hide()
		_unread_indicator.hide()
		_hint.hide()
		return
	_collapse_button.show()
	var collapsed := _presentation_state == PresentationState.COLLAPSED
	_panel.show()
	_height_button.show()
	_unread_indicator.visible = collapsed and _collapsed_has_unread
	_hint.visible = not _opened


func _set_presentation_state(
	state: PresentationState,
	persist: bool = true,
	animate: bool = false,
) -> void:
	var previous_state := _presentation_state
	if (
		state == PresentationState.COLLAPSED
		and previous_state != PresentationState.COLLAPSED
	):
		_visible_state_before_collapse = previous_state
	_refresh_handle_labels(state)
	if state == _presentation_state and not animate:
		_layout_presentation(false)
		_refresh_visibility()
		return
	_presentation_state = state
	var collapsed := state == PresentationState.COLLAPSED
	if not collapsed:
		_collapsed_has_unread = false
		_unread_indicator.hide()
	_layout_presentation(animate)
	if persist and _settings != null:
		_settings.update_chat_preferences(_entry.text, collapsed)
		_draft_save_timer.start()
	_refresh_visibility()


func set_output_scale(output_scale: float) -> void:
	_output_scale = maxf(output_scale, 0.001)


func set_dock_right(should_dock_right: bool) -> void:
	_dock_right = should_dock_right
	if not is_node_ready() or _panel == null:
		return
	_panel.add_theme_stylebox_override("panel", _chat_panel_style())
	_refresh_handle_labels(_presentation_state)
	_layout_presentation(false)


func is_docked_right() -> bool:
	return _dock_right


func _refresh_handle_labels(state: PresentationState) -> void:
	var collapsed := state == PresentationState.COLLAPSED
	var height_state := _visible_state_before_collapse if collapsed else state
	if _dock_right:
		_collapse_button.text = "<" if collapsed else ">"
	else:
		_collapse_button.text = ">" if collapsed else "<"
	_collapse_button.tooltip_text = (
		"Show chat" if collapsed else "Hide chat"
	)
	_height_button.text = "v" if height_state == PresentationState.EXPANDED else "^"
	_height_button.tooltip_text = (
		"Compact chat"
		if height_state == PresentationState.EXPANDED
		else "Expand chat history"
	)


func _update_panel_opacity(immediate_recheck: bool = false) -> void:
	if _panel == null or not _available:
		return
	if _presentation_state == PresentationState.COLLAPSED:
		if _height_tween == null or not _height_tween.is_running():
			_panel.modulate.a = IDLE_ALPHA
			_collapse_button.modulate.a = (
				1.0 if _collapsed_has_unread else 0.82
			)
			_height_button.modulate.a = 0.82
		return
	var recent := (
		Time.get_ticks_msec() / 1000.0 - _last_message_time < RECENT_SECONDS
	)
	var focus_owner := get_viewport().gui_get_focus_owner()
	var wants_full := (
		_opened or recent or _panel_hovered
		or focus_owner == _collapse_button
		or focus_owner == _height_button
		or focus_owner == _entry
	)
	var desired := 1.0 if wants_full else IDLE_ALPHA
	if not immediate_recheck and is_equal_approx(desired, _target_alpha):
		return
	_target_alpha = desired
	if _opacity_tween != null and _opacity_tween.is_valid():
		_opacity_tween.kill()
	_opacity_tween = create_tween()
	_opacity_tween.set_parallel(true)
	for control: Control in [_panel, _collapse_button, _height_button]:
		_opacity_tween.tween_property(
			control, "modulate:a", desired, 0.18
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
		var screen_position := (
			camera.unproject_position(world_position) / _output_scale
		)
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
	_settings.update_chat_preferences(
		_entry.text,
		_presentation_state == PresentationState.COLLAPSED,
	)
	_draft_save_timer.start()


func _flush_draft() -> void:
	if _settings == null or _entry == null:
		return
	_settings.update_chat_preferences(
		_entry.text,
		_presentation_state == PresentationState.COLLAPSED,
	)
	_settings.save_chat_preferences()


func _set_status(text: String) -> void:
	_status.text = text
	_status.visible = not text.is_empty()


func _layout_presentation(animate: bool) -> void:
	if _panel == null:
		return
	var viewport_width := size.x
	if viewport_width <= 0.0:
		viewport_width = 1280.0
	var viewport_height := size.y
	if viewport_height <= 0.0:
		viewport_height = 720.0
	var bottom_margin := minf(
		BOTTOM_MARGIN,
		maxf(MIN_TOP_MARGIN, (viewport_height - MIN_HISTORY_HEIGHT) * 0.25),
	)
	var bottom := viewport_height - bottom_margin
	var height := COMPACT_HEIGHT
	var layout_state := (
		_visible_state_before_collapse
		if _presentation_state == PresentationState.COLLAPSED
		else _presentation_state
	)
	if layout_state == PresentationState.EXPANDED:
		height = maxf(MIN_HISTORY_HEIGHT, viewport_height - 2.0 * bottom_margin)
	height = minf(height, maxf(MIN_HISTORY_HEIGHT, bottom - MIN_TOP_MARGIN))
	var collapsed := _presentation_state == PresentationState.COLLAPSED
	var panel_x: float
	if _dock_right:
		panel_x = (
			viewport_width - COLLAPSED_REVEAL_WIDTH
			if collapsed
			else viewport_width - PANEL_WIDTH
		)
	else:
		panel_x = -(PANEL_WIDTH - COLLAPSED_REVEAL_WIDTH) if collapsed else 0.0
	var target_position := Vector2(panel_x, bottom - height)
	var target_size := Vector2(PANEL_WIDTH, height)
	var handle_stack_height := HANDLE_SIZE.y * 2.0 + HANDLE_GAP
	var handle_stack_top := (
		bottom - COMPACT_HEIGHT * 0.5 - handle_stack_height * 0.5
	)
	var handle_x: float
	if _dock_right:
		handle_x = panel_x - HANDLE_SIZE.x
	else:
		handle_x = COLLAPSED_REVEAL_WIDTH if collapsed else PANEL_WIDTH
	var collapse_position := Vector2(
		handle_x,
		handle_stack_top + HANDLE_SIZE.y + HANDLE_GAP,
	)
	var height_position := Vector2(handle_x, handle_stack_top)
	var unread_offset_x := -18.0 if _dock_right else 6.0
	var unread_position := collapse_position + Vector2(unread_offset_x, -18.0)
	var hint_position := Vector2(
		(
			viewport_width - _hint.size.x - HINT_EDGE_MARGIN
			if _dock_right
			else HINT_EDGE_MARGIN
		),
		viewport_height - _hint.size.y - HINT_EDGE_MARGIN,
	)
	if _height_tween != null and _height_tween.is_valid():
		_height_tween.kill()
	if not animate:
		_panel.position = target_position
		_panel.size = target_size
		_collapse_button.position = collapse_position
		_height_button.position = height_position
		_unread_indicator.position = unread_position
		_hint.position = hint_position
		return
	var scroll_state := _capture_history_scroll()
	_height_tween = create_tween().set_parallel(true)
	_height_tween.tween_property(
		_panel, "position", target_position, UIMotion.CHAT_RESIZE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_height_tween.tween_property(
		_panel, "size", target_size, UIMotion.CHAT_RESIZE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_height_tween.tween_property(
		_collapse_button,
		"position",
		collapse_position,
		UIMotion.CHAT_RESIZE_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_height_tween.tween_property(
		_height_button,
		"position",
		height_position,
		UIMotion.CHAT_RESIZE_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_height_tween.tween_property(
		_unread_indicator,
		"position",
		unread_position,
		UIMotion.CHAT_RESIZE_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_height_tween.finished.connect(func() -> void:
		_restore_history_scroll(scroll_state)
	)
	_hint.position = hint_position


func _capture_history_scroll() -> Dictionary:
	if _history == null:
		return {"pinned": true, "value": 0.0}
	var scroll := _history.get_v_scroll_bar()
	if scroll == null:
		return {"pinned": true, "value": 0.0}
	var bottom := maxf(scroll.min_value, scroll.max_value - scroll.page)
	return {
		"pinned": scroll.value >= bottom - 2.0,
		"value": scroll.value,
	}


func _restore_history_scroll(state: Dictionary) -> void:
	if _history == null:
		return
	var scroll := _history.get_v_scroll_bar()
	if scroll == null:
		return
	if bool(state.get("pinned", true)):
		scroll.value = maxf(scroll.min_value, scroll.max_value - scroll.page)
	else:
		scroll.value = clampf(
			float(state.get("value", 0.0)),
			scroll.min_value,
			maxf(scroll.min_value, scroll.max_value - scroll.page),
		)


func _on_viewport_resized() -> void:
	_layout_presentation(false)


func _on_exterior_handle_entered() -> void:
	_panel_hovered = true
	_update_panel_opacity(true)


func _on_exterior_handle_exited() -> void:
	_panel_hovered = false
	_update_panel_opacity(true)


func _on_peer_removed(peer_id: int) -> void:
	var state: Dictionary = _speech.get(peer_id, {})
	var bubble := state.get("bubble") as PanelContainer
	if bubble != null:
		bubble.queue_free()
	_speech.erase(peer_id)
