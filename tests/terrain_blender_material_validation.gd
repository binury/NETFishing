extends SceneTree

const REGION := preload("res://world/regions/starter_island_region.tscn")
const TERRAIN_MODEL_PATH: String = (
	"res://art/exported/environment/terrain/starter_island.glb"
)
const EXPECTED_SURFACES: Array[String] = [
	"grass_lite",
	"dirt",
	"cliff_wall",
	"dirt_wall",
	"sand",
	"sandstone_heavy",
]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var model_scene := load(TERRAIN_MODEL_PATH) as PackedScene
	_check(model_scene != null, "Starter-island GLB must load as a scene.")
	if model_scene == null:
		_finish()
		return

	var model_root := model_scene.instantiate()
	var model_terrain := _find_mesh(model_root, "starter_island")
	_check(model_terrain != null, "GLB must contain the starter_island mesh.")
	_check(_find_mesh(model_root, "Cube") == null, "GLB must not contain Cube.")
	if model_terrain != null:
		_validate_terrain_materials(model_terrain, "GLB")
	model_root.free()

	var region := REGION.instantiate()
	root.add_child(region)
	await process_frame
	var runtime_terrain := region.get_node_or_null(
		"Terrain/Visual/starter_island"
	) as MeshInstance3D
	_check(runtime_terrain != null, "Region must contain the terrain mesh.")
	if runtime_terrain != null:
		_validate_terrain_materials(runtime_terrain, "Region")
		for surface_index: int in runtime_terrain.mesh.get_surface_count():
			_check(
				runtime_terrain.get_surface_override_material(surface_index) == null,
				"Region surface %d must use its Blender material." % surface_index,
			)
	region.free()
	_finish()


func _find_mesh(node: Node, mesh_name: String) -> MeshInstance3D:
	if node is MeshInstance3D and node.name == mesh_name:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var match := _find_mesh(child, mesh_name)
		if match != null:
			return match
	return null


func _validate_terrain_materials(
	terrain: MeshInstance3D,
	context: String,
) -> void:
	_check(terrain.mesh != null, "%s terrain must have a mesh." % context)
	if terrain.mesh == null:
		return
	_check(
		terrain.mesh.get_surface_count() == EXPECTED_SURFACES.size(),
		"%s terrain must have %d surfaces." % [
			context,
			EXPECTED_SURFACES.size(),
		],
	)
	var checked_count := mini(
		terrain.mesh.get_surface_count(),
		EXPECTED_SURFACES.size(),
	)
	for surface_index: int in checked_count:
		var expected_name := EXPECTED_SURFACES[surface_index]
		_check(
			terrain.mesh.surface_get_name(surface_index) == expected_name,
			"%s surface %d must be named %s." % [
				context,
				surface_index,
				expected_name,
			],
		)
		var material := terrain.get_active_material(surface_index)
		_check(
			material is StandardMaterial3D,
			"%s surface %s must use a Blender material." % [
				context,
				expected_name,
			],
		)
		if material is StandardMaterial3D:
			var texture := (material as StandardMaterial3D).albedo_texture
			_check(
				texture != null,
				"%s surface %s must have an embedded texture." % [
					context,
					expected_name,
				],
			)
			if texture != null:
				_check(
					texture.resource_path.begins_with(TERRAIN_MODEL_PATH + "::"),
					"%s surface %s must source its texture from the GLB." % [
						context,
						expected_name,
					],
				)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("Blender terrain material validation: PASS")
		quit(0)
		return
	for failure: String in failures:
		printerr("Blender terrain material validation: ", failure)
	quit(1)
