class_name TerrainChunkGenerator
extends Node3D

signal generation_completed(summary: Dictionary)

const EDGE_PROFILE_QUANTIZATION := 0.001

@export var catalog: TerrainChunkCatalog
@export var grid_size := Vector2i(5, 5)
@export var generation_seed := 13001
@export var generate_on_ready := true
@export var build_collision := true
@export var show_chunk_labels := false
@export var force_center_chunk_id: StringName = &"chunk_0000"
@export var required_chunk_ids := PackedStringArray()
@export_range(1.0, 100.0, 1.0) var required_chunk_weight_multiplier := 64.0
@export_range(0.001, 0.1, 0.001) var edge_match_tolerance := 0.01
@export_range(1, 100000, 1) var maximum_backtracks := 20000

var _variants: Array[TerrainChunkVariant] = []
var _placements: Array[TerrainChunkVariant] = []
var _random := RandomNumberGenerator.new()
var _generated_chunks: Node3D
var _backtrack_count := 0


func _ready() -> void:
	if generate_on_ready:
		call_deferred(&"generate")


func generate() -> bool:
	_clear_generated_chunks()
	if not _prepare_catalog():
		return false
	_random.seed = generation_seed
	_backtrack_count = 0
	_placements.clear()
	_placements.resize(grid_size.x * grid_size.y)
	if not _solve_cell(0):
		push_error(
			"Terrain generation could not solve a %dx%d grid with seed %d."
			% [grid_size.x, grid_size.y, generation_seed]
		)
		return false
	_instantiate_solution()
	var summary := _build_summary()
	generation_completed.emit(summary)
	return true


func _prepare_catalog() -> bool:
	if catalog == null:
		push_error("TerrainChunkGenerator requires a catalog.")
		return false
	if grid_size.x <= 0 or grid_size.y <= 0:
		push_error("TerrainChunkGenerator grid dimensions must be positive.")
		return false
	var catalog_errors := catalog.validation_errors()
	if not catalog_errors.is_empty():
		push_error("Terrain chunk catalog is invalid:\n" + "\n".join(catalog_errors))
		return false

	_variants.clear()
	for definition: TerrainChunkDefinition in catalog.definitions:
		var analyzed := TerrainChunkAnalyzer.create_variants(
			definition,
			catalog.chunk_size,
		)
		var seen_signatures: Dictionary[String, bool] = {}
		for variant: TerrainChunkVariant in analyzed:
			var signature := variant.topology_signature(
				EDGE_PROFILE_QUANTIZATION
			)
			if seen_signatures.has(signature):
				continue
			seen_signatures[signature] = true
			_variants.append(variant)
	if _variants.is_empty():
		push_error("Terrain chunk catalog produced no usable variants.")
		return false
	return true


func _solve_cell(index: int) -> bool:
	if index >= _placements.size():
		return _required_chunks_are_present()
	if _backtrack_count >= maximum_backtracks:
		return false
	var candidates := _compatible_candidates(index)
	for candidate: TerrainChunkVariant in _weighted_candidate_order(candidates):
		_placements[index] = candidate
		if _solve_cell(index + 1):
			return true
		_placements[index] = null
		_backtrack_count += 1
		if _backtrack_count >= maximum_backtracks:
			break
	return false


func _compatible_candidates(index: int) -> Array[TerrainChunkVariant]:
	var result: Array[TerrainChunkVariant] = []
	var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
	var center := Vector2i(grid_size.x / 2, grid_size.y / 2)
	for candidate: TerrainChunkVariant in _variants:
		if not _definition_has_capacity(candidate.definition):
			continue
		if (
			coordinate == center
			and force_center_chunk_id != &""
			and candidate.definition.stable_id != force_center_chunk_id
		):
			continue
		if coordinate.x > 0:
			var west_neighbor := _placements[index - 1]
			if (
				west_neighbor != null
				and not _edges_are_compatible(
					candidate,
					TerrainChunkTopology.Edge.WEST,
					west_neighbor,
					TerrainChunkTopology.Edge.EAST,
				)
			):
				continue
		if coordinate.y > 0:
			var north_neighbor := _placements[index - grid_size.x]
			if (
				north_neighbor != null
				and not _edges_are_compatible(
					candidate,
					TerrainChunkTopology.Edge.NORTH,
					north_neighbor,
					TerrainChunkTopology.Edge.SOUTH,
				)
			):
				continue
		result.append(candidate)
	return result


func _definition_has_capacity(definition: TerrainChunkDefinition) -> bool:
	if definition.maximum_placements < 0:
		return true
	var count := 0
	for placement: TerrainChunkVariant in _placements:
		if placement != null and placement.definition == definition:
			count += 1
	return count < definition.maximum_placements


func _edges_are_compatible(
	first: TerrainChunkVariant,
	first_edge: TerrainChunkTopology.Edge,
	second: TerrainChunkVariant,
	second_edge: TerrainChunkTopology.Edge,
) -> bool:
	if not first.profile(first_edge).matches(
		second.profile(second_edge),
		edge_match_tolerance,
	):
		return false
	var first_inlet := _variant_edge_has_connector(
		first,
		first.definition.water_inlet_edges,
		first_edge,
	)
	var first_outlet := _variant_edge_has_connector(
		first,
		first.definition.water_outlet_edges,
		first_edge,
	)
	var second_inlet := _variant_edge_has_connector(
		second,
		second.definition.water_inlet_edges,
		second_edge,
	)
	var second_outlet := _variant_edge_has_connector(
		second,
		second.definition.water_outlet_edges,
		second_edge,
	)
	var first_has_water := first_inlet or first_outlet
	var second_has_water := second_inlet or second_outlet
	if not first_has_water and not second_has_water:
		return true
	return (
		(first_outlet and second_inlet)
		or (first_inlet and second_outlet)
	)


func _variant_edge_has_connector(
	variant: TerrainChunkVariant,
	source_mask: int,
	edge: TerrainChunkTopology.Edge,
) -> bool:
	return (variant.rotated_edge_mask(source_mask) & (1 << int(edge))) != 0


func _required_chunks_are_present() -> bool:
	if required_chunk_ids.is_empty():
		return true
	var found: Dictionary[StringName, bool] = {}
	for placement: TerrainChunkVariant in _placements:
		if placement != null:
			found[placement.definition.stable_id] = true
	for required_id: String in required_chunk_ids:
		if not found.has(StringName(required_id)):
			return false
	return true


func _weighted_candidate_order(
	candidates: Array[TerrainChunkVariant],
) -> Array[TerrainChunkVariant]:
	var scored: Array[Dictionary] = []
	for candidate: TerrainChunkVariant in candidates:
		var weight := maxf(candidate.definition.selection_weight, 0.01)
		if _required_chunk_is_missing(candidate.definition.stable_id):
			weight *= required_chunk_weight_multiplier
		var sample := maxf(_random.randf(), 0.000001)
		scored.append(
			{
				"variant": candidate,
				"score": pow(sample, 1.0 / weight),
			}
		)
	scored.sort_custom(_higher_candidate_score)
	var result: Array[TerrainChunkVariant] = []
	for entry: Dictionary in scored:
		result.append(entry["variant"] as TerrainChunkVariant)
	return result


func _required_chunk_is_missing(stable_id: StringName) -> bool:
	if not required_chunk_ids.has(String(stable_id)):
		return false
	for placement: TerrainChunkVariant in _placements:
		if (
			placement != null
			and placement.definition.stable_id == stable_id
		):
			return false
	return true


func _instantiate_solution() -> void:
	_generated_chunks = Node3D.new()
	_generated_chunks.name = "GeneratedChunks"
	add_child(_generated_chunks)
	var half_grid := Vector2(
		float(grid_size.x - 1) * 0.5,
		float(grid_size.y - 1) * 0.5,
	)
	for index: int in _placements.size():
		var variant := _placements[index]
		if variant == null:
			continue
		var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
		var chunk_root := variant.definition.packed_scene.instantiate() as Node3D
		if chunk_root == null:
			push_error("%s does not instantiate as Node3D." % variant.stable_key())
			continue
		chunk_root.name = "%s_%d_%d" % [
			variant.stable_key().replace("@", "r"),
			coordinate.x,
			coordinate.y,
		]
		chunk_root.position = Vector3(
			(float(coordinate.x) - half_grid.x) * catalog.chunk_size,
			0.0,
			(float(coordinate.y) - half_grid.y) * catalog.chunk_size,
		)
		chunk_root.rotation.y = variant.rotation_radians()
		_generated_chunks.add_child(chunk_root)
		if build_collision:
			_add_collision(chunk_root, variant.definition)
		if show_chunk_labels:
			_add_chunk_label(chunk_root, variant)


func _add_collision(
	chunk_root: Node3D,
	definition: TerrainChunkDefinition,
) -> void:
	var primary_mesh := TerrainChunkAnalyzer.find_primary_mesh(
		chunk_root,
		definition.primary_mesh_name,
	)
	if primary_mesh == null or primary_mesh.mesh == null:
		return
	var terrain_shape := primary_mesh.mesh.create_trimesh_shape()
	if terrain_shape == null or terrain_shape.get_faces().is_empty():
		push_warning("%s produced no terrain collision." % definition.stable_id)
		return
	var collision_body := StaticBody3D.new()
	collision_body.name = "TerrainCollision"
	collision_body.collision_layer = 1
	collision_body.collision_mask = 0
	primary_mesh.add_child(collision_body)
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "TerrainShape"
	collision_shape.shape = terrain_shape
	collision_body.add_child(collision_shape)


func _add_chunk_label(
	chunk_root: Node3D,
	variant: TerrainChunkVariant,
) -> void:
	var label := Label3D.new()
	label.name = "ChunkLabel"
	label.text = "%s  r%d" % [
		variant.definition.stable_id,
		variant.quarter_turns,
	]
	label.position = Vector3(0.0, 1.25, 0.0)
	label.font_size = 24
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	chunk_root.add_child(label)


func _clear_generated_chunks() -> void:
	if is_instance_valid(_generated_chunks):
		remove_child(_generated_chunks)
		_generated_chunks.free()
	_generated_chunks = null


func _build_summary() -> Dictionary:
	var counts: Dictionary[StringName, int] = {}
	for variant: TerrainChunkVariant in _placements:
		if variant == null:
			continue
		var stable_id := variant.definition.stable_id
		counts[stable_id] = counts.get(stable_id, 0) + 1
	return {
		"seed": generation_seed,
		"grid_size": grid_size,
		"chunk_count": _placements.size(),
		"variant_count": _variants.size(),
		"backtracks": _backtrack_count,
		"counts": counts,
		"placements": placement_keys(),
	}


func placement_keys() -> PackedStringArray:
	var result := PackedStringArray()
	for variant: TerrainChunkVariant in _placements:
		result.append(variant.stable_key() if variant != null else "empty")
	return result


func placement_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in _placements.size():
		var variant: TerrainChunkVariant = _placements[index]
		if variant == null:
			continue
		var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
		result.append({
			"coordinate": coordinate,
			"position": chunk_position(coordinate),
			"rotation_quarters": variant.quarter_turns,
			"stable_id": variant.definition.stable_id,
			"tags": variant.definition.tags,
			"water_surface_size": variant.definition.water_surface_size,
			"water_surface_offset": variant.definition.water_surface_offset,
		})
	return result


func chunk_position(coordinate: Vector2i) -> Vector3:
	if catalog == null:
		return Vector3.ZERO
	var half_grid := Vector2(
		float(grid_size.x - 1) * 0.5,
		float(grid_size.y - 1) * 0.5,
	)
	return Vector3(
		(float(coordinate.x) - half_grid.x) * catalog.chunk_size,
		0.0,
		(float(coordinate.y) - half_grid.y) * catalog.chunk_size,
	)


func get_generated_chunks_root() -> Node3D:
	return _generated_chunks


static func _higher_candidate_score(a: Dictionary, b: Dictionary) -> bool:
	return float(a["score"]) > float(b["score"])
