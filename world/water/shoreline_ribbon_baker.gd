@tool
class_name ShorelineRibbonBaker
extends Node

@export var water_bodies: Array[ShorelineRibbonConfig] = []
@export_enum("Off", "Raw", "Simplified", "Smoothed") var debug_path_stage := 0
@export_tool_button("Rebuild Shoreline Ribbons")
var rebuild_shorelines: Callable = rebuild_all


func rebuild_all() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for configuration: ShorelineRibbonConfig in water_bodies:
		var result := _rebuild(configuration)
		if result.is_empty():
			return []
		results.append(result)
	_update_debug_display(results)
	return results


func _rebuild(configuration: ShorelineRibbonConfig) -> Dictionary:
	if configuration == null:
		push_error("Shoreline ribbon configuration is missing.")
		return {}
	if configuration.water_type != WaterType.Type.SALT_WATER:
		return {
			"skipped": true,
			"water_type": configuration.water_type,
			"output_path": configuration.output_resource_path,
		}
	var source := get_node_or_null(configuration.terrain_source) as Node3D
	if source == null:
		push_error(
			"Shoreline terrain source was not found: %s"
			% configuration.terrain_source
		)
		return {}
	if configuration.output_resource_path.is_empty():
		push_error("Shoreline output resource path is empty.")
		return {}
	var faces := _terrain_faces(source)
	if faces.is_empty():
		push_error("Configured shoreline terrain source exposes no triangles.")
		return {}
	var result := ShorelineRibbonGenerator.generate(
		faces,
		configuration.water_height,
		configuration.generation_bounds,
		configuration.water_reference,
		configuration.water_is_inside,
		configuration.simplification_tolerance,
		configuration.smoothing_iterations,
		configuration.resample_spacing,
		configuration.corner_rounding_distance,
	)
	var output_directory := configuration.output_resource_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory))
	var save_error := ResourceSaver.save(
		result["mesh"], configuration.output_resource_path
	)
	if save_error != OK:
		push_error(
			"Failed to save %s: %s"
			% [configuration.output_resource_path, error_string(save_error)]
		)
		return {}
	result["output_path"] = configuration.output_resource_path
	result["water_height"] = configuration.water_height
	result["water_type"] = configuration.water_type
	result["skipped"] = false
	return result


func _update_debug_display(results: Array[Dictionary]) -> void:
	var previous := get_node_or_null("_ShorelinePathDebug")
	if previous != null:
		previous.queue_free()
	if not Engine.is_editor_hint() or debug_path_stage == 0:
		return
	var debug_mesh := ImmediateMesh.new()
	var debug_material := StandardMaterial3D.new()
	debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	debug_material.albedo_color = Color(1.0, 0.35, 0.65, 1.0)
	var stage_key: String = [
		"", "debug_raw_paths", "debug_simplified_paths", "debug_smoothed_paths"
	][debug_path_stage]
	for result: Dictionary in results:
		if result.get("skipped", false):
			continue
		var height := float(result["water_height"]) + 0.06
		for path_data: Dictionary in result[stage_key]:
			var points: PackedVector2Array = path_data["points"]
			if points.size() < 2:
				continue
			debug_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, debug_material)
			for point: Vector2 in points:
				debug_mesh.surface_add_vertex(Vector3(point.x, height, point.y))
			if path_data["closed"]:
				debug_mesh.surface_add_vertex(Vector3(points[0].x, height, points[0].y))
			debug_mesh.surface_end()
	var debug_instance := MeshInstance3D.new()
	debug_instance.name = "_ShorelinePathDebug"
	debug_instance.mesh = debug_mesh
	add_child(debug_instance)


func _terrain_faces(source: Node3D) -> PackedVector3Array:
	var result := PackedVector3Array()
	if source is CollisionShape3D:
		var collision_shape := source as CollisionShape3D
		var concave_shape := collision_shape.shape as ConcavePolygonShape3D
		if concave_shape == null:
			return result
		for vertex: Vector3 in concave_shape.get_faces():
			result.append(_to_map_space(source, vertex))
		return result
	if source is MeshInstance3D:
		var mesh_instance := source as MeshInstance3D
		if mesh_instance.mesh == null:
			return result
		for surface: int in mesh_instance.mesh.get_surface_count():
			var arrays := mesh_instance.mesh.surface_get_arrays(surface)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			if indices.is_empty():
				for vertex: Vector3 in vertices:
					result.append(_to_map_space(source, vertex))
			else:
				for index: int in indices:
					result.append(_to_map_space(source, vertices[index]))
	return result


func _to_map_space(source: Node3D, vertex: Vector3) -> Vector3:
	var map_root := get_parent() as Node3D
	if map_root == null:
		return source.to_global(vertex)
	return map_root.to_local(source.to_global(vertex))
