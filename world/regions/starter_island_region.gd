class_name StarterIslandRegion
extends GrayboxRegion

const FishingShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)

@export var visual_mesh_path: NodePath = (
	^"Visuals/StarterIslandModel/starter_island"
)
@export var terrain_collision_shape_path: NodePath = (
	^"StaticCollision/Terrain/Shape"
)
@export var player_spawn_path: NodePath = ^"PlayerSpawn"
@export var fishing_shop_path: NodePath = (
	^"Interactables/FishingShopWorld/FishingShopInteraction"
)
@export var pelican_landmark_path: NodePath = (
	^"Interactables/PelicanCoolerPerch"
)


func _ready() -> void:
	_build_terrain_collision()


func get_player_spawn_transform() -> Transform3D:
	var spawn: Marker3D = get_node_or_null(player_spawn_path) as Marker3D
	return spawn.global_transform if spawn != null else global_transform


func get_fishing_shop() -> FishingShopInteractionType:
	return get_node_or_null(fishing_shop_path) as FishingShopInteractionType


func get_pelican_landmark() -> Node3D:
	return get_node_or_null(pelican_landmark_path) as Node3D


func has_terrain_collision() -> bool:
	var collision_shape: CollisionShape3D = (
		get_node_or_null(terrain_collision_shape_path) as CollisionShape3D
	)
	return collision_shape != null and collision_shape.shape != null


func _build_terrain_collision() -> void:
	var visual_mesh: MeshInstance3D = (
		get_node_or_null(visual_mesh_path) as MeshInstance3D
	)
	var collision_shape: CollisionShape3D = (
		get_node_or_null(terrain_collision_shape_path) as CollisionShape3D
	)
	if visual_mesh == null or visual_mesh.mesh == null:
		push_error("Starter island visual mesh is unavailable.")
		return
	if collision_shape == null:
		push_error("Starter island collision owner is unavailable.")
		return
	var terrain_shape: ConcavePolygonShape3D = (
		visual_mesh.mesh.create_trimesh_shape()
	)
	if terrain_shape == null or terrain_shape.get_faces().is_empty():
		push_error("Starter island terrain collision could not be created.")
		return
	collision_shape.shape = terrain_shape
