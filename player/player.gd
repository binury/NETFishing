class_name Player
extends CharacterBody3D

const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")
const FishCatchType = preload("res://fish/fish_catch.gd")

class ShowcaseCameraSnapshot:
	extends RefCounted

	var yaw_transform: Transform3D
	var yaw_rotation: Vector3
	var pitch_rotation: Vector3
	var spring_length: float
	var target_zoom: float
	var camera_input_enabled: bool
	var camera_dragging: bool


@export_category("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var sneak_speed: float = 2.0
@export var slow_walk_speed: float = 3.25
@export var jump_velocity: float = 6.0
@export var body_rotation_speed: float = 12.0

@export_category("Control")
@export var local_control_enabled: bool = true

@export_category("Fishing Stats")
@export_range(0.01, 2.0, 0.01) var reel_speed: float = 0.32
@export_range(1, 100, 1) var click_power: int = 1

@export_category("Showcase")
@export_range(0.05, 1.0, 0.01) var showcase_turn_duration: float = 0.28
@export_range(0.05, 1.0, 0.01) var showcase_restore_duration: float = 0.24
@export_range(0.05, 1.5, 0.01) var showcase_camera_transition_duration: float = 0.42
@export_range(-180.0, 180.0, 1.0) var showcase_camera_yaw_offset: float = 180.0
@export_range(-80.0, 80.0, 1.0) var showcase_camera_pitch: float = -8.0
@export_range(1.0, 10.0, 0.1) var showcase_camera_zoom_distance: float = 3.6
@export_range(0.5, 3.0, 0.05) var showcase_camera_target_height: float = 1.45

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
@onready var _camera: Camera3D = %Camera3D
@onready var inventory: FishInventoryType = %Inventory
@onready var collection_log: CollectionLogType = %CollectionLog
@onready var _cast_origin: Marker3D = %CastOrigin
@onready var _fishing_rod: Node3D = %FishingRod
@onready var _fishing_rod_tip: Marker3D = %FishingRodTip
@onready var _catch_display: Node3D = %CatchDisplay
@onready var _catch_sprite: Sprite3D = %CatchSprite

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _camera_dragging: bool = false
var _camera_input_enabled: bool = true
var _movement_enabled: bool = true
var _target_zoom: float = 5.0
var _showcase_rod_visibility: bool = true
var _showcase_rod_state_stored: bool = false
var _showcase_visual_rotation: Vector3
var _showcase_visual_rotation_stored: bool = false
var _showcase_turn_tween: Tween
var _showcase_restore_tween: Tween
var _showcase_camera_tween: Tween
var _showcase_camera_snapshot: ShowcaseCameraSnapshot
var _showcase_restore_generation: int = 0


func _ready() -> void:
	_target_zoom = clampf(_spring_arm.spring_length, minimum_zoom, maximum_zoom)
	_spring_arm.spring_length = _target_zoom
	_camera.current = local_control_enabled


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	elif (
		local_control_enabled
		and _movement_enabled
		and Input.is_action_just_pressed("jump")
	):
		velocity.y = jump_velocity

	if not local_control_enabled or not _movement_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

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
	if not local_control_enabled:
		return

	if (
		_camera_input_enabled
		and _camera_dragging
		and not Input.is_action_pressed("camera_drag")
	):
		_camera_dragging = false

	if _camera_input_enabled:
		var stick: Vector2 = Vector2(
			Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
		)
		if stick.length() > controller_camera_deadzone:
			var adjusted_strength: float = (
				(stick.length() - controller_camera_deadzone)
				/ (1.0 - controller_camera_deadzone)
			)
			_rotate_camera(
				stick.normalized()
				* adjusted_strength
				* controller_camera_speed
				* delta
			)

		var zoom_weight: float = 1.0 - exp(-zoom_smoothing * delta)
		_spring_arm.spring_length = lerpf(
			_spring_arm.spring_length,
			_target_zoom,
			zoom_weight
		)


func _unhandled_input(event: InputEvent) -> void:
	if not local_control_enabled or not _camera_input_enabled:
		return

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


func set_local_control(enabled: bool) -> void:
	local_control_enabled = enabled
	if is_node_ready():
		_camera.current = enabled
	if not enabled:
		_camera_dragging = false


func is_local_control_enabled() -> bool:
	return local_control_enabled


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled
	if not enabled:
		velocity.x = 0.0
		velocity.z = 0.0


func get_fishing_rod_tip() -> Marker3D:
	return _fishing_rod_tip


func get_fishing_rod() -> Node3D:
	return _fishing_rod


func get_cast_origin_position() -> Vector3:
	return _cast_origin.global_position


func begin_catch_showcase(fish_catch: FishCatchType) -> void:
	if fish_catch == null or not fish_catch.is_valid():
		return
	_kill_showcase_camera_tween()
	_kill_showcase_restore_tween()
	_capture_showcase_camera_snapshot()
	if not _showcase_visual_rotation_stored:
		_showcase_visual_rotation = _visuals.rotation
		_showcase_visual_rotation_stored = true
	var showcase_camera_position: Vector3 = _begin_showcase_camera_transition()
	_turn_showcase_toward_position(showcase_camera_position)
	if not _showcase_rod_state_stored:
		_showcase_rod_visibility = _fishing_rod.visible
		_showcase_rod_state_stored = true
	_fishing_rod.visible = false
	_catch_sprite.texture = fish_catch.fish.display_texture
	_catch_display.scale = Vector3.ONE * fish_catch.display_scale
	_catch_display.visible = _catch_sprite.texture != null


func end_catch_showcase(
	restored_callback: Callable = Callable(),
	immediate: bool = false,
) -> void:
	_kill_showcase_turn_tween()
	_kill_showcase_camera_tween()
	_kill_showcase_restore_tween()
	_catch_display.visible = false
	_catch_display.scale = Vector3.ONE
	_catch_sprite.texture = null
	if _showcase_rod_state_stored:
		_fishing_rod.visible = _showcase_rod_visibility
	_showcase_rod_visibility = true
	_showcase_rod_state_stored = false
	if (
		not _showcase_visual_rotation_stored
		and _showcase_camera_snapshot == null
	):
		if restored_callback.is_valid():
			restored_callback.call()
		return
	if immediate:
		_complete_showcase_restore(restored_callback)
		return

	var current_rotation: Vector3 = _visuals.rotation
	var restore_target: Vector3 = _showcase_visual_rotation
	restore_target.y = (
		current_rotation.y
		+ wrapf(
			_showcase_visual_rotation.y - current_rotation.y,
			-PI,
			PI
		)
	)
	var restore_generation: int = _showcase_restore_generation
	_showcase_restore_tween = create_tween()
	_showcase_restore_tween.set_parallel(true)
	_showcase_restore_tween.set_trans(Tween.TRANS_QUAD)
	_showcase_restore_tween.set_ease(Tween.EASE_IN_OUT)
	if _showcase_visual_rotation_stored:
		_showcase_restore_tween.tween_property(
			_visuals,
			"rotation",
			restore_target,
			maxf(showcase_restore_duration, 0.05)
		)
	if _showcase_camera_snapshot != null:
		var camera_yaw_target: Vector3 = (
			_showcase_camera_snapshot.yaw_rotation
		)
		camera_yaw_target.y = (
			_camera_yaw.rotation.y
			+ wrapf(
				camera_yaw_target.y - _camera_yaw.rotation.y,
				-PI,
				PI
			)
		)
		var camera_duration: float = maxf(
			showcase_camera_transition_duration,
			0.05
		)
		_showcase_restore_tween.tween_property(
			_camera_yaw,
			"rotation",
			camera_yaw_target,
			camera_duration
		)
		_showcase_restore_tween.tween_property(
			_camera_yaw,
			"position",
			_showcase_camera_snapshot.yaw_transform.origin,
			camera_duration
		)
		_showcase_restore_tween.tween_property(
			_camera_pitch,
			"rotation",
			_showcase_camera_snapshot.pitch_rotation,
			camera_duration
		)
		_showcase_restore_tween.tween_property(
			_spring_arm,
			"spring_length",
			_showcase_camera_snapshot.spring_length,
			camera_duration
		)
	_showcase_restore_tween.finished.connect(
		_on_showcase_restore_finished.bind(
			restore_generation,
			restored_callback
		)
	)


func _turn_showcase_toward_position(target_position: Vector3) -> void:
	_kill_showcase_turn_tween()
	var camera_direction: Vector3 = (
		target_position - _visuals.global_position
	)
	camera_direction.y = 0.0
	if camera_direction.is_zero_approx():
		return
	camera_direction = camera_direction.normalized()
	var target_world_yaw: float = atan2(
		-camera_direction.x,
		-camera_direction.z
	)
	var target_local_yaw: float = target_world_yaw - global_rotation.y
	var current_yaw: float = _visuals.rotation.y
	var shortest_target_yaw: float = (
		current_yaw
		+ wrapf(target_local_yaw - current_yaw, -PI, PI)
	)
	_showcase_turn_tween = create_tween()
	_showcase_turn_tween.set_trans(Tween.TRANS_QUAD)
	_showcase_turn_tween.set_ease(Tween.EASE_IN_OUT)
	_showcase_turn_tween.tween_property(
		_visuals,
		"rotation:y",
		shortest_target_yaw,
		maxf(showcase_turn_duration, 0.05)
	)
	_showcase_turn_tween.finished.connect(_on_showcase_turn_finished)


func _kill_showcase_turn_tween() -> void:
	if _showcase_turn_tween != null and _showcase_turn_tween.is_valid():
		_showcase_turn_tween.kill()
	_showcase_turn_tween = null


func _kill_showcase_restore_tween() -> void:
	if _showcase_restore_tween != null and _showcase_restore_tween.is_valid():
		_showcase_restore_tween.kill()
	_showcase_restore_tween = null
	_showcase_restore_generation += 1


func _kill_showcase_camera_tween() -> void:
	if _showcase_camera_tween != null and _showcase_camera_tween.is_valid():
		_showcase_camera_tween.kill()
	_showcase_camera_tween = null


func _on_showcase_turn_finished() -> void:
	_showcase_turn_tween = null


func _on_showcase_restore_finished(
	restore_generation: int,
	restored_callback: Callable,
) -> void:
	if restore_generation != _showcase_restore_generation:
		return
	_showcase_restore_tween = null
	_complete_showcase_restore(restored_callback)


func _complete_showcase_restore(
	restored_callback: Callable,
) -> void:
	if _showcase_visual_rotation_stored:
		_visuals.rotation = _showcase_visual_rotation
	_showcase_visual_rotation = Vector3.ZERO
	_showcase_visual_rotation_stored = false
	if _showcase_camera_snapshot != null:
		_camera_yaw.transform = _showcase_camera_snapshot.yaw_transform
		_camera_pitch.rotation = _showcase_camera_snapshot.pitch_rotation
		_spring_arm.spring_length = _showcase_camera_snapshot.spring_length
		_target_zoom = _showcase_camera_snapshot.target_zoom
		_camera_input_enabled = (
			_showcase_camera_snapshot.camera_input_enabled
		)
		_camera_dragging = _showcase_camera_snapshot.camera_dragging
	_showcase_camera_snapshot = null
	if restored_callback.is_valid():
		restored_callback.call()


func _capture_showcase_camera_snapshot() -> void:
	if _showcase_camera_snapshot != null:
		return
	_showcase_camera_snapshot = ShowcaseCameraSnapshot.new()
	_showcase_camera_snapshot.yaw_transform = _camera_yaw.transform
	_showcase_camera_snapshot.yaw_rotation = _camera_yaw.rotation
	_showcase_camera_snapshot.pitch_rotation = _camera_pitch.rotation
	_showcase_camera_snapshot.spring_length = _spring_arm.spring_length
	_showcase_camera_snapshot.target_zoom = _target_zoom
	_showcase_camera_snapshot.camera_input_enabled = _camera_input_enabled
	_showcase_camera_snapshot.camera_dragging = _camera_dragging
	_camera_input_enabled = false
	_camera_dragging = false


func _begin_showcase_camera_transition() -> Vector3:
	var target_world_yaw: float = (
		_visuals.global_rotation.y
		+ deg_to_rad(showcase_camera_yaw_offset)
	)
	var target_local_yaw: float = target_world_yaw - global_rotation.y
	var shortest_target_yaw: float = (
		_camera_yaw.rotation.y
		+ wrapf(
			target_local_yaw - _camera_yaw.rotation.y,
			-PI,
			PI
		)
	)
	var target_pitch: float = deg_to_rad(showcase_camera_pitch)
	var target_position: Vector3 = _camera_yaw.position
	target_position.y = showcase_camera_target_height
	var target_zoom: float = maxf(showcase_camera_zoom_distance, 0.1)
	var camera_duration: float = maxf(
		showcase_camera_transition_duration,
		0.05
	)
	_showcase_camera_tween = create_tween()
	_showcase_camera_tween.set_parallel(true)
	_showcase_camera_tween.set_trans(Tween.TRANS_QUAD)
	_showcase_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_showcase_camera_tween.tween_property(
		_camera_yaw,
		"rotation:y",
		shortest_target_yaw,
		camera_duration
	)
	_showcase_camera_tween.tween_property(
		_camera_yaw,
		"position:y",
		target_position.y,
		camera_duration
	)
	_showcase_camera_tween.tween_property(
		_camera_pitch,
		"rotation:x",
		target_pitch,
		camera_duration
	)
	_showcase_camera_tween.tween_property(
		_spring_arm,
		"spring_length",
		target_zoom,
		camera_duration
	)

	var horizontal_offset: Vector3 = (
		Basis(Vector3.UP, target_world_yaw).z * target_zoom
	)
	return global_position + target_position + horizontal_offset


func get_facing_direction() -> Vector3:
	var facing: Vector3 = -_visuals.global_basis.z
	facing.y = 0.0
	if facing.is_zero_approx():
		facing = -global_basis.z
		facing.y = 0.0
	if facing.is_zero_approx():
		return Vector3.FORWARD
	return facing.normalized()
