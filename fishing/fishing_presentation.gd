class_name FishingPresentation
extends Node3D

signal cast_completed
signal outcome_completed(outcome: StringName)

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

@export_category("Water")
@export var water_surface_offset_y: float = -0.72
@export_range(0.1, 10.0, 0.1) var pickup_distance_from_player: float = 5.5

@export_category("Fishing Line")
@export_flags_3d_physics var line_obstacle_mask: int = 1
@export_range(1.0, 30.0, 0.5) var routing_probe_height: float = 8.0
@export_range(0.1, 2.0, 0.05) var obstruction_sample_spacing: float = 0.4
@export_range(0.01, 1.0, 0.01) var terrain_clearance: float = 0.1
@export_range(1, 3, 1) var maximum_obstruction_ranges: int = 1
@export_range(2, 12, 1) var maximum_contact_anchors_per_range: int = 5
@export_range(0.0, 3.0, 0.05) var route_lead_in_distance: float = 0.8
@export_range(0.0, 3.0, 0.05) var route_lead_out_distance: float = 0.8
@export_range(0.05, 2.0, 0.05) var fallback_arch_height: float = 0.35
@export_range(0.0, 0.5, 0.01) var slack_amount: float = 0.08
@export_range(0.0, 2.0, 0.01) var minimum_slack: float = 0.08
@export_range(0.0, 3.0, 0.01) var maximum_slack: float = 0.65
@export_range(2, 20, 1) var clear_span_interpolation_count: int = 8
@export_range(1, 8, 1) var contact_span_interpolation_count: int = 2
@export_range(0.1, 30.0, 0.1) var line_transition_speed: float = 7.0

@export_category("Cast")
@export_range(0.1, 30.0, 0.1) var target_movement_smoothing: float = 14.0
@export_range(0.1, 3.0, 0.05) var cast_travel_duration: float = 0.65
@export_range(0.1, 5.0, 0.1) var cast_arc_height: float = 2.0
@export_range(0.0, 90.0, 1.0) var maximum_rod_cock_degrees: float = 50.0
@export_range(0.0, 60.0, 1.0) var rod_forward_swing_degrees: float = 22.0
@export_range(0.05, 1.0, 0.01) var rod_forward_swing_duration: float = 0.12
@export_range(0.05, 1.0, 0.01) var rod_recovery_duration: float = 0.22
@export var valid_target_material: Material
@export var invalid_target_material: Material

@onready var _target_marker: MeshInstance3D = %CastTargetMarker
@onready var _invalid_cross_a: MeshInstance3D = %InvalidCrossA
@onready var _invalid_cross_b: MeshInstance3D = %InvalidCrossB
@onready var _bobber: MeshInstance3D = %Bobber
@onready var _line: MeshInstance3D = %FishingLine

var _mode: VisualMode = VisualMode.NONE
var _line_mode: LineMode = LineMode.HIDDEN
var _line_mesh: ImmediateMesh = ImmediateMesh.new()
var _route_points: PackedVector3Array = PackedVector3Array()
var _contact_start_anchor_index: int = -1
var _contact_end_anchor_index: int = -1
var _current_sag: float = 0.0
var _rod: Node3D
var _rod_tip: Marker3D
var _rod_neutral_rotation: Vector3
var _target_goal: Vector3
var _cast_position: Vector3
var _pickup_position: Vector3
var _active_tween: Tween
var _rod_tween: Tween
var _bite_tween: Tween
var _default_water_surface_offset_y: float


func _ready() -> void:
	_default_water_surface_offset_y = water_surface_offset_y
	_line.mesh = _line_mesh
	cleanup()


func _process(delta: float) -> void:
	if _mode == VisualMode.AIMING:
		var weight: float = 1.0 - exp(-target_movement_smoothing * delta)
		_target_marker.global_position = _target_marker.global_position.lerp(
			_target_goal,
			weight
		)
	if _line_mode != LineMode.HIDDEN:
		_update_line(delta)


func get_water_surface_height() -> float:
	return global_position.y + water_surface_offset_y


func set_water_surface_height(surface_height: float) -> void:
	water_surface_offset_y = surface_height - global_position.y


func reset_water_surface_height() -> void:
	water_surface_offset_y = _default_water_surface_offset_y


func set_line_mode(mode: LineMode) -> void:
	_line_mode = mode
	_line.visible = mode != LineMode.HIDDEN
	if mode == LineMode.HIDDEN:
		_current_sag = 0.0
		_route_points.clear()
		_contact_start_anchor_index = -1
		_contact_end_anchor_index = -1
		_line_mesh.clear_surfaces()


func begin_aim(
	rod_tip: Marker3D,
	rod: Node3D,
	minimum_target: Vector3,
	target_is_fishable: bool,
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
	_set_target_validity(target_is_fishable)


func update_rod_charge(charge: float) -> void:
	if _mode != VisualMode.AIMING or _rod == null:
		return

	var cock_rotation: Vector3 = _rod_neutral_rotation
	cock_rotation.x += deg_to_rad(maximum_rod_cock_degrees) * clampf(charge, 0.0, 1.0)
	_rod.rotation = cock_rotation


func update_aim_target(
	target: Vector3,
	charge: float,
	target_is_fishable: bool,
) -> void:
	if _mode != VisualMode.AIMING:
		return

	_target_goal = target
	var maximum_response: float = smoothstep(0.9, 1.0, clampf(charge, 0.0, 1.0))
	_target_marker.scale = Vector3.ONE * lerpf(1.0, 1.15, maximum_response)
	_set_target_validity(target_is_fishable)


func begin_cast(target: Vector3) -> void:
	if _mode != VisualMode.AIMING or _rod_tip == null:
		return

	_kill_active_tween()
	_mode = VisualMode.CASTING
	_target_marker.visible = false
	_bobber.visible = true
	_bobber.scale = Vector3.ONE
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

	_kill_bite_tween()
	_bobber.scale = Vector3.ONE
	_bite_tween = create_tween()
	_bite_tween.set_trans(Tween.TRANS_QUAD)
	_bite_tween.set_ease(Tween.EASE_IN_OUT)
	_bite_tween.tween_property(
		_bobber,
		"scale",
		Vector3.ONE * 0.68,
		0.08
	)
	_bite_tween.tween_property(
		_bobber,
		"scale",
		Vector3.ONE * 1.2,
		0.1
	)
	_bite_tween.tween_property(
		_bobber,
		"scale",
		Vector3.ONE,
		0.1
	)
	_bite_tween.finished.connect(_on_bite_tween_finished)


func show_withdrawal_position(position: Vector3) -> void:
	if _mode != VisualMode.FISHING:
		return

	_kill_active_tween()
	_bobber.global_position = _with_water_height(position)


func begin_reeling() -> void:
	if _mode != VisualMode.FISHING:
		return

	_kill_active_tween()
	_cast_position = _with_water_height(_bobber.global_position)


func show_reel_position(position: Vector3, _input_held: bool) -> void:
	if _mode != VisualMode.FISHING:
		return

	_kill_active_tween()
	_bobber.global_position = _with_water_height(position)


func play_outcome(outcome: StringName) -> void:
	if _mode == VisualMode.NONE:
		cleanup()
		return

	_kill_active_tween()
	_kill_bite_tween()
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
	_invalid_cross_a.visible = false
	_invalid_cross_b.visible = false
	_bobber.visible = false
	_bobber.scale = Vector3.ONE
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


func _update_line(delta: float) -> void:
	if _rod_tip == null or not is_instance_valid(_rod_tip):
		cleanup()
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
	_route_points = _build_line_route(rod_tip_position, bobber_position)
	var rendered_points: PackedVector3Array = _build_rendered_line_points(
		_route_points,
		_current_sag
	)

	_line_mesh.clear_surfaces()
	if rendered_points.size() < 2:
		return
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for point_index: int in range(1, rendered_points.size()):
		_line_mesh.surface_add_vertex(to_local(rendered_points[point_index - 1]))
		_line_mesh.surface_add_vertex(to_local(rendered_points[point_index]))
	_line_mesh.surface_end()


func _build_line_route(start: Vector3, end: Vector3) -> PackedVector3Array:
	_contact_start_anchor_index = -1
	_contact_end_anchor_index = -1
	if _raycast_obstacle(start, end).is_empty():
		return PackedVector3Array([start, end])

	var horizontal_delta := Vector2(end.x - start.x, end.z - start.z)
	var horizontal_length: float = horizontal_delta.length()
	if horizontal_length <= 0.001:
		return _build_fallback_arch(start, end)

	var sample_count: int = clampi(
		ceili(horizontal_length / obstruction_sample_spacing),
		2,
		64
	)
	var obstructed_samples := PackedByteArray()
	for sample_index: int in range(sample_count + 1):
		var progress: float = float(sample_index) / float(sample_count)
		var base_point: Vector3 = start.lerp(end, progress)
		var surface_hit: Dictionary = _probe_surface(base_point)
		var is_obstructed: bool = false
		if not surface_hit.is_empty():
			var surface_position: Vector3 = surface_hit["position"]
			var required_height: float = surface_position.y + terrain_clearance
			if required_height > base_point.y:
				is_obstructed = true
		obstructed_samples.append(1 if is_obstructed else 0)

	var obstruction_ranges: Array[Vector2i] = _find_obstruction_ranges(
		obstructed_samples
	)
	if obstruction_ranges.is_empty():
		return _build_fallback_arch(start, end)
	if obstruction_ranges.size() > maximum_obstruction_ranges:
		return _build_fallback_arch(start, end)

	var first_sample: int = obstruction_ranges[0].x
	var last_sample: int = obstruction_ranges[obstruction_ranges.size() - 1].y
	var first_progress: float = float(first_sample) / float(sample_count)
	var last_progress: float = float(last_sample) / float(sample_count)
	var lead_in_progress: float = maxf(
		0.0,
		first_progress - route_lead_in_distance / horizontal_length
	)
	var lead_out_progress: float = minf(
		1.0,
		last_progress + route_lead_out_distance / horizontal_length
	)

	var route := PackedVector3Array([start])
	_append_unique_route_point(route, start.lerp(end, lead_in_progress))
	_contact_start_anchor_index = route.size() - 1
	_append_contact_anchors(
		route,
		start,
		end,
		first_sample,
		last_sample,
		sample_count
	)
	_append_unique_route_point(route, start.lerp(end, lead_out_progress))
	_contact_end_anchor_index = route.size() - 1
	_append_unique_route_point(route, end)
	route = _remove_near_duplicate_route_points(route)
	_update_contact_indices_after_reduction(route)
	return _validate_reduced_route(route, start, end)


func _build_rendered_line_points(
	route: PackedVector3Array,
	sag: float,
) -> PackedVector3Array:
	var points := PackedVector3Array()
	if route.is_empty():
		return points
	if (
		_contact_start_anchor_index < 0
		or _contact_end_anchor_index < _contact_start_anchor_index
		or _contact_end_anchor_index >= route.size()
	):
		_append_clear_span(points, route[0], route[route.size() - 1], sag)
		return points

	_append_clear_span(
		points,
		route[0],
		route[_contact_start_anchor_index],
		sag
	)
	for anchor_index: int in range(
		_contact_start_anchor_index,
		_contact_end_anchor_index
	):
		_append_contact_span(
			points,
			route[anchor_index],
			route[anchor_index + 1]
		)
	_append_clear_span(
		points,
		route[_contact_end_anchor_index],
		route[route.size() - 1],
		sag
	)
	return points


func _raycast_obstacle(from: Vector3, to: Vector3) -> Dictionary:
	if from.is_equal_approx(to):
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		from,
		to,
		line_obstacle_mask
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func _find_obstruction_ranges(
	obstructed_samples: PackedByteArray,
) -> Array[Vector2i]:
	var ranges: Array[Vector2i] = []
	var range_start: int = -1
	for sample_index: int in range(obstructed_samples.size()):
		var is_obstructed: bool = obstructed_samples[sample_index] != 0
		if is_obstructed and range_start < 0:
			range_start = sample_index
		elif not is_obstructed and range_start >= 0:
			ranges.append(Vector2i(range_start, sample_index - 1))
			range_start = -1
	if range_start >= 0:
		ranges.append(Vector2i(range_start, obstructed_samples.size() - 1))
	return ranges


func _append_contact_anchors(
	route: PackedVector3Array,
	start: Vector3,
	end: Vector3,
	first_sample: int,
	last_sample: int,
	sample_count: int,
) -> void:
	var available_samples: int = last_sample - first_sample + 1
	var anchor_count: int = mini(
		available_samples,
		maximum_contact_anchors_per_range
	)
	for anchor_offset: int in range(anchor_count):
		var weight: float = 0.0
		if anchor_count > 1:
			weight = float(anchor_offset) / float(anchor_count - 1)
		var sample_index: int = roundi(
			lerpf(float(first_sample), float(last_sample), weight)
		)
		var progress: float = float(sample_index) / float(sample_count)
		var contact: Vector3 = _raise_point_above_obstacle(
			start.lerp(end, progress)
		)
		_append_unique_route_point(route, contact)


func _append_unique_route_point(
	route: PackedVector3Array,
	point: Vector3,
) -> void:
	if route.is_empty() or point.distance_to(route[route.size() - 1]) > 0.03:
		route.append(point)


func _remove_near_duplicate_route_points(
	route: PackedVector3Array,
) -> PackedVector3Array:
	var cleaned := PackedVector3Array()
	for point: Vector3 in route:
		_append_unique_route_point(cleaned, point)
	return cleaned


func _update_contact_indices_after_reduction(route: PackedVector3Array) -> void:
	if route.size() <= 2:
		_contact_start_anchor_index = -1
		_contact_end_anchor_index = -1
		return
	_contact_start_anchor_index = 1
	_contact_end_anchor_index = route.size() - 2


func _validate_reduced_route(
	route: PackedVector3Array,
	start: Vector3,
	end: Vector3,
) -> PackedVector3Array:
	var correction_index: int = -1
	var correction_hit: Dictionary
	for segment_index: int in range(route.size() - 1):
		var hit: Dictionary = _raycast_obstacle(
			route[segment_index],
			route[segment_index + 1]
		)
		if not hit.is_empty():
			correction_index = segment_index + 1
			correction_hit = hit
			break
	if correction_index < 0:
		return route

	var hit_position: Vector3 = correction_hit["position"]
	var correction: Vector3 = _raise_point_above_obstacle(hit_position)
	route.insert(correction_index, correction)
	_contact_start_anchor_index = mini(
		_contact_start_anchor_index,
		correction_index
	)
	_contact_end_anchor_index = maxi(
		_contact_end_anchor_index + 1,
		correction_index
	)
	for segment_index: int in range(route.size() - 1):
		if not _raycast_obstacle(
			route[segment_index],
			route[segment_index + 1]
		).is_empty():
			return _build_fallback_arch(start, end)
	return route


func _append_clear_span(
	points: PackedVector3Array,
	start: Vector3,
	end: Vector3,
	sag: float,
) -> void:
	if points.is_empty():
		points.append(start)
	elif not points[points.size() - 1].is_equal_approx(start):
		points.append(start)
	var subdivisions: int = 1 if sag <= 0.001 else clear_span_interpolation_count
	for step: int in range(1, subdivisions + 1):
		var progress: float = float(step) / float(subdivisions)
		var point: Vector3 = start.lerp(end, progress)
		if step < subdivisions and sag > 0.0:
			point.y -= 4.0 * progress * (1.0 - progress) * sag
			point.y = maxf(
				point.y,
				get_water_surface_height() + terrain_clearance * 0.25
			)
			point = _raise_point_above_obstacle(point)
		points.append(point)


func _append_contact_span(
	points: PackedVector3Array,
	start: Vector3,
	end: Vector3,
) -> void:
	if points.is_empty():
		points.append(start)
	elif not points[points.size() - 1].is_equal_approx(start):
		points.append(start)
	for step: int in range(1, contact_span_interpolation_count + 1):
		var progress: float = (
			float(step) / float(contact_span_interpolation_count)
		)
		var point: Vector3 = start.lerp(end, progress)
		if step < contact_span_interpolation_count:
			point = _raise_point_above_obstacle(point)
		points.append(point)


func _build_fallback_arch(
	start: Vector3,
	end: Vector3,
) -> PackedVector3Array:
	var route := PackedVector3Array([start])
	for progress: float in [0.25, 0.5, 0.75]:
		var point: Vector3 = start.lerp(end, progress)
		point.y += sin(progress * PI) * fallback_arch_height
		route.append(_raise_point_above_obstacle(point))
	route.append(end)
	_contact_start_anchor_index = 1
	_contact_end_anchor_index = route.size() - 2
	return route


func _probe_surface(point: Vector3) -> Dictionary:
	var probe_start: Vector3 = point + Vector3.UP * routing_probe_height
	var probe_end: Vector3 = point - Vector3.UP * routing_probe_height
	return _raycast_obstacle(probe_start, probe_end)


func _raise_point_above_obstacle(point: Vector3) -> Vector3:
	var hit: Dictionary = _probe_surface(point)
	if hit.is_empty():
		return point
	var surface_position: Vector3 = hit["position"]
	point.y = maxf(point.y, surface_position.y + terrain_clearance)
	return point


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
	if target_is_fishable:
		_target_marker.material_override = valid_target_material
	else:
		_target_marker.material_override = invalid_target_material
	_invalid_cross_a.visible = not target_is_fishable
	_invalid_cross_b.visible = not target_is_fishable


func _kill_active_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null


func _kill_bite_tween() -> void:
	if _bite_tween != null and _bite_tween.is_valid():
		_bite_tween.kill()
	_bite_tween = null
	if is_instance_valid(_bobber):
		_bobber.scale = Vector3.ONE


func _on_bite_tween_finished() -> void:
	_bite_tween = null


func _kill_rod_tween() -> void:
	if _rod_tween != null and _rod_tween.is_valid():
		_rod_tween.kill()
	_rod_tween = null
