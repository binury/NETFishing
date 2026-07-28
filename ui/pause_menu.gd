class_name PauseMenu
extends Control

const INPUT_OWNER: StringName = &"game_menu"
const PAUSE_DESKTOP_REFERENCE_SIZE: Vector2 = Vector2(1280.0, 720.0)
const PAUSE_COMPACT_REFERENCE_SIZE: Vector2 = Vector2(640.0, 480.0)
const COMPACT_HEIGHT_THRESHOLD: float = 560.0
const PAGE_OUTGOING_DURATION: float = 1.70
const PAGE_INCOMING_DURATION: float = 1.85
const VISIBILITY_FADE_DURATION: float = 0.55
const BACKDROP_TARGET_ALPHA: float = 0.68
const PlayerType = preload("res://player/player.gd")
const SaveManagerType = preload("res://save/player_save_manager.gd")
const SettingsManagerType = preload(
	"res://settings/player_settings_manager.gd"
)
const SettingsPanelType = preload("res://ui/settings_panel.gd")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")

signal return_to_title_requested
signal reset_progress_requested
signal quit_requested
signal menu_visibility_changed(is_open: bool)

enum ConfirmationAction {
	NONE,
	RETURN_TO_TITLE,
	RESET_PROGRESS,
	QUIT_ANYWAY,
}

enum CloseReason {
	USER_RETURN,
	BITE_STARTED,
	WATER_RECOVERY,
	RETURN_TO_TITLE,
	RESET_PROGRESS,
	QUIT,
	TEARDOWN,
}

@onready var _presentation_scale_root: Control = %PausePresentationScaleRoot
@onready var _root_page: SettingsBubblePage = %RootPage
@onready var _settings_panel: SettingsPanelType = %SettingsPanel
@onready var _dim_background: ColorRect = %DimBackground
@onready var _transition_flurry: BubbleTransitionFlurry = (
	%TransitionBubbleLayer
)
@onready var _confirmation_panel: PanelContainer = %ConfirmationPanel
@onready var _confirmation_title: Label = %ConfirmationTitle
@onready var _confirmation_text: Label = %ConfirmationText
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelConfirmButton
@onready var _feedback: Label = %FeedbackLabel
@onready var _save_button: BubbleButton = %SaveButton

var _player: PlayerType
var _save_manager: SaveManagerType
var _settings_manager: SettingsManagerType
var _fishing_spot: FishingSpotType
var _prior_movement_enabled: bool = true
var _prior_camera_enabled: bool = true
var _prior_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _control_snapshot_stored: bool = false
var _mouse_snapshot_stored: bool = false
var _confirmation_action: ConfirmationAction = ConfirmationAction.NONE
var _action_in_progress: bool = false
var _root_transition_active: bool = false
var _root_transition_generation: int = 0
var _closing_menu: bool = false
var _backdrop_fade: Tween
var _backdrop_fade_generation: int = 0
var _confirmation_fade: Tween
var _confirmation_fade_generation: int = 0
var _confirmation_fade_active: bool = false


func _ready() -> void:
	%ResumeButton.pressed.connect(resume)
	_save_button.pressed.connect(_save_now)
	%SettingsButton.pressed.connect(_open_settings)
	%ReturnToTitleButton.pressed.connect(_confirm_return_to_title)
	%ResetProgressButton.pressed.connect(_confirm_reset_progress)
	%QuitButton.pressed.connect(_request_quit)
	_confirm_button.pressed.connect(_accept_confirmation)
	_cancel_button.pressed.connect(_close_confirmation)
	_settings_panel.applied.connect(_on_settings_applied)
	_settings_panel.closed.connect(_on_settings_closed)
	_settings_panel.navigation_transition_started.connect(
		_emit_transition_flurry
	)
	_dim_background.color.a = 0.0
	_confirmation_panel.modulate.a = 0.0
	_set_confirmation_interactive(false)
	resized.connect(_update_responsive_pause_stage)
	call_deferred("_update_responsive_pause_stage")


func setup(
	player: PlayerType,
	save_manager: SaveManagerType,
	settings_manager: SettingsManagerType,
	fishing_spot: FishingSpotType,
) -> void:
	_player = player
	_save_manager = save_manager
	_settings_manager = settings_manager
	_fishing_spot = fishing_spot
	if not _fishing_spot.bite_activated.is_connected(_on_bite_activated):
		_fishing_spot.bite_activated.connect(_on_bite_activated)


func open_menu() -> void:
	if visible or _player == null:
		return
	_prior_movement_enabled = _player.is_movement_enabled()
	_prior_camera_enabled = _player.is_camera_input_enabled()
	_prior_mouse_mode = Input.mouse_mode
	_control_snapshot_stored = true
	_mouse_snapshot_stored = true
	_player.set_movement_enabled(false)
	_player.set_camera_input_enabled(false)
	_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_feedback.text = ""
	_settings_panel.hide()
	_confirmation_panel.hide()
	_confirmation_action = ConfirmationAction.NONE
	_action_in_progress = false
	_root_page.hide_page()
	show()
	_fade_backdrop(true)
	_update_responsive_pause_stage()
	_begin_root_entry(false)
	menu_visibility_changed.emit(true)


func resume() -> void:
	if (
		not visible
		or _action_in_progress
		or _root_transition_active
		or _settings_panel.visible
		or _confirmation_action != ConfirmationAction.NONE
	):
		return
	_fade_backdrop(false)
	_begin_root_exit(_finish_user_close)


func close_for_title_transition() -> void:
	close_menu(CloseReason.RETURN_TO_TITLE, false)


func close_for_water_recovery() -> void:
	close_menu(CloseReason.WATER_RECOVERY, false)


func close_menu(
	reason: CloseReason,
	restore_controls: bool = true,
) -> void:
	if not visible:
		return
	_finish_close(reason, restore_controls)


func handle_escape() -> bool:
	if not visible:
		return false
	if _root_transition_active or _confirmation_fade_active:
		return true
	if _confirmation_panel.visible:
		_close_confirmation()
	elif _settings_panel.visible:
		_settings_panel.handle_back()
	else:
		resume()
	return true


func _save_now() -> void:
	if _action_in_progress or _root_transition_active:
		return
	_action_in_progress = true
	_save_button.disabled = true
	if _save_manager.save_now():
		_feedback.text = "game saved."
	else:
		_feedback.text = "save failed. previous save was preserved."
	_action_in_progress = false
	call_deferred("_reenable_save_button")


func _reenable_save_button() -> void:
	_save_button.disabled = false


func _open_settings() -> void:
	if (
		_action_in_progress
		or _root_transition_active
		or _confirmation_action != ConfirmationAction.NONE
	):
		return
	_begin_root_exit(_finish_open_settings)


func _finish_open_settings() -> void:
	_settings_panel.open_panel(
		_settings_manager,
		SettingsPanelType.PresentationMode.GAMEPLAY_MODAL,
		true,
		true
	)


func _on_settings_applied() -> void:
	if _closing_menu:
		return
	_feedback.text = "settings saved."
	_begin_root_entry(true)


func _on_settings_closed() -> void:
	if _closing_menu:
		return
	_begin_root_entry(true)


func _confirm_return_to_title() -> void:
	_open_confirmation(
		ConfirmationAction.RETURN_TO_TITLE,
		"return to title",
		"unsaved progress will be saved first.",
		"save and return",
		false
	)


func _confirm_reset_progress() -> void:
	_open_confirmation(
		ConfirmationAction.RESET_PROGRESS,
		"reset all progression?",
		(
			"this permanently deletes your fish, discoveries, "
			+ "favorites, and wallet balance.\n\n"
			+ "your settings will be preserved."
		),
		"delete all progress",
		true
	)


func _request_quit() -> void:
	if _action_in_progress or _root_transition_active:
		return
	_action_in_progress = true
	var settings_saved: bool = _settings_manager.save_if_dirty()
	var progression_saved: bool = _save_manager.save_if_dirty()
	_action_in_progress = false
	if settings_saved and progression_saved:
		quit_requested.emit()
		return
	_open_confirmation(
		ConfirmationAction.QUIT_ANYWAY,
		"save failed",
		"some progress or settings could not be saved. quit anyway?",
		"quit anyway",
		true
	)


func _open_confirmation(
	action: ConfirmationAction,
	title: String,
	message: String,
	confirm_text: String,
	dangerous: bool,
) -> void:
	if _action_in_progress or _root_transition_active:
		return
	_confirmation_action = action
	_confirmation_title.text = title
	_confirmation_text.text = message
	_confirm_button.text = confirm_text
	_confirm_button.theme_type_variation = (
		&"DangerButton" if dangerous else StringName()
	)
	_begin_root_exit(_show_confirmation.bind(dangerous))


func _show_confirmation(dangerous: bool) -> void:
	_fade_confirmation(
		true,
		_finish_confirmation_open.bind(dangerous)
	)


func _finish_confirmation_open(dangerous: bool) -> void:
	_set_confirmation_interactive(true)
	if dangerous:
		_cancel_button.grab_focus()
	else:
		_confirm_button.grab_focus()


func _close_confirmation() -> void:
	if _root_transition_active or _confirmation_fade_active:
		return
	_confirmation_action = ConfirmationAction.NONE
	_fade_confirmation(false, _finish_confirmation_cancel)


func _finish_confirmation_cancel() -> void:
	_begin_root_entry(false)


func _accept_confirmation() -> void:
	if (
		_action_in_progress
		or _root_transition_active
		or _confirmation_fade_active
	):
		return
	var action: ConfirmationAction = _confirmation_action
	_confirmation_action = ConfirmationAction.NONE
	_action_in_progress = true
	_fade_confirmation(
		false,
		_finish_confirmation_accept.bind(action)
	)


func _finish_confirmation_accept(action: ConfirmationAction) -> void:
	match action:
		ConfirmationAction.RETURN_TO_TITLE:
			if _save_manager.save_now():
				return_to_title_requested.emit()
			else:
				_feedback.text = "save failed. previous save was preserved."
				_action_in_progress = false
				_begin_root_entry(false)
				return
		ConfirmationAction.RESET_PROGRESS:
			reset_progress_requested.emit()
		ConfirmationAction.QUIT_ANYWAY:
			quit_requested.emit()
		_:
			_action_in_progress = false
			_begin_root_entry(false)
			return
	_action_in_progress = false


func report_reset_failure() -> void:
	_action_in_progress = false
	_confirmation_action = ConfirmationAction.NONE
	_feedback.text = "reset failed. your progression was preserved."
	if visible:
		_begin_root_entry(false)


func _begin_root_entry(flurry_already_emitted: bool) -> void:
	if _root_transition_active:
		return
	_root_transition_generation += 1
	_root_transition_active = true
	if not flurry_already_emitted:
		_emit_transition_flurry()
	var generation: int = _root_transition_generation
	_root_page.transition_in(
		true,
		_finish_root_entry.bind(generation),
		PAGE_INCOMING_DURATION
	)


func _finish_root_entry(generation: int) -> void:
	if generation != _root_transition_generation or not visible:
		return
	_root_transition_active = false


func _begin_root_exit(completed: Callable) -> void:
	if _root_transition_active or not _root_page.visible:
		return
	_root_transition_generation += 1
	_root_transition_active = true
	_emit_transition_flurry()
	var generation: int = _root_transition_generation
	_root_page.transition_out(
		_finish_root_exit.bind(generation, completed),
		PAGE_OUTGOING_DURATION
	)


func _finish_root_exit(
	generation: int,
	completed: Callable,
) -> void:
	if generation != _root_transition_generation or not visible:
		return
	_root_transition_active = false
	completed.call()


func _finish_user_close() -> void:
	_finish_close(CloseReason.USER_RETURN, true)


func _finish_close(reason: CloseReason, restore_controls: bool) -> void:
	_closing_menu = true
	if _settings_panel.visible:
		_settings_panel.close_panel(true)
	_closing_menu = false
	_root_transition_generation += 1
	_root_transition_active = false
	_cancel_backdrop_fade()
	_cancel_confirmation_fade()
	_dim_background.color.a = 0.0
	_dim_background.hide()
	_confirmation_panel.modulate.a = 0.0
	_set_confirmation_interactive(false)
	_settings_panel.hide()
	_root_page.hide_page()
	_confirmation_panel.hide()
	_confirmation_action = ConfirmationAction.NONE
	_action_in_progress = false
	_transition_flurry.clear_flurries()
	hide()
	if _fishing_spot != null and is_instance_valid(_fishing_spot):
		_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, false)
	get_viewport().gui_release_focus()
	if restore_controls:
		_restore_controls()
	else:
		_control_snapshot_stored = false
	_apply_mouse_close_policy(reason)
	menu_visibility_changed.emit(false)


func _emit_transition_flurry() -> void:
	_transition_flurry.emit_flurry()


func _fade_backdrop(fade_in: bool) -> void:
	_backdrop_fade_generation += 1
	_cancel_backdrop_fade()
	_dim_background.show()
	var target_alpha: float = BACKDROP_TARGET_ALPHA if fade_in else 0.0
	if is_equal_approx(_dim_background.color.a, target_alpha):
		_finish_backdrop_fade(_backdrop_fade_generation, fade_in)
		return
	var generation: int = _backdrop_fade_generation
	_backdrop_fade = create_tween()
	_backdrop_fade.tween_property(
		_dim_background,
		"color:a",
		target_alpha,
		VISIBILITY_FADE_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_backdrop_fade.finished.connect(
		_finish_backdrop_fade.bind(generation, fade_in),
		CONNECT_ONE_SHOT
	)


func _finish_backdrop_fade(generation: int, faded_in: bool) -> void:
	if generation != _backdrop_fade_generation:
		return
	_backdrop_fade = null
	_dim_background.color.a = (
		BACKDROP_TARGET_ALPHA if faded_in else 0.0
	)
	if not faded_in:
		_dim_background.hide()


func _cancel_backdrop_fade() -> void:
	if _backdrop_fade != null:
		_backdrop_fade.kill()
		_backdrop_fade = null


func _fade_confirmation(
	fade_in: bool,
	completed: Callable,
) -> void:
	_confirmation_fade_generation += 1
	_cancel_confirmation_fade()
	_confirmation_fade_active = true
	_set_confirmation_interactive(false)
	_confirmation_panel.show()
	var target_alpha: float = 1.0 if fade_in else 0.0
	if is_equal_approx(_confirmation_panel.modulate.a, target_alpha):
		_finish_confirmation_fade(
			_confirmation_fade_generation,
			fade_in,
			completed
		)
		return
	var generation: int = _confirmation_fade_generation
	_confirmation_fade = create_tween()
	_confirmation_fade.tween_property(
		_confirmation_panel,
		"modulate:a",
		target_alpha,
		VISIBILITY_FADE_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_confirmation_fade.finished.connect(
		_finish_confirmation_fade.bind(
			generation,
			fade_in,
			completed
		),
		CONNECT_ONE_SHOT
	)


func _finish_confirmation_fade(
	generation: int,
	faded_in: bool,
	completed: Callable,
) -> void:
	if generation != _confirmation_fade_generation or not visible:
		return
	_confirmation_fade = null
	_confirmation_fade_active = false
	_confirmation_panel.modulate.a = 1.0 if faded_in else 0.0
	if not faded_in:
		_confirmation_panel.hide()
	completed.call()


func _cancel_confirmation_fade() -> void:
	_confirmation_fade_generation += 1
	_confirmation_fade_active = false
	if _confirmation_fade != null:
		_confirmation_fade.kill()
		_confirmation_fade = null


func _set_confirmation_interactive(interactive: bool) -> void:
	_confirmation_panel.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if interactive
		else Control.MOUSE_FILTER_IGNORE
	)
	for button: Button in [_confirm_button, _cancel_button]:
		if not interactive and button.has_focus():
			button.release_focus()
		button.focus_mode = (
			Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
		)
		button.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if interactive
			else Control.MOUSE_FILTER_IGNORE
		)


func _update_responsive_pause_stage() -> void:
	if not is_node_ready():
		return
	var display_size := Vector2(
		maxf(1.0, size.x),
		maxf(1.0, size.y)
	)
	var reference_size: Vector2 = (
		PAUSE_COMPACT_REFERENCE_SIZE
		if display_size.y < COMPACT_HEIGHT_THRESHOLD
		else PAUSE_DESKTOP_REFERENCE_SIZE
	)
	var presentation_scale: float = minf(
		display_size.x / reference_size.x,
		display_size.y / reference_size.y
	)
	_presentation_scale_root.size = reference_size
	_presentation_scale_root.scale = Vector2.ONE * presentation_scale
	_presentation_scale_root.position = (
		display_size - reference_size * presentation_scale
	) * 0.5


func _restore_controls() -> void:
	if not _control_snapshot_stored:
		return
	if _player != null and is_instance_valid(_player):
		_player.set_movement_enabled(_prior_movement_enabled)
		_player.set_camera_input_enabled(_prior_camera_enabled)
	_control_snapshot_stored = false


func _apply_mouse_close_policy(reason: CloseReason) -> void:
	if not _mouse_snapshot_stored:
		return
	match reason:
		CloseReason.USER_RETURN, CloseReason.BITE_STARTED:
			Input.mouse_mode = _prior_mouse_mode
		CloseReason.WATER_RECOVERY:
			# Recovery owns local input until it finishes. Keep the current
			# visible gameplay cursor policy without restoring stale state.
			pass
		CloseReason.RETURN_TO_TITLE, CloseReason.RESET_PROGRESS:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		CloseReason.QUIT, CloseReason.TEARDOWN:
			pass
	_mouse_snapshot_stored = false


func _on_bite_activated() -> void:
	if visible:
		close_menu(CloseReason.BITE_STARTED)


func _exit_tree() -> void:
	if visible:
		close_menu(CloseReason.TEARDOWN)
