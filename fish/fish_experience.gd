class_name FishExperience
extends RefCounted

const FishCatchType = preload("res://fish/fish_catch.gd")
const FishQualityType = preload("res://fish/fish_quality.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")

const RARITY_BASE_EXPERIENCE: Array[int] = [10, 18, 32, 55, 90]
const QUALITY_MULTIPLIERS: Array[float] = [1.0, 1.15, 1.4, 1.8, 2.5]
const MAXIMUM_WEIGHT_BONUS: float = 0.25
const FIRST_SPECIES_BONUS: int = 25
const FIRST_QUALITY_BONUS: int = 15
const SPECIES_MASTERY_BONUS: int = 100


static func calculate_for_collection(
	fish_catch: FishCatchType,
	collection_log: CollectionLogType,
) -> int:
	if fish_catch == null or collection_log == null:
		return 0
	return calculate_catch_experience(
		fish_catch,
		collection_log.has_discovered(fish_catch.fish_id),
		collection_log.get_quality_mask(fish_catch.fish_id),
	)


static func calculate_catch_experience(
	fish_catch: FishCatchType,
	was_species_discovered: bool,
	previous_quality_mask: int,
) -> int:
	if fish_catch == null or not fish_catch.is_valid():
		return 0
	var rarity: int = int(fish_catch.fish.rarity)
	if rarity < 0 or rarity >= RARITY_BASE_EXPERIENCE.size():
		return 0
	if not FishQualityType.is_valid(fish_catch.quality):
		return 0
	var weight_percentile: float = _get_weight_percentile(fish_catch)
	var weight_multiplier: float = (
		1.0 + MAXIMUM_WEIGHT_BONUS * weight_percentile * weight_percentile
	)
	var catch_experience: int = roundi(
		float(RARITY_BASE_EXPERIENCE[rarity])
		* QUALITY_MULTIPLIERS[fish_catch.quality]
		* weight_multiplier
	)
	var quality_bit: int = FishQualityType.bit_for(fish_catch.quality)
	if not was_species_discovered:
		catch_experience += FIRST_SPECIES_BONUS
	if (previous_quality_mask & quality_bit) == 0:
		catch_experience += FIRST_QUALITY_BONUS
	var next_quality_mask: int = previous_quality_mask | quality_bit
	if (
		previous_quality_mask != FishQualityType.ALL_TIERS_MASK
		and next_quality_mask == FishQualityType.ALL_TIERS_MASK
	):
		catch_experience += SPECIES_MASTERY_BONUS
	return maxi(catch_experience, 0)


static func _get_weight_percentile(fish_catch: FishCatchType) -> float:
	var minimum_weight: float = fish_catch.fish.get_minimum_weight()
	var maximum_weight: float = fish_catch.fish.get_maximum_weight()
	if maximum_weight <= minimum_weight:
		return 0.0
	return clampf(
		inverse_lerp(minimum_weight, maximum_weight, fish_catch.weight_lb),
		0.0,
		1.0,
	)
