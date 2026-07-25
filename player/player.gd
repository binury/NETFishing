class_name Player
extends CharacterBody3D

@export_category("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var sneak_speed: float = 2.0
@export var slow_walk_speed: float = 3.25
@export var jump_velocity: float = 6.0
@export var body_rotation_speed: float = 12.0

@export_category("Camera")
@export var mouse_sensitivity: float = 0.005
@export var controller_camera_speed: float = 2.5
@export_range(0.0, 1.0, 0.01) var controller_camera_deadzone: float = 0.2
@export_range(-89.0, 0.0, 0.5) var minimum_pitch_degrees: float = -65.0
@export_range(0.0, 89.0, 0.5) var maximum_pitch_degrees: float = 45.0
@export var minimum_zoom: float = 2.0
@export var maximum_zoom: float = 8.0
@export var zoom_step: float = 0.75
@export var zoom_smoothing: float = 12.0

@onready var _visuals: Node3D = %Visuals
@onready var _camera_yaw: Node3D = %CameraYaw
@onready var _camera_pitch: Node3D = %CameraPitch
@onready var _spring_arm: SpringArm3D = %SpringArm3D

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _camera_dragging: bool = false
var _target_zoom: float = 5.0


func _ready() -> void:
	_target_zoom = clampf(_spring_arm.spring_length, minimum_zoom, maximum_zoom)
	_spring_arm.spring_length = _target_zoom


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)
	var camera_basis: Basis = _camera_yaw.global_basis
	var move_direction: Vector3 = camera_basis.x * input_vector.x + camera_basis.z * input_vector.y
	move_direction.y = 0.0
	var input_strength: float = minf(input_vector.length(), 1.0)
	move_direction = move_direction.normalized()

	var speed: float = _get_current_speed()
	velocity.x = move_direction.x * speed * input_strength
	velocity.z = move_direction.z * speed * input_strength

	if not move_direction.is_zero_approx():
		var target_rotation: float = atan2(-move_direction.x, -move_direction.z)
		_visuals.rotation.y = lerp_angle(
			_visuals.rotation.y,
			target_rotation,
			1.0 - exp(-body_rotation_speed * delta)
		)

	move_and_slide()


func _process(delta: float) -> void:
	if _camera_dragging and not Input.is_action_pressed("camera_drag"):
		_camera_dragging = false

	var stick: Vector2 = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if stick.length() > controller_camera_deadzone:
		var adjusted_strength: float = (
			(stick.length() - controller_camera_deadzone)
			/ (1.0 - controller_camera_deadzone)
		)
		_rotate_camera(stick.normalized() * adjusted_strength * controller_camera_speed * delta)

	var zoom_weight: float = 1.0 - exp(-zoom_smoothing * delta)
	_spring_arm.spring_length = lerpf(_spring_arm.spring_length, _target_zoom, zoom_weight)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("camera_drag"):
		_camera_dragging = event.is_pressed()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _camera_dragging:
		_rotate_camera(event.relative * mouse_sensitivity)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("camera_zoom_in"):
		_set_target_zoom(_target_zoom - zoom_step)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_zoom_out"):
		_set_target_zoom(_target_zoom + zoom_step)
		get_viewport().set_input_as_handled()


func _get_current_speed() -> float:
	if Input.is_action_pressed("sneak"):
		return sneak_speed
	if Input.is_action_pressed("slow_walk"):
		return slow_walk_speed
	if Input.is_action_pressed("sprint"):
		return sprint_speed
	return walk_speed


func _rotate_camera(delta_rotation: Vector2) -> void:
	_camera_yaw.rotation.y -= delta_rotation.x
	_camera_pitch.rotation.x = clampf(
		_camera_pitch.rotation.x - delta_rotation.y,
		deg_to_rad(minimum_pitch_degrees),
		deg_to_rad(maximum_pitch_degrees)
	)


func _set_target_zoom(value: float) -> void:
	_target_zoom = clampf(value, minimum_zoom, maximum_zoom)
