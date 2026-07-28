class_name SettingsPanel
extends Control

const MAX_PANEL_SIZE: Vector2 = Vector2(960.0, 700.0)
const PANEL_EDGE_MARGIN: float = 16.0
const PAGE_ROOT: StringName = &"root"
const PAGE_DISPLAY: StringName = &"display"
const PAGE_CONTROLS: StringName = &"controls"
const PAGE_ACCESSIBILITY: StringName = &"accessibility"
const TITLE_HOST_OUTGOING_DURATION: float = 1.70
const TITLE_HOST_INCOMING_DURATION: float = 1.80
const PIXELATION_NAMES: PackedStringArray = [
	"legible",
	"cute",
	"retro",
	"hardcore",
	"wtf",
]
const SettingsManagerType = preload(
	"res://settings/player_settings_manager.gd"
)

signal applied
signal closed
signal opened
signal crisp_reset_focus_requested
signal panel_visibility_changed(is_visible: bool)
signal navigation_transition_started

enum PresentationMode {
	TITLE_EMBEDDED,
	GAMEPLAY_MODAL,
}

@onready var _backdrop: ColorRect = $Backdrop
@onready var _root_page: SettingsBubblePage = %RootPage
@onready var _display_page: SettingsBubblePage = %DisplayPage
@onready var _controls_page: SettingsBubblePage = %ControlsPage
@onready var _accessibility_page: SettingsBubblePage = %AccessibilityPage
@onready var _feedback: Label = %SettingsFeedback

@onready var _world_value: BubbleButton = %WorldValue
@onready var _ui_value: BubbleButton = %UIValue
@onready var _mouse_value: BubbleButton = %MouseValue
@onready var _controller_value: BubbleButton = %ControllerValue
@onready var _invert_y_toggle: BubbleButton = %InvertYToggle
@onready var _auto_click_toggle: BubbleButton = %AutoClickToggle
@onready var _auto_click_interval: BubbleButton = %AutoClickIntervalValue

@onready var _world_options: Array[BubbleButton] = [
	%WorldLegible,
	%WorldCute,
	%WorldRetro,
	%WorldHardcore,
	%WorldWtf,
]
@onready var _ui_options: Array[BubbleButton] = [
	%UILegible,
	%UICute,
	%UIRetro,
	%UIHardcore,
	%UIWtf,
]

var _settings_manager: SettingsManagerType
var _effective_ui_pixel_size: int = PlayerSettings.DEFAULT_UI_PIXEL_SIZE
var _page_stack: Array[StringName] = []
var _pages: Dictionary[StringName, SettingsBubblePage] = {}
var _page_transition_generation: int = 0
var _page_transition_active: bool = false
var _presentation_mode: PresentationMode = PresentationMode.GAMEPLAY_MODAL
var _auto_click_enabled: bool = false
var _auto_click_interval_value: float = 0.20
var _mouse_sensitivity: float = 0.005
var _controller_sensitivity: float = 2.5
var _invert_camera_y: bool = false


func _ready() -> void:
	_pages = {
		PAGE_ROOT: _root_page,
		PAGE_DISPLAY: _display_page,
		PAGE_CONTROLS: _controls_page,
		PAGE_ACCESSIBILITY: _accessibility_page,
	}
	%DisplayCategory.pressed.connect(_push_page.bind(PAGE_DISPLAY))
	%ControlsCategory.pressed.connect(_push_page.bind(PAGE_CONTROLS))
	%AccessibilityCategory.pressed.connect(
		_push_page.bind(PAGE_ACCESSIBILITY)
	)
	%ApplySettingsButton.pressed.connect(_apply_settings)
	%RootBackButton.pressed.connect(close_panel)
	%DisplayBackButton.pressed.connect(handle_back)
	%ControlsBackButton.pressed.connect(handle_back)
	%AccessibilityBackButton.pressed.connect(handle_back)
	%RootBackButton.gui_input.connect(_on_back_bubble_gui_input)
	%DisplayBackButton.gui_input.connect(_on_back_bubble_gui_input)
	%ControlsBackButton.gui_input.connect(_on_back_bubble_gui_input)
	%AccessibilityBackButton.gui_input.connect(_on_back_bubble_gui_input)
	for index: int in _world_options.size():
		_world_options[index].pressed.connect(
			_set_world_pixelation.bind(index + 1)
		)
	for index: int in _ui_options.size():
		_ui_options[index].pressed.connect(
			_set_ui_pixelation.bind(index + 1)
		)
	%MouseDecrease.pressed.connect(_adjust_mouse_sensitivity.bind(-1))
	%MouseIncrease.pressed.connect(_adjust_mouse_sensitivity.bind(1))
	_mouse_value.pressed.connect(_adjust_mouse_sensitivity.bind(1))
	%ControllerDecrease.pressed.connect(
		_adjust_controller_sensitivity.bind(-1)
	)
	%ControllerIncrease.pressed.connect(
		_adjust_controller_sensitivity.bind(1)
	)
	_controller_value.pressed.connect(
		_adjust_controller_sensitivity.bind(1)
	)
	_invert_y_toggle.pressed.connect(_toggle_invert_y)
	_auto_click_toggle.pressed.connect(_toggle_auto_click)
	%IntervalDecrease.pressed.connect(_adjust_auto_click_interval.bind(-1))
	%IntervalIncrease.pressed.connect(_adjust_auto_click_interval.bind(1))
	_auto_click_interval.pressed.connect(
		_adjust_auto_click_interval.bind(1)
	)
	_mouse_value.gui_input.connect(
		_on_continuous_value_input.bind(&"mouse")
	)
	_controller_value.gui_input.connect(
		_on_continuous_value_input.bind(&"controller")
	)
	_auto_click_interval.gui_input.connect(
		_on_continuous_value_input.bind(&"interval")
	)
	resized.connect(_refresh_panel_size)
	var parent_control := get_parent() as Control
	if parent_control != null:
		parent_control.resized.connect(_refresh_panel_size)
	for page: SettingsBubblePage in _pages.values():
		page.hide_page()
	call_deferred("_refresh_panel_size")


func open_panel(
	settings_manager: SettingsManagerType,
	presentation_mode: PresentationMode = PresentationMode.GAMEPLAY_MODAL,
) -> void:
	_cancel_page_transition()
	_presentation_mode = presentation_mode
	_backdrop.visible = presentation_mode == PresentationMode.GAMEPLAY_MODAL
	_settings_manager = settings_manager
	_load_controls()
	_feedback.text = ""
	show()
	_page_stack.clear()
	_page_stack.append(PAGE_ROOT)
	panel_visibility_changed.emit(true)
	if presentation_mode == PresentationMode.TITLE_EMBEDDED:
		for page: SettingsBubblePage in _pages.values():
			page.hide_page()
		_page_transition_generation += 1
		_page_transition_active = true
		var generation: int = _page_transition_generation
		_root_page.transition_in(
			true,
			_finish_embedded_open.bind(generation),
			TITLE_HOST_INCOMING_DURATION
		)
	else:
		_show_active_page(true)
		opened.emit()


func close_panel() -> void:
	if not visible:
		return
	if _presentation_mode == PresentationMode.TITLE_EMBEDDED:
		if _page_transition_active:
			return
		_begin_embedded_close(false)
		return
	_finish_panel_close(false)


func _finish_panel_close(applied_result: bool) -> void:
	_cancel_page_transition()
	for page: SettingsBubblePage in _pages.values():
		page.hide_page()
	_page_stack.clear()
	hide()
	panel_visibility_changed.emit(false)
	if applied_result:
		applied.emit()
	else:
		_load_controls()
		closed.emit()


func handle_back() -> void:
	if _page_transition_active:
		return
	if _page_stack.size() > 1:
		_start_page_transition(_page_stack[-2], false)
		return
	close_panel()


func get_active_page_id() -> StringName:
	return _page_stack.back() if not _page_stack.is_empty() else StringName()


func _push_page(page_id: StringName) -> void:
	if (
		_page_transition_active
		or not _pages.has(page_id)
		or get_active_page_id() == page_id
	):
		return
	_start_page_transition(page_id, true)


func _start_page_transition(page_id: StringName, push_page: bool) -> void:
	var outgoing_page: SettingsBubblePage = _get_active_page()
	var incoming_page: SettingsBubblePage = _pages.get(page_id)
	if outgoing_page == null or incoming_page == null:
		return
	_page_transition_generation += 1
	_page_transition_active = true
	navigation_transition_started.emit()
	var generation: int = _page_transition_generation
	outgoing_page.transition_out(
		_finish_outgoing_page.bind(
			generation,
			page_id,
			push_page,
			incoming_page
		)
	)


func _finish_outgoing_page(
	generation: int,
	page_id: StringName,
	push_page: bool,
	incoming_page: SettingsBubblePage,
) -> void:
	if generation != _page_transition_generation or not _page_transition_active:
		return
	if push_page:
		_page_stack.append(page_id)
	else:
		_page_stack.pop_back()
	for page: SettingsBubblePage in _pages.values():
		if page != incoming_page:
			page.hide_page()
	incoming_page.transition_in(
		true,
		_finish_incoming_page.bind(generation)
	)


func _finish_incoming_page(generation: int) -> void:
	if generation != _page_transition_generation or not _page_transition_active:
		return
	_page_transition_active = false


func _finish_embedded_open(generation: int) -> void:
	if generation != _page_transition_generation or not _page_transition_active:
		return
	_page_transition_active = false
	opened.emit()


func _begin_embedded_close(applied_result: bool) -> void:
	var active_page: SettingsBubblePage = _get_active_page()
	if active_page == null:
		return
	_page_transition_generation += 1
	_page_transition_active = true
	navigation_transition_started.emit()
	var generation: int = _page_transition_generation
	active_page.transition_out(
		_finish_embedded_close.bind(generation, applied_result),
		TITLE_HOST_OUTGOING_DURATION
	)


func _finish_embedded_close(
	generation: int,
	applied_result: bool,
) -> void:
	if generation != _page_transition_generation or not _page_transition_active:
		return
	_finish_panel_close(applied_result)


func _cancel_page_transition() -> void:
	_page_transition_generation += 1
	_page_transition_active = false


func _show_active_page(should_focus: bool) -> void:
	for page_id: StringName in _pages:
		var page: SettingsBubblePage = _pages[page_id]
		if page_id == get_active_page_id():
			page.show_page(should_focus)
		else:
			page.hide_page()


func _get_active_page() -> SettingsBubblePage:
	return _pages.get(get_active_page_id()) as SettingsBubblePage


func _apply_settings() -> void:
	if _page_transition_active:
		return
	if _settings_manager == null:
		_feedback.text = "settings are unavailable."
		return
	var edited := PlayerSettings.new()
	edited.auto_click_enabled = _auto_click_enabled
	edited.auto_click_interval = _auto_click_interval_value
	edited.mouse_camera_sensitivity = _mouse_sensitivity
	edited.controller_camera_sensitivity = _controller_sensitivity
	edited.invert_camera_y = _invert_camera_y
	edited.world_pixel_size = _settings_manager.current_settings.world_pixel_size
	edited.ui_pixel_size = _settings_manager.current_settings.ui_pixel_size
	if _settings_manager.apply_settings(edited):
		if _presentation_mode == PresentationMode.TITLE_EMBEDDED:
			_begin_embedded_close(true)
		else:
			_finish_panel_close(true)
	else:
		_feedback.text = "failed to save settings."


func _load_controls() -> void:
	if _settings_manager == null or not is_node_ready():
		return
	var settings: PlayerSettings = _settings_manager.current_settings
	_auto_click_enabled = settings.auto_click_enabled
	_auto_click_interval_value = settings.auto_click_interval
	_mouse_sensitivity = settings.mouse_camera_sensitivity
	_controller_sensitivity = settings.controller_camera_sensitivity
	_invert_camera_y = settings.invert_camera_y
	_refresh_value_labels()


func _refresh_value_labels() -> void:
	if _settings_manager == null:
		return
	var settings: PlayerSettings = _settings_manager.current_settings
	_world_value.text = (
		"world\npixelation\n"
		+ _pixel_size_label(settings.world_pixel_size)
	)
	_ui_value.text = (
		"ui\npixelation\n"
		+ _pixel_size_label(settings.ui_pixel_size)
	)
	_mouse_value.text = "mouse\nsensitivity\n%.4f" % _mouse_sensitivity
	_controller_value.text = (
		"controller\nsensitivity\n%.1f" % _controller_sensitivity
	)
	_invert_y_toggle.text = (
		"invert\nvertical\ncamera\n"
		+ ("on" if _invert_camera_y else "off")
	)
	_auto_click_toggle.text = (
		"accessibility\nauto-click\n"
		+ ("on" if _auto_click_enabled else "off")
	)
	_auto_click_interval.text = (
		"auto-click\ninterval\n%.2f s" % _auto_click_interval_value
	)
	for index: int in _world_options.size():
		_world_options[index].button_pressed = (
			index + 1 == settings.world_pixel_size
		)
	for index: int in _ui_options.size():
		_ui_options[index].button_pressed = index + 1 == settings.ui_pixel_size


func _set_world_pixelation(pixel_size: int) -> void:
	if _settings_manager == null:
		return
	if not _settings_manager.apply_pixelation(
		pixel_size,
		_settings_manager.current_settings.ui_pixel_size
	):
		_feedback.text = "failed to save pixelation settings."
		return
	_refresh_value_labels()


func _set_ui_pixelation(pixel_size: int) -> void:
	if _settings_manager == null:
		return
	if not _settings_manager.apply_pixelation(
		_settings_manager.current_settings.world_pixel_size,
		pixel_size
	):
		_feedback.text = "failed to save pixelation settings."
		return
	_refresh_value_labels()


func _adjust_mouse_sensitivity(direction: int) -> void:
	_mouse_sensitivity = clampf(
		_mouse_sensitivity + float(direction) * 0.0005,
		PlayerSettings.MIN_MOUSE_SENSITIVITY,
		PlayerSettings.MAX_MOUSE_SENSITIVITY
	)
	_refresh_value_labels()


func _adjust_controller_sensitivity(direction: int) -> void:
	_controller_sensitivity = clampf(
		_controller_sensitivity + float(direction) * 0.1,
		PlayerSettings.MIN_CONTROLLER_SENSITIVITY,
		PlayerSettings.MAX_CONTROLLER_SENSITIVITY
	)
	_refresh_value_labels()


func _adjust_auto_click_interval(direction: int) -> void:
	_auto_click_interval_value = clampf(
		_auto_click_interval_value + float(direction) * 0.01,
		PlayerSettings.MIN_AUTO_CLICK_INTERVAL,
		PlayerSettings.MAX_AUTO_CLICK_INTERVAL
	)
	_refresh_value_labels()


func _toggle_invert_y() -> void:
	_invert_camera_y = not _invert_camera_y
	_refresh_value_labels()


func _toggle_auto_click() -> void:
	_auto_click_enabled = not _auto_click_enabled
	_refresh_value_labels()


func _on_continuous_value_input(
	event: InputEvent,
	control_id: StringName,
) -> void:
	var direction: int = 0
	if event.is_action_pressed("ui_left"):
		direction = -1
	elif event.is_action_pressed("ui_right"):
		direction = 1
	if direction == 0:
		return
	match control_id:
		&"mouse":
			_adjust_mouse_sensitivity(direction)
		&"controller":
			_adjust_controller_sensitivity(direction)
		&"interval":
			_adjust_auto_click_interval(direction)
	accept_event()


func _pixel_size_label(pixel_size: int) -> String:
	var index: int = clampi(
		pixel_size - 1,
		0,
		PIXELATION_NAMES.size() - 1
	)
	return PIXELATION_NAMES[index]


func set_effective_ui_pixel_size(pixel_size: int) -> void:
	_effective_ui_pixel_size = clampi(
		pixel_size,
		PlayerSettings.MIN_UI_PIXEL_SIZE,
		PlayerSettings.MAX_UI_PIXEL_SIZE
	)
	if is_node_ready():
		_refresh_value_labels()


func focus_back_button() -> void:
	var active_page: SettingsBubblePage = _get_active_page()
	if active_page != null:
		active_page.focus_back()


func _on_back_bubble_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_focus_next"):
		crisp_reset_focus_requested.emit()
		accept_event()


func refresh_open_panel() -> void:
	if visible:
		_load_controls()


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
