class_name TerrainChunkAnalyzer
extends RefCounted

const DEFAULT_EDGE_EPSILON := 0.005
const DEFAULT_PROFILE_QUANTIZATION := 0.001


static func create_variants(
	definition: TerrainChunkDefinition,
	chunk_size: float,
	edge_epsilon := DEFAULT_EDGE_EPSILON,
	profile_quantization := DEFAULT_PROFILE_QUANTIZATION,
) -> Array[TerrainChunkVariant]:
	var variants: Array[TerrainChunkVariant] = []
	if definition == null or definition.packed_scene == null:
		return variants
	var chunk_root := definition.packed_scene.instantiate()
	var primary_mesh := find_primary_mesh(
		chunk_root,
		definition.primary_mesh_name,
	)
	if primary_mesh == null or primary_mesh.mesh == null:
		push_error(
			"Terrain chunk %s has no MeshInstance3D named %s."
			% [definition.stable_id, definition.primary_mesh_name]
		)
		chunk_root.free()
		return variants

	var mesh_transform := _transform_relative_to(primary_mesh, chunk_root)
	var boundary_points := _collect_boundary_points(
		primary_mesh.mesh,
		mesh_transform,
		chunk_size,
		edge_epsilon,
	)
	if definition.base_layer_scene != null:
		var base_layer_root := definition.base_layer_scene.instantiate()
		var base_layer_mesh := find_primary_mesh(
			base_layer_root,
			definition.base_layer_mesh_name,
		)
		if base_layer_mesh == null or base_layer_mesh.mesh == null:
			push_error(
				"Terrain chunk %s has no base-layer MeshInstance3D named %s."
				% [definition.stable_id, definition.base_layer_mesh_name]
			)
			base_layer_root.free()
			chunk_root.free()
			return variants
		boundary_points.append_array(
			_collect_boundary_points(
				base_layer_mesh.mesh,
				_transform_relative_to(base_layer_mesh, base_layer_root),
				chunk_size,
				edge_epsilon,
			)
		)
		base_layer_root.free()
	for quarter_turns: int in 4:
		if not definition.allows_quarter_turn(quarter_turns):
			continue
		var rotated_points := _rotate_points(boundary_points, quarter_turns)
		var variant := TerrainChunkVariant.new()
		variant.definition = definition
		variant.quarter_turns = quarter_turns
		variant.edge_profiles = _build_profiles(
			rotated_points,
			chunk_size,
			edge_epsilon,
			profile_quantization,
		)
		variants.append(variant)
	chunk_root.free()
	return variants


static func find_primary_mesh(
	root: Node,
	primary_mesh_name: StringName,
) -> MeshInstance3D:
	if root is MeshInstance3D and root.name == primary_mesh_name:
		return root as MeshInstance3D
	for candidate: Node in root.find_children(
		"*",
		"MeshInstance3D",
		true,
		false,
	):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance != null and mesh_instance.name == primary_mesh_name:
			return mesh_instance
	return null


static func _transform_relative_to(node: Node3D, root: Node) -> Transform3D:
	var relative_transform := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			relative_transform = (
				(current as Node3D).transform * relative_transform
			)
		current = current.get_parent()
	return relative_transform


static func _collect_boundary_points(
	mesh: Mesh,
	mesh_transform: Transform3D,
	chunk_size: float,
	edge_epsilon: float,
) -> PackedVector3Array:
	var result := PackedVector3Array()
	var half_size := chunk_size * 0.5
	var unique_points: Dictionary[Vector3i, bool] = {}
	for surface_index: int in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface_index)
		if arrays.is_empty():
			continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for source_vertex: Vector3 in vertices:
			var vertex := mesh_transform * source_vertex
			if not _is_boundary_point(vertex, half_size, edge_epsilon):
				continue
			var key := Vector3i(
				roundi(vertex.x / edge_epsilon),
				roundi(vertex.y / edge_epsilon),
				roundi(vertex.z / edge_epsilon),
			)
			if unique_points.has(key):
				continue
			unique_points[key] = true
			result.append(vertex)
	return result


static func _is_boundary_point(
	point: Vector3,
	half_size: float,
	tolerance: float,
) -> bool:
	return (
		absf(absf(point.x) - half_size) <= tolerance
		or absf(absf(point.z) - half_size) <= tolerance
	)


static func _rotate_points(
	points: PackedVector3Array,
	quarter_turns: int,
) -> PackedVector3Array:
	var result := PackedVector3Array()
	var angle := float(posmod(quarter_turns, 4)) * PI * 0.5
	for point: Vector3 in points:
		result.append(point.rotated(Vector3.UP, angle))
	return result


static func _build_profiles(
	boundary_points: PackedVector3Array,
	chunk_size: float,
	edge_epsilon: float,
	profile_quantization: float,
) -> Array[TerrainChunkEdgeProfile]:
	var profiles: Array[TerrainChunkEdgeProfile] = []
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var edge := edge_value as TerrainChunkTopology.Edge
		profiles.append(
			_build_profile(
				edge,
				boundary_points,
				chunk_size * 0.5,
				edge_epsilon,
				profile_quantization,
			)
		)
	return profiles


static func _build_profile(
	edge: TerrainChunkTopology.Edge,
	boundary_points: PackedVector3Array,
	half_size: float,
	edge_epsilon: float,
	profile_quantization: float,
) -> TerrainChunkEdgeProfile:
	var unique_points: Dictionary[Vector2i, bool] = {}
	var profile_points: Array[Vector2] = []
	for point: Vector3 in boundary_points:
		if not _point_is_on_edge(point, edge, half_size, edge_epsilon):
			continue
		var tangent := (
			point.x
			if edge in [
				TerrainChunkTopology.Edge.NORTH,
				TerrainChunkTopology.Edge.SOUTH,
			]
			else point.z
		)
		var key := Vector2i(
			roundi(tangent / profile_quantization),
			roundi(point.y / profile_quantization),
		)
		if unique_points.has(key):
			continue
		unique_points[key] = true
		profile_points.append(
			Vector2(key.x, key.y) * profile_quantization
		)
	profile_points.sort_custom(_profile_point_less_than)
	return TerrainChunkEdgeProfile.new(
		edge,
		PackedVector2Array(profile_points),
	)


static func _point_is_on_edge(
	point: Vector3,
	edge: TerrainChunkTopology.Edge,
	half_size: float,
	tolerance: float,
) -> bool:
	match edge:
		TerrainChunkTopology.Edge.NORTH:
			return absf(point.z + half_size) <= tolerance
		TerrainChunkTopology.Edge.EAST:
			return absf(point.x - half_size) <= tolerance
		TerrainChunkTopology.Edge.SOUTH:
			return absf(point.z - half_size) <= tolerance
		TerrainChunkTopology.Edge.WEST:
			return absf(point.x + half_size) <= tolerance
	return false


static func _profile_point_less_than(a: Vector2, b: Vector2) -> bool:
	if is_equal_approx(a.x, b.x):
		return a.y < b.y
	return a.x < b.x
