extends SceneTree

const FishCatchType = preload("res://fish/fish_catch.gd")
const FishQualityType = preload("res://fish/fish_quality.gd")
const FishSelectorType = preload("res://fish/fish_selector.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")
const NetworkSaleServiceType = preload(
	"res://network/network_sale_service.gd"
)
const Catalog: FishPool = preload("res://fish/pools/fish_catalog.tres")
const PelicanBuyer: FishBuyerProfile = preload(
	"res://economy/buyers/pelicans.tres"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_tiers_and_distribution()
	_validate_barrier_challenge_curve()
	_validate_fight_pacing_and_reel_upgrades()
	_validate_catch_round_trip_and_sale()
	_validate_mail_round_trip()
	_validate_collection_mastery()
	_validate_version_four_migration()
	assert(NetworkProtocol.PROTOCOL_VERSION == 6)
	assert(NetworkProtocol.ENET_CHANNEL_COUNT == 10)
	assert(NetworkProtocol.FISH_QUALITY_CAPABILITY == "fish_quality_v1")
	print("Fish quality validation: PASS")
	quit()


func _validate_tiers_and_distribution() -> void:
	assert(FishQualityType.TIER_COUNT == 5)
	assert(FishQualityType.display_name(0) == "boring")
	assert(FishQualityType.display_name(4) == "shiny")
	assert(UIPalette.get_quality_color(0) == UIPalette.QUALITY_BORING)
	assert(UIPalette.get_quality_color(4) == UIPalette.QUALITY_SHINY)
	assert(
		UIPalette.get_quality_color(0)
		!= UIPalette.get_quality_color(1)
	)
	assert(FishQualityType.apply_sale_value(3, 0) == 3)
	assert(FishQualityType.apply_sale_value(3, 1) == 4)
	assert(FishQualityType.apply_sale_value(3, 2) == 5)
	assert(FishQualityType.apply_sale_value(3, 3) == 6)
	assert(FishQualityType.apply_sale_value(3, 4) == 7)
	var previous_offer: int = -1
	for quality: int in FishQualityType.TIER_COUNT:
		var offer: int = PelicanBuyer.get_quality_offer(3, quality)
		assert(offer > previous_offer)
		previous_offer = offer
	assert(
		FishQualityType.qualified_name_with_article("bluegill", 0)
		== "a boring bluegill"
	)
	assert(
		FishQualityType.qualified_name_with_article("bluegill", 1)
		== "an average bluegill"
	)
	var rng := RandomNumberGenerator.new()
	rng.seed = 727272
	var counts: Array[int] = [0, 0, 0, 0, 0]
	const SAMPLE_COUNT: int = 50000
	for _sample: int in SAMPLE_COUNT:
		counts[FishQualityType.roll(rng)] += 1
	for quality: int in FishQualityType.TIER_COUNT:
		var observed: float = float(counts[quality]) / float(SAMPLE_COUNT)
		var expected: float = (
			FishQualityType.BASE_ROLL_WEIGHTS[quality] / 100.0
		)
		assert(absf(observed - expected) < 0.015)


func _validate_barrier_challenge_curve() -> void:
	assert(
		FishQualityType.BARRIER_HEALTH_MULTIPLIERS.size()
		== FishQualityType.TIER_COUNT
	)
	var expected_minimums: Array[int] = [1, 10, 50, 100, 200]
	var expected_maximums: Array[int] = [9, 50, 100, 200, 400]
	var previous_health: int = 0
	for quality: int in FishQualityType.TIER_COUNT:
		var expected_range := Vector2i(
			expected_minimums[quality], expected_maximums[quality]
		)
		assert(
			FishQualityType.barrier_health_range(quality)
			== expected_range
		)
		assert(
			FishQualityType.roll_barrier_health(null, quality)
			== expected_range.x
		)
		var rng := RandomNumberGenerator.new()
		rng.seed = 73013 + quality
		var observed_counts: Dictionary[int, int] = {}
		var observed_minimum: int = expected_range.y
		var observed_maximum: int = expected_range.x
		var observed_total: int = 0
		var band_size: int = expected_range.y - expected_range.x + 1
		var sample_count: int = maxi(10000, band_size * 250)
		for _sample: int in sample_count:
			var rolled_health: int = FishQualityType.roll_barrier_health(
				rng, quality
			)
			assert(
				rolled_health >= expected_range.x
				and rolled_health <= expected_range.y
			)
			observed_counts[rolled_health] = (
				int(observed_counts.get(rolled_health, 0)) + 1
			)
			observed_minimum = mini(observed_minimum, rolled_health)
			observed_maximum = maxi(observed_maximum, rolled_health)
			observed_total += rolled_health
		assert(observed_minimum == expected_range.x)
		assert(observed_maximum == expected_range.y)
		for authored_health: int in range(
			expected_range.x, expected_range.y + 1
		):
			assert(observed_counts.has(authored_health))
		var observed_average: float = (
			float(observed_total) / float(sample_count)
		)
		var authored_midpoint: float = (
			float(expected_range.x + expected_range.y) / 2.0
		)
		assert(
			absf(observed_average - authored_midpoint)
			< maxf(0.15, float(band_size) * 0.01)
		)
		var health: int = FishQualityType.apply_barrier_health(8, quality)
		assert(health > previous_health)
		previous_health = health
	assert(FishQualityType.apply_barrier_health(8, -1) == 8)
	assert(FishQualityType.apply_barrier_health(0, FishQualityType.Tier.SHINY) == 4)
	assert(
		FishQualityType.barrier_health_range(-1)
		== Vector2i(1, 9)
	)

	var profile := CatchDifficultyProfile.new()
	profile.barrier_count_min = 1
	profile.barrier_count_max = 1
	profile.first_barrier_margin = 0.2
	profile.final_barrier_margin = 0.2
	profile.minimum_barrier_spacing = 0.1
	var controller := CatchController.new()
	root.add_child(controller)
	for quality: int in FishQualityType.TIER_COUNT:
		controller.start_authoritative_encounter(
			profile,
			0.1,
			1,
			818181,
			quality,
		)
		var barriers_value: Variant = controller.get("_barriers")
		assert(barriers_value is Array)
		var barriers: Array = barriers_value as Array
		assert(barriers.size() == 1)
		var barrier := barriers[0] as RefCounted
		assert(barrier != null)
		var health: int = int(barrier.get("maximum_health"))
		assert(health >= expected_minimums[quality])
		assert(health <= expected_maximums[quality])
	controller.queue_free()

	var shiny_health: int = FishQualityType.barrier_health_range(
		FishQualityType.Tier.SHINY
	).y
	var base_power_clicks: int = ceili(float(shiny_health) / 1.0)
	var maximum_barrier_damage: int = (
		PlayerFishingUpgrades.get_barrier_damage_for_level(
			PlayerFishingUpgrades.MAX_BARRIER_POWER_LEVEL
		)
	)
	var max_power_clicks: int = ceili(
		float(shiny_health)
		/ float(maximum_barrier_damage)
	)
	assert(base_power_clicks == 400)
	assert(maximum_barrier_damage == 128)
	assert(
		NetworkFishingProtocol.MAX_BARRIER_DAMAGE
		== maximum_barrier_damage
	)
	assert(max_power_clicks == 4)
	assert(max_power_clicks < base_power_clicks)


func _validate_fight_pacing_and_reel_upgrades() -> void:
	assert(is_equal_approx(CatchController.CHASE_SPEED, 0.07))
	assert(is_equal_approx(CatchController.CHASE_START_DELAY, 1.0))
	assert(is_equal_approx(CatchController.CHASE_START_OFFSET, 0.04))
	assert(is_equal_approx(Player.BASE_REEL_SPEED, 0.16))

	var upgrades := PlayerFishingUpgrades.new()
	assert(is_equal_approx(upgrades.get_reel_speed_multiplier(), 1.0))
	assert(
		PlayerFishingUpgrades.BARRIER_POWER_COSTS.size()
		== PlayerFishingUpgrades.MAX_BARRIER_POWER_LEVEL
	)
	for barrier_level: int in range(
		PlayerFishingUpgrades.MAX_BARRIER_POWER_LEVEL + 1
	):
		assert(upgrades.restore_levels(0, barrier_level))
		assert(upgrades.get_barrier_damage() == 1 << barrier_level)
		if barrier_level < PlayerFishingUpgrades.MAX_BARRIER_POWER_LEVEL:
			assert(
				upgrades.get_next_barrier_power_cost()
				== PlayerFishingUpgrades.BARRIER_POWER_COSTS[barrier_level]
			)
		else:
			assert(upgrades.get_next_barrier_power_cost() == -1)
	assert(
		upgrades.restore_levels(
			PlayerFishingUpgrades.MAX_REEL_SPEED_LEVEL,
			0,
		)
	)
	var upgraded_multiplier: float = upgrades.get_reel_speed_multiplier()
	assert(is_equal_approx(upgraded_multiplier, 1.5))

	var profile := CatchDifficultyProfile.new()
	profile.barrier_count_min = 0
	profile.barrier_count_max = 0
	var controller := CatchController.new()
	root.add_child(controller)
	controller.start_authoritative_encounter(
		profile,
		Player.BASE_REEL_SPEED,
		1,
		919191,
	)
	controller.set_reel_input(true)
	controller.call("_update_free_reeling", 1.0)
	var base_progress: float = controller.progress
	assert(is_equal_approx(base_progress, Player.BASE_REEL_SPEED))

	controller.reset()
	controller.start_authoritative_encounter(
		profile,
		Player.BASE_REEL_SPEED * upgraded_multiplier,
		1,
		919191,
	)
	controller.set_reel_input(true)
	controller.call("_update_free_reeling", 1.0)
	assert(
		is_equal_approx(
			controller.progress,
			Player.BASE_REEL_SPEED * upgraded_multiplier,
		)
	)
	assert(controller.progress > base_progress)
	controller.queue_free()
	upgrades.queue_free()


func _validate_catch_round_trip_and_sale() -> void:
	var fish: FishData = Catalog.get_fish_by_id(&"bluegill")
	assert(fish != null)
	var selector := FishSelectorType.new()
	selector.use_deterministic_test_seed = true
	selector.deterministic_test_seed = 9911
	selector.quality_weight_multipliers = [0.0, 0.0, 0.0, 0.0, 1.0]
	selector.begin_roll()
	var fish_catch: FishCatch = selector.create_catch(fish, [&"worm"])
	assert(fish_catch != null)
	assert(fish_catch.quality == FishQualityType.Tier.SHINY)
	assert(
		fish_catch.sale_value
		== FishQualityType.apply_sale_value(
			fish.get_sale_value_for_weight(fish_catch.weight_lb),
			FishQualityType.Tier.SHINY,
		)
	)
	var save_data: Dictionary = fish_catch.to_save_dict()
	fish_catch.catch_sequence = 1
	save_data = fish_catch.to_save_dict()
	var restored: FishCatch = FishCatchType.from_save_dict(save_data, fish)
	assert(restored != null and restored.quality == fish_catch.quality)
	var network_data: Dictionary = fish_catch.to_network_dict()
	var replicated: FishCatch = FishCatchType.from_network_dict(
		network_data,
		fish,
	)
	assert(replicated != null and replicated.quality == fish_catch.quality)
	var missing_quality: Dictionary = network_data.duplicate(true)
	missing_quality.erase("quality")
	assert(FishCatchType.from_network_dict(missing_quality, fish) == null)

	var session := NetworkSession.new()
	var sale_service := NetworkSaleServiceType.new()
	root.add_child(session)
	root.add_child(sale_service)
	sale_service.set("_session", session)
	sale_service.set("_fish_catalog", Catalog)
	var accepted: Dictionary = sale_service.call(
		"_build_authoritative_result",
		1,
		"quality_sale",
		[network_data],
		PelicanBuyer,
	)
	assert(bool(accepted.get("accepted", false)))
	assert(
		int(accepted["payout"])
		== PelicanBuyer.get_quality_offer(
			fish.get_sale_value_for_weight(fish_catch.weight_lb),
			fish_catch.quality,
		)
	)
	var inventory := FishInventory.new()
	var wallet := PlayerWallet.new()
	var local_sale := FishSaleService.new()
	root.add_child(inventory)
	root.add_child(wallet)
	root.add_child(local_sale)
	local_sale.setup(inventory, wallet)
	inventory.add_catch(fish_catch)
	var local_preview: FishSaleResult = local_sale.preview_batch(
		[fish_catch.catch_id],
		PelicanBuyer,
	)
	assert(local_preview.is_success())
	assert(local_preview.payout == int(accepted["payout"]))
	var forged: Dictionary = network_data.duplicate(true)
	forged["quality"] = FishQualityType.Tier.BORING
	var rejected: Dictionary = sale_service.call(
		"_build_authoritative_result",
		1,
		"quality_sale_forged",
		[forged],
		PelicanBuyer,
	)
	assert(not bool(rejected.get("accepted", false)))
	local_sale.queue_free()
	wallet.queue_free()
	inventory.queue_free()
	sale_service.queue_free()
	session.queue_free()


func _validate_mail_round_trip() -> void:
	var fish: FishData = Catalog.get_fish_by_id(&"bluegill")
	var fish_catch := FishCatchType.new()
	fish_catch.fish = fish
	fish_catch.fish_id = fish.id
	fish_catch.weight_lb = fish.get_minimum_weight()
	fish_catch.display_scale = fish.get_display_scale_for_weight(
		fish_catch.weight_lb
	)
	fish_catch.quality = FishQualityType.Tier.IMPRESSIVE
	fish_catch.sale_value = FishQualityType.apply_sale_value(
		fish.get_sale_value_for_weight(fish_catch.weight_lb),
		fish_catch.quality,
	)
	fish_catch.ensure_identity()
	var attachment: Dictionary = {
		"type": PlayerAssetReservationService.AttachmentType.FISH,
		"catch_id": String(fish_catch.catch_id),
		"catch": fish_catch.to_network_dict(),
	}
	var service := NetworkMailService.new()
	root.add_child(service)
	service.set("_fish_catalog", Catalog)
	var restored: FishCatch = service.call("_decode_catch", attachment)
	assert(restored != null)
	assert(restored.quality == FishQualityType.Tier.IMPRESSIVE)
	var signature: Array = NetworkMailProtocol.attachment_signature_fields(
		attachment
	)
	assert(int(signature[5]) == FishQualityType.Tier.IMPRESSIVE)
	var altered: Dictionary = attachment.duplicate(true)
	(altered["catch"] as Dictionary)["quality"] = (
		FishQualityType.Tier.BORING
	)
	assert(
		NetworkMailProtocol.attachment_signature_fields(altered)
		!= signature
	)
	service.queue_free()


func _validate_collection_mastery() -> void:
	var collection := CollectionLogType.new()
	root.add_child(collection)
	for quality: int in FishQualityType.TIER_COUNT:
		collection.mark_quality_discovered(&"bluegill", quality)
		assert(collection.has_discovered_quality(&"bluegill", quality))
	assert(collection.has_discovered(&"bluegill"))
	assert(collection.has_mastered(&"bluegill"))
	assert(
		collection.get_quality_mask(&"bluegill")
		== FishQualityType.ALL_TIERS_MASK
	)
	collection.queue_free()


func _validate_version_four_migration() -> void:
	var manager := PlayerSaveManager.new()
	root.add_child(manager)
	var version_four: Dictionary = {
		"save_version": 4,
		"wallet": {"balance": 12},
		"collection": {"discovered_fish_ids": ["bluegill"]},
		"inventory": {
			"next_catch_sequence": 2,
			"catches": [{
				"catch_id": "carp:legacy",
				"catch_sequence": 1,
				"fish_id": "carp",
				"weight_lb": 2.0,
				"display_scale": 1.0,
				"sale_value": 4,
				"is_favorited": false,
			}],
		},
		"bag": {"items": []},
		"hotbar": {"selected_slot": 0, "slots": []},
		"upgrades": {"reel_speed_level": 0, "barrier_power_level": 0},
		"cooler": {"capacity_level": 0},
	}
	var migrated: Dictionary = manager.call(
		"_migrate_save",
		version_four,
		4,
	)
	assert(int(migrated.get("save_version", -1)) == 7)
	assert(int((migrated["experience"] as Dictionary)["total_experience"]) == 0)
	assert(
		is_equal_approx(
			float((migrated["world"] as Dictionary)["time_hours"]),
			8.0,
		)
	)
	var catches: Array = migrated["inventory"]["catches"]
	assert(int((catches[0] as Dictionary)["quality"]) == 0)
	var collection: Dictionary = migrated["collection"]
	var ids: Array = collection["discovered_fish_ids"]
	assert("bluegill" in ids and "carp" in ids)
	var masks: Dictionary = collection["discovered_quality_masks"]
	var boring_bit: int = FishQualityType.bit_for(FishQualityType.Tier.BORING)
	assert(int(masks["bluegill"]) == boring_bit)
	assert(int(masks["carp"]) == boring_bit)
	assert(
		PlayerJobService.validate_save_data(migrated.get("jobs", {}))
	)
	manager.queue_free()
