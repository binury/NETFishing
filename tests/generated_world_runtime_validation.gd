extends SceneTree

const RegionScene: PackedScene = preload(
	"res://world/generation/generated_world_region.tscn"
)
const FIRST_SEED := 13001
const SECOND_SEED := 13002


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
	var first_decorations := _decoration_signature(region)
	assert(region.generate_world(FIRST_SEED))
	assert(generator.placement_keys() == first_layout)
	assert(_decoration_signature(region) == first_decorations)

	assert(region.generate_world(SECOND_SEED))
	await physics_frame
	_validate_generated_region(region, generator)
	assert(generator.placement_keys() != first_layout)

	region.queue_free()
	await process_frame
	print("Generated world runtime validation: PASS")
	quit()


func _validate_generated_region(
	region: GeneratedWorldRegion,
	generator: TerrainChunkGenerator,
) -> void:
	var placements := generator.placement_keys()
	assert(placements.size() == 25)
	assert(placements[12].begins_with("chunk_spawn@"))
	assert(_placement_count(placements, "chunk_spawn") == 1)
	assert(_placement_count(placements, "chunk_0001") >= 1)
	assert(_placement_count(placements, "chunk_0002") >= 1)
	assert(_placement_count(placements, "chunk_0003") >= 1)
	assert(_placement_count(placements, "chunk_0004") >= 1)
	assert(generator.get_generated_chunks_root().get_child_count() == 25)

	var shop := region.get_node("Interactables/FishingShopWorld") as Node3D
	var storage := region.get_node("Interactables/PlayerStorageBox") as Node3D
	assert(shop != null and shop.has_node("Shopkeeper"))
	assert(storage != null and storage.has_node("InteractionArea"))
	assert(absf(shop.position.x) < 5.0 and absf(shop.position.z) < 5.0)
	assert(absf(storage.position.x) < 5.0 and absf(storage.position.z) < 5.0)
	assert(region.get_fishing_shop() != null)
	assert(region.get_player_storage() != null)
	assert(region.get_player_spawn_transform().origin.y > 0.0)

	var ocean := region.get_node("WaterBodies/OceanWater") as WaterBodyAuthoring
	var fresh_root := region.get_node("WaterBodies/FreshWaterBodies") as Node3D
	assert(ocean != null and fresh_root != null)
	assert(ocean.water_type == WaterType.Type.SALT_WATER)
	var fresh_placement_count := 0
	for record: Dictionary in generator.placement_records():
		var tags: PackedStringArray = record.get("tags", PackedStringArray())
		if "fresh_water" in tags:
			fresh_placement_count += 1
	assert(fresh_root.get_child_count() == fresh_placement_count)
	for child: Node in fresh_root.get_children():
		var fresh := child as WaterBodyAuthoring
		assert(fresh != null)
		assert(fresh.water_type == WaterType.Type.FRESH_WATER)
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
		assert(
			child.name.begins_with("regular_tree_")
			or child.name.begins_with("palm_tree_")
		)
		_validate_decoration_transform(child as Node3D)
	assert(_decoration_count(decorations, "regular_tree_") > 0)
	assert(_decoration_count(decorations, "palm_tree_") > 0)


func _validate_decoration_transform(prop: Node3D) -> void:
	assert(prop != null)
	assert(prop.scale.is_equal_approx(Vector3.ONE))
	var visual := prop.get_node_or_null("Visual") as MeshInstance3D
	var collision := prop.get_node_or_null(
		"TrunkCollision/CollisionShape"
	) as CollisionShape3D
	assert(visual != null and visual.mesh != null)
	assert(collision != null and collision.shape is CylinderShape3D)
	assert(collision.global_basis.get_scale().is_equal_approx(Vector3.ONE))
	var bounds := visual.mesh.get_aabb()
	var minimum_y := INF
	for corner_index: int in 8:
		var corner := bounds.position + Vector3(
			bounds.size.x if (corner_index & 1) != 0 else 0.0,
			bounds.size.y if (corner_index & 2) != 0 else 0.0,
			bounds.size.z if (corner_index & 4) != 0 else 0.0,
		)
		minimum_y = minf(
			minimum_y,
			(visual.global_transform * corner).y,
		)
	assert(absf(minimum_y - prop.global_position.y) <= 0.01)


func _validate_authored_chunk_surfaces(
	region: GeneratedWorldRegion,
	generator: TerrainChunkGenerator,
) -> void:
	var generated := generator.get_generated_chunks_root()
	var found_beach := false
	var found_pond := false
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
	assert(found_beach)
	assert(found_pond)


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


func _decoration_count(decorations: Node3D, prefix: String) -> int:
	var count := 0
	for child: Node in decorations.get_children():
		if child.name.begins_with(prefix):
			count += 1
	return count


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
