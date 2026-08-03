class_name TestWorld
extends Node3D

const FishingShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
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


func get_player_spawn_transform() -> Transform3D:
	return _starter_island.get_player_spawn_transform()


func get_world_environment() -> WorldEnvironment:
	return _world_environment


func get_sun() -> DirectionalLight3D:
	return _sun


func get_fishable_water_regions() -> Array[FishableWaterRegion]:
	var waters: Array[FishableWaterRegion] = []
	for region: WorldRegion in _get_regions():
		waters.append_array(region.get_fishable_water_regions())
	return waters


func get_pelican_convenience_landmark() -> Node3D:
	return _starter_island.get_pelican_landmark()


func get_saltwater_shoreline_mesh() -> MeshInstance3D:
	return _starter_island.get_saltwater_shoreline_mesh()


func _get_regions() -> Array[WorldRegion]:
	var regions: Array[WorldRegion] = []
	for child: Node in _regions_root.get_children():
		var region: WorldRegion = child as WorldRegion
		if region != null:
			regions.append(region)
	return regions
