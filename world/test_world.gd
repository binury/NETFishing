class_name TestWorld
extends Node3D

const FishingShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)
const PlayerStorageInteractionType = preload(
	"res://world/player_storage_interaction.gd"
)
const WorldLayoutType = preload("res://world/world_layout.gd")
const GENERATED_REGION_SCENE: PackedScene = preload(
	"res://world/generation/generated_world_region.tscn"
)
const STARTER_ISLAND_REGION_SCENE: PackedScene = preload(
	"res://world/regions/starter_island_region.tscn"
)
## Keep the player boundary beyond the longest fishing cast. The boundary is
## solid terrain to character movement and therefore also blocks cast-arc
## probes when it sits directly against the authored shoreline.
const WORLD_BOUNDARY_SHORELINE_CLEARANCE := 18.0

@onready var _regions_root: Node3D = $Regions
@onready var _active_region: WorldRegion = _find_active_region()
@onready var _below_world_failsafe: PlayerWaterTrigger = (
	$Safety/BelowWorldFailsafe
)
@onready var _world_environment: WorldEnvironment = $Environment/WorldEnvironment
@onready var _sun: DirectionalLight3D = $Environment/Sun

var _world_layout: StringName = WorldLayoutType.GENERATED
var _world_seed: int = PlayerSaveManager.DEFAULT_WORLD_SEED
var _light_performance_profile: bool = false


func get_player_water_triggers() -> Array[PlayerWaterTrigger]:
	var triggers: Array[PlayerWaterTrigger] = []
	if _active_region != null:
		triggers.append_array(_active_region.get_water_recovery_triggers())
	triggers.append(_below_world_failsafe)
	return triggers


func get_safe_respawn_points() -> Array[SafeRespawnPoint]:
	return (
		_active_region.get_safe_respawn_points()
		if _active_region != null
		else []
	)


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
	_light_performance_profile = enabled
	if _active_region != null:
		_active_region.set_light_performance_profile(enabled)


func get_fishable_water_regions() -> Array[FishableWaterRegion]:
	return (
		_active_region.get_fishable_water_regions()
		if _active_region != null
		else []
	)


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


func activate_world(layout: StringName, seed: int) -> bool:
	if (
		not WorldLayoutType.is_valid(layout)
		or seed <= 0
		or seed > PlayerSaveManager.MAX_WORLD_SEED
	):
		return false
	if _active_region == null or _active_region.region_id != layout:
		if not _replace_active_region(layout, seed):
			return false
	_world_layout = layout
	_world_seed = seed
	if layout == WorldLayoutType.GENERATED:
		if not _active_region.has_method("generate_world"):
			return false
		if not bool(_active_region.call("generate_world", seed)):
			return false
	_configure_world_coverage()
	return true


func generate_world(seed: int) -> bool:
	return activate_world(WorldLayoutType.GENERATED, seed)


func get_world_layout() -> StringName:
	return _world_layout


func get_generation_seed() -> int:
	return _world_seed


func get_diggable_area_triangles(
	area_id: StringName,
) -> Array[PackedVector3Array]:
	if _active_region != null:
		var area: DiggableArea3D = _active_region.get_diggable_area(area_id)
		if area != null:
			return area.get_surface_triangles()
	return []


func get_gatherable_spawn_positions(
	anchor_set_id: StringName,
) -> PackedVector3Array:
	if _active_region != null:
		var anchor_set: GatherableAnchorSet3D = (
			_active_region.get_gatherable_anchor_set(anchor_set_id)
		)
		if anchor_set != null:
			return anchor_set.get_spawn_positions()
	return PackedVector3Array()


func _ready() -> void:
	if _active_region != null:
		_world_layout = _active_region.region_id
	_configure_world_coverage()


func _find_active_region() -> WorldRegion:
	for child: Node in _regions_root.get_children():
		var region := child as WorldRegion
		if region != null:
			return region
	return null


func _replace_active_region(layout: StringName, seed: int) -> bool:
	var region_scene: PackedScene = (
		GENERATED_REGION_SCENE
		if layout == WorldLayoutType.GENERATED
		else STARTER_ISLAND_REGION_SCENE
	)
	var replacement := region_scene.instantiate() as WorldRegion
	if replacement == null:
		return false
	if layout == WorldLayoutType.GENERATED:
		replacement.set("initial_seed", seed)
	if _active_region != null:
		_regions_root.remove_child(_active_region)
		_active_region.free()
	_active_region = replacement
	_regions_root.add_child(_active_region)
	_active_region.set_light_performance_profile(_light_performance_profile)
	return true


func _configure_world_coverage() -> void:
	if _active_region == null:
		return
	var half: Vector2 = _active_region.get_playable_half_extents()
	var wall_margin := WORLD_BOUNDARY_SHORELINE_CLEARANCE
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
