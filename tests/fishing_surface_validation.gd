extends SceneTree

const FishingSpotScene = preload("res://fishing/fishing_spot.tscn")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const FishingPresentationType = preload(
	"res://fishing/fishing_presentation.gd"
)
const RemoteFishingPresentationType = preload(
	"res://fishing/remote_fishing_presentation.gd"
)
const PlayerScene = preload("res://player/player.tscn")
const FishCatchType = preload("res://fish/fish_catch.gd")
const FishingSurfaceResolverType = preload(
	"res://fishing/fishing_surface_resolver.gd"
)
const FishingSurfaceSampleType = preload(
	"res://fishing/fishing_surface_sample.gd"
)
const FishableWaterRegionType = preload(
	"res://world/fishable_water_region.gd"
)
const FishPoolType = preload("res://fish/fish_pool.gd")
const WaterBodyScene = preload("res://world/water_body.tscn")
const StarterRegionScene = preload(
	"res://world/regions/starter_island_region.tscn"
)
const PondPool: FishPoolType = preload(
	"res://fish/pools/starter_pond_pool.tres"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _validate_resolver_layers()
	await _validate_portable_water_body()
	await _validate_starter_region_surfaces()
	await _validate_presentation()
	await _validate_remote_presentation()
	await _validate_bite_wait_distribution()
	print("Fishing surface validation: PASS")
	quit()


func _validate_resolver_layers() -> void:
	var world := Node3D.new()
	root.add_child(world)
	_add_solid_box(world, Vector3(40.0, 2.0, 12.0), Vector3(10.0, -1.0, 0.0))
	_add_water_region(world, Vector3(0.0, 2.0, 0.0), Vector2(8.0, 8.0), PondPool)
	_add_solid_box(world, Vector3(1.0, 1.0, 1.0), Vector3(2.0, 2.25, 0.0))
	_add_solid_box(world, Vector3(1.0, 1.0, 1.0), Vector3(-2.0, 6.0, 0.0))
	_add_solid_box(world, Vector3(1.0, 1.0, 1.0), Vector3(0.0, 1.49, 2.0))
	_add_solid_box(world, Vector3(1.0, 1.0, 1.0), Vector3(0.0, 1.5, -2.0))
	_add_water_region(world, Vector3(10.0, 5.0, 0.0), Vector2(6.0, 6.0), PondPool)
	_add_water_region(world, Vector3(20.0, 3.0, 0.0), Vector2(6.0, 6.0), null)
	await physics_frame
	await physics_frame

	var resolver := FishingSurfaceResolverType.new()
	var space_state: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var water: FishingSurfaceSampleType = resolver.resolve_surface(
		space_state,
		Vector3.ZERO,
		4.0,
	)
	assert(water.is_fishable())
	assert(is_equal_approx(water.position.y, 2.0))
	var water_under_overhang: FishingSurfaceSampleType = resolver.resolve_surface(
		space_state,
		Vector3(-2.0, 4.0, 0.0),
		4.0,
		0.08,
	)
	assert(water_under_overhang.is_fishable())
	assert(is_equal_approx(water_under_overhang.position.y, 2.0))
	var shallow_water: FishingSurfaceSampleType = resolver.resolve_surface(
		space_state,
		Vector3(0.0, 2.0, 2.0),
		4.0,
		0.04,
	)
	assert(shallow_water.is_fishable())
	var exact_shore_contact: FishingSurfaceSampleType = resolver.resolve_surface(
		space_state,
		Vector3(0.0, 2.0, -2.0),
		4.0,
		0.04,
	)
	assert(exact_shore_contact.has_surface)
	assert(not exact_shore_contact.is_fishable())

	var covered_water: FishingSurfaceSampleType = resolver.resolve_surface(
		space_state,
		Vector3(2.0, 2.0, 0.0),
		4.0,
	)
	assert(covered_water.has_surface)
	assert(not covered_water.is_water_surface)
	assert(is_equal_approx(covered_water.position.y, 2.75))

	var elevated_water: FishingSurfaceSampleType = resolver.resolve_surface(
		space_state,
		Vector3(10.0, 0.0, 0.0),
		8.0,
	)
	assert(elevated_water.is_fishable())
	assert(is_equal_approx(elevated_water.position.y, 5.0))

	var unstocked_water: FishingSurfaceSampleType = resolver.resolve_surface(
		space_state,
		Vector3(20.0, 0.0, 0.0),
		6.0,
	)
	assert(unstocked_water.has_surface)
	assert(unstocked_water.is_water_surface)
	assert(not unstocked_water.is_fishable())
	assert(is_equal_approx(unstocked_water.position.y, 3.0))

	var safe_reel: FishingSurfaceSampleType = resolver.resolve_withdrawal_surface(
		space_state,
		Vector3(0.0, 2.0, 0.0),
		Vector3(3.0, 2.0, 0.0),
		Vector3.RIGHT,
		4.0,
		0.4,
	)
	assert(safe_reel.is_fishable())
	assert(is_equal_approx(safe_reel.position.y, 2.0))
	var shoreline_reel: FishingSurfaceSampleType = (
		resolver.resolve_withdrawal_surface(
			space_state,
			Vector3(3.0, 2.0, 0.0),
			Vector3(3.7, 2.0, 0.0),
			Vector3.RIGHT,
			4.0,
			0.4,
		)
	)
	assert(not shoreline_reel.is_fishable())
	assert(shoreline_reel.position.is_equal_approx(Vector3(3.0, 2.0, 0.0)))

	world.queue_free()
	await process_frame


func _validate_portable_water_body() -> void:
	var water_body := WaterBodyScene.instantiate() as Node3D
	water_body.position = Vector3(3.0, 7.0, -2.0)
	water_body.set("surface_size", Vector2(12.0, 8.0))
	water_body.set("fishing_depth", 6.0)
	water_body.set("recovery_depth", 7.0)
	water_body.set("fish_pool", PondPool)
	root.add_child(water_body)
	await process_frame

	var visual := water_body.get_node("VisualWater") as MeshInstance3D
	var visual_mesh := visual.mesh as PlaneMesh
	assert(visual_mesh.size.is_equal_approx(Vector2(12.0, 8.0)))
	var fishing_region := water_body.get_node(
		"FishingRegion"
	) as FishableWaterRegionType
	var fishing_shape_node := water_body.get_node(
		"FishingRegion/Shape"
	) as CollisionShape3D
	var fishing_shape := fishing_shape_node.shape as BoxShape3D
	assert(fishing_region.fish_pool == PondPool)
	assert(is_equal_approx(fishing_region.get_surface_height(), 7.0))
	assert(is_equal_approx(fishing_shape_node.position.y, -3.0))
	assert(fishing_shape.size.is_equal_approx(Vector3(12.0, 6.0, 8.0)))
	var recovery_region := water_body.get_node("RecoveryRegion") as Area3D
	assert(is_equal_approx(recovery_region.position.y, -3.5))

	water_body.queue_free()
	await process_frame

	var mesh_derived_body := WaterBodyScene.instantiate() as WaterBodyAuthoring
	mesh_derived_body.position = Vector3(-4.0, 3.0, 6.0)
	mesh_derived_body.derive_coverage_from_visual_mesh = true
	mesh_derived_body.fishing_depth = 3.0
	mesh_derived_body.fish_pool = PondPool
	var derived_visual := mesh_derived_body.get_node(
		"VisualWater"
	) as MeshInstance3D
	var derived_mesh := derived_visual.mesh as PlaneMesh
	derived_mesh.size = Vector2(18.0, 11.0)
	root.add_child(mesh_derived_body)
	await process_frame

	var derived_shape_node := mesh_derived_body.get_node(
		"FishingRegion/Shape"
	) as CollisionShape3D
	var derived_shape := derived_shape_node.shape as BoxShape3D
	assert(derived_shape.size.is_equal_approx(Vector3(18.0, 3.0, 11.0)))
	assert(derived_shape_node.position.is_equal_approx(Vector3(0.0, -1.5, 0.0)))
	assert(derived_mesh.size.is_equal_approx(Vector2(18.0, 11.0)))

	mesh_derived_body.queue_free()
	await process_frame


func _validate_starter_region_surfaces() -> void:
	var region := StarterRegionScene.instantiate() as Node3D
	root.add_child(region)
	var ocean_body := region.get_node(
		"WaterBodies/Ocean"
	) as WaterBodyAuthoring
	assert(ocean_body != null)
	assert(ocean_body.derive_coverage_from_visual_mesh)
	assert(not ocean_body.manage_recovery_coverage)
	var ocean_region := region.get_node(
		"WaterBodies/Ocean/FishingRegions/OceanFishingRegion"
	) as FishableWaterRegionType
	assert(ocean_region.get_child_count() == 1)
	var fishing_spot := FishingSpotScene.instantiate() as FishingSpotType
	root.add_child(fishing_spot)
	await physics_frame
	await physics_frame

	var pond: FishingSurfaceSampleType = fishing_spot.resolve_fishing_surface(
		Vector3(-9.4, 2.51, 2.1),
		4.0,
	)
	assert(pond.is_fishable())
	assert(is_equal_approx(pond.position.y, 2.51))
	var ocean: FishingSurfaceSampleType = fishing_spot.resolve_fishing_surface(
		Vector3(50.0, -0.45, 0.0),
		4.0,
	)
	assert(ocean.is_fishable())
	assert(is_equal_approx(ocean.position.y, -0.45))
	var ocean_visual := region.get_node(
		"WaterBodies/Ocean/VisualWater"
	) as WaterSurfaceMotion
	assert(ocean_visual != null)
	assert(ocean_visual.is_processing())
	assert(
		absf(ocean_visual.global_position.y - ocean.position.y)
		<= ocean_visual.amplitude + 0.0001
	)
	var ocean_shapes := region.get_node(
		"WaterBodies/Ocean/FishingRegions/OceanFishingRegion"
	).get_children()
	assert(ocean_shapes.size() == 1)
	var ocean_shape := ocean_shapes[0] as CollisionShape3D
	assert(ocean_shape != null)
	var ocean_box := ocean_shape.shape as BoxShape3D
	assert(ocean_box != null)
	var ocean_mesh := ocean_visual.mesh as PlaneMesh
	assert(ocean_mesh != null)
	assert(ocean_box.size.is_equal_approx(Vector3(
		ocean_mesh.size.x,
		2.0,
		ocean_mesh.size.y,
	)))
	var expanded_ocean: FishingSurfaceSampleType = (
		fishing_spot.resolve_fishing_surface(
			Vector3(72.0, -0.45, 0.0),
			4.0,
		)
	)
	assert(expanded_ocean.is_fishable())
	assert(is_equal_approx(expanded_ocean.position.y, -0.45))
	var covered_ocean: FishingSurfaceSampleType = (
		fishing_spot.resolve_fishing_surface(
			Vector3(20.0, -0.45, 0.0),
			4.0,
		)
	)
	assert(covered_ocean.has_surface)
	assert(not covered_ocean.is_fishable())
	assert(covered_ocean.position.y > -0.45)

	# The ocean fishing layer covers the island's complete editable footprint.
	# Terrain at or above the waterline remains authoritative, while shoreline
	# terrain lowered below the surface becomes fishable without reshaping a
	# manually authored exclusion ring.
	var editable_shallows_found := 0
	for x_position: int in range(-24, 24, 2):
		for z_position: int in range(-21, 22, 2):
			var candidate: FishingSurfaceSampleType = (
				fishing_spot.resolve_fishing_surface(
					Vector3(x_position, -0.45, z_position),
					4.0,
				)
			)
			if (
				candidate.is_fishable()
				and candidate.water_region.water_type
				== WaterType.Type.SALT_WATER
			):
				editable_shallows_found += 1
	assert(editable_shallows_found > 0)

	fishing_spot.queue_free()
	region.queue_free()
	await process_frame


func _validate_presentation() -> void:
	var fishing_spot := FishingSpotScene.instantiate() as FishingSpotType
	root.add_child(fishing_spot)
	var presentation := fishing_spot.get_node(
		"FishingPresentation"
	) as FishingPresentationType
	var rod := Node3D.new()
	var rod_tip := Marker3D.new()
	rod.add_child(rod_tip)
	root.add_child(rod)
	rod_tip.position = Vector3(0.0, 1.0, 0.0)
	await process_frame

	var slope_normal := Vector3(0.0, 1.0, 1.0).normalized()
	presentation.begin_aim(
		rod_tip,
		rod,
		Vector3(0.0, 0.1, -1.0),
		slope_normal,
		false,
	)
	var marker := presentation.get_node("CastTargetMarker") as Node3D
	var valid_marker := presentation.get_node(
		"CastTargetMarker/ValidTargetMarker"
	) as MeshInstance3D
	var invalid_marker := presentation.get_node(
		"CastTargetMarker/InvalidTargetMarker"
	) as Node3D
	assert(not valid_marker.visible)
	assert(invalid_marker.visible)
	assert(invalid_marker.get_child_count() == 2)
	assert(marker.global_basis.y.normalized().dot(slope_normal) > 0.999)

	var landing := Vector3(0.0, 0.13, -4.0)
	presentation.begin_cast(landing, landing, true)
	await presentation.cast_completed
	var bobber := presentation.get_node("Bobber") as MeshInstance3D
	assert(bobber.visible)
	assert(bobber.global_position.is_equal_approx(landing))
	presentation.play_outcome(&"invalid")
	await process_frame
	assert(bobber.visible)
	await presentation.outcome_completed
	assert(not bobber.visible)

	rod.queue_free()
	fishing_spot.queue_free()
	await process_frame


func _validate_bite_wait_distribution() -> void:
	var fishing_spot := FishingSpotScene.instantiate() as FishingSpotType
	root.add_child(fishing_spot)
	await process_frame
	var bite_rng := fishing_spot.get("_bite_rng") as RandomNumberGenerator
	bite_rng.seed = 84219
	var quick_count: int = 0
	var typical_or_long_count: int = 0
	var very_long_count: int = 0
	var total_wait_seconds: float = 0.0
	for _sample_index: int in 10000:
		var wait_seconds: float = fishing_spot.roll_bite_wait_time()
		assert(wait_seconds >= FishingSpotType.BITE_QUICK_MIN_SECONDS)
		assert(wait_seconds <= FishingSpotType.BITE_MAX_SECONDS)
		total_wait_seconds += wait_seconds
		if wait_seconds < FishingSpotType.BITE_QUICK_MAX_SECONDS:
			quick_count += 1
		else:
			typical_or_long_count += 1
		if wait_seconds >= FishingSpotType.BITE_LONG_MAX_SECONDS:
			very_long_count += 1
	var average_wait_seconds: float = total_wait_seconds / 10000.0
	var quick_ratio: float = float(quick_count) / 10000.0
	var very_long_ratio: float = float(very_long_count) / 10000.0
	var very_long_probability: float = 1.0 - (
		FishingSpotType.BITE_QUICK_PROBABILITY
		+ FishingSpotType.BITE_TYPICAL_PROBABILITY
		+ FishingSpotType.BITE_LONG_PROBABILITY
	)
	var expected_average_wait_seconds: float = (
		FishingSpotType.BITE_QUICK_PROBABILITY
		* (
			FishingSpotType.BITE_QUICK_MIN_SECONDS
			+ FishingSpotType.BITE_QUICK_MAX_SECONDS
		)
		* 0.5
		+ FishingSpotType.BITE_TYPICAL_PROBABILITY
		* (
			FishingSpotType.BITE_QUICK_MAX_SECONDS
			+ FishingSpotType.BITE_TYPICAL_MAX_SECONDS
		)
		* 0.5
		+ FishingSpotType.BITE_LONG_PROBABILITY
		* (
			FishingSpotType.BITE_TYPICAL_MAX_SECONDS
			+ FishingSpotType.BITE_LONG_MAX_SECONDS
		)
		* 0.5
		+ very_long_probability
		* (
			FishingSpotType.BITE_LONG_MAX_SECONDS
			+ FishingSpotType.BITE_MAX_SECONDS
		)
		* 0.5
	)
	assert(absf(
		quick_ratio - FishingSpotType.BITE_QUICK_PROBABILITY
	) <= 0.02)
	assert(typical_or_long_count > quick_count)
	assert(absf(very_long_ratio - very_long_probability) <= 0.005)
	assert(absf(
		average_wait_seconds - expected_average_wait_seconds
	) <= 1.0)
	fishing_spot.queue_free()
	await process_frame


func _validate_remote_presentation() -> void:
	var player := PlayerScene.instantiate() as Player
	root.add_child(player)
	player.set_local_control(false)
	var presentation := RemoteFishingPresentationType.new()
	root.add_child(presentation)
	presentation.setup(player)
	await process_frame
	var origin: Vector3 = player.get_fishing_rod_tip().global_position
	var target: Vector3 = origin + Vector3(-4.0, -0.5, 0.0)
	presentation.show_cast(origin, target)
	var bobber := presentation.get("_bobber") as MeshInstance3D
	assert(bobber.visible)
	assert(presentation.get("_cast_tween") != null)
	await create_timer(0.7).timeout
	assert(bobber.global_position.distance_to(target) < 0.1)
	var first_bob_y: float = bobber.global_position.y
	await create_timer(0.2).timeout
	assert(not is_equal_approx(bobber.global_position.y, first_bob_y))

	var fish_catch := FishCatchType.new()
	var fish: FishData = PondPool.candidates.front()
	fish_catch.fish = fish
	fish_catch.fish_id = fish.id
	fish_catch.catch_id = &"remote-presentation-test"
	fish_catch.weight_lb = 1.0
	fish_catch.display_scale = 1.0
	fish_catch.sale_value = 1
	assert(fish_catch.is_valid())
	presentation.play_return(fish_catch)
	var catch_display := player.find_child(
		"CatchDisplay", true, false
	) as Node3D
	assert(catch_display != null)
	var showcase_deadline_msec: int = Time.get_ticks_msec() + 2000
	while (
		not catch_display.visible
		and Time.get_ticks_msec() < showcase_deadline_msec
	):
		await process_frame
	assert(catch_display.visible)
	await presentation.return_completed
	assert(not catch_display.visible)

	presentation.queue_free()
	player.queue_free()
	await process_frame


func _add_water_region(
	parent: Node3D,
	position: Vector3,
	surface_size: Vector2,
	fish_pool: FishPoolType,
) -> void:
	var water_root := Node3D.new()
	water_root.position = position
	parent.add_child(water_root)
	var region := FishableWaterRegionType.new()
	region.collision_layer = 4
	region.collision_mask = 0
	region.monitoring = false
	region.surface_height_mode = FishableWaterRegionType.SurfaceHeightMode.PARENT_GLOBAL_Y
	region.fish_pool = fish_pool
	water_root.add_child(region)
	var shape_node := CollisionShape3D.new()
	shape_node.position.y = -2.0
	var shape := BoxShape3D.new()
	shape.size = Vector3(surface_size.x, 4.0, surface_size.y)
	shape_node.shape = shape
	region.add_child(shape_node)


func _add_solid_box(
	parent: Node3D,
	size: Vector3,
	position: Vector3,
) -> void:
	var body := StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
