class_name SprintDustTrail
extends MultiMeshInstance3D

const PUFF_COUNT: int = 12
const PUFF_SPACING: float = 0.46
const PUFF_LIFETIME: float = 0.62
const PUFF_GROW_TIME: float = 0.16
const PUFF_FADE_TIME: float = 0.22
const PUFF_BACK_OFFSET: float = 0.14
const PUFF_SIDE_OFFSET: float = 0.11
const PUFF_HEIGHT: float = 0.08
const PUFF_MIN_SCALE: float = 0.22

@export var puff_mesh: Mesh

var _puff_positions: Array[Vector3] = []
var _puff_ages := PackedFloat32Array()
var _puff_widths := PackedFloat32Array()
var _puff_heights := PackedFloat32Array()
var _puff_phases := PackedFloat32Array()
var _next_puff: int = 0
var _spawn_serial: int = 0
var _foot_side: float = -1.0
var _tracking_run: bool = false
var _previous_source_position: Vector3
var _distance_since_puff: float = 0.0


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_initialize_pool()


func update_trail(
	delta: float,
	source_position: Vector3,
	movement_velocity: Vector3,
	is_running: bool,
) -> void:
	_update_existing_puffs(delta)
	custom_aabb = AABB(
		source_position - Vector3(5.0, 2.0, 5.0),
		Vector3(10.0, 5.0, 10.0),
	)
	if not is_running:
		_tracking_run = false
		_distance_since_puff = 0.0
		return

	var flat_source := Vector3(
		source_position.x,
		source_position.y,
		source_position.z,
	)
	if not _tracking_run:
		_tracking_run = true
		_previous_source_position = flat_source
		_distance_since_puff = 0.0
		return

	var segment := flat_source - _previous_source_position
	segment.y = 0.0
	var remaining_distance: float = segment.length()
	if remaining_distance <= 0.0001:
		_previous_source_position = flat_source
		return

	var segment_direction: Vector3 = segment / remaining_distance
	var movement_direction := Vector3(
		movement_velocity.x,
		0.0,
		movement_velocity.z,
	).normalized()
	if movement_direction.is_zero_approx():
		movement_direction = segment_direction
	var cursor: Vector3 = _previous_source_position
	var distance_to_next: float = PUFF_SPACING - _distance_since_puff
	while remaining_distance >= distance_to_next:
		cursor += segment_direction * distance_to_next
		_spawn_puff(cursor, movement_direction)
		remaining_distance -= distance_to_next
		_distance_since_puff = 0.0
		distance_to_next = PUFF_SPACING
	_distance_since_puff += remaining_distance
	_previous_source_position = flat_source


func clear_trail() -> void:
	_tracking_run = false
	_distance_since_puff = 0.0
	for index: int in PUFF_COUNT:
		_puff_ages[index] = PUFF_LIFETIME
		_write_inactive_puff(index)


func emit_landing_burst(
	source_position: Vector3,
	facing_direction: Vector3,
) -> void:
	var direction := Vector3(
		facing_direction.x,
		0.0,
		facing_direction.z,
	).normalized()
	if direction.is_zero_approx():
		direction = Vector3.FORWARD
	var first_direction: Vector3 = -direction
	for puff_index: int in 5:
		var spread_direction := first_direction.rotated(
			Vector3.UP,
			TAU * float(puff_index) / 5.0,
		)
		var radius: float = lerpf(
			0.38,
			0.46,
			_stable_variation(_spawn_serial + puff_index + 81),
		)
		_spawn_puff_at(
			source_position
			+ spread_direction * radius
			+ Vector3.UP * PUFF_HEIGHT,
			0.95,
		)


func get_active_puff_count() -> int:
	var active_count: int = 0
	for age: float in _puff_ages:
		if age < PUFF_LIFETIME:
			active_count += 1
	return active_count


func get_first_active_puff_position() -> Vector3:
	for index: int in PUFF_COUNT:
		if _puff_ages[index] < PUFF_LIFETIME:
			return _puff_positions[index]
	return Vector3.INF


func _initialize_pool() -> void:
	var pool := MultiMesh.new()
	pool.transform_format = MultiMesh.TRANSFORM_3D
	pool.use_custom_data = true
	pool.instance_count = PUFF_COUNT
	pool.mesh = puff_mesh
	multimesh = pool
	_puff_positions.resize(PUFF_COUNT)
	_puff_ages.resize(PUFF_COUNT)
	_puff_widths.resize(PUFF_COUNT)
	_puff_heights.resize(PUFF_COUNT)
	_puff_phases.resize(PUFF_COUNT)
	clear_trail()


func _spawn_puff(source_position: Vector3, direction: Vector3) -> void:
	var lateral := Vector3(-direction.z, 0.0, direction.x)
	var position := (
		source_position
		- direction * PUFF_BACK_OFFSET
		+ lateral * PUFF_SIDE_OFFSET * _foot_side
		+ Vector3.UP * PUFF_HEIGHT
	)
	_spawn_puff_at(position)
	_foot_side *= -1.0


func _spawn_puff_at(
	position: Vector3,
	size_multiplier: float = 1.0,
) -> void:
	var variation: float = _stable_variation(_spawn_serial)
	var second_variation: float = _stable_variation(_spawn_serial + 37)
	var index: int = _next_puff
	_puff_positions[index] = position
	_puff_ages[index] = 0.0
	_puff_widths[index] = (
		lerpf(0.34, 0.43, variation) * size_multiplier
	)
	_puff_heights[index] = (
		lerpf(0.23, 0.30, second_variation) * size_multiplier
	)
	_puff_phases[index] = variation
	_write_puff(index, PUFF_MIN_SCALE, 1.0)
	_next_puff = (_next_puff + 1) % PUFF_COUNT
	_spawn_serial += 1


func _update_existing_puffs(delta: float) -> void:
	if multimesh == null:
		return
	for index: int in PUFF_COUNT:
		var age: float = _puff_ages[index]
		if age >= PUFF_LIFETIME:
			continue
		age += delta
		_puff_ages[index] = age
		if age >= PUFF_LIFETIME:
			_write_inactive_puff(index)
			continue
		var visual_scale: float = 1.0
		if age < PUFF_GROW_TIME:
			var grow_weight: float = smoothstep(
				0.0,
				1.0,
				age / PUFF_GROW_TIME,
			)
			visual_scale = lerpf(PUFF_MIN_SCALE, 1.0, grow_weight)
		var visual_alpha: float = 1.0
		if age > PUFF_LIFETIME - PUFF_FADE_TIME:
			var fade_weight: float = smoothstep(
				0.0,
				1.0,
				(age - (PUFF_LIFETIME - PUFF_FADE_TIME))
				/ PUFF_FADE_TIME,
			)
			visual_alpha = 1.0 - fade_weight
		_write_puff(index, visual_scale, visual_alpha)


func _write_puff(
	index: int,
	visual_scale: float,
	visual_alpha: float,
) -> void:
	var puff_transform := Transform3D.IDENTITY
	puff_transform.origin = _puff_positions[index]
	multimesh.set_instance_transform(index, puff_transform)
	multimesh.set_instance_custom_data(
		index,
		Color(
			_puff_phases[index],
			_puff_widths[index] * visual_scale,
			_puff_heights[index] * visual_scale,
			visual_alpha,
		),
	)


func _write_inactive_puff(index: int) -> void:
	var inactive_transform := Transform3D.IDENTITY
	inactive_transform.origin = _puff_positions[index]
	multimesh.set_instance_transform(index, inactive_transform)
	multimesh.set_instance_custom_data(index, Color(0.0, 0.0, 0.0, 0.0))


func _stable_variation(serial: int) -> float:
	return fposmod(sin(float(serial + 1) * 12.9898) * 43758.5453, 1.0)
