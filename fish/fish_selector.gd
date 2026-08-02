class_name FishSelector
extends RefCounted

const CollectionLogType = preload("res://collection/collection_log.gd")
const FishCatchType = preload("res://fish/fish_catch.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const FishQualityType = preload("res://fish/fish_quality.gd")
const FishingContextType = preload("res://fishing/fishing_context.gd")

var undiscovered_weight_multiplier: float = 1.5
var rarity_weight_multipliers: Array[float] = []
var quality_weight_multipliers: Array[float] = []
var use_deterministic_test_seed: bool = false
var deterministic_test_seed: int = 24680
var selection_seed: int = 0

var _rng := RandomNumberGenerator.new()


func begin_roll() -> void:
	if use_deterministic_test_seed:
		selection_seed = deterministic_test_seed
		_rng.seed = deterministic_test_seed
	else:
		_rng.randomize()
		selection_seed = _rng.seed


func select_fish(
	pool: FishPoolType,
	context: FishingContextType,
	collection_log: CollectionLogType,
) -> FishDataType:
	if pool == null or context == null or collection_log == null:
		return null

	var eligible_fish: Array[FishDataType] = []
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for fish: FishDataType in pool.candidates:
		if fish == null or not fish.is_selectable():
			continue
		if not fish.is_allowed_in_water(context.water_type):
			continue
		if fish.availability != null and not fish.availability.is_available(context):
			continue
		var final_weight: float = fish.base_catch_weight
		if fish.availability != null:
			final_weight *= fish.availability.get_bait_weight_multiplier(context)
		if not collection_log.has_discovered(fish.id):
			final_weight *= maxf(undiscovered_weight_multiplier, 0.0)
		if fish.rarity >= 0 and fish.rarity < rarity_weight_multipliers.size():
			final_weight *= maxf(rarity_weight_multipliers[fish.rarity], 0.0)
		if final_weight <= 0.0:
			continue
		eligible_fish.append(fish)
		weights.append(final_weight)
		total_weight += final_weight

	if eligible_fish.is_empty() or total_weight <= 0.0:
		return null
	var roll: float = _rng.randf() * total_weight
	var accumulated_weight: float = 0.0
	for index: int in range(eligible_fish.size()):
		accumulated_weight += weights[index]
		if roll <= accumulated_weight:
			return eligible_fish[index]
	return eligible_fish.back()


func create_catch(fish: FishDataType) -> FishCatchType:
	if fish == null or not fish.is_selectable():
		return null
	var caught_fish := FishCatchType.new()
	caught_fish.fish = fish
	caught_fish.fish_id = fish.id
	caught_fish.ensure_identity()
	caught_fish.weight_lb = _rng.randf_range(
		fish.get_minimum_weight(),
		fish.get_maximum_weight()
	)
	caught_fish.display_scale = fish.get_display_scale_for_weight(
		caught_fish.weight_lb
	)
	caught_fish.quality = FishQualityType.roll(
		_rng,
		quality_weight_multipliers,
	)
	caught_fish.sale_value = FishQualityType.apply_sale_value(
		fish.get_sale_value_for_weight(caught_fish.weight_lb),
		caught_fish.quality,
	)
	return caught_fish
