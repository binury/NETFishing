class_name FishData
extends Resource

const CatchDifficultyProfileType = preload(
	"res://fishing/catch_difficulty_profile.gd"
)
const FishAvailabilityType = preload("res://fish/fish_availability.gd")

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	EPIC,
	LEGENDARY,
}

@export var id: StringName
@export var display_name: String
@export var rarity: Rarity = Rarity.COMMON
@export_range(0.0, 1000.0, 0.01) var base_catch_weight: float = 1.0
@export var catch_profile: CatchDifficultyProfileType
@export var availability: FishAvailabilityType
@export_range(0.01, 1000.0, 0.01) var weight_min_lb: float = 0.5
@export_range(0.01, 1000.0, 0.01) var weight_max_lb: float = 1.0
@export_range(0.01, 20.0, 0.01) var display_scale_min: float = 0.8
@export_range(0.01, 20.0, 0.01) var display_scale_max: float = 1.2
@export_range(0.01, 10.0, 0.01) var display_scale_curve: float = 1.0
@export_range(0, 1000000, 1) var sell_value_min: int = 0
@export_range(0, 1000000, 1) var sell_value_max: int = 1
@export_range(0.01, 10.0, 0.01) var sell_value_curve: float = 1.0
@export var display_texture: Texture2D


func is_selectable() -> bool:
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
	)


func get_minimum_weight() -> float:
	return maxf(weight_min_lb, 0.01)


func get_maximum_weight() -> float:
	return maxf(weight_max_lb, get_minimum_weight())


func get_display_scale_for_weight(weight_lb: float) -> float:
	var minimum_weight: float = get_minimum_weight()
	var maximum_weight: float = get_maximum_weight()
	var normalized_weight: float = 0.0
	if maximum_weight > minimum_weight:
		normalized_weight = inverse_lerp(
			minimum_weight,
			maximum_weight,
			weight_lb
		)
	normalized_weight = pow(
		clampf(normalized_weight, 0.0, 1.0),
		maxf(display_scale_curve, 0.01)
	)
	var minimum_scale: float = maxf(display_scale_min, 0.01)
	var maximum_scale: float = maxf(display_scale_max, minimum_scale)
	return lerpf(minimum_scale, maximum_scale, normalized_weight)


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
