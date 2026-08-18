@tool
class_name WorldRegion
extends Node3D

@export var region_id: StringName
@export var fishable_water_root: NodePath = ^"FishingWater"
@export var water_recovery_root: NodePath = ^"WaterRecovery"
@export var safe_respawns_root: NodePath = ^"SafeRespawns"
@export var diggable_area_root: NodePath = ^"DiggableAreas"
@export var gatherable_anchor_root: NodePath = ^"GatherableAnchors"


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


func get_diggable_areas() -> Array[DiggableArea3D]:
	var areas: Array[DiggableArea3D] = []
	var root: Node = get_node_or_null(diggable_area_root)
	if root == null:
		return areas
	_collect_diggable_areas(root, areas)
	return areas


func get_diggable_area(area_id: StringName) -> DiggableArea3D:
	if area_id.is_empty():
		return null
	for area: DiggableArea3D in get_diggable_areas():
		if area.area_id == area_id:
			return area
	return null


func get_gatherable_anchor_sets() -> Array[GatherableAnchorSet3D]:
	var anchor_sets: Array[GatherableAnchorSet3D] = []
	var root: Node = get_node_or_null(gatherable_anchor_root)
	if root == null:
		return anchor_sets
	_collect_gatherable_anchor_sets(root, anchor_sets)
	return anchor_sets


func get_gatherable_anchor_set(
	anchor_set_id: StringName,
) -> GatherableAnchorSet3D:
	if anchor_set_id.is_empty():
		return null
	for anchor_set: GatherableAnchorSet3D in get_gatherable_anchor_sets():
		if anchor_set.anchor_set_id == anchor_set_id:
			return anchor_set
	return null


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


func _collect_diggable_areas(
	root: Node,
	areas: Array[DiggableArea3D],
) -> void:
	for child: Node in root.get_children():
		var area := child as DiggableArea3D
		if area != null:
			areas.append(area)
		_collect_diggable_areas(child, areas)


func _collect_gatherable_anchor_sets(
	root: Node,
	anchor_sets: Array[GatherableAnchorSet3D],
) -> void:
	for child: Node in root.get_children():
		var anchor_set := child as GatherableAnchorSet3D
		if anchor_set != null:
			anchor_sets.append(anchor_set)
		_collect_gatherable_anchor_sets(child, anchor_sets)
