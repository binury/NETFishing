class_name TerrainChunkEdgeProfile
extends RefCounted

var edge := TerrainChunkTopology.Edge.NORTH
var points := PackedVector2Array()


func _init(
	profile_edge := TerrainChunkTopology.Edge.NORTH,
	profile_points := PackedVector2Array(),
) -> void:
	edge = profile_edge
	points = profile_points


func matches(other: TerrainChunkEdgeProfile, tolerance: float) -> bool:
	if other == null:
		return false
	var first_surface := _upper_surface_points()
	var second_surface := other._upper_surface_points()
	if first_surface.size() < 2 or second_surface.size() < 2:
		return false
	if (
		absf(first_surface[0].x - second_surface[0].x) > tolerance
		or absf(
			first_surface[first_surface.size() - 1].x
			- second_surface[second_surface.size() - 1].x
		) > tolerance
	):
		return false

	var sample_tangents := PackedFloat32Array()
	for point: Vector2 in first_surface:
		_append_unique_tangent(sample_tangents, point.x, tolerance)
	for point: Vector2 in second_surface:
		_append_unique_tangent(sample_tangents, point.x, tolerance)
	sample_tangents.sort()
	for tangent: float in sample_tangents:
		var first_height := _sample_height(first_surface, tangent)
		var second_height := _sample_height(second_surface, tangent)
		if absf(first_height - second_height) > tolerance:
			return false
	return true


func _upper_surface_points() -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		if (
			not result.is_empty()
			and is_equal_approx(result[result.size() - 1].x, point.x)
		):
			var previous := result[result.size() - 1]
			previous.y = maxf(previous.y, point.y)
			result[result.size() - 1] = previous
			continue
		result.append(point)
	return result


func _append_unique_tangent(
	tangents: PackedFloat32Array,
	tangent: float,
	tolerance: float,
) -> void:
	for existing: float in tangents:
		if absf(existing - tangent) <= tolerance:
			return
	tangents.append(tangent)


func _sample_height(surface: PackedVector2Array, tangent: float) -> float:
	if tangent <= surface[0].x:
		return surface[0].y
	for index: int in range(1, surface.size()):
		var right := surface[index]
		if tangent > right.x:
			continue
		var left := surface[index - 1]
		var span := right.x - left.x
		if is_zero_approx(span):
			return maxf(left.y, right.y)
		return lerpf(left.y, right.y, (tangent - left.x) / span)
	return surface[surface.size() - 1].y


func signature(quantization: float) -> String:
	var tokens := PackedStringArray()
	for point: Vector2 in points:
		tokens.append(
			"%d:%d"
			% [
				roundi(point.x / quantization),
				roundi(point.y / quantization),
			]
		)
	return ",".join(tokens)
