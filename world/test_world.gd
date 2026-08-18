class_name TestWorld
extends Node3D

const FishingShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)
const PlayerStorageInteractionType = preload(
	"res://world/player_storage_interaction.gd"
)

@onready var _regions_root: Node3D = $Regions
@onready var _starter_island: StarterIslandRegion = (
	$Regions/StarterIslandRegion
)
@onready var _below_world_failsafe: PlayerWaterTrigger = (
	$Safety/BelowWorldFailsafe
)
@onready var _fishing_shop: FishingShopInteractionType = (
	_starter_island.get_fishing_shop()
)
@onready var _player_storage: PlayerStorageInteractionType = (
	_starter_island.get_player_storage()
)
@onready var _world_environment: WorldEnvironment = $Environment/WorldEnvironment
@onready var _sun: DirectionalLight3D = $Environment/Sun


func get_player_water_triggers() -> Array[PlayerWaterTrigger]:
	var triggers: Array[PlayerWaterTrigger] = []
	for region: WorldRegion in _get_regions():
		triggers.append_array(region.get_water_recovery_triggers())
	triggers.append(_below_world_failsafe)
	return triggers


func get_safe_respawn_points() -> Array[SafeRespawnPoint]:
	var points: Array[SafeRespawnPoint] = []
	for region: WorldRegion in _get_regions():
		points.append_array(region.get_safe_respawn_points())
	return points


func get_fishing_shop() -> FishingShopInteractionType:
	return _fishing_shop


func get_player_storage() -> PlayerStorageInteractionType:
	return _player_storage


func get_player_spawn_transform() -> Transform3D:
	return _starter_island.get_player_spawn_transform()


func get_world_environment() -> WorldEnvironment:
	return _world_environment


func get_sun() -> DirectionalLight3D:
	return _sun


func set_light_performance_profile(enabled: bool) -> void:
	_starter_island.set_light_performance_profile(enabled)


func get_fishable_water_regions() -> Array[FishableWaterRegion]:
	var waters: Array[FishableWaterRegion] = []
	for region: WorldRegion in _get_regions():
		waters.append_array(region.get_fishable_water_regions())
	return waters


func get_saltwater_shoreline_mesh() -> MeshInstance3D:
	return _starter_island.get_saltwater_shoreline_mesh()


func get_spawn_surface_triangles(
	material_names: Array[StringName],
	minimum_global_y: float,
) -> Array[PackedVector3Array]:
	return _starter_island.get_spawn_surface_triangles(
		material_names,
		minimum_global_y,
	)


func get_diggable_area_triangles(
	area_id: StringName,
) -> Array[PackedVector3Array]:
	for region: WorldRegion in _get_regions():
		var area: DiggableArea3D = region.get_diggable_area(area_id)
		if area != null:
			return area.get_surface_triangles()
	return []


func get_gatherable_spawn_positions(
	anchor_set_id: StringName,
) -> PackedVector3Array:
	for region: WorldRegion in _get_regions():
		var anchor_set: GatherableAnchorSet3D = (
			region.get_gatherable_anchor_set(anchor_set_id)
		)
		if anchor_set != null:
			return anchor_set.get_spawn_positions()
	return PackedVector3Array()


func _get_regions() -> Array[WorldRegion]:
	var regions: Array[WorldRegion] = []
	for child: Node in _regions_root.get_children():
		var region: WorldRegion = child as WorldRegion
		if region != null:
			regions.append(region)
	return regions
