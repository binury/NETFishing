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
const WORM_ROLL_WEIGHTS: Array[float] = [80.0, 10.0, 5.0, 4.0, 1.0]
const SNAIL_ROLL_WEIGHTS: Array[float] = [68.0, 16.0, 8.0, 6.0, 2.0]
const SHRIMP_ROLL_WEIGHTS: Array[float] = [56.0, 21.0, 12.0, 8.0, 3.0]
const SQUID_ROLL_WEIGHTS: Array[float] = [44.0, 25.0, 16.0, 11.0, 4.0]
const MINNOW_ROLL_WEIGHTS: Array[float] = [34.0, 27.0, 20.0, 13.0, 6.0]
const SARDINE_ROLL_WEIGHTS: Array[float] = [25.0, 28.0, 23.0, 16.0, 8.0]
const LUMINOUS_ROE_ROLL_WEIGHTS: Array[float] = [16.0, 26.0, 26.0, 20.0, 12.0]
const SALE_MULTIPLIERS: Array[float] = [1.0, 1.1, 1.25, 1.5, 2.0]
# Legacy profile multiplier retained for serialized/profile compatibility.
# New encounters use the weighted quality/rarity/weight bands below.
const BARRIER_HEALTH_MULTIPLIERS: Array[float] = [1.0, 1.25, 1.6, 2.2, 3.25]
# Barrier health is weighted 70% by quality, 20% by rarity, and 10% by the
# catch's position in its authored weight range.  The upper bounds define the
# intended per-barrier challenge bands; a small seeded variance keeps barriers
# from feeling identical without crossing those bands.
const BARRIER_QUALITY_WEIGHT: float = 0.70
const BARRIER_RARITY_WEIGHT: float = 0.20
const BARRIER_WEIGHT_WEIGHT: float = 0.10
const BARRIER_HEALTH_MINIMUMS: Array[int] = [1, 10, 50, 100, 200]
const BARRIER_HEALTH_MAXIMUMS: Array[int] = [9, 50, 100, 200, 400]
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


static func barrier_health_multiplier(quality: int) -> float:
	return (
		BARRIER_HEALTH_MULTIPLIERS[quality]
		if is_valid(quality)
		else BARRIER_HEALTH_MULTIPLIERS[Tier.BORING]
	)


static func apply_barrier_health(base_health: int, quality: int) -> int:
	return maxi(
		ceili(
			float(maxi(base_health, 1))
			* barrier_health_multiplier(quality)
		),
		1,
	)


static func barrier_health_for_catch(
	quality: int,
	rarity: int,
	weight_percentile: float,
	variance: float = 1.0,
) -> int:
	var safe_quality: int = (
		quality if is_valid(quality) else Tier.BORING
	)
	var safe_rarity: float = clampf(float(rarity) / 4.0, 0.0, 1.0)
	var safe_weight: float = clampf(weight_percentile, 0.0, 1.0)
	var weighted_health: float = float(BARRIER_HEALTH_MAXIMUMS[safe_quality]) * (
		BARRIER_QUALITY_WEIGHT
		+ BARRIER_RARITY_WEIGHT * safe_rarity
		+ BARRIER_WEIGHT_WEIGHT * safe_weight
	)
	var varied_health: int = roundi(
		weighted_health * clampf(variance, 0.8, 1.2)
	)
	return clampi(
		varied_health,
		BARRIER_HEALTH_MINIMUMS[safe_quality],
		BARRIER_HEALTH_MAXIMUMS[safe_quality],
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


static func roll_weights_for_bait(active_bait_tags: Array[StringName]) -> Array[float]:
	var bait_weights: Array[float] = rarity_weights_for_bait(active_bait_tags)
	var weights: Array[float] = []
	for quality: int in TIER_COUNT:
		weights.append(bait_weights[quality] / BASE_ROLL_WEIGHTS[quality])
	return weights


static func rarity_weights_for_bait(
	active_bait_tags: Array[StringName],
) -> Array[float]:
	var weights: Array[float] = []
	if active_bait_tags.is_empty():
		weights.assign([100.0, 0.0, 0.0, 0.0, 0.0])
	elif active_bait_tags.has(&"bait_rarity_6"):
		weights.assign(LUMINOUS_ROE_ROLL_WEIGHTS)
	elif active_bait_tags.has(&"bait_rarity_5"):
		weights.assign(SARDINE_ROLL_WEIGHTS)
	elif active_bait_tags.has(&"bait_rarity_4"):
		weights.assign(MINNOW_ROLL_WEIGHTS)
	elif active_bait_tags.has(&"bait_rarity_3"):
		weights.assign(SQUID_ROLL_WEIGHTS)
	elif active_bait_tags.has(&"bait_rarity_2"):
		weights.assign(SHRIMP_ROLL_WEIGHTS)
	elif active_bait_tags.has(&"bait_rarity_1"):
		weights.assign(SNAIL_ROLL_WEIGHTS)
	else:
		# Unknown and legacy bait tags retain the original worms behavior.
		weights.assign(WORM_ROLL_WEIGHTS)
	return weights


static func qualified_name(fish_name: String, quality: int) -> String:
	return "%s %s" % [display_name(quality), fish_name]


static func qualified_name_with_article(
	fish_name: String,
	quality: int,
) -> String:
	var quality_name: String = display_name(quality)
	var article: String = "an" if quality_name[0] in ["a", "e", "i", "o", "u"] else "a"
	return "%s %s %s" % [article, quality_name, fish_name]
