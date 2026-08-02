class_name SurfaceDrawingPlacement
extends RefCounted

const SNAP_DISTANCE: float = 0.55
const SNAP_PLANE_DISTANCE: float = 0.18
const SNAP_NORMAL_DOT: float = 0.94


static func resolve(
	origin: Vector3,
	normal: Vector3,
	fallback_tangent: Vector3,
	canvas_states: Array[Dictionary],
) -> Dictionary:
	var surface_normal: Vector3 = normal.normalized()
	var surface_tangent: Vector3 = _projected_tangent(
		fallback_tangent, surface_normal
	)
	var best: Dictionary = {
		"origin": origin,
		"normal": surface_normal,
		"tangent": surface_tangent,
		"snapped": false,
	}
	var nearest_distance: float = SNAP_DISTANCE
	for state: Dictionary in canvas_states:
		if not SurfaceDrawingProtocol.validate_canvas_state(state):
			continue
		var anchor_normal: Vector3 = SurfaceDrawingProtocol.array_to_vector(
			state["normal"]
		).normalized()
		if anchor_normal.dot(surface_normal) < SNAP_NORMAL_DOT:
			continue
		var anchor_origin: Vector3 = SurfaceDrawingProtocol.array_to_vector(
			state["origin"]
		)
		var relative: Vector3 = origin - anchor_origin
		if absf(relative.dot(anchor_normal)) > SNAP_PLANE_DISTANCE:
			continue
		var anchor_tangent: Vector3 = _projected_tangent(
			SurfaceDrawingProtocol.array_to_vector(state["tangent"]),
			anchor_normal,
		)
		var anchor_bitangent: Vector3 = anchor_normal.cross(
			anchor_tangent
		).normalized()
		var width: float = float(state["width"]) * float(state["cell_size"])
		var height: float = float(state["height"]) * float(state["cell_size"])
		if width <= 0.0 or height <= 0.0:
			continue
		var horizontal_step: int = roundi(relative.dot(anchor_tangent) / width)
		var vertical_step: int = roundi(relative.dot(anchor_bitangent) / height)
		if horizontal_step == 0 and vertical_step == 0:
			continue
		var candidate: Vector3 = (
			anchor_origin
			+ anchor_tangent * float(horizontal_step) * width
			+ anchor_bitangent * float(vertical_step) * height
		)
		var distance: float = candidate.distance_to(origin)
		if distance > nearest_distance:
			continue
		nearest_distance = distance
		best = {
			"origin": candidate,
			"normal": anchor_normal,
			"tangent": anchor_tangent,
			"snapped": true,
		}
	return best


static func _projected_tangent(
	value: Vector3,
	normal: Vector3,
) -> Vector3:
	var tangent: Vector3 = (value - normal * value.dot(normal)).normalized()
	if tangent.is_zero_approx():
		tangent = Vector3.UP.cross(normal).normalized()
	if tangent.is_zero_approx():
		tangent = Vector3.RIGHT
	return tangent
