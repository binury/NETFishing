extends SceneTree

const REGION := preload("res://world/regions/starter_island_region.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var region := REGION.instantiate()
	root.add_child(region)
	await process_frame
	var terrain := region.get_node(
		"Terrain/Visual/starter_island"
	) as MeshInstance3D
	assert(terrain != null)
	assert(terrain.mesh.get_surface_count() == 5)
	assert(terrain.mesh.surface_get_name(0) == "grass_lite")
	assert(terrain.mesh.surface_get_name(1) == "dirt")
	assert(terrain.mesh.surface_get_name(2) == "sand")
	assert(terrain.mesh.surface_get_name(3) == "cliff_wall")
	assert(terrain.mesh.surface_get_name(4) == "dirt_wall")

	_validate_projected_material(
		terrain.get_surface_override_material(0),
		"res://art/exported/environment/textures/grass_lite.png"
	)
	_validate_projected_material(
		terrain.get_surface_override_material(2),
		"res://art/exported/environment/textures/sand.png"
	)
	for surface: int in [1, 3, 4]:
		assert(terrain.get_surface_override_material(surface) == null)
		assert(terrain.mesh.surface_get_material(surface) is StandardMaterial3D)

	print("Terrain projection validation: PASS")
	region.free()
	quit()


func _validate_projected_material(
	material: Material,
	expected_texture_path: String,
) -> void:
	assert(material is ShaderMaterial)
	var shader_material := material as ShaderMaterial
	assert(
		shader_material.shader.resource_path
		== "res://world/materials/terrain_surface_projection.gdshader"
	)
	assert(
		is_equal_approx(
			float(shader_material.get_shader_parameter("tile_world_size")),
			2.5
		)
	)
	assert(
		is_equal_approx(
			float(shader_material.get_shader_parameter("blend_sharpness")),
			6.0
		)
	)
	assert(
		is_equal_approx(
			float(shader_material.get_shader_parameter("top_projection_bias")),
			2.0
		)
	)
	var texture: Texture2D = shader_material.get_shader_parameter(
		"albedo_texture"
	) as Texture2D
	assert(texture != null)
	assert(texture.resource_path == expected_texture_path)
	var imported_image: Image = texture.get_image()
	assert(imported_image != null)
	assert(not imported_image.has_mipmaps())
	assert(imported_image.get_format() == Image.FORMAT_RGBA8)
