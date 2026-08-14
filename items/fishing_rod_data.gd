class_name FishingRodData
extends ItemData

const FishDataType = preload("res://fish/fish_data.gd")
const FishingContextType = preload("res://fishing/fishing_context.gd")

enum TimeAffinity {
	ANY,
	DAY,
	NIGHT,
}

enum WeatherAffinity {
	ANY,
	RAIN,
	FOG,
}

const MULTIPLIER_COUNT: int = 5

@export_category("Rod Shop")
@export var shop_enabled: bool = true
@export_range(1, 999, 1) var shop_order: int = 1
@export_range(0, 1000000, 1) var shop_price: int = 0
@export_range(1, 100000, 1) var unlock_level: int = 1

@export_category("Rod Presentation")
## Optional authored visual. A null scene deliberately uses the current
## temporary rod mesh so new rod data never requires a model to function.
@export var rod_model_scene: PackedScene
@export var rod_model_transform: Transform3D = Transform3D.IDENTITY
@export var rod_tip_position := Vector3(0.0, 1.1, 0.0)

@export_category("Rod Affinity")
@export var preferred_location_tags: Array[StringName] = []
@export var preferred_collection_groups: Array[StringName] = []
@export var time_affinity: TimeAffinity = TimeAffinity.ANY
@export var weather_affinity: WeatherAffinity = WeatherAffinity.ANY
@export_range(0.0, 10.0, 0.01) var affinity_weight_multiplier: float = 1.0
@export_range(0.0, 10.0, 0.01) var undiscovered_weight_multiplier: float = 1.0

@export_category("Rod Catch Modifiers")
@export_range(-0.5, 0.5, 0.01) var weight_roll_bias: float = 0.0
@export_range(0.05, 5.0, 0.01) var bite_time_multiplier: float = 1.0
@export_range(0.05, 5.0, 0.01) var reel_speed_multiplier: float = 1.0
@export_range(0.05, 5.0, 0.01) var barrier_power_multiplier: float = 1.0
@export var rarity_weight_multipliers: Array[float] = [
	1.0, 1.0, 1.0, 1.0, 1.0,
]
@export var quality_weight_multipliers: Array[float] = [
	1.0, 1.0, 1.0, 1.0, 1.0,
]
@export_multiline var effect_summary: String
@export_multiline var tradeoff: String


func is_valid() -> bool:
	return (
		super.is_valid()
		and category == Category.ROD
		and shop_order >= 1
		and shop_price >= 0
		and unlock_level >= 1
		and rarity_weight_multipliers.size() == MULTIPLIER_COUNT
		and quality_weight_multipliers.size() == MULTIPLIER_COUNT
		and _multipliers_are_non_negative(rarity_weight_multipliers)
		and _multipliers_are_non_negative(quality_weight_multipliers)
		and affinity_weight_multiplier >= 0.0
		and undiscovered_weight_multiplier >= 0.0
		and bite_time_multiplier > 0.0
		and reel_speed_multiplier > 0.0
		and barrier_power_multiplier > 0.0
	)


func is_shop_available() -> bool:
	return is_available() and shop_enabled and icon != null


func get_affinity_multiplier(
	fish: FishDataType,
	context: FishingContextType,
) -> float:
	if fish == null or context == null or not _has_authored_affinity():
		return 1.0
	if (
		not preferred_location_tags.is_empty()
		and not _has_any_match(
			preferred_location_tags,
			context.location_tags,
		)
	):
		return 1.0
	if (
		not preferred_collection_groups.is_empty()
		and fish.collection_group not in preferred_collection_groups
	):
		return 1.0
	match time_affinity:
		TimeAffinity.DAY:
			if context.is_night or context.is_day_night_transition:
				return 1.0
		TimeAffinity.NIGHT:
			if not context.is_night or context.is_day_night_transition:
				return 1.0
	match weather_affinity:
		WeatherAffinity.RAIN:
			if not context.is_raining:
				return 1.0
		WeatherAffinity.FOG:
			if not context.is_foggy:
				return 1.0
	return maxf(affinity_weight_multiplier, 0.0)


func get_rarity_multiplier(rarity: int) -> float:
	if rarity < 0 or rarity >= rarity_weight_multipliers.size():
		return 1.0
	return maxf(rarity_weight_multipliers[rarity], 0.0)


func get_quality_multiplier(quality: int) -> float:
	if quality < 0 or quality >= quality_weight_multipliers.size():
		return 1.0
	return maxf(quality_weight_multipliers[quality], 0.0)


func _has_authored_affinity() -> bool:
	return (
		not preferred_location_tags.is_empty()
		or not preferred_collection_groups.is_empty()
		or time_affinity != TimeAffinity.ANY
		or weather_affinity != WeatherAffinity.ANY
	)


func _has_any_match(
	expected: Array[StringName],
	actual: Array[StringName],
) -> bool:
	for value: StringName in expected:
		if value in actual:
			return true
	return false


func _multipliers_are_non_negative(values: Array[float]) -> bool:
	for value: float in values:
		if not is_finite(value) or value < 0.0:
			return false
	return true
