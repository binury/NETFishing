@tool
class_name StarterIslandRegion
extends WorldRegion

const FishingShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)

@export_group("Owned Nodes")
@export_node_path("MeshInstance3D")
var visual_mesh_path: NodePath = (
	^"Terrain/Visual/starter_island"
)
@export_node_path("CollisionShape3D")
var terrain_collision_shape_path: NodePath = (
	^"Terrain/Collision/Shape"
)
@export_node_path("Marker3D")
var player_spawn_path: NodePath = ^"PlayerSpawn"
@export_node_path("Area3D")
var fishing_shop_path: NodePath = (
	^"Interactables/FishingShopWorld/InteractionArea"
)
@export_node_path("Node3D")
var pelican_landmark_path: NodePath = (
	^"Interactables/PelicanCoolerPerch"
)

@export_group("Grass Surface")
@export var grass_material: Material
@export_range(0, 16, 1) var grass_surface_index: int = 0


func _ready() -> void:
	_apply_grass_material()
	_build_terrain_collision()
	if Engine.is_editor_hint():
		update_configuration_warnings()


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


func _apply_grass_material() -> void:
	var visual_mesh: MeshInstance3D = (
		get_node_or_null(visual_mesh_path) as MeshInstance3D
	)
	if visual_mesh == null or visual_mesh.mesh == null:
		push_error("Starter island visual mesh is unavailable.")
		return
	if grass_material == null:
		push_error("Starter island grass material is unavailable.")
		return
	if grass_surface_index >= visual_mesh.mesh.get_surface_count():
		push_error("Starter island grass surface index is invalid.")
		return
	if visual_mesh.mesh.surface_get_name(grass_surface_index) != "grass":
		push_error("Starter island grass surface name does not match.")
		return
	visual_mesh.set_surface_override_material(
		grass_surface_index,
		grass_material
	)


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


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var visual_mesh := get_node_or_null(visual_mesh_path) as MeshInstance3D
	if visual_mesh == null or visual_mesh.mesh == null:
		warnings.append("Terrain/Visual must provide the island mesh.")
	elif grass_surface_index >= visual_mesh.mesh.get_surface_count():
		warnings.append("Grass surface index is outside the terrain mesh.")
	elif visual_mesh.mesh.surface_get_name(grass_surface_index) != "grass":
		warnings.append("Grass surface index must identify the grass surface.")
	if grass_material == null:
		warnings.append("Assign the starter-island grass material.")
	if get_node_or_null(terrain_collision_shape_path) == null:
		warnings.append("Terrain/Collision must provide a collision shape.")
	if get_node_or_null(player_spawn_path) == null:
		warnings.append("PlayerSpawn marker is missing.")
	if get_node_or_null(fishing_shop_path) == null:
		warnings.append("Fishing Shop placement is missing.")
	if get_node_or_null(pelican_landmark_path) == null:
		warnings.append("Pelican placement is missing.")
	return warnings
