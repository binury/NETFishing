extends SceneTree

const FishCatchType = preload("res://fish/fish_catch.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const FishBuyerProfileType = preload("res://economy/fish_buyer_profile.gd")
const FishSelectorType = preload("res://fish/fish_selector.gd")
const FishingContextType = preload("res://fishing/fishing_context.gd")
const NetworkSaleServiceType = preload(
	"res://network/network_sale_service.gd"
)
const NetworkFishingServiceType = preload(
	"res://network/network_fishing_service.gd"
)
const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const CalendarSeasonType = preload("res://world/calendar_season.gd")

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
	&"goby_round",
]
const SALT_WATER_IDS: Array[StringName] = [
	&"bass",
	&"sunfish",
	&"tuna_albacore",
	&"tuna_bigeye",
	&"tuna_bluefin",
	&"tuna_skipjack",
	&"tuna_yellowfin",
	&"salmon_atlantic",
	&"salmon_chum",
	&"salmon_coho",
	&"salmon_pink",
	&"salmon_sockeye",
	&"anchovy_european", &"anchovy_northern",
	&"grouper_gulf", &"grouper_red",
	&"mackerel_atlantic", &"mackerel_cero", &"mackerel_chub",
	&"mackerel_king", &"mackerel_spanish",
	&"marlin_black", &"marlin_blue", &"marlin_white",
	&"pomfret_black", &"pomfret_chinese", &"pomfret_golden",
	&"pomfret_white", &"sailfish",
	&"snapper_lane", &"snapper_mangrove", &"snapper_mutton",
	&"snapper_red", &"swordfish",
]
const NEW_FRESH_WATER_IDS: Array[StringName] = [
	&"chub_european", &"chub_flame", &"chub_lake", &"goldfish",
	&"goldfish_bubbleeye", &"sauger", &"saugeye", &"trout_cutthroat",
	&"trout_golden", &"trout_rainbow", &"trout_steelhead", &"walleye",
	&"bowfin", &"sturgeon_lake", &"gar_longnose", &"paddlefish",
	&"sturgeon_shovelnose", &"gar_spotted", &"lungfish_west_african",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_catalog_and_pools()
	_validate_weight_based_display_scale()
	_validate_starter_water_bodies()
	_validate_authoritative_water_filter()
	_validate_catches_and_authoritative_sale()
	print("Fish catalog content validation: PASS")
	quit()


func _validate_weight_based_display_scale() -> void:
	var previous_scale: float = 0.0
	for fish: FishDataType in Catalog.candidates:
		if not fish.active:
			continue
		assert(fish.is_selectable())
		assert(fish.weight_min_lb > 0.0)
		assert(fish.weight_max_lb <= 1000.0)
		var minimum_scale: float = fish.get_display_scale_for_weight(
			fish.weight_min_lb
		)
		var maximum_scale: float = fish.get_display_scale_for_weight(
			fish.weight_max_lb
		)
		assert(minimum_scale >= FishDataType.DISPLAY_MIN_SCALE)
		assert(maximum_scale <= FishDataType.DISPLAY_MAX_SCALE)
		assert(maximum_scale >= minimum_scale)
		var midpoint_weight: float = lerpf(
			fish.weight_min_lb,
			fish.weight_max_lb,
			0.5,
		)
		assert(
			fish.get_display_scale_for_weight(midpoint_weight)
			>= minimum_scale
		)
		# A one-pound catch is a shared visual reference, not a per-species
		# texture-size decision.
		var reference_scale: float = fish.get_display_scale_for_weight(1.0)
		assert(is_equal_approx(reference_scale, FishDataType.DISPLAY_REFERENCE_SCALE))
		previous_scale = maxf(previous_scale, maximum_scale)
	assert(previous_scale <= FishDataType.DISPLAY_MAX_SCALE)


func _validate_catalog_and_pools() -> void:
	assert(Catalog.candidates.size() == 316)
	assert(PondPool.candidates.size() == 26)
	assert(OceanPool.candidates.size() == 34)
	var active_count: int = 0
	var inactive_count: int = 0
	var catalog_numbers: Dictionary[int, bool] = {}
	for fish: FishDataType in Catalog.candidates:
		assert(fish != null and not fish.id.is_empty())
		assert(fish.catalog_number > 0)
		assert(not fish.collection_group.is_empty())
		assert(not catalog_numbers.has(fish.catalog_number))
		catalog_numbers[fish.catalog_number] = true
		assert(not fish.logbook_fact.strip_edges().is_empty())
		assert(CalendarSeasonType.is_valid_mask(fish.available_seasons))
		assert(not fish.get_season_text().is_empty())
		if fish.active:
			active_count += 1
			assert(fish.is_selectable())
			assert(fish.display_texture != null)
		else:
			inactive_count += 1
			assert(not fish.is_selectable())
			assert(fish.display_texture == null)
	assert(active_count == 63)
	assert(inactive_count == 253)
	var chum: FishDataType = Catalog.get_fish_by_id(&"salmon_chum")
	assert(chum != null)
	assert(chum.get_season_text() == "fall")
	assert(
		chum.is_available_in_season(CalendarSeasonType.Season.FALL)
	)
	assert(
		not chum.is_available_in_season(CalendarSeasonType.Season.SUMMER)
	)
	var chum_pool := FishPoolType.new()
	chum_pool.candidates = [chum]
	var seasonal_collection := CollectionLogType.new()
	var seasonal_selector := FishSelectorType.new()
	seasonal_selector.use_deterministic_test_seed = true
	var summer_context := FishingContextType.new()
	summer_context.water_type = WaterType.Type.SALT_WATER
	summer_context.season = CalendarSeasonType.Season.SUMMER
	seasonal_selector.begin_roll()
	assert(
		seasonal_selector.select_fish(
			chum_pool,
			summer_context,
			seasonal_collection,
		) == null
	)
	var fall_context := FishingContextType.new()
	fall_context.water_type = WaterType.Type.SALT_WATER
	fall_context.season = CalendarSeasonType.Season.FALL
	seasonal_selector.begin_roll()
	assert(
		seasonal_selector.select_fish(
			chum_pool,
			fall_context,
			seasonal_collection,
		) == chum
	)
	seasonal_collection.free()
	var inactive_fish: FishDataType = Catalog.get_fish_by_id(&"mudskipper_atlantic")
	assert(inactive_fish != null and not inactive_fish.active)
	var inactive_pool := FishPoolType.new()
	inactive_pool.candidates = [inactive_fish]
	var inactive_context := FishingContextType.new()
	inactive_context.water_type = WaterType.Type.FRESH_WATER
	var inactive_collection := CollectionLogType.new()
	var inactive_selector := FishSelectorType.new()
	inactive_selector.use_deterministic_test_seed = true
	inactive_selector.begin_roll()
	assert(
		inactive_selector.select_fish(
			inactive_pool,
			inactive_context,
			inactive_collection,
		) == null
	)
	assert(inactive_selector.create_catch(inactive_fish) == null)
	inactive_collection.free()
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
		assert(
			LogbookCatalog.category_for(fresh_fish)
			== LogbookCatalog.Category.FRESH_WATER
		)
	for fish_id: StringName in SALT_WATER_IDS:
		var salt_fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(OceanPool.get_fish_by_id(fish_id) == salt_fish)
		assert(PondPool.get_fish_by_id(fish_id) == null)
		assert(salt_fish.is_allowed_in_water(WaterType.Type.SALT_WATER))
		assert(not salt_fish.is_allowed_in_water(WaterType.Type.FRESH_WATER))
		assert(
			LogbookCatalog.category_for(salt_fish)
			== LogbookCatalog.Category.SALT_WATER
		)
	for fish_id: StringName in CATFISH_IDS:
		var fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(fish != null)
		assert(fish.is_selectable())
		assert(PondPool.get_fish_by_id(fish_id) == fish)
		assert(OceanPool.get_fish_by_id(fish_id) == null)
		assert(fish.availability.allowed_location_tags == [&"starter_pond"])
		assert(
			LogbookCatalog.category_for(fish)
			== LogbookCatalog.Category.FRESH_WATER
		)
	for fish_id: StringName in NEW_FRESH_WATER_IDS:
		var fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(fish != null and fish.is_selectable())
		assert(PondPool.get_fish_by_id(fish_id) == fish)
		assert(OceanPool.get_fish_by_id(fish_id) == null)
		assert(
			LogbookCatalog.category_for(fish)
			== LogbookCatalog.Category.FRESH_WATER
		)

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

	var expected_tuna_values: Dictionary[StringName, Array] = {
		&"tuna_albacore": [2, 1.5, 10.0, 45.0, 12, 24],
		&"tuna_bigeye": [3, 0.55, 20.0, 120.0, 22, 48],
		&"tuna_bluefin": [4, 0.18, 30.0, 250.0, 35, 90],
		&"tuna_skipjack": [1, 3.0, 5.0, 25.0, 8, 16],
		&"tuna_yellowfin": [2, 1.0, 15.0, 80.0, 16, 36],
	}
	for fish_id: StringName in expected_tuna_values:
		var fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		var values: Array = expected_tuna_values[fish_id]
		assert(fish != null and fish.is_selectable())
		assert(int(fish.rarity) == int(values[0]))
		assert(is_equal_approx(fish.base_catch_weight, float(values[1])))
		assert(is_equal_approx(fish.weight_min_lb, float(values[2])))
		assert(is_equal_approx(fish.weight_max_lb, float(values[3])))
		assert(fish.sell_value_min == int(values[4]))
		assert(fish.sell_value_max == int(values[5]))

	var expected_new_values: Dictionary[StringName, Array] = {
		&"goby_round": [0, 8.0, 0.1, 0.6, 2, 3],
		&"salmon_atlantic": [3, 0.65, 8.0, 40.0, 20, 42],
		&"salmon_chum": [1, 2.5, 6.0, 25.0, 10, 22],
		&"salmon_coho": [2, 1.4, 5.0, 30.0, 14, 28],
		&"salmon_pink": [1, 3.0, 3.0, 12.0, 8, 15],
		&"salmon_sockeye": [2, 1.6, 4.0, 15.0, 12, 24],
	}
	for fish_id: StringName in expected_new_values:
		var fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		var values: Array = expected_new_values[fish_id]
		assert(fish != null and fish.is_selectable())
		assert(int(fish.rarity) == int(values[0]))
		assert(is_equal_approx(fish.base_catch_weight, float(values[1])))
		assert(is_equal_approx(fish.weight_min_lb, float(values[2])))
		assert(is_equal_approx(fish.weight_max_lb, float(values[3])))
		assert(fish.sell_value_min == int(values[4]))
		assert(fish.sell_value_max == int(values[5]))

	var pond_context := FishingContextType.new()
	pond_context.location_tags = [&"starter_pond"]
	pond_context.water_type = WaterType.Type.FRESH_WATER
	var night_pond_context := FishingContextType.new()
	night_pond_context.location_tags = [&"starter_pond"]
	night_pond_context.water_type = WaterType.Type.FRESH_WATER
	night_pond_context.is_night = true
	var ocean_context := FishingContextType.new()
	ocean_context.location_tags = [&"coast", &"ocean"]
	ocean_context.water_type = WaterType.Type.SALT_WATER
	for fish_id: StringName in CATFISH_IDS:
		var fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(not fish.availability.is_available(pond_context))
		assert(fish.availability.is_available(night_pond_context))
		assert(not fish.availability.is_available(ocean_context))
		var single_species_pool := FishPoolType.new()
		single_species_pool.candidates = [fish]
		var collection := CollectionLogType.new()
		var selector := FishSelectorType.new()
		selector.use_deterministic_test_seed = true
		selector.begin_roll()
		assert(
			selector.select_fish(
				single_species_pool, night_pond_context, collection
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
		service.call(
			"_select_authoritative_fish", pond_region, evidence, null, null
		)
		!= null
	)
	assert(
		service.call(
			"_select_authoritative_fish", ocean_region, evidence, null, null
		)
		!= null
	)
	assert(
		service.call(
			"_select_authoritative_fish",
			stale_salt_pool_region,
			evidence,
			null,
			null,
		) == null
	)
	assert(
		service.call(
			"_select_authoritative_fish",
			stale_fresh_pool_region,
			evidence,
			null,
			null,
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
	var shoreline_geometry := (
		region.get_node_or_null("ShorelineRibbons/Ocean") as MeshInstance3D
	)
	assert(shoreline_geometry != null)
	assert(not shoreline_geometry.visible)
	assert(shoreline_geometry.material_override == null)
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
	var sale_buyers: Dictionary[StringName, FishBuyerProfileType] = {
		PelicanBuyer.id: PelicanBuyer,
	}
	sale_service.set("_buyers", sale_buyers)

	var catch_sequence: int = 0
	for fish: FishDataType in Catalog.candidates:
		if not fish.active:
			continue
		catch_sequence += 1
		var fish_catch: FishCatch = selector.create_catch(fish)
		assert(fish_catch != null)
		fish_catch.catch_sequence = catch_sequence
		assert(fish_catch.fish.display_texture == fish.display_texture)

		var loaded: FishCatch = FishCatchType.from_save_dict(
			fish_catch.to_save_dict(), Catalog.get_fish_by_id(fish.id)
		)
		assert(loaded != null)
		assert(loaded.fish_id == fish.id)
		assert(loaded.fish == fish)
		assert(
			is_equal_approx(
				loaded.display_scale,
				fish.get_display_scale_for_weight(loaded.weight_lb),
			)
		)

		var replicated: FishCatch = FishCatchType.from_network_dict(
			fish_catch.to_network_dict(), Catalog.get_fish_by_id(fish.id)
		)
		assert(replicated != null)
		assert(replicated.fish_id == fish.id)
		assert(replicated.fish.display_texture == fish.display_texture)
		assert(
			is_equal_approx(
				replicated.display_scale,
				fish.get_display_scale_for_weight(replicated.weight_lb),
			)
		)

		inventory.add_catch(loaded)
		assert(inventory.contains_catch_id(loaded.catch_id))
		var sale_result: Dictionary = sale_service.call(
			"_build_authoritative_result",
			1,
			"catalog_sale_%d" % catch_sequence,
			[loaded.to_network_dict()],
			[],
			PelicanBuyer,
		)
		assert(bool(sale_result.get("accepted", false)))
		assert(int(sale_result.get("base_value", -1)) == loaded.sale_value)
		assert((sale_result.get("catch_ids", []) as Array).size() == 1)

	inventory.queue_free()
	sale_service.queue_free()
	session.queue_free()
