class_name GeneratedWorldRegion
extends WorldRegion

signal world_generated(seed: int, summary: Dictionary)

const FishingShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)
const PlayerStorageInteractionType = preload(
	"res://world/player_storage_interaction.gd"
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
const WATER_HEIGHT := -0.25
const PROP_EDGE_MARGIN := 2.2
const PROP_PLACEMENT_ATTEMPTS := 12
const PROP_MINIMUM_GROUND_CLEARANCE := 0.05
const PROP_CHANCE_SCALE := 10000
const PROP_SELECTION_WEIGHT_SCALE := 1000
const PROCEDURAL_PROP_GROUPS: Array[StringName] = [
	&"grass_tree",
	&"grass_detail",
	&"sand_tree",
]

@export var initial_seed := PlayerSaveManager.DEFAULT_WORLD_SEED
@export var prop_catalog: TerrainPropCatalog
@export var biome_catalog: TerrainBiomeCatalog

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
var _placed_prop_positions: Array[Vector3] = []
var _placed_prop_clearance_radii: Array[float] = []
var _placed_prop_groups: Array[StringName] = []
var _placed_group_coordinates: Dictionary[StringName, Array] = {}
var _biome_assignments: Dictionary[Vector2i, StringName] = {}


func _ready() -> void:
	_generator.generation_completed.connect(_on_generation_completed)
	_validate_prop_catalog()
	_validate_biome_catalog()
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


func get_prop_catalog() -> TerrainPropCatalog:
	return prop_catalog


func get_biome_catalog() -> TerrainBiomeCatalog:
	return biome_catalog


func get_biome_at(coordinate: Vector2i) -> StringName:
	return _biome_assignments.get(coordinate, &"")


func set_light_performance_profile(enabled: bool) -> void:
	_light_performance_profile = enabled
	_apply_water_materials()


func get_spawn_surface_triangles(
	material_names: Array[StringName],
	minimum_global_y: float,
	minimum_up_dot: float = 0.6,
) -> Array[PackedVector3Array]:
	var triangles: Array[PackedVector3Array] = []
	if material_names.is_empty():
		return triangles
	for mesh_instance: MeshInstance3D in _generator.get_primary_terrain_meshes():
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
	_assign_biomes(records, summary)
	var spawn_position := Vector3.ZERO
	_clear_children(_decorations)
	_clear_children(_tree_anchors)
	_placed_prop_positions.clear()
	_placed_prop_clearance_radii.clear()
	_placed_prop_groups.clear()
	_placed_group_coordinates.clear()
	var random := RandomNumberGenerator.new()
	random.seed = _current_seed ^ 0x5EED71
	var terrain_triangles := _terrain_surface_triangles()
	var biomes: Array[TerrainBiomeDefinition] = []
	if biome_catalog != null:
		biomes.assign(biome_catalog.definitions)
	var eligible_records: Dictionary[StringName, Array] = {}
	var group_counts: Dictionary[StringName, int] = {}
	for group: StringName in PROCEDURAL_PROP_GROUPS:
		for biome: TerrainBiomeDefinition in biomes:
			var rule := biome.prop_rule_for_group(group)
			if rule == null:
				continue
			var group_key := _biome_group_key(biome.stable_id, group)
			eligible_records[group_key] = []
			group_counts[group_key] = 0
			_placed_group_coordinates[group_key] = []
	for record: Dictionary in records:
		var position: Vector3 = record.get("position", Vector3.ZERO)
		var tags: PackedStringArray = record.get(
			"tags", PackedStringArray()
		)
		if "spawn" in tags:
			spawn_position = position
			continue
		var coordinate: Vector2i = record.get(
			"coordinate",
			Vector2i.ZERO,
		)
		var biome_id: StringName = record.get("biome_id", &"")
		if biome_catalog == null:
			continue
		var biome := biome_catalog.definition_for_id(biome_id)
		if biome == null:
			continue
		for group: StringName in PROCEDURAL_PROP_GROUPS:
			var rule := biome.prop_rule_for_group(group)
			if rule == null:
				continue
			var definitions := _spawn_distance_eligible_definitions(
				_prop_definitions_for(rule, tags),
				coordinate,
			)
			if definitions.is_empty():
				continue
			var group_key := _biome_group_key(biome_id, group)
			var group_records: Array = eligible_records[group_key]
			group_records.append(record)
	for group: StringName in PROCEDURAL_PROP_GROUPS:
		for biome: TerrainBiomeDefinition in biomes:
			var rule := biome.prop_rule_for_group(group)
			if rule == null:
				continue
			var group_key := _biome_group_key(biome.stable_id, group)
			var group_records: Array = eligible_records[group_key]
			var maximum := _prop_group_maximum(rule, group_records.size())
			for record: Dictionary in group_records:
				if group_counts.get(group_key, 0) >= maximum:
					break
				var coordinate: Vector2i = record.get(
					"coordinate",
					Vector2i.ZERO,
				)
				var tags: PackedStringArray = record.get(
					"tags",
					PackedStringArray(),
				)
				var definitions := _spawn_distance_eligible_definitions(
					_prop_definitions_for(rule, tags),
					coordinate,
				)
				if (
					definitions.is_empty()
					or not _prop_group_roll_succeeds(
						rule,
						group_key,
						coordinate,
						random,
					)
				):
					continue
				if _maybe_add_prop(
					definitions,
					record.get("position", Vector3.ZERO),
					coordinate,
					biome.stable_id,
					random,
					terrain_triangles,
				):
					group_counts[group_key] += 1
					_record_prop_group_coordinate(
						group_key,
						coordinate,
					)
	_ensure_minimum_props(
		eligible_records,
		group_counts,
		random,
		terrain_triangles,
	)
	_place_spawn_amenities(spawn_position)
	_configure_fresh_water(records)
	_configure_diggable_area()
	world_generated.emit(_current_seed, summary)


func _assign_biomes(
	records: Array[Dictionary],
	summary: Dictionary,
) -> void:
	_biome_assignments = TerrainBiomeAssigner.assign(
		biome_catalog,
		records,
		_current_seed,
	)
	for index: int in records.size():
		var record := records[index]
		var coordinate: Vector2i = record.get(
			"coordinate",
			Vector2i.ZERO,
		)
		record["biome_id"] = _biome_assignments.get(coordinate, &"")
		records[index] = record
	var generated_chunks := _generator.get_generated_chunks_root()
	if generated_chunks != null:
		for child: Node in generated_chunks.get_children():
			var coordinate: Vector2i = child.get_meta(
				&"terrain_chunk_coordinate",
				Vector2i.ZERO,
			)
			child.set_meta(
				&"terrain_biome_id",
				_biome_assignments.get(coordinate, &""),
			)
	summary["biome_counts"] = TerrainBiomeAssigner.counts(
		_biome_assignments
	)
	summary["biome_fingerprint"] = TerrainBiomeAssigner.fingerprint(
		_biome_assignments
	)


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
	definitions: Array[TerrainPropDefinition],
	chunk_center: Vector3,
	chunk_coordinate: Vector2i,
	biome_id: StringName,
	random: RandomNumberGenerator,
	terrain_triangles: Array[PackedVector3Array],
) -> bool:
	var definition := _pick_prop_definition(
		definitions,
		chunk_center,
		random,
	)
	if definition == null:
		return false
	return _add_prop(
		definition,
		chunk_center,
		chunk_coordinate,
		biome_id,
		random,
		terrain_triangles,
	)


func _add_prop(
	definition: TerrainPropDefinition,
	chunk_center: Vector3,
	chunk_coordinate: Vector2i,
	biome_id: StringName,
	random: RandomNumberGenerator,
	terrain_triangles: Array[PackedVector3Array],
) -> bool:
	if definition == null or definition.packed_scene == null:
		return false
	var placement := Vector3.ZERO
	var found_surface := false
	for attempt: int in PROP_PLACEMENT_ATTEMPTS:
		var offset := Vector3(
			random.randf_range(-PROP_EDGE_MARGIN, PROP_EDGE_MARGIN),
			0.0,
			random.randf_range(-PROP_EDGE_MARGIN, PROP_EDGE_MARGIN),
		)
		placement = chunk_center + offset
		var surface_height := _surface_height_at(
			placement,
			terrain_triangles,
		)
		if (
			surface_height > -INF
			and surface_height
			> WATER_HEIGHT + PROP_MINIMUM_GROUND_CLEARANCE
			and _has_prop_clearance(
				placement,
				definition.clearance_radius,
			)
		):
			placement.y = surface_height
			found_surface = true
			break
	if not found_surface:
		return false
	var packed_instance := definition.packed_scene.instantiate()
	var visual_root := packed_instance as Node3D
	if visual_root == null:
		packed_instance.free()
		return false
	var prop := Node3D.new()
	prop.name = "%s_%d" % [
		String(definition.stable_id).trim_prefix("prop_"),
		_decorations.get_child_count(),
	]
	prop.set_meta(&"terrain_prop_id", definition.stable_id)
	prop.set_meta(&"terrain_prop_group", definition.procedural_group)
	prop.set_meta(&"terrain_chunk_coordinate", chunk_coordinate)
	prop.set_meta(&"terrain_biome_id", biome_id)
	prop.position = placement
	prop.rotation.y = random.randf_range(-PI, PI)
	_decorations.add_child(prop)
	visual_root.name = "Visual"
	prop.add_child(visual_root)
	_configure_prop_visuals(visual_root)
	_add_prop_collision(prop, definition)
	_placed_prop_positions.append(placement)
	_placed_prop_clearance_radii.append(definition.clearance_radius)
	_placed_prop_groups.append(definition.procedural_group)
	if definition.gatherable_anchor_height > 0.0:
		var anchor := Marker3D.new()
		anchor.name = "TreeAnchor_%d" % _tree_anchors.get_child_count()
		anchor.position = prop.position + Vector3(
			0.0,
			definition.gatherable_anchor_height,
			0.0,
		)
		_tree_anchors.add_child(anchor)
	return true


func _validate_prop_catalog() -> void:
	if prop_catalog == null:
		push_error("Generated world terrain prop catalog is unavailable.")
		return
	for error: String in prop_catalog.validation_errors():
		push_error("Generated world terrain prop catalog: %s" % error)


func _validate_biome_catalog() -> void:
	if biome_catalog == null:
		push_error("Generated world terrain biome catalog is unavailable.")
		return
	for error: String in biome_catalog.validation_errors():
		push_error("Generated world terrain biome catalog: %s" % error)
	if prop_catalog == null:
		return
	for biome: TerrainBiomeDefinition in biome_catalog.definitions:
		if biome == null:
			continue
		for rule: TerrainBiomePropRule in biome.prop_rules:
			if rule == null:
				continue
			if rule.procedural_group not in PROCEDURAL_PROP_GROUPS:
				push_error(
					"Biome %s references unsupported prop group %s."
					% [biome.stable_id, rule.procedural_group]
				)
			for prop_id_value: String in rule.allowed_prop_ids:
				var prop_id := StringName(prop_id_value)
				var definition := prop_catalog.definition_for_id(prop_id)
				if definition == null:
					push_error(
						"Biome %s references missing prop %s."
						% [biome.stable_id, prop_id]
					)
				elif definition.procedural_group != rule.procedural_group:
					push_error(
						"Biome %s assigns prop %s to the wrong group."
						% [biome.stable_id, prop_id]
					)


func _prop_definitions_for(
	rule: TerrainBiomePropRule,
	tags: PackedStringArray,
) -> Array[TerrainPropDefinition]:
	if prop_catalog == null or rule == null:
		return []
	var result: Array[TerrainPropDefinition] = []
	for definition: TerrainPropDefinition in (
		prop_catalog.procedural_definitions(rule.procedural_group, tags)
	):
		if rule.allows_prop(definition):
			result.append(definition)
	return result


func _prop_group_roll_succeeds(
	rule: TerrainBiomePropRule,
	group_key: StringName,
	coordinate: Vector2i,
	random: RandomNumberGenerator,
) -> bool:
	var threshold := rule.placement_chance
	if _group_has_adjacent_placement(group_key, coordinate):
		threshold += rule.adjacency_bonus
	threshold = mini(threshold, PROP_CHANCE_SCALE)
	return random.randi_range(0, PROP_CHANCE_SCALE - 1) < threshold


func _pick_prop_definition(
	definitions: Array[TerrainPropDefinition],
	chunk_center: Vector3,
	random: RandomNumberGenerator,
) -> TerrainPropDefinition:
	var total_weight := 0
	var weights: Array[int] = []
	for definition: TerrainPropDefinition in definitions:
		var weight := maxi(
			1,
			roundi(
				definition.selection_weight
				* float(PROP_SELECTION_WEIGHT_SCALE)
			),
		)
		if not definition.preferred_nearby_prop_groups.is_empty():
			var multiplier := definition.nearby_preference_weight_multiplier
			if _has_preferred_prop_near(definition, chunk_center):
				weight = maxi(roundi(float(weight) * multiplier), 1)
			else:
				weight = maxi(roundi(float(weight) / multiplier), 1)
		weights.append(weight)
		total_weight += weight
	if total_weight <= 0:
		return null
	var roll := random.randi_range(1, total_weight)
	for index: int in definitions.size():
		roll -= weights[index]
		if roll <= 0:
			return definitions[index]
	return definitions.back() if not definitions.is_empty() else null


func _prop_group_maximum(
	rule: TerrainBiomePropRule,
	eligible_count: int,
) -> int:
	if eligible_count <= 0:
		return 0
	var maximum := ceili(
		float(eligible_count * rule.maximum_density)
		/ float(PROP_CHANCE_SCALE)
	)
	return maxi(maximum, rule.minimum_placements)


func _spawn_distance_eligible_definitions(
	definitions: Array[TerrainPropDefinition],
	coordinate: Vector2i,
) -> Array[TerrainPropDefinition]:
	var result: Array[TerrainPropDefinition] = []
	var center := Vector2i(
		_generator.grid_size.x / 2,
		_generator.grid_size.y / 2,
	)
	var distance := (
		absi(coordinate.x - center.x)
		+ absi(coordinate.y - center.y)
	)
	for definition: TerrainPropDefinition in definitions:
		if distance >= definition.minimum_spawn_chunk_distance:
			result.append(definition)
	return result


func _group_has_adjacent_placement(
	group: StringName,
	coordinate: Vector2i,
) -> bool:
	var coordinates: Array = _placed_group_coordinates.get(group, [])
	for coordinate_value: Variant in coordinates:
		var other: Vector2i = coordinate_value
		if (
			absi(coordinate.x - other.x)
			+ absi(coordinate.y - other.y)
			== 1
		):
			return true
	return false


func _record_prop_group_coordinate(
	group: StringName,
	coordinate: Vector2i,
) -> void:
	var coordinates: Array = _placed_group_coordinates.get(group, [])
	coordinates.append(coordinate)
	_placed_group_coordinates[group] = coordinates


func _has_preferred_prop_near(
	definition: TerrainPropDefinition,
	position: Vector3,
) -> bool:
	for index: int in _placed_prop_positions.size():
		if (
			_placed_prop_groups[index]
			not in definition.preferred_nearby_prop_groups
		):
			continue
		var other := _placed_prop_positions[index]
		if Vector2(position.x - other.x, position.z - other.z).length() <= (
			definition.preferred_nearby_radius
		):
			return true
	return false


func _ensure_minimum_props(
	eligible_records: Dictionary[StringName, Array],
	group_counts: Dictionary[StringName, int],
	random: RandomNumberGenerator,
	terrain_triangles: Array[PackedVector3Array],
) -> void:
	if biome_catalog == null:
		return
	for group: StringName in PROCEDURAL_PROP_GROUPS:
		for biome: TerrainBiomeDefinition in biome_catalog.definitions:
			var rule := biome.prop_rule_for_group(group)
			if rule == null or rule.minimum_placements <= 0:
				continue
			var group_key := _biome_group_key(biome.stable_id, group)
			var records: Array = eligible_records.get(group_key, [])
			if records.is_empty():
				continue
			var maximum_attempts := maxi(
				PROP_PLACEMENT_ATTEMPTS,
				records.size() * rule.minimum_placements * 2,
			)
			for _attempt: int in maximum_attempts:
				if (
					group_counts.get(group_key, 0)
					>= rule.minimum_placements
				):
					break
				var record: Dictionary = records[
					random.randi_range(0, records.size() - 1)
				]
				var tags: PackedStringArray = record.get(
					"tags",
					PackedStringArray(),
				)
				var coordinate: Vector2i = record.get(
					"coordinate",
					Vector2i.ZERO,
				)
				var definitions := _spawn_distance_eligible_definitions(
					_prop_definitions_for(rule, tags),
					coordinate,
				)
				if _maybe_add_prop(
					definitions,
					record.get("position", Vector3.ZERO),
					coordinate,
					biome.stable_id,
					random,
					terrain_triangles,
				):
					group_counts[group_key] += 1
					_record_prop_group_coordinate(
						group_key,
						coordinate,
					)


func _biome_group_key(
	biome_id: StringName,
	group: StringName,
) -> StringName:
	return StringName("%s:%s" % [biome_id, group])


func _has_prop_clearance(position: Vector3, radius: float) -> bool:
	for index: int in _placed_prop_positions.size():
		var other := _placed_prop_positions[index]
		var distance := Vector2(
			position.x - other.x,
			position.z - other.z,
		).length()
		if distance < radius + _placed_prop_clearance_radii[index]:
			return false
	return true


func _configure_prop_visuals(root_node: Node) -> void:
	if root_node is GeometryInstance3D:
		(root_node as GeometryInstance3D).cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
	for child: Node in root_node.get_children():
		_configure_prop_visuals(child)


func _terrain_surface_triangles() -> Array[PackedVector3Array]:
	var triangles: Array[PackedVector3Array] = []
	for mesh_instance: MeshInstance3D in _generator.get_primary_terrain_meshes():
		if mesh_instance.mesh == null:
			continue
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			_append_surface_triangles(
				triangles,
				mesh_instance,
				mesh_instance.mesh.surface_get_arrays(surface_index),
				-INF,
				0.35,
			)
	return triangles


func _surface_height_at(
	position: Vector3,
	triangles: Array[PackedVector3Array],
) -> float:
	var highest := -INF
	var segment_start := position + Vector3.UP * 100.0
	var segment_end := position + Vector3.DOWN * 100.0
	for triangle: PackedVector3Array in triangles:
		if triangle.size() != 3:
			continue
		var hit: Variant = Geometry3D.segment_intersects_triangle(
			segment_start,
			segment_end,
			triangle[0],
			triangle[1],
			triangle[2],
		)
		if hit is Vector3:
			highest = maxf(highest, (hit as Vector3).y)
	return highest


func _add_prop_collision(
	prop: Node3D,
	definition: TerrainPropDefinition,
) -> void:
	if not definition.has_collision():
		return
	var body := StaticBody3D.new()
	body.name = "TrunkCollision"
	body.collision_layer = 1
	body.collision_mask = 0
	prop.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape"
	if definition.has_box_collision():
		var box := BoxShape3D.new()
		box.size = definition.collision_box_size
		collision.shape = box
		collision.position = definition.collision_offset
	else:
		var cylinder := CylinderShape3D.new()
		cylinder.radius = definition.collision_radius
		cylinder.height = definition.collision_height
		collision.shape = cylinder
		collision.position = (
			definition.collision_offset
			+ Vector3.UP * cylinder.height * 0.5
		)
	body.add_child(collision)


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


func _clear_children(root: Node) -> void:
	for child: Node in root.get_children():
		root.remove_child(child)
		child.free()
