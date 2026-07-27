class_name SettingsPanel
extends PanelContainer

const MAX_PANEL_SIZE: Vector2 = Vector2(720.0, 600.0)
const PANEL_EDGE_MARGIN: float = 16.0
const SettingsManagerType = preload(
	"res://settings/player_settings_manager.gd"
)

signal applied
signal closed
signal crisp_reset_focus_requested
signal panel_visibility_changed(is_visible: bool)

@onready var _auto_click_toggle: CheckButton = %AutoClickToggle
@onready var _auto_click_interval: HSlider = %AutoClickInterval
@onready var _auto_click_interval_value: Label = %AutoClickIntervalValue
@onready var _mouse_sensitivity: HSlider = %MouseSensitivity
@onready var _mouse_sensitivity_value: Label = %MouseSensitivityValue
@onready var _controller_sensitivity: HSlider = %ControllerSensitivity
@onready var _controller_sensitivity_value: Label = %ControllerSensitivityValue
@onready var _invert_y_toggle: CheckButton = %InvertYToggle
@onready var _world_pixel_size: HSlider = %WorldPixelSize
@onready var _world_pixel_size_value: Label = %WorldPixelSizeValue
@onready var _ui_pixel_size: HSlider = %UIPixelSize
@onready var _ui_pixel_size_value: Label = %UIPixelSizeValue
@onready var _feedback: Label = %SettingsFeedback

var _settings_manager: SettingsManagerType
var _loading_controls: bool = false
var _effective_ui_pixel_size: int = PlayerSettings.DEFAULT_UI_PIXEL_SIZE


func _ready() -> void:
	%ApplySettingsButton.pressed.connect(_apply_settings)
	%CancelSettingsButton.pressed.connect(close_panel)
	_auto_click_interval.value_changed.connect(_refresh_value_labels)
	_mouse_sensitivity.value_changed.connect(_refresh_value_labels)
	_controller_sensitivity.value_changed.connect(_refresh_value_labels)
	_world_pixel_size.value_changed.connect(_on_pixel_size_changed)
	_ui_pixel_size.value_changed.connect(_on_pixel_size_changed)
	%CancelSettingsButton.gui_input.connect(_on_back_button_gui_input)
	get_viewport().size_changed.connect(_refresh_panel_size)
	var parent_control := get_parent() as Control
	if parent_control != null:
		parent_control.resized.connect(_refresh_panel_size)
	call_deferred("_refresh_panel_size")


func open_panel(settings_manager: SettingsManagerType) -> void:
	_settings_manager = settings_manager
	_load_controls()
	_feedback.text = ""
	show()
	panel_visibility_changed.emit(true)
	_auto_click_toggle.grab_focus()


func close_panel() -> void:
	if not visible:
		return
	hide()
	panel_visibility_changed.emit(false)
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
	edited.world_pixel_size = roundi(_world_pixel_size.value)
	edited.ui_pixel_size = roundi(_ui_pixel_size.value)
	if _settings_manager.apply_settings(edited):
		hide()
		panel_visibility_changed.emit(false)
		applied.emit()
	else:
		_feedback.text = "failed to save settings."


func _load_controls() -> void:
	if _settings_manager == null or not is_node_ready():
		return
	_loading_controls = true
	var settings: PlayerSettings = _settings_manager.current_settings
	_auto_click_toggle.button_pressed = settings.auto_click_enabled
	_auto_click_interval.value = settings.auto_click_interval
	_mouse_sensitivity.value = settings.mouse_camera_sensitivity
	_controller_sensitivity.value = settings.controller_camera_sensitivity
	_invert_y_toggle.button_pressed = settings.invert_camera_y
	_world_pixel_size.value = settings.world_pixel_size
	_ui_pixel_size.value = settings.ui_pixel_size
	_loading_controls = false
	_refresh_value_labels(0.0)


func _refresh_value_labels(_unused: float) -> void:
	_auto_click_interval_value.text = "%.2f s" % _auto_click_interval.value
	_mouse_sensitivity_value.text = "%.4f" % _mouse_sensitivity.value
	_controller_sensitivity_value.text = "%.1f" % _controller_sensitivity.value
	_world_pixel_size_value.text = _pixel_size_label(
		roundi(_world_pixel_size.value),
		true
	)
	_ui_pixel_size_value.text = _pixel_size_label(
		roundi(_ui_pixel_size.value),
		false
	)


func _on_pixel_size_changed(_unused: float) -> void:
	_refresh_value_labels(0.0)
	if _loading_controls or _settings_manager == null:
		return
	if not _settings_manager.apply_pixelation(
		roundi(_world_pixel_size.value),
		roundi(_ui_pixel_size.value)
	):
		_feedback.text = "failed to save pixelation settings."


func _pixel_size_label(pixel_size: int, _is_world: bool) -> String:
	var names: PackedStringArray = [
		"legible",
		"cute",
		"retro",
		"hardcore",
		"wtf",
	]
	var index: int = clampi(pixel_size - 1, 0, names.size() - 1)
	return names[index]


func set_effective_ui_pixel_size(pixel_size: int) -> void:
	_effective_ui_pixel_size = clampi(
		pixel_size,
		PlayerSettings.MIN_UI_PIXEL_SIZE,
		PlayerSettings.MAX_UI_PIXEL_SIZE
	)
	if is_node_ready():
		_refresh_value_labels(0.0)


func focus_back_button() -> void:
	%CancelSettingsButton.grab_focus()


func refresh_open_panel() -> void:
	if visible:
		_load_controls()


func _on_back_button_gui_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("ui_down")
		or event.is_action_pressed("ui_focus_next")
	):
		crisp_reset_focus_requested.emit()
		accept_event()


func _refresh_panel_size() -> void:
	if not is_node_ready():
		return
	var parent_control := get_parent() as Control
	if parent_control == null:
		return
	var available_size: Vector2 = parent_control.size - Vector2.ONE * (
		PANEL_EDGE_MARGIN * 2.0
	)
	var target_size := Vector2(
		minf(MAX_PANEL_SIZE.x, maxf(320.0, available_size.x)),
		minf(MAX_PANEL_SIZE.y, maxf(240.0, available_size.y))
	)
	custom_minimum_size = target_size
	if parent_control is CenterContainer:
		return
	set_anchors_preset(Control.PRESET_CENTER)
	position = (parent_control.size - target_size) * 0.5
	size = target_size
