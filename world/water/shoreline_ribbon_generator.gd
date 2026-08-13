class_name ShorelineRibbonGenerator
extends RefCounted

const WATER_PLANE_EPSILON := 0.001
const ENDPOINT_MERGE_TOLERANCE := 0.03
const LOOP_CLOSURE_TOLERANCE := 0.06
const MINIMUM_FRAGMENT_LENGTH := 2.0
const SIMPLIFICATION_TOLERANCE := 0.55
const SMOOTHING_ITERATIONS := 3
const RESAMPLE_SPACING := 0.16
const CORNER_ROUNDING_DISTANCE := 2.4
const CORNER_ROUNDING_START_DEGREES := 24.0
const CORNER_ROUNDING_FULL_DEGREES := 78.0
const MAXIMUM_JOIN_SCALE := 1.0
const RIBBON_REACH_GROWTH_PER_METER := 0.52
const RIBBON_WIDTH := 1.35
const LAND_INSET := 0.12
const SURFACE_OFFSET := 0.018


static func generate(
	faces: PackedVector3Array,
	water_height: float,
	bounds: Rect2,
	water_reference: Vector2,
	water_is_inside: bool,
	simplification_override := -1.0,
	smoothing_iterations_override := -1,
	resample_spacing_override := -1.0,
	corner_rounding_override := -1.0
) -> Dictionary:
	var simplification := (
		SIMPLIFICATION_TOLERANCE
		if simplification_override < 0.0
		else simplification_override
	)
	var smoothing_iterations := (
		SMOOTHING_ITERATIONS
		if smoothing_iterations_override < 0
		else smoothing_iterations_override
	)
	var resample_spacing := (
		RESAMPLE_SPACING
		if resample_spacing_override < 0.0
		else resample_spacing_override
	)
	var corner_rounding := (
		CORNER_ROUNDING_DISTANCE
		if corner_rounding_override < 0.0
		else corner_rounding_override
	)
	var segments := _extract_segments(faces, water_height, bounds)
	var raw_paths := _stitch_segments(segments)
	var processed_paths: Array[Dictionary] = []
	var simplified_paths: Array[Dictionary] = []
	var raw_point_count := 0
	var simplified_point_count := 0
	var smoothed_point_count := 0
	for path_data: Dictionary in raw_paths:
		var raw_points: PackedVector2Array = path_data["points"]
		var closed: bool = path_data["closed"]
		if _path_length(raw_points, closed) < MINIMUM_FRAGMENT_LENGTH:
			continue
		var simplified := _simplify(raw_points, closed, simplification)
		simplified_paths.append({"points": simplified, "closed": closed})
		var rounded := _round_sharp_corners(
			simplified,
			closed,
			corner_rounding,
		)
		var smoothed := _chaikin(rounded, closed, smoothing_iterations)
		var resampled := _resample(smoothed, closed, resample_spacing)
		if resampled.size() < (3 if closed else 2):
			continue
		raw_point_count += raw_points.size()
		simplified_point_count += simplified.size()
		smoothed_point_count += resampled.size()
		processed_paths.append({"points": resampled, "closed": closed})
	var mesh := _build_mesh(
		processed_paths,
		water_height,
		water_reference,
		water_is_inside
	)
	return {
		"mesh": mesh,
		"segment_count": segments.size(),
		"loop_count": processed_paths.size(),
		"raw_point_count": raw_point_count,
		"simplified_point_count": simplified_point_count,
		"smoothed_point_count": smoothed_point_count,
		"triangle_count": _mesh_triangle_count(mesh),
		"debug_raw_paths": raw_paths,
		"debug_simplified_paths": simplified_paths,
		"debug_smoothed_paths": processed_paths,
	}


static func _extract_segments(
	faces: PackedVector3Array,
	water_height: float,
	bounds: Rect2
) -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	for index: int in range(0, faces.size(), 3):
		var triangle: Array[Vector3] = [
			faces[index], faces[index + 1], faces[index + 2]
		]
		var hits := PackedVector2Array()
		for edge: int in 3:
			var a := triangle[edge]
			var b := triangle[(edge + 1) % 3]
			var distance_a := a.y - water_height
			var distance_b := b.y - water_height
			if (
				absf(distance_a) <= WATER_PLANE_EPSILON
				and absf(distance_b) <= WATER_PLANE_EPSILON
			):
				continue
			if not (
				distance_a * distance_b < 0.0
				or absf(distance_a) <= WATER_PLANE_EPSILON
				or absf(distance_b) <= WATER_PLANE_EPSILON
			):
				continue
			var denominator := distance_a - distance_b
			var amount := (
				0.0
				if absf(denominator) <= WATER_PLANE_EPSILON
				else distance_a / denominator
			)
			var hit3 := a.lerp(b, clampf(amount, 0.0, 1.0))
			var hit := Vector2(hit3.x, hit3.z)
			if bounds.has_point(hit) and not _contains_near(hits, hit):
				hits.append(hit)
		if (
			hits.size() == 2
			and hits[0].distance_to(hits[1]) > WATER_PLANE_EPSILON
		):
			segments.append(hits)
	return segments


static func _stitch_segments(
	segments: Array[PackedVector2Array]
) -> Array[Dictionary]:
	var point_by_key: Dictionary = {}
	var adjacency: Dictionary = {}
	var unused_edges: Dictionary = {}
	for segment: PackedVector2Array in segments:
		var a_key := _point_key(segment[0])
		var b_key := _point_key(segment[1])
		if a_key == b_key:
			continue
		point_by_key[a_key] = segment[0]
		point_by_key[b_key] = segment[1]
		if not adjacency.has(a_key):
			adjacency[a_key] = []
		if not adjacency.has(b_key):
			adjacency[b_key] = []
		var edge_key := _edge_key(a_key, b_key)
		if unused_edges.has(edge_key):
			continue
		(adjacency[a_key] as Array).append(b_key)
		(adjacency[b_key] as Array).append(a_key)
		unused_edges[edge_key] = true

	var starts: Array = []
	for key: Vector2i in adjacency:
		if (adjacency[key] as Array).size() != 2:
			starts.append(key)
	for key: Vector2i in adjacency:
		if not starts.has(key):
			starts.append(key)

	var paths: Array[Dictionary] = []
	for start: Vector2i in starts:
		while _has_unused_neighbor(start, adjacency, unused_edges):
			var walked := _walk_path(start, point_by_key, adjacency, unused_edges)
			if (walked["points"] as PackedVector2Array).size() >= 2:
				paths.append(walked)
	return paths


static func _walk_path(
	start: Vector2i,
	point_by_key: Dictionary,
	adjacency: Dictionary,
	unused_edges: Dictionary
) -> Dictionary:
	var points := PackedVector2Array()
	var previous := Vector2i(2147483647, 2147483647)
	var current := start
	var closed := false
	var guard := unused_edges.size() + 2
	while guard > 0:
		guard -= 1
		points.append(point_by_key[current])
		var next_key := Vector2i(2147483647, 2147483647)
		for candidate: Vector2i in adjacency[current]:
			if candidate == previous and (adjacency[current] as Array).size() > 1:
				continue
			if unused_edges.get(_edge_key(current, candidate), false):
				next_key = candidate
				break
		if next_key.x == 2147483647:
			for candidate: Vector2i in adjacency[current]:
				if unused_edges.get(_edge_key(current, candidate), false):
					next_key = candidate
					break
		if next_key.x == 2147483647:
			break
		unused_edges[_edge_key(current, next_key)] = false
		previous = current
		current = next_key
		if current == start:
			closed = true
			break
	return {"points": points, "closed": closed}


static func _simplify(
	points: PackedVector2Array,
	closed: bool,
	tolerance: float
) -> PackedVector2Array:
	if points.size() <= (4 if closed else 2):
		return points
	if not closed:
		return _rdp_open(points, tolerance)
	var split_a := 0
	var split_b := 1
	var greatest_distance := 0.0
	for a: int in points.size():
		for b: int in range(a + 1, points.size()):
			var distance := points[a].distance_squared_to(points[b])
			if distance > greatest_distance:
				greatest_distance = distance
				split_a = a
				split_b = b
	var first_arc := _closed_arc(points, split_a, split_b)
	var second_arc := _closed_arc(points, split_b, split_a)
	var first_result := _rdp_open(first_arc, tolerance)
	var second_result := _rdp_open(second_arc, tolerance)
	var result := PackedVector2Array()
	for index: int in first_result.size() - 1:
		result.append(first_result[index])
	for index: int in second_result.size() - 1:
		result.append(second_result[index])
	return result if result.size() >= 4 else points


static func _rdp_open(
	points: PackedVector2Array,
	tolerance: float
) -> PackedVector2Array:
	if points.size() <= 2:
		return points
	var greatest_distance := 0.0
	var split_index := 0
	for index: int in range(1, points.size() - 1):
		var distance := _point_segment_distance(
			points[index], points[0], points[points.size() - 1]
		)
		if distance > greatest_distance:
			greatest_distance = distance
			split_index = index
	if greatest_distance <= tolerance:
		return PackedVector2Array([points[0], points[points.size() - 1]])
	var left := _rdp_open(points.slice(0, split_index + 1), tolerance)
	var right := _rdp_open(points.slice(split_index), tolerance)
	var result := PackedVector2Array()
	for index: int in left.size() - 1:
		result.append(left[index])
	result.append_array(right)
	return result


static func _closed_arc(
	points: PackedVector2Array,
	start: int,
	finish: int
) -> PackedVector2Array:
	var result := PackedVector2Array()
	var index := start
	result.append(points[index])
	while index != finish:
		index = (index + 1) % points.size()
		result.append(points[index])
	return result


static func _chaikin(
	points: PackedVector2Array,
	closed: bool,
	iterations: int
) -> PackedVector2Array:
	var result := points
	for _iteration: int in iterations:
		var next := PackedVector2Array()
		if not closed:
			next.append(result[0])
		var edge_count := result.size() if closed else result.size() - 1
		for index: int in edge_count:
			var a := result[index]
			var b := result[(index + 1) % result.size()]
			next.append(a.lerp(b, 0.25))
			next.append(a.lerp(b, 0.75))
		if not closed:
			next.append(result[result.size() - 1])
		result = next
	return result


static func _round_sharp_corners(
	points: PackedVector2Array,
	closed: bool,
	rounding_distance: float,
) -> PackedVector2Array:
	if rounding_distance <= WATER_PLANE_EPSILON or points.size() < 3:
		return points
	var result := PackedVector2Array()
	for index: int in points.size():
		if not closed and (index == 0 or index == points.size() - 1):
			result.append(points[index])
			continue
		var previous := points[(index - 1 + points.size()) % points.size()]
		var point := points[index]
		var following := points[(index + 1) % points.size()]
		var incoming_vector := point - previous
		var outgoing_vector := following - point
		var incoming_length := incoming_vector.length()
		var outgoing_length := outgoing_vector.length()
		if (
			incoming_length <= WATER_PLANE_EPSILON
			or outgoing_length <= WATER_PLANE_EPSILON
		):
			result.append(point)
			continue
		var incoming := incoming_vector / incoming_length
		var outgoing := outgoing_vector / outgoing_length
		var turn_degrees := rad_to_deg(
			acos(clampf(incoming.dot(outgoing), -1.0, 1.0))
		)
		var corner_weight := smoothstep(
			CORNER_ROUNDING_START_DEGREES,
			CORNER_ROUNDING_FULL_DEGREES,
			turn_degrees,
		)
		var cut_distance := minf(
			rounding_distance * corner_weight,
			minf(incoming_length, outgoing_length) * 0.44,
		)
		if cut_distance <= WATER_PLANE_EPSILON:
			result.append(point)
			continue
		var entry := point - incoming * cut_distance
		var exit := point + outgoing * cut_distance
		var curve_steps := maxi(3, ceili(cut_distance / 0.22))
		for step: int in curve_steps + 1:
			var amount := float(step) / float(curve_steps)
			var first := entry.lerp(point, amount)
			var second := point.lerp(exit, amount)
			var rounded_point := first.lerp(second, amount)
			if (
				result.is_empty()
				or result[result.size() - 1].distance_to(rounded_point)
				> WATER_PLANE_EPSILON
			):
				result.append(rounded_point)
	return result


static func _resample(
	points: PackedVector2Array,
	closed: bool,
	spacing: float
) -> PackedVector2Array:
	var total_length := _path_length(points, closed)
	if total_length <= spacing:
		return points
	var count := maxi(roundi(total_length / spacing), 3 if closed else 2)
	var actual_spacing := total_length / float(count if closed else count - 1)
	var result := PackedVector2Array()
	var edge := 0
	var edge_start_distance := 0.0
	var edge_length := points[0].distance_to(points[1])
	for sample: int in count:
		var target := actual_spacing * sample
		while target > edge_start_distance + edge_length and edge < points.size() - 1:
			edge_start_distance += edge_length
			edge += 1
			if edge >= points.size() - 1:
				edge_length = points[edge].distance_to(points[0]) if closed else 0.0
			else:
				edge_length = points[edge].distance_to(points[edge + 1])
		var next_index := (edge + 1) % points.size()
		var amount := (
			0.0
			if edge_length <= WATER_PLANE_EPSILON
			else (target - edge_start_distance) / edge_length
		)
		result.append(points[edge].lerp(points[next_index], clampf(amount, 0.0, 1.0)))
	return result


static func _build_mesh(
	paths: Array[Dictionary],
	water_height: float,
	water_reference: Vector2,
	water_is_inside: bool
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for path_data: Dictionary in paths:
		var points: PackedVector2Array = path_data["points"]
		var closed: bool = path_data["closed"]
		var closed_water_side := (
			_closed_path_water_side(points, water_is_inside)
			if closed
			else 0.0
		)
		var base_index := vertices.size()
		var water_normals := PackedVector2Array()
		var join_scales := PackedFloat32Array()
		var water_reaches := PackedFloat32Array()
		for index: int in points.size():
			var previous := points[(index - 1 + points.size()) % points.size()]
			var following := points[(index + 1) % points.size()]
			if not closed:
				previous = points[maxi(index - 1, 0)]
				following = points[mini(index + 1, points.size() - 1)]
			var point := points[index]
			var incoming := previous.direction_to(point)
			var outgoing := point.direction_to(following)
			if incoming.is_zero_approx():
				incoming = outgoing
			if outgoing.is_zero_approx():
				outgoing = incoming
			var incoming_normal := Vector2(-incoming.y, incoming.x)
			var outgoing_normal := Vector2(-outgoing.y, outgoing.x)
			var water_normal := incoming_normal + outgoing_normal
			if water_normal.is_zero_approx():
				water_normal = outgoing_normal
			water_normal = water_normal.normalized()
			if closed:
				water_normal *= closed_water_side
			else:
				var toward_reference := point.direction_to(water_reference)
				if (
					(water_is_inside and water_normal.dot(toward_reference) < 0.0)
					or (not water_is_inside and water_normal.dot(toward_reference) > 0.0)
				):
					water_normal = -water_normal
			var join_scale := minf(
				1.0 / maxf(absf(water_normal.dot(outgoing_normal)), 0.55),
				MAXIMUM_JOIN_SCALE,
			)
			var water_reach := _safe_water_reach(
				incoming,
				outgoing,
				water_normal,
				previous.distance_to(point),
				point.distance_to(following),
				(RIBBON_WIDTH - LAND_INSET) * join_scale,
			)
			water_normals.append(water_normal)
			join_scales.append(join_scale)
			water_reaches.append(water_reach)
		water_reaches = _smooth_water_reaches(
			points,
			water_reaches,
			closed,
		)
		var path_distance := 0.0
		for index: int in points.size():
			if index > 0:
				path_distance += points[index - 1].distance_to(points[index])
			var point := points[index]
			var water_normal := water_normals[index]
			var join_scale := join_scales[index]
			var land_point := (
				point - water_normal * LAND_INSET * join_scale
			)
			var water_point := (
				point
				+ water_normal * water_reaches[index]
			)
			vertices.append(Vector3(land_point.x, water_height + SURFACE_OFFSET, land_point.y))
			vertices.append(Vector3(water_point.x, water_height + SURFACE_OFFSET, water_point.y))
			normals.append(Vector3.UP)
			normals.append(Vector3.UP)
			uvs.append(Vector2(path_distance, 0.0))
			uvs.append(Vector2(path_distance, 1.0))
		var edge_count := points.size() if closed else points.size() - 1
		for index: int in edge_count:
			var next := (index + 1) % points.size()
			var a := base_index + index * 2
			var b := a + 1
			var c := base_index + next * 2
			var d := c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _safe_water_reach(
	incoming: Vector2,
	outgoing: Vector2,
	water_normal: Vector2,
	incoming_length: float,
	outgoing_length: float,
	desired_reach: float,
) -> float:
	var turn_cross := incoming.cross(outgoing)
	var water_side := incoming.cross(water_normal)
	if turn_cross * water_side <= 0.0:
		return desired_reach
	var turn_angle := acos(clampf(incoming.dot(outgoing), -1.0, 1.0))
	if turn_angle <= WATER_PLANE_EPSILON:
		return desired_reach
	var radius := minf(incoming_length, outgoing_length) / maxf(
		2.0 * sin(turn_angle * 0.5),
		WATER_PLANE_EPSILON,
	)
	return minf(desired_reach, maxf(radius * 0.58, 0.24))


static func _smooth_water_reaches(
	points: PackedVector2Array,
	reaches: PackedFloat32Array,
	closed: bool,
) -> PackedFloat32Array:
	var result := reaches.duplicate()
	if result.size() < 2:
		return result
	for _pass: int in 3:
		var forward_start := 0 if closed else 1
		for index: int in range(forward_start, result.size()):
			var previous := (index - 1 + result.size()) % result.size()
			var allowed := (
				result[previous]
				+ points[previous].distance_to(points[index])
				* RIBBON_REACH_GROWTH_PER_METER
			)
			result[index] = minf(result[index], allowed)
		var backward_start := result.size() - 1 if closed else result.size() - 2
		for index: int in range(backward_start, -1, -1):
			var following := (index + 1) % result.size()
			var allowed := (
				result[following]
				+ points[index].distance_to(points[following])
				* RIBBON_REACH_GROWTH_PER_METER
			)
			result[index] = minf(result[index], allowed)
	return result


static func _closed_path_water_side(
	points: PackedVector2Array,
	water_is_inside: bool,
) -> float:
	var signed_area_twice := 0.0
	for index: int in points.size():
		signed_area_twice += points[index].cross(
			points[(index + 1) % points.size()]
		)
	var interior_side := 1.0 if signed_area_twice >= 0.0 else -1.0
	return interior_side if water_is_inside else -interior_side


static func _point_key(point: Vector2) -> Vector2i:
	return Vector2i(
		roundi(point.x / ENDPOINT_MERGE_TOLERANCE),
		roundi(point.y / ENDPOINT_MERGE_TOLERANCE)
	)


static func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y <= b.y):
		return "%d:%d|%d:%d" % [a.x, a.y, b.x, b.y]
	return "%d:%d|%d:%d" % [b.x, b.y, a.x, a.y]


static func _has_unused_neighbor(
	key: Vector2i,
	adjacency: Dictionary,
	unused_edges: Dictionary
) -> bool:
	for neighbor: Vector2i in adjacency[key]:
		if unused_edges.get(_edge_key(key, neighbor), false):
			return true
	return false


static func _contains_near(points: PackedVector2Array, point: Vector2) -> bool:
	for existing: Vector2 in points:
		if existing.distance_to(point) <= WATER_PLANE_EPSILON:
			return true
	return false


static func _point_segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var segment := b - a
	if segment.length_squared() <= WATER_PLANE_EPSILON:
		return point.distance_to(a)
	var amount := clampf((point - a).dot(segment) / segment.length_squared(), 0.0, 1.0)
	return point.distance_to(a + segment * amount)


static func _path_length(points: PackedVector2Array, closed: bool) -> float:
	var result := 0.0
	for index: int in points.size() - 1:
		result += points[index].distance_to(points[index + 1])
	if closed and points.size() > 2:
		result += points[points.size() - 1].distance_to(points[0])
	return result


static func _mesh_triangle_count(mesh: ArrayMesh) -> int:
	if mesh.get_surface_count() == 0:
		return 0
	var arrays := mesh.surface_get_arrays(0)
	return floori(
		float((arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size()) / 3.0
	)
