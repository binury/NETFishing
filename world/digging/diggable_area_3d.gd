@tool
class_name DiggableArea3D
extends Node3D

@export var area_id: StringName
@export_node_path("Node3D") var terrain_source: NodePath
@export var surface_materials: Array[StringName] = []
@export var generation_bounds := Rect2(-50.0, -50.0, 100.0, 100.0)
@export_range(-100.0, 100.0, 0.01) var minimum_global_y: float = -100.0
@export_range(-100.0, 100.0, 0.01) var maximum_global_y: float = 100.0
@export_range(0.0, 1.0, 0.01) var minimum_up_dot: float = 0.6


func get_surface_triangles() -> Array[PackedVector3Array]:
	var triangles: Array[PackedVector3Array] = []
	if area_id.is_empty() or surface_materials.is_empty():
		return triangles
	var terrain_root: Node = get_node_or_null(terrain_source)
	if terrain_root == null:
		return triangles
	for mesh_instance: MeshInstance3D in _collect_mesh_instances(terrain_root):
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		for surface_index: int in mesh.get_surface_count():
			var material: Material = mesh_instance.get_active_material(surface_index)
			if (
				material == null
				or not surface_materials.has(StringName(material.resource_name))
			):
				continue
			_append_surface_triangles(
				triangles,
				mesh_instance,
				mesh.surface_get_arrays(surface_index),
			)
	return triangles


func _append_surface_triangles(
	result: Array[PackedVector3Array],
	mesh_instance: MeshInstance3D,
	arrays: Array,
) -> void:
	if arrays.size() <= Mesh.ARRAY_INDEX:
		return
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	if vertices.is_empty():
		return
	if indices.is_empty():
		for vertex_index: int in range(0, vertices.size() - 2, 3):
			_append_triangle(
				result,
				mesh_instance.to_global(vertices[vertex_index]),
				mesh_instance.to_global(vertices[vertex_index + 1]),
				mesh_instance.to_global(vertices[vertex_index + 2]),
			)
		return
	for index_offset: int in range(0, indices.size() - 2, 3):
		_append_triangle(
			result,
			mesh_instance.to_global(vertices[indices[index_offset]]),
			mesh_instance.to_global(vertices[indices[index_offset + 1]]),
			mesh_instance.to_global(vertices[indices[index_offset + 2]]),
		)


func _append_triangle(
	result: Array[PackedVector3Array],
	a: Vector3,
	b: Vector3,
	c: Vector3,
) -> void:
	if (
		a.y < minimum_global_y
		or b.y < minimum_global_y
		or c.y < minimum_global_y
		or a.y > maximum_global_y
		or b.y > maximum_global_y
		or c.y > maximum_global_y
	):
		return
	var center := (a + b + c) / 3.0
	if not generation_bounds.has_point(Vector2(center.x, center.z)):
		return
	var cross := (b - a).cross(c - a)
	if cross.length_squared() <= 0.0000001:
		return
	if absf(cross.normalized().dot(Vector3.UP)) < minimum_up_dot:
		return
	result.append(PackedVector3Array([a, b, c]))


func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		meshes.append(root as MeshInstance3D)
	for child: Node in root.get_children():
		meshes.append_array(_collect_mesh_instances(child))
	return meshes


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if area_id.is_empty():
		warnings.append("Diggable area ID is required.")
	if get_node_or_null(terrain_source) == null:
		warnings.append("Diggable area terrain source is unavailable.")
	if surface_materials.is_empty():
		warnings.append("At least one terrain material is required.")
	if maximum_global_y < minimum_global_y:
		warnings.append("Maximum height must not be below minimum height.")
	return warnings
