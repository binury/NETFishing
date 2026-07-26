class_name GrayboxRegion
extends Node3D

@export var region_id: StringName
@export var fishable_water_root: NodePath = ^"FishingWater"
@export var water_recovery_root: NodePath = ^"WaterRecovery"
@export var safe_respawns_root: NodePath = ^"SafeRespawns"


func get_fishable_water_regions() -> Array[FishableWaterRegion]:
	var regions: Array[FishableWaterRegion] = []
	var root: Node = get_node_or_null(fishable_water_root)
	if root == null:
		return regions
	for child: Node in root.get_children():
		var water: FishableWaterRegion = child as FishableWaterRegion
		if water != null:
			regions.append(water)
	return regions


func get_water_recovery_triggers() -> Array[PlayerWaterTrigger]:
	var triggers: Array[PlayerWaterTrigger] = []
	var root: Node = get_node_or_null(water_recovery_root)
	if root == null:
		return triggers
	for child: Node in root.get_children():
		var trigger: PlayerWaterTrigger = child as PlayerWaterTrigger
		if trigger != null:
			triggers.append(trigger)
	return triggers


func get_safe_respawn_points() -> Array[SafeRespawnPoint]:
	var points: Array[SafeRespawnPoint] = []
	var root: Node = get_node_or_null(safe_respawns_root)
	if root == null:
		return points
	for child: Node in root.get_children():
		var point: SafeRespawnPoint = child as SafeRespawnPoint
		if point != null:
			points.append(point)
	return points
