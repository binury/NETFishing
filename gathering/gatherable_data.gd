class_name GatherableData
extends Resource

const FishDataType = preload("res://fish/fish_data.gd")
const FishQualityType = preload("res://fish/fish_quality.gd")
const CalendarSeasonType = preload("res://world/calendar_season.gd")

enum PresentationMode {
	VISIBLE_CREATURE,
	WATER_SPURT,
}

@export var type_id: StringName
@export var catch_data: FishDataType
@export var required_tool_id: StringName
@export var surface_materials: Array[StringName] = []
@export var diggable_area_id: StringName
@export var spawn_anchor_set_id: StringName
@export_range(-100.0, 100.0, 0.01) var minimum_surface_y: float = 0.08
@export_range(0, 64, 1) var population: int = 0
@export var presentation_mode: PresentationMode = PresentationMode.VISIBLE_CREATURE
@export var requires_sneaking: bool = true
@export_range(0.0, 120.0, 0.1) var active_lifetime_seconds: float = 0.0
@export_range(0.0, 10.0, 0.05) var movement_speed: float = 0.35
@export_range(0.1, 20.0, 0.1) var roam_radius: float = 3.5
@export_range(0.1, 20.0, 0.1) var scare_radius: float = 2.8
@export var quality_movement_speed_multipliers: Array[float] = [
	1.0,
	1.15,
	1.35,
	1.6,
	2.0,
]
@export var quality_scare_radius_multipliers: Array[float] = [
	1.0,
	1.1,
	1.25,
	1.45,
	1.7,
]
@export_range(0.1, 5.0, 0.05) var capture_radius: float = 0.7
@export_range(0.1, 10.0, 0.05) var interaction_range: float = 2.6
@export_range(0.1, 10.0, 0.05) var charge_duration: float = 2.0
@export_range(0.0001, 0.01, 0.00005) var sprite_pixel_size: float = 0.001
@export_range(-90.0, 90.0, 1.0) var sprite_tilt_degrees: float = -45.0
@export_category("Respawn Budget")
@export_range(0.0, 3600.0, 1.0) var capture_respawn_min_seconds: float = 480.0
@export_range(0.0, 3600.0, 1.0) var capture_respawn_max_seconds: float = 720.0
@export_range(0.0, 3600.0, 1.0) var scare_respawn_min_seconds: float = 45.0
@export_range(0.0, 3600.0, 1.0) var scare_respawn_max_seconds: float = 90.0
@export_range(0.0, 3600.0, 1.0) var minimum_respawn_spacing_seconds: float = 180.0


func is_valid() -> bool:
	var uses_diggable_area: bool = not diggable_area_id.is_empty()
	var uses_spawn_anchors: bool = not spawn_anchor_set_id.is_empty()
	var movement_parameters_valid: bool = (
		movement_speed >= 0.0
		and (
			presentation_mode == PresentationMode.WATER_SPURT
			or (roam_radius > 0.0 and scare_radius > 0.0)
		)
	)
	return (
		not type_id.is_empty()
		and catch_data != null
		and catch_data.is_valid_catalog_entry()
		and catch_data.collection_method != FishDataType.CollectionMethod.FISHING
		and not required_tool_id.is_empty()
		and (
			uses_diggable_area
			or uses_spawn_anchors
			or not surface_materials.is_empty()
		)
		and (
			not uses_diggable_area
			or catch_data.collection_method
			== FishDataType.CollectionMethod.DIGGING
		)
		and population > 0
		and movement_parameters_valid
		and _quality_multipliers_are_valid(
			quality_movement_speed_multipliers
		)
		and _quality_multipliers_are_valid(
			quality_scare_radius_multipliers
		)
		and capture_radius > 0.0
		and interaction_range > 0.0
		and charge_duration > 0.0
		and sprite_pixel_size > 0.0
		and capture_respawn_max_seconds >= capture_respawn_min_seconds
		and scare_respawn_max_seconds >= scare_respawn_min_seconds
	)


func is_stationary_hotspot() -> bool:
	return presentation_mode == PresentationMode.WATER_SPURT


func is_stationary_spawn() -> bool:
	return is_stationary_hotspot() or not spawn_anchor_set_id.is_empty()


func can_be_scared() -> bool:
	return not is_stationary_spawn() and scare_radius > 0.0


func get_movement_speed_for_quality(quality: int) -> float:
	return movement_speed * _quality_multiplier(
		quality_movement_speed_multipliers,
		quality,
	)


func get_scare_radius_for_quality(quality: int) -> float:
	return scare_radius * _quality_multiplier(
		quality_scare_radius_multipliers,
		quality,
	)


func get_respawn_delay(reason: StringName, rng: RandomNumberGenerator) -> float:
	var minimum_seconds: float = capture_respawn_min_seconds
	var maximum_seconds: float = capture_respawn_max_seconds
	if reason == &"scared":
		minimum_seconds = scare_respawn_min_seconds
		maximum_seconds = scare_respawn_max_seconds
	if rng == null or maximum_seconds <= minimum_seconds:
		return minimum_seconds
	return rng.randf_range(minimum_seconds, maximum_seconds)


func is_available(season: int = CalendarSeasonType.UNKNOWN) -> bool:
	return (
		catch_data != null
		and catch_data.active
		and catch_data.is_available_in_season(season)
		and is_valid()
	)


func _quality_multiplier(values: Array[float], quality: int) -> float:
	if values.size() != FishQualityType.TIER_COUNT:
		return 1.0
	var safe_quality: int = (
		quality
		if FishQualityType.is_valid(quality)
		else FishQualityType.Tier.BORING
	)
	return maxf(values[safe_quality], 0.0)


func _quality_multipliers_are_valid(values: Array[float]) -> bool:
	if values.size() != FishQualityType.TIER_COUNT:
		return false
	for multiplier: float in values:
		if not is_finite(multiplier) or multiplier <= 0.0:
			return false
	return true
