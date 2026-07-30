class_name PlayerSettings
extends Resource

const MIN_AUTO_CLICK_INTERVAL: float = 0.10
const MAX_AUTO_CLICK_INTERVAL: float = 0.50
const MIN_MOUSE_SENSITIVITY: float = 0.001
const MAX_MOUSE_SENSITIVITY: float = 0.012
const MIN_CONTROLLER_SENSITIVITY: float = 0.5
const MAX_CONTROLLER_SENSITIVITY: float = 5.0
const MIN_WORLD_PIXEL_SIZE: int = 1
const MAX_WORLD_PIXEL_SIZE: int = 5
const DEFAULT_WORLD_PIXEL_SIZE: int = 3
const MIN_UI_PIXEL_SIZE: int = 1
const MAX_UI_PIXEL_SIZE: int = 5
const DEFAULT_UI_PIXEL_SIZE: int = 3
const COMPACT_DISPLAY_HEIGHT: int = 560
const WORLD_DESKTOP_GRID_HEIGHTS: Array[int] = [0, 540, 360, 216, 96]
const WORLD_COMPACT_GRID_HEIGHTS: Array[int] = [0, 360, 240, 144, 72]
const UI_DESKTOP_RENDER_HEIGHTS: Array[int] = [0, 612, 504, 396, 288]
const UI_COMPACT_RENDER_HEIGHTS: Array[int] = [0, 408, 336, 264, 192]

@export var auto_click_enabled: bool = false
@export var use_readable_interface_font: bool = false
@export_range(0.10, 0.50, 0.01) var auto_click_interval: float = 0.20
@export_range(0.001, 0.012, 0.0005) var mouse_camera_sensitivity: float = 0.005
@export_range(0.5, 5.0, 0.1) var controller_camera_sensitivity: float = 2.5
@export var invert_camera_y: bool = false
@export_range(1, 5, 1) var world_pixel_size: int = DEFAULT_WORLD_PIXEL_SIZE
@export_range(1, 5, 1) var ui_pixel_size: int = DEFAULT_UI_PIXEL_SIZE


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
		and world_pixel_size >= MIN_WORLD_PIXEL_SIZE
		and world_pixel_size <= MAX_WORLD_PIXEL_SIZE
		and ui_pixel_size >= MIN_UI_PIXEL_SIZE
		and ui_pixel_size <= MAX_UI_PIXEL_SIZE
	)


func copy() -> PlayerSettings:
	var result := PlayerSettings.new()
	result.auto_click_enabled = auto_click_enabled
	result.use_readable_interface_font = use_readable_interface_font
	result.auto_click_interval = auto_click_interval
	result.mouse_camera_sensitivity = mouse_camera_sensitivity
	result.controller_camera_sensitivity = controller_camera_sensitivity
	result.invert_camera_y = invert_camera_y
	result.world_pixel_size = world_pixel_size
	result.ui_pixel_size = ui_pixel_size
	return result


static func get_world_grid_height(
	pixel_size: int,
	displayed_height: int,
) -> int:
	var index: int = clampi(
		pixel_size,
		MIN_WORLD_PIXEL_SIZE,
		MAX_WORLD_PIXEL_SIZE
	) - 1
	if index == 0:
		return maxi(1, displayed_height)
	var targets: Array[int] = (
		WORLD_COMPACT_GRID_HEIGHTS
		if displayed_height < COMPACT_DISPLAY_HEIGHT
		else WORLD_DESKTOP_GRID_HEIGHTS
	)
	return mini(maxi(1, displayed_height), targets[index])


static func get_world_grid_size(
	pixel_size: int,
	displayed_size: Vector2i,
) -> Vector2i:
	var safe_size := Vector2i(
		maxi(1, displayed_size.x),
		maxi(1, displayed_size.y)
	)
	var target_height: int = get_world_grid_height(
		pixel_size,
		safe_size.y
	)
	return Vector2i(
		maxi(
			1,
			roundi(
				float(target_height)
				* float(safe_size.x)
				/ float(safe_size.y)
			)
		),
		target_height
	)


static func get_ui_render_height(
	pixel_size: int,
	displayed_height: int,
) -> int:
	var index: int = clampi(
		pixel_size,
		MIN_UI_PIXEL_SIZE,
		MAX_UI_PIXEL_SIZE
	) - 1
	if index == 0:
		return maxi(1, displayed_height)
	var targets: Array[int] = (
		UI_COMPACT_RENDER_HEIGHTS
		if displayed_height < COMPACT_DISPLAY_HEIGHT
		else UI_DESKTOP_RENDER_HEIGHTS
	)
	return mini(maxi(1, displayed_height), targets[index])


static func get_ui_render_size(
	pixel_size: int,
	displayed_size: Vector2i,
) -> Vector2i:
	var safe_size := Vector2i(
		maxi(1, displayed_size.x),
		maxi(1, displayed_size.y)
	)
	var target_height: int = get_ui_render_height(
		pixel_size,
		safe_size.y
	)
	return Vector2i(
		maxi(
			1,
			roundi(
				float(target_height)
				* float(safe_size.x)
				/ float(safe_size.y)
			)
		),
		target_height
	)
