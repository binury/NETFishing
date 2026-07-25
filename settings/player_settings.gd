class_name PlayerSettings
extends Resource

const MIN_AUTO_CLICK_INTERVAL: float = 0.10
const MAX_AUTO_CLICK_INTERVAL: float = 0.50
const MIN_MOUSE_SENSITIVITY: float = 0.001
const MAX_MOUSE_SENSITIVITY: float = 0.012
const MIN_CONTROLLER_SENSITIVITY: float = 0.5
const MAX_CONTROLLER_SENSITIVITY: float = 5.0

@export var auto_click_enabled: bool = false
@export_range(0.10, 0.50, 0.01) var auto_click_interval: float = 0.20
@export_range(0.001, 0.012, 0.0005) var mouse_camera_sensitivity: float = 0.005
@export_range(0.5, 5.0, 0.1) var controller_camera_sensitivity: float = 2.5
@export var invert_camera_y: bool = false


func is_valid() -> bool:
	return (
		is_finite(auto_click_interval)
		and auto_click_interval >= MIN_AUTO_CLICK_INTERVAL
		and auto_click_interval <= MAX_AUTO_CLICK_INTERVAL
		and is_finite(mouse_camera_sensitivity)
		and mouse_camera_sensitivity >= MIN_MOUSE_SENSITIVITY
		and mouse_camera_sensitivity <= MAX_MOUSE_SENSITIVITY
		and is_finite(controller_camera_sensitivity)
		and controller_camera_sensitivity >= MIN_CONTROLLER_SENSITIVITY
		and controller_camera_sensitivity <= MAX_CONTROLLER_SENSITIVITY
	)


func copy() -> PlayerSettings:
	var result := PlayerSettings.new()
	result.auto_click_enabled = auto_click_enabled
	result.auto_click_interval = auto_click_interval
	result.mouse_camera_sensitivity = mouse_camera_sensitivity
	result.controller_camera_sensitivity = controller_camera_sensitivity
	result.invert_camera_y = invert_camera_y
	return result
