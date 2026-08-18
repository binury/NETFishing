extends SceneTree

const StarterIslandScene = preload(
	"res://world/regions/starter_island_region.tscn"
)
const ShovelAttachmentScene = preload("res://player/shovel_attachment.tscn")
const ItemCatalogResource: ItemCatalog = preload(
	"res://items/catalog/item_catalog.tres"
)
const Gatherables: GatherableCatalog = preload(
	"res://gathering/catalog/gatherable_catalog.tres"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_catalog_content()
	_validate_flat_shovel()
	await _validate_beach_authoring()
	print("Digging prototype validation: PASS")
	quit()


func _validate_catalog_content() -> void:
	var shovel: ItemData = ItemCatalogResource.get_available_item_by_id(
		&"standard_shovel"
	)
	assert(shovel != null)
	assert(shovel.category == ItemData.Category.TOOL)
	assert(shovel.equippable and shovel.hotbar_allowed)
	var clam: GatherableData = Gatherables.get_entry(&"clam_manila")
	assert(clam != null and clam.is_available())
	assert(clam.required_tool_id == shovel.item_id)
	assert(clam.diggable_area_id == &"starter_beach")
	assert(clam.presentation_mode == GatherableData.PresentationMode.WATER_SPURT)
	assert(not clam.requires_sneaking)
	assert(is_equal_approx(clam.active_lifetime_seconds, 10.0))


func _validate_flat_shovel() -> void:
	var attachment := ShovelAttachmentScene.instantiate() as BoneAttachment3D
	assert(attachment != null)
	var shovel := attachment.get_node("Shovel") as Node3D
	assert(shovel != null)
	var meshes: Array[MeshInstance3D] = []
	_collect_meshes(shovel, meshes)
	assert(meshes.size() == 5)
	for mesh_instance: MeshInstance3D in meshes:
		assert(
			mesh_instance.cast_shadow
			== GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		var material := mesh_instance.mesh.surface_get_material(0) as StandardMaterial3D
		assert(material != null)
		assert(material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED)
		assert(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
		assert(material.albedo_texture == null)
		assert(is_equal_approx(material.albedo_color.a, 1.0))
	attachment.free()


func _validate_beach_authoring() -> void:
	var region := StarterIslandScene.instantiate() as WorldRegion
	root.add_child(region)
	await process_frame
	var area: DiggableArea3D = region.get_diggable_area(&"starter_beach")
	assert(area != null)
	assert(area.terrain_source == NodePath("../../Terrain/Visual"))
	assert(area.surface_materials.size() == 1)
	assert(area.surface_materials[0] == &"sand")
	var triangles: Array[PackedVector3Array] = area.get_surface_triangles()
	assert(not triangles.is_empty())
	for triangle: PackedVector3Array in triangles:
		assert(triangle.size() == 3)
		var center := (triangle[0] + triangle[1] + triangle[2]) / 3.0
		assert(area.generation_bounds.has_point(Vector2(center.x, center.z)))
		assert(center.y <= area.maximum_global_y + 0.001)
	region.queue_free()


func _collect_meshes(
	root_node: Node,
	result: Array[MeshInstance3D],
) -> void:
	for child: Node in root_node.get_children():
		if child is MeshInstance3D:
			result.append(child as MeshInstance3D)
		_collect_meshes(child, result)
