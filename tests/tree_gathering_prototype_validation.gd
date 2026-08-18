extends SceneTree

const StarterIslandScene = preload(
	"res://world/regions/starter_island_region.tscn"
)
const Gatherables: GatherableCatalog = preload(
	"res://gathering/catalog/gatherable_catalog.tres"
)
const FishCatalog: FishPool = preload("res://fish/pools/fish_catalog.tres")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_beetle_data()
	await _validate_tree_anchors()
	_validate_anchored_presentation()
	_validate_three_dimensional_targeting()
	print("Tree gathering prototype validation: PASS")
	quit()


func _validate_beetle_data() -> void:
	var beetle: GatherableData = Gatherables.get_entry(&"beetle_stag_common")
	assert(beetle != null and beetle.is_available())
	assert(beetle.catch_data == FishCatalog.get_fish_by_id(&"beetle_stag_common"))
	assert(beetle.catch_data.display_texture != null)
	assert(beetle.catch_data.collection_method == FishData.CollectionMethod.NET)
	assert(beetle.catch_data.collection_group == &"Beetles")
	assert(beetle.required_tool_id == &"crab_net")
	assert(beetle.spawn_anchor_set_id == &"starter_reachable_tree_trunks")
	assert(beetle.population == 3)
	assert(is_equal_approx(beetle.sprite_pixel_size, 0.005))
	assert(beetle.is_stationary_spawn())
	assert(not beetle.can_be_scared())


func _validate_tree_anchors() -> void:
	var region := StarterIslandScene.instantiate() as WorldRegion
	root.add_child(region)
	await process_frame
	var anchor_set: GatherableAnchorSet3D = region.get_gatherable_anchor_set(
		&"starter_reachable_tree_trunks"
	)
	assert(anchor_set != null)
	var positions: PackedVector3Array = anchor_set.get_spawn_positions()
	assert(positions.size() == 8)
	for position: Vector3 in positions:
		assert(position.is_finite())
		assert(position.y >= 4.3 and position.y <= 4.5)
	region.queue_free()


func _validate_anchored_presentation() -> void:
	var beetle: GatherableData = Gatherables.get_entry(&"beetle_stag_common")
	var presentation := WorldGatherable.new()
	root.add_child(presentation)
	presentation.configure("beetle-visual", beetle, Vector3.ZERO, 0.0)
	var sprite := presentation.get_node("GatherableSprite") as Sprite3D
	assert(sprite != null)
	assert(is_zero_approx(sprite.position.y))
	assert(is_equal_approx(sprite.pixel_size, 0.005))
	assert(not sprite.shaded)
	assert(sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	assert(sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	presentation.queue_free()


func _validate_three_dimensional_targeting() -> void:
	var service := NetworkWorldSpawnService.new()
	var beetle: GatherableData = Gatherables.get_entry(&"beetle_stag_common")
	service.set(
		"_entities",
		{
			"beetle-test": {
				"entity_id": "beetle-test",
				"type_id": &"beetle_stag_common",
				"data": beetle,
				"position": Vector3(2.0, 4.4, 3.0),
				"locked": false,
			},
		},
	)
	assert(
		service.find_capture_target(
			Vector3(2.0, 4.4, 3.0),
			&"crab_net",
		)
		== "beetle-test"
	)
	assert(
		service.find_capture_target(
			Vector3(2.0, 3.0, 3.0),
			&"crab_net",
		).is_empty()
	)
	service.free()
