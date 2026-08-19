class_name TestWorld
extends Node3D

const FishingShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)
const PlayerStorageInteractionType = preload(
	"res://world/player_storage_interaction.gd"
)

@onready var _regions_root: Node3D = $Regions
@onready var _active_region: WorldRegion = _find_active_region()
@onready var _below_world_failsafe: PlayerWaterTrigger = (
	$Safety/BelowWorldFailsafe
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
	return _active_region.get_fishing_shop()


func get_player_storage() -> PlayerStorageInteractionType:
	return _active_region.get_player_storage()


func get_player_spawn_transform() -> Transform3D:
	return _active_region.get_player_spawn_transform()


func get_world_environment() -> WorldEnvironment:
	return _world_environment


func get_sun() -> DirectionalLight3D:
	return _sun


func set_light_performance_profile(enabled: bool) -> void:
	_active_region.set_light_performance_profile(enabled)


func get_fishable_water_regions() -> Array[FishableWaterRegion]:
	var waters: Array[FishableWaterRegion] = []
	for region: WorldRegion in _get_regions():
		waters.append_array(region.get_fishable_water_regions())
	return waters


func get_saltwater_shoreline_mesh() -> MeshInstance3D:
	return _active_region.get_saltwater_shoreline_mesh()


func get_spawn_surface_triangles(
	material_names: Array[StringName],
	minimum_global_y: float,
) -> Array[PackedVector3Array]:
	return _active_region.get_spawn_surface_triangles(
		material_names,
		minimum_global_y,
	)


func generate_world(seed: int) -> bool:
	if _active_region == null or not _active_region.has_method("generate_world"):
		return false
	var generated: bool = bool(_active_region.call("generate_world", seed))
	if generated:
		_configure_world_coverage()
	return generated


func get_generation_seed() -> int:
	if _active_region != null and _active_region.has_method("get_generation_seed"):
		return int(_active_region.call("get_generation_seed"))
	return PlayerSaveManager.DEFAULT_WORLD_SEED


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


func _ready() -> void:
	_configure_world_coverage()


func _find_active_region() -> WorldRegion:
	for child: Node in _regions_root.get_children():
		var region := child as WorldRegion
		if region != null:
			return region
	return null


func _configure_world_coverage() -> void:
	if _active_region == null:
		return
	var half: Vector2 = _active_region.get_playable_half_extents()
	var wall_margin := 2.0
	var wall_height := 14.0
	var bounds_root := $WorldBounds as Node3D
	var north_south_size := Vector3(
		half.x * 2.0 + wall_margin * 2.0,
		wall_height,
		2.0,
	)
	var east_west_size := Vector3(
		2.0,
		wall_height,
		half.y * 2.0 + wall_margin * 2.0,
	)
	_set_bound(bounds_root.get_node("North"), Vector3(0.0, 5.0, half.y + wall_margin), north_south_size)
	_set_bound(bounds_root.get_node("South"), Vector3(0.0, 5.0, -half.y - wall_margin), north_south_size)
	_set_bound(bounds_root.get_node("West"), Vector3(-half.x - wall_margin, 5.0, 0.0), east_west_size)
	_set_bound(bounds_root.get_node("East"), Vector3(half.x + wall_margin, 5.0, 0.0), east_west_size)
	_below_world_failsafe.position = Vector3(0.0, -7.0, 0.0)
	var coverage := _below_world_failsafe.get_node("Coverage") as CollisionShape3D
	var coverage_shape := coverage.shape as BoxShape3D
	if coverage_shape != null:
		coverage_shape.size = Vector3(half.x * 2.0, 4.0, half.y * 2.0)


func _set_bound(body: Node3D, position: Vector3, size: Vector3) -> void:
	body.position = position
	var collision := body.get_node("Shape") as CollisionShape3D
	var shape := collision.shape as BoxShape3D
	if shape != null:
		shape.size = size
