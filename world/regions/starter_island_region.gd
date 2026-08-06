@tool
class_name StarterIslandRegion
extends WorldRegion

const FishingShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)
const GRASS_SURFACE_NAME: String = "grass_lite"
const SAND_SURFACE_NAME: String = "sand"

@export_group("Owned Nodes")
@export_node_path("MeshInstance3D")
var visual_mesh_path: NodePath = (
	^"Terrain/Visual/starter_island"
)
@export_node_path("Node3D")
var terrain_visual_root_path: NodePath = ^"Terrain/Visual"
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

@export_group("Sand Surface")
@export var sand_material: Material
@export_range(0, 16, 1) var sand_surface_index: int = 2


func _ready() -> void:
	_apply_grass_material()
	_apply_sand_material()
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


func get_saltwater_shoreline_mesh() -> MeshInstance3D:
	return get_node_or_null(^"ShorelineRibbons/Ocean") as MeshInstance3D


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
	if (
		visual_mesh.mesh.surface_get_name(grass_surface_index)
		!= GRASS_SURFACE_NAME
	):
		push_error("Starter island grass surface name does not match.")
		return
	visual_mesh.set_surface_override_material(
		grass_surface_index,
		grass_material
	)


func _apply_sand_material() -> void:
	var visual_mesh: MeshInstance3D = (
		get_node_or_null(visual_mesh_path) as MeshInstance3D
	)
	if visual_mesh == null or visual_mesh.mesh == null:
		push_error("Starter island visual mesh is unavailable.")
		return
	if sand_material == null:
		push_error("Starter island sand material is unavailable.")
		return
	if sand_surface_index >= visual_mesh.mesh.get_surface_count():
		push_error("Starter island sand surface index is invalid.")
		return
	if (
		visual_mesh.mesh.surface_get_name(sand_surface_index)
		!= SAND_SURFACE_NAME
	):
		push_error("Starter island sand surface name does not match.")
		return
	visual_mesh.set_surface_override_material(
		sand_surface_index,
		sand_material
	)


func _build_terrain_collision() -> void:
	var terrain_root: Node = get_node_or_null(terrain_visual_root_path)
	if terrain_root == null:
		terrain_root = get_node_or_null(visual_mesh_path)
	var collision_shape: CollisionShape3D = (
		get_node_or_null(terrain_collision_shape_path) as CollisionShape3D
	)
	if terrain_root == null:
		push_error("Starter island visual terrain root is unavailable.")
		return
	if collision_shape == null:
		push_error("Starter island collision owner is unavailable.")
		return
	var mesh_instances := _collect_terrain_mesh_instances(terrain_root)
	if mesh_instances.is_empty():
		var visual_mesh: MeshInstance3D = terrain_root as MeshInstance3D
		if visual_mesh == null or visual_mesh.mesh == null:
			push_error("Starter island visual mesh is unavailable.")
			return
		var fallback_shape: ConcavePolygonShape3D = (
			visual_mesh.mesh.create_trimesh_shape()
		)
		if fallback_shape == null or fallback_shape.get_faces().is_empty():
			push_error("Starter island terrain collision could not be created.")
			return
		collision_shape.shape = fallback_shape
		return
	var terrain_shape := ConcavePolygonShape3D.new()
	var faces := PackedVector3Array()
	for mesh_instance: MeshInstance3D in mesh_instances:
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		var mesh_shape := mesh.create_trimesh_shape()
		if mesh_shape == null:
			continue
		for face_vertex: Vector3 in mesh_shape.get_faces():
			faces.append(to_local(mesh_instance.to_global(face_vertex)))
	if faces.is_empty():
		push_error("Starter island terrain collision could not be created.")
		return
	terrain_shape.set_faces(faces)
	collision_shape.shape = terrain_shape


func _collect_terrain_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var mesh_instances: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		mesh_instances.append(root as MeshInstance3D)
	for child: Node in root.get_children():
		mesh_instances.append_array(_collect_terrain_mesh_instances(child))
	return mesh_instances


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var visual_mesh := get_node_or_null(visual_mesh_path) as MeshInstance3D
	if visual_mesh == null:
		warnings.append("Terrain/Visual terrain mesh node is unavailable.")
		return warnings
	if visual_mesh == null or visual_mesh.mesh == null:
		warnings.append("Terrain/Visual must provide the island mesh.")
	elif grass_surface_index >= visual_mesh.mesh.get_surface_count():
		warnings.append("Grass surface index is outside the terrain mesh.")
	elif (
		visual_mesh.mesh.surface_get_name(grass_surface_index)
		!= GRASS_SURFACE_NAME
	):
		warnings.append("Grass surface index must identify the grass surface.")
	if grass_material == null:
		warnings.append("Assign the starter-island grass material.")
	if visual_mesh != null and visual_mesh.mesh != null:
		if sand_surface_index >= visual_mesh.mesh.get_surface_count():
			warnings.append("Sand surface index is outside the terrain mesh.")
		elif (
			visual_mesh.mesh.surface_get_name(sand_surface_index)
			!= SAND_SURFACE_NAME
		):
			warnings.append("Sand surface index must identify the sand surface.")
	if sand_material == null:
		warnings.append("Assign the starter-island sand material.")
	if get_node_or_null(terrain_collision_shape_path) == null:
		warnings.append("Terrain/Collision must provide a collision shape.")
	if get_node_or_null(terrain_visual_root_path) == null:
		warnings.append("Terrain/Visual root is missing for terrain collision generation.")
	if get_node_or_null(player_spawn_path) == null:
		warnings.append("PlayerSpawn marker is missing.")
	if get_node_or_null(fishing_shop_path) == null:
		warnings.append("Fishing Shop placement is missing.")
	if get_node_or_null(pelican_landmark_path) == null:
		warnings.append("Pelican placement is missing.")
	return warnings
