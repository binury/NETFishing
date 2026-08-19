class_name ChatUI
extends Control

const INPUT_OWNER: StringName = &"chat"
const RECENT_SECONDS: float = 8.0
const SPEECH_SECONDS: float = 6.0
const DRAFT_SAVE_DELAY: float = 0.4
const IDLE_ALPHA: float = 0.58
const CHAT_SURFACE_COLOR := Color(0.025, 0.13, 0.19, 0.94)
const PANEL_WIDTH: float = 290.0
const COMPACT_HEIGHT: float = 250.0
const BOTTOM_MARGIN: float = 12.0
const MIN_TOP_MARGIN: float = 24.0
const MIN_HISTORY_HEIGHT: float = 92.0
const HISTORY_FONT_SIZE: int = 20
const INPUT_FONT_SIZE: int = 23
const HINT_FONT_SIZE: int = 12
const HISTORY_INPUT_GAP: int = 8
const HANDLE_SIZE := Vector2(34, 42)
const HANDLE_GAP: float = 6.0
const HANDLE_TOP_INSET: float = 18.0
const COLLAPSED_REVEAL_WIDTH: float = 8.0
const HINT_EDGE_MARGIN: float = 4.0
const SPEECH_BUBBLE_WIDTH: float = 320.0
const SPEECH_POINTER_HALF_WIDTH: float = 12.0
const SPEECH_POINTER_HEIGHT: float = 14.0
const SPEECH_POINTER_OVERLAP: float = 3.0
const ANIMALESE_FULL_VOLUME_DISTANCE: float = 4.0
const ANIMALESE_SILENT_DISTANCE: float = 24.0
const ANIMALESE_SILENT_VOLUME_DB: float = -80.0
const MOBILE_COMPACT_WIDTH: float = 620.0
const MOBILE_EXPANDED_WIDTH: float = 820.0
const MOBILE_COMPACT_HEIGHT: float = 220.0
const MOBILE_EXPANDED_HEIGHT: float = 390.0
const MOBILE_EDGE_MARGIN: float = 12.0
const CLOCK_SIZE := Vector2(174.0, 51.0)
const CLOCK_FONT_SIZE: int = 27
const CLOCK_EDGE_MARGIN: float = 10.0
const WEATHER_ICON_SIZE := Vector2(51.0, 51.0)
const WEATHER_ICON_GAP: float = 6.0
const CALENDAR_SIZE := Vector2(
	CLOCK_SIZE.x + WEATHER_ICON_GAP + WEATHER_ICON_SIZE.x,
	28.0,
)
const CALENDAR_FONT_SIZE: int = 16
const CALENDAR_TOP_GAP: float = 4.0
const EXPANDED_CHAT_TOP_GAP: float = 12.0
const EXPANDED_TOP_MARGIN: float = (
	CLOCK_EDGE_MARGIN
	+ CLOCK_SIZE.y
	+ CALENDAR_TOP_GAP
	+ CALENDAR_SIZE.y
	+ EXPANDED_CHAT_TOP_GAP
)
const STATUS_EFFECT_ICON_SIZE := Vector2(40.0, 40.0)
const STATUS_EFFECT_TOP_GAP: float = 6.0
const STATUS_EFFECT_ICON_GAP: int = 4
const STATUS_EFFECT_WARNING_RATIO: float = 0.10
const STATUS_EFFECT_PULSE_PERIOD: float = 1.0
const STATUS_EFFECT_PULSE_MIN_ALPHA: float = 0.25
const CHAT_SHOW_ICON: Texture2D = preload(
	"res://ui/icons/pictograms/arrow_light_right_more.png"
)
const CHAT_HIDE_ICON: Texture2D = preload(
	"res://ui/icons/pictograms/arrow_light_left_more.png"
)
const CHAT_EXPAND_ICON: Texture2D = preload(
	"res://ui/icons/pictograms/arrow_light_up_more.png"
)
const CHAT_COMPACT_ICON: Texture2D = preload(
	"res://ui/icons/pictograms/arrow_light_down_more.png"
)
const WorldTimeServiceType = preload("res://world/world_time_service.gd")
const WorldWeatherServiceType = preload(
	"res://world/world_weather_service.gd"
)
const WeatherIconType = preload("res://ui/weather_icon.gd")
const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")

const TypewriterRevealType = preload("res://ui/typewriter_reveal.gd")
const AnimaleseVoiceType = preload("res://ui/animalese_voice.gd")
const VoiceProfilesType = preload(
	"res://player/animalese_voice_profiles.gd"
)


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
var _animalese_voice: AnimaleseVoiceType
var _clock_panel: PanelContainer
var _clock_label: Label
var _calendar_panel: PanelContainer
var _calendar_label: Label
var _weather_icon: WeatherIconType
var _status_effect_column: VBoxContainer
var _status_effect_icons: Dictionary[StringName, TextureRect] = {}
var _speech: Dictionary[int, Dictionary] = {}
var _draft_save_timer: Timer
var _opacity_tween: Tween
var _height_tween: Tween
var _opened: bool = false
var _available: bool = false
var _hud_hidden: bool = false
var _world_speech_visible: bool = true
var _presentation_state := PresentationState.COMPACT
var _visible_state_before_collapse := PresentationState.COMPACT
var _panel_hovered: bool = false
var _collapsed_has_unread: bool = false
var _last_message_time: float = -INF
var _target_alpha: float = -1.0
var _send_pending: bool = false
var _pending_send_body: String = ""
var _controller_refocused: bool = false
var _input_lock_applied: bool = false
var _last_submit_frame: int = -1
var _output_scale: float = 1.0
var _dock_right: bool = false
var _mobile_mode: bool = false
var _world_time: WorldTimeServiceType
var _world_weather: WorldWeatherServiceType
var _item_effects: PlayerItemEffects
var _item_catalog: ItemCatalogType


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
	world_time: WorldTimeServiceType,
	world_weather: WorldWeatherServiceType,
	item_effects: PlayerItemEffects,
	item_catalog: ItemCatalogType,
) -> void:
	_service = service
	_session = session
	_spawn = spawn
	_player = player
	_fishing_spot = fishing_spot
	_settings = settings
	_world_time = world_time
	_world_weather = world_weather
	_item_effects = item_effects
	_item_catalog = item_catalog
	_rebuild_status_effect_icons()
	if (
		_fishing_spot != null
		and not _fishing_spot.local_speech_requested.is_connected(
			show_local_speech
		)
	):
		_fishing_spot.local_speech_requested.connect(show_local_speech)
	if (
		_world_time != null
		and not _world_time.time_changed.is_connected(
			_on_world_time_changed
		)
	):
		_world_time.time_changed.connect(_on_world_time_changed)
		_on_world_time_changed(
			_world_time.get_time_hours(), _world_time.get_phase()
		)
	if (
		_world_time != null
		and not _world_time.calendar_date_changed.is_connected(
			_on_world_calendar_date_changed
		)
	):
		_world_time.calendar_date_changed.connect(
			_on_world_calendar_date_changed
		)
		_on_world_calendar_date_changed(
			_world_time.get_calendar_date_id()
		)
	if (
		_world_weather != null
		and not _world_weather.weather_changed.is_connected(
			_on_world_weather_changed
		)
	):
		_world_weather.weather_changed.connect(_on_world_weather_changed)
		_on_world_weather_changed(
			_world_weather.get_weather(),
			_world_weather.get_seconds_remaining(),
		)
	set_mobile_mode(_settings.current_settings.chat_mobile_mode)
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


func _rebuild_status_effect_icons() -> void:
	for child: Node in _status_effect_column.get_children():
		_status_effect_column.remove_child(child)
		child.queue_free()
	_status_effect_icons.clear()
	if _item_effects == null or _item_catalog == null:
		_status_effect_column.hide()
		return
	for item_id: StringName in _item_effects.get_registered_effect_ids():
		var item: ItemDataType = _item_catalog.get_item_by_id(item_id)
		if item == null or item.icon == null:
			continue
		var icon := TextureRect.new()
		icon.name = "StatusEffect_%s" % String(item_id)
		icon.texture = item.icon
		icon.custom_minimum_size = STATUS_EFFECT_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.hide()
		_status_effect_column.add_child(icon)
		_status_effect_icons[item_id] = icon
	var icon_count: int = _status_effect_icons.size()
	_status_effect_column.size = Vector2(
		STATUS_EFFECT_ICON_SIZE.x,
		STATUS_EFFECT_ICON_SIZE.y * icon_count
		+ STATUS_EFFECT_ICON_GAP * maxi(icon_count - 1, 0),
	)


func _update_status_effect_icons() -> void:
	if _status_effect_column == null:
		return
	var has_active_effect: bool = false
	for item_id: StringName in _status_effect_icons:
		var icon: TextureRect = _status_effect_icons[item_id]
		var remaining: float = (
			_item_effects.get_remaining(item_id)
			if _item_effects != null
			else 0.0
		)
		icon.visible = remaining > 0.0
		icon.modulate = Color.WHITE
		if remaining <= 0.0:
			continue
		has_active_effect = true
		var warning_duration: float = (
			_item_effects.get_effect_duration(item_id)
			* STATUS_EFFECT_WARNING_RATIO
		)
		if warning_duration <= 0.0 or remaining > warning_duration:
			continue
		var warning_elapsed: float = maxf(
			warning_duration - remaining, 0.0
		)
		var pulse_phase: float = (
			fmod(warning_elapsed, STATUS_EFFECT_PULSE_PERIOD)
			/ STATUS_EFFECT_PULSE_PERIOD
		)
		var pulse_weight: float = 0.5 + 0.5 * cos(pulse_phase * TAU)
		icon.modulate.a = lerpf(
			STATUS_EFFECT_PULSE_MIN_ALPHA, 1.0, pulse_weight
		)
	_status_effect_column.visible = (
		has_active_effect
		and _available
		and (not _hud_hidden or _opened)
	)


func open_chat() -> void:
	if (
		_opened or not _available or _service == null
		or not _session.is_gameplay_session_active()
	):
		return
	if _presentation_state == PresentationState.COLLAPSED:
		_set_presentation_state(_visible_state_before_collapse, true, true)
	_controller_refocused = false
	_opened = true
	text_entry_ownership_changed.emit(true)
	_input_lock_applied = true
	_player.set_local_input_suppressed(INPUT_OWNER, true)
	_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, true)
	# Clear the last authoritative input immediately. Merely disabling local
	# prediction would let a remote host continue the last held movement.
	_session.submit_neutral_local_movement()
	_entry.show()
	_configure_controller_focus()
	_entry.virtual_keyboard_enabled = false
	_hint.hide()
	_refresh_input_ownership()
	call_deferred("_focus_entry_after_open")
	_update_panel_opacity(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func open_command_chat() -> void:
	open_chat()
	if not _opened:
		return
	if not _entry.text.begins_with("/"):
		_entry.text = "/" + _entry.text
	_entry.caret_column = _entry.text.length()


func set_available(value: bool) -> void:
	_available = value
	if not value:
		_send_pending = false
		_pending_send_body = ""
		_entry.editable = true
		close_chat()
	_flush_draft()
	_refresh_visibility()


func close_chat(preserve_status: bool = false) -> void:
	var ownership_was_active: bool = _opened or _input_lock_applied
	_opened = false
	if not preserve_status:
		_set_status("")
	_entry.virtual_keyboard_enabled = false
	_entry.release_focus()
	_entry.hide()
	_configure_controller_focus()
	if _input_lock_applied:
		_player.set_local_input_suppressed(INPUT_OWNER, false)
		_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, false)
		_input_lock_applied = false
	if ownership_was_active:
		text_entry_ownership_changed.emit(false)
	_flush_draft()
	_refresh_visibility()
	_refresh_input_ownership()


func toggle_chat() -> void:
	if _presentation_state == PresentationState.COLLAPSED:
		open_chat()
		return
	if _opened:
		close_chat()
		_set_presentation_state(PresentationState.COLLAPSED, true, true)
		return
	if _controller_refocused:
		_controller_refocused = false
		_set_presentation_state(PresentationState.COLLAPSED, true, true)
		return
	open_chat()


func refocus_gameplay() -> void:
	close_chat()
	_controller_refocused = true
	var current_viewport: Viewport = get_viewport()
	if current_viewport != null:
		current_viewport.gui_release_focus()


func toggle_focus() -> void:
	if _presentation_state == PresentationState.COLLAPSED:
		return
	if _opened:
		refocus_gameplay()
	else:
		open_chat()


func request_virtual_keyboard() -> bool:
	if not _opened or not _entry.has_focus():
		return false
	_entry.virtual_keyboard_enabled = true
	# Re-entering focus after the controller accept event is the explicit
	# request Android uses to display its keyboard. Merely focusing Chat keeps
	# the keyboard disabled so the world remains readable.
	_entry.release_focus()
	_entry.call_deferred("grab_focus")
	return true


func _focus_entry_after_open() -> void:
	if not _opened or not _entry.visible:
		return
	_entry.grab_focus()
	_refresh_input_ownership()


func is_open() -> bool:
	return _opened


func is_collapsed() -> bool:
	return _presentation_state == PresentationState.COLLAPSED


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_chat"):
		if event is InputEventKey:
			if _opened:
				_focus_entry_after_open()
			else:
				open_chat()
		else:
			toggle_chat()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			if _opened:
				_last_submit_frame = Engine.get_process_frames()
				_send()
			elif (
				_available
				and get_viewport().gui_get_focus_owner() is not LineEdit
				and Engine.get_process_frames() != _last_submit_frame
			):
				open_chat()
			get_viewport().set_input_as_handled()
		elif (
			event.unicode == 47
			and not _opened
			and _available
			and get_viewport().gui_get_focus_owner() is not LineEdit
		):
			open_command_chat()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _opened:
			close_chat()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	_refresh_visibility()
	_update_status_effect_icons()
	_update_panel_opacity()
	_update_speech()


func _exit_tree() -> void:
	if _input_lock_applied and is_instance_valid(_player):
		_player.set_local_input_suppressed(INPUT_OWNER, false)
		_input_lock_applied = false
	_flush_draft()


func _build_ui() -> void:
	_clock_panel = PanelContainer.new()
	_clock_panel.name = "WorldClockPanel"
	_clock_panel.size = CLOCK_SIZE
	_clock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_panel.add_theme_stylebox_override(
		"panel", _clock_panel_style()
	)
	add_child(_clock_panel)
	_clock_label = Label.new()
	_clock_label.name = "WorldClockLabel"
	_clock_label.text = "8:00 am"
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clock_label.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	_clock_label.add_theme_font_size_override("font_size", CLOCK_FONT_SIZE)
	_clock_label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	_clock_panel.add_child(_clock_label)
	_calendar_panel = PanelContainer.new()
	_calendar_panel.name = "WorldCalendarPanel"
	_calendar_panel.size = CALENDAR_SIZE
	_calendar_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_calendar_panel.add_theme_stylebox_override(
		"panel", _calendar_panel_style()
	)
	add_child(_calendar_panel)
	_calendar_label = Label.new()
	_calendar_label.name = "WorldCalendarLabel"
	_calendar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_calendar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_calendar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_calendar_label.add_theme_font_override(
		"font", UtilityPageStyle.TuffyFont
	)
	_calendar_label.add_theme_font_size_override(
		"font_size", CALENDAR_FONT_SIZE
	)
	_calendar_label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	_calendar_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_calendar_panel.add_child(_calendar_label)
	_status_effect_column = VBoxContainer.new()
	_status_effect_column.name = "StatusEffectColumn"
	_status_effect_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_effect_column.add_theme_constant_override(
		"separation", STATUS_EFFECT_ICON_GAP
	)
	add_child(_status_effect_column)
	_weather_icon = WeatherIconType.new()
	_weather_icon.name = "WorldWeatherIcon"
	_weather_icon.size = WEATHER_ICON_SIZE
	_weather_icon.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_weather_icon)
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
	_history.scroll_following = true
	_history.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_history.mouse_filter = Control.MOUSE_FILTER_STOP
	_history.add_theme_font_override("normal_font", UtilityPageStyle.TuffyFont)
	_history.add_theme_font_size_override("normal_font_size", HISTORY_FONT_SIZE)
	_history.add_theme_color_override("default_color", UtilityPageStyle.LIGHT_TEXT)
	_history.add_theme_stylebox_override("normal", _borderless_style(Color.TRANSPARENT))
	box.add_child(_history)
	_status = Label.new()
	_status.name = "ChatStatus"
	_status.custom_minimum_size = Vector2(0, 20)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.hide()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	_status.add_theme_color_override("font_color", Color("ffd6a1"))
	box.add_child(_status)
	_entry = LineEdit.new()
	_entry.name = "ChatEntry"
	_entry.placeholder_text = "type a message…"
	_entry.max_length = NetworkChatProtocol.MAX_VISIBLE_CHARACTERS
	_entry.text_submitted.connect(_on_entry_text_submitted)
	_entry.text_changed.connect(_on_draft_changed)
	UtilityPageStyle.apply_ocean_line_edit(_entry)
	_entry.add_theme_font_size_override("font_size", INPUT_FONT_SIZE)
	box.add_child(_entry)
	_entry.hide()
	_collapse_button = Button.new()
	_collapse_button.name = "ChatCollapseButton"
	_collapse_button.size = HANDLE_SIZE
	_collapse_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_collapse_button.focus_mode = Control.FOCUS_NONE
	_collapse_button.z_index = 3
	_collapse_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_collapse_button.expand_icon = true
	_collapse_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collapse_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_collapse_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_collapse_button.add_theme_constant_override(
		"icon_max_width",
		roundi(minf(HANDLE_SIZE.x, HANDLE_SIZE.y) * 0.5),
	)
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
	_height_button.focus_mode = Control.FOCUS_NONE
	_height_button.z_index = 3
	_height_button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_height_button.expand_icon = true
	_height_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_height_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_height_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_height_button.add_theme_constant_override(
		"icon_max_width",
		roundi(minf(HANDLE_SIZE.x, HANDLE_SIZE.y) * 0.5),
	)
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
	_animalese_voice = AnimaleseVoiceType.new()
	_animalese_voice.name = "PlayerAnimaleseVoice"
	add_child(_animalese_voice)
	_draft_save_timer = Timer.new()
	_draft_save_timer.one_shot = true
	_draft_save_timer.wait_time = DRAFT_SAVE_DELAY
	_draft_save_timer.timeout.connect(_flush_draft)
	add_child(_draft_save_timer)
	_panel.hide()
	_clock_panel.hide()
	_calendar_panel.hide()
	_weather_icon.hide()
	_collapse_button.hide()
	_height_button.hide()
	_unread_indicator.hide()
	_hint.hide()
	_layout_presentation(false)
	_refresh_input_ownership()


func _chat_panel_style() -> StyleBoxFlat:
	var style := _borderless_style(CHAT_SURFACE_COLOR)
	if _mobile_mode:
		style.corner_radius_top_left = 0
		style.corner_radius_top_right = 0
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
	else:
		style.corner_radius_top_left = 10 if _dock_right else 0
		style.corner_radius_bottom_left = 10 if _dock_right else 0
		style.corner_radius_top_right = 0 if _dock_right else 10
		style.corner_radius_bottom_right = 0 if _dock_right else 10
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _refresh_input_ownership() -> void:
	if _panel == null or _history == null:
		return
	var filter: Control.MouseFilter = (
		Control.MOUSE_FILTER_STOP
		if _opened
		else Control.MOUSE_FILTER_IGNORE
	)
	_panel.mouse_filter = filter
	_history.mouse_filter = filter
	_entry.focus_mode = (
		Control.FOCUS_ALL if _opened else Control.FOCUS_NONE
	)
	_collapse_button.focus_mode = (
		Control.FOCUS_ALL if _opened else Control.FOCUS_NONE
	)
	_height_button.focus_mode = (
		Control.FOCUS_ALL
		if _opened and not _mobile_mode
		else Control.FOCUS_NONE
	)
	if not _opened:
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		if focus_owner in [_entry, _collapse_button, _height_button]:
			get_viewport().gui_release_focus()


func _clock_panel_style() -> StyleBoxFlat:
	var style := _borderless_style(CHAT_SURFACE_COLOR)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _calendar_panel_style() -> StyleBoxFlat:
	var style := _borderless_style(CHAT_SURFACE_COLOR)
	style.set_corner_radius_all(10)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	return style


func _borderless_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(0)
	style.anti_aliasing = false
	style.shadow_size = 0
	style.shadow_color = Color.TRANSPARENT
	style.shadow_offset = Vector2.ZERO
	return style


func _flat_chat_button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_border_width_all(0)
	style.set_corner_radius_all(0)
	if _dock_right:
		style.corner_radius_top_left = 10
		style.corner_radius_bottom_left = 10
	else:
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_right = 10
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
	for state: StringName in [
		&"normal",
		&"hover",
		&"pressed",
		&"hover_pressed",
		&"focus",
		&"disabled",
	]:
		button.add_theme_stylebox_override(
			state,
			_flat_chat_button_style(CHAT_SURFACE_COLOR),
		)


func _speech_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(UtilityPageStyle.OCEAN_PANEL_MID, 0.96)
	style.set_border_width_all(0)
	style.set_corner_radius_all(12)
	style.anti_aliasing = false
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _create_speech_pointer() -> Polygon2D:
	var pointer := Polygon2D.new()
	pointer.name = "SpeechPointer"
	pointer.polygon = PackedVector2Array([
		Vector2(-SPEECH_POINTER_HALF_WIDTH, 0.0),
		Vector2(SPEECH_POINTER_HALF_WIDTH, 0.0),
		Vector2(0.0, SPEECH_POINTER_HEIGHT),
	])
	pointer.color = Color(UtilityPageStyle.OCEAN_PANEL_MID, 0.96)
	pointer.antialiased = false
	pointer.z_index = -1
	return pointer


func _on_entry_text_submitted(_value: String) -> void:
	_last_submit_frame = Engine.get_process_frames()
	_send()


func _send() -> void:
	if _send_pending:
		return
	var body := _entry.text
	if body.strip_edges().is_empty():
		close_chat()
		return
	_send_pending = true
	_pending_send_body = NetworkChatProtocol.sanitize_body(body)
	_entry.editable = false
	if not _service.send_local_message(
		body,
		_player.get_animalese_voice_id(),
		_player.get_animalese_sample_set_id(),
	):
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
	_show_speech_bubble(
		peer_id,
		str(message["body"]),
		str(message.get("sender_fingerprint", "")),
		VoiceProfilesType.sanitized_id(str(message.get(
			"voice_id", VoiceProfilesType.DEFAULT_ID
		))),
		VoiceProfilesType.sanitized_sample_set_id(str(message.get(
			"sample_set_id", VoiceProfilesType.DEFAULT_SAMPLE_SET_ID
		))),
	)


func show_local_speech(body: String) -> void:
	if body.strip_edges().is_empty() or _session == null:
		return
	_show_speech_bubble(_session.get_local_peer_id(), body, "")


func _show_speech_bubble(
	peer_id: int,
	body: String,
	fingerprint: String,
	requested_voice_profile_id: String = "",
	requested_sample_set_id: String = "",
) -> void:
	_on_peer_removed(peer_id)
	var bubble := PanelContainer.new()
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.custom_minimum_size = Vector2(SPEECH_BUBBLE_WIDTH, 0.0)
	bubble.add_theme_stylebox_override("panel", _speech_panel_style())
	var pointer := _create_speech_pointer()
	bubble.add_child(pointer)
	var label := Label.new()
	label.text = body
	label.custom_minimum_size = Vector2(
		SPEECH_BUBBLE_WIDTH - 20.0,
		0.0,
	)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
	label.add_theme_color_override(
		"font_color", UtilityPageStyle.OCEAN_TEXT_PRIMARY
	)
	bubble.add_child(label)
	_speech_layer.add_child(bubble)
	var reveal_seconds := TypewriterRevealType.start(label)
	var voice_profile_id: String = VoiceProfilesType.DEFAULT_ID
	var sample_set_id: String = VoiceProfilesType.DEFAULT_SAMPLE_SET_ID
	var speaker_avatar := _spawn.get_avatar(peer_id)
	if not requested_voice_profile_id.is_empty():
		voice_profile_id = VoiceProfilesType.sanitized_id(
			requested_voice_profile_id
		)
	elif speaker_avatar != null:
		voice_profile_id = VoiceProfilesType.sanitized_id(
			speaker_avatar.get_animalese_voice_id()
		)
	if not requested_sample_set_id.is_empty():
		sample_set_id = VoiceProfilesType.sanitized_sample_set_id(
			requested_sample_set_id
		)
	elif speaker_avatar != null:
		sample_set_id = VoiceProfilesType.sanitized_sample_set_id(
			speaker_avatar.get_animalese_sample_set_id()
		)
	var voice_volume_offset_db := _get_voice_volume_offset_db(speaker_avatar)
	if voice_volume_offset_db > ANIMALESE_SILENT_VOLUME_DB:
		_animalese_voice.speak_text(
			_animalese_voice,
			label.text,
			str(peer_id),
			voice_profile_id,
			-1.0,
			sample_set_id,
			voice_volume_offset_db,
		)
	_speech[peer_id] = {
		"bubble": bubble,
		"pointer": pointer,
		"expires": (
			Time.get_ticks_msec() / 1000.0
			+ reveal_seconds
			+ SPEECH_SECONDS
		),
		"fingerprint": fingerprint,
	}


func _get_voice_volume_offset_db(speaker_avatar: Player) -> float:
	if speaker_avatar == null or _player == null:
		return ANIMALESE_SILENT_VOLUME_DB
	return animalese_volume_offset_db_for_distance(
		speaker_avatar.global_position.distance_to(_player.global_position)
	)


static func animalese_volume_offset_db_for_distance(distance: float) -> float:
	if not is_finite(distance) or distance >= ANIMALESE_SILENT_DISTANCE:
		return ANIMALESE_SILENT_VOLUME_DB
	if distance <= ANIMALESE_FULL_VOLUME_DISTANCE:
		return 0.0
	var distance_weight := inverse_lerp(
		ANIMALESE_FULL_VOLUME_DISTANCE,
		ANIMALESE_SILENT_DISTANCE,
		distance,
	)
	var amplitude := pow(1.0 - distance_weight, 2.0)
	return maxf(linear_to_db(amplitude), ANIMALESE_SILENT_VOLUME_DB)


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
	else:
		call_deferred("_focus_entry_after_open")


func _refresh_history() -> void:
	if _service == null:
		return
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
	_scroll_history_to_bottom.call_deferred()


func _refresh_visibility() -> void:
	if not _available:
		_panel.hide()
		_clock_panel.hide()
		_calendar_panel.hide()
		_weather_icon.hide()
		_status_effect_column.hide()
		_collapse_button.hide()
		_height_button.hide()
		_unread_indicator.hide()
		_hint.hide()
		return
	if _hud_hidden and not _opened:
		_panel.hide()
		_clock_panel.hide()
		_calendar_panel.hide()
		_weather_icon.hide()
		_status_effect_column.hide()
		_collapse_button.hide()
		_height_button.hide()
		_unread_indicator.hide()
		_hint.hide()
		return
	_clock_panel.show()
	_calendar_panel.visible = not _calendar_label.text.is_empty()
	_weather_icon.show()
	_collapse_button.show()
	var collapsed := _presentation_state == PresentationState.COLLAPSED
	_panel.show()
	_collapse_button.focus_mode = (
		Control.FOCUS_ALL if _opened else Control.FOCUS_NONE
	)
	_height_button.visible = not _mobile_mode
	_height_button.focus_mode = (
		Control.FOCUS_ALL
		if _opened and not _mobile_mode
		else Control.FOCUS_NONE
	)
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
	_apply_flat_chat_button(_collapse_button)
	_apply_flat_chat_button(_height_button)
	_refresh_handle_labels(_presentation_state)
	_layout_presentation(false)


func is_docked_right() -> bool:
	return _dock_right


func set_mobile_mode(enabled: bool) -> void:
	_mobile_mode = enabled
	if not is_node_ready() or _panel == null:
		return
	if _mobile_mode:
		if _presentation_state == PresentationState.EXPANDED:
			_presentation_state = PresentationState.COMPACT
		if _visible_state_before_collapse == PresentationState.EXPANDED:
			_visible_state_before_collapse = PresentationState.COMPACT
	_panel.add_theme_stylebox_override("panel", _chat_panel_style())
	_refresh_handle_labels(_presentation_state)
	_refresh_visibility()
	_layout_presentation(false)


func is_mobile_mode() -> bool:
	return _mobile_mode


func set_hud_hidden(hidden: bool) -> void:
	_hud_hidden = hidden
	_refresh_visibility()


func is_hud_hidden() -> bool:
	return _hud_hidden


func set_world_speech_visible(should_be_visible: bool) -> void:
	_world_speech_visible = should_be_visible
	if _speech_layer != null:
		_speech_layer.visible = should_be_visible


func is_world_speech_visible() -> bool:
	return _world_speech_visible


func _refresh_handle_labels(state: PresentationState) -> void:
	var collapsed := state == PresentationState.COLLAPSED
	var height_state := _visible_state_before_collapse if collapsed else state
	_collapse_button.text = ""
	_collapse_button.icon = CHAT_SHOW_ICON if collapsed else CHAT_HIDE_ICON
	_collapse_button.tooltip_text = (
		"Show chat" if collapsed else "Hide chat"
	)
	_collapse_button.accessibility_name = _collapse_button.tooltip_text
	_height_button.text = ""
	_height_button.icon = (
		CHAT_COMPACT_ICON
		if height_state == PresentationState.EXPANDED
		else CHAT_EXPAND_ICON
	)
	_height_button.tooltip_text = (
		"Compact chat"
		if height_state == PresentationState.EXPANDED
		else "Expand chat history"
	)
	_height_button.accessibility_name = _height_button.tooltip_text


func _update_panel_opacity(immediate_recheck: bool = false) -> void:
	if _panel == null or not _available:
		return
	if _presentation_state == PresentationState.COLLAPSED:
		if _height_tween == null or not _height_tween.is_running():
			_panel.modulate.a = IDLE_ALPHA
			_collapse_button.modulate.a = IDLE_ALPHA
			_height_button.modulate.a = IDLE_ALPHA
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
		if _is_speech_world_occluded(camera, avatar, world_position):
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
			bubble.size.x * 0.5,
			bubble.size.y + SPEECH_POINTER_HEIGHT,
		)
		bubble.position = Vector2(
			clampf(desired.x, 8.0, viewport_size.x - bubble.size.x - 8.0),
			clampf(
				desired.y,
				8.0,
				viewport_size.y
				- bubble.size.y
				- SPEECH_POINTER_HEIGHT
				- 8.0,
			),
		)
		var pointer := state.get("pointer") as Polygon2D
		if pointer != null:
			pointer.position = Vector2(
				clampf(
					screen_position.x - bubble.position.x,
					SPEECH_POINTER_HALF_WIDTH + 12.0,
					bubble.size.x - SPEECH_POINTER_HALF_WIDTH - 12.0,
				),
				bubble.size.y - SPEECH_POINTER_OVERLAP,
			)
		bubble.show()


func _is_speech_world_occluded(
	camera: Camera3D,
	speaker: Player,
	world_position: Vector3,
) -> bool:
	var world := camera.get_world_3d()
	if world == null:
		return false
	var excluded: Array[RID] = []
	if _player != null:
		excluded.append(_player.get_rid())
	if speaker != _player:
		excluded.append(speaker.get_rid())
	var query := PhysicsRayQueryParameters3D.create(
		camera.global_position,
		world_position,
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	for _attempt: int in range(8):
		query.exclude = excluded
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if hit.is_empty():
			return false
		var collider := hit.get("collider") as CollisionObject3D
		if collider is Player:
			excluded.append(collider.get_rid())
			continue
		return true
	return false


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
	var layout_state := (
		_visible_state_before_collapse
		if _presentation_state == PresentationState.COLLAPSED
		else _presentation_state
	)
	var collapsed := _presentation_state == PresentationState.COLLAPSED
	var bottom_margin := minf(
		BOTTOM_MARGIN,
		maxf(MIN_TOP_MARGIN, (viewport_height - MIN_HISTORY_HEIGHT) * 0.25),
	)
	var bottom := viewport_height - bottom_margin
	var height := COMPACT_HEIGHT
	var panel_width := PANEL_WIDTH
	var panel_x: float = 0.0
	var panel_y: float = 0.0
	var collapse_position := Vector2.ZERO
	var height_position := Vector2.ZERO
	var unread_position := Vector2.ZERO
	if _mobile_mode:
		panel_width = (
			MOBILE_EXPANDED_WIDTH
			if layout_state == PresentationState.EXPANDED
			else MOBILE_COMPACT_WIDTH
		)
		panel_width = minf(
			panel_width,
			maxf(1.0, viewport_width - MOBILE_EDGE_MARGIN * 2.0),
		)
		height = (
			MOBILE_EXPANDED_HEIGHT
			if layout_state == PresentationState.EXPANDED
			else MOBILE_COMPACT_HEIGHT
		)
		height = minf(
			height,
			maxf(MIN_HISTORY_HEIGHT, viewport_height - HANDLE_SIZE.y),
		)
		panel_x = (viewport_width - panel_width) * 0.5
		panel_y = -(height - COLLAPSED_REVEAL_WIDTH) if collapsed else 0.0
		var mobile_handle_y: float = (
			COLLAPSED_REVEAL_WIDTH if collapsed else height
		)
		collapse_position = Vector2(
			panel_x + panel_width - HANDLE_SIZE.x,
			mobile_handle_y,
		)
		height_position = Vector2(
			collapse_position.x - HANDLE_SIZE.x - HANDLE_GAP,
			mobile_handle_y,
		)
		unread_position = collapse_position + Vector2(6.0, -18.0)
	else:
		if layout_state == PresentationState.EXPANDED:
			height = maxf(
				MIN_HISTORY_HEIGHT,
				viewport_height - bottom_margin - EXPANDED_TOP_MARGIN,
			)
		height = minf(
			height,
			maxf(MIN_HISTORY_HEIGHT, bottom - MIN_TOP_MARGIN),
		)
		if _dock_right:
			panel_x = (
				viewport_width - COLLAPSED_REVEAL_WIDTH
				if collapsed
				else viewport_width - PANEL_WIDTH
			)
		else:
			panel_x = (
				-(PANEL_WIDTH - COLLAPSED_REVEAL_WIDTH)
				if collapsed
				else 0.0
			)
		panel_y = bottom - height
		var handle_stack_top := panel_y + HANDLE_TOP_INSET
		var handle_x: float = (
			panel_x - HANDLE_SIZE.x
			if _dock_right
			else COLLAPSED_REVEAL_WIDTH if collapsed else PANEL_WIDTH
		)
		collapse_position = Vector2(
			handle_x,
			handle_stack_top + HANDLE_SIZE.y + HANDLE_GAP,
		)
		height_position = Vector2(handle_x, handle_stack_top)
		var unread_offset_x := -18.0 if _dock_right else 6.0
		unread_position = collapse_position + Vector2(
			unread_offset_x,
			-18.0,
		)
	var target_position := Vector2(panel_x, panel_y)
	var target_size := Vector2(panel_width, height)
	var clock_x: float = (
		viewport_width - CLOCK_SIZE.x - CLOCK_EDGE_MARGIN
		if _dock_right else CLOCK_EDGE_MARGIN
	)
	var clock_position := Vector2(
		clock_x,
		CLOCK_EDGE_MARGIN,
	)
	var status_effect_column_position := Vector2(
		clock_position.x
		+ (CLOCK_SIZE.x - STATUS_EFFECT_ICON_SIZE.x) * 0.5,
		clock_position.y + CLOCK_SIZE.y + STATUS_EFFECT_TOP_GAP,
	)
	var weather_icon_x: float = (
		clock_position.x - WEATHER_ICON_GAP - WEATHER_ICON_SIZE.x
		if _dock_right
		else clock_position.x + CLOCK_SIZE.x + WEATHER_ICON_GAP
	)
	var weather_icon_position := Vector2(
		weather_icon_x, clock_position.y
	)
	var calendar_position := Vector2(
		minf(clock_position.x, weather_icon_position.x),
		clock_position.y + CLOCK_SIZE.y + CALENDAR_TOP_GAP,
	)
	status_effect_column_position = Vector2(
		calendar_position.x
		+ (CALENDAR_SIZE.x - STATUS_EFFECT_ICON_SIZE.x) * 0.5,
		calendar_position.y
		+ CALENDAR_SIZE.y
		+ STATUS_EFFECT_TOP_GAP,
	)
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
		_clock_panel.position = clock_position
		_clock_panel.size = CLOCK_SIZE
		_calendar_panel.position = calendar_position
		_calendar_panel.size = CALENDAR_SIZE
		_status_effect_column.position = status_effect_column_position
		_weather_icon.position = weather_icon_position
		_weather_icon.size = WEATHER_ICON_SIZE
		_collapse_button.position = collapse_position
		_height_button.position = height_position
		_unread_indicator.position = unread_position
		_hint.position = hint_position
		_configure_controller_focus()
		return
	_height_tween = create_tween().set_parallel(true)
	_height_tween.tween_property(
		_panel, "position", target_position, UIMotion.CHAT_RESIZE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_height_tween.tween_property(
		_panel, "size", target_size, UIMotion.CHAT_RESIZE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_height_tween.tween_property(
		_clock_panel,
		"position",
		clock_position,
		UIMotion.CHAT_RESIZE_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_height_tween.tween_property(
		_calendar_panel,
		"position",
		calendar_position,
		UIMotion.CHAT_RESIZE_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_height_tween.tween_property(
		_status_effect_column,
		"position",
		status_effect_column_position,
		UIMotion.CHAT_RESIZE_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_height_tween.tween_property(
		_weather_icon,
		"position",
		weather_icon_position,
		UIMotion.CHAT_RESIZE_DURATION,
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
		_scroll_history_to_bottom()
		_configure_controller_focus()
	)
	_hint.position = hint_position


func _configure_controller_focus() -> void:
	if _entry == null or _collapse_button == null or _height_button == null:
		return
	for button: Button in [_collapse_button, _height_button]:
		button.focus_mode = (
			Control.FOCUS_ALL if _opened else Control.FOCUS_NONE
		)
	if not _opened:
		return
	_entry.focus_mode = Control.FOCUS_ALL
	if _mobile_mode:
		_set_controller_neighbors(
			_entry, _entry, _entry, _entry, _height_button
		)
		_set_controller_neighbors(
			_height_button,
			_height_button,
			_collapse_button,
			_entry,
			_height_button,
		)
		_set_controller_neighbors(
			_collapse_button,
			_height_button,
			_collapse_button,
			_entry,
			_collapse_button,
		)
		return
	var panel_side: Control = _entry
	if _dock_right:
		_set_controller_neighbors(
			_entry, _collapse_button, _entry, _entry, _entry
		)
		_set_controller_neighbors(
			_collapse_button,
			_collapse_button,
			panel_side,
			_height_button,
			_collapse_button,
		)
		_set_controller_neighbors(
			_height_button,
			_height_button,
			panel_side,
			_height_button,
			_collapse_button,
		)
	else:
		_set_controller_neighbors(
			_entry, _entry, _collapse_button, _entry, _entry
		)
		_set_controller_neighbors(
			_collapse_button,
			panel_side,
			_collapse_button,
			_height_button,
			_collapse_button,
		)
		_set_controller_neighbors(
			_height_button,
			panel_side,
			_height_button,
			_height_button,
			_collapse_button,
		)


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


func _scroll_history_to_bottom() -> void:
	if _history == null:
		return
	var scroll := _history.get_v_scroll_bar()
	if scroll == null:
		return
	scroll.value = maxf(scroll.min_value, scroll.max_value - scroll.page)


func _on_viewport_resized() -> void:
	_layout_presentation(false)


func _on_world_time_changed(
	_time_hours: float,
	_phase: WorldTimeService.Phase,
) -> void:
	if _clock_label != null and _world_time != null:
		_clock_label.text = _world_time.get_clock_text()
	if _weather_icon != null and _world_time != null:
		_weather_icon.set_nighttime(_world_time.is_night_period())


func _on_world_calendar_date_changed(_date_id: String) -> void:
	if _calendar_label == null or _world_time == null:
		return
	_calendar_label.text = _world_time.get_calendar_text()
	_calendar_panel.visible = (
		_available
		and (not _hud_hidden or _opened)
		and not _calendar_label.text.is_empty()
	)


func _on_world_weather_changed(
	weather: WorldWeatherService.Weather,
	_seconds_remaining: float,
) -> void:
	if _weather_icon != null:
		_weather_icon.set_weather(weather)


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
