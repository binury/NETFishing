class_name FishQuality
extends RefCounted

enum Tier {
	BORING,
	AVERAGE,
	IMPRESSIVE,
	EXCEPTIONAL,
	SHINY,
}

const TIER_COUNT: int = 5
const ALL_TIERS_MASK: int = (1 << TIER_COUNT) - 1

# Starting distribution. Equipment and tackle can supply per-tier
# multipliers later without changing catch serialization or tier identity.
const BASE_ROLL_WEIGHTS: Array[float] = [40.0, 32.0, 18.0, 8.0, 2.0]
const SALE_MULTIPLIERS: Array[float] = [1.0, 1.1, 1.25, 1.5, 2.0]
const DISPLAY_NAMES: PackedStringArray = [
	"boring",
	"average",
	"impressive",
	"exceptional",
	"shiny",
]


static func is_valid(quality: int) -> bool:
	return quality >= 0 and quality < TIER_COUNT


static func display_name(quality: int) -> String:
	return DISPLAY_NAMES[quality] if is_valid(quality) else "unknown"


static func bit_for(quality: int) -> int:
	return 1 << quality if is_valid(quality) else 0


static func sale_multiplier(quality: int) -> float:
	return SALE_MULTIPLIERS[quality] if is_valid(quality) else 1.0


static func apply_sale_value(base_value: int, quality: int) -> int:
	if base_value <= 0 or not is_valid(quality):
		return maxi(base_value, 0)
	if quality == Tier.BORING:
		return base_value
	return maxi(
		base_value + quality,
		ceili(float(base_value) * sale_multiplier(quality)),
	)


static func roll(
	rng: RandomNumberGenerator,
	weight_multipliers: Array[float] = [],
) -> int:
	if rng == null:
		return Tier.BORING
	var weights: Array[float] = []
	var total_weight: float = 0.0
	for quality: int in TIER_COUNT:
		var multiplier: float = 1.0
		if quality < weight_multipliers.size():
			multiplier = maxf(weight_multipliers[quality], 0.0)
		var weight: float = BASE_ROLL_WEIGHTS[quality] * multiplier
		weights.append(weight)
		total_weight += weight
	if total_weight <= 0.0:
		return Tier.BORING
	var rolled_weight: float = rng.randf() * total_weight
	var accumulated_weight: float = 0.0
	for quality: int in TIER_COUNT:
		accumulated_weight += weights[quality]
		if rolled_weight <= accumulated_weight:
			return quality
	return Tier.SHINY


static func qualified_name(fish_name: String, quality: int) -> String:
	return "%s %s" % [display_name(quality), fish_name]


static func qualified_name_with_article(
	fish_name: String,
	quality: int,
) -> String:
	var quality_name: String = display_name(quality)
	var article: String = "an" if quality_name[0] in ["a", "e", "i", "o", "u"] else "a"
	return "%s %s %s" % [article, quality_name, fish_name]
