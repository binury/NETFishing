class_name TitleScreen
extends Control

const SaveInspectionType = preload("res://save/player_save_inspection.gd")
const SaveManagerType = preload("res://save/player_save_manager.gd")
const SettingsManagerType = preload(
	"res://settings/player_settings_manager.gd"
)
const SettingsPanelType = preload("res://ui/settings_panel.gd")

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
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _confirmation_panel: PanelContainer = %ConfirmationPanel
@onready var _confirmation_text: Label = %ConfirmationText
@onready var _confirm_button: Button = %ConfirmButton
@onready var _settings_panel: SettingsPanelType = %SettingsPanel

var _save_manager: SaveManagerType
var _settings_manager: SettingsManagerType
var _inspection: SaveInspectionType
var _confirmation_action: ConfirmationAction = ConfirmationAction.NONE
var _action_in_progress: bool = false


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


func setup(
	save_manager: SaveManagerType,
	settings_manager: SettingsManagerType,
) -> void:
	_save_manager = save_manager
	_settings_manager = settings_manager
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh_save_inspection()
	show()
	call_deferred("_focus_initial_button")


func reopen() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_close_confirmation()
	_settings_panel.hide()
	_refresh_save_inspection()
	show()
	call_deferred("_focus_initial_button")


func _input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if _confirmation_panel.visible:
		_close_confirmation()
	elif _settings_panel.visible:
		_close_settings()
	else:
		return
	get_viewport().set_input_as_handled()


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
		_feedback_label.text = "Save loaded."
		gameplay_requested.emit()
	else:
		_refresh_save_inspection()
		_feedback_label.text = "Failed to load save. The original was preserved."
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
			"This save is from a newer game version. "
			+ "Use Delete Save before starting over."
		)
		return
	if _inspection.status == SaveInspectionType.Status.IO_ERROR:
		_feedback_label.text = "The existing save cannot be accessed safely."
		return
	_open_confirmation(
		ConfirmationAction.NEW_GAME,
		"Start a new game? Existing progression will be deleted.",
		"Start New Game"
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
		"Delete your saved progression? This cannot be undone.",
		"Delete"
	)


func _on_confirmation_accepted() -> void:
	if _action_in_progress:
		return
	var action: ConfirmationAction = _confirmation_action
	_close_confirmation()
	_action_in_progress = true
	if not _save_manager.delete_progression_save():
		_feedback_label.text = "Failed to delete saved progression."
		_action_in_progress = false
		_refresh_save_inspection()
		return
	_save_manager.initialize_new_game()
	_refresh_save_inspection()
	if action == ConfirmationAction.NEW_GAME:
		gameplay_requested.emit()
	else:
		_feedback_label.text = "Saved progression deleted."
	_action_in_progress = false


func _open_confirmation(
	action: ConfirmationAction,
	message: String,
	confirm_text: String,
) -> void:
	_confirmation_action = action
	_confirmation_text.text = message
	_confirm_button.text = confirm_text
	_confirmation_panel.visible = true
	_confirm_button.grab_focus()


func _close_confirmation() -> void:
	_confirmation_action = ConfirmationAction.NONE
	_confirmation_panel.visible = false
	_focus_initial_button()


func _open_settings() -> void:
	if _confirmation_panel.visible or _action_in_progress:
		return
	_feedback_label.text = ""
	_settings_panel.open_panel(_settings_manager)


func _close_settings() -> void:
	_settings_panel.close_panel()


func _on_settings_applied() -> void:
	_feedback_label.text = "Settings saved."
	_settings_button.grab_focus()


func _on_settings_closed() -> void:
	_settings_button.grab_focus()


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
	if not is_node_ready() or not visible:
		return
	if not _continue_button.disabled:
		_continue_button.grab_focus()
	else:
		_new_game_button.grab_focus()


func _on_quit_pressed() -> void:
	if (
		not _action_in_progress
		and not _confirmation_panel.visible
		and not _settings_panel.visible
	):
		quit_requested.emit()
