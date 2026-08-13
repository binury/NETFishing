extends SceneTree

const ShorelineMesh: ArrayMesh = preload(
	"res://world/generated/shorelines/starter_ocean_shoreline.tres"
)
const GEOMETRY_EPSILON := 0.0001
const CROSSING_NEIGHBORHOOD := 32


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(ShorelineMesh.get_surface_count() == 1)
	var arrays := ShorelineMesh.surface_get_arrays(0)
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	assert(not vertices.is_empty())
	assert(vertices.size() % 2 == 0)
	assert(indices.size() == vertices.size() * 3)
	var point_count := vertices.size() / 2
	var land_edge := PackedVector2Array()
	var water_edge := PackedVector2Array()
	for index: int in point_count:
		var land := vertices[index * 2]
		var water := vertices[index * 2 + 1]
		land_edge.append(Vector2(land.x, land.z))
		water_edge.append(Vector2(water.x, water.z))
		var ribbon_width := land.distance_to(water)
		assert(ribbon_width >= 0.34)
		assert(ribbon_width <= 1.5)
	var crossing_count := (
		_count_local_crossings(water_edge)
		+ _count_local_crossings(land_edge)
	)
	if crossing_count > 0:
		push_error(
			"Shoreline ribbon contains %d local edge crossings."
			% crossing_count
		)
		quit(1)
		return
	print("Shoreline ribbon validation: PASS")
	quit()


func _count_local_crossings(points: PackedVector2Array) -> int:
	var crossing_count := 0
	for first: int in points.size():
		var first_next := (first + 1) % points.size()
		var checked_neighbors := mini(
			CROSSING_NEIGHBORHOOD,
			points.size() - 2,
		)
		for offset: int in range(2, checked_neighbors + 1):
			var second := (first + offset) % points.size()
			var second_next := (second + 1) % points.size()
			if second_next == first:
				continue
			if _segments_cross(
				points[first],
				points[first_next],
				points[second],
				points[second_next],
			):
				crossing_count += 1
	return crossing_count


func _segments_cross(
	a: Vector2,
	b: Vector2,
	c: Vector2,
	d: Vector2,
) -> bool:
	if (
		maxf(a.x, b.x) < minf(c.x, d.x) - GEOMETRY_EPSILON
		or maxf(c.x, d.x) < minf(a.x, b.x) - GEOMETRY_EPSILON
		or maxf(a.y, b.y) < minf(c.y, d.y) - GEOMETRY_EPSILON
		or maxf(c.y, d.y) < minf(a.y, b.y) - GEOMETRY_EPSILON
	):
		return false
	var first_direction := b - a
	var second_direction := d - c
	var denominator := first_direction.cross(second_direction)
	if absf(denominator) <= GEOMETRY_EPSILON:
		return false
	var offset := c - a
	var first_amount := offset.cross(second_direction) / denominator
	var second_amount := offset.cross(first_direction) / denominator
	return (
		first_amount > GEOMETRY_EPSILON
		and first_amount < 1.0 - GEOMETRY_EPSILON
		and second_amount > GEOMETRY_EPSILON
		and second_amount < 1.0 - GEOMETRY_EPSILON
	)
