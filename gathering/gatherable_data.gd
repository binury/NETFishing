class_name GatherableData
extends Resource

const FishDataType = preload("res://fish/fish_data.gd")

@export var type_id: StringName
@export var catch_data: FishDataType
@export var required_tool_id: StringName
@export var surface_materials: Array[StringName] = []
@export_range(-100.0, 100.0, 0.01) var minimum_surface_y: float = 0.08
@export_range(0, 64, 1) var population: int = 0
@export_range(0.0, 10.0, 0.05) var movement_speed: float = 0.35
@export_range(0.1, 20.0, 0.1) var roam_radius: float = 3.5
@export_range(0.1, 20.0, 0.1) var scare_radius: float = 2.8
@export_range(0.1, 5.0, 0.05) var capture_radius: float = 0.7
@export_range(0.1, 10.0, 0.05) var interaction_range: float = 2.6
@export_range(0.1, 10.0, 0.05) var charge_duration: float = 2.0
@export_range(0.1, 5.0, 0.01) var sprite_pixel_size: float = 0.001
@export_range(-90.0, 90.0, 1.0) var sprite_tilt_degrees: float = -45.0
@export_category("Respawn Budget")
@export_range(0.0, 3600.0, 1.0) var capture_respawn_min_seconds: float = 480.0
@export_range(0.0, 3600.0, 1.0) var capture_respawn_max_seconds: float = 720.0
@export_range(0.0, 3600.0, 1.0) var scare_respawn_min_seconds: float = 45.0
@export_range(0.0, 3600.0, 1.0) var scare_respawn_max_seconds: float = 90.0
@export_range(0.0, 3600.0, 1.0) var minimum_respawn_spacing_seconds: float = 180.0


func is_valid() -> bool:
	return (
		not type_id.is_empty()
		and catch_data != null
		and catch_data.is_valid_catalog_entry()
		and catch_data.collection_method != FishDataType.CollectionMethod.FISHING
		and not required_tool_id.is_empty()
		and not surface_materials.is_empty()
		and population > 0
		and movement_speed >= 0.0
		and roam_radius > 0.0
		and scare_radius > 0.0
		and capture_radius > 0.0
		and interaction_range > 0.0
		and charge_duration > 0.0
		and sprite_pixel_size > 0.0
		and capture_respawn_max_seconds >= capture_respawn_min_seconds
		and scare_respawn_max_seconds >= scare_respawn_min_seconds
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


func is_available() -> bool:
	return catch_data != null and catch_data.active and is_valid()
