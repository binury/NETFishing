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
var _active_bait_tags: Array[StringName] = []

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
	_active_bait_tags = context.active_bait_tags.duplicate()
	var all_fish: Array[FishDataType] = []
	var all_weights: Array[float] = []
	var rarity_fish: Array[FishDataType] = []
	var rarity_weights: Array[float] = []
	var selected_rarity: int = _roll_rarity(context)
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
		# Species-specific preferred bait is deprecated. Bait now controls
		# quality and rarity bands globally; required tags remain authoritative.
		if not collection_log.has_discovered(fish.id):
			final_weight *= maxf(undiscovered_weight_multiplier, 0.0)
		if fish.rarity >= 0 and fish.rarity < rarity_weight_multipliers.size():
			final_weight *= maxf(rarity_weight_multipliers[fish.rarity], 0.0)
		if final_weight <= 0.0:
			continue
		all_fish.append(fish)
		all_weights.append(final_weight)
		if int(fish.rarity) == selected_rarity:
			rarity_fish.append(fish)
			rarity_weights.append(final_weight)
	var eligible_fish: Array[FishDataType] = rarity_fish if not rarity_fish.is_empty() else all_fish
	weights = rarity_weights if not rarity_weights.is_empty() else all_weights
	for weight: float in weights:
		total_weight += weight

	if eligible_fish.is_empty() or total_weight <= 0.0:
		return null
	var roll: float = _rng.randf() * total_weight
	var accumulated_weight: float = 0.0
	for index: int in range(eligible_fish.size()):
		accumulated_weight += weights[index]
		if roll <= accumulated_weight:
			return eligible_fish[index]
	return eligible_fish.back()


func _roll_rarity(context: FishingContextType) -> int:
	var weights: Array[float] = [100.0, 0.0, 0.0, 0.0, 0.0]
	if not context.active_bait_tags.is_empty():
		weights = [80.0, 10.0, 5.0, 4.0, 1.0]
	for index: int in range(weights.size()):
		if index < rarity_weight_multipliers.size():
			weights[index] *= maxf(rarity_weight_multipliers[index], 0.0)
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	if total <= 0.0:
		return FishDataType.Rarity.COMMON
	var roll: float = _rng.randf() * total
	for index: int in range(weights.size()):
		roll -= weights[index]
		if roll <= 0.0:
			return index
	return FishDataType.Rarity.LEGENDARY


func create_catch(fish: FishDataType, bait_tags: Array[StringName] = []) -> FishCatchType:
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
	var effective_bait: Array[StringName] = bait_tags if not bait_tags.is_empty() else _active_bait_tags
	var quality_multipliers: Array[float] = FishQualityType.roll_weights_for_bait(effective_bait)
	for quality: int in range(mini(quality_multipliers.size(), quality_weight_multipliers.size())):
		quality_multipliers[quality] *= maxf(quality_weight_multipliers[quality], 0.0)
	caught_fish.quality = FishQualityType.roll(
		_rng,
		quality_multipliers,
	)
	caught_fish.sale_value = FishQualityType.apply_sale_value(
		fish.get_sale_value_for_weight(caught_fish.weight_lb),
		caught_fish.quality,
	)
	return caught_fish
