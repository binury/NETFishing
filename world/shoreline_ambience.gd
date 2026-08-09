class_name ShorelineAmbience
extends Node

@export_range(0.0, 20.0, 0.1) var near_distance: float = 2.0
@export_range(1.0, 100.0, 0.5) var far_distance: float = 24.0
@export_range(-40.0, 12.0, 0.5) var near_volume_db: float = 1.0
@export_range(-80.0, 0.0, 0.5) var far_volume_db: float = -18.0
@export_range(0.05, 1.0, 0.05) var distance_update_interval: float = 0.2
@export_range(0.1, 20.0, 0.1) var volume_smoothing_speed: float = 4.0

@onready var _waves_audio: AudioStreamPlayer = %WavesAudio

var _listener: Node3D
var _shoreline_segments: Array[PackedVector2Array] = []
var _distance_update_remaining: float = 0.0
var _target_volume_db: float = -80.0
var _is_active := false


func _ready() -> void:
	_waves_audio.bus = &"Environment"
	_configure_audio_loop(_waves_audio.stream)
	_waves_audio.volume_db = -80.0
	set_process(false)


func configure(listener: Node3D, shoreline_mesh: MeshInstance3D) -> void:
	_listener = listener
	_shoreline_segments = _extract_shoreline_segments(shoreline_mesh)
	_distance_update_remaining = 0.0
	if _shoreline_segments.is_empty():
		push_warning("Saltwater shoreline ambience has no coastline geometry.")


func set_active(active: bool) -> void:
	_is_active = active
	set_process(active)
	if active:
		_distance_update_remaining = 0.0
		_update_target_volume()
		_waves_audio.volume_db = _target_volume_db
		if not _waves_audio.playing and _waves_audio.stream != null:
			_waves_audio.play()
	else:
		_waves_audio.stop()
		_waves_audio.volume_db = -80.0


func _process(delta: float) -> void:
	if not _is_active:
		return
	_distance_update_remaining -= delta
	if _distance_update_remaining <= 0.0:
		_distance_update_remaining = distance_update_interval
		_update_target_volume()
	_waves_audio.volume_db = lerpf(
		_waves_audio.volume_db,
		_target_volume_db,
		1.0 - exp(-volume_smoothing_speed * delta),
	)


func _update_target_volume() -> void:
	if _listener == null or _shoreline_segments.is_empty():
		_target_volume_db = -80.0
		return
	var listener_position := Vector2(
		_listener.global_position.x,
		_listener.global_position.z,
	)
	var distance := distance_to_segments(listener_position, _shoreline_segments)
	var blend := clampf(
		inverse_lerp(near_distance, maxf(near_distance + 0.01, far_distance), distance),
		0.0,
		1.0,
	)
	_target_volume_db = lerpf(near_volume_db, far_volume_db, smoothstep(0.0, 1.0, blend))


func _extract_shoreline_segments(
	shoreline_mesh: MeshInstance3D,
) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	var seen_segments: Dictionary = {}
	if shoreline_mesh == null or shoreline_mesh.mesh == null:
		return segments
	for surface_index in shoreline_mesh.mesh.get_surface_count():
		var arrays := shoreline_mesh.mesh.surface_get_arrays(surface_index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			continue
		for index_offset in range(0, indices.size() - 2, 3):
			var triangle := PackedVector2Array()
			for corner in 3:
				var vertex := shoreline_mesh.to_global(
					vertices[indices[index_offset + corner]]
				)
				triangle.append(Vector2(vertex.x, vertex.z))
			_append_unique_segment(segments, seen_segments, triangle[0], triangle[1])
			_append_unique_segment(segments, seen_segments, triangle[1], triangle[2])
			_append_unique_segment(segments, seen_segments, triangle[2], triangle[0])
	return segments


func _append_unique_segment(
	segments: Array[PackedVector2Array],
	seen_segments: Dictionary,
	start: Vector2,
	end: Vector2,
) -> void:
	if start.distance_squared_to(end) <= 0.000001:
		return
	# The baked ribbon repeats shared triangle edges. Quantized canonical keys
	# keep only distinct segments without an O(n²) startup pass.
	var first := start
	var second := end
	if first.x > second.x or (is_equal_approx(first.x, second.x) and first.y > second.y):
		first = end
		second = start
	var key := "%d,%d:%d,%d" % [
		roundi(first.x * 10000.0),
		roundi(first.y * 10000.0),
		roundi(second.x * 10000.0),
		roundi(second.y * 10000.0),
	]
	if seen_segments.has(key):
		return
	seen_segments[key] = true
	segments.append(PackedVector2Array([start, end]))


static func distance_to_segments(
	point: Vector2,
	segments: Array[PackedVector2Array],
) -> float:
	var closest_squared := INF
	for segment in segments:
		if segment.size() < 2:
			continue
		var closest := Geometry2D.get_closest_point_to_segment(
			point,
			segment[0],
			segment[1],
		)
		closest_squared = minf(closest_squared, point.distance_squared_to(closest))
	return sqrt(closest_squared) if closest_squared < INF else INF


func _configure_audio_loop(stream: AudioStream) -> void:
	var wav := stream as AudioStreamWAV
	if wav == null:
		return
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	if wav.loop_end <= wav.loop_begin:
		wav.loop_begin = 0
		wav.loop_end = int(round(wav.get_length() * wav.mix_rate))
