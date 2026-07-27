class_name PauseMenu
extends Control

const INPUT_OWNER: StringName = &"game_menu"
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

@onready var _root_panel: PanelContainer = %RootPanel
@onready var _settings_panel: SettingsPanelType = %SettingsPanel
@onready var _confirmation_panel: PanelContainer = %ConfirmationPanel
@onready var _confirmation_title: Label = %ConfirmationTitle
@onready var _confirmation_text: Label = %ConfirmationText
@onready var _confirm_button: Button = %ConfirmButton
@onready var _cancel_button: Button = %CancelConfirmButton
@onready var _feedback: Label = %FeedbackLabel
@onready var _save_button: Button = %SaveButton

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
	_root_panel.show()
	_settings_panel.hide()
	_confirmation_panel.hide()
	_confirmation_action = ConfirmationAction.NONE
	show()
	%ResumeButton.grab_focus()
	menu_visibility_changed.emit(true)


func resume() -> void:
	if not visible or _action_in_progress:
		return
	close_menu(CloseReason.USER_RETURN)


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
	if _settings_panel.visible:
		_settings_panel.close_panel()
	hide()
	_root_panel.show()
	_settings_panel.hide()
	_confirmation_panel.hide()
	_confirmation_action = ConfirmationAction.NONE
	_action_in_progress = false
	if _fishing_spot != null and is_instance_valid(_fishing_spot):
		_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, false)
	get_viewport().gui_release_focus()
	if restore_controls:
		_restore_controls()
	else:
		_control_snapshot_stored = false
	_apply_mouse_close_policy(reason)
	menu_visibility_changed.emit(false)


func handle_escape() -> bool:
	if not visible:
		return false
	if _confirmation_panel.visible:
		_close_confirmation()
	elif _settings_panel.visible:
		_settings_panel.close_panel()
	else:
		resume()
	return true


func _save_now() -> void:
	if _action_in_progress:
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
	if _action_in_progress or _confirmation_panel.visible:
		return
	_root_panel.hide()
	_settings_panel.open_panel(_settings_manager)


func _on_settings_applied() -> void:
	_root_panel.show()
	_feedback.text = "settings saved."
	%SettingsButton.grab_focus()


func _on_settings_closed() -> void:
	_root_panel.show()
	%SettingsButton.grab_focus()


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
	if _action_in_progress:
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
	if _action_in_progress:
		return
	_confirmation_action = action
	_confirmation_title.text = title
	_confirmation_text.text = message
	_confirm_button.text = confirm_text
	_confirm_button.theme_type_variation = (
		&"DangerButton" if dangerous else StringName()
	)
	_root_panel.hide()
	_confirmation_panel.show()
	if dangerous:
		_cancel_button.grab_focus()
	else:
		_confirm_button.grab_focus()


func _close_confirmation() -> void:
	_confirmation_action = ConfirmationAction.NONE
	_confirmation_panel.hide()
	_root_panel.show()
	%ResumeButton.grab_focus()


func _accept_confirmation() -> void:
	if _action_in_progress:
		return
	var action: ConfirmationAction = _confirmation_action
	_confirmation_action = ConfirmationAction.NONE
	_confirmation_panel.hide()
	_action_in_progress = true
	match action:
		ConfirmationAction.RETURN_TO_TITLE:
			if _save_manager.save_now():
				return_to_title_requested.emit()
			else:
				_feedback.text = "save failed. previous save was preserved."
				_root_panel.show()
		ConfirmationAction.RESET_PROGRESS:
			reset_progress_requested.emit()
		ConfirmationAction.QUIT_ANYWAY:
			quit_requested.emit()
		_:
			_root_panel.show()
	_action_in_progress = false


func report_reset_failure() -> void:
	_action_in_progress = false
	_root_panel.show()
	_confirmation_panel.hide()
	_feedback.text = "reset failed. your progression was preserved."
	%ResumeButton.grab_focus()


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
