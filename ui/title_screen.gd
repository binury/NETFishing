class_name TitleScreen
extends Control

const SaveInspectionType = preload("res://save/player_save_inspection.gd")
const SaveManagerType = preload("res://save/player_save_manager.gd")
const SettingsManagerType = preload(
	"res://settings/player_settings_manager.gd"
)
const SettingsPanelType = preload("res://ui/settings_panel.gd")
const BubbleButtonType = preload(
	"res://ui/components/bubble_menu/bubble_button.gd"
)
const BubbleClusterType = preload(
	"res://ui/components/bubble_menu/bubble_cluster.gd"
)
const TitleConfirmationBubblePageType = preload(
	"res://ui/title_confirmation_bubble_page.gd"
)
const NetworkSessionType = preload("res://network/network_session.gd")
const SavedServerStoreType = preload("res://network/saved_server_store.gd")
const JoinGamePageType = preload("res://ui/network/join_game_page.gd")
const DECORATIVE_FISH_TEXTURES: Array[Texture2D] = [
	preload("res://fish/species/bass/fish_bass_striped.png"),
	preload("res://fish/species/bluegill/fish_bluegill.png"),
	preload("res://fish/species/carp/fish_carp_common.png"),
	preload("res://fish/species/sunfish/fish_sunfish.png"),
]
const DECORATIVE_BUBBLE_TEXTURES: Array[Texture2D] = [
	preload("res://ui/assets/title/bubbles/bubble1.png"),
	preload("res://ui/assets/title/bubbles/bubble2.png"),
	preload("res://ui/assets/title/bubbles/bubble3.png"),
]

const FIRST_FISH_DELAY_MIN: float = 2.0
const FIRST_FISH_DELAY_MAX: float = 5.0
const NEXT_FISH_DELAY_MIN: float = 5.0
const NEXT_FISH_DELAY_MAX: float = 12.0
const CROSSING_DURATION_MIN: float = 8.0
const CROSSING_DURATION_MAX: float = 16.0
const FISH_LONGEST_SIDE_MIN: float = 120.0
const FISH_LONGEST_SIDE_MAX: float = 210.0
const FISH_EDGE_MARGIN: float = 24.0
const BUBBLE_EVENT_DELAY_MIN: float = 4.0
const BUBBLE_EVENT_DELAY_MAX: float = 10.0
const BUBBLE_CLUSTER_DELAY_MIN: float = 0.25
const BUBBLE_CLUSTER_DELAY_MAX: float = 0.65
const BUBBLE_TRAVEL_DURATION_MIN: float = 7.0
const BUBBLE_TRAVEL_DURATION_MAX: float = 14.0
const BUBBLE_SCALE_MIN: float = 0.65
const BUBBLE_SCALE_MAX: float = 1.15
const BUBBLE_OPACITY_MIN: float = 0.55
const BUBBLE_OPACITY_MAX: float = 0.90
const BUBBLE_DRIFT_MIN: float = 10.0
const BUBBLE_DRIFT_MAX: float = 45.0
const BUBBLE_WOBBLE_MIN: float = 3.0
const BUBBLE_WOBBLE_MAX: float = 9.0
const BUBBLE_EDGE_MARGIN: float = 16.0
const MAX_DECORATIVE_BUBBLES: int = 6
const TRANSITION_BUBBLE_COUNT_MIN: int = 4
const TRANSITION_BUBBLE_COUNT_MAX: int = 5
const MAX_TRANSITION_BUBBLES: int = 30
const TRANSITION_BUBBLE_X_MIN: float = 0.36
const TRANSITION_BUBBLE_X_MAX: float = 0.64
const TRANSITION_BUBBLE_Y_MIN: float = 0.60
const TRANSITION_BUBBLE_Y_MAX: float = 0.78
const LOGO_ASPECT_RATIO: float = 2560.0 / 760.0
const LOGO_WIDTH_FACTOR: float = 0.4784
const LOGO_MIN_WIDTH: float = 294.0
const LOGO_MAX_WIDTH: float = 662.0
const TITLE_HORIZONTAL_MARGIN: float = 48.0
const TITLE_DESKTOP_REFERENCE_SIZE: Vector2 = Vector2(1280.0, 720.0)
const TITLE_COMPACT_REFERENCE_SIZE: Vector2 = Vector2(640.0, 480.0)
const BUBBLE_FIELD_MAX_WIDTH: float = 396.0
const BUBBLE_FIELD_DESKTOP_HEIGHT: float = 318.0
const BUBBLE_FIELD_COMPACT_WIDTH: float = 294.0
const BUBBLE_FIELD_COMPACT_HEIGHT: float = 200.0
const BUBBLE_COMPACT_HEIGHT_THRESHOLD: float = 560.0
const START_PROMPT_MIN_SCALE: float = 0.985
const START_PROMPT_MAX_SCALE: float = 1.015
const START_PROMPT_CYCLE_SECONDS: float = 3.0
const DISABLED_BUBBLE_LABEL_ALPHA: float = 0.55
const INTRO_PROMPT_FADE_DURATION: float = 0.55
const INTRO_BUBBLE_TRAVEL_DURATION: float = 2.40
const INTRO_BRANDING_TRAVEL_DURATION: float = 2.0
const INTRO_BRANDING_START_DELAY: float = 0.35
const HOST_CLUSTER_SAFE_MARGIN: float = 24.0

signal new_game_requested
signal continue_game_requested
signal quit_requested
signal join_game_requested(endpoint: String)

enum ConfirmationAction {
	NONE,
	NEW_GAME,
	DELETE_SAVE,
}

@onready var _continue_button: BubbleButtonType = %ContinueButton
@onready var _new_game_button: BubbleButtonType = %NewGameButton
@onready var _settings_button: BubbleButtonType = %SettingsButton
@onready var _delete_button: BubbleButtonType = %DeleteSaveButton
@onready var _quit_button: BubbleButtonType = %QuitButton
@onready var _join_game_button: BubbleButtonType = %JoinGameButton
@onready var _new_game_label: Label = %NewGameLabel
@onready var _delete_save_label: Label = %DeleteSaveLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _confirmation_page: TitleConfirmationBubblePageType = (
	%ConfirmationPage
)
@onready var _settings_panel: SettingsPanelType = %SettingsPanel
@onready var _title_presentation_scale_root: Control = (
	%TitlePresentationScaleRoot
)
@onready var _background: ColorRect = %Background
@onready var _decorative_fish_layer: Control = %DecorativeFishLayer
@onready var _decorative_fish_timer: Timer = %DecorativeFishTimer
@onready var _decorative_bubble_layer: Control = %DecorativeBubbleLayer
@onready var _decorative_bubble_event_timer: Timer = %DecorativeBubbleEventTimer
@onready var _decorative_bubble_cluster_timer: Timer = %DecorativeBubbleClusterTimer
@onready var _title_logo: TextureRect = %TitleLogo
@onready var _playtest_label: Label = %PlaytestLabel
@onready var _intro_branding_anchor: Control = %IntroBrandingAnchor
@onready var _presentation_center: CenterContainer = %Center
@onready var _main_content: VBoxContainer = %MainContent
@onready var _branding_slot: Control = %BrandingSlot
@onready var _branding_motion_root: Control = %BrandingMotionRoot
@onready var _version_row: Control = %VersionRow
@onready var _title_spacer: Control = %Spacer
@onready var _button_center: CenterContainer = %ButtonCenter
@onready var _bubble_layout_slot: Control = %BubbleLayoutSlot
@onready var _bubble_motion_root: Control = %BubbleMotionRoot
@onready var _bubble_field: BubbleClusterType = %BubbleField
@onready var _start_prompt_center: CenterContainer = %StartPromptCenter
@onready var _start_prompt_label: Label = %StartPromptLabel
@onready var _join_game_page: JoinGamePageType = %JoinGamePage

var _save_manager: SaveManagerType
var _settings_manager: SettingsManagerType
var _inspection: SaveInspectionType
var _confirmation_action: ConfirmationAction = ConfirmationAction.NONE
var _action_in_progress: bool = false
var _decorative_rng := RandomNumberGenerator.new()
var _decorative_fish: TextureRect
var _decorative_fish_tween: Tween
var _decorative_presentation_ready: bool = false
var _decorative_presentation_active: bool = false
var _decorative_generation: int = 0
var _decorative_bubbles: Array[TextureRect] = []
var _decorative_bubble_tweens: Dictionary[int, Tween] = {}
var _transition_bubble_ids: Dictionary[int, bool] = {}
var _pending_cluster_bubbles: int = 0
var _awaiting_start_input: bool = false
var _start_prompt_elapsed: float = 0.0
var _navigation_focus_active: bool = false
var _modal_restore_navigation_focus: bool = false
var _world_pixel_size: int = PlayerSettings.DEFAULT_WORLD_PIXEL_SIZE
var _title_settings_transition: Tween
var _title_settings_transition_generation: int = 0
var _title_settings_transition_active: bool = false
var _title_bubble_rest_position: Vector2 = Vector2.ZERO
var _title_content_rest_position: Vector2 = Vector2.ZERO
var _title_entry_transition: Tween
var _title_entry_generation: int = 0
var _title_entry_transition_active: bool = false
var _intro_geometry_ready: bool = false
var _intro_layout_generation: int = 0
var _branding_intro_position: Vector2 = Vector2.ZERO
var _bubble_intro_position: Vector2 = Vector2.ZERO
var _feedback_visible_before_settings: bool = false
var _feedback_text_before_settings: String = ""
var _continue_stats_hovered: bool = false
var _continue_stats_focused: bool = false
var _continue_stats_fade: Tween
var _confirmation_transition: Tween
var _confirmation_transition_generation: int = 0
var _confirmation_transition_active: bool = false
var _confirmation_title_content_rest_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_continue_button.mouse_entered.connect(
		_on_continue_stats_hover_changed.bind(true)
	)
	_continue_button.mouse_exited.connect(
		_on_continue_stats_hover_changed.bind(false)
	)
	_continue_button.focus_entered.connect(
		_on_continue_stats_focus_changed.bind(true)
	)
	_continue_button.focus_exited.connect(
		_on_continue_stats_focus_changed.bind(false)
	)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_join_game_button.pressed.connect(_open_join_game)
	_settings_button.pressed.connect(_open_settings)
	_delete_button.pressed.connect(_on_delete_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	_confirmation_page.confirmed.connect(_on_confirmation_accepted)
	_confirmation_page.cancelled.connect(_request_close_confirmation)
	_settings_panel.applied.connect(_on_settings_applied)
	_settings_panel.closed.connect(_on_settings_closed)
	_settings_panel.closing.connect(_on_settings_closing)
	_settings_panel.opened.connect(_on_settings_opened)
	_settings_panel.navigation_transition_started.connect(
		_emit_navigation_bubble_flurry
	)
	_bubble_field.configure(_get_title_buttons())
	_decorative_fish_timer.timeout.connect(_on_decorative_fish_timer_timeout)
	_decorative_bubble_event_timer.timeout.connect(
		_on_decorative_bubble_event_timer_timeout
	)
	_decorative_bubble_cluster_timer.timeout.connect(
		_on_decorative_bubble_cluster_timer_timeout
	)
	visibility_changed.connect(_on_title_visibility_changed)
	resized.connect(_update_responsive_title_stage)
	_start_prompt_label.resized.connect(_update_start_prompt_pivot)
	_decorative_rng.randomize()
	set_process(false)
	call_deferred("_update_responsive_title_stage")
	call_deferred("_update_start_prompt_pivot")
	call_deferred("_capture_title_bubble_rest_position")
	call_deferred("_capture_title_content_rest_position")


func setup(
	save_manager: SaveManagerType,
	settings_manager: SettingsManagerType,
	network_session: NetworkSessionType,
	saved_servers: SavedServerStoreType,
	server_trust: ServerTrustStore,
) -> void:
	_save_manager = save_manager
	_settings_manager = settings_manager
	_join_game_page.setup(network_session, saved_servers, false, server_trust)
	_join_game_page.join_requested.connect(join_game_requested.emit)
	_join_game_page.back_requested.connect(_close_join_game)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_save_inspection()
	show()
	_decorative_presentation_ready = true
	_start_decorative_presentation()
	_begin_title_entry()


func reopen() -> void:
	_cancel_title_entry_transition()
	_cancel_title_settings_transition()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_prepare_awaiting_start_input()
	_reset_confirmation()
	_settings_panel.hide()
	_join_game_page.close_page()
	_refresh_save_inspection()
	show()
	_start_decorative_presentation()
	_start_entry_prompt_animation()


func open_join_game_page(endpoint: String = "") -> void:
	_cancel_title_entry_transition()
	_awaiting_start_input = false
	_start_prompt_center.hide()
	_presentation_center.hide()
	_settings_panel.hide()
	_confirmation_page.hide_page()
	_join_game_page.open_page(endpoint)


func report_network_error(message: String) -> void:
	_join_game_page.set_status(message)
	if not _join_game_page.visible:
		_feedback_label.text = message
		_feedback_label.show()
		_feedback_label.modulate.a = 1.0


func _open_join_game() -> void:
	if _action_in_progress or _is_confirmation_active():
		return
	open_join_game_page()


func _close_join_game() -> void:
	_join_game_page.close_page()
	_presentation_center.show()
	_button_center.show()
	_start_prompt_center.hide()
	_focus_initial_button()


func is_awaiting_start_input() -> bool:
	return _awaiting_start_input


func is_decorative_presentation_active() -> bool:
	return _decorative_presentation_active


func get_active_decorative_fish_count() -> int:
	return 1 if is_instance_valid(_decorative_fish) else 0


func get_active_decorative_bubble_count() -> int:
	return _decorative_bubbles.size()


func is_decorative_bubble_scheduler_active() -> bool:
	return (
		_decorative_presentation_active
		and (
			not _decorative_bubble_event_timer.is_stopped()
			or not _decorative_bubble_cluster_timer.is_stopped()
		)
	)


func _update_title_layout() -> void:
	if not is_node_ready():
		return
	var layout_size: Vector2 = _title_presentation_scale_root.size
	var available_width: float = maxf(
		1.0,
		layout_size.x - TITLE_HORIZONTAL_MARGIN
	)
	var logo_width: float = minf(
		clampf(
			layout_size.x * LOGO_WIDTH_FACTOR,
			LOGO_MIN_WIDTH,
			LOGO_MAX_WIDTH
		),
		available_width
	)
	_title_logo.custom_minimum_size = Vector2(
		logo_width,
		logo_width / LOGO_ASPECT_RATIO
	)
	var branding_separation: float = float(
		_main_content.get_theme_constant("separation")
	)
	var branding_size := Vector2(
		logo_width,
		logo_width / LOGO_ASPECT_RATIO
		+ branding_separation
		+ _version_row.get_combined_minimum_size().y
	)
	_branding_slot.custom_minimum_size = branding_size
	_branding_motion_root.size = branding_size
	var field_width: float = minf(BUBBLE_FIELD_MAX_WIDTH, available_width)
	var field_height: float = (
		BUBBLE_FIELD_COMPACT_HEIGHT
		if layout_size.y < BUBBLE_COMPACT_HEIGHT_THRESHOLD
		else BUBBLE_FIELD_DESKTOP_HEIGHT
	)
	if layout_size.y < BUBBLE_COMPACT_HEIGHT_THRESHOLD:
		field_width = minf(BUBBLE_FIELD_COMPACT_WIDTH, available_width)
	_bubble_layout_slot.custom_minimum_size = Vector2(field_width, field_height)
	_bubble_motion_root.size = Vector2(field_width, field_height)
	_bubble_field.custom_minimum_size = Vector2(field_width, field_height)
	var compact_layout: bool = field_height == BUBBLE_FIELD_COMPACT_HEIGHT
	_bubble_field.apply_layout(
		Vector2(field_width, field_height),
		compact_layout
	)
	if not _title_settings_transition_active:
		call_deferred("_capture_title_bubble_rest_position")
	_new_game_label.text = "new\ngame" if compact_layout else "new game"
	_delete_save_label.text = (
		"delete\nsave" if compact_layout else "delete save"
	)
	if _awaiting_start_input and not _title_entry_transition_active:
		_schedule_intro_presentation()
	_update_world_preview_resolution()


func _update_responsive_title_stage() -> void:
	if not is_node_ready():
		return
	_title_presentation_scale_root.size = TITLE_DESKTOP_REFERENCE_SIZE
	_title_presentation_scale_root.scale = Vector2.ONE
	_title_presentation_scale_root.position = Vector2.ZERO
	_update_title_layout()
	if (
		_is_confirmation_active()
		and not _confirmation_page.is_transitioning()
	):
		_set_confirmation_stage_rect()


func _get_title_buttons() -> Array[BubbleButton]:
	return [
		_continue_button,
		_new_game_button,
		_join_game_button,
		_settings_button,
		_delete_button,
		_quit_button,
	]


func set_world_pixelation(pixel_size: int) -> void:
	_world_pixel_size = clampi(
		pixel_size,
		PlayerSettings.MIN_WORLD_PIXEL_SIZE,
		PlayerSettings.MAX_WORLD_PIXEL_SIZE
	)
	if is_node_ready():
		_update_world_preview_resolution()


func _update_world_preview_resolution() -> void:
	var displayed_size := Vector2i(
		maxi(1, roundi(size.x)),
		maxi(1, roundi(size.y))
	)
	var grid_size: Vector2i = PlayerSettings.get_world_grid_size(
		_world_pixel_size,
		displayed_size
	)
	var shader_material := _background.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(
			"virtual_pixel_density",
			Vector2(grid_size)
		)
	var logo_material := _title_logo.material as ShaderMaterial
	if logo_material != null:
		var render_scale: float = (
			float(grid_size.y) / float(displayed_size.y)
		)
		var effect_scale: float = 1.0 / render_scale
		logo_material.set_shader_parameter(
			"horizontal_displacement_pixels",
			minf(2.0, 1.5 * effect_scale)
		)
		logo_material.set_shader_parameter(
			"bob_amount_pixels",
			minf(4.0, 3.0 * effect_scale)
		)


func _snap_world_preview(value: Vector2) -> Vector2:
	var displayed_size := Vector2i(
		maxi(1, roundi(size.x)),
		maxi(1, roundi(size.y))
	)
	var grid_size: Vector2i = PlayerSettings.get_world_grid_size(
		_world_pixel_size,
		displayed_size
	)
	var render_scale: float = float(grid_size.y) / float(displayed_size.y)
	var step: float = 1.0 / render_scale
	return Vector2(
		roundf(value.x / step) * step,
		roundf(value.y / step) * step
	)


func _process(delta: float) -> void:
	if not visible:
		return
	if _awaiting_start_input and _start_prompt_center.visible:
		_start_prompt_elapsed = fmod(
			_start_prompt_elapsed + delta,
			START_PROMPT_CYCLE_SECONDS
		)
		var phase: float = (
			_start_prompt_elapsed / START_PROMPT_CYCLE_SECONDS
		)
		var pulse_weight: float = (
			sin(phase * TAU - PI * 0.5) + 1.0
		) * 0.5
		var prompt_scale: float = lerpf(
			START_PROMPT_MIN_SCALE,
			START_PROMPT_MAX_SCALE,
			pulse_weight
		)
		_start_prompt_label.scale = Vector2.ONE * prompt_scale
	if _main_content.visible and _button_center.visible:
		_bubble_field.advance_motion(delta)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _join_game_page.visible:
		if event.is_action_pressed("ui_cancel"):
			_close_join_game()
			get_viewport().set_input_as_handled()
		return
	if (
		_title_settings_transition_active
		or _title_entry_transition_active
		or _confirmation_transition_active
	):
		get_viewport().set_input_as_handled()
		return
	if _awaiting_start_input:
		if not _is_start_prompt_reveal_event(event):
			return
		if not _intro_geometry_ready:
			get_viewport().set_input_as_handled()
			return
		_reveal_primary_menu()
		get_viewport().set_input_as_handled()
		return
	if _handle_primary_menu_focus_input(event):
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _is_confirmation_active():
		_request_close_confirmation()
	elif _settings_panel.visible:
		_settings_panel.handle_back()
	else:
		return
	get_viewport().set_input_as_handled()


func _is_start_prompt_reveal_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	return false


func _handle_primary_menu_focus_input(event: InputEvent) -> bool:
	if (
		not _button_center.visible
		or _is_confirmation_active()
		or _settings_panel.visible
	):
		return false
	if event is InputEventMouseMotion:
		_navigation_focus_active = false
		_release_primary_menu_focus()
		_update_continue_stats_visibility()
		return false
	if event is InputEventKey and (event as InputEventKey).echo:
		return false
	var moves_forward: bool = (
		event.is_action_pressed("ui_down")
		or event.is_action_pressed("ui_right")
	)
	var moves_backward: bool = (
		event.is_action_pressed("ui_up")
		or event.is_action_pressed("ui_left")
	)
	if not moves_forward and not moves_backward:
		return false
	_navigation_focus_active = true
	if _primary_menu_has_focus():
		return false
	if moves_forward:
		_get_first_available_menu_button().grab_focus()
	else:
		_quit_button.grab_focus()
	return true


func _get_first_available_menu_button() -> Button:
	return _continue_button if not _continue_button.disabled else _new_game_button


func _primary_menu_has_focus() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	return focus_owner != null and _button_center.is_ancestor_of(focus_owner)


func _release_primary_menu_focus() -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner != null and _button_center.is_ancestor_of(focus_owner):
		focus_owner.release_focus()


func _release_title_focus() -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()


func _begin_title_entry() -> void:
	_prepare_awaiting_start_input()
	_start_entry_prompt_animation()


func _prepare_awaiting_start_input() -> void:
	_cancel_title_entry_transition()
	_awaiting_start_input = true
	_intro_geometry_ready = false
	_navigation_focus_active = false
	_modal_restore_navigation_focus = false
	_button_center.show()
	_feedback_label.show()
	_feedback_label.modulate.a = 0.0
	_continue_stats_hovered = false
	_continue_stats_focused = false
	_cancel_continue_stats_fade()
	_main_content.show()
	_start_prompt_center.show()
	_start_prompt_center.modulate.a = 1.0
	_set_title_bubbles_interactive(false)
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()
	_schedule_intro_presentation()


func _start_entry_prompt_animation() -> void:
	_start_prompt_elapsed = 0.0
	_start_prompt_label.scale = Vector2.ONE * START_PROMPT_MIN_SCALE
	_update_start_prompt_pivot()
	set_process(true)


func _stop_entry_prompt_animation() -> void:
	set_process(visible and _button_center.visible)
	_start_prompt_elapsed = 0.0
	_start_prompt_label.scale = Vector2.ONE


func _update_start_prompt_pivot() -> void:
	if not is_node_ready():
		return
	_start_prompt_label.pivot_offset = _start_prompt_label.size * 0.5


func _reveal_primary_menu() -> void:
	if (
		not _awaiting_start_input
		or not _intro_geometry_ready
		or _title_entry_transition_active
	):
		return
	_awaiting_start_input = false
	_stop_entry_prompt_animation()
	_title_entry_generation += 1
	_title_entry_transition_active = true
	_set_title_bubbles_interactive(false)
	var generation: int = _title_entry_generation
	set_process(true)
	_navigation_focus_active = false
	_release_title_focus()
	_title_entry_transition = create_tween()
	_title_entry_transition.set_parallel(true)
	_title_entry_transition.tween_property(
		_start_prompt_center,
		"modulate:a",
		0.0,
		INTRO_PROMPT_FADE_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_title_entry_transition.tween_property(
		_bubble_motion_root,
		"position",
		Vector2.ZERO,
		INTRO_BUBBLE_TRAVEL_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_entry_transition.tween_property(
		_branding_motion_root,
		"position",
		Vector2.ZERO,
		INTRO_BRANDING_TRAVEL_DURATION
	).set_delay(INTRO_BRANDING_START_DELAY).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN_OUT)
	_title_entry_transition.finished.connect(
		_finish_primary_menu_reveal.bind(generation),
		CONNECT_ONE_SHOT
	)


func _finish_primary_menu_reveal(generation: int) -> void:
	if (
		generation != _title_entry_generation
		or not _title_entry_transition_active
	):
		return
	_title_entry_transition = null
	_title_entry_transition_active = false
	_start_prompt_center.hide()
	_start_prompt_center.modulate.a = 1.0
	_feedback_label.modulate.a = 0.0
	_set_title_bubbles_interactive(true)


func _cancel_title_entry_transition() -> void:
	_title_entry_generation += 1
	if _title_entry_transition != null:
		_title_entry_transition.kill()
		_title_entry_transition = null
	_title_entry_transition_active = false
	if is_node_ready():
		_start_prompt_center.modulate.a = 1.0


func _schedule_intro_presentation() -> void:
	_intro_layout_generation += 1
	_intro_geometry_ready = false
	call_deferred(
		"_prepare_intro_presentation",
		_intro_layout_generation
	)


func _prepare_intro_presentation(generation: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if (
		generation != _intro_layout_generation
		or not is_node_ready()
		or not _awaiting_start_input
		or _title_entry_transition_active
	):
		return
	_branding_motion_root.size = _branding_slot.size
	_bubble_motion_root.size = _bubble_layout_slot.size
	var intro_tail_height: float = (
		_title_spacer.get_combined_minimum_size().y
		+ float(_main_content.get_theme_constant("separation"))
	)
	var inverse_stage_transform: Transform2D = (
		_title_presentation_scale_root.get_global_transform().affine_inverse()
	)
	var branding_anchor_position: Vector2 = (
		inverse_stage_transform
		* _intro_branding_anchor.get_global_transform().origin
	)
	var branding_slot_position: Vector2 = (
		inverse_stage_transform
		* _branding_slot.get_global_transform().origin
	)
	var branding_target_position := Vector2(
		floorf(
			branding_anchor_position.x
			- _branding_motion_root.size.x * 0.5
		),
		floorf(
			branding_anchor_position.y
			- (_branding_motion_root.size.y + intro_tail_height) * 0.5
		)
	)
	_branding_intro_position = (
		branding_target_position
		- branding_slot_position
	)
	var bubble_bounds: Rect2 = _get_title_bubble_stage_bounds()
	bubble_bounds.position -= _bubble_motion_root.position
	var presentation_allowance: float = _get_bubble_offscreen_allowance()
	_bubble_intro_position = Vector2(
		0.0,
		_title_presentation_scale_root.size.y
		+ presentation_allowance
		- bubble_bounds.position.y
	)
	_branding_motion_root.position = _branding_intro_position
	_bubble_motion_root.position = _bubble_intro_position
	_title_content_rest_position = _presentation_center.position
	_title_bubble_rest_position = _bubble_field.position
	_intro_geometry_ready = true


func _get_title_bubble_stage_bounds() -> Rect2:
	var bubbles: Array[BubbleButton] = _get_title_buttons()
	var bounds: Rect2 = _get_title_stage_rect(bubbles[0])
	for index: int in range(1, bubbles.size()):
		bounds = bounds.merge(_get_title_stage_rect(bubbles[index]))
	return bounds


func _get_title_stage_rect(control: Control) -> Rect2:
	var inverse_stage_transform: Transform2D = (
		_title_presentation_scale_root.get_global_transform().affine_inverse()
	)
	var global_rect: Rect2 = control.get_global_rect()
	var local_position: Vector2 = (
		inverse_stage_transform * global_rect.position
	)
	var local_end: Vector2 = inverse_stage_transform * global_rect.end
	return Rect2(local_position, local_end - local_position)


func _get_bubble_offscreen_allowance() -> float:
	var maximum_vertical_amplitude: float = 0.0
	var maximum_deformation_growth: float = 0.0
	for bubble: BubbleButton in _get_title_buttons():
		maximum_vertical_amplitude = maxf(
			maximum_vertical_amplitude,
			bubble.vertical_amplitude
		)
		var maximum_scale: float = (
			1.0 + bubble.deformation_amplitude
		) * _bubble_field.profile.hover_focus_scale
		maximum_deformation_growth = maxf(
			maximum_deformation_growth,
			bubble.presented_size.y * (maximum_scale - 1.0) * 0.5
		)
	return (
		HOST_CLUSTER_SAFE_MARGIN
		+ maximum_vertical_amplitude
		+ maximum_deformation_growth
		+ _bubble_field.profile.hover_focus_lift
		+ _bubble_field.profile.maximum_separation
	)


func _on_continue_stats_hover_changed(hovered: bool) -> void:
	_continue_stats_hovered = hovered
	_update_continue_stats_visibility()


func _on_continue_stats_focus_changed(focused: bool) -> void:
	_continue_stats_focused = focused
	_update_continue_stats_visibility()


func _update_continue_stats_visibility() -> void:
	if not is_node_ready():
		return
	var requested_visible: bool = (
		_continue_stats_hovered
		or (
			_continue_stats_focused
			and _navigation_focus_active
		)
	)
	requested_visible = (
		requested_visible
		and not _continue_button.disabled
		and _inspection != null
		and _inspection.status == SaveInspectionType.Status.VALID_SUPPORTED
		and not _awaiting_start_input
		and not _title_entry_transition_active
		and not _title_settings_transition_active
		and not _settings_panel.visible
		and not _is_confirmation_active()
		and not _action_in_progress
		and _presentation_center.visible
	)
	if requested_visible:
		_feedback_label.text = _get_continue_stats_text()
	_fade_continue_stats_to(1.0 if requested_visible else 0.0)


func _hide_continue_stats_context() -> void:
	_continue_stats_hovered = false
	_continue_stats_focused = false
	_fade_continue_stats_to(0.0)


func _fade_continue_stats_to(target_opacity: float) -> void:
	if not is_node_ready():
		return
	_cancel_continue_stats_fade()
	if is_equal_approx(_feedback_label.modulate.a, target_opacity):
		_feedback_label.modulate.a = target_opacity
		return
	_continue_stats_fade = create_tween()
	_continue_stats_fade.tween_property(
		_feedback_label,
		"modulate:a",
		target_opacity,
		INTRO_PROMPT_FADE_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _cancel_continue_stats_fade() -> void:
	if _continue_stats_fade != null:
		_continue_stats_fade.kill()
		_continue_stats_fade = null


func _get_continue_stats_text() -> String:
	if (
		_inspection == null
		or _inspection.status != SaveInspectionType.Status.VALID_SUPPORTED
	):
		return ""
	return (
		"%d fish • $%d • %d discovered"
		% [
			_inspection.catch_count,
			_inspection.wallet_balance,
			_inspection.discovered_species_count,
		]
	)


func _on_continue_pressed() -> void:
	if (
		_action_in_progress
		or _is_confirmation_active()
		or _settings_panel.visible
		or _inspection == null
		or not _inspection.can_continue()
	):
		return
	_hide_continue_stats_context()
	_action_in_progress = true
	continue_game_requested.emit()
	_action_in_progress = false


func _on_new_game_pressed() -> void:
	if (
		_action_in_progress
		or _is_confirmation_active()
		or _settings_panel.visible
		or _inspection == null
	):
		return
	_hide_continue_stats_context()
	if _inspection.status == SaveInspectionType.Status.MISSING:
		new_game_requested.emit()
		return
	if _inspection.status == SaveInspectionType.Status.UNSUPPORTED_VERSION:
		_feedback_label.text = (
			"this save is from a newer game version. "
			+ "use delete save before starting over."
		)
		return
	if _inspection.status == SaveInspectionType.Status.IO_ERROR:
		_feedback_label.text = "the existing save cannot be accessed safely."
		return
	_open_confirmation(
		ConfirmationAction.NEW_GAME,
		"start a new game? existing progression will be deleted.",
		"start\nnew game",
		true
	)


func _on_delete_pressed() -> void:
	if (
		_action_in_progress
		or _is_confirmation_active()
		or _settings_panel.visible
		or _inspection == null
		or not _inspection.can_delete()
	):
		return
	_hide_continue_stats_context()
	_open_confirmation(
		ConfirmationAction.DELETE_SAVE,
		"delete your saved progression? this cannot be undone.",
		"delete"
	)


func _on_confirmation_accepted() -> void:
	if (
		_action_in_progress
		or _confirmation_transition_active
		or _confirmation_action == ConfirmationAction.NONE
	):
		return
	var action: ConfirmationAction = _confirmation_action
	_confirmation_page.lock_interaction()
	_action_in_progress = true
	if action == ConfirmationAction.NEW_GAME:
		_confirmation_action = ConfirmationAction.NONE
		_confirmation_transition_generation += 1
		_cancel_confirmation_transition()
		_confirmation_page.hide_page()
		new_game_requested.emit()
		_action_in_progress = false
		return
	if not _save_manager.delete_progression_save():
		_feedback_label.text = "failed to delete saved progression."
		_action_in_progress = false
		_refresh_save_inspection()
		_begin_confirmation_return()
		return
	_save_manager.initialize_new_game()
	_refresh_save_inspection()
	_feedback_label.text = "saved progression deleted."
	_begin_confirmation_return()
	_action_in_progress = false


func _open_confirmation(
	action: ConfirmationAction,
	message: String,
	confirm_text: String,
	use_multiline_action_layout: bool = false,
) -> void:
	_hide_continue_stats_context()
	_modal_restore_navigation_focus = _navigation_focus_active
	_confirmation_action = action
	_confirmation_page.configure(
		message,
		confirm_text,
		use_multiline_action_layout
	)
	_begin_confirmation_open()


func _request_close_confirmation() -> void:
	if (
		not _confirmation_page.visible
		or _confirmation_transition_active
		or _action_in_progress
	):
		return
	_begin_confirmation_return()


func _begin_confirmation_open() -> void:
	_confirmation_transition_generation += 1
	_cancel_confirmation_transition()
	_confirmation_transition_active = true
	_emit_navigation_bubble_flurry()
	_confirmation_title_content_rest_position = _presentation_center.position
	_set_confirmation_stage_rect()
	_confirmation_page.hide_page()
	_set_title_bubbles_interactive(false)
	_release_primary_menu_focus()
	var generation: int = _confirmation_transition_generation
	var content_bounds: Rect2 = _get_title_stage_rect(_main_content)
	var exit_distance: float = (
		content_bounds.end.y + HOST_CLUSTER_SAFE_MARGIN
	)
	_confirmation_transition = create_tween()
	_confirmation_transition.tween_property(
		_presentation_center,
		"position:y",
		_confirmation_title_content_rest_position.y - exit_distance,
		UIMotion.bubble_duration(exit_distance)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_confirmation_transition.finished.connect(
		_finish_confirmation_title_exit.bind(generation),
		CONNECT_ONE_SHOT
	)


func _finish_confirmation_title_exit(generation: int) -> void:
	if (
		generation != _confirmation_transition_generation
		or not _confirmation_transition_active
	):
		return
	_confirmation_transition = null
	_presentation_center.hide()
	_presentation_center.position = _confirmation_title_content_rest_position
	_confirmation_page.transition_in(
		0.0,
		_finish_confirmation_open.bind(generation)
	)


func _finish_confirmation_open(generation: int) -> void:
	if (
		generation != _confirmation_transition_generation
		or not _confirmation_transition_active
	):
		return
	_confirmation_transition_active = false


func _begin_confirmation_return() -> void:
	if not _confirmation_page.visible or _confirmation_transition_active:
		return
	_confirmation_transition_generation += 1
	_cancel_confirmation_transition()
	_confirmation_transition_active = true
	_emit_navigation_bubble_flurry()
	_confirmation_page.lock_interaction()
	var generation: int = _confirmation_transition_generation
	_confirmation_page.transition_out(
		0.0,
		_finish_confirmation_page_exit.bind(generation)
	)


func _finish_confirmation_page_exit(generation: int) -> void:
	if (
		generation != _confirmation_transition_generation
		or not _confirmation_transition_active
	):
		return
	_confirmation_action = ConfirmationAction.NONE
	_presentation_center.position = Vector2(
		_confirmation_title_content_rest_position.x,
		_title_presentation_scale_root.size.y
		+ HOST_CLUSTER_SAFE_MARGIN
	)
	_presentation_center.show()
	var entry_distance: float = absf(
		_presentation_center.position.y
		- _confirmation_title_content_rest_position.y
	)
	_confirmation_transition = create_tween()
	_confirmation_transition.tween_property(
		_presentation_center,
		"position",
		_confirmation_title_content_rest_position,
		UIMotion.bubble_duration(entry_distance)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_confirmation_transition.finished.connect(
		_finish_confirmation_return.bind(generation),
		CONNECT_ONE_SHOT
	)


func _finish_confirmation_return(generation: int) -> void:
	if (
		generation != _confirmation_transition_generation
		or not _confirmation_transition_active
	):
		return
	_confirmation_transition = null
	_confirmation_transition_active = false
	_presentation_center.position = _confirmation_title_content_rest_position
	_set_title_bubbles_interactive(true)
	var restore_navigation_focus: bool = _modal_restore_navigation_focus
	_modal_restore_navigation_focus = false
	if restore_navigation_focus:
		_focus_initial_button()
	else:
		_navigation_focus_active = false
		_release_title_focus()
	_update_continue_stats_visibility()


func _set_confirmation_stage_rect() -> void:
	var slot_rect: Rect2 = _get_title_stage_rect(_bubble_layout_slot)
	_confirmation_page.set_stage_rect(
		slot_rect
	)


func _reset_confirmation() -> void:
	_confirmation_transition_generation += 1
	_cancel_confirmation_transition()
	_confirmation_transition_active = false
	_confirmation_action = ConfirmationAction.NONE
	_confirmation_page.hide_page()
	if is_node_ready():
		_presentation_center.position = _confirmation_title_content_rest_position
		_presentation_center.show()


func _cancel_confirmation_transition() -> void:
	if _confirmation_transition != null:
		_confirmation_transition.kill()
		_confirmation_transition = null


func _is_confirmation_active() -> bool:
	return (
		_confirmation_action != ConfirmationAction.NONE
		or _confirmation_page.visible
		or _confirmation_transition_active
	)


func _open_settings() -> void:
	if (
		_is_confirmation_active()
		or _action_in_progress
		or _settings_panel.visible
		or _title_settings_transition_active
	):
		return
	_hide_continue_stats_context()
	_modal_restore_navigation_focus = _navigation_focus_active
	_feedback_visible_before_settings = _feedback_label.visible
	_feedback_text_before_settings = _feedback_label.text
	_begin_title_cluster_exit()


func _close_settings() -> void:
	_settings_panel.close_panel()


func _on_settings_applied() -> void:
	_feedback_text_before_settings = "settings saved."


func _on_settings_closed() -> void:
	pass


func _on_settings_closing() -> void:
	await get_tree().create_timer(
		UIMotion.BUBBLE_TRANSITION_OVERLAP_DELAY
	).timeout
	if _settings_panel.visible:
		_begin_title_cluster_return(_feedback_text_before_settings)


func _on_settings_opened() -> void:
	pass


func _begin_title_cluster_exit() -> void:
	_title_settings_transition_generation += 1
	_cancel_title_settings_tween()
	_title_settings_transition_active = true
	_emit_navigation_bubble_flurry()
	_title_content_rest_position = _presentation_center.position
	_title_bubble_rest_position = _bubble_field.position
	_set_title_bubbles_interactive(false)
	_release_primary_menu_focus()
	var generation: int = _title_settings_transition_generation
	var content_bounds: Rect2 = _get_title_stage_rect(_main_content)
	var exit_distance: float = (
		content_bounds.end.y + HOST_CLUSTER_SAFE_MARGIN
	)
	_title_settings_transition = create_tween()
	_title_settings_transition.tween_property(
		_presentation_center,
		"position:y",
		_title_content_rest_position.y - exit_distance,
		UIMotion.bubble_duration(exit_distance)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_settings_transition.finished.connect(
		_finish_title_cluster_exit.bind(generation),
		CONNECT_ONE_SHOT
	)
	await get_tree().create_timer(
		UIMotion.BUBBLE_TRANSITION_OVERLAP_DELAY
	).timeout
	if (
		generation == _title_settings_transition_generation
		and _title_settings_transition_active
	):
		_settings_panel.open_panel(
			_settings_manager,
			SettingsPanelType.PresentationMode.TITLE_EMBEDDED
		)


func _finish_title_cluster_exit(generation: int) -> void:
	if (
		generation != _title_settings_transition_generation
		or not _title_settings_transition_active
	):
		return
	_title_settings_transition = null
	_title_settings_transition_active = false
	_presentation_center.hide()
	_presentation_center.position = _title_content_rest_position


func _begin_title_cluster_return(feedback_text: String) -> void:
	_title_settings_transition_generation += 1
	_cancel_title_settings_tween()
	_title_settings_transition_active = true
	if _feedback_label.text != feedback_text:
		_feedback_label.text = feedback_text
	_feedback_label.visible = _feedback_visible_before_settings
	_hide_continue_stats_context()
	_set_title_bubbles_interactive(false)
	var generation: int = _title_settings_transition_generation
	_presentation_center.position = Vector2(
		_title_content_rest_position.x,
		_title_presentation_scale_root.size.y + HOST_CLUSTER_SAFE_MARGIN
	)
	_presentation_center.show()
	var entry_distance: float = absf(
		_presentation_center.position.y - _title_content_rest_position.y
	)
	_title_settings_transition = create_tween()
	_title_settings_transition.tween_property(
		_presentation_center,
		"position",
		_title_content_rest_position,
		UIMotion.bubble_duration(entry_distance)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_title_settings_transition.finished.connect(
		_finish_title_cluster_return.bind(generation),
		CONNECT_ONE_SHOT
	)


func _finish_title_cluster_return(generation: int) -> void:
	if (
		generation != _title_settings_transition_generation
		or not _title_settings_transition_active
	):
		return
	_title_settings_transition = null
	_title_settings_transition_active = false
	_presentation_center.position = _title_content_rest_position
	_bubble_field.position = _title_bubble_rest_position
	_set_title_bubbles_interactive(true)
	_restore_settings_focus()
	_update_continue_stats_visibility()

func _set_title_bubbles_interactive(interactive: bool) -> void:
	for bubble: BubbleButton in _get_title_buttons():
		bubble.focus_mode = (
			Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
		)
		bubble.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if interactive
			else Control.MOUSE_FILTER_IGNORE
		)


func _capture_title_bubble_rest_position() -> void:
	if (
		not is_node_ready()
		or _title_settings_transition_active
		or not _button_center.visible
	):
		return
	_title_bubble_rest_position = _bubble_field.position


func _capture_title_content_rest_position() -> void:
	if (
		not is_node_ready()
		or _title_settings_transition_active
		or _title_entry_transition_active
		or not _button_center.visible
	):
		return
	_title_content_rest_position = _presentation_center.position


func _cancel_title_settings_transition() -> void:
	_title_settings_transition_generation += 1
	_cancel_title_settings_tween()
	_title_settings_transition_active = false
	if is_node_ready():
		_presentation_center.position = _title_content_rest_position
		_presentation_center.show()
		_bubble_field.position = _title_bubble_rest_position
		_set_title_bubbles_interactive(true)


func _cancel_title_settings_tween() -> void:
	if _title_settings_transition != null:
		_title_settings_transition.kill()
		_title_settings_transition = null


func _restore_settings_focus() -> void:
	var restore_navigation_focus: bool = _modal_restore_navigation_focus
	_modal_restore_navigation_focus = false
	if restore_navigation_focus:
		_navigation_focus_active = true
		_settings_button.grab_focus()
	else:
		_navigation_focus_active = false
		_release_title_focus()


func _refresh_save_inspection() -> void:
	_inspection = _save_manager.inspect_save()
	_continue_button.disabled = not _inspection.can_continue()
	_delete_button.disabled = not _inspection.can_delete()
	_delete_save_label.modulate.a = (
		DISABLED_BUBBLE_LABEL_ALPHA if _delete_button.disabled else 1.0
	)
	_feedback_label.text = _inspection.message
	if _inspection.status == SaveInspectionType.Status.VALID_SUPPORTED:
		_feedback_label.text = _get_continue_stats_text()
	if _continue_button.disabled:
		_hide_continue_stats_context()
	else:
		_update_continue_stats_visibility()


func _focus_initial_button() -> void:
	if (
		not is_node_ready()
		or not visible
		or _awaiting_start_input
		or not _button_center.visible
	):
		return
	if not _continue_button.disabled:
		_continue_button.grab_focus()
	else:
		_new_game_button.grab_focus()
	_navigation_focus_active = true
	_update_continue_stats_visibility()


func _on_quit_pressed() -> void:
	if (
		not _action_in_progress
		and not _is_confirmation_active()
		and not _settings_panel.visible
	):
		_hide_continue_stats_context()
		quit_requested.emit()


func _on_title_visibility_changed() -> void:
	if not _decorative_presentation_ready:
		return
	if visible:
		set_process(true)
		_start_decorative_presentation()
	else:
		_hide_continue_stats_context()
		_stop_entry_prompt_animation()
		_navigation_focus_active = false
		_modal_restore_navigation_focus = false
		_reset_confirmation()
		_stop_decorative_presentation()


func _start_decorative_presentation() -> void:
	if (
		not _decorative_presentation_ready
		or not visible
		or _decorative_presentation_active
	):
		return
	_decorative_generation += 1
	_decorative_presentation_active = true
	_schedule_next_decorative_fish(
		FIRST_FISH_DELAY_MIN,
		FIRST_FISH_DELAY_MAX
	)
	_schedule_next_decorative_bubble_event(
		BUBBLE_EVENT_DELAY_MIN,
		BUBBLE_EVENT_DELAY_MAX
	)


func _stop_decorative_presentation() -> void:
	_decorative_generation += 1
	_decorative_presentation_active = false
	_decorative_fish_timer.stop()
	if _decorative_fish_tween != null:
		_decorative_fish_tween.kill()
		_decorative_fish_tween = null
	if is_instance_valid(_decorative_fish):
		_decorative_fish.queue_free()
	_decorative_fish = null
	_decorative_bubble_event_timer.stop()
	_decorative_bubble_cluster_timer.stop()
	_pending_cluster_bubbles = 0
	for bubble_tween: Tween in _decorative_bubble_tweens.values():
		if bubble_tween != null:
			bubble_tween.kill()
	_decorative_bubble_tweens.clear()
	for bubble: TextureRect in _decorative_bubbles:
		if is_instance_valid(bubble):
			bubble.queue_free()
	_decorative_bubbles.clear()
	_transition_bubble_ids.clear()


func _schedule_next_decorative_fish(
	minimum_delay: float,
	maximum_delay: float,
) -> void:
	if not _decorative_presentation_active or not visible:
		return
	_decorative_fish_timer.start(
		_decorative_rng.randf_range(minimum_delay, maximum_delay)
	)


func _on_decorative_fish_timer_timeout() -> void:
	if (
		not _decorative_presentation_active
		or not visible
		or is_instance_valid(_decorative_fish)
	):
		return
	_spawn_decorative_fish(_decorative_generation)


func _spawn_decorative_fish(generation: int) -> void:
	if (
		generation != _decorative_generation
		or not _decorative_presentation_active
		or not visible
		or DECORATIVE_FISH_TEXTURES.is_empty()
	):
		return
	var layer_size: Vector2 = _decorative_fish_layer.size
	if layer_size.x <= 1.0 or layer_size.y <= 1.0:
		_schedule_next_decorative_fish(0.5, 1.0)
		return
	var texture: Texture2D = DECORATIVE_FISH_TEXTURES[
		_decorative_rng.randi_range(0, DECORATIVE_FISH_TEXTURES.size() - 1)
	]
	var source_size: Vector2 = texture.get_size()
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		_schedule_next_decorative_fish(
			NEXT_FISH_DELAY_MIN,
			NEXT_FISH_DELAY_MAX
		)
		return
	var longest_side: float = _decorative_rng.randf_range(
		FISH_LONGEST_SIDE_MIN,
		FISH_LONGEST_SIDE_MAX
	)
	var presentation_scale: float = longest_side / maxf(
		source_size.x,
		source_size.y
	)
	var presentation_size: Vector2 = source_size * presentation_scale
	var fish_control := TextureRect.new()
	fish_control.name = "DecorativeFish"
	fish_control.texture = texture
	fish_control.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fish_control.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fish_control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fish_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fish_control.custom_minimum_size = presentation_size
	fish_control.size = presentation_size
	fish_control.modulate.a = 0.46

	var direction: float = (
		1.0
		if _decorative_rng.randi_range(0, 1) == 1
		else -1.0
	)
	fish_control.flip_h = direction > 0.0
	var minimum_y: float = maxf(24.0, layer_size.y * 0.08)
	var maximum_y: float = maxf(
		minimum_y,
		layer_size.y - presentation_size.y - maxf(24.0, layer_size.y * 0.08)
	)
	var base_y: float = _decorative_rng.randf_range(minimum_y, maximum_y)
	var bob_amplitude: float = _decorative_rng.randf_range(3.0, 8.0)
	var bob_speed: float = _decorative_rng.randf_range(0.65, 1.15)
	var crossing_duration: float = _decorative_rng.randf_range(
		CROSSING_DURATION_MIN,
		CROSSING_DURATION_MAX
	)
	fish_control.position = Vector2(
		-presentation_size.x - FISH_EDGE_MARGIN
		if direction > 0.0
		else layer_size.x + FISH_EDGE_MARGIN,
		base_y
	)
	_decorative_fish_layer.add_child(fish_control)
	_decorative_fish = fish_control
	_decorative_fish_tween = create_tween()
	_decorative_fish_tween.tween_method(
		_update_decorative_fish.bind(
			fish_control,
			direction,
			base_y,
			bob_amplitude,
			bob_speed,
			crossing_duration,
			generation
		),
		0.0,
		1.0,
		crossing_duration
	)
	_decorative_fish_tween.finished.connect(
		_on_decorative_fish_finished.bind(fish_control, generation),
		CONNECT_ONE_SHOT
	)


func _update_decorative_fish(
	progress: float,
	fish_control: TextureRect,
	direction: float,
	base_y: float,
	bob_amplitude: float,
	bob_speed: float,
	crossing_duration: float,
	generation: int,
) -> void:
	if (
		generation != _decorative_generation
		or not _decorative_presentation_active
		or not is_instance_valid(fish_control)
	):
		return
	var start_x: float = (
		-fish_control.size.x - FISH_EDGE_MARGIN
		if direction > 0.0
		else _decorative_fish_layer.size.x + FISH_EDGE_MARGIN
	)
	var end_x: float = (
		_decorative_fish_layer.size.x + FISH_EDGE_MARGIN
		if direction > 0.0
		else -fish_control.size.x - FISH_EDGE_MARGIN
	)
	fish_control.position.x = lerpf(start_x, end_x, progress)
	var bobbed_y: float = (
		base_y
		+ sin(progress * crossing_duration * bob_speed) * bob_amplitude
	)
	fish_control.position.y = clampf(
		bobbed_y,
		8.0,
		maxf(8.0, _decorative_fish_layer.size.y - fish_control.size.y - 8.0)
	)
	fish_control.position = _snap_world_preview(fish_control.position)


func _on_decorative_fish_finished(
	fish_control: TextureRect,
	generation: int,
) -> void:
	if generation != _decorative_generation:
		return
	_decorative_fish_tween = null
	if is_instance_valid(fish_control):
		fish_control.queue_free()
	if _decorative_fish == fish_control:
		_decorative_fish = null
	_schedule_next_decorative_fish(
		NEXT_FISH_DELAY_MIN,
		NEXT_FISH_DELAY_MAX
	)


func _schedule_next_decorative_bubble_event(
	minimum_delay: float,
	maximum_delay: float,
) -> void:
	if not _decorative_presentation_active or not visible:
		return
	_decorative_bubble_event_timer.start(
		_decorative_rng.randf_range(minimum_delay, maximum_delay)
	)


func _on_decorative_bubble_event_timer_timeout() -> void:
	if not _decorative_presentation_active or not visible:
		return
	var available_slots: int = (
		MAX_DECORATIVE_BUBBLES - _get_idle_decorative_bubble_count()
	)
	if available_slots <= 0:
		_schedule_next_decorative_bubble_event(
			BUBBLE_EVENT_DELAY_MIN,
			BUBBLE_EVENT_DELAY_MAX
		)
		return
	var event_size: int = _choose_decorative_bubble_event_size()
	event_size = mini(event_size, available_slots)
	if not _spawn_decorative_bubble(_decorative_generation):
		_schedule_next_decorative_bubble_event(0.5, 1.0)
		return
	_pending_cluster_bubbles = event_size - 1
	if _pending_cluster_bubbles > 0:
		_start_decorative_bubble_cluster_timer()
	else:
		_schedule_next_decorative_bubble_event(
			BUBBLE_EVENT_DELAY_MIN,
			BUBBLE_EVENT_DELAY_MAX
		)


func _choose_decorative_bubble_event_size() -> int:
	var roll: float = _decorative_rng.randf()
	if roll < 0.75:
		return 1
	if roll < 0.95:
		return 2
	return 3


func _start_decorative_bubble_cluster_timer() -> void:
	_decorative_bubble_cluster_timer.start(
		_decorative_rng.randf_range(
			BUBBLE_CLUSTER_DELAY_MIN,
			BUBBLE_CLUSTER_DELAY_MAX
		)
	)


func _on_decorative_bubble_cluster_timer_timeout() -> void:
	if (
		not _decorative_presentation_active
		or not visible
		or _pending_cluster_bubbles <= 0
	):
		_pending_cluster_bubbles = 0
		return
	if _get_idle_decorative_bubble_count() < MAX_DECORATIVE_BUBBLES:
		_spawn_decorative_bubble(_decorative_generation)
	_pending_cluster_bubbles -= 1
	if _pending_cluster_bubbles > 0:
		_start_decorative_bubble_cluster_timer()
	else:
		_schedule_next_decorative_bubble_event(
			BUBBLE_EVENT_DELAY_MIN,
			BUBBLE_EVENT_DELAY_MAX
		)


func _spawn_decorative_bubble(
	generation: int,
	start_y_ratio: float = -1.0,
	normalized_x_override: float = -1.0,
	is_transition_bubble: bool = false,
) -> bool:
	if (
		generation != _decorative_generation
		or not _decorative_presentation_active
		or not visible
		or DECORATIVE_BUBBLE_TEXTURES.is_empty()
	):
		return false
	if is_transition_bubble:
		if _transition_bubble_ids.size() >= MAX_TRANSITION_BUBBLES:
			return false
	elif _get_idle_decorative_bubble_count() >= MAX_DECORATIVE_BUBBLES:
		return false
	var layer_size: Vector2 = _decorative_bubble_layer.size
	if layer_size.x <= 1.0 or layer_size.y <= 1.0:
		return false
	var texture: Texture2D = DECORATIVE_BUBBLE_TEXTURES[
		_decorative_rng.randi_range(
			0,
			DECORATIVE_BUBBLE_TEXTURES.size() - 1
		)
	]
	var presentation_scale: float = _decorative_rng.randf_range(
		BUBBLE_SCALE_MIN,
		BUBBLE_SCALE_MAX
	)
	var presentation_size: Vector2 = texture.get_size() * presentation_scale
	var bubble := TextureRect.new()
	bubble.name = "DecorativeBubble"
	bubble.texture = texture
	bubble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bubble.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bubble.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.size = presentation_size
	bubble.modulate.a = _decorative_rng.randf_range(
		BUBBLE_OPACITY_MIN,
		BUBBLE_OPACITY_MAX
	)
	_decorative_bubble_layer.add_child(bubble)
	_decorative_bubbles.append(bubble)
	if is_transition_bubble:
		_transition_bubble_ids[bubble.get_instance_id()] = true

	var normalized_x: float = normalized_x_override
	if normalized_x < 0.0:
		normalized_x = _decorative_rng.randf_range(0.08, 0.92)
	var drift_direction: float = (
		1.0 if _decorative_rng.randi_range(0, 1) == 1 else -1.0
	)
	var horizontal_drift: float = (
		_decorative_rng.randf_range(
			BUBBLE_DRIFT_MIN,
			BUBBLE_DRIFT_MAX
		)
		* drift_direction
	)
	var wobble_amplitude: float = _decorative_rng.randf_range(
		BUBBLE_WOBBLE_MIN,
		BUBBLE_WOBBLE_MAX
	)
	var wobble_cycles: float = _decorative_rng.randf_range(0.8, 1.6)
	var wobble_phase: float = _decorative_rng.randf_range(0.0, TAU)
	var travel_duration: float = _decorative_rng.randf_range(
		BUBBLE_TRAVEL_DURATION_MIN,
		BUBBLE_TRAVEL_DURATION_MAX
	)
	if start_y_ratio >= 0.0:
		var full_start_y: float = (
			layer_size.y + presentation_size.y + BUBBLE_EDGE_MARGIN
		)
		var end_y: float = -presentation_size.y - BUBBLE_EDGE_MARGIN
		var burst_start_y: float = (
			start_y_ratio * layer_size.y - presentation_size.y * 0.5
		)
		var remaining_distance: float = maxf(burst_start_y - end_y, 1.0)
		var full_distance: float = maxf(full_start_y - end_y, 1.0)
		travel_duration *= remaining_distance / full_distance
		_update_decorative_bubble(
			0.0,
			bubble,
			normalized_x,
			horizontal_drift,
			wobble_amplitude,
			wobble_cycles,
			wobble_phase,
			start_y_ratio,
			generation
		)
	var bubble_tween: Tween = create_tween()
	_decorative_bubble_tweens[bubble.get_instance_id()] = bubble_tween
	bubble_tween.tween_method(
		_update_decorative_bubble.bind(
			bubble,
			normalized_x,
			horizontal_drift,
			wobble_amplitude,
			wobble_cycles,
			wobble_phase,
			start_y_ratio,
			generation
		),
		0.0,
		1.0,
		travel_duration
	)
	bubble_tween.finished.connect(
		_on_decorative_bubble_finished.bind(bubble, generation),
		CONNECT_ONE_SHOT
	)
	return true


func _update_decorative_bubble(
	progress: float,
	bubble: TextureRect,
	normalized_x: float,
	horizontal_drift: float,
	wobble_amplitude: float,
	wobble_cycles: float,
	wobble_phase: float,
	start_y_ratio: float,
	generation: int,
) -> void:
	if (
		generation != _decorative_generation
		or not _decorative_presentation_active
		or not is_instance_valid(bubble)
	):
		return
	var layer_size: Vector2 = _decorative_bubble_layer.size
	var start_y: float = (
		layer_size.y + bubble.size.y + BUBBLE_EDGE_MARGIN
	)
	if start_y_ratio >= 0.0:
		start_y = start_y_ratio * layer_size.y - bubble.size.y * 0.5
	var end_y: float = -bubble.size.y - BUBBLE_EDGE_MARGIN
	var base_x: float = normalized_x * layer_size.x
	var wobble: float = sin(
		wobble_phase + progress * TAU * wobble_cycles
	) * wobble_amplitude
	bubble.position = _snap_world_preview(Vector2(
		base_x
		+ horizontal_drift * progress
		+ wobble
		- bubble.size.x * 0.5,
		lerpf(start_y, end_y, progress)
	))


func _on_decorative_bubble_finished(
	bubble: TextureRect,
	generation: int,
) -> void:
	if generation != _decorative_generation:
		return
	if is_instance_valid(bubble):
		_decorative_bubble_tweens.erase(bubble.get_instance_id())
		_transition_bubble_ids.erase(bubble.get_instance_id())
		_decorative_bubbles.erase(bubble)
		bubble.queue_free()


func _get_idle_decorative_bubble_count() -> int:
	return _decorative_bubbles.size() - _transition_bubble_ids.size()


func _emit_navigation_bubble_flurry() -> void:
	if not _decorative_presentation_active or not visible:
		return
	var bubble_count: int = _decorative_rng.randi_range(
		TRANSITION_BUBBLE_COUNT_MIN,
		TRANSITION_BUBBLE_COUNT_MAX
	)
	for _bubble_index: int in bubble_count:
		if not _spawn_decorative_bubble(
			_decorative_generation,
			_decorative_rng.randf_range(
				TRANSITION_BUBBLE_Y_MIN,
				TRANSITION_BUBBLE_Y_MAX
			),
			_decorative_rng.randf_range(
				TRANSITION_BUBBLE_X_MIN,
				TRANSITION_BUBBLE_X_MAX
			),
			true
		):
			break


func _exit_tree() -> void:
	_stop_decorative_presentation()
