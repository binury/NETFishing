class_name TestWorld
extends Node3D

const FishingShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)

@onready var _regions_root: Node3D = $Regions
@onready var _below_world_failsafe: PlayerWaterTrigger = (
	$Safety/BelowWorldFailsafe
)
@onready var _fishing_shop: FishingShopInteractionType = (
	$Regions/VillageRegion/Interactables/FishingShopWorld/FishingShopInteraction
)


func get_player_water_triggers() -> Array[PlayerWaterTrigger]:
	var triggers: Array[PlayerWaterTrigger] = []
	for region: GrayboxRegion in _get_regions():
		triggers.append_array(region.get_water_recovery_triggers())
	triggers.append(_below_world_failsafe)
	return triggers


func get_safe_respawn_points() -> Array[SafeRespawnPoint]:
	var points: Array[SafeRespawnPoint] = []
	for region: GrayboxRegion in _get_regions():
		points.append_array(region.get_safe_respawn_points())
	return points


func get_fishing_shop() -> FishingShopInteractionType:
	return _fishing_shop


func get_fishable_water_regions() -> Array[FishableWaterRegion]:
	var waters: Array[FishableWaterRegion] = []
	for region: GrayboxRegion in _get_regions():
		waters.append_array(region.get_fishable_water_regions())
	return waters


func get_pelican_convenience_landmark() -> Node3D:
	return (
		$Regions/VillageRegion/Interactables/PelicanCoolerPerch
		as Node3D
	)


func _get_regions() -> Array[GrayboxRegion]:
	var regions: Array[GrayboxRegion] = []
	for child: Node in _regions_root.get_children():
		var region: GrayboxRegion = child as GrayboxRegion
		if region != null:
			regions.append(region)
	return regions
