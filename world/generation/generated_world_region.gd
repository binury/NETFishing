class_name GeneratedWorldRegion
extends WorldRegion

signal world_generated(seed: int, summary: Dictionary)

const FishingShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)
const PlayerStorageInteractionType = preload(
	"res://world/player_storage_interaction.gd"
)
const PROP_SOURCE: PackedScene = preload(
	"res://art/exported/environment/terrain/starter_island.glb"
)
const WATER_BODY_SCENE: PackedScene = preload("res://world/water_body.tscn")
const SALT_WATER_MATERIAL: Material = preload(
	"res://world/materials/stylized_water.tres"
)
const FRESH_WATER_MATERIAL: Material = preload(
	"res://world/materials/stylized_water_fresh.tres"
)
const POND_POOL: FishPool = preload(
	"res://fish/pools/starter_pond_pool.tres"
)
const OCEAN_POOL: FishPool = preload(
	"res://fish/pools/starter_ocean_pool.tres"
)
const TREE_SOURCE_NAME := "tree_2_001"
const PALM_SOURCE_NAME := "plam_tree"
const TREE_RUNTIME_NAME := "regular_tree"
const PALM_RUNTIME_NAME := "palm_tree"
const WATER_HEIGHT := -0.25
const PROP_EDGE_MARGIN := 2.2
const TREE_CHANCE := 0.58
const PALM_CHANCE := 0.42

@export var initial_seed := PlayerSaveManager.DEFAULT_WORLD_SEED

@onready var _generator: TerrainChunkGenerator = %TerrainChunkGenerator
@onready var _player_spawn: Marker3D = %PlayerSpawn
@onready var _safe_spawn: SafeRespawnPoint = %SafeSpawn
@onready var _fishing_shop: FishingShopInteractionType = (
	$Interactables/FishingShopWorld/InteractionArea
)
@onready var _player_storage: PlayerStorageInteractionType = (
	$Interactables/PlayerStorageBox/InteractionArea
)
@onready var _shop_root: Node3D = %FishingShopWorld
@onready var _storage_root: Node3D = %PlayerStorageBox
@onready var _decorations: Node3D = %Decorations
@onready var _tree_anchors: GatherableAnchorSet3D = %ReachableTreeTrunks
@onready var _diggable_beach: DiggableArea3D = %DiggableBeach
@onready var _ocean: WaterBodyAuthoring = %OceanWater
@onready var _fresh_water_root: Node3D = %FreshWaterBodies
@onready var _shoreline_reference: MeshInstance3D = %ShorelineReference

var _current_seed := PlayerSaveManager.DEFAULT_WORLD_SEED
var _light_performance_profile := false
var _source_meshes: Dictionary[String, Mesh] = {}
var _source_bases: Dictionary[String, Basis] = {}
var _source_minimum_y: Dictionary[String, float] = {}


func _ready() -> void:
	_generator.generation_completed.connect(_on_generation_completed)
	_cache_prop_source(TREE_SOURCE_NAME)
	_cache_prop_source(PALM_SOURCE_NAME)
	_configure_static_water()
	_build_shoreline_reference()
	if not generate_world(initial_seed):
		push_error("The initial generated world could not be built.")


func generate_world(seed: int) -> bool:
	if seed <= 0 or seed > PlayerSaveManager.MAX_WORLD_SEED:
		return false
	_current_seed = seed
	_generator.generation_seed = seed
	return _generator.generate()


func get_generation_seed() -> int:
	return _current_seed


func get_playable_half_extents() -> Vector2:
	var size := Vector2(
		float(_generator.grid_size.x),
		float(_generator.grid_size.y),
	) * _generator.catalog.chunk_size
	return size * 0.5


func get_player_spawn_transform() -> Transform3D:
	return _player_spawn.global_transform


func get_fishing_shop() -> FishingShopInteractionType:
	return _fishing_shop


func get_player_storage() -> PlayerStorageInteractionType:
	return _player_storage


func get_saltwater_shoreline_mesh() -> MeshInstance3D:
	return _shoreline_reference


func set_light_performance_profile(enabled: bool) -> void:
	_light_performance_profile = enabled
	_apply_water_materials()


func get_spawn_surface_triangles(
	material_names: Array[StringName],
	minimum_global_y: float,
	minimum_up_dot: float = 0.6,
) -> Array[PackedVector3Array]:
	var triangles: Array[PackedVector3Array] = []
	var root: Node3D = _generator.get_generated_chunks_root()
	if root == null or material_names.is_empty():
		return triangles
	for mesh_instance: MeshInstance3D in _collect_mesh_instances(root):
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		for surface_index: int in mesh.get_surface_count():
			var material: Material = mesh_instance.get_active_material(surface_index)
			if material == null or not material_names.has(
				StringName(material.resource_name)
			):
				continue
			_append_surface_triangles(
				triangles,
				mesh_instance,
				mesh.surface_get_arrays(surface_index),
				minimum_global_y,
				minimum_up_dot,
			)
	return triangles


func _on_generation_completed(summary: Dictionary) -> void:
	var records: Array[Dictionary] = _generator.placement_records()
	var spawn_position := Vector3.ZERO
	_clear_children(_decorations)
	_clear_children(_tree_anchors)
	var random := RandomNumberGenerator.new()
	random.seed = _current_seed ^ 0x5EED71
	var grass_centers: Array[Vector3] = []
	var sand_centers: Array[Vector3] = []
	var tree_count := 0
	var palm_count := 0
	for record: Dictionary in records:
		var position: Vector3 = record.get("position", Vector3.ZERO)
		var tags: PackedStringArray = record.get(
			"tags", PackedStringArray()
		)
		if "spawn" in tags:
			spawn_position = position
		if "spawn" not in tags and "grass" in tags:
			grass_centers.append(position)
			if _maybe_add_prop(
				TREE_SOURCE_NAME,
				TREE_RUNTIME_NAME,
				position,
				TREE_CHANCE,
				random,
				true,
			):
				tree_count += 1
		elif "sand" in tags:
			sand_centers.append(position)
			if _maybe_add_prop(
				PALM_SOURCE_NAME,
				PALM_RUNTIME_NAME,
				position,
				PALM_CHANCE,
				random,
				false,
			):
				palm_count += 1
	if tree_count == 0 and not grass_centers.is_empty():
		_add_prop(
			TREE_SOURCE_NAME,
			TREE_RUNTIME_NAME,
			grass_centers[random.randi_range(0, grass_centers.size() - 1)],
			random,
			true,
		)
	if palm_count == 0 and not sand_centers.is_empty():
		_add_prop(
			PALM_SOURCE_NAME,
			PALM_RUNTIME_NAME,
			sand_centers[random.randi_range(0, sand_centers.size() - 1)],
			random,
			false,
		)
	_place_spawn_amenities(spawn_position)
	_configure_fresh_water(records)
	_configure_diggable_area()
	world_generated.emit(_current_seed, summary)


func _place_spawn_amenities(center: Vector3) -> void:
	_player_spawn.position = center + Vector3(0.0, 0.18, 2.2)
	_safe_spawn.position = _player_spawn.position
	_shop_root.position = center + Vector3(2.35, 0.0, -1.35)
	_shop_root.rotation.y = PI
	_storage_root.position = center + Vector3(-2.4, 0.0, 1.2)
	_storage_root.rotation.y = PI * 0.5


func _configure_static_water() -> void:
	_ocean.water_type = WaterType.Type.SALT_WATER
	_ocean.fish_pool = OCEAN_POOL
	_ocean.location_tags = [&"coast", &"ocean", &"generated_ocean"]
	_ocean.surface_size = Vector2(10000.0, 10000.0)
	_ocean.position.y = WATER_HEIGHT - 0.025
	_apply_water_materials()


func _configure_fresh_water(records: Array[Dictionary]) -> void:
	_clear_children(_fresh_water_root)
	for record: Dictionary in records:
		var tags: PackedStringArray = record.get(
			"tags", PackedStringArray()
		)
		if "fresh_water" not in tags:
			continue
		var surface_size: Vector2 = record.get(
			"water_surface_size", Vector2.ZERO
		)
		if surface_size.x <= 0.0 or surface_size.y <= 0.0:
			continue
		var body := WATER_BODY_SCENE.instantiate() as WaterBodyAuthoring
		if body == null:
			continue
		var coordinate: Vector2i = record.get("coordinate", Vector2i.ZERO)
		body.name = "FreshWater_%d_%d" % [coordinate.x, coordinate.y]
		_fresh_water_root.add_child(body)
		var turns := int(record.get("rotation_quarters", 0))
		var angle := float(posmod(turns, 4)) * PI * 0.5
		var offset: Vector2 = record.get(
			"water_surface_offset", Vector2.ZERO
		)
		var rotated_offset := Vector3(offset.x, 0.0, offset.y).rotated(
			Vector3.UP,
			angle,
		)
		body.position = (
			record.get("position", Vector3.ZERO)
			+ rotated_offset
			+ Vector3.UP * WATER_HEIGHT
		)
		body.rotation.y = angle
		body.surface_size = surface_size
		body.visual_surface_enabled = false
		body.water_material = _fresh_water_material()
		body.water_type = WaterType.Type.FRESH_WATER
		body.fish_pool = POND_POOL
		body.location_tags = _fresh_water_location_tags(tags)
		body.selection_priority = 10


func _fresh_water_location_tags(tags: PackedStringArray) -> Array[StringName]:
	var result: Array[StringName] = [&"generated_fresh_water"]
	if "pond" in tags:
		result.append(&"pond")
	if "river" in tags:
		result.append(&"river")
	return result


func _configure_diggable_area() -> void:
	var half_extents := get_playable_half_extents()
	_diggable_beach.generation_bounds = Rect2(
		-half_extents,
		half_extents * 2.0,
	)


func _apply_water_materials() -> void:
	if not is_node_ready():
		return
	if _light_performance_profile:
		_ocean.water_material = _light_water_material(
			Color(0.11, 0.345, 0.435),
		)
	else:
		_ocean.water_material = SALT_WATER_MATERIAL
	for child: Node in _fresh_water_root.get_children():
		var body := child as WaterBodyAuthoring
		if body != null:
			body.water_material = _fresh_water_material()


func _fresh_water_material() -> Material:
	if _light_performance_profile:
		return _light_water_material(Color(0.18, 0.46, 0.50))
	return FRESH_WATER_MATERIAL


func _light_water_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return material


func _maybe_add_prop(
	source_name: String,
	runtime_name: String,
	chunk_center: Vector3,
	chance: float,
	random: RandomNumberGenerator,
	add_anchor: bool,
) -> bool:
	if random.randf() > chance or not _source_meshes.has(source_name):
		return false
	_add_prop(
		source_name,
		runtime_name,
		chunk_center,
		random,
		add_anchor,
	)
	return true


func _add_prop(
	source_name: String,
	runtime_name: String,
	chunk_center: Vector3,
	random: RandomNumberGenerator,
	add_anchor: bool,
) -> void:
	if not _source_meshes.has(source_name):
		return
	var prop := Node3D.new()
	prop.name = "%s_%d" % [runtime_name, _decorations.get_child_count()]
	var offset := Vector3(
		random.randf_range(-PROP_EDGE_MARGIN, PROP_EDGE_MARGIN),
		0.0,
		random.randf_range(-PROP_EDGE_MARGIN, PROP_EDGE_MARGIN),
	)
	prop.position = chunk_center + offset
	prop.rotation.y = random.randf_range(-PI, PI)
	_decorations.add_child(prop)
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	visual.mesh = _source_meshes[source_name]
	visual.basis = _source_bases[source_name]
	visual.position.y = -_source_minimum_y.get(source_name, 0.0)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	prop.add_child(visual)
	_add_prop_collision(prop, source_name == TREE_SOURCE_NAME)
	if add_anchor:
		var anchor := Marker3D.new()
		anchor.name = "TreeAnchor_%d" % _tree_anchors.get_child_count()
		anchor.position = prop.position + Vector3(0.0, 2.15, 0.0)
		_tree_anchors.add_child(anchor)


func _add_prop_collision(prop: Node3D, broad_tree: bool) -> void:
	var body := StaticBody3D.new()
	body.name = "TrunkCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	prop.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape"
	var shape := CylinderShape3D.new()
	shape.radius = 0.5 if broad_tree else 0.35
	shape.height = 4.2 if broad_tree else 4.8
	collision.position.y = shape.height * 0.5
	collision.shape = shape
	body.add_child(collision)


func _cache_prop_source(source_name: String) -> void:
	var source_root := PROP_SOURCE.instantiate()
	var source := source_root.find_child(
		source_name,
		true,
		false,
	) as MeshInstance3D
	if source != null and source.mesh != null:
		_source_meshes[source_name] = source.mesh
		_source_bases[source_name] = source.transform.basis
		_source_minimum_y[source_name] = _minimum_transformed_mesh_y(
			source.mesh,
			source.transform.basis,
		)
	else:
		push_warning("Generated terrain prop source '%s' is unavailable." % source_name)
	source_root.free()


func _minimum_transformed_mesh_y(mesh: Mesh, basis: Basis) -> float:
	var bounds := mesh.get_aabb()
	var minimum_y := INF
	for corner_index: int in 8:
		var corner := bounds.position + Vector3(
			bounds.size.x if (corner_index & 1) != 0 else 0.0,
			bounds.size.y if (corner_index & 2) != 0 else 0.0,
			bounds.size.z if (corner_index & 4) != 0 else 0.0,
		)
		minimum_y = minf(minimum_y, (basis * corner).y)
	return minimum_y if minimum_y < INF else 0.0


func _build_shoreline_reference() -> void:
	var half := get_playable_half_extents()
	var width := 0.05
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var corners := [
		Vector3(-half.x, WATER_HEIGHT, -half.y),
		Vector3(half.x, WATER_HEIGHT, -half.y),
		Vector3(half.x, WATER_HEIGHT, half.y),
		Vector3(-half.x, WATER_HEIGHT, half.y),
	]
	for index: int in 4:
		var start: Vector3 = corners[index]
		var finish: Vector3 = corners[(index + 1) % 4]
		var direction := (finish - start).normalized()
		var perpendicular := Vector3(-direction.z, 0.0, direction.x) * width
		var base := vertices.size()
		vertices.append_array(PackedVector3Array([
			start - perpendicular,
			start + perpendicular,
			finish + perpendicular,
			finish - perpendicular,
		]))
		indices.append_array(PackedInt32Array([
			base, base + 1, base + 2,
			base, base + 2, base + 3,
		]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_shoreline_reference.mesh = mesh


func _append_surface_triangles(
	result: Array[PackedVector3Array],
	mesh_instance: MeshInstance3D,
	arrays: Array,
	minimum_global_y: float,
	minimum_up_dot: float,
) -> void:
	if arrays.size() <= Mesh.ARRAY_INDEX:
		return
	var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	if vertices.is_empty():
		return
	if indices.is_empty():
		for index: int in range(0, vertices.size() - 2, 3):
			_append_triangle(result, mesh_instance, vertices[index], vertices[index + 1], vertices[index + 2], minimum_global_y, minimum_up_dot)
		return
	for index: int in range(0, indices.size() - 2, 3):
		_append_triangle(result, mesh_instance, vertices[indices[index]], vertices[indices[index + 1]], vertices[indices[index + 2]], minimum_global_y, minimum_up_dot)


func _append_triangle(
	result: Array[PackedVector3Array],
	mesh_instance: MeshInstance3D,
	local_a: Vector3,
	local_b: Vector3,
	local_c: Vector3,
	minimum_global_y: float,
	minimum_up_dot: float,
) -> void:
	var a := mesh_instance.to_global(local_a)
	var b := mesh_instance.to_global(local_b)
	var c := mesh_instance.to_global(local_c)
	if minf(a.y, minf(b.y, c.y)) <= minimum_global_y:
		return
	var cross := (b - a).cross(c - a)
	if cross.length_squared() <= 0.0000001:
		return
	if absf(cross.normalized().dot(Vector3.UP)) < minimum_up_dot:
		return
	result.append(PackedVector3Array([a, b, c]))


func _collect_mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		result.append(root as MeshInstance3D)
	for child: Node in root.get_children():
		result.append_array(_collect_mesh_instances(child))
	return result


func _clear_children(root: Node) -> void:
	for child: Node in root.get_children():
		root.remove_child(child)
		child.free()
