extends SceneTree

const Gatherables: GatherableCatalog = preload(
	"res://gathering/catalog/gatherable_catalog.tres"
)
const FishCatalog: FishPool = preload("res://fish/pools/fish_catalog.tres")
const GatheringControllerType = preload(
	"res://gathering/gathering_controller.gd"
)
const WorldGatherableType = preload("res://gathering/world_gatherable.gd")

const CRAB_PIXEL_SIZE: float = 0.0005
const REDUCED_CATCH_RING_RADIUS: float = 0.175
const NET_STRIKE_MARKER_DISTANCE: float = 0.85
const CalendarSeasonType = preload("res://world/calendar_season.gd")


func _initialize() -> void:
	assert(NetworkProtocol.PROTOCOL_VERSION == 8)
	assert(
		NetworkWorldSpawnProtocol.CAPABILITY
		== NetworkProtocol.WORLD_SPAWN_CAPABILITY
	)
	assert(NetworkWorldSpawnProtocol.SNAPSHOT_ENTITIES_PER_ENVELOPE <= 4)
	_validate_catalog_statuses()
	_validate_billboard_presentation()
	_validate_envelopes()
	print("World spawn protocol validation: PASS")
	quit()


func _validate_catalog_statuses() -> void:
	var brown: GatherableData = Gatherables.get_entry(&"crab_brown")
	assert(brown != null and brown.is_available())
	assert(brown.catch_data.active)
	assert(brown.catch_data.collection_method == FishData.CollectionMethod.NET)
	assert(brown.catch_data.logbook_section == FishData.LogbookSection.SHELLFISH)
	assert(brown.population == 2)
	assert(is_equal_approx(brown.charge_duration, 2.0))
	assert(
		is_equal_approx(
			brown.sprite_pixel_size,
			CRAB_PIXEL_SIZE,
		)
	)
	_validate_quality_behavior(brown)
	assert(is_equal_approx(brown.capture_respawn_min_seconds, 480.0))
	assert(is_equal_approx(brown.capture_respawn_max_seconds, 720.0))
	assert(is_equal_approx(brown.scare_respawn_min_seconds, 45.0))
	assert(is_equal_approx(brown.scare_respawn_max_seconds, 90.0))
	assert(is_equal_approx(brown.minimum_respawn_spacing_seconds, 180.0))
	assert(brown.required_tool_id == &"crab_net")
	assert(is_equal_approx(brown.minimum_surface_y, -0.44))
	assert(FishCatalog.get_fish_by_id(&"crab_brown") == brown.catch_data)
	assert(not brown.catch_data.is_fishable())
	var clam: GatherableData = Gatherables.get_entry(&"clam_manila")
	assert(clam != null and clam.is_available())
	assert(clam.catch_data.collection_method == FishData.CollectionMethod.DIGGING)
	assert(clam.catch_data.logbook_section == FishData.LogbookSection.SHELLFISH)
	assert(clam.required_tool_id == &"standard_shovel")
	assert(clam.diggable_area_id == &"starter_beach")
	assert(clam.presentation_mode == GatherableData.PresentationMode.WATER_SPURT)
	assert(clam.is_stationary_hotspot())
	assert(not clam.requires_sneaking)
	assert(not clam.can_be_scared())
	assert(is_equal_approx(clam.active_lifetime_seconds, 10.0))
	assert(FishCatalog.get_fish_by_id(&"clam_manila") == clam.catch_data)
	assert(not clam.catch_data.is_fishable())
	var beetle: GatherableData = Gatherables.get_entry(&"beetle_stag_common")
	assert(beetle != null and beetle.is_available())
	assert(beetle.is_available(CalendarSeasonType.Season.SUMMER))
	assert(not beetle.is_available(CalendarSeasonType.Season.WINTER))
	assert(beetle.catch_data.collection_method == FishData.CollectionMethod.NET)
	assert(beetle.required_tool_id == &"crab_net")
	assert(beetle.spawn_anchor_set_id == &"starter_reachable_tree_trunks")
	assert(beetle.is_stationary_spawn())
	assert(not beetle.is_stationary_hotspot())
	assert(not beetle.requires_sneaking)
	assert(not beetle.can_be_scared())
	assert(FishCatalog.get_fish_by_id(&"beetle_stag_common") == beetle.catch_data)
	assert(not beetle.catch_data.is_fishable())

	for type_id: StringName in [
		&"crab_ghost",
		&"crab_blue",
		&"crab_dungeness",
	]:
		var entry: GatherableData = Gatherables.get_entry(type_id)
		assert(entry != null)
		assert(entry.is_valid())
		assert(not entry.catch_data.active)
		assert(not entry.is_available())
		assert(
			is_equal_approx(
				entry.sprite_pixel_size,
				CRAB_PIXEL_SIZE,
			)
		)
		assert(entry.catch_data.collection_method == FishData.CollectionMethod.NET)
		assert(
			entry.catch_data.logbook_section
			== FishData.LogbookSection.SHELLFISH
		)

	var available: Array[GatherableData] = Gatherables.get_available_entries()
	assert(available.size() == 3)
	assert(available.has(brown))
	assert(available.has(clam))
	assert(available.has(beetle))
	var winter_available: Array[GatherableData] = (
		Gatherables.get_available_entries(CalendarSeasonType.Season.WINTER)
	)
	assert(winter_available.has(brown))
	assert(winter_available.has(clam))
	assert(not winter_available.has(beetle))
	var rng := RandomNumberGenerator.new()
	rng.seed = 24680
	var captured_delay: float = brown.get_respawn_delay(&"captured", rng)
	var scared_delay: float = brown.get_respawn_delay(&"scared", rng)
	assert(captured_delay >= 480.0 and captured_delay <= 720.0)
	assert(scared_delay >= 45.0 and scared_delay <= 90.0)

	var gathering_controller := GatheringControllerType.new()
	assert(
		is_equal_approx(
			gathering_controller.marker_radius,
			REDUCED_CATCH_RING_RADIUS,
		)
	)
	assert(
		is_equal_approx(
			gathering_controller.marker_distance,
			NET_STRIKE_MARKER_DISTANCE,
		)
	)
	gathering_controller.free()


func _validate_billboard_presentation() -> void:
	var gatherable := WorldGatherableType.new()
	gatherable.call("_ensure_visual")
	var sprite := gatherable.get_node("GatherableSprite") as Sprite3D
	assert(sprite != null)
	assert(sprite.billboard == BaseMaterial3D.BILLBOARD_ENABLED)
	assert(sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	assert(not sprite.shaded)
	gatherable.free()

	var hotspot := WorldGatherableType.new()
	hotspot.call("_ensure_water_spurt_visual")
	var hole := hotspot.get_node("WaterSpurt/BurrowMark") as MeshInstance3D
	assert(hole != null)
	assert(hole.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var hole_material := hole.mesh.surface_get_material(0) as StandardMaterial3D
	assert(hole_material != null)
	assert(hole_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert(hole_material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
	assert(is_equal_approx(hole_material.albedo_color.a, 1.0))
	hotspot.queue_free()


func _validate_quality_behavior(entry: GatherableData) -> void:
	var prior_speed: float = -1.0
	var prior_scare_radius: float = -1.0
	for quality: int in FishQuality.TIER_COUNT:
		var movement_speed: float = entry.get_movement_speed_for_quality(
			quality
		)
		var scare_radius: float = entry.get_scare_radius_for_quality(quality)
		assert(movement_speed > prior_speed)
		assert(scare_radius > prior_scare_radius)
		prior_speed = movement_speed
		prior_scare_radius = scare_radius
	assert(
		is_equal_approx(
			entry.get_movement_speed_for_quality(FishQuality.Tier.BORING),
			entry.movement_speed,
		)
	)
	assert(
		is_equal_approx(
			entry.get_movement_speed_for_quality(FishQuality.Tier.SHINY),
			entry.movement_speed * 2.0,
		)
	)
	assert(
		is_equal_approx(
			entry.get_scare_radius_for_quality(FishQuality.Tier.SHINY),
			entry.scare_radius * 1.7,
		)
	)
	var service := NetworkWorldSpawnService.new()
	var spawned_catch := service.call(
		"_create_catch_for_state",
		entry,
		{"quality": FishQuality.Tier.EXCEPTIONAL},
	) as FishCatch
	assert(spawned_catch != null and spawned_catch.is_valid())
	assert(spawned_catch.quality == FishQuality.Tier.EXCEPTIONAL)
	assert(
		spawned_catch.sale_value
		== FishQuality.apply_sale_value(
			entry.catch_data.get_sale_value_for_weight(
				spawned_catch.weight_lb
			),
			FishQuality.Tier.EXCEPTIONAL,
		)
	)
	spawned_catch = null
	service.free()


func _validate_envelopes() -> void:
	var entity: Dictionary = {
		"entity_id": "world:sample",
		"type_id": "future_shellfish",
		"position": [1.0, 2.0, 3.0],
		"yaw": 0.5,
		"revision": 7,
	}
	assert(NetworkWorldSpawnProtocol.validate_entity_state(entity))
	var future_entity: Dictionary = entity.duplicate(true)
	future_entity["future_state"] = {"buried": false}
	assert(NetworkWorldSpawnProtocol.validate_entity_state(future_entity))

	var envelope: Dictionary = NetworkWorldSpawnProtocol.make_envelope(
		"session-test",
		12,
		&"future_spawn_type",
		{"entity": entity, "future_payload": [1, 2, 3]},
	)
	assert(NetworkWorldSpawnProtocol.validate_envelope(envelope))

	var malformed_position: Dictionary = entity.duplicate(true)
	malformed_position["position"] = [1.0, "not-a-number", 3.0]
	assert(
		not NetworkWorldSpawnProtocol.validate_entity_state(
			malformed_position
		)
	)
	assert(
		not NetworkWorldSpawnProtocol.array_to_vector3(
			malformed_position["position"]
		).is_finite()
	)

	var invalid_envelope: Dictionary = envelope.duplicate(true)
	invalid_envelope["envelope_version"] = 0
	assert(not NetworkWorldSpawnProtocol.validate_envelope(invalid_envelope))
