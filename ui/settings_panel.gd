class_name SettingsPanel
extends PanelContainer

const SettingsManagerType = preload(
	"res://settings/player_settings_manager.gd"
)

signal applied
signal closed

@onready var _auto_click_toggle: CheckButton = %AutoClickToggle
@onready var _auto_click_interval: HSlider = %AutoClickInterval
@onready var _auto_click_interval_value: Label = %AutoClickIntervalValue
@onready var _mouse_sensitivity: HSlider = %MouseSensitivity
@onready var _mouse_sensitivity_value: Label = %MouseSensitivityValue
@onready var _controller_sensitivity: HSlider = %ControllerSensitivity
@onready var _controller_sensitivity_value: Label = %ControllerSensitivityValue
@onready var _invert_y_toggle: CheckButton = %InvertYToggle
@onready var _feedback: Label = %SettingsFeedback

var _settings_manager: SettingsManagerType


func _ready() -> void:
	%ApplySettingsButton.pressed.connect(_apply_settings)
	%CancelSettingsButton.pressed.connect(close_panel)
	_auto_click_interval.value_changed.connect(_refresh_value_labels)
	_mouse_sensitivity.value_changed.connect(_refresh_value_labels)
	_controller_sensitivity.value_changed.connect(_refresh_value_labels)


func open_panel(settings_manager: SettingsManagerType) -> void:
	_settings_manager = settings_manager
	_load_controls()
	_feedback.text = ""
	show()
	_auto_click_toggle.grab_focus()


func close_panel() -> void:
	if not visible:
		return
	hide()
	_load_controls()
	closed.emit()


func _apply_settings() -> void:
	if _settings_manager == null:
		_feedback.text = "settings are unavailable."
		return
	var edited := PlayerSettings.new()
	edited.auto_click_enabled = _auto_click_toggle.button_pressed
	edited.auto_click_interval = float(_auto_click_interval.value)
	edited.mouse_camera_sensitivity = float(_mouse_sensitivity.value)
	edited.controller_camera_sensitivity = float(_controller_sensitivity.value)
	edited.invert_camera_y = _invert_y_toggle.button_pressed
	if _settings_manager.apply_settings(edited):
		hide()
		applied.emit()
	else:
		_feedback.text = "failed to save settings."


func _load_controls() -> void:
	if _settings_manager == null or not is_node_ready():
		return
	var settings: PlayerSettings = _settings_manager.current_settings
	_auto_click_toggle.button_pressed = settings.auto_click_enabled
	_auto_click_interval.value = settings.auto_click_interval
	_mouse_sensitivity.value = settings.mouse_camera_sensitivity
	_controller_sensitivity.value = settings.controller_camera_sensitivity
	_invert_y_toggle.button_pressed = settings.invert_camera_y
	_refresh_value_labels(0.0)


func _refresh_value_labels(_unused: float) -> void:
	_auto_click_interval_value.text = "%.2f s" % _auto_click_interval.value
	_mouse_sensitivity_value.text = "%.4f" % _mouse_sensitivity.value
	_controller_sensitivity_value.text = "%.1f" % _controller_sensitivity.value
