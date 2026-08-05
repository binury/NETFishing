class_name ProfilePreview
extends SubViewportContainer

const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const FRONT_FACING_YAW: float = PI

@export_range(0.1, 2.0, 0.05) var drag_sensitivity: float = 0.012
@export_range(0.1, 4.0, 0.1) var keyboard_speed: float = 1.8

@onready var _preview_root: Node3D = %PreviewRoot
@onready var _preview_environment: WorldEnvironment = %WorldEnvironment
@onready var _preview_sun: DirectionalLight3D = %KeyLight

var _dragging: bool = false
var _visuals: Node3D
var _controller_mapping_manager: ControllerMappingManagerType
var _source_environment: WorldEnvironment
var _source_sun: DirectionalLight3D


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


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	gui_input.connect(_on_gui_input)
	reset_view()
	_visuals = PlayerVisualPresenter.instantiate_visuals()
	_preview_root.add_child(_visuals)
	var rod := _visuals.find_child("FishingRod", true, false) as Node3D
	if rod != null:
		rod.visible = false
	var catch_display := _visuals.find_child("CatchDisplay", true, false) as Node3D
	if catch_display != null:
		catch_display.visible = false


func apply_appearance_profile(profile: Dictionary) -> void:
	if _visuals != null:
		PlayerVisualPresenter.apply_appearance(_visuals, profile)


func reset_view() -> void:
	_preview_root.rotation.y = FRONT_FACING_YAW


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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			grab_focus()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_rotate(event.relative.x * drag_sensitivity)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_dragging = false


func _rotate(amount: float) -> void:
	_preview_root.rotation.y = fposmod(_preview_root.rotation.y + amount, TAU)


func _sync_world_lighting() -> void:
	if (
		_preview_environment == null
		or _preview_sun == null
		or _source_environment == null
		or _source_sun == null
	):
		return
	_preview_environment.environment = _source_environment.environment
	_preview_sun.rotation = _source_sun.global_rotation
	_preview_sun.light_color = _source_sun.light_color
	_preview_sun.light_energy = _source_sun.light_energy
	_preview_sun.light_indirect_energy = _source_sun.light_indirect_energy
	_preview_sun.shadow_enabled = _source_sun.shadow_enabled
