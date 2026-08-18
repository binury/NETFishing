@tool
class_name StarterIslandRegion
extends WorldRegion

const FishingShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)
const PlayerStorageInteractionType = preload(
	"res://world/player_storage_interaction.gd"
)
const FOLIAGE_WIND_SHADER: Shader = preload(
	"res://world/materials/foliage_wind.gdshader"
)
const FOLIAGE_MATERIAL_NAMES: Array[StringName] = [
	&"leaf",
	&"leaf_light",
	&"leaf_dark",
]
const NORMAL_SALT_WATER_MATERIAL: Material = preload(
	"res://world/materials/stylized_water.tres"
)
const NORMAL_FRESH_WATER_MATERIAL: Material = preload(
	"res://world/materials/stylized_water_fresh.tres"
)
const LIGHT_SALT_WATER_COLOR := Color(0.11, 0.345, 0.435)
const LIGHT_FRESH_WATER_COLOR := Color(0.18, 0.46, 0.50)

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
@export_node_path("Area3D")
var player_storage_path: NodePath = (
	^"Interactables/PlayerStorageBox/InteractionArea"
)
@export_group("Terrain Collision")
# The imported GLB is the collision authority. Rebuild once per region load so
# newly authored terrain and props cannot retain a stale saved fallback shape.
@export var rebuild_terrain_collision_on_ready: bool = true
@export_group("Foliage Wind")
@export_range(0.0, 0.4, 0.005) var foliage_wind_strength: float = 0.36
@export_range(0.0, 4.0, 0.05) var foliage_wind_speed: float = 0.9

var _foliage_wind_enabled: bool = false


func _ready() -> void:
	if rebuild_terrain_collision_on_ready or not has_terrain_collision():
		_build_terrain_collision()
	_set_foliage_wind_enabled(true)
	if Engine.is_editor_hint():
		update_configuration_warnings()


func get_player_spawn_transform() -> Transform3D:
	var spawn: Marker3D = get_node_or_null(player_spawn_path) as Marker3D
	return spawn.global_transform if spawn != null else global_transform


func get_fishing_shop() -> FishingShopInteractionType:
	return get_node_or_null(fishing_shop_path) as FishingShopInteractionType


func get_player_storage() -> PlayerStorageInteractionType:
	return get_node_or_null(player_storage_path) as PlayerStorageInteractionType


func get_saltwater_shoreline_mesh() -> MeshInstance3D:
	return get_node_or_null(^"ShorelineRibbons/Ocean") as MeshInstance3D


func set_light_performance_profile(enabled: bool) -> void:
	_set_foliage_wind_enabled(not enabled)
	var pond := get_node_or_null(
		^"WaterBodies/Pond/VisualWater"
	) as MeshInstance3D
	var ocean := get_node_or_null(
		^"WaterBodies/Ocean/VisualWater"
	) as MeshInstance3D
	if pond != null:
		pond.material_override = (
			_create_light_water_material(
				LIGHT_FRESH_WATER_COLOR,
				&"light_fresh_water",
			)
			if enabled
			else NORMAL_FRESH_WATER_MATERIAL
		)
	if ocean != null:
		ocean.material_override = (
			_create_light_water_material(
				LIGHT_SALT_WATER_COLOR,
				&"light_salt_water",
			)
			if enabled
			else NORMAL_SALT_WATER_MATERIAL
		)


func is_foliage_wind_enabled() -> bool:
	return _foliage_wind_enabled


func _create_light_water_material(
	color: Color,
	material_name: StringName,
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = str(material_name)
	material.albedo_color = color
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return material


func get_spawn_surface_triangles(
	material_names: Array[StringName],
	minimum_global_y: float,
	minimum_up_dot: float = 0.6,
) -> Array[PackedVector3Array]:
	var triangles: Array[PackedVector3Array] = []
	if material_names.is_empty():
		return triangles
	var terrain_root: Node = get_node_or_null(terrain_visual_root_path)
	if terrain_root == null:
		return triangles
	for mesh_instance: MeshInstance3D in _collect_terrain_mesh_instances(
		terrain_root
	):
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		for surface_index: int in mesh.get_surface_count():
			var material: Material = mesh_instance.get_active_material(
				surface_index
			)
			if material == null or not material_names.has(
				StringName(material.resource_name)
			):
				continue
			var arrays: Array = mesh.surface_get_arrays(surface_index)
			if arrays.size() <= Mesh.ARRAY_INDEX:
				continue
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			if vertices.is_empty():
				continue
			if indices.is_empty():
				for vertex_index: int in range(0, vertices.size() - 2, 3):
					_append_spawn_triangle(
						triangles,
						mesh_instance,
						vertices[vertex_index],
						vertices[vertex_index + 1],
						vertices[vertex_index + 2],
						minimum_global_y,
						minimum_up_dot,
					)
			else:
				for index_offset: int in range(0, indices.size() - 2, 3):
					_append_spawn_triangle(
						triangles,
						mesh_instance,
						vertices[indices[index_offset]],
						vertices[indices[index_offset + 1]],
						vertices[indices[index_offset + 2]],
						minimum_global_y,
						minimum_up_dot,
					)
	return triangles


func _append_spawn_triangle(
	result: Array[PackedVector3Array],
	mesh_instance: MeshInstance3D,
	local_a: Vector3,
	local_b: Vector3,
	local_c: Vector3,
	minimum_global_y: float,
	minimum_up_dot: float,
) -> void:
	var a: Vector3 = mesh_instance.to_global(local_a)
	var b: Vector3 = mesh_instance.to_global(local_b)
	var c: Vector3 = mesh_instance.to_global(local_c)
	if (
		a.y <= minimum_global_y
		or b.y <= minimum_global_y
		or c.y <= minimum_global_y
	):
		return
	var cross: Vector3 = (b - a).cross(c - a)
	if cross.length_squared() <= 0.0000001:
		return
	if absf(cross.normalized().dot(Vector3.UP)) < minimum_up_dot:
		return
	result.append(PackedVector3Array([a, b, c]))


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


func _set_foliage_wind_enabled(enabled: bool) -> void:
	_foliage_wind_enabled = enabled
	var terrain_root: Node = get_node_or_null(terrain_visual_root_path)
	if terrain_root == null:
		return
	for mesh_instance: MeshInstance3D in _collect_terrain_mesh_instances(
		terrain_root
	):
		if enabled:
			_apply_foliage_wind_to_mesh(mesh_instance)
		else:
			_remove_foliage_wind_from_mesh(mesh_instance)


func _remove_foliage_wind_from_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
	for surface_index: int in mesh_instance.mesh.get_surface_count():
		var override_material: Material = (
			mesh_instance.get_surface_override_material(surface_index)
		)
		var shader_material := override_material as ShaderMaterial
		if (
			shader_material != null
			and shader_material.shader == FOLIAGE_WIND_SHADER
		):
			mesh_instance.set_surface_override_material(surface_index, null)


func _apply_foliage_wind_to_mesh(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
	var bounds: AABB = mesh_instance.get_aabb()
	var mesh_global_scale: Vector3 = mesh_instance.global_basis.get_scale().abs()
	var horizontal_scale: float = maxf(
		(mesh_global_scale.x + mesh_global_scale.z) * 0.5,
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
	if get_node_or_null(player_storage_path) == null:
		warnings.append("Private player storage placement is missing.")
	return warnings
