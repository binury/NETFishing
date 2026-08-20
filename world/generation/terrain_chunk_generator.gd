class_name TerrainChunkGenerator
extends Node3D

signal generation_completed(summary: Dictionary)

const CONSTRAINT_PROFILE_QUANTIZATION := 0.001
const CANDIDATE_WEIGHT_SCALE := 10000.0
const LARGE_GRID_LIGHTWEIGHT_THRESHOLD := 128
const LARGE_GRID_PROPAGATION_INTERVAL := 8

@export var catalog: TerrainChunkCatalog
@export var grid_size := Vector2i(7, 7)
@export var generation_seed := 13001
@export var generate_on_ready := true
@export var build_collision := true
@export var show_chunk_labels := false
@export var force_center_chunk_id: StringName = &"chunk_0000"
@export var required_chunk_ids := PackedStringArray()
@export_group("Elevated Inland Feature")
@export var elevated_cliff_feature_enabled := false
@export var elevated_cliff_base_chunk_id: StringName = &"chunk_0000"
@export var elevated_cliff_top_chunk_id: StringName = &"chunk_0009"
@export var elevated_cliff_corner_chunk_id: StringName = &"chunk_0010"
@export var elevated_cliff_edge_chunk_id: StringName = &"chunk_0011"
@export var elevated_cliff_ramp_chunk_id: StringName = &"chunk_0012"
@export_range(0.0, 1.0, 0.05) var elevated_cliff_ramp_chance := 0.75
@export_group("")
@export_range(1.0, 100.0, 1.0) var required_chunk_weight_multiplier := 64.0
@export_range(1.0, 4.0, 0.05) var preferred_neighbor_weight_multiplier := 1.6
@export_range(0.01, 1.0, 0.01) var long_repeat_weight_multiplier := 0.3
@export_range(1.0, 10.0, 0.1) var boundary_preference_multiplier := 4.0
@export_range(0.001, 0.1, 0.001) var edge_match_tolerance := 0.01
@export_range(1, 100000, 1) var maximum_backtracks := 20000

# Every allowed authored rotation remains available for visual placement.
var _variants: Array[TerrainChunkVariant] = []
# Rotations with identical terrain edges and connector directions share one
# solver candidate, then resolve back to an authored rotation after solving.
var _solver_variants: Array[TerrainChunkVariant] = []
var _equivalent_rotations: Dictionary[String, PackedInt32Array] = {}
var _solver_variant_indices: Dictionary = {}
var _edge_compatibility := PackedByteArray()
var _placements: Array[TerrainChunkVariant] = []
var _random := RandomNumberGenerator.new()
var _generated_chunks: Node3D
var _backtrack_count := 0
var _elevated_feature_center := Vector2i(-1, -1)
var _elevated_feature_reserved_grass_indices: Dictionary[int, bool] = {}


func _ready() -> void:
	if generate_on_ready:
		call_deferred(&"generate")


func generate() -> bool:
	if not _prepare_catalog():
		return false
	var previous_placements: Array[TerrainChunkVariant] = []
	previous_placements.assign(_placements)
	_random.seed = generation_seed
	_backtrack_count = 0
	_placements.clear()
	_placements.resize(grid_size.x * grid_size.y)
	if not _prepare_elevated_feature_region():
		_placements.assign(previous_placements)
		return false
	if not _solve_cell(0):
		_placements.assign(previous_placements)
		push_error(
			"Terrain generation could not solve a %dx%d grid with seed %d."
			% [grid_size.x, grid_size.y, generation_seed]
		)
		return false
	_resolve_equivalent_rotations()
	if not _apply_elevated_feature():
		_placements.assign(previous_placements)
		return false
	var solution_root := _build_solution_root()
	if solution_root == null:
		_placements.assign(previous_placements)
		return false
	_replace_generated_chunks(solution_root)
	var summary := _build_summary()
	generation_completed.emit(summary)
	return true


func generate_from_placement_keys(keys: PackedStringArray) -> bool:
	if not _prepare_catalog():
		return false
	if keys.size() != grid_size.x * grid_size.y:
		push_error(
			"Terrain layout contains %d cells; expected %d."
			% [keys.size(), grid_size.x * grid_size.y]
		)
		return false
	var variants_by_key: Dictionary[String, TerrainChunkVariant] = {}
	for variant: TerrainChunkVariant in _variants:
		variants_by_key[variant.stable_key()] = variant
	var resolved: Array[TerrainChunkVariant] = []
	for key: String in keys:
		var variant: TerrainChunkVariant = variants_by_key.get(key)
		if variant == null:
			push_error("Terrain layout references unknown variant %s." % key)
			return false
		resolved.append(variant)
	var validation_error := _resolved_layout_validation_error(resolved)
	if not validation_error.is_empty():
		push_error("Terrain layout is invalid: " + validation_error)
		return false

	var previous_placements: Array[TerrainChunkVariant] = []
	previous_placements.assign(_placements)
	_placements.assign(resolved)
	_backtrack_count = 0
	var solution_root := _build_solution_root()
	if solution_root == null:
		_placements.assign(previous_placements)
		return false
	_replace_generated_chunks(solution_root)
	var summary := _build_summary()
	generation_completed.emit(summary)
	return true


func _resolved_layout_validation_error(
	layout: Array[TerrainChunkVariant],
) -> String:
	var counts: Dictionary[StringName, int] = {}
	for variant: TerrainChunkVariant in layout:
		if variant == null:
			return "one or more cells are empty."
		var stable_id := variant.definition.stable_id
		counts[stable_id] = counts.get(stable_id, 0) + 1
		var maximum := variant.definition.maximum_placements
		if maximum >= 0 and counts[stable_id] > maximum:
			return "%s exceeds its placement limit." % stable_id
	for required_id_value: String in required_chunk_ids:
		var required_id := StringName(required_id_value)
		if counts.get(required_id, 0) <= 0:
			return "required chunk %s is missing." % required_id
	if force_center_chunk_id != &"":
		var center := Vector2i(grid_size.x / 2, grid_size.y / 2)
		var center_index := center.y * grid_size.x + center.x
		if layout[center_index].definition.stable_id != force_center_chunk_id:
			return "the forced center chunk is missing from the center cell."
	for index: int in layout.size():
		var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
		var current := layout[index]
		if not _variant_respects_ocean_boundary(current, coordinate):
			return (
				"cell %d has an ocean-facing edge directed into the terrain grid."
				% index
			)
		if coordinate.x + 1 < grid_size.x:
			var east := layout[index + 1]
			if not _edges_are_compatible(
				current,
				TerrainChunkTopology.Edge.EAST,
				east,
				TerrainChunkTopology.Edge.WEST,
			):
				return "cells %d and %d have incompatible east/west edges." % [
					index,
					index + 1,
				]
		if coordinate.y + 1 < grid_size.y:
			var south := layout[index + grid_size.x]
			if not _edges_are_compatible(
				current,
				TerrainChunkTopology.Edge.SOUTH,
				south,
				TerrainChunkTopology.Edge.NORTH,
			):
				return "cells %d and %d have incompatible south/north edges." % [
					index,
					index + grid_size.x,
				]
	var neighbor_error := _neighbor_requirement_validation_error(layout)
	if not neighbor_error.is_empty():
		return neighbor_error
	return _walkable_connectivity_validation_error(layout)


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
	if not _validate_generation_requirements():
		return false

	_variants.clear()
	_solver_variants.clear()
	_equivalent_rotations.clear()
	_solver_variant_indices.clear()
	for definition: TerrainChunkDefinition in catalog.definitions:
		var analyzed := TerrainChunkAnalyzer.create_variants(
			definition,
			catalog.chunk_size,
		)
		if analyzed.is_empty():
			push_error(
				"Terrain chunk %s produced no usable rotation variants."
				% definition.stable_id
			)
			return false
		for variant: TerrainChunkVariant in analyzed:
			_variants.append(variant)
			if definition.overlay_only:
				continue
			var constraint_key := _constraint_key(variant)
			var rotations: PackedInt32Array = _equivalent_rotations.get(
				constraint_key,
				PackedInt32Array(),
			)
			rotations.append(variant.quarter_turns)
			_equivalent_rotations[constraint_key] = rotations
			if rotations.size() == 1:
				_solver_variants.append(variant)
	if _variants.is_empty():
		push_error("Terrain chunk catalog produced no usable variants.")
		return false
	if _solver_variants.is_empty():
		push_error("Terrain chunk catalog produced no base-terrain solver variants.")
		return false
	for index: int in _solver_variants.size():
		_solver_variant_indices[_solver_variants[index]] = index
	_build_edge_compatibility_cache()
	return true


func _constraint_key(variant: TerrainChunkVariant) -> String:
	return "%s|%s" % [
		variant.definition.stable_id,
		variant.constraint_signature(CONSTRAINT_PROFILE_QUANTIZATION),
	]


func _build_edge_compatibility_cache() -> void:
	var variant_count := _solver_variants.size()
	_edge_compatibility.resize(variant_count * 4 * variant_count)
	_edge_compatibility.fill(0)
	for first_index: int in variant_count:
		var first := _solver_variants[first_index]
		for first_edge_value: int in TerrainChunkTopology.Edge.values():
			var first_edge := first_edge_value as TerrainChunkTopology.Edge
			var second_edge := TerrainChunkTopology.opposite_edge(first_edge)
			for second_index: int in variant_count:
				var second := _solver_variants[second_index]
				var cache_index := _edge_compatibility_index(
					first_index,
					first_edge,
					second_index,
				)
				_edge_compatibility[cache_index] = int(
					_calculate_edge_compatibility(
					first,
					first_edge,
					second,
					second_edge,
					)
				)


func _edge_compatibility_index(
	first_index: int,
	first_edge: TerrainChunkTopology.Edge,
	second_index: int,
) -> int:
	var variant_count := _solver_variants.size()
	return (
		(first_index * 4 + int(first_edge)) * variant_count
		+ second_index
	)


func _validate_generation_requirements() -> bool:
	var seen_required: Dictionary[StringName, bool] = {}
	for required_id_value: String in required_chunk_ids:
		var required_id := StringName(required_id_value)
		if seen_required.has(required_id):
			continue
		seen_required[required_id] = true
		var definition := catalog.definition_for_id(required_id)
		if definition == null:
			push_error("Required terrain chunk %s is not in the catalog." % required_id)
			return false
		if definition.maximum_placements == 0:
			push_error("Required terrain chunk %s permits no placements." % required_id)
			return false
	if seen_required.size() > grid_size.x * grid_size.y:
		push_error("The terrain grid has fewer cells than required chunk IDs.")
		return false
	if force_center_chunk_id != &"":
		var center_definition := catalog.definition_for_id(force_center_chunk_id)
		if center_definition == null:
			push_error(
				"Forced center terrain chunk %s is not in the catalog."
				% force_center_chunk_id
			)
			return false
		if center_definition.maximum_placements == 0:
			push_error(
				"Forced center terrain chunk %s permits no placements."
				% force_center_chunk_id
			)
			return false
	return true


func _solve_cell(placed_count: int) -> bool:
	if placed_count >= _placements.size():
		return (
			_required_chunks_are_present()
			and _neighbor_requirement_validation_error(_placements).is_empty()
			and _walkable_connectivity_validation_error(_placements).is_empty()
		)
	if _backtrack_count >= maximum_backtracks:
		return false
	if not _requirements_can_still_be_satisfied():
		return false
	var next_cell := _select_next_cell(placed_count)
	var index := int(next_cell.get("index", -1))
	if index < 0:
		return false
	var candidates := next_cell.get(
		"candidates",
		[],
	) as Array[TerrainChunkVariant]
	for candidate: TerrainChunkVariant in _weighted_candidate_order(
		candidates,
		index,
	):
		_placements[index] = candidate
		if _solve_cell(placed_count + 1):
			return true
		_placements[index] = null
		_backtrack_count += 1
		if _backtrack_count >= maximum_backtracks:
			break
	return false


func _select_next_cell(placed_count: int) -> Dictionary:
	if (
		_placements.size() >= LARGE_GRID_LIGHTWEIGHT_THRESHOLD
		and placed_count % LARGE_GRID_PROPAGATION_INTERVAL != 0
	):
		return _select_next_large_grid_cell()
	# Rebuild and propagate the small domain table on every branch. This catches
	# unsupported connector chains before they turn into a deep recursive dead
	# end, while keeping placement state simple and deterministic.
	var domains: Dictionary = {}
	for index: int in _placements.size():
		if _placements[index] != null:
			continue
		var candidates := _compatible_candidates(index)
		if candidates.is_empty():
			return {"index": index, "candidates": candidates}
		domains[index] = candidates
	if not _propagate_domains(domains):
		return {"index": -1, "candidates": []}

	# Minimum-remaining-values traversal exposes contradictions before a long
	# row-major branch has already filled most of the map.
	var best_index := -1
	var best_candidates: Array[TerrainChunkVariant] = []
	for index_value: Variant in domains:
		var index := int(index_value)
		var candidates: Array[TerrainChunkVariant] = []
		candidates.assign(domains[index])
		if best_index < 0 or candidates.size() < best_candidates.size():
			best_index = index
			best_candidates = candidates
			if candidates.size() == 1:
				break
	return {"index": best_index, "candidates": best_candidates}


func _select_next_large_grid_cell() -> Dictionary:
	# Full all-cell arc propagation scales cubically as the map grows. Large
	# worlds instead use the same compatibility checks with a frontier-aware MRV
	# pass. Exact placement validation and backtracking remain unchanged.
	var best_index := -1
	var best_candidates: Array[TerrainChunkVariant] = []
	var best_placed_neighbors := -1
	for index: int in _placements.size():
		if _placements[index] != null:
			continue
		var candidates := _compatible_candidates(index)
		if candidates.is_empty():
			return {"index": index, "candidates": candidates}
		var placed_neighbors := _placed_neighbor_count(index)
		if (
			best_index < 0
			or candidates.size() < best_candidates.size()
			or (
				candidates.size() == best_candidates.size()
				and placed_neighbors > best_placed_neighbors
			)
		):
			best_index = index
			best_candidates = candidates
			best_placed_neighbors = placed_neighbors
	return {"index": best_index, "candidates": best_candidates}


func _placed_neighbor_count(index: int) -> int:
	var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
	var count := 0
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var neighbor_coordinate := (
			coordinate
			+ TerrainChunkTopology.grid_offset(
				edge_value as TerrainChunkTopology.Edge
			)
		)
		if not _coordinate_is_inside_grid(neighbor_coordinate):
			continue
		var neighbor_index := (
			neighbor_coordinate.y * grid_size.x + neighbor_coordinate.x
		)
		if _placements[neighbor_index] != null:
			count += 1
	return count


func _propagate_domains(domains: Dictionary) -> bool:
	var changed := true
	while changed:
		changed = false
		for index_value: Variant in domains.keys():
			var index := int(index_value)
			var candidates: Array[TerrainChunkVariant] = []
			candidates.assign(domains[index])
			var supported: Array[TerrainChunkVariant] = []
			for candidate: TerrainChunkVariant in candidates:
				if _candidate_has_domain_support(candidate, index, domains):
					supported.append(candidate)
			if supported.is_empty():
				return false
			if supported.size() != candidates.size():
				domains[index] = supported
				changed = true
		var required_result := _constrain_required_domains(domains)
		if required_result < 0:
			return false
		if required_result > 0:
			changed = true
		if not _placed_neighbor_requirements_have_domain_support(domains):
			return false
	return true


func _candidate_has_domain_support(
	candidate: TerrainChunkVariant,
	index: int,
	domains: Dictionary,
) -> bool:
	var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
	var possible_required_neighbors := 0
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var edge := edge_value as TerrainChunkTopology.Edge
		var neighbor_coordinate := (
			coordinate + TerrainChunkTopology.grid_offset(edge)
		)
		if not _coordinate_is_inside_grid(neighbor_coordinate):
			continue
		var neighbor_index := (
			neighbor_coordinate.y * grid_size.x + neighbor_coordinate.x
		)
		var placed_neighbor := _placements[neighbor_index]
		if placed_neighbor != null:
			if _definition_matches_required_neighbor_tags(
				candidate.definition,
				placed_neighbor.definition,
			):
				possible_required_neighbors += 1
			continue
		var neighbor_candidates: Array[TerrainChunkVariant] = []
		neighbor_candidates.assign(domains.get(neighbor_index, []))
		var has_support := false
		var has_required_support := false
		for neighbor: TerrainChunkVariant in neighbor_candidates:
			if not _definitions_have_joint_capacity(
				candidate.definition,
				neighbor.definition,
			):
				continue
			if _edges_are_compatible(
				candidate,
				edge,
				neighbor,
				TerrainChunkTopology.opposite_edge(edge),
			):
				has_support = true
				if _definition_matches_required_neighbor_tags(
					candidate.definition,
					neighbor.definition,
				):
					has_required_support = true
		if not has_support:
			return false
		if has_required_support:
			possible_required_neighbors += 1
	return (
		possible_required_neighbors
		>= candidate.definition.minimum_required_neighbors
	)


func _placed_neighbor_requirements_have_domain_support(
	domains: Dictionary,
) -> bool:
	for index: int in _placements.size():
		var placement := _placements[index]
		if placement == null or placement.definition.minimum_required_neighbors <= 0:
			continue
		var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
		var possible_neighbors := 0
		for edge_value: int in TerrainChunkTopology.Edge.values():
			var edge := edge_value as TerrainChunkTopology.Edge
			var neighbor_coordinate := (
				coordinate + TerrainChunkTopology.grid_offset(edge)
			)
			if not _coordinate_is_inside_grid(neighbor_coordinate):
				continue
			var neighbor_index := (
				neighbor_coordinate.y * grid_size.x + neighbor_coordinate.x
			)
			var neighbor := _placements[neighbor_index]
			if neighbor != null:
				if _definition_matches_required_neighbor_tags(
					placement.definition,
					neighbor.definition,
				):
					possible_neighbors += 1
				continue
			var domain_candidates: Array[TerrainChunkVariant] = []
			domain_candidates.assign(domains.get(neighbor_index, []))
			for candidate: TerrainChunkVariant in domain_candidates:
				if (
					_definition_matches_required_neighbor_tags(
						placement.definition,
						candidate.definition,
					)
					and _edges_are_compatible(
						placement,
						edge,
						candidate,
						TerrainChunkTopology.opposite_edge(edge),
					)
				):
					possible_neighbors += 1
					break
		if possible_neighbors < placement.definition.minimum_required_neighbors:
			return false
	return true


func _definition_matches_required_neighbor_tags(
	definition: TerrainChunkDefinition,
	neighbor: TerrainChunkDefinition,
) -> bool:
	return (
		definition != null
		and neighbor != null
		and TerrainChunkDefinition.has_any_tag(
			neighbor.tags,
			definition.required_neighbor_tags,
		)
	)


func _definitions_have_joint_capacity(
	first: TerrainChunkDefinition,
	second: TerrainChunkDefinition,
) -> bool:
	if first != second or first.maximum_placements < 0:
		return true
	return (
		_definition_placement_count(first) + 2
		<= first.maximum_placements
	)


## Returns -1 for a contradiction, 0 for no change, or 1 when at least one
## required definition was forced into its only remaining cell.
func _constrain_required_domains(domains: Dictionary) -> int:
	var changed := false
	for stable_id: StringName in _missing_required_ids():
		var supporting_cells: Array[int] = []
		for index_value: Variant in domains:
			var index := int(index_value)
			for candidate: TerrainChunkVariant in domains[index]:
				if candidate.definition.stable_id == stable_id:
					supporting_cells.append(index)
					break
		if supporting_cells.is_empty():
			return -1
		if supporting_cells.size() != 1:
			continue
		var forced_index := supporting_cells[0]
		var forced_candidates: Array[TerrainChunkVariant] = []
		for candidate: TerrainChunkVariant in domains[forced_index]:
			if candidate.definition.stable_id == stable_id:
				forced_candidates.append(candidate)
		if forced_candidates.is_empty():
			return -1
		if forced_candidates.size() != domains[forced_index].size():
			domains[forced_index] = forced_candidates
			changed = true
	return 1 if changed else 0


func _compatible_candidates(index: int) -> Array[TerrainChunkVariant]:
	var result: Array[TerrainChunkVariant] = []
	var missing_required := _missing_required_ids()
	var remaining_cells := _unfilled_cell_count()
	var must_place_missing_required := missing_required.size() >= remaining_cells
	for candidate: TerrainChunkVariant in _solver_variants:
		if (
			must_place_missing_required
			and not missing_required.has(candidate.definition.stable_id)
		):
			continue
		if not _candidate_can_occupy_cell(candidate, index):
			continue
		result.append(candidate)
	return result


func _candidate_can_occupy_cell(
	candidate: TerrainChunkVariant,
	index: int,
) -> bool:
	if not _definition_has_capacity(candidate.definition):
		return false
	var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
	if (
		_elevated_feature_reserved_grass_indices.has(index)
		and candidate.definition.stable_id != elevated_cliff_base_chunk_id
	):
		return false
	var center := Vector2i(grid_size.x / 2, grid_size.y / 2)
	var center_index := center.y * grid_size.x + center.x
	if (
		coordinate == center
		and force_center_chunk_id != &""
		and candidate.definition.stable_id != force_center_chunk_id
	):
		return false
	if (
		index != center_index
		and _placements[center_index] == null
		and candidate.definition.stable_id == force_center_chunk_id
		and candidate.definition.maximum_placements >= 0
		and _definition_placement_count(candidate.definition)
		>= candidate.definition.maximum_placements - 1
	):
		return false
	return (
		_variant_respects_ocean_boundary(candidate, coordinate)
		and _candidate_matches_placed_neighbors(candidate, coordinate)
		and _candidate_neighbor_requirement_can_still_be_met(
			candidate.definition,
			coordinate,
		)
		and _candidate_preserves_placed_neighbor_requirements(
			candidate.definition,
			coordinate,
		)
	)


func _prepare_elevated_feature_region() -> bool:
	_elevated_feature_center = Vector2i(-1, -1)
	_elevated_feature_reserved_grass_indices.clear()
	if not elevated_cliff_feature_enabled:
		return true
	for stable_id: StringName in [
		elevated_cliff_base_chunk_id,
		elevated_cliff_top_chunk_id,
		elevated_cliff_corner_chunk_id,
		elevated_cliff_edge_chunk_id,
		elevated_cliff_ramp_chunk_id,
	]:
		if catalog.definition_for_id(stable_id) == null:
			push_error("Elevated cliff feature references missing chunk %s." % stable_id)
			return false
	if grid_size.x < 11 or grid_size.y < 9:
		push_error(
			"Elevated cliff feature requires at least an 11x9 terrain grid."
		)
		return false
	var forced_center := Vector2i(grid_size.x / 2, grid_size.y / 2)
	var candidates: Array[Vector2i] = []
	for row: int in range(2, grid_size.y - 2):
		for column: int in range(2, grid_size.x - 2):
			var candidate := Vector2i(column, row)
			if (
				absi(candidate.x - forced_center.x) <= 2
				and absi(candidate.y - forced_center.y) <= 2
			):
				continue
			candidates.append(candidate)
	if candidates.is_empty():
		push_error("Terrain grid has no inland 3x3 cliff feature location.")
		return false
	var feature_random := RandomNumberGenerator.new()
	feature_random.seed = generation_seed ^ 0x2E1E7A7ED
	_elevated_feature_center = candidates[
		feature_random.randi_range(0, candidates.size() - 1)
	]
	# Solve the authored 3x3 cliff assembly into a one-cell ring of ordinary
	# level-one flat grass. Every raised piece still occupies one of the inner
	# nine grass cells; the outer ring prevents a stream, pond, or coast profile
	# from being exposed directly against its downhill edge.
	for row_offset: int in range(-2, 3):
		for column_offset: int in range(-2, 3):
			var coordinate := (
				_elevated_feature_center
				+ Vector2i(column_offset, row_offset)
			)
			_elevated_feature_reserved_grass_indices[
				coordinate.y * grid_size.x + coordinate.x
			] = true
	return true


func _apply_elevated_feature() -> bool:
	if not elevated_cliff_feature_enabled:
		return true
	if _elevated_feature_center.x < 0 or _elevated_feature_center.y < 0:
		push_error("Elevated cliff feature has no reserved base region.")
		return false
	var edge_specs: Array[Dictionary] = [
		{"offset": Vector2i(0, -1), "turns": 1},
		{"offset": Vector2i(1, 0), "turns": 0},
		{"offset": Vector2i(0, 1), "turns": 3},
		{"offset": Vector2i(-1, 0), "turns": 2},
	]
	var feature_random := RandomNumberGenerator.new()
	feature_random.seed = generation_seed ^ 0x51A7C11FF
	var ramp_edge := -1
	if feature_random.randf() < elevated_cliff_ramp_chance:
		ramp_edge = feature_random.randi_range(0, edge_specs.size() - 1)
	var placements: Array[Dictionary] = [
		{"offset": Vector2i(-1, -1), "id": elevated_cliff_corner_chunk_id, "turns": 2},
		{"offset": Vector2i(1, -1), "id": elevated_cliff_corner_chunk_id, "turns": 1},
		{"offset": Vector2i(0, 0), "id": elevated_cliff_top_chunk_id, "turns": 0},
		{"offset": Vector2i(-1, 1), "id": elevated_cliff_corner_chunk_id, "turns": 3},
		{"offset": Vector2i(1, 1), "id": elevated_cliff_corner_chunk_id, "turns": 0},
	]
	for edge_index: int in edge_specs.size():
		var edge_spec := edge_specs[edge_index]
		placements.append({
			"offset": edge_spec["offset"],
			"id": (
				elevated_cliff_ramp_chunk_id
				if edge_index == ramp_edge
				else elevated_cliff_edge_chunk_id
			),
			"turns": edge_spec["turns"],
		})
	for spec: Dictionary in placements:
		var definition := catalog.definition_for_id(spec["id"] as StringName)
		var variant := _authored_variant(definition, int(spec["turns"]))
		if variant == null:
			push_error(
				"Elevated cliff feature cannot resolve %s rotation %d."
				% [spec["id"], spec["turns"]]
			)
			return false
		var coordinate := _elevated_feature_center + (spec["offset"] as Vector2i)
		_placements[coordinate.y * grid_size.x + coordinate.x] = variant
	var validation_error := _resolved_layout_validation_error(_placements)
	if not validation_error.is_empty():
		push_error("Elevated cliff feature is invalid: " + validation_error)
		return false
	return true


func _variant_respects_ocean_boundary(
	variant: TerrainChunkVariant,
	coordinate: Vector2i,
) -> bool:
	if (
		variant.definition.must_be_interior
		and _coordinate_is_on_boundary(coordinate)
	):
		return false
	var ocean_edges := variant.rotated_edge_mask(
		variant.definition.ocean_facing_edges
	)
	for edge_value: int in TerrainChunkTopology.Edge.values():
		if (ocean_edges & (1 << edge_value)) == 0:
			continue
		var ocean_coordinate := (
			coordinate
			+ TerrainChunkTopology.grid_offset(
				edge_value as TerrainChunkTopology.Edge
			)
		)
		if _coordinate_is_inside_grid(ocean_coordinate):
			return false
	return true


func _candidate_matches_placed_neighbors(
	candidate: TerrainChunkVariant,
	coordinate: Vector2i,
) -> bool:
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var edge := edge_value as TerrainChunkTopology.Edge
		var neighbor_coordinate := (
			coordinate + TerrainChunkTopology.grid_offset(edge)
		)
		if not _coordinate_is_inside_grid(neighbor_coordinate):
			continue
		var neighbor_index := (
			neighbor_coordinate.y * grid_size.x + neighbor_coordinate.x
		)
		var neighbor := _placements[neighbor_index]
		if neighbor == null:
			continue
		if not _edges_are_compatible(
			candidate,
			edge,
			neighbor,
			TerrainChunkTopology.opposite_edge(edge),
		):
			return false
	return true


func _coordinate_is_inside_grid(coordinate: Vector2i) -> bool:
	return (
		coordinate.x >= 0
		and coordinate.y >= 0
		and coordinate.x < grid_size.x
		and coordinate.y < grid_size.y
	)


func _candidate_neighbor_requirement_can_still_be_met(
	definition: TerrainChunkDefinition,
	coordinate: Vector2i,
) -> bool:
	if definition.minimum_required_neighbors <= 0:
		return true
	var possible_neighbors := 0
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var neighbor_coordinate := (
			coordinate
			+ TerrainChunkTopology.grid_offset(
				edge_value as TerrainChunkTopology.Edge
			)
		)
		if not _coordinate_is_inside_grid(neighbor_coordinate):
			continue
		var neighbor := _placements[
			neighbor_coordinate.y * grid_size.x + neighbor_coordinate.x
		]
		if (
			neighbor == null
			or _definition_matches_required_neighbor_tags(
				definition,
				neighbor.definition,
			)
		):
			possible_neighbors += 1
	return possible_neighbors >= definition.minimum_required_neighbors


func _candidate_preserves_placed_neighbor_requirements(
	definition: TerrainChunkDefinition,
	coordinate: Vector2i,
) -> bool:
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var neighbor_coordinate := (
			coordinate
			+ TerrainChunkTopology.grid_offset(
				edge_value as TerrainChunkTopology.Edge
			)
		)
		if not _coordinate_is_inside_grid(neighbor_coordinate):
			continue
		var neighbor := _placements[
			neighbor_coordinate.y * grid_size.x + neighbor_coordinate.x
		]
		if neighbor == null or neighbor.definition.minimum_required_neighbors <= 0:
			continue
		if not _placed_requirement_can_still_be_met_with_candidate(
			neighbor.definition,
			neighbor_coordinate,
			definition,
			coordinate,
		):
			return false
	return true


func _placed_requirement_can_still_be_met_with_candidate(
	definition: TerrainChunkDefinition,
	coordinate: Vector2i,
	candidate_definition: TerrainChunkDefinition,
	candidate_coordinate: Vector2i,
) -> bool:
	var possible_neighbors := 0
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var neighbor_coordinate := (
			coordinate
			+ TerrainChunkTopology.grid_offset(
				edge_value as TerrainChunkTopology.Edge
			)
		)
		if not _coordinate_is_inside_grid(neighbor_coordinate):
			continue
		if neighbor_coordinate == candidate_coordinate:
			if _definition_matches_required_neighbor_tags(
				definition,
				candidate_definition,
			):
				possible_neighbors += 1
			continue
		var neighbor := _placements[
			neighbor_coordinate.y * grid_size.x + neighbor_coordinate.x
		]
		if (
			neighbor == null
			or _definition_matches_required_neighbor_tags(
				definition,
				neighbor.definition,
			)
		):
			possible_neighbors += 1
	return possible_neighbors >= definition.minimum_required_neighbors


func _definition_has_capacity(definition: TerrainChunkDefinition) -> bool:
	if definition.maximum_placements < 0:
		return true
	return _definition_placement_count(definition) < definition.maximum_placements


func _definition_placement_count(definition: TerrainChunkDefinition) -> int:
	var count := 0
	for placement: TerrainChunkVariant in _placements:
		if placement != null and placement.definition == definition:
			count += 1
	return count


func _edges_are_compatible(
	first: TerrainChunkVariant,
	first_edge: TerrainChunkTopology.Edge,
	second: TerrainChunkVariant,
	second_edge: TerrainChunkTopology.Edge,
) -> bool:
	if (
		second_edge == TerrainChunkTopology.opposite_edge(first_edge)
		and _solver_variant_indices.has(first)
		and _solver_variant_indices.has(second)
	):
		var cache_index := _edge_compatibility_index(
			int(_solver_variant_indices[first]),
			first_edge,
			int(_solver_variant_indices[second]),
		)
		return _edge_compatibility[cache_index] != 0
	return _calculate_edge_compatibility(
		first,
		first_edge,
		second,
		second_edge,
	)


func _calculate_edge_compatibility(
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
	if first_has_water or second_has_water:
		return (
			(first_outlet and second_inlet)
			or (first_inlet and second_outlet)
		)
	return (
		first.allows_non_water_neighbor_on_edge(second, first_edge)
		and second.allows_non_water_neighbor_on_edge(first, second_edge)
	)


func _variant_edge_has_connector(
	variant: TerrainChunkVariant,
	source_mask: int,
	edge: TerrainChunkTopology.Edge,
) -> bool:
	return (variant.rotated_edge_mask(source_mask) & (1 << int(edge))) != 0


func _required_chunks_are_present() -> bool:
	return _missing_required_ids().is_empty()


func _requirements_can_still_be_satisfied() -> bool:
	var missing_required := _missing_required_ids()
	if missing_required.size() > _unfilled_cell_count():
		return false
	for stable_id: StringName in missing_required:
		var definition := catalog.definition_for_id(stable_id)
		if definition == null or not _definition_has_capacity(definition):
			return false
		if not _definition_has_available_cell(definition):
			return false
	return true


func _definition_has_available_cell(
	definition: TerrainChunkDefinition,
) -> bool:
	for index: int in _placements.size():
		if _placements[index] != null:
			continue
		for candidate: TerrainChunkVariant in _solver_variants:
			if (
				candidate.definition == definition
				and _candidate_can_occupy_cell(candidate, index)
			):
				return true
	return false


func _unfilled_cell_count() -> int:
	var count := 0
	for placement: TerrainChunkVariant in _placements:
		if placement == null:
			count += 1
	return count


func _missing_required_ids() -> Array[StringName]:
	var found: Dictionary[StringName, bool] = {}
	for placement: TerrainChunkVariant in _placements:
		if placement != null:
			found[placement.definition.stable_id] = true
	var result: Array[StringName] = []
	for required_id_value: String in required_chunk_ids:
		var required_id := StringName(required_id_value)
		if not found.has(required_id) and not result.has(required_id):
			result.append(required_id)
	return result


func _weighted_candidate_order(
	candidates: Array[TerrainChunkVariant],
	index: int,
) -> Array[TerrainChunkVariant]:
	var candidate_counts: Dictionary[StringName, int] = {}
	for candidate: TerrainChunkVariant in candidates:
		var stable_id := candidate.definition.stable_id
		candidate_counts[stable_id] = candidate_counts.get(stable_id, 0) + 1
	var remaining: Array[TerrainChunkVariant] = []
	var weight_units: Array[int] = []
	for candidate: TerrainChunkVariant in candidates:
		var stable_id := candidate.definition.stable_id
		var rotation_count := maxi(candidate_counts.get(stable_id, 1), 1)
		var weight := (
			maxf(candidate.definition.selection_weight, 0.01)
			/ float(rotation_count)
		)
		if _required_chunk_is_missing(candidate.definition.stable_id):
			weight *= required_chunk_weight_multiplier
		var preferred_neighbors := _preferred_neighbor_count(
			index,
			candidate.definition,
		)
		for _preferred_index: int in preferred_neighbors:
			weight *= preferred_neighbor_weight_multiplier
		for _repeat_index: int in _long_definition_run_count(
			index,
			candidate.definition,
		):
			weight *= long_repeat_weight_multiplier
		if (
			candidate.definition.prefers_map_boundary
			and _coordinate_is_on_boundary(
				Vector2i(index % grid_size.x, index / grid_size.x)
			)
		):
			weight *= boundary_preference_multiplier
		remaining.append(candidate)
		weight_units.append(
			maxi(roundi(weight * CANDIDATE_WEIGHT_SCALE), 1)
		)
	var result: Array[TerrainChunkVariant] = []
	while not remaining.is_empty():
		var total_units := 0
		for units: int in weight_units:
			total_units += units
		var ticket := _random.randi_range(1, total_units)
		var accumulated := 0
		var selected_index := 0
		for candidate_index: int in remaining.size():
			accumulated += weight_units[candidate_index]
			if ticket <= accumulated:
				selected_index = candidate_index
				break
		result.append(remaining[selected_index])
		remaining.remove_at(selected_index)
		weight_units.remove_at(selected_index)
	return result


func _adjacent_definition_repeat_count(
	index: int,
	definition: TerrainChunkDefinition,
) -> int:
	var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
	var count := 0
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var edge := edge_value as TerrainChunkTopology.Edge
		var neighbor_coordinate := (
			coordinate + TerrainChunkTopology.grid_offset(edge)
		)
		if not _coordinate_is_inside_grid(neighbor_coordinate):
			continue
		var neighbor := _placements[
			neighbor_coordinate.y * grid_size.x + neighbor_coordinate.x
		]
		if neighbor != null and neighbor.definition == definition:
			count += 1
	return count


func _preferred_neighbor_count(
	index: int,
	definition: TerrainChunkDefinition,
) -> int:
	var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
	var count := 0
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var edge := edge_value as TerrainChunkTopology.Edge
		var neighbor_coordinate := (
			coordinate + TerrainChunkTopology.grid_offset(edge)
		)
		if not _coordinate_is_inside_grid(neighbor_coordinate):
			continue
		var neighbor := _placements[
			neighbor_coordinate.y * grid_size.x + neighbor_coordinate.x
		]
		if neighbor != null and definition.prefers_neighbor(neighbor.definition):
			count += 1
	return count


func _long_definition_run_count(
	index: int,
	definition: TerrainChunkDefinition,
) -> int:
	var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
	var count := 0
	for axis: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
		if (
			_definition_at(coordinate - axis) == definition
			and _definition_at(coordinate + axis) == definition
		):
			count += 1
		for direction: int in [-1, 1]:
			if (
				_definition_at(coordinate + axis * direction) == definition
				and _definition_at(coordinate + axis * direction * 2)
				== definition
			):
				count += 1
	return count


func _definition_at(coordinate: Vector2i) -> TerrainChunkDefinition:
	if not _coordinate_is_inside_grid(coordinate):
		return null
	var placement := _placements[coordinate.y * grid_size.x + coordinate.x]
	return placement.definition if placement != null else null


func _coordinate_is_on_boundary(coordinate: Vector2i) -> bool:
	return (
		coordinate.x == 0
		or coordinate.y == 0
		or coordinate.x == grid_size.x - 1
		or coordinate.y == grid_size.y - 1
	)


func _neighbor_requirement_validation_error(
	layout: Array[TerrainChunkVariant],
) -> String:
	for index: int in layout.size():
		var placement := layout[index]
		if placement == null or placement.definition.minimum_required_neighbors <= 0:
			continue
		var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
		var matching_neighbors := 0
		for edge_value: int in TerrainChunkTopology.Edge.values():
			var neighbor_coordinate := (
				coordinate
				+ TerrainChunkTopology.grid_offset(
					edge_value as TerrainChunkTopology.Edge
				)
			)
			if not _coordinate_is_inside_grid(neighbor_coordinate):
				continue
			var neighbor := layout[
				neighbor_coordinate.y * grid_size.x + neighbor_coordinate.x
			]
			if (
				neighbor != null
				and _definition_matches_required_neighbor_tags(
					placement.definition,
					neighbor.definition,
				)
			):
				matching_neighbors += 1
		if matching_neighbors < placement.definition.minimum_required_neighbors:
			return (
				"%s at cell %d has %d required neighbors; expected at least %d."
				% [
					placement.definition.stable_id,
					index,
					matching_neighbors,
					placement.definition.minimum_required_neighbors,
				]
			)
	return ""


func _walkable_connectivity_validation_error(
	layout: Array[TerrainChunkVariant],
) -> String:
	var walkable_indices: Array[int] = []
	for index: int in layout.size():
		var placement := layout[index]
		if placement != null and "walkable" in placement.definition.tags:
			walkable_indices.append(index)
	if walkable_indices.is_empty():
		return ""
	var start_index := walkable_indices[0]
	if force_center_chunk_id != &"":
		var center := Vector2i(grid_size.x / 2, grid_size.y / 2)
		var center_index := center.y * grid_size.x + center.x
		if (
			layout[center_index] != null
			and "walkable" in layout[center_index].definition.tags
		):
			start_index = center_index
	var visited: Dictionary[int, bool] = {start_index: true}
	var pending: Array[int] = [start_index]
	var pending_cursor := 0
	while pending_cursor < pending.size():
		var index := pending[pending_cursor]
		pending_cursor += 1
		var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
		var current := layout[index]
		for edge_value: int in TerrainChunkTopology.Edge.values():
			var edge := edge_value as TerrainChunkTopology.Edge
			var neighbor_coordinate := (
				coordinate + TerrainChunkTopology.grid_offset(edge)
			)
			if not _coordinate_is_inside_grid(neighbor_coordinate):
				continue
			var neighbor_index := (
				neighbor_coordinate.y * grid_size.x + neighbor_coordinate.x
			)
			if visited.has(neighbor_index):
				continue
			var neighbor := layout[neighbor_index]
			if neighbor == null or "walkable" not in neighbor.definition.tags:
				continue
			if not _edges_are_compatible(
				current,
				edge,
				neighbor,
				TerrainChunkTopology.opposite_edge(edge),
			):
				continue
			visited[neighbor_index] = true
			pending.append(neighbor_index)
	if visited.size() != walkable_indices.size():
		return (
			"walkable terrain is split into disconnected regions "
			+ "(%d of %d cells reachable from spawn)."
			% [visited.size(), walkable_indices.size()]
		)
	return ""


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


func _resolve_equivalent_rotations() -> void:
	for index: int in _placements.size():
		var placement := _placements[index]
		if placement == null:
			continue
		var rotations: PackedInt32Array = _equivalent_rotations.get(
			_constraint_key(placement),
			PackedInt32Array([placement.quarter_turns]),
		)
		if rotations.size() <= 1:
			continue
		var selected_turns := _least_repeated_equivalent_rotation(
			index,
			placement.definition,
			rotations,
		)
		var resolved := _authored_variant(
			placement.definition,
			selected_turns,
		)
		if resolved != null:
			_placements[index] = resolved


func _least_repeated_equivalent_rotation(
	index: int,
	definition: TerrainChunkDefinition,
	rotations: PackedInt32Array,
) -> int:
	var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
	var best_score := 3
	var best_rotations := PackedInt32Array()
	for turns: int in rotations:
		var score := 0
		for neighbor_coordinate: Vector2i in [
			coordinate + Vector2i.LEFT,
			coordinate + Vector2i.UP,
		]:
			if not _coordinate_is_inside_grid(neighbor_coordinate):
				continue
			var neighbor := _placements[
				neighbor_coordinate.y * grid_size.x + neighbor_coordinate.x
			]
			if (
				neighbor != null
				and neighbor.definition == definition
				and neighbor.quarter_turns == turns
			):
				score += 1
		if score < best_score:
			best_score = score
			best_rotations = PackedInt32Array([turns])
		elif score == best_score:
			best_rotations.append(turns)
	return best_rotations[_random.randi_range(0, best_rotations.size() - 1)]


func _authored_variant(
	definition: TerrainChunkDefinition,
	quarter_turns: int,
) -> TerrainChunkVariant:
	for variant: TerrainChunkVariant in _variants:
		if (
			variant.definition == definition
			and variant.quarter_turns == quarter_turns
		):
			return variant
	return null


func _build_solution_root() -> Node3D:
	var solution_root := Node3D.new()
	solution_root.name = "GeneratedChunks"
	var half_grid := Vector2(
		float(grid_size.x - 1) * 0.5,
		float(grid_size.y - 1) * 0.5,
	)
	for index: int in _placements.size():
		var variant := _placements[index]
		if variant == null:
			continue
		var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
		var chunk_root := _instantiate_chunk_root(variant.definition)
		if chunk_root == null:
			push_error("%s does not instantiate as Node3D." % variant.stable_key())
			solution_root.free()
			return null
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
		chunk_root.set_meta(&"terrain_chunk_coordinate", coordinate)
		chunk_root.set_meta(
			&"terrain_chunk_id",
			variant.definition.stable_id,
		)
		solution_root.add_child(chunk_root)
		if build_collision:
			_add_collision(chunk_root, variant.definition)
		if show_chunk_labels:
			_add_chunk_label(chunk_root, variant)
	return solution_root


func _instantiate_chunk_root(
	definition: TerrainChunkDefinition,
) -> Node3D:
	var terrain_visual := definition.packed_scene.instantiate() as Node3D
	if terrain_visual == null:
		return null
	if definition.base_layer_scene == null:
		return terrain_visual
	var base_layer_visual := definition.base_layer_scene.instantiate() as Node3D
	if base_layer_visual == null:
		terrain_visual.free()
		return null
	var layered_root := Node3D.new()
	layered_root.name = "LayeredTerrainChunk"
	base_layer_visual.name = "TerrainBaseLayer"
	terrain_visual.name = "TerrainOverlay"
	layered_root.add_child(base_layer_visual)
	layered_root.add_child(terrain_visual)
	return layered_root


func _replace_generated_chunks(solution_root: Node3D) -> void:
	_clear_generated_chunks()
	_generated_chunks = solution_root
	add_child(_generated_chunks)


func _add_collision(
	chunk_root: Node3D,
	definition: TerrainChunkDefinition,
) -> void:
	var primary_mesh := TerrainChunkAnalyzer.find_primary_mesh(
		chunk_root,
		definition.primary_mesh_name,
	)
	_add_collision_to_mesh(
		primary_mesh,
		definition.stable_id,
		"TerrainCollision",
	)
	if definition.base_layer_scene == null:
		return
	var base_layer_mesh := TerrainChunkAnalyzer.find_primary_mesh(
		chunk_root,
		definition.base_layer_mesh_name,
	)
	_add_collision_to_mesh(
		base_layer_mesh,
		definition.stable_id,
		"TerrainBaseLayerCollision",
	)


func _add_collision_to_mesh(
	primary_mesh: MeshInstance3D,
	stable_id: StringName,
	collision_name: String,
) -> void:
	if primary_mesh == null or primary_mesh.mesh == null:
		return
	var terrain_shape := primary_mesh.mesh.create_trimesh_shape()
	if terrain_shape == null or terrain_shape.get_faces().is_empty():
		push_warning("%s produced no terrain collision." % stable_id)
		return
	var concave_shape := terrain_shape as ConcavePolygonShape3D
	if concave_shape != null:
		# Authored terrain can expose cliff walls and transitional surfaces with
		# mixed winding. Treat both sides as solid so a visible walkable surface
		# can never become an invisible collision gap.
		concave_shape.backface_collision = true
	var collision_body := StaticBody3D.new()
	collision_body.name = collision_name
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
	var variant_counts: Dictionary[StringName, int] = {}
	for variant: TerrainChunkVariant in _variants:
		var variant_id := variant.definition.stable_id
		variant_counts[variant_id] = variant_counts.get(variant_id, 0) + 1
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
		"solver_variant_count": _solver_variants.size(),
		"compatible_edge_pairs": _compatible_edge_pair_count(),
		"backtracks": _backtrack_count,
		"adjacent_repeat_edges": _count_adjacent_repeat_edges(),
		"counts": counts,
		"variant_counts": variant_counts,
		"placements": placement_keys(),
		"layout_fingerprint": placement_fingerprint(),
	}


func _compatible_edge_pair_count() -> int:
	var count := 0
	for compatible: int in _edge_compatibility:
		if compatible != 0:
			count += 1
	return count


func _count_adjacent_repeat_edges() -> int:
	var count := 0
	for index: int in _placements.size():
		var current := _placements[index]
		if current == null:
			continue
		var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
		if coordinate.x > 0:
			var west := _placements[index - 1]
			if west != null and west.definition == current.definition:
				count += 1
		if coordinate.y > 0:
			var north := _placements[index - grid_size.x]
			if north != null and north.definition == current.definition:
				count += 1
	return count


func placement_keys() -> PackedStringArray:
	var result := PackedStringArray()
	for variant: TerrainChunkVariant in _placements:
		result.append(variant.stable_key() if variant != null else "empty")
	return result


func placement_fingerprint() -> String:
	var fingerprint_input := PackedStringArray([
		"grid:%dx%d" % [grid_size.x, grid_size.y],
		"chunk_size:%.6f" % (catalog.chunk_size if catalog != null else 0.0),
	])
	fingerprint_input.append_array(placement_keys())
	return "\n".join(fingerprint_input).sha256_text()


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
			"ocean_facing_edges": variant.rotated_edge_mask(
				variant.definition.ocean_facing_edges
			),
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


func get_primary_terrain_meshes() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if not is_instance_valid(_generated_chunks):
		return result
	var chunk_count := mini(
		_generated_chunks.get_child_count(),
		_placements.size(),
	)
	for index: int in chunk_count:
		var placement := _placements[index]
		var chunk_root := _generated_chunks.get_child(index)
		if placement == null or chunk_root == null:
			continue
		var primary_mesh := TerrainChunkAnalyzer.find_primary_mesh(
			chunk_root,
			placement.definition.primary_mesh_name,
		)
		if primary_mesh != null and primary_mesh.mesh != null:
			result.append(primary_mesh)
	return result
