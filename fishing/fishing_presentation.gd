class_name FishingPresentation
extends Node3D

signal cast_completed

enum VisualMode {
	NONE,
	AIMING,
	CASTING,
	FISHING,
	OUTCOME,
}

@export_category("Water")
@export var water_surface_offset_y: float = -0.72
@export_range(0.1, 10.0, 0.1) var pickup_distance_from_player: float = 5.5

@export_category("Cast")
@export_range(0.1, 30.0, 0.1) var target_movement_smoothing: float = 14.0
@export_range(0.1, 3.0, 0.05) var cast_travel_duration: float = 0.65
@export_range(0.1, 5.0, 0.1) var cast_arc_height: float = 2.0
@export_range(0.0, 90.0, 1.0) var maximum_rod_cock_degrees: float = 50.0
@export_range(0.0, 60.0, 1.0) var rod_forward_swing_degrees: float = 22.0
@export_range(0.05, 1.0, 0.01) var rod_forward_swing_duration: float = 0.12
@export_range(0.05, 1.0, 0.01) var rod_recovery_duration: float = 0.22

@onready var _target_marker: MeshInstance3D = %CastTargetMarker
@onready var _bobber: MeshInstance3D = %Bobber
@onready var _line: MeshInstance3D = %FishingLine

var _mode: VisualMode = VisualMode.NONE
var _line_mesh: ImmediateMesh = ImmediateMesh.new()
var _rod: Node3D
var _rod_tip: Marker3D
var _rod_neutral_rotation: Vector3
var _target_goal: Vector3
var _cast_position: Vector3
var _pickup_position: Vector3
var _active_tween: Tween
var _rod_tween: Tween


func _ready() -> void:
	_line.mesh = _line_mesh
	cleanup()


func _process(delta: float) -> void:
	if _mode == VisualMode.AIMING:
		var weight: float = 1.0 - exp(-target_movement_smoothing * delta)
		_target_marker.global_position = _target_marker.global_position.lerp(
			_target_goal,
			weight
		)
	if _line.visible:
		_update_line()


func get_water_surface_height() -> float:
	return global_position.y + water_surface_offset_y


func begin_aim(
	rod_tip: Marker3D,
	rod: Node3D,
	minimum_target: Vector3,
) -> void:
	cleanup()
	if rod_tip == null or rod == null:
		return

	_mode = VisualMode.AIMING
	_rod = rod
	_rod_tip = rod_tip
	_rod_neutral_rotation = _rod.rotation
	_target_goal = minimum_target
	_target_marker.global_position = minimum_target
	_target_marker.scale = Vector3.ONE
	_target_marker.visible = true


func update_rod_charge(charge: float) -> void:
	if _mode != VisualMode.AIMING or _rod == null:
		return

	var cock_rotation: Vector3 = _rod_neutral_rotation
	cock_rotation.x += deg_to_rad(maximum_rod_cock_degrees) * clampf(charge, 0.0, 1.0)
	_rod.rotation = cock_rotation


func update_aim_target(target: Vector3, charge: float) -> void:
	if _mode != VisualMode.AIMING:
		return

	_target_goal = target
	var maximum_response: float = smoothstep(0.9, 1.0, clampf(charge, 0.0, 1.0))
	_target_marker.scale = Vector3.ONE * lerpf(1.0, 1.15, maximum_response)


func begin_cast(target: Vector3) -> void:
	if _mode != VisualMode.AIMING or _rod_tip == null:
		return

	_kill_active_tween()
	_mode = VisualMode.CASTING
	_target_marker.visible = false
	_bobber.visible = true
	_bobber.scale = Vector3.ONE
	_line.visible = true
	_cast_position = _with_water_height(target)
	_pickup_position = _calculate_pickup_position(_cast_position)

	var cast_start: Vector3 = _rod_tip.global_position
	_bobber.global_position = cast_start
	_begin_rod_release()
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_method(
		_set_cast_sample.bind(cast_start, _cast_position),
		0.0,
		1.0,
		cast_travel_duration
	)
	_active_tween.finished.connect(_on_cast_tween_finished)


func show_bite() -> void:
	if _mode != VisualMode.FISHING:
		return

	_kill_active_tween()
	var bite_position: Vector3 = _with_water_height(_bobber.global_position)
	_bobber.global_position = bite_position
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD)
	_active_tween.tween_property(
		_bobber,
		"global_position:y",
		get_water_surface_height() - 0.25,
		0.11
	)
	_active_tween.tween_property(
		_bobber,
		"global_position:y",
		get_water_surface_height() + 0.05,
		0.14
	)
	_active_tween.tween_property(
		_bobber,
		"global_position:y",
		bite_position.y,
		0.12
	)


func show_withdrawal_position(position: Vector3) -> void:
	if _mode != VisualMode.FISHING:
		return

	_kill_active_tween()
	_bobber.global_position = _with_water_height(position)


func begin_reeling(pickup_position: Vector3) -> void:
	if _mode != VisualMode.FISHING:
		return

	_kill_active_tween()
	_cast_position = _with_water_height(_bobber.global_position)
	_pickup_position = _with_water_height(pickup_position)


func show_reel_progress(progress: float, _input_held: bool) -> void:
	if _mode != VisualMode.FISHING:
		return

	_kill_active_tween()
	_bobber.scale = Vector3.ONE
	_bobber.global_position = _cast_position.lerp(
		_pickup_position,
		clampf(progress, 0.0, 1.0)
	)
	_bobber.global_position.y = get_water_surface_height()


func play_outcome(outcome: StringName) -> void:
	if _mode == VisualMode.NONE:
		cleanup()
		return

	_kill_active_tween()
	_kill_rod_tween()
	_restore_rod_neutral()
	_mode = VisualMode.OUTCOME
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD)
	_active_tween.set_ease(Tween.EASE_IN)

	if _target_marker.visible and not _bobber.visible:
		_active_tween.tween_property(_target_marker, "scale", Vector3.ZERO, 0.18)
	else:
		_target_marker.visible = false
		match outcome:
			&"catch":
				var catch_target: Vector3 = _bobber.global_position
				if _rod_tip != null:
					catch_target = _rod_tip.global_position
				_active_tween.set_parallel(true)
				_active_tween.tween_property(_bobber, "global_position", catch_target, 0.35)
				_active_tween.tween_property(_bobber, "scale", Vector3.ZERO, 0.35)
			&"escape":
				var start_x: float = _bobber.global_position.x
				_active_tween.tween_property(
					_bobber,
					"global_position:x",
					start_x - 0.18,
					0.08
				)
				_active_tween.tween_property(
					_bobber,
					"global_position:x",
					start_x + 0.18,
					0.08
				)
				_active_tween.tween_property(
					_bobber,
					"global_position:y",
					get_water_surface_height() - 0.4,
					0.2
				)
			&"miss":
				_active_tween.set_parallel(true)
				_active_tween.tween_property(
					_bobber,
					"global_position:y",
					get_water_surface_height() - 0.4,
					0.3
				)
				_active_tween.tween_property(_bobber, "scale", Vector3.ONE * 0.65, 0.3)
			&"invalid":
				var return_target: Vector3 = _bobber.global_position
				if _rod_tip != null:
					return_target = _rod_tip.global_position
				_active_tween.set_parallel(true)
				_active_tween.tween_property(_bobber, "global_position", return_target, 0.28)
				_active_tween.tween_property(_bobber, "scale", Vector3.ZERO, 0.28)
			&"withdrawal":
				var withdrawal_target: Vector3 = _bobber.global_position
				if _rod_tip != null:
					withdrawal_target = _rod_tip.global_position
				_active_tween.set_parallel(true)
				_active_tween.tween_property(
					_bobber,
					"global_position",
					withdrawal_target,
					0.28
				)
				_active_tween.tween_property(_bobber, "scale", Vector3.ZERO, 0.28)
			_:
				_active_tween.tween_property(_bobber, "scale", Vector3.ZERO, 0.18)

	_active_tween.finished.connect(cleanup)


func cleanup() -> void:
	_kill_active_tween()
	_kill_rod_tween()
	_restore_rod_neutral()
	_mode = VisualMode.NONE
	_rod = null
	_rod_tip = null
	_target_marker.visible = false
	_target_marker.scale = Vector3.ONE
	_bobber.visible = false
	_bobber.scale = Vector3.ONE
	_line.visible = false
	_line_mesh.clear_surfaces()


func _set_cast_sample(
	progress: float,
	start: Vector3,
	target: Vector3,
) -> void:
	var sample: Vector3 = start.lerp(target, progress)
	sample.y += sin(progress * PI) * cast_arc_height
	_bobber.global_position = sample


func _on_cast_tween_finished() -> void:
	if _mode != VisualMode.CASTING:
		return

	_active_tween = null
	_bobber.global_position = _cast_position
	_mode = VisualMode.FISHING
	cast_completed.emit()


func _calculate_pickup_position(target: Vector3) -> Vector3:
	var player_on_water: Vector3 = target
	if _rod_tip != null:
		player_on_water = _with_water_height(_rod_tip.global_position)
	var outward: Vector3 = target - player_on_water
	outward.y = 0.0
	if outward.is_zero_approx():
		outward = Vector3.FORWARD
	else:
		outward = outward.normalized()
	var target_distance: float = player_on_water.distance_to(target)
	var pickup_distance: float = minf(
		pickup_distance_from_player,
		target_distance * 0.8
	)
	return player_on_water + outward * pickup_distance


func _with_water_height(position: Vector3) -> Vector3:
	return Vector3(position.x, get_water_surface_height(), position.z)


func _update_line() -> void:
	if _rod_tip == null or not is_instance_valid(_rod_tip):
		cleanup()
		return

	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_line_mesh.surface_add_vertex(to_local(_rod_tip.global_position))
	_line_mesh.surface_add_vertex(to_local(_bobber.global_position))
	_line_mesh.surface_end()


func _begin_rod_release() -> void:
	_kill_rod_tween()
	if _rod == null:
		return

	var forward_rotation: Vector3 = _rod_neutral_rotation
	forward_rotation.x -= deg_to_rad(rod_forward_swing_degrees)
	_rod_tween = create_tween()
	_rod_tween.set_trans(Tween.TRANS_QUAD)
	_rod_tween.set_ease(Tween.EASE_OUT)
	_rod_tween.tween_property(
		_rod,
		"rotation",
		forward_rotation,
		rod_forward_swing_duration
	)
	_rod_tween.set_ease(Tween.EASE_IN_OUT)
	_rod_tween.tween_property(
		_rod,
		"rotation",
		_rod_neutral_rotation,
		rod_recovery_duration
	)


func _restore_rod_neutral() -> void:
	if _rod != null and is_instance_valid(_rod):
		_rod.rotation = _rod_neutral_rotation


func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _kill_rod_tween() -> void:
	if _rod_tween != null and _rod_tween.is_valid():
		_rod_tween.kill()
	_rod_tween = null
