extends SceneTree

const FishCatchType = preload("res://fish/fish_catch.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const FishSelectorType = preload("res://fish/fish_selector.gd")
const FishingContextType = preload("res://fishing/fishing_context.gd")
const NetworkSaleServiceType = preload(
	"res://network/network_sale_service.gd"
)
const NetworkFishingServiceType = preload(
	"res://network/network_fishing_service.gd"
)
const FishingSpotType = preload("res://fishing/fishing_spot.gd")

const Catalog: FishPoolType = preload("res://fish/pools/fish_catalog.tres")
const PondPool: FishPoolType = preload(
	"res://fish/pools/starter_pond_pool.tres"
)
const OceanPool: FishPoolType = preload(
	"res://fish/pools/starter_ocean_pool.tres"
)
const PelicanBuyer = preload("res://economy/buyers/pelicans.tres")
const StarterRegionScene = preload(
	"res://world/regions/starter_island_region.tscn"
)

const ORIGINAL_IDS: Array[StringName] = [
	&"bluegill", &"bass", &"carp", &"sunfish",
]
const CATFISH_IDS: Array[StringName] = [
	&"catfish_blue",
	&"catfish_channel",
	&"catfish_flathead",
	&"catfish_white",
]
const FRESH_WATER_IDS: Array[StringName] = [
	&"bluegill", &"carp", &"catfish_blue", &"catfish_channel",
	&"catfish_flathead", &"catfish_white",
]
const SALT_WATER_IDS: Array[StringName] = [&"bass", &"sunfish"]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_catalog_and_pools()
	_validate_starter_water_bodies()
	_validate_authoritative_water_filter()
	_validate_catches_and_authoritative_sale()
	print("Fish catalog content validation: PASS")
	quit()


func _validate_catalog_and_pools() -> void:
	assert(Catalog.candidates.size() == 8)
	assert(PondPool.candidates.size() == 6)
	assert(OceanPool.candidates.size() == 2)
	for fish_id: StringName in ORIGINAL_IDS:
		var original_fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(original_fish != null)
		assert(original_fish.is_selectable())
	for fish_id: StringName in FRESH_WATER_IDS:
		var fresh_fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(PondPool.get_fish_by_id(fish_id) == fresh_fish)
		assert(OceanPool.get_fish_by_id(fish_id) == null)
		assert(fresh_fish.is_allowed_in_water(WaterType.Type.FRESH_WATER))
		assert(not fresh_fish.is_allowed_in_water(WaterType.Type.SALT_WATER))
		assert(LogbookCatalog.category_for(fresh_fish) == WaterType.Type.FRESH_WATER)
	for fish_id: StringName in SALT_WATER_IDS:
		var salt_fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(OceanPool.get_fish_by_id(fish_id) == salt_fish)
		assert(PondPool.get_fish_by_id(fish_id) == null)
		assert(salt_fish.is_allowed_in_water(WaterType.Type.SALT_WATER))
		assert(not salt_fish.is_allowed_in_water(WaterType.Type.FRESH_WATER))
		assert(LogbookCatalog.category_for(salt_fish) == WaterType.Type.SALT_WATER)
	for fish_id: StringName in CATFISH_IDS:
		var fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(fish != null)
		assert(fish.is_selectable())
		assert(PondPool.get_fish_by_id(fish_id) == fish)
		assert(OceanPool.get_fish_by_id(fish_id) == null)
		assert(fish.availability.allowed_location_tags == [&"starter_pond"])
		assert(LogbookCatalog.category_for(fish) == WaterType.Type.FRESH_WATER)

	var expected_values: Dictionary[StringName, Array] = {
		&"catfish_blue": [1, 1.25, 3.0, 12.0, 6, 9],
		&"catfish_channel": [0, 2.0, 1.5, 7.0, 4, 7],
		&"catfish_flathead": [1, 1.0, 3.0, 14.0, 7, 10],
		&"catfish_white": [0, 2.0, 1.0, 5.0, 4, 6],
	}
	for fish_id: StringName in CATFISH_IDS:
		var fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		var values: Array = expected_values[fish_id]
		assert(int(fish.rarity) == int(values[0]))
		assert(is_equal_approx(fish.base_catch_weight, float(values[1])))
		assert(is_equal_approx(fish.weight_min_lb, float(values[2])))
		assert(is_equal_approx(fish.weight_max_lb, float(values[3])))
		assert(fish.sell_value_min == int(values[4]))
		assert(fish.sell_value_max == int(values[5]))

	var pond_context := FishingContextType.new()
	pond_context.location_tags = [&"starter_pond"]
	pond_context.water_type = WaterType.Type.FRESH_WATER
	var ocean_context := FishingContextType.new()
	ocean_context.location_tags = [&"coast", &"ocean"]
	ocean_context.water_type = WaterType.Type.SALT_WATER
	for fish_id: StringName in CATFISH_IDS:
		var fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(fish.availability.is_available(pond_context))
		assert(not fish.availability.is_available(ocean_context))
		var single_species_pool := FishPoolType.new()
		single_species_pool.candidates = [fish]
		var collection := CollectionLogType.new()
		var selector := FishSelectorType.new()
		selector.use_deterministic_test_seed = true
		selector.begin_roll()
		assert(
			selector.select_fish(
				single_species_pool, pond_context, collection
			) == fish
		)
		collection.free()
	for fish_id: StringName in SALT_WATER_IDS:
		var fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		var single_species_pool := FishPoolType.new()
		single_species_pool.candidates = [fish]
		var collection := CollectionLogType.new()
		var selector := FishSelectorType.new()
		selector.use_deterministic_test_seed = true
		selector.begin_roll()
		assert(
			selector.select_fish(single_species_pool, pond_context, collection)
			== null
		)
		assert(
			selector.select_fish(single_species_pool, ocean_context, collection)
			== fish
		)
		collection.free()


func _validate_authoritative_water_filter() -> void:
	var fishing_spot := FishingSpotType.new()
	var service := NetworkFishingServiceType.new()
	service.set("_fish_catalog", Catalog)
	service.set("_fishing_spot", fishing_spot)
	var pond_region := FishableWaterRegion.new()
	pond_region.water_type = WaterType.Type.FRESH_WATER
	pond_region.fish_pool = PondPool
	pond_region.location_tags = [&"starter_pond"]
	var ocean_region := FishableWaterRegion.new()
	ocean_region.water_type = WaterType.Type.SALT_WATER
	ocean_region.fish_pool = OceanPool
	ocean_region.location_tags = [&"coast", &"ocean"]
	var stale_salt_pool_region := FishableWaterRegion.new()
	stale_salt_pool_region.water_type = WaterType.Type.FRESH_WATER
	stale_salt_pool_region.fish_pool = OceanPool
	stale_salt_pool_region.location_tags = [&"starter_pond"]
	var stale_fresh_pool_region := FishableWaterRegion.new()
	stale_fresh_pool_region.water_type = WaterType.Type.SALT_WATER
	stale_fresh_pool_region.fish_pool = PondPool
	stale_fresh_pool_region.location_tags = [&"coast", &"ocean"]
	var evidence := {"discovered_fish_ids": []}
	assert(
		service.call("_select_authoritative_fish", pond_region, evidence, null)
		!= null
	)
	assert(
		service.call("_select_authoritative_fish", ocean_region, evidence, null)
		!= null
	)
	assert(
		service.call(
			"_select_authoritative_fish", stale_salt_pool_region, evidence, null
		) == null
	)
	assert(
		service.call(
			"_select_authoritative_fish", stale_fresh_pool_region, evidence, null
		) == null
	)
	service.free()
	fishing_spot.free()
	pond_region.free()
	ocean_region.free()
	stale_salt_pool_region.free()
	stale_fresh_pool_region.free()


func _validate_starter_water_bodies() -> void:
	var region := StarterRegionScene.instantiate()
	var pond := region.get_node("WaterBodies/Pond/FishingRegion") as FishableWaterRegion
	var ocean := region.get_node(
		"WaterBodies/Ocean/FishingRegions/OceanFishingRegion"
	) as FishableWaterRegion
	assert(pond.water_type == WaterType.Type.FRESH_WATER)
	assert(ocean.water_type == WaterType.Type.SALT_WATER)
	assert(pond.fish_pool == PondPool)
	assert(ocean.fish_pool == OceanPool)
	assert(region.get_node_or_null("ShorelineRibbons/Pond") == null)
	assert(region.get_node_or_null("ShorelineRibbons/Ocean") != null)
	var pond_material := (
		region.get_node("WaterBodies/Pond/VisualWater") as MeshInstance3D
	).material_override as ShaderMaterial
	var ocean_material := (
		region.get_node("WaterBodies/Ocean/VisualWater") as MeshInstance3D
	).material_override as ShaderMaterial
	assert(not bool(pond_material.get_shader_parameter("tide_effect_enabled")))
	assert(bool(ocean_material.get_shader_parameter("tide_effect_enabled")))
	region.free()


func _validate_catches_and_authoritative_sale() -> void:
	var inventory := FishInventoryType.new()
	root.add_child(inventory)
	var selector := FishSelectorType.new()
	selector.use_deterministic_test_seed = true
	selector.begin_roll()
	var sale_service := NetworkSaleServiceType.new()
	var session := NetworkSession.new()
	root.add_child(session)
	root.add_child(sale_service)
	sale_service.set("_session", session)
	sale_service.set("_fish_catalog", Catalog)
	sale_service.set("_buyer", PelicanBuyer)

	for index: int in Catalog.candidates.size():
		var fish: FishDataType = Catalog.candidates[index]
		var fish_catch: FishCatch = selector.create_catch(fish)
		assert(fish_catch != null)
		fish_catch.catch_sequence = index + 1
		assert(fish_catch.fish.display_texture == fish.display_texture)

		var loaded: FishCatch = FishCatchType.from_save_dict(
			fish_catch.to_save_dict(), Catalog.get_fish_by_id(fish.id)
		)
		assert(loaded != null)
		assert(loaded.fish_id == fish.id)
		assert(loaded.fish == fish)

		var replicated: FishCatch = FishCatchType.from_network_dict(
			fish_catch.to_network_dict(), Catalog.get_fish_by_id(fish.id)
		)
		assert(replicated != null)
		assert(replicated.fish_id == fish.id)
		assert(replicated.fish.display_texture == fish.display_texture)

		inventory.add_catch(loaded)
		assert(inventory.contains_catch_id(loaded.catch_id))
		var sale_result: Dictionary = sale_service.call(
			"_build_authoritative_result",
			1,
			"catalog_sale_%d" % index,
			[loaded.to_network_dict()],
		)
		assert(bool(sale_result.get("accepted", false)))
		assert(int(sale_result.get("base_value", -1)) == loaded.sale_value)
		assert((sale_result.get("catch_ids", []) as Array).size() == 1)

	inventory.queue_free()
	sale_service.queue_free()
	session.queue_free()
