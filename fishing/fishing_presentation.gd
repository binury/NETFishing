class_name FishingPresentation
extends Node3D

const WaterSurfaceMotionType = preload(
	"res://world/water_surface_motion.gd"
)

signal cast_completed
signal outcome_completed(outcome: StringName)
signal presentation_interrupted

enum VisualMode {
	NONE,
	AIMING,
	CASTING,
	FISHING,
	OUTCOME,
}

enum LineMode {
	HIDDEN,
	TAUT,
	SLACK,
}

@export_category("Fishing Line")
@export_range(0.0, 0.5, 0.01) var slack_amount: float = 0.08
@export_range(0.0, 2.0, 0.01) var minimum_slack: float = 0.08
@export_range(0.0, 3.0, 0.01) var maximum_slack: float = 0.65
@export_range(2, 20, 1) var sag_interpolation_count: int = 8
@export_range(0.1, 30.0, 0.1) var line_transition_speed: float = 7.0
@export_range(0.002, 0.05, 0.001) var line_thickness: float = 0.016

@export_category("Cast")
@export_range(0.1, 3.0, 0.05) var cast_travel_duration: float = 0.65
@export_range(0.1, 5.0, 0.1) var cast_arc_height: float = 2.0
@export_range(0.0, 90.0, 1.0) var maximum_rod_cock_degrees: float = 50.0
@export_range(0.0, 60.0, 1.0) var rod_forward_swing_degrees: float = 22.0
@export_range(0.05, 1.0, 0.01) var rod_forward_swing_duration: float = 0.12
@export_range(0.05, 1.0, 0.01) var rod_recovery_duration: float = 0.22

@export_category("Bobber Idle")
@export_range(0.0, 0.2, 0.005) var bobber_bob_amplitude: float = 0.035
@export_range(0.1, 3.0, 0.05) var bobber_bob_cycles_per_second: float = 0.7
@export_range(0.0, 12.0, 0.5) var bobber_tilt_degrees: float = 4.0
@onready var _target_marker: Node3D = %CastTargetMarker
@onready var _valid_target_marker: MeshInstance3D = %ValidTargetMarker
@onready var _invalid_target_marker: Node3D = %InvalidTargetMarker
@onready var _bobber: MeshInstance3D = %Bobber
@onready var _line: MeshInstance3D = %FishingLine

var _mode: VisualMode = VisualMode.NONE
var _line_mode: LineMode = LineMode.HIDDEN
var _line_mesh: ImmediateMesh = ImmediateMesh.new()
var _current_sag: float = 0.0
var _rod: Node3D
var _rod_tip: Marker3D
var _rod_neutral_rotation: Vector3
var _cast_arrival_position: Vector3
var _active_cast_arc_height: float = 0.0
var _cast_tracks_water_surface: bool = false
var _bobber_surface_position: Vector3
var _bobber_idle_elapsed: float = 0.0
var _bobber_base_scale: Vector3 = Vector3.ONE
var _active_tween: Tween
var _rod_tween: Tween
var _bite_tween: Tween


func _ready() -> void:
	_line.mesh = _line_mesh
	cleanup()


func _process(delta: float) -> void:
	if _mode == VisualMode.FISHING and _bobber.visible:
		_bobber_idle_elapsed += delta
		_apply_bobber_idle_motion()
		var bobber_position := _bobber.global_position
		bobber_position.y += WaterSurfaceMotionType.get_default_height_offset()
		_bobber.global_position = bobber_position
	if _line_mode != LineMode.HIDDEN:
		_update_line(delta)


func set_line_mode(mode: LineMode) -> void:
	_line_mode = mode
	_line.visible = mode != LineMode.HIDDEN
	if mode == LineMode.HIDDEN:
		_current_sag = 0.0
		_line_mesh.clear_surfaces()


func begin_aim(
	rod_tip: Marker3D,
	rod: Node3D,
	minimum_target: Vector3,
	target_normal: Vector3,
	target_is_fishable: bool,
	character_scale: float = 1.0,
) -> void:
	cleanup()
	if rod_tip == null or rod == null:
		return

	_bobber_base_scale = Vector3.ONE * maxf(character_scale, 0.01)
	_mode = VisualMode.AIMING
	_rod = rod
	_rod_tip = rod_tip
	_rod_neutral_rotation = _rod.rotation
	_set_target_surface(minimum_target, target_normal)
	_target_marker.scale = Vector3.ONE
	_target_marker.visible = true
	_set_target_validity(target_is_fishable)


func update_rod_charge(charge: float) -> void:
	if _mode != VisualMode.AIMING or _rod == null:
		return

	var cock_rotation: Vector3 = _rod_neutral_rotation
	cock_rotation.x += deg_to_rad(maximum_rod_cock_degrees) * clampf(charge, 0.0, 1.0)
	_rod.rotation = cock_rotation


func update_aim_target(
	target: Vector3,
	target_normal: Vector3,
	charge: float,
	target_is_fishable: bool,
) -> void:
	if _mode != VisualMode.AIMING:
		return

	# The gameplay resolver already advances the horizontal target smoothly.
	# Snap each sample to its resolved surface so interpolation can never draw
	# the marker through a vertical shoreline between two valid endpoints.
	_set_target_surface(target, target_normal)
	var maximum_response: float = smoothstep(0.9, 1.0, clampf(charge, 0.0, 1.0))
	_target_marker.scale = Vector3.ONE * lerpf(1.0, 1.15, maximum_response)
	_set_target_validity(target_is_fishable)


func _set_target_surface(target: Vector3, surface_normal: Vector3) -> void:
	_target_marker.global_position = target
	var resolved_normal: Vector3 = surface_normal.normalized()
	if resolved_normal.is_zero_approx():
		resolved_normal = Vector3.UP
	_target_marker.global_basis = Basis(
		Quaternion(Vector3.UP, resolved_normal)
	)


func begin_cast(
	target: Vector3,
	blocked_landing_position: Vector3 = Vector3.ZERO,
	cast_is_blocked: bool = false,
	resolved_arc_height: float = -1.0,
) -> void:
	if _mode != VisualMode.AIMING or _rod_tip == null:
		return

	_kill_active_tween()
	_mode = VisualMode.CASTING
	_target_marker.visible = false
	_bobber.visible = true
	_bobber.scale = _bobber_base_scale
	_cast_arrival_position = (
		blocked_landing_position if cast_is_blocked else target
	)
	_active_cast_arc_height = (
		maxf(resolved_arc_height, 0.0)
		if resolved_arc_height >= 0.0
		else cast_arc_height
	)
	_cast_tracks_water_surface = not cast_is_blocked

	var cast_start: Vector3 = _rod_tip.global_position
	_bobber.global_position = cast_start
	_begin_rod_release()
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_SINE)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_method(
		_set_cast_sample.bind(cast_start, _cast_arrival_position),
		0.0,
		1.0,
		cast_travel_duration
	)
	if cast_is_blocked:
		# Let the bobber visibly settle on the blocking surface before the
		# normal invalid-cast return animation begins.
		_active_tween.tween_interval(0.16)
	_active_tween.finished.connect(_on_cast_tween_finished)


func show_bite() -> void:
	if _mode != VisualMode.FISHING:
		return

	_kill_bite_tween()
	_bobber.scale = _bobber_base_scale
	_bite_tween = create_tween()
	_bite_tween.set_trans(Tween.TRANS_QUAD)
	_bite_tween.set_ease(Tween.EASE_IN_OUT)
	_bite_tween.tween_property(
		_bobber,
		"scale",
		_bobber_base_scale * 0.68,
		0.08
	)
	_bite_tween.tween_property(
		_bobber,
		"scale",
		_bobber_base_scale * 1.2,
		0.1
	)
	_bite_tween.tween_property(
		_bobber,
		"scale",
		_bobber_base_scale,
		0.1
	)
	_bite_tween.finished.connect(_on_bite_tween_finished)


func show_withdrawal_position(world_position: Vector3) -> void:
	if _mode != VisualMode.FISHING:
		return

	_kill_active_tween()
	_bobber_surface_position = world_position
	_apply_bobber_idle_motion()


func begin_fight() -> void:
	if _mode != VisualMode.FISHING:
		return

	_kill_active_tween()


func play_outcome(outcome: StringName) -> void:
	if _mode == VisualMode.NONE:
		cleanup()
		# Gameplay completion must not depend on a presentation tween still
		# being active. The caller owns idempotency for the outcome.
		outcome_completed.emit(outcome)
		return

	_kill_active_tween()
	_kill_bite_tween()
	_kill_rod_tween()
	_restore_rod_neutral()
	_mode = VisualMode.OUTCOME
	_bobber.rotation = Vector3.ZERO
	if outcome == &"withdrawal":
		# Withdrawal is a visible return, not an instant cancellation. Keep the
		# bobber present even if the preceding reel update hid or reset it.
		_bobber.visible = true
		_bobber.scale = _bobber_base_scale
	_active_tween = create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD)
	_active_tween.set_ease(Tween.EASE_IN)

	if _target_marker.visible and not _bobber.visible:
		_active_tween.tween_property(_target_marker, "scale", Vector3.ZERO, 0.18)
	else:
		_target_marker.visible = false
		match outcome:
			&"catch":
				_queue_bobber_return(0.35, 0.45)
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
				_queue_bobber_return(0.42, 0.65)
			&"invalid", &"withdrawal":
				_queue_bobber_return(0.42, 0.65)
			_:
				_active_tween.tween_property(_bobber, "scale", Vector3.ZERO, 0.18)

	_active_tween.finished.connect(_on_outcome_finished.bind(outcome))


func cleanup() -> void:
	_kill_active_tween()
	_kill_bite_tween()
	_kill_rod_tween()
	_restore_rod_neutral()
	_mode = VisualMode.NONE
	_rod = null
	_rod_tip = null
	_target_marker.visible = false
	_target_marker.scale = Vector3.ONE
	_valid_target_marker.visible = true
	_invalid_target_marker.visible = false
	_bobber.visible = false
	_bobber.scale = Vector3.ONE
	_bobber_base_scale = Vector3.ONE
	_bobber.rotation = Vector3.ZERO
	_cast_arrival_position = Vector3.ZERO
	_active_cast_arc_height = 0.0
	_cast_tracks_water_surface = false
	_bobber_surface_position = Vector3.ZERO
	_bobber_idle_elapsed = 0.0
	set_line_mode(LineMode.HIDDEN)


func _on_outcome_finished(outcome: StringName) -> void:
	cleanup()
	outcome_completed.emit(outcome)


func _set_cast_sample(
	progress: float,
	start: Vector3,
	target: Vector3,
) -> void:
	var sample: Vector3 = start.lerp(target, progress)
	sample.y += sin(progress * PI) * _active_cast_arc_height
	if _cast_tracks_water_surface:
		sample.y += (
			WaterSurfaceMotionType.get_default_height_offset()
			* smoothstep(0.72, 1.0, progress)
		)
	_bobber.global_position = sample


func _queue_bobber_return(duration: float, arc_scale: float) -> void:
	var return_start: Vector3 = _bobber.global_position
	var return_target: Vector3 = return_start
	if _rod_tip != null:
		return_target = _rod_tip.global_position
	_active_tween.tween_method(
		_set_return_sample.bind(return_start, return_target, arc_scale),
		0.0,
		1.0,
		duration,
	)
	_active_tween.tween_property(_bobber, "scale", Vector3.ZERO, 0.1)


func _set_return_sample(
	progress: float,
	start: Vector3,
	target: Vector3,
	arc_scale: float,
) -> void:
	var eased_progress: float = 1.0 - pow(1.0 - progress, 3.0)
	var sample: Vector3 = start.lerp(target, eased_progress)
	sample.y += sin(eased_progress * PI) * maxf(
		cast_arc_height * arc_scale,
		0.75,
	)
	_bobber.global_position = sample


func _on_cast_tween_finished() -> void:
	if _mode != VisualMode.CASTING:
		return

	_active_tween = null
	_bobber.global_position = _cast_arrival_position
	_bobber_surface_position = _cast_arrival_position
	_bobber_idle_elapsed = 0.0
	_mode = VisualMode.FISHING
	cast_completed.emit()


func _apply_bobber_idle_motion() -> void:
	var phase: float = _bobber_idle_elapsed * bobber_bob_cycles_per_second * TAU
	_bobber.global_position = (
		_bobber_surface_position
		+ Vector3.UP * sin(phase) * bobber_bob_amplitude
	)
	_bobber.rotation.z = (
		deg_to_rad(bobber_tilt_degrees) * sin(phase * 0.73)
	)


func _update_line(delta: float) -> void:
	if _rod_tip == null or not is_instance_valid(_rod_tip):
		var was_active: bool = _mode != VisualMode.NONE
		cleanup()
		if was_active:
			presentation_interrupted.emit()
		return

	var rod_tip_position: Vector3 = _rod_tip.global_position
	var bobber_position: Vector3 = _bobber.global_position
	var target_sag: float = 0.0
	if _line_mode == LineMode.SLACK:
		var line_length: float = rod_tip_position.distance_to(bobber_position)
		target_sag = clampf(
			line_length * slack_amount,
			minimum_slack,
			maximum_slack
		)
	var sag_weight: float = 1.0 - exp(-line_transition_speed * delta)
	_current_sag = lerpf(_current_sag, target_sag, sag_weight)
	var rendered_points: PackedVector3Array = _build_sagged_line_points(
		rod_tip_position,
		bobber_position,
		_current_sag,
	)

	_line_mesh.clear_surfaces()
	if rendered_points.size() < 2:
		return
	_draw_line_ribbon(rendered_points)


func _draw_line_ribbon(points: PackedVector3Array) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for point: Vector3 in points:
			_line_mesh.surface_add_vertex(to_local(point))
		_line_mesh.surface_end()
		return

	var half_thickness: float = line_thickness * 0.5
	_line_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for point_index: int in range(1, points.size()):
		var start: Vector3 = points[point_index - 1]
		var end: Vector3 = points[point_index]
		var segment: Vector3 = end - start
		if segment.length_squared() <= 0.000001:
			continue
		var to_camera: Vector3 = (
			camera.global_position - start.lerp(end, 0.5)
		)
		var side: Vector3 = segment.normalized().cross(to_camera.normalized())
		if side.length_squared() <= 0.000001:
			side = segment.normalized().cross(Vector3.UP)
		if side.length_squared() <= 0.000001:
			side = segment.normalized().cross(Vector3.RIGHT)
		side = side.normalized() * half_thickness

		var start_left: Vector3 = to_local(start - side)
		var start_right: Vector3 = to_local(start + side)
		var end_right: Vector3 = to_local(end + side)
		var end_left: Vector3 = to_local(end - side)
		_line_mesh.surface_add_vertex(start_left)
		_line_mesh.surface_add_vertex(start_right)
		_line_mesh.surface_add_vertex(end_right)
		_line_mesh.surface_add_vertex(start_left)
		_line_mesh.surface_add_vertex(end_right)
		_line_mesh.surface_add_vertex(end_left)
	_line_mesh.surface_end()


func _build_sagged_line_points(
	start: Vector3,
	end: Vector3,
	sag: float,
) -> PackedVector3Array:
	var points := PackedVector3Array()
	var subdivisions: int = 1 if sag <= 0.001 else sag_interpolation_count
	points.append(start)
	for step: int in range(1, subdivisions + 1):
		var progress: float = float(step) / float(subdivisions)
		var point: Vector3 = start.lerp(end, progress)
		if step < subdivisions and sag > 0.0:
			point.y -= 4.0 * progress * (1.0 - progress) * sag
		points.append(point)
	return points


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


func _set_target_validity(target_is_fishable: bool) -> void:
	_valid_target_marker.visible = target_is_fishable
	_invalid_target_marker.visible = not target_is_fishable


func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _kill_bite_tween() -> void:
	if _bite_tween != null and _bite_tween.is_valid():
		_bite_tween.kill()
	_bite_tween = null
	if is_instance_valid(_bobber):
		_bobber.scale = _bobber_base_scale


func _on_bite_tween_finished() -> void:
	_bite_tween = null


func _kill_rod_tween() -> void:
	if _rod_tween != null and _rod_tween.is_valid():
		_rod_tween.kill()
	_rod_tween = null
