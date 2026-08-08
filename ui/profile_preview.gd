class_name ProfilePreview
extends SubViewportContainer

const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const UIReferencePresentationType = preload(
	"res://ui/ui_reference_presentation.gd"
)
const FRONT_FACING_YAW: float = PI
const DEFAULT_CAMERA_DISTANCE: float = 1.9
const DEFAULT_CAMERA_PITCH: float = 0.12
const MIN_CAMERA_DISTANCE: float = 1.05
const MAX_CAMERA_DISTANCE: float = 2.8
const CAMERA_ZOOM_STEP: float = 0.14
const CAMERA_TARGET_HEIGHT: float = 0.95

@export_range(0.1, 2.0, 0.05) var drag_sensitivity: float = 0.012
@export_range(0.1, 4.0, 0.1) var keyboard_speed: float = 1.8

@onready var _preview_root: Node3D = %PreviewRoot
@onready var _preview_environment: WorldEnvironment = %WorldEnvironment
@onready var _preview_sun: DirectionalLight3D = %KeyLight
@onready var _preview_camera: Camera3D = $Viewport/Camera3D
@onready var _pixelation_material: ShaderMaterial = material as ShaderMaterial

var _dragging: bool = false
var _camera_yaw: float = 0.0
var _camera_pitch: float = DEFAULT_CAMERA_PITCH
var _camera_distance: float = DEFAULT_CAMERA_DISTANCE
var _visuals: Node3D
var _controller_mapping_manager: ControllerMappingManagerType
var _source_environment: WorldEnvironment
var _source_sun: DirectionalLight3D
var _world_pixel_size: int = PlayerSettings.DEFAULT_WORLD_PIXEL_SIZE


func setup_controller_mapping(
	mapping_manager: ControllerMappingManagerType,
) -> void:
	_controller_mapping_manager = mapping_manager


func setup_world_lighting(
	world_environment: WorldEnvironment,
	world_sun: DirectionalLight3D,
) -> void:
	_source_environment = world_environment
	_source_sun = world_sun
	_sync_world_lighting()


func set_world_pixel_size(pixel_size: int) -> void:
	_world_pixel_size = clampi(
		pixel_size,
		PlayerSettings.MIN_WORLD_PIXEL_SIZE,
		PlayerSettings.MAX_WORLD_PIXEL_SIZE,
	)
	_refresh_pixelation_filter()


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gui_input.connect(_on_gui_input)
	resized.connect(_refresh_pixelation_filter)
	get_window().size_changed.connect(_refresh_pixelation_filter)
	_configure_preview_lighting()
	reset_view()
	_visuals = PlayerVisualPresenter.instantiate_visuals()
	_preview_root.add_child(_visuals)
	var rod := _visuals.find_child("FishingRod", true, false) as Node3D
	if rod != null:
		rod.visible = false
	var catch_display := _visuals.find_child("CatchDisplay", true, false) as Node3D
	if catch_display != null:
		catch_display.visible = false
	call_deferred("_refresh_pixelation_filter")


func apply_appearance_profile(profile: Dictionary) -> void:
	if _visuals != null:
		PlayerVisualPresenter.apply_appearance(_visuals, profile)


func reset_view() -> void:
	_preview_root.rotation.y = FRONT_FACING_YAW
	_camera_yaw = 0.0
	_camera_pitch = DEFAULT_CAMERA_PITCH
	_camera_distance = DEFAULT_CAMERA_DISTANCE
	_apply_camera_orbit()


func _process(delta: float) -> void:
	_sync_world_lighting()
	if not has_focus():
		return
	var axis := Input.get_axis("ui_left", "ui_right")
	var right_stick: float = (
		_controller_mapping_manager.get_role_axis(
			ControllerMappingManagerType.ROLE_RIGHT_STICK_X
		)
		if _controller_mapping_manager != null
		else Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	)
	if absf(right_stick) > 0.2:
		axis = right_stick
	if absf(axis) > 0.1:
		_rotate(axis * keyboard_speed * delta)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.shift_pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_preview(-CAMERA_ZOOM_STEP)
			grab_focus()
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_preview(CAMERA_ZOOM_STEP)
			grab_focus()
			accept_event()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_dragging = event.pressed
		if event.pressed:
			grab_focus()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_rotate(event.relative.x * drag_sensitivity)
		_camera_pitch = clampf(
			_camera_pitch + event.relative.y * drag_sensitivity,
			-0.55,
			0.55,
		)
		_apply_camera_orbit()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_dragging = false


func _rotate(amount: float) -> void:
	_camera_yaw = fposmod(_camera_yaw + amount, TAU)
	_apply_camera_orbit()


func _zoom_preview(amount: float) -> void:
	if _preview_camera == null:
		return
	_camera_distance = clampf(
		_camera_distance + amount,
		MIN_CAMERA_DISTANCE,
		MAX_CAMERA_DISTANCE,
	)
	_apply_camera_orbit()


func _apply_camera_orbit() -> void:
	if _preview_camera == null:
		return
	var horizontal_distance := cos(_camera_pitch) * _camera_distance
	_preview_camera.position = Vector3(
		sin(_camera_yaw) * horizontal_distance,
		CAMERA_TARGET_HEIGHT + sin(_camera_pitch) * _camera_distance,
		cos(_camera_yaw) * horizontal_distance,
	)
	_preview_camera.look_at(
		Vector3(0.0, CAMERA_TARGET_HEIGHT, 0.0),
		Vector3.UP,
	)


func _sync_world_lighting() -> void:
	# The customization viewport deliberately does not follow gameplay time of
	# day. Keep this method as a compatibility seam for existing setup callers.
	pass


func _configure_preview_lighting() -> void:
	if _preview_environment == null or _preview_sun == null:
		return
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("082431")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b9d8d4")
	environment.ambient_light_energy = 1.15
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_preview_environment.environment = environment
	_preview_sun.rotation_degrees = Vector3(-35.0, -25.0, 0.0)
	_preview_sun.light_color = Color("fff1d0")
	_preview_sun.light_energy = 1.1
	_preview_sun.light_indirect_energy = 0.0
	_preview_sun.shadow_enabled = false


func _refresh_pixelation_filter() -> void:
	if not is_node_ready() or _pixelation_material == null:
		return
	_pixelation_material.set_shader_parameter(
		"logical_grid_size",
		Vector2(calculate_pixelated_grid_size(
			size,
			Vector2(get_window().size),
			_world_pixel_size,
		)),
	)


static func calculate_pixelated_grid_size(
	control_size: Vector2,
	window_size: Vector2,
	pixel_size: int,
) -> Vector2i:
	var safe_window_size := Vector2(
		maxf(window_size.x, 1.0),
		maxf(window_size.y, 1.0),
	)
	var world_grid_size: Vector2i = PlayerSettings.get_world_grid_size(
		pixel_size,
		Vector2i(roundi(safe_window_size.x), roundi(safe_window_size.y)),
	)
	var world_pixel_extent: float = (
		safe_window_size.y / float(maxi(world_grid_size.y, 1))
	)
	var presentation_scale: float = UIReferencePresentationType.get_scale(
		safe_window_size
	)
	var grid_size: Vector2 = (
		control_size * presentation_scale / maxf(world_pixel_extent, 0.001)
	)
	return Vector2i(
		maxi(roundi(grid_size.x), 1),
		maxi(roundi(grid_size.y), 1),
	)
