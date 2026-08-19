class_name FishData
extends Resource

# Fish are displayed by their physical weight, rather than by per-species
# texture or resource dimensions.  A cube-root curve approximates the way a
# fish's linear dimensions grow with mass while keeping large catches readable
# beside the player.
const DISPLAY_REFERENCE_WEIGHT_LB: float = 1.0
const DISPLAY_REFERENCE_SCALE: float = 0.85
const DISPLAY_WEIGHT_EXPONENT: float = 0.33333334
const DISPLAY_MIN_SCALE: float = 0.45
const DISPLAY_MAX_SCALE: float = 3.0

const CatchDifficultyProfileType = preload(
	"res://fishing/catch_difficulty_profile.gd"
)
const FishAvailabilityType = preload("res://fish/fish_availability.gd")
const CalendarSeasonType = preload("res://world/calendar_season.gd")

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

enum CollectionMethod {
	FISHING,
	NET,
	DIGGING,
}

enum LogbookSection {
	AUTOMATIC,
	SHELLFISH,
}

@export var id: StringName
@export var display_name: String
@export_category("Developer Catalog")
## Disabled species remain resolvable for saves but cannot be newly selected.
@export var active: bool = true
@export_range(1, 999999, 1) var catalog_number: int = 1
@export var collection_group: StringName
@export_multiline var logbook_fact: String
@export var collection_method: CollectionMethod = CollectionMethod.FISHING
@export var logbook_section: LogbookSection = LogbookSection.AUTOMATIC
@export var habitat_label: String = ""
@export_flags("Spring", "Summer", "Fall", "Winter")
var available_seasons: int = CalendarSeasonType.ALL_MASK
@export_category("Fishing")
@export_flags("Fresh Water", "Salt Water")
var allowed_water_types: int = WaterType.ALL_FISHABLE_MASK
@export var rarity: Rarity = Rarity.COMMON
@export_range(0.0, 1000.0, 0.01) var base_catch_weight: float = 1.0
@export var catch_profile: CatchDifficultyProfileType
@export var availability: FishAvailabilityType
@export_range(0.001, 500000.0, 0.001) var weight_min_lb: float = 0.5
@export_range(0.001, 500000.0, 0.001) var weight_max_lb: float = 1.0
# Retained in resource files for compatibility with existing authored data;
# runtime presentation is derived from absolute weight below.
@export_range(0.01, 20.0, 0.01) var display_scale_min: float = 0.8
@export_range(0.01, 20.0, 0.01) var display_scale_max: float = 1.2
@export_range(0.01, 10.0, 0.01) var display_scale_curve: float = 1.0
@export_range(0, 1000000, 1) var sell_value_min: int = 0
@export_range(0, 1000000, 1) var sell_value_max: int = 1
@export_range(0.01, 10.0, 0.01) var sell_value_curve: float = 1.0
@export var display_texture: Texture2D


func is_selectable() -> bool:
	return active and is_valid_catalog_entry()


func is_valid_catalog_entry() -> bool:
	return (
		not id.is_empty()
		and base_catch_weight > 0.0
		and catch_profile != null
		and weight_min_lb > 0.0
		and weight_max_lb >= weight_min_lb
		and display_scale_min > 0.0
		and display_scale_max >= display_scale_min
		and display_scale_curve > 0.0
		and sell_value_min >= 0
		and sell_value_max >= sell_value_min
		and sell_value_curve > 0.0
		and CalendarSeasonType.is_valid_mask(available_seasons)
	)


func is_fishable() -> bool:
	return is_selectable() and collection_method == CollectionMethod.FISHING


func get_habitat_label() -> String:
	if not habitat_label.strip_edges().is_empty():
		return habitat_label.strip_edges().to_lower()
	return WaterType.label(get_primary_water_type()).to_lower()


func is_allowed_in_water(type: WaterType.Type) -> bool:
	return (allowed_water_types & WaterType.mask_for(type)) != 0


func is_available_in_season(season: int) -> bool:
	return CalendarSeasonType.includes(available_seasons, season)


func get_season_text() -> String:
	return CalendarSeasonType.format_mask(available_seasons)


func get_primary_water_type() -> WaterType.Type:
	if allowed_water_types & WaterType.FRESH_WATER_MASK:
		return WaterType.Type.FRESH_WATER
	if allowed_water_types & WaterType.SALT_WATER_MASK:
		return WaterType.Type.SALT_WATER
	return WaterType.Type.OTHER


func get_minimum_weight() -> float:
	return maxf(weight_min_lb, 0.001)


func get_maximum_weight() -> float:
	return maxf(weight_max_lb, get_minimum_weight())


func get_weight_percentile(weight_lb: float) -> float:
	var minimum_weight: float = get_minimum_weight()
	var maximum_weight: float = get_maximum_weight()
	if maximum_weight <= minimum_weight:
		return 0.0
	return clampf(
		inverse_lerp(minimum_weight, maximum_weight, weight_lb),
		0.0,
		1.0,
	)


func get_display_scale_for_weight(weight_lb: float) -> float:
	var safe_weight_lb: float = maxf(weight_lb, 0.01)
	var weight_ratio: float = safe_weight_lb / DISPLAY_REFERENCE_WEIGHT_LB
	var weight_scale: float = DISPLAY_REFERENCE_SCALE * pow(
		weight_ratio,
		DISPLAY_WEIGHT_EXPONENT,
	)
	return clampf(weight_scale, DISPLAY_MIN_SCALE, DISPLAY_MAX_SCALE)


func get_sale_value_for_weight(weight_lb: float) -> int:
	var minimum_value: int = maxi(sell_value_min, 0)
	var maximum_value: int = maxi(sell_value_max, minimum_value)
	var normalized_weight: float = 0.0
	var minimum_weight: float = get_minimum_weight()
	var maximum_weight: float = get_maximum_weight()
	if maximum_weight > minimum_weight:
		normalized_weight = inverse_lerp(
			minimum_weight,
			maximum_weight,
			weight_lb
		)
	normalized_weight = pow(
		clampf(normalized_weight, 0.0, 1.0),
		maxf(sell_value_curve, 0.01)
	)
	return clampi(
		roundi(lerpf(minimum_value, maximum_value, normalized_weight)),
		minimum_value,
		maximum_value
	)


func get_rarity_name() -> String:
	return Rarity.keys()[rarity].to_lower()
