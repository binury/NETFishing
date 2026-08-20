extends SceneTree

const RegionScene: PackedScene = preload(
	"res://world/generation/generated_world_region.tscn"
)
const FIRST_SEED := 13001
const SECOND_SEED := 13004
const EXPECTED_PROP_IDS: Array[StringName] = [
	&"prop_bridge",
	&"prop_dock",
	&"prop_log",
	&"prop_log_post_1",
	&"prop_log_post_2",
	&"prop_mushroom",
	&"prop_palm",
	&"prop_pine",
	&"prop_timber_1",
	&"prop_timber_2",
	&"prop_tree_1",
	&"prop_tree_2",
	&"prop_tree_3",
]
const EXPECTED_BIOME_IDS: Array[StringName] = [
	&"biome_plains",
	&"biome_forest",
	&"biome_pine_forest",
	&"biome_coast",
]
const PROCEDURAL_PROP_IDS: Array[StringName] = [
	&"prop_log",
	&"prop_mushroom",
	&"prop_palm",
	&"prop_pine",
	&"prop_tree_1",
	&"prop_tree_2",
	&"prop_tree_3",
]


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var region := RegionScene.instantiate() as GeneratedWorldRegion
	assert(region != null)
	root.add_child(region)
	await process_frame
	await physics_frame

	var generator := region.get_node(
		"Terrain/TerrainChunkGenerator"
	) as TerrainChunkGenerator
	assert(generator != null)
	assert(region.get_generation_seed() == FIRST_SEED)
	_validate_generated_region(region, generator)

	var first_layout := generator.placement_keys()
	var first_biomes := _biome_signature(region, generator)
	var first_decorations := _decoration_signature(region)
	assert(region.generate_world(FIRST_SEED))
	assert(generator.placement_keys() == first_layout)
	assert(_biome_signature(region, generator) == first_biomes)
	assert(_decoration_signature(region) == first_decorations)

	assert(region.generate_world(SECOND_SEED))
	await process_frame
	await physics_frame
	await physics_frame
	_validate_generated_region(region, generator)
	assert(generator.placement_keys() != first_layout)
	assert(_biome_signature(region, generator) != first_biomes)

	region.queue_free()
	await process_frame
	print("Generated world runtime validation: PASS")
	quit()


func _validate_generated_region(
	region: GeneratedWorldRegion,
	generator: TerrainChunkGenerator,
) -> void:
	var placements := generator.placement_keys()
	var expected_chunk_count := generator.grid_size.x * generator.grid_size.y
	var center := Vector2i(
		generator.grid_size.x / 2,
		generator.grid_size.y / 2,
	)
	var center_index := center.y * generator.grid_size.x + center.x
	assert(placements.size() == expected_chunk_count)
	assert(placements[center_index].begins_with("chunk_spawn@"))
	assert(_placement_count(placements, "chunk_spawn") == 1)
	assert(_placement_count(placements, "chunk_0001") >= 1)
	assert(_placement_count(placements, "chunk_0002") >= 1)
	assert(_placement_count(placements, "chunk_0003") >= 1)
	assert(_placement_count(placements, "chunk_0004") >= 1)
	assert(_placement_count(placements, "chunk_0005") >= 1)
	assert(_placement_count(placements, "chunk_0006") >= 1)
	assert(_placement_count(placements, "chunk_0007") >= 1)
	assert(_placement_count(placements, "chunk_0008") >= 1)
	assert(_placement_count(placements, "chunk_0009") == 1)
	assert(_placement_count(placements, "chunk_0010") == 4)
	assert(
		_placement_count(placements, "chunk_0011")
		+ _placement_count(placements, "chunk_0012")
		== 4
	)
	assert(_placement_count(placements, "chunk_0012") <= 1)
	assert(
		generator.get_generated_chunks_root().get_child_count()
		== expected_chunk_count
	)
	assert(
		generator.get_primary_terrain_meshes().size()
		== expected_chunk_count
	)
	_validate_elevated_cliff_feature(generator)

	var shop := region.get_node("Interactables/FishingShopWorld") as Node3D
	var storage := region.get_node("Interactables/PlayerStorageBox") as Node3D
	assert(shop != null and shop.has_node("Shopkeeper"))
	assert(storage != null and storage.has_node("InteractionArea"))
	assert(absf(shop.position.x) < 5.0 and absf(shop.position.z) < 5.0)
	assert(absf(storage.position.x) < 5.0 and absf(storage.position.z) < 5.0)
	assert(region.get_fishing_shop() != null)
	assert(region.get_player_storage() != null)
	assert(region.get_player_spawn_transform().origin.y > 0.0)
	_validate_prop_catalog(region)
	_validate_biome_catalog(region, generator)

	var ocean := region.get_node("WaterBodies/OceanWater") as WaterBodyAuthoring
	var fresh_root := region.get_node("WaterBodies/FreshWaterBodies") as Node3D
	assert(ocean != null and fresh_root != null)
	assert(ocean.water_type == WaterType.Type.SALT_WATER)
	assert(is_equal_approx(ocean.position.y, GeneratedWorldRegion.WATER_HEIGHT))
	var fresh_placement_count := 0
	for record: Dictionary in generator.placement_records():
		var tags: PackedStringArray = record.get("tags", PackedStringArray())
		if "coast" in tags:
			_validate_ocean_facing_record(record, generator.grid_size)
		if "fresh_water" in tags:
			fresh_placement_count += 1
	assert(fresh_root.get_child_count() == fresh_placement_count)
	for child: Node in fresh_root.get_children():
		var fresh := child as WaterBodyAuthoring
		assert(fresh != null)
		assert(fresh.water_type == WaterType.Type.FRESH_WATER)
		assert(is_equal_approx(fresh.position.y, GeneratedWorldRegion.WATER_HEIGHT))
		assert(fresh.visible)
		assert(fresh.surface_size.x < 10.0 or fresh.surface_size.y < 10.0)
		assert(not fresh.visual_surface_enabled)
		assert(not (fresh.get_node("VisualWater") as MeshInstance3D).visible)

	_validate_authored_chunk_surfaces(region, generator)

	var decorations := region.get_node("Decorations") as Node3D
	var anchors := region.get_node(
		"GatherableAnchors/ReachableTreeTrunks"
	) as GatherableAnchorSet3D
	assert(decorations != null and decorations.get_child_count() > 0)
	assert(anchors != null)
	assert(anchors.get_spawn_positions().size() > 0)
	for child: Node in decorations.get_children():
		var prop_id := StringName(child.get_meta(&"terrain_prop_id", &""))
		assert(PROCEDURAL_PROP_IDS.has(prop_id))
		var definition := region.get_prop_catalog().definition_for_id(prop_id)
		assert(definition != null)
		var biome_id := StringName(
			child.get_meta(&"terrain_biome_id", &"")
		)
		var biome := region.get_biome_catalog().definition_for_id(biome_id)
		assert(biome != null)
		var biome_rule := biome.prop_rule_for_group(
			definition.procedural_group
		)
		assert(biome_rule != null and biome_rule.allows_prop(definition))
		var coordinate: Vector2i = child.get_meta(
			&"terrain_chunk_coordinate",
			Vector2i.ZERO,
		)
		var spawn_coordinate := Vector2i(
			generator.grid_size.x / 2,
			generator.grid_size.y / 2,
		)
		var spawn_distance := (
			absi(coordinate.x - spawn_coordinate.x)
			+ absi(coordinate.y - spawn_coordinate.y)
		)
		assert(spawn_distance >= definition.minimum_spawn_chunk_distance)
		_validate_decoration_transform(
			region,
			child as Node3D,
			definition,
		)
		if prop_id in [&"prop_tree_1", &"prop_tree_2", &"prop_tree_3"]:
			assert(
				_has_material_variant_override(
					child.get_node_or_null("Visual"),
					definition.material_variants,
				)
			)
	assert(_decoration_group_count(region, &"grass_tree") > 0)
	assert(_decoration_group_count(region, &"sand_tree") > 0)
	assert(
		_decoration_biome_group_count(
			region,
			&"biome_forest",
			&"grass_tree",
		) >= 2
	)
	assert(
		_decoration_biome_group_count(
			region,
			&"biome_pine_forest",
			&"grass_tree",
		) >= 2
	)


func _validate_elevated_cliff_feature(
	generator: TerrainChunkGenerator,
) -> void:
	var elevated_coordinates: Dictionary[Vector2i, StringName] = {}
	var top_coordinate := Vector2i(-1, -1)
	for record: Dictionary in generator.placement_records():
		var stable_id: StringName = record.get("stable_id", &"")
		if stable_id not in [
			&"chunk_0009",
			&"chunk_0010",
			&"chunk_0011",
			&"chunk_0012",
		]:
			continue
		var coordinate: Vector2i = record.get("coordinate", Vector2i.ZERO)
		assert(coordinate.x > 0 and coordinate.x < generator.grid_size.x - 1)
		assert(coordinate.y > 0 and coordinate.y < generator.grid_size.y - 1)
		elevated_coordinates[coordinate] = stable_id
		if stable_id == &"chunk_0009":
			top_coordinate = coordinate
	assert(elevated_coordinates.size() == 9)
	assert(top_coordinate != Vector2i(-1, -1))
	for row_offset: int in range(-1, 2):
		for column_offset: int in range(-1, 2):
			assert(
				elevated_coordinates.has(
					top_coordinate + Vector2i(column_offset, row_offset)
				)
			)

	var generated := generator.get_generated_chunks_root()
	assert(generated != null)
	var layered_count := 0
	for chunk_root: Node in generated.get_children():
		var stable_id := StringName(
			chunk_root.get_meta(&"terrain_chunk_id", &"")
		)
		if stable_id not in [
			&"chunk_0009",
			&"chunk_0010",
			&"chunk_0011",
			&"chunk_0012",
		]:
			continue
		layered_count += 1
		var base_layer := chunk_root.get_node_or_null("TerrainBaseLayer")
		var overlay := chunk_root.get_node_or_null("TerrainOverlay")
		assert(base_layer != null and overlay != null)
		var base_mesh := TerrainChunkAnalyzer.find_primary_mesh(
			base_layer,
			&"chunk_0000",
		)
		var overlay_mesh := TerrainChunkAnalyzer.find_primary_mesh(
			overlay,
			stable_id,
		)
		assert(base_mesh != null and base_mesh.mesh != null)
		assert(overlay_mesh != null and overlay_mesh.mesh != null)
		assert(base_mesh.has_node("TerrainBaseLayerCollision"))
		assert(overlay_mesh.has_node("TerrainCollision"))
	assert(layered_count == 9)


func _validate_ocean_facing_record(
	record: Dictionary,
	grid_size: Vector2i,
) -> void:
	var coordinate: Vector2i = record.get("coordinate", Vector2i.ZERO)
	var ocean_edges := int(record.get("ocean_facing_edges", 0))
	assert(ocean_edges != 0)
	for edge_value: int in TerrainChunkTopology.Edge.values():
		if (ocean_edges & (1 << edge_value)) == 0:
			continue
		var ocean_coordinate := (
			coordinate
			+ TerrainChunkTopology.grid_offset(
				edge_value as TerrainChunkTopology.Edge
			)
		)
		assert(
			ocean_coordinate.x < 0
			or ocean_coordinate.y < 0
			or ocean_coordinate.x >= grid_size.x
			or ocean_coordinate.y >= grid_size.y
		)


func _validate_prop_catalog(region: GeneratedWorldRegion) -> void:
	var catalog := region.get_prop_catalog()
	assert(catalog != null)
	assert(catalog.validation_errors().is_empty())
	assert(catalog.definitions.size() == EXPECTED_PROP_IDS.size())
	for stable_id: StringName in EXPECTED_PROP_IDS:
		var definition := catalog.definition_for_id(stable_id)
		assert(definition != null and definition.packed_scene != null)
		var instance := definition.packed_scene.instantiate() as Node3D
		assert(instance != null)
		assert(instance.position.is_zero_approx())
		assert(_find_mesh_instance(instance) != null)
		instance.free()
	var mushroom := catalog.definition_for_id(&"prop_mushroom")
	assert(mushroom != null and mushroom.has_collision())
	assert(mushroom.visual_offset.y < 0.0)
	for tree_id: StringName in [
		&"prop_tree_1",
		&"prop_tree_2",
		&"prop_tree_3",
	]:
		var tree := catalog.definition_for_id(tree_id)
		assert(tree != null)
		assert(tree.minimum_visual_scale < tree.maximum_visual_scale)
		assert(tree.material_variants.size() >= 3)
		assert(not tree.variant_material_slot_names.is_empty())
	var pine := catalog.definition_for_id(&"prop_pine")
	assert(pine != null)
	assert(pine.minimum_visual_scale < pine.maximum_visual_scale)
	assert(pine.material_variants.is_empty())


func _validate_biome_catalog(
	region: GeneratedWorldRegion,
	generator: TerrainChunkGenerator,
) -> void:
	var catalog := region.get_biome_catalog()
	assert(catalog != null)
	assert(catalog.validation_errors().is_empty())
	assert(catalog.definitions.size() == EXPECTED_BIOME_IDS.size())
	var counts: Dictionary[StringName, int] = {}
	for record: Dictionary in generator.placement_records():
		var coordinate: Vector2i = record.get("coordinate", Vector2i.ZERO)
		var biome_id := region.get_biome_at(coordinate)
		var tags: PackedStringArray = record.get("tags", PackedStringArray())
		if "grass" in tags or "sand" in tags:
			assert(biome_id != &"")
			var biome := catalog.definition_for_id(biome_id)
			assert(biome != null and biome.supports_chunk_tags(tags))
			counts[biome_id] = counts.get(biome_id, 0) + 1
		else:
			assert(biome_id == &"")
	for biome_id: StringName in EXPECTED_BIOME_IDS:
		assert(counts.get(biome_id, 0) > 0)
	var center := Vector2i(
		generator.grid_size.x / 2,
		generator.grid_size.y / 2,
	)
	assert(region.get_biome_at(center) == &"biome_plains")
	for child: Node in generator.get_generated_chunks_root().get_children():
		var coordinate: Vector2i = child.get_meta(
			&"terrain_chunk_coordinate",
			Vector2i.ZERO,
		)
		assert(
			StringName(child.get_meta(&"terrain_biome_id", &""))
			== region.get_biome_at(coordinate)
		)


func _validate_decoration_transform(
	region: GeneratedWorldRegion,
	prop: Node3D,
	definition: TerrainPropDefinition,
) -> void:
	assert(prop != null)
	assert(prop.scale.is_equal_approx(Vector3.ONE))
	var visual_root := prop.get_node_or_null("Visual") as Node3D
	var visual := _find_mesh_instance(visual_root)
	var collision := prop.get_node_or_null(
		"TrunkCollision/CollisionShape"
	) as CollisionShape3D
	assert(visual_root != null)
	assert(visual_root.position.is_equal_approx(definition.visual_offset))
	var visual_scale := float(
		prop.get_meta(&"terrain_prop_visual_scale", 1.0)
	)
	assert(visual_scale >= definition.minimum_visual_scale - 0.001)
	assert(visual_scale <= definition.maximum_visual_scale + 0.001)
	assert(
		visual_root.scale.is_equal_approx(Vector3.ONE * visual_scale)
	)
	assert(visual != null and visual.mesh != null)
	if definition.has_collision():
		assert(collision != null)
		assert(
			collision.shape is CylinderShape3D
			or collision.shape is BoxShape3D
		)
		assert(collision.global_basis.get_scale().is_equal_approx(Vector3.ONE))
	else:
		assert(collision == null)
	var query := PhysicsRayQueryParameters3D.create(
		prop.global_position + Vector3.UP * 8.0,
		prop.global_position + Vector3.DOWN * 8.0,
		1,
	)
	var prop_body := prop.get_node_or_null(
		"TrunkCollision",
	) as CollisionObject3D
	if prop_body != null:
		query.exclude = [prop_body.get_rid()]
	var hit := region.get_world_3d().direct_space_state.intersect_ray(query)
	assert(
		not hit.is_empty(),
		"No terrain collision below %s (%s) at %s."
		% [prop.name, definition.stable_id, prop.global_position],
	)
	var ground_position: Vector3 = hit["position"]
	assert(absf(ground_position.y - prop.global_position.y) <= 0.01)


func _find_mesh_instance(root_node: Node) -> MeshInstance3D:
	if root_node is MeshInstance3D:
		return root_node as MeshInstance3D
	if root_node == null:
		return null
	for child: Node in root_node.get_children():
		var mesh_instance := _find_mesh_instance(child)
		if mesh_instance != null:
			return mesh_instance
	return null


func _has_material_variant_override(
	root_node: Node,
	variants: Array[Material],
) -> bool:
	if root_node == null:
		return false
	var mesh_instance := root_node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var override := mesh_instance.get_surface_override_material(
				surface_index
			)
			if override != null and override in variants:
				return true
	for child: Node in root_node.get_children():
		if _has_material_variant_override(child, variants):
			return true
	return false


func _validate_authored_chunk_surfaces(
	region: GeneratedWorldRegion,
	generator: TerrainChunkGenerator,
) -> void:
	var generated := generator.get_generated_chunks_root()
	var found_beach := false
	var found_pond := false
	var found_grass_ocean_edge := false
	var found_grass_beach_transition := false
	var found_grass_ocean_corner := false
	var found_beach_ocean_corner := false
	for chunk_root: Node in generated.get_children():
		if chunk_root.name.begins_with("chunk_0002r"):
			var beach := chunk_root.find_child(
				"chunk_0002", true, false
			) as MeshInstance3D
			assert(beach != null and beach.mesh != null)
			var material := beach.get_active_material(0)
			assert(material != null and material.resource_name == "sand")
			found_beach = true
		elif chunk_root.name.begins_with("chunk_0004r"):
			var pond := chunk_root.find_child(
				"chunk_0004", true, false
			) as MeshInstance3D
			assert(pond != null and pond.mesh != null)
			for surface_index: int in pond.mesh.get_surface_count():
				var arrays := pond.mesh.surface_get_arrays(surface_index)
				var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
				for normal: Vector3 in normals:
					assert(normal.y >= -0.001)
			_validate_pond_collision(region, pond)
			found_pond = true
		elif chunk_root.name.begins_with("chunk_0005r"):
			var grass_ocean_edge := chunk_root.find_child(
				"chunk_0005", true, false
			) as MeshInstance3D
			assert(grass_ocean_edge != null and grass_ocean_edge.mesh != null)
			var edge_materials := _material_names(grass_ocean_edge)
			assert("grass_lite" in edge_materials)
			assert("cliff_wall" in edge_materials)
			found_grass_ocean_edge = true
		elif chunk_root.name.begins_with("chunk_0006r"):
			var grass_beach_transition := chunk_root.find_child(
				"chunk_0006", true, false
			) as MeshInstance3D
			assert(
				grass_beach_transition != null
				and grass_beach_transition.mesh != null
			)
			var transition_materials := _material_names(
				grass_beach_transition
			)
			assert("sand" in transition_materials)
			assert("grass_lite" in transition_materials)
			assert("cliff_wall" in transition_materials)
			found_grass_beach_transition = true
		elif chunk_root.name.begins_with("chunk_0007r"):
			var grass_ocean_corner := chunk_root.find_child(
				"chunk_0007", true, false
			) as MeshInstance3D
			assert(grass_ocean_corner != null and grass_ocean_corner.mesh != null)
			var corner_materials := _material_names(grass_ocean_corner)
			assert("grass_lite" in corner_materials)
			assert("cliff_wall" in corner_materials)
			found_grass_ocean_corner = true
		elif chunk_root.name.begins_with("chunk_0008r"):
			var beach_ocean_corner := chunk_root.find_child(
				"chunk_0008", true, false
			) as MeshInstance3D
			assert(beach_ocean_corner != null and beach_ocean_corner.mesh != null)
			var beach_corner_materials := _material_names(beach_ocean_corner)
			assert("sand" in beach_corner_materials)
			found_beach_ocean_corner = true
	assert(found_beach)
	assert(found_pond)
	assert(found_grass_ocean_edge)
	assert(found_grass_beach_transition)
	assert(found_grass_ocean_corner)
	assert(found_beach_ocean_corner)


func _material_names(mesh_instance: MeshInstance3D) -> PackedStringArray:
	var result := PackedStringArray()
	for surface_index: int in mesh_instance.mesh.get_surface_count():
		var material := mesh_instance.get_active_material(surface_index)
		if material != null:
			result.append(material.resource_name)
	return result


func _validate_pond_collision(
	region: GeneratedWorldRegion,
	pond: MeshInstance3D,
) -> void:
	var best_centroid := Vector3.ZERO
	var best_height := -INF
	for surface_index: int in pond.mesh.get_surface_count():
		var arrays := pond.mesh.surface_get_arrays(surface_index)
		var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var normals := arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
		var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
		var triangle_count := (
			indices.size() / 3 if not indices.is_empty() else vertices.size() / 3
		)
		for triangle_index: int in triangle_count:
			var offset := triangle_index * 3
			var index_a: int = indices[offset] if not indices.is_empty() else offset
			var index_b: int = (
				indices[offset + 1] if not indices.is_empty() else offset + 1
			)
			var index_c: int = (
				indices[offset + 2] if not indices.is_empty() else offset + 2
			)
			var a: Vector3 = vertices[index_a]
			var b: Vector3 = vertices[index_b]
			var c: Vector3 = vertices[index_c]
			var normal := (
				(normals[index_a] + normals[index_b] + normals[index_c]) / 3.0
			).normalized()
			var centroid := (a + b + c) / 3.0
			if normal.y > 0.5 and centroid.y > best_height:
				best_height = centroid.y
				best_centroid = centroid
	assert(best_height > -INF)
	var target := pond.global_transform * best_centroid
	var query := PhysicsRayQueryParameters3D.create(
		target + Vector3.UP * 2.0,
		target + Vector3.DOWN * 2.0,
		1,
	)
	var hit := region.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty())
	var collider := hit.get("collider") as Node
	assert(collider != null and collider.get_parent() == pond)


func _decoration_group_count(
	region: GeneratedWorldRegion,
	group: StringName,
) -> int:
	var count := 0
	var decorations := region.get_node("Decorations") as Node3D
	for child: Node in decorations.get_children():
		var stable_id := StringName(child.get_meta(&"terrain_prop_id", &""))
		var definition := region.get_prop_catalog().definition_for_id(stable_id)
		if definition != null and definition.procedural_group == group:
			count += 1
	return count


func _decoration_biome_group_count(
	region: GeneratedWorldRegion,
	biome_id: StringName,
	group: StringName,
) -> int:
	var count := 0
	var decorations := region.get_node("Decorations") as Node3D
	for child: Node in decorations.get_children():
		if StringName(child.get_meta(&"terrain_biome_id", &"")) != biome_id:
			continue
		var prop_id := StringName(child.get_meta(&"terrain_prop_id", &""))
		var definition := region.get_prop_catalog().definition_for_id(prop_id)
		if definition != null and definition.procedural_group == group:
			count += 1
	return count


func _biome_signature(
	region: GeneratedWorldRegion,
	generator: TerrainChunkGenerator,
) -> PackedStringArray:
	var result := PackedStringArray()
	for row: int in generator.grid_size.y:
		for column: int in generator.grid_size.x:
			result.append(
				String(region.get_biome_at(Vector2i(column, row)))
			)
	return result


func _placement_count(keys: PackedStringArray, stable_id: String) -> int:
	var count := 0
	for key: String in keys:
		if key.begins_with(stable_id + "@"):
			count += 1
	return count


func _decoration_signature(region: GeneratedWorldRegion) -> PackedStringArray:
	var result := PackedStringArray()
	var decorations := region.get_node("Decorations") as Node3D
	for child: Node in decorations.get_children():
		var prop := child as Node3D
		result.append("%s:%s:%s" % [
			prop.name,
			prop.position,
			prop.rotation,
		])
	return result
