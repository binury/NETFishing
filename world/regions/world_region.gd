@tool
class_name WorldRegion
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
	_collect_fishable_water_regions(root, regions)
	return regions


func get_water_recovery_triggers() -> Array[PlayerWaterTrigger]:
	var triggers: Array[PlayerWaterTrigger] = []
	var root: Node = get_node_or_null(water_recovery_root)
	if root == null:
		return triggers
	_collect_water_recovery_triggers(root, triggers)
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


func _collect_fishable_water_regions(
	root: Node,
	regions: Array[FishableWaterRegion],
) -> void:
	for child: Node in root.get_children():
		var water := child as FishableWaterRegion
		if water != null:
			regions.append(water)
		_collect_fishable_water_regions(child, regions)


func _collect_water_recovery_triggers(
	root: Node,
	triggers: Array[PlayerWaterTrigger],
) -> void:
	for child: Node in root.get_children():
		var trigger := child as PlayerWaterTrigger
		if trigger != null:
			triggers.append(trigger)
		_collect_water_recovery_triggers(child, triggers)
