@tool
class_name StarterIslandRegion
extends WorldRegion

const FishingShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)
const FOLIAGE_WIND_SHADER: Shader = preload(
	"res://world/materials/foliage_wind.gdshader"
)
const FOLIAGE_MATERIAL_NAMES: Array[StringName] = [
	&"leaf",
	&"leaf_light",
	&"leaf_dark",
]

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
@export_group("Terrain Collision")
@export var rebuild_terrain_collision_on_ready: bool = false
@export_group("Foliage Wind")
@export_range(0.0, 0.4, 0.005) var foliage_wind_strength: float = 0.12
@export_range(0.0, 4.0, 0.05) var foliage_wind_speed: float = 0.9

func _ready() -> void:
	if rebuild_terrain_collision_on_ready or not has_terrain_collision():
		_build_terrain_collision()
	_apply_foliage_wind()
	if Engine.is_editor_hint():
		update_configuration_warnings()


func get_player_spawn_transform() -> Transform3D:
	var spawn: Marker3D = get_node_or_null(player_spawn_path) as Marker3D
	return spawn.global_transform if spawn != null else global_transform


func get_fishing_shop() -> FishingShopInteractionType:
	return get_node_or_null(fishing_shop_path) as FishingShopInteractionType


func get_saltwater_shoreline_mesh() -> MeshInstance3D:
	return get_node_or_null(^"ShorelineRibbons/Ocean") as MeshInstance3D


func has_terrain_collision() -> bool:
	var collision_shape: CollisionShape3D = (
		get_node_or_null(terrain_collision_shape_path) as CollisionShape3D
	)
	return collision_shape != null and collision_shape.shape != null


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


func _apply_foliage_wind() -> void:
	var terrain_root: Node = get_node_or_null(terrain_visual_root_path)
	if terrain_root == null:
		return
	for mesh_instance: MeshInstance3D in _collect_terrain_mesh_instances(
		terrain_root
	):
		_apply_foliage_wind_to_mesh(mesh_instance)


func _apply_foliage_wind_to_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
	var bounds: AABB = mesh_instance.get_aabb()
	var global_scale: Vector3 = mesh_instance.global_basis.get_scale().abs()
	var horizontal_scale: float = maxf(
		(global_scale.x + global_scale.z) * 0.5,
		0.001,
	)
	var local_strength: float = foliage_wind_strength / horizontal_scale
	var phase: float = fposmod(
		mesh_instance.global_position.x * 0.73
		+ mesh_instance.global_position.z * 0.41,
		TAU,
	)
	for surface_index: int in mesh_instance.mesh.get_surface_count():
		var source_material: Material = mesh_instance.get_active_material(
			surface_index
		)
		if not source_material is StandardMaterial3D:
			continue
		if not FOLIAGE_MATERIAL_NAMES.has(
			StringName(source_material.resource_name)
		):
			continue
		var source_standard := source_material as StandardMaterial3D
		var wind_material := ShaderMaterial.new()
		wind_material.shader = FOLIAGE_WIND_SHADER
		wind_material.set_shader_parameter(
			"albedo_color",
			source_standard.albedo_color,
		)
		wind_material.set_shader_parameter(
			"material_roughness",
			source_standard.roughness,
		)
		wind_material.set_shader_parameter(
			"material_metallic",
			source_standard.metallic,
		)
		wind_material.set_shader_parameter("local_min_y", bounds.position.y)
		wind_material.set_shader_parameter(
			"local_height",
			maxf(bounds.size.y, 0.001),
		)
		wind_material.set_shader_parameter(
			"local_wind_strength",
			local_strength,
		)
		wind_material.set_shader_parameter("wind_speed", foliage_wind_speed)
		wind_material.set_shader_parameter("wind_phase", phase)
		mesh_instance.set_surface_override_material(
			surface_index,
			wind_material,
		)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var visual_mesh := get_node_or_null(visual_mesh_path) as MeshInstance3D
	if visual_mesh == null:
		warnings.append("Terrain/Visual terrain mesh node is unavailable.")
		return warnings
	if visual_mesh == null or visual_mesh.mesh == null:
		warnings.append("Terrain/Visual must provide the island mesh.")
		return warnings

	if get_node_or_null(terrain_collision_shape_path) == null:
		warnings.append("Terrain/Collision must provide a collision shape.")
	if get_node_or_null(terrain_visual_root_path) == null:
		warnings.append("Terrain/Visual root is missing for terrain collision generation.")
	if get_node_or_null(player_spawn_path) == null:
		warnings.append("PlayerSpawn marker is missing.")
	if get_node_or_null(fishing_shop_path) == null:
		warnings.append("Fishing Shop placement is missing.")
	return warnings
