class_name TitleScreen
extends Control

const SaveInspectionType = preload("res://save/player_save_inspection.gd")
const SaveManagerType = preload("res://save/player_save_manager.gd")
const SettingsManagerType = preload(
	"res://settings/player_settings_manager.gd"
)
const SettingsPanelType = preload("res://ui/settings_panel.gd")
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
const LOGO_ASPECT_RATIO: float = 2560.0 / 760.0
const LOGO_WIDTH_FACTOR: float = 0.52
const LOGO_MIN_WIDTH: float = 320.0
const LOGO_MAX_WIDTH: float = 720.0
const BUTTON_COLUMN_WIDTH: float = 360.0
const TITLE_HORIZONTAL_MARGIN: float = 48.0
const START_PROMPT_MIN_SCALE: float = 0.985
const START_PROMPT_MAX_SCALE: float = 1.015
const START_PROMPT_CYCLE_SECONDS: float = 3.0

signal gameplay_requested
signal quit_requested

enum ConfirmationAction {
	NONE,
	NEW_GAME,
	DELETE_SAVE,
}

@onready var _continue_button: Button = %ContinueButton
@onready var _new_game_button: Button = %NewGameButton
@onready var _settings_button: Button = %SettingsButton
@onready var _delete_button: Button = %DeleteSaveButton
@onready var _quit_button: Button = %QuitButton
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _confirmation_panel: PanelContainer = %ConfirmationPanel
@onready var _confirmation_text: Label = %ConfirmationText
@onready var _confirm_button: Button = %ConfirmButton
@onready var _settings_panel: SettingsPanelType = %SettingsPanel
@onready var _decorative_fish_layer: Control = %DecorativeFishLayer
@onready var _decorative_fish_timer: Timer = %DecorativeFishTimer
@onready var _decorative_bubble_layer: Control = %DecorativeBubbleLayer
@onready var _decorative_bubble_event_timer: Timer = %DecorativeBubbleEventTimer
@onready var _decorative_bubble_cluster_timer: Timer = %DecorativeBubbleClusterTimer
@onready var _title_logo: TextureRect = %TitleLogo
@onready var _button_center: CenterContainer = %ButtonCenter
@onready var _button_stack: VBoxContainer = %ButtonStack
@onready var _start_prompt_center: CenterContainer = %StartPromptCenter
@onready var _start_prompt_label: Label = %StartPromptLabel

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
var _pending_cluster_bubbles: int = 0
var _awaiting_start_input: bool = false
var _start_prompt_elapsed: float = 0.0
var _navigation_focus_active: bool = false
var _modal_restore_navigation_focus: bool = false


func _ready() -> void:
	_continue_button.pressed.connect(_on_continue_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_settings_button.pressed.connect(_open_settings)
	_delete_button.pressed.connect(_on_delete_pressed)
	%QuitButton.pressed.connect(_on_quit_pressed)
	_confirm_button.pressed.connect(_on_confirmation_accepted)
	%CancelConfirmButton.pressed.connect(_close_confirmation)
	_settings_panel.applied.connect(_on_settings_applied)
	_settings_panel.closed.connect(_on_settings_closed)
	_decorative_fish_timer.timeout.connect(_on_decorative_fish_timer_timeout)
	_decorative_bubble_event_timer.timeout.connect(
		_on_decorative_bubble_event_timer_timeout
	)
	_decorative_bubble_cluster_timer.timeout.connect(
		_on_decorative_bubble_cluster_timer_timeout
	)
	visibility_changed.connect(_on_title_visibility_changed)
	resized.connect(_update_title_layout)
	_start_prompt_label.resized.connect(_update_start_prompt_pivot)
	_decorative_rng.randomize()
	set_process(false)
	call_deferred("_update_title_layout")
	call_deferred("_update_start_prompt_pivot")


func setup(
	save_manager: SaveManagerType,
	settings_manager: SettingsManagerType,
) -> void:
	_save_manager = save_manager
	_settings_manager = settings_manager
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_save_inspection()
	show()
	_decorative_presentation_ready = true
	_start_decorative_presentation()
	_begin_title_entry()


func reopen() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_prepare_awaiting_start_input()
	_close_confirmation()
	_settings_panel.hide()
	_refresh_save_inspection()
	show()
	_start_decorative_presentation()
	_start_entry_prompt_animation()


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
	var available_width: float = maxf(1.0, size.x - TITLE_HORIZONTAL_MARGIN)
	var logo_width: float = minf(
		clampf(
			size.x * LOGO_WIDTH_FACTOR,
			LOGO_MIN_WIDTH,
			LOGO_MAX_WIDTH
		),
		available_width
	)
	_title_logo.custom_minimum_size = Vector2(
		logo_width,
		logo_width / LOGO_ASPECT_RATIO
	)
	_button_stack.custom_minimum_size = Vector2(
		minf(BUTTON_COLUMN_WIDTH, available_width),
		0.0
	)


func _process(delta: float) -> void:
	if (
		not _awaiting_start_input
		or not visible
		or not _start_prompt_center.visible
	):
		return
	_start_prompt_elapsed = fmod(
		_start_prompt_elapsed + delta,
		START_PROMPT_CYCLE_SECONDS
	)
	var phase: float = _start_prompt_elapsed / START_PROMPT_CYCLE_SECONDS
	var pulse_weight: float = (sin(phase * TAU - PI * 0.5) + 1.0) * 0.5
	var prompt_scale: float = lerpf(
		START_PROMPT_MIN_SCALE,
		START_PROMPT_MAX_SCALE,
		pulse_weight
	)
	_start_prompt_label.scale = Vector2.ONE * prompt_scale


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _awaiting_start_input:
		if not _is_start_prompt_reveal_event(event):
			return
		_reveal_primary_menu()
		get_viewport().set_input_as_handled()
		return
	if _handle_primary_menu_focus_input(event):
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _confirmation_panel.visible:
		_close_confirmation()
	elif _settings_panel.visible:
		_close_settings()
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
		or _confirmation_panel.visible
		or _settings_panel.visible
	):
		return false
	if event is InputEventMouseMotion:
		_navigation_focus_active = false
		_release_primary_menu_focus()
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
	_awaiting_start_input = true
	_navigation_focus_active = false
	_modal_restore_navigation_focus = false
	_button_center.hide()
	_feedback_label.hide()
	_start_prompt_center.show()
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner != null and is_ancestor_of(focus_owner):
		focus_owner.release_focus()


func _start_entry_prompt_animation() -> void:
	_start_prompt_elapsed = 0.0
	_start_prompt_label.scale = Vector2.ONE * START_PROMPT_MIN_SCALE
	_update_start_prompt_pivot()
	set_process(true)


func _stop_entry_prompt_animation() -> void:
	set_process(false)
	_start_prompt_elapsed = 0.0
	_start_prompt_label.scale = Vector2.ONE


func _update_start_prompt_pivot() -> void:
	if not is_node_ready():
		return
	_start_prompt_label.pivot_offset = _start_prompt_label.size * 0.5


func _reveal_primary_menu() -> void:
	if not _awaiting_start_input:
		return
	_awaiting_start_input = false
	_stop_entry_prompt_animation()
	_start_prompt_center.hide()
	_button_center.show()
	_feedback_label.show()
	_navigation_focus_active = false
	_release_title_focus()


func _on_continue_pressed() -> void:
	if (
		_action_in_progress
		or _confirmation_panel.visible
		or _settings_panel.visible
		or _inspection == null
		or not _inspection.can_continue()
	):
		return
	_action_in_progress = true
	if _save_manager.load_player_data():
		_feedback_label.text = "save loaded."
		gameplay_requested.emit()
	else:
		_refresh_save_inspection()
		_feedback_label.text = "failed to load save. the original was preserved."
	_action_in_progress = false


func _on_new_game_pressed() -> void:
	if (
		_action_in_progress
		or _confirmation_panel.visible
		or _settings_panel.visible
		or _inspection == null
	):
		return
	if _inspection.status == SaveInspectionType.Status.MISSING:
		if _save_manager.initialize_new_game():
			gameplay_requested.emit()
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
		"start new game"
	)


func _on_delete_pressed() -> void:
	if (
		_action_in_progress
		or _confirmation_panel.visible
		or _settings_panel.visible
		or _inspection == null
		or not _inspection.can_delete()
	):
		return
	_open_confirmation(
		ConfirmationAction.DELETE_SAVE,
		"delete your saved progression? this cannot be undone.",
		"delete"
	)


func _on_confirmation_accepted() -> void:
	if _action_in_progress:
		return
	var action: ConfirmationAction = _confirmation_action
	_close_confirmation()
	_action_in_progress = true
	if not _save_manager.delete_progression_save():
		_feedback_label.text = "failed to delete saved progression."
		_action_in_progress = false
		_refresh_save_inspection()
		return
	_save_manager.initialize_new_game()
	_refresh_save_inspection()
	if action == ConfirmationAction.NEW_GAME:
		gameplay_requested.emit()
	else:
		_feedback_label.text = "saved progression deleted."
	_action_in_progress = false


func _open_confirmation(
	action: ConfirmationAction,
	message: String,
	confirm_text: String,
) -> void:
	_modal_restore_navigation_focus = _navigation_focus_active
	_confirmation_action = action
	_confirmation_text.text = message
	_confirm_button.text = confirm_text
	_confirmation_panel.visible = true
	_confirm_button.grab_focus()


func _close_confirmation() -> void:
	var restore_navigation_focus: bool = _modal_restore_navigation_focus
	_modal_restore_navigation_focus = false
	_confirmation_action = ConfirmationAction.NONE
	_confirmation_panel.visible = false
	if _awaiting_start_input:
		return
	if restore_navigation_focus:
		_focus_initial_button()
	else:
		_navigation_focus_active = false
		_release_title_focus()


func _open_settings() -> void:
	if _confirmation_panel.visible or _action_in_progress:
		return
	_modal_restore_navigation_focus = _navigation_focus_active
	_feedback_label.text = ""
	_settings_panel.open_panel(_settings_manager)


func _close_settings() -> void:
	_settings_panel.close_panel()


func _on_settings_applied() -> void:
	_feedback_label.text = "settings saved."
	_restore_settings_focus()


func _on_settings_closed() -> void:
	_restore_settings_focus()


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
	_feedback_label.text = _inspection.message
	if _inspection.status == SaveInspectionType.Status.VALID_SUPPORTED:
		_feedback_label.text = (
			"%d fish • $%d • %d discovered"
			% [
				_inspection.catch_count,
				_inspection.wallet_balance,
				_inspection.discovered_species_count,
			]
		)


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


func _on_quit_pressed() -> void:
	if (
		not _action_in_progress
		and not _confirmation_panel.visible
		and not _settings_panel.visible
	):
		quit_requested.emit()


func _on_title_visibility_changed() -> void:
	if not _decorative_presentation_ready:
		return
	if visible:
		_start_decorative_presentation()
	else:
		_stop_entry_prompt_animation()
		_navigation_focus_active = false
		_modal_restore_navigation_focus = false
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
		MAX_DECORATIVE_BUBBLES - _decorative_bubbles.size()
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
	if _decorative_bubbles.size() < MAX_DECORATIVE_BUBBLES:
		_spawn_decorative_bubble(_decorative_generation)
	_pending_cluster_bubbles -= 1
	if _pending_cluster_bubbles > 0:
		_start_decorative_bubble_cluster_timer()
	else:
		_schedule_next_decorative_bubble_event(
			BUBBLE_EVENT_DELAY_MIN,
			BUBBLE_EVENT_DELAY_MAX
		)


func _spawn_decorative_bubble(generation: int) -> bool:
	if (
		generation != _decorative_generation
		or not _decorative_presentation_active
		or not visible
		or _decorative_bubbles.size() >= MAX_DECORATIVE_BUBBLES
		or DECORATIVE_BUBBLE_TEXTURES.is_empty()
	):
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

	var normalized_x: float = _decorative_rng.randf_range(0.08, 0.92)
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
	var end_y: float = -bubble.size.y - BUBBLE_EDGE_MARGIN
	var base_x: float = normalized_x * layer_size.x
	var wobble: float = sin(
		wobble_phase + progress * TAU * wobble_cycles
	) * wobble_amplitude
	bubble.position = Vector2(
		base_x
		+ horizontal_drift * progress
		+ wobble
		- bubble.size.x * 0.5,
		lerpf(start_y, end_y, progress)
	)


func _on_decorative_bubble_finished(
	bubble: TextureRect,
	generation: int,
) -> void:
	if generation != _decorative_generation:
		return
	if is_instance_valid(bubble):
		_decorative_bubble_tweens.erase(bubble.get_instance_id())
		_decorative_bubbles.erase(bubble)
		bubble.queue_free()


func _exit_tree() -> void:
	_stop_decorative_presentation()
