class_name TerrainChunkGenerator
extends Node3D

signal generation_completed(summary: Dictionary)

const CONSTRAINT_PROFILE_QUANTIZATION := 0.001
const CANDIDATE_WEIGHT_SCALE := 10000.0
const LARGE_GRID_LIGHTWEIGHT_THRESHOLD := 128
const LARGE_GRID_PROPAGATION_INTERVAL := 8
const ELEVATED_FEATURE_RADIUS := 2
const ELEVATED_FEATURE_CLEARANCE_RADIUS := ELEVATED_FEATURE_RADIUS + 1
const ELEVATED_FEATURE_BOUNDARY_MARGIN := ELEVATED_FEATURE_CLEARANCE_RADIUS + 1
const SECONDARY_ELEVATED_FEATURE_RADIUS := 1
const SECONDARY_ELEVATED_FEATURE_CLEARANCE_RADIUS := (
	SECONDARY_ELEVATED_FEATURE_RADIUS + 1
)
# Keep packed domain bits below the signed 64-bit sign bit. Catalogs larger
# than this remain correct through the unpacked solver path.
const MAX_PACKED_SOLVER_VARIANTS := 62

@export var catalog: TerrainChunkCatalog
@export var grid_size := Vector2i(7, 7)
@export var generation_seed := 13001
@export var generate_on_ready := true
@export var build_collision := true
@export var show_chunk_labels := false
@export var force_center_chunk_id: StringName = &"chunk_0000"
@export var required_chunk_ids := PackedStringArray()
@export_group("Grass-Sand Smoothing")
@export var grass_sand_smoothing_enabled := false
@export var smoothing_grass_chunk_id: StringName = &"chunk_0000"
@export var smoothing_sand_chunk_id: StringName = &"chunk_0001"
@export var smoothing_diagonal_chunk_id: StringName = &"chunk_0013"
@export_range(1, 64, 1) var maximum_smoothing_placements := 16
@export_group("")
@export_group("Elevated Inland Feature")
@export var elevated_cliff_feature_enabled := false
@export var elevated_cliff_base_chunk_id: StringName = &"chunk_0000"
@export var elevated_cliff_top_chunk_id: StringName = &"chunk_0009"
@export var elevated_cliff_corner_chunk_id: StringName = &"chunk_0010"
@export var elevated_cliff_edge_chunk_id: StringName = &"chunk_0011"
@export var elevated_cliff_ramp_chunk_id: StringName = &"chunk_0012"
@export var elevated_cliff_sea_edge_chunk_id: StringName = &"chunk_0014"
@export var elevated_cliff_sea_corner_chunk_id: StringName = &"chunk_0015"
@export var elevated_cliff_sea_transition_right_chunk_id: StringName = &"chunk_0017"
@export var elevated_cliff_sea_transition_left_chunk_id: StringName = &"chunk_0018"
@export var elevated_cliff_coast_base_chunk_id: StringName = &"chunk_0005"
@export_range(0.0, 1.0, 0.05) var elevated_cliff_ramp_chance := 1.0
## A smaller third tier reuses the existing corner geometry at the authored
## two-meter level interval. It is nested into the lower cliff assembly rather
## than occupying or replacing additional terrain-grid cells.
@export_range(0.0, 1.0, 0.05) var elevated_cliff_third_level_chance := 0.7
@export_range(0.1, 10.0, 0.1) var elevated_cliff_level_height := 2.0
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
var _solver_definitions: Array[TerrainChunkDefinition] = []
var _solver_variants_by_definition: Dictionary[StringName, Array] = {}
var _definition_variant_masks: Dictionary[StringName, int] = {}
var _required_neighbor_variant_masks: Dictionary[StringName, int] = {}
var _equivalent_rotations: Dictionary[String, PackedInt32Array] = {}
var _solver_variant_indices: Dictionary = {}
var _edge_compatibility := PackedByteArray()
var _edge_compatibility_masks := PackedInt64Array()
var _static_cell_candidate_masks := PackedInt64Array()
var _neighbor_indices: Array[PackedInt32Array] = []
var _placements: Array[TerrainChunkVariant] = []
var _placement_counts: Dictionary[StringName, int] = {}
var _unfilled_cells := 0
var _required_stable_ids: Array[StringName] = []
var _selection_missing_required_count := 0
var _selection_missing_required_mask := 0
var _random := RandomNumberGenerator.new()
var _generated_chunks: Node3D
var _backtrack_count := 0
var _elevated_feature_center := Vector2i(-1, -1)
var _secondary_elevated_feature_center := Vector2i(-1, -1)
var _elevated_feature_reserved_grass_indices: Dictionary[int, bool] = {}
var _stacked_elevated_placements: Array[Dictionary] = []


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
	_reset_placements(grid_size.x * grid_size.y)
	if not _prepare_elevated_feature_region():
		_assign_placements(previous_placements)
		return false
	if not _solve_cell(0):
		_assign_placements(previous_placements)
		push_error(
			"Terrain generation could not solve a %dx%d grid with seed %d."
			% [grid_size.x, grid_size.y, generation_seed]
		)
		return false
	_resolve_equivalent_rotations()
	if not _apply_grass_sand_smoothing():
		_assign_placements(previous_placements)
		return false
	if not _apply_elevated_feature():
		_assign_placements(previous_placements)
		return false
	if not _configure_stacked_elevated_feature():
		_assign_placements(previous_placements)
		return false
	var solution_root := _build_solution_root()
	if solution_root == null:
		_assign_placements(previous_placements)
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
	_assign_placements(resolved)
	_backtrack_count = 0
	if not _configure_stacked_elevated_feature():
		_assign_placements(previous_placements)
		return false
	var solution_root := _build_solution_root()
	if solution_root == null:
		_assign_placements(previous_placements)
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
				"cell %d does not exactly match the authored ocean boundary."
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
	_solver_definitions.clear()
	_solver_variants_by_definition.clear()
	_definition_variant_masks.clear()
	_required_neighbor_variant_masks.clear()
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
			if (
				definition.overlay_only
				or not definition.participates_in_base_solver
			):
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
		var variant := _solver_variants[index]
		_solver_variant_indices[variant] = index
		var definition_variants: Array = _solver_variants_by_definition.get(
			variant.definition.stable_id,
			[],
		)
		definition_variants.append(variant)
		if definition_variants.size() == 1:
			_solver_definitions.append(variant.definition)
		_solver_variants_by_definition[
			variant.definition.stable_id
		] = definition_variants
		if index < MAX_PACKED_SOLVER_VARIANTS:
			_definition_variant_masks[variant.definition.stable_id] = (
				int(
					_definition_variant_masks.get(
						variant.definition.stable_id,
						0,
					)
				)
				| (1 << index)
			)
	_build_edge_compatibility_cache()
	return true


func _reset_placements(cell_count: int) -> void:
	_placements.clear()
	_placements.resize(cell_count)
	_placement_counts.clear()
	_unfilled_cells = cell_count


func _assign_placements(layout: Array[TerrainChunkVariant]) -> void:
	_placements.assign(layout)
	_rebuild_placement_tracking()


func _rebuild_placement_tracking() -> void:
	_placement_counts.clear()
	_unfilled_cells = 0
	for placement: TerrainChunkVariant in _placements:
		if placement == null:
			_unfilled_cells += 1
			continue
		_adjust_placement_count(placement.definition.stable_id, 1)


func _set_placement(index: int, placement: TerrainChunkVariant) -> void:
	var previous := _placements[index]
	if previous == placement:
		return
	if previous == null:
		_unfilled_cells -= 1
	else:
		_adjust_placement_count(previous.definition.stable_id, -1)
	_placements[index] = placement
	if placement == null:
		_unfilled_cells += 1
	else:
		_adjust_placement_count(placement.definition.stable_id, 1)


func _adjust_placement_count(stable_id: StringName, difference: int) -> void:
	var updated := int(_placement_counts.get(stable_id, 0)) + difference
	if updated <= 0:
		_placement_counts.erase(stable_id)
		return
	_placement_counts[stable_id] = updated


func _constraint_key(variant: TerrainChunkVariant) -> String:
	return "%s|%s" % [
		variant.definition.stable_id,
		variant.constraint_signature(CONSTRAINT_PROFILE_QUANTIZATION),
	]


func _build_edge_compatibility_cache() -> void:
	var variant_count := _solver_variants.size()
	_edge_compatibility.resize(variant_count * 4 * variant_count)
	_edge_compatibility.fill(0)
	_edge_compatibility_masks.resize(
		variant_count * 4 if _packed_solver_domains_are_available() else 0
	)
	_edge_compatibility_masks.fill(0)
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
				var compatible := _calculate_edge_compatibility(
					first,
					first_edge,
					second,
					second_edge,
				)
				_edge_compatibility[cache_index] = int(compatible)
				if compatible and _packed_solver_domains_are_available():
					var mask_index := first_index * 4 + int(first_edge)
					_edge_compatibility_masks[mask_index] = (
						_edge_compatibility_masks[mask_index]
						| (1 << second_index)
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
	_required_stable_ids.clear()
	for required_id_value: String in required_chunk_ids:
		var required_id := StringName(required_id_value)
		if seen_required.has(required_id):
			continue
		seen_required[required_id] = true
		_required_stable_ids.append(required_id)
		var definition := catalog.definition_for_id(required_id)
		if definition == null:
			push_error("Required terrain chunk %s is not in the catalog." % required_id)
			return false
		if definition.maximum_placements == 0:
			push_error("Required terrain chunk %s permits no placements." % required_id)
			return false
		if (
			definition.overlay_only
			or not definition.participates_in_base_solver
		):
			push_error(
				"Required terrain chunk %s does not participate in the base solver."
				% required_id
			)
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
	_refresh_selection_required_cache()
	if not _requirements_can_still_be_satisfied():
		return false
	var next_cell := _select_next_cell(placed_count)
	var index := int(next_cell.get("index", -1))
	if index < 0:
		return false
	var candidates: Array[TerrainChunkVariant] = []
	candidates.assign(next_cell.get("candidates", []))
	for candidate: TerrainChunkVariant in _weighted_candidate_order(
		candidates,
		index,
	):
		_set_placement(index, candidate)
		if _solve_cell(placed_count + 1):
			return true
		_set_placement(index, null)
		_backtrack_count += 1
		if _backtrack_count >= maximum_backtracks:
			break
	return false


func _refresh_selection_required_cache() -> void:
	_selection_missing_required_count = 0
	_selection_missing_required_mask = 0
	for stable_id: StringName in _required_stable_ids:
		if int(_placement_counts.get(stable_id, 0)) > 0:
			continue
		_selection_missing_required_count += 1
		_selection_missing_required_mask |= int(
			_definition_variant_masks.get(stable_id, 0)
		)


func _select_next_cell(placed_count: int) -> Dictionary:
	if _packed_solver_domains_are_available():
		if (
			_placements.size() >= LARGE_GRID_LIGHTWEIGHT_THRESHOLD
			and placed_count % LARGE_GRID_PROPAGATION_INTERVAL != 0
		):
			return _select_next_large_grid_cell()
		return _select_next_large_grid_propagated_cell()
	if _placements.size() >= LARGE_GRID_LIGHTWEIGHT_THRESHOLD:
		if placed_count % LARGE_GRID_PROPAGATION_INTERVAL != 0:
			return _select_next_large_grid_cell_unpacked()
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


func _select_next_large_grid_propagated_cell() -> Dictionary:
	var domains: Dictionary[int, int] = {}
	for index: int in _placements.size():
		if _placements[index] != null:
			continue
		var candidate_mask := _compatible_candidate_mask(index)
		if candidate_mask == 0:
			return {"index": index, "candidates": []}
		domains[index] = candidate_mask
	if not _propagate_domain_masks(domains):
		return {"index": -1, "candidates": []}

	var best_index := -1
	var best_mask := 0
	var best_size := _solver_variants.size() + 1
	for index: int in domains:
		var candidate_mask := domains[index]
		var candidate_count := _mask_bit_count(candidate_mask)
		if best_index < 0 or candidate_count < best_size:
			best_index = index
			best_mask = candidate_mask
			best_size = candidate_count
			if candidate_count == 1:
				break
	return {
		"index": best_index,
		"candidates": _candidates_from_mask(best_mask),
	}


func _candidates_from_mask(candidate_mask: int) -> Array[TerrainChunkVariant]:
	var result: Array[TerrainChunkVariant] = []
	for candidate_index: int in _solver_variants.size():
		if (candidate_mask & (1 << candidate_index)) != 0:
			result.append(_solver_variants[candidate_index])
	return result


func _mask_bit_count(candidate_mask: int) -> int:
	var count := 0
	var remaining := candidate_mask
	while remaining != 0:
		remaining &= remaining - 1
		count += 1
	return count


func _propagate_domain_masks(domains: Dictionary[int, int]) -> bool:
	var changed := true
	while changed:
		changed = false
		for index: int in domains.keys():
			var candidates := domains[index]
			var supported := 0
			for candidate_index: int in _solver_variants.size():
				var candidate_bit := 1 << candidate_index
				if (
					(candidates & candidate_bit) != 0
					and _domain_candidate_has_mask_support(
						candidate_index,
						index,
						domains,
					)
				):
					supported |= candidate_bit
			if supported == 0:
				return false
			if supported != candidates:
				domains[index] = supported
				changed = true
		var required_result := _constrain_required_domain_masks(domains)
		if required_result < 0:
			return false
		if required_result > 0:
			changed = true
		if not _placed_neighbor_requirements_have_domain_mask_support(domains):
			return false
	return true


func _domain_candidate_has_mask_support(
	candidate_index: int,
	index: int,
	domains: Dictionary[int, int],
) -> bool:
	var candidate := _solver_variants[candidate_index]
	var possible_required_neighbors := 0
	var required_neighbor_mask := _required_neighbor_variant_mask(
		candidate.definition
	)
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var edge := edge_value as TerrainChunkTopology.Edge
		var neighbor_index := _neighbor_indices[index][edge_value]
		if neighbor_index < 0:
			continue
		var placed_neighbor := _placements[neighbor_index]
		if placed_neighbor != null:
			if _definition_matches_required_neighbor_tags(
				candidate.definition,
				placed_neighbor.definition,
			):
				possible_required_neighbors += 1
			continue
		var support_mask := (
			int(domains.get(neighbor_index, 0))
			& _edge_compatibility_masks[candidate_index * 4 + int(edge)]
		)
		if (
			candidate.definition.maximum_placements >= 0
			and _definition_placement_count(candidate.definition) + 2
			> candidate.definition.maximum_placements
		):
			support_mask &= ~int(
				_definition_variant_masks.get(
					candidate.definition.stable_id,
					0,
				)
			)
		if support_mask == 0:
			return false
		if (support_mask & required_neighbor_mask) != 0:
			possible_required_neighbors += 1
	return (
		possible_required_neighbors
		>= candidate.definition.minimum_required_neighbors
	)


func _required_neighbor_variant_mask(
	definition: TerrainChunkDefinition,
) -> int:
	if _required_neighbor_variant_masks.has(definition.stable_id):
		return _required_neighbor_variant_masks[definition.stable_id]
	var result := 0
	for candidate_index: int in _solver_variants.size():
		if _definition_matches_required_neighbor_tags(
			definition,
			_solver_variants[candidate_index].definition,
		):
			result |= 1 << candidate_index
	_required_neighbor_variant_masks[definition.stable_id] = result
	return result


func _constrain_required_domain_masks(
	domains: Dictionary[int, int],
) -> int:
	var changed := false
	for stable_id: StringName in _missing_required_ids():
		var definition_mask := int(_definition_variant_masks.get(stable_id, 0))
		var supporting_cell := -1
		var supporting_cell_count := 0
		for index: int in domains:
			if (domains[index] & definition_mask) == 0:
				continue
			supporting_cell = index
			supporting_cell_count += 1
			if supporting_cell_count > 1:
				break
		if supporting_cell_count == 0:
			return -1
		if supporting_cell_count != 1:
			continue
		var forced_mask := domains[supporting_cell] & definition_mask
		if forced_mask == 0:
			return -1
		if forced_mask != domains[supporting_cell]:
			domains[supporting_cell] = forced_mask
			changed = true
	return 1 if changed else 0


func _placed_neighbor_requirements_have_domain_mask_support(
	domains: Dictionary[int, int],
) -> bool:
	for index: int in _placements.size():
		var placement := _placements[index]
		if placement == null or placement.definition.minimum_required_neighbors <= 0:
			continue
		var placement_variant_index := int(
			_solver_variant_indices.get(placement, -1)
		)
		if placement_variant_index < 0:
			return false
		var required_neighbor_mask := _required_neighbor_variant_mask(
			placement.definition
		)
		var possible_neighbors := 0
		for edge_value: int in TerrainChunkTopology.Edge.values():
			var edge := edge_value as TerrainChunkTopology.Edge
			var neighbor_index := _neighbor_indices[index][edge_value]
			if neighbor_index < 0:
				continue
			var neighbor := _placements[neighbor_index]
			if neighbor != null:
				if _definition_matches_required_neighbor_tags(
					placement.definition,
					neighbor.definition,
				):
					possible_neighbors += 1
				continue
			var compatible_required_mask := (
				int(domains.get(neighbor_index, 0))
				& required_neighbor_mask
				& _edge_compatibility_masks[
					placement_variant_index * 4 + int(edge)
				]
			)
			if compatible_required_mask != 0:
				possible_neighbors += 1
		if possible_neighbors < placement.definition.minimum_required_neighbors:
			return false
	return true


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
		var candidate_mask := _compatible_candidate_mask(index)
		if candidate_mask == 0:
			return {"index": index, "candidates": []}
		var candidates := _candidates_from_mask(candidate_mask)
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


func _select_next_large_grid_cell_unpacked() -> Dictionary:
	var best_index := -1
	var best_candidates: Array[TerrainChunkVariant] = []
	var best_placed_neighbors := -1
	for index: int in _placements.size():
		if _placements[index] != null:
			continue
		var candidates := _compatible_candidates_unpacked(index)
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
	var count := 0
	for neighbor_index: int in _neighbor_indices[index]:
		if neighbor_index < 0:
			continue
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
	if not _packed_solver_domains_are_available():
		return _compatible_candidates_unpacked(index)
	return _candidates_from_mask(_compatible_candidate_mask(index))


func _compatible_candidates_unpacked(
	index: int,
) -> Array[TerrainChunkVariant]:
	var result: Array[TerrainChunkVariant] = []
	var missing_required := _missing_required_ids()
	var must_place_missing_required := (
		missing_required.size() >= _unfilled_cells
	)
	for candidate: TerrainChunkVariant in _solver_variants:
		if (
			must_place_missing_required
			and not missing_required.has(candidate.definition.stable_id)
		):
			continue
		if _candidate_can_occupy_cell(candidate, index):
			result.append(candidate)
	return result


func _packed_solver_domains_are_available() -> bool:
	return _solver_variants.size() <= MAX_PACKED_SOLVER_VARIANTS


func _compatible_candidate_mask(index: int) -> int:
	if index < 0 or index >= _static_cell_candidate_masks.size():
		return 0
	var result := int(_static_cell_candidate_masks[index])
	if _selection_missing_required_count >= _unfilled_cells:
		result &= _selection_missing_required_mask
	if result == 0:
		return 0
	result = _mask_matching_placed_neighbors(result, index)
	if result == 0:
		return 0

	for definition: TerrainChunkDefinition in _solver_definitions:
		var definition_mask := int(
			_definition_variant_masks.get(definition.stable_id, 0)
		)
		if (result & definition_mask) == 0:
			continue
		var definition_variants: Array = _solver_variants_by_definition.get(
			definition.stable_id,
			[],
		)
		if (
			definition_variants.is_empty()
			or not _candidate_dynamic_cell_rules_are_satisfied(
				definition_variants[0] as TerrainChunkVariant,
				index,
			)
		):
			result &= ~definition_mask
	return result


func _mask_matching_placed_neighbors(candidate_mask: int, index: int) -> int:
	var result := candidate_mask
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var neighbor_index := _neighbor_indices[index][edge_value]
		if neighbor_index < 0:
			continue
		var neighbor := _placements[neighbor_index]
		if neighbor == null:
			continue
		var neighbor_variant_index := int(
			_solver_variant_indices.get(neighbor, -1)
		)
		if neighbor_variant_index < 0:
			return 0
		var neighbor_edge := TerrainChunkTopology.opposite_edge(
			edge_value as TerrainChunkTopology.Edge
		)
		result &= _edge_compatibility_masks[
			neighbor_variant_index * 4 + int(neighbor_edge)
		]
		if result == 0:
			return 0
	return result


func _candidate_dynamic_cell_rules_are_satisfied(
	candidate: TerrainChunkVariant,
	index: int,
) -> bool:
	if not _definition_has_capacity(candidate.definition):
		return false
	var center_index := (grid_size.y / 2) * grid_size.x + grid_size.x / 2
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
		_candidate_neighbor_requirement_can_still_be_met_at_index(
			candidate.definition,
			index,
		)
		and _candidate_preserves_placed_neighbor_requirements_at_index(
			candidate.definition,
			index,
		)
	)


func _candidate_neighbor_requirement_can_still_be_met_at_index(
	definition: TerrainChunkDefinition,
	index: int,
) -> bool:
	if definition.minimum_required_neighbors <= 0:
		return true
	var possible_neighbors := 0
	for neighbor_index: int in _neighbor_indices[index]:
		if neighbor_index < 0:
			continue
		var neighbor := _placements[neighbor_index]
		if (
			neighbor == null
			or _definition_matches_required_neighbor_tags(
				definition,
				neighbor.definition,
			)
		):
			possible_neighbors += 1
	return possible_neighbors >= definition.minimum_required_neighbors


func _candidate_preserves_placed_neighbor_requirements_at_index(
	candidate_definition: TerrainChunkDefinition,
	candidate_index: int,
) -> bool:
	for neighbor_index: int in _neighbor_indices[candidate_index]:
		if neighbor_index < 0:
			continue
		var neighbor := _placements[neighbor_index]
		if neighbor == null or neighbor.definition.minimum_required_neighbors <= 0:
			continue
		var possible_neighbors := 0
		for requirement_neighbor_index: int in _neighbor_indices[neighbor_index]:
			if requirement_neighbor_index < 0:
				continue
			if requirement_neighbor_index == candidate_index:
				if _definition_matches_required_neighbor_tags(
					neighbor.definition,
					candidate_definition,
				):
					possible_neighbors += 1
				continue
			var requirement_neighbor := _placements[requirement_neighbor_index]
			if (
				requirement_neighbor == null
				or _definition_matches_required_neighbor_tags(
					neighbor.definition,
					requirement_neighbor.definition,
				)
			):
				possible_neighbors += 1
		if possible_neighbors < neighbor.definition.minimum_required_neighbors:
			return false
	return true


func _candidate_can_occupy_cell(
	candidate: TerrainChunkVariant,
	index: int,
) -> bool:
	var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
	if (
		_elevated_feature_reserved_grass_indices.has(index)
		and candidate.definition.stable_id != elevated_cliff_base_chunk_id
		and not (
			coordinate == Vector2i(grid_size.x / 2, grid_size.y / 2)
			and force_center_chunk_id != &""
			and candidate.definition.stable_id == force_center_chunk_id
			and "grass" in candidate.definition.tags
			and "flat" in candidate.definition.tags
		)
	):
		return false
	var center := Vector2i(grid_size.x / 2, grid_size.y / 2)
	if (
		coordinate == center
		and force_center_chunk_id != &""
		and candidate.definition.stable_id != force_center_chunk_id
	):
		return false
	return (
		_variant_respects_ocean_boundary(candidate, coordinate)
		and _candidate_matches_placed_neighbors(candidate, coordinate)
		and _candidate_dynamic_cell_rules_are_satisfied(candidate, index)
	)


func _prepare_elevated_feature_region() -> bool:
	_elevated_feature_center = Vector2i(-1, -1)
	_secondary_elevated_feature_center = Vector2i(-1, -1)
	_elevated_feature_reserved_grass_indices.clear()
	_stacked_elevated_placements.clear()
	if not elevated_cliff_feature_enabled:
		_build_grid_solver_caches()
		return true
	for stable_id: StringName in [
		elevated_cliff_base_chunk_id,
		elevated_cliff_top_chunk_id,
		elevated_cliff_corner_chunk_id,
		elevated_cliff_edge_chunk_id,
		elevated_cliff_ramp_chunk_id,
		elevated_cliff_sea_edge_chunk_id,
		elevated_cliff_sea_corner_chunk_id,
		elevated_cliff_sea_transition_right_chunk_id,
		elevated_cliff_sea_transition_left_chunk_id,
		elevated_cliff_coast_base_chunk_id,
	]:
		if catalog.definition_for_id(stable_id) == null:
			push_error("Elevated cliff feature references missing chunk %s." % stable_id)
			return false
	if grid_size.x < 11 or grid_size.y < 11:
		push_error(
			"Elevated cliff feature requires at least an 11x11 terrain grid."
		)
		return false
	var forced_center := Vector2i(grid_size.x / 2, grid_size.y / 2)
	var candidates: Array[Vector2i] = []
	for row: int in range(
		ELEVATED_FEATURE_BOUNDARY_MARGIN,
		grid_size.y - ELEVATED_FEATURE_BOUNDARY_MARGIN,
	):
		for column: int in range(
			ELEVATED_FEATURE_BOUNDARY_MARGIN,
			grid_size.x - ELEVATED_FEATURE_BOUNDARY_MARGIN,
		):
			var candidate := Vector2i(column, row)
			if (
				absi(candidate.x - forced_center.x)
				<= ELEVATED_FEATURE_RADIUS
				and absi(candidate.y - forced_center.y)
				<= ELEVATED_FEATURE_RADIUS
			):
				continue
			candidates.append(candidate)
	if candidates.is_empty():
		push_error("Terrain grid has no inland 5x5 cliff feature location.")
		return false
	var feature_random := RandomNumberGenerator.new()
	feature_random.seed = generation_seed ^ 0x2E1E7A7ED
	_elevated_feature_center = candidates[
		feature_random.randi_range(0, candidates.size() - 1)
	]
	# Solve the authored 5x5 plateau into a one-cell ring of ordinary level-one
	# flat grass. The larger top provides a real landing beyond the ramp and
	# leaves usable second-tier terrain around the optional third tier.
	_reserve_elevated_feature_base(
		_elevated_feature_center,
		ELEVATED_FEATURE_CLEARANCE_RADIUS,
	)
	var secondary_candidates := _coastal_elevated_feature_centers()
	var combined_clearance := (
		ELEVATED_FEATURE_CLEARANCE_RADIUS
		+ SECONDARY_ELEVATED_FEATURE_CLEARANCE_RADIUS
	)
	secondary_candidates = secondary_candidates.filter(
		func(candidate: Vector2i) -> bool:
			var separation := candidate - _elevated_feature_center
			return (
				absi(separation.x) > combined_clearance
				or absi(separation.y) > combined_clearance
			)
	)
	if not secondary_candidates.is_empty():
		_secondary_elevated_feature_center = secondary_candidates[
			feature_random.randi_range(0, secondary_candidates.size() - 1)
		]
		_reserve_elevated_feature_base(
			_secondary_elevated_feature_center,
			SECONDARY_ELEVATED_FEATURE_CLEARANCE_RADIUS,
		)
	_build_grid_solver_caches()
	return true


func _coastal_elevated_feature_centers() -> Array[Vector2i]:
	return [
		Vector2i(1, 1),
		Vector2i(grid_size.x - 2, 1),
		Vector2i(1, grid_size.y - 2),
		Vector2i(grid_size.x - 2, grid_size.y - 2),
	]


func _reserve_elevated_feature_base(
	center: Vector2i,
	clearance_radius: int,
) -> void:
	for row_offset: int in range(-clearance_radius, clearance_radius + 1):
		for column_offset: int in range(
			-clearance_radius,
			clearance_radius + 1,
		):
			var coordinate := center + Vector2i(column_offset, row_offset)
			if (
				not _coordinate_is_inside_grid(coordinate)
				or _coordinate_is_on_boundary(coordinate)
			):
				continue
			_elevated_feature_reserved_grass_indices[
				coordinate.y * grid_size.x + coordinate.x
			] = true


func _build_grid_solver_caches() -> void:
	_neighbor_indices.clear()
	_neighbor_indices.resize(_placements.size())
	_static_cell_candidate_masks.resize(_placements.size())
	_static_cell_candidate_masks.fill(0)
	var center := Vector2i(grid_size.x / 2, grid_size.y / 2)
	for index: int in _placements.size():
		var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
		var neighbors := PackedInt32Array([-1, -1, -1, -1])
		for edge_value: int in TerrainChunkTopology.Edge.values():
			var neighbor_coordinate := (
				coordinate
				+ TerrainChunkTopology.grid_offset(
					edge_value as TerrainChunkTopology.Edge
				)
			)
			if _coordinate_is_inside_grid(neighbor_coordinate):
				neighbors[edge_value] = (
					neighbor_coordinate.y * grid_size.x
					+ neighbor_coordinate.x
				)
		_neighbor_indices[index] = neighbors

		if not _packed_solver_domains_are_available():
			continue
		var candidate_mask := 0
		for candidate_index: int in _solver_variants.size():
			var candidate := _solver_variants[candidate_index]
			if (
				_elevated_feature_reserved_grass_indices.has(index)
				and candidate.definition.stable_id
				!= elevated_cliff_base_chunk_id
				and not (
					coordinate == center
					and force_center_chunk_id != &""
					and candidate.definition.stable_id
					== force_center_chunk_id
					and "grass" in candidate.definition.tags
					and "flat" in candidate.definition.tags
				)
			):
				continue
			if (
				coordinate == center
				and force_center_chunk_id != &""
				and candidate.definition.stable_id != force_center_chunk_id
			):
				continue
			if not _variant_respects_ocean_boundary(candidate, coordinate):
				continue
			candidate_mask |= 1 << candidate_index
		_static_cell_candidate_masks[index] = candidate_mask


func _apply_grass_sand_smoothing() -> bool:
	if not grass_sand_smoothing_enabled:
		return true
	var diagonal_definition := catalog.definition_for_id(
		smoothing_diagonal_chunk_id
	)
	if diagonal_definition == null:
		push_error(
			"Grass-sand smoothing references missing chunk %s."
			% smoothing_diagonal_chunk_id
		)
		return false
	if diagonal_definition.participates_in_base_solver:
		push_error(
			"Grass-sand smoothing chunk %s must be excluded from the base solver."
			% smoothing_diagonal_chunk_id
		)
		return false

	var candidates: Array[Dictionary] = []
	var center := Vector2i(grid_size.x / 2, grid_size.y / 2)
	for index: int in _placements.size():
		var placement := _placements[index]
		if placement == null or placement.definition.stable_id not in [
			smoothing_grass_chunk_id,
			smoothing_sand_chunk_id,
		]:
			continue
		var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
		if (
			_coordinate_is_on_boundary(coordinate)
			or _elevated_feature_reserved_grass_indices.has(index)
			or (
				absi(coordinate.x - center.x)
				+ absi(coordinate.y - center.y)
				<= 1
			)
		):
			continue
		for quarter_turns: int in 4:
			var diagonal := _authored_variant(
				diagonal_definition,
				quarter_turns,
			)
			if (
				diagonal != null
				and _candidate_matches_placed_neighbors(diagonal, coordinate)
			):
				candidates.append({"index": index, "variant": diagonal})
				break

	var smoothing_random := RandomNumberGenerator.new()
	smoothing_random.seed = generation_seed ^ 0xD1A60A1
	for candidate_index: int in range(candidates.size() - 1, 0, -1):
		var swap_index := smoothing_random.randi_range(0, candidate_index)
		var temporary := candidates[candidate_index]
		candidates[candidate_index] = candidates[swap_index]
		candidates[swap_index] = temporary

	var previous_placements: Array[TerrainChunkVariant] = []
	previous_placements.assign(_placements)
	var replacement_count := 0
	for candidate: Dictionary in candidates:
		if replacement_count >= maximum_smoothing_placements:
			break
		var index := int(candidate["index"])
		var coordinate := Vector2i(index % grid_size.x, index / grid_size.x)
		var diagonal := candidate["variant"] as TerrainChunkVariant
		if (
			diagonal == null
			or not _candidate_matches_placed_neighbors(diagonal, coordinate)
			or not _replacement_preserves_required_chunk(_placements[index])
		):
			continue
		_set_placement(index, diagonal)
		replacement_count += 1

	var validation_error := _resolved_layout_validation_error(_placements)
	if not validation_error.is_empty():
		_assign_placements(previous_placements)
		push_error(
			"Grass-sand smoothing produced an invalid layout: "
			+ validation_error
		)
		return false
	return true


func _replacement_preserves_required_chunk(
	original: TerrainChunkVariant,
) -> bool:
	if original == null:
		return false
	var stable_id := original.definition.stable_id
	if String(stable_id) not in required_chunk_ids:
		return true
	return _definition_placement_count(original.definition) > 1


func _apply_elevated_feature() -> bool:
	if not elevated_cliff_feature_enabled:
		return true
	if _elevated_feature_center.x < 0 or _elevated_feature_center.y < 0:
		push_error("Elevated cliff feature has no reserved base region.")
		return false
	var feature_random := RandomNumberGenerator.new()
	feature_random.seed = generation_seed ^ 0x51A7C11FF
	var placements := _elevated_feature_placement_specs(
		_elevated_feature_center,
		ELEVATED_FEATURE_RADIUS,
		feature_random,
	)
	if (
		_secondary_elevated_feature_center.x >= 0
		and int(
			_placement_counts.get(elevated_cliff_coast_base_chunk_id, 0)
		) > 0
	):
		placements.append_array(
			_coastal_elevated_feature_placement_specs(
				_secondary_elevated_feature_center,
				feature_random,
			)
		)
	for spec: Dictionary in placements:
		var definition := catalog.definition_for_id(spec["id"] as StringName)
		var variant := _authored_variant(definition, int(spec["turns"]))
		if variant == null:
			push_error(
				"Elevated cliff feature cannot resolve %s rotation %d."
				% [spec["id"], spec["turns"]]
			)
			return false
		var coordinate := spec["coordinate"] as Vector2i
		_set_placement(
			coordinate.y * grid_size.x + coordinate.x,
			variant,
		)
	var validation_error := _resolved_layout_validation_error(_placements)
	if not validation_error.is_empty():
		push_error("Elevated cliff feature is invalid: " + validation_error)
		return false
	return true


func _elevated_feature_placement_specs(
	center: Vector2i,
	radius: int,
	feature_random: RandomNumberGenerator,
) -> Array[Dictionary]:
	var edge_specs: Array[Dictionary] = [
		{
			"edge": TerrainChunkTopology.Edge.NORTH,
			"offset": Vector2i(0, -radius),
			"turns": 1,
		},
		{
			"edge": TerrainChunkTopology.Edge.EAST,
			"offset": Vector2i(radius, 0),
			"turns": 0,
		},
		{
			"edge": TerrainChunkTopology.Edge.SOUTH,
			"offset": Vector2i(0, radius),
			"turns": 3,
		},
		{
			"edge": TerrainChunkTopology.Edge.WEST,
			"offset": Vector2i(-radius, 0),
			"turns": 2,
		},
	]
	var ramp_edge: int = -1
	if feature_random.randf() < elevated_cliff_ramp_chance:
		var usable_edges: Array[int] = []
		for edge_index: int in edge_specs.size():
			var edge_spec := edge_specs[edge_index]
			var landing_coordinate := (
				center
				+ (edge_spec["offset"] as Vector2i)
				+ TerrainChunkTopology.grid_offset(
					edge_spec["edge"] as TerrainChunkTopology.Edge
				)
			)
			if (
				_coordinate_is_inside_grid(landing_coordinate)
				and not _coordinate_is_on_boundary(landing_coordinate)
			):
				usable_edges.append(edge_index)
		if not usable_edges.is_empty():
			ramp_edge = usable_edges[
				feature_random.randi_range(0, usable_edges.size() - 1)
			]
	var placements: Array[Dictionary] = []
	for row_offset: int in range(-radius, radius + 1):
		for column_offset: int in range(-radius, radius + 1):
			var offset := Vector2i(column_offset, row_offset)
			var on_horizontal_edge := absi(column_offset) == radius
			var on_vertical_edge := absi(row_offset) == radius
			if on_horizontal_edge and on_vertical_edge:
				placements.append({
					"coordinate": center + offset,
					"id": elevated_cliff_corner_chunk_id,
					"turns": _elevated_corner_turns(offset),
				})
				continue
			if on_horizontal_edge or on_vertical_edge:
				var edge_index := _elevated_edge_index(offset, radius)
				placements.append({
					"coordinate": center + offset,
					"id": (
						elevated_cliff_ramp_chunk_id
						if ramp_edge >= 0
						and offset == edge_specs[ramp_edge]["offset"]
						else elevated_cliff_edge_chunk_id
					),
					"turns": edge_specs[edge_index]["turns"],
				})
				continue
			placements.append({
				"coordinate": center + offset,
				"id": elevated_cliff_top_chunk_id,
				"turns": 0,
			})
	return placements


func _coastal_elevated_feature_placement_specs(
	center: Vector2i,
	feature_random: RandomNumberGenerator,
) -> Array[Dictionary]:
	var placements := _elevated_feature_placement_specs(
		center,
		SECONDARY_ELEVATED_FEATURE_RADIUS,
		feature_random,
	)
	for spec: Dictionary in placements:
		var coordinate := spec["coordinate"] as Vector2i
		var outside_edge_count := _outside_edge_count(coordinate)
		if outside_edge_count == 2:
			spec["id"] = elevated_cliff_sea_corner_chunk_id
		elif (
			outside_edge_count == 1
			and spec["id"] == elevated_cliff_corner_chunk_id
		):
			spec["id"] = _coastal_transition_id(
				coordinate,
				int(spec["turns"]),
			)
		elif outside_edge_count == 1 and (
			spec["id"] == elevated_cliff_edge_chunk_id
			or spec["id"] == elevated_cliff_ramp_chunk_id
		):
			spec["id"] = elevated_cliff_sea_edge_chunk_id
	return placements


func _coastal_transition_id(
	coordinate: Vector2i,
	quarter_turns: int,
) -> StringName:
	for stable_id: StringName in [
		elevated_cliff_sea_transition_right_chunk_id,
		elevated_cliff_sea_transition_left_chunk_id,
	]:
		var definition := catalog.definition_for_id(stable_id)
		var variant := _authored_variant(definition, quarter_turns)
		if (
			variant != null
			and _variant_respects_ocean_boundary(variant, coordinate)
		):
			return stable_id
	push_error(
		"Coastal cliff feature has no transition for %s rotation %d."
		% [coordinate, quarter_turns]
	)
	return &""


func _outside_edge_count(coordinate: Vector2i) -> int:
	var result := 0
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var neighbor := (
			coordinate
			+ TerrainChunkTopology.grid_offset(
				edge_value as TerrainChunkTopology.Edge
			)
		)
		if not _coordinate_is_inside_grid(neighbor):
			result += 1
	return result


func _elevated_edge_index(offset: Vector2i, radius: int) -> int:
	if offset.y == -radius:
		return 0
	if offset.x == radius:
		return 1
	if offset.y == radius:
		return 2
	return 3


func _elevated_corner_turns(offset: Vector2i) -> int:
	if offset.x < 0 and offset.y < 0:
		return 2
	if offset.x > 0 and offset.y < 0:
		return 1
	if offset.x < 0 and offset.y > 0:
		return 3
	return 0


func _configure_stacked_elevated_feature() -> bool:
	_stacked_elevated_placements.clear()
	if (
		not elevated_cliff_feature_enabled
		or elevated_cliff_third_level_chance <= 0.0
	):
		return true
	var top_coordinate := _elevated_feature_center
	if top_coordinate.x < 0:
		return true
	var top_index := top_coordinate.y * grid_size.x + top_coordinate.x
	if (
		top_index < 0
		or top_index >= _placements.size()
		or _placements[top_index] == null
		or _placements[top_index].definition.stable_id
		!= elevated_cliff_top_chunk_id
	):
		push_error("Stacked cliff feature lost its central supporting top.")
		return false
	var stack_random := RandomNumberGenerator.new()
	stack_random.seed = generation_seed ^ 0x7312DC11F
	if stack_random.randf() >= elevated_cliff_third_level_chance:
		return true
	var corner_definition := catalog.definition_for_id(
		elevated_cliff_corner_chunk_id
	)
	if corner_definition == null:
		push_error(
			"Stacked cliff feature references missing corner chunk %s."
			% elevated_cliff_corner_chunk_id
		)
		return false
	# Four nearly half-cell-offset corners form a closed 2x2 ring. A slight
	# inward overlap keeps the authored curved feet fully seated on the lower
	# plateau instead of exposing a hairline gap at its outermost vertices.
	var specs: Array[Dictionary] = [
		{"offset": Vector2(-0.45, -0.45), "turns": 2},
		{"offset": Vector2(0.45, -0.45), "turns": 1},
		{"offset": Vector2(-0.45, 0.45), "turns": 3},
		{"offset": Vector2(0.45, 0.45), "turns": 0},
	]
	for spec: Dictionary in specs:
		var variant := _authored_variant(
			corner_definition,
			int(spec["turns"]),
		)
		if variant == null:
			push_error(
				"Stacked cliff feature cannot resolve %s rotation %d."
				% [elevated_cliff_corner_chunk_id, spec["turns"]]
			)
			return false
		_stacked_elevated_placements.append({
			"support_coordinate": top_coordinate,
			"offset": spec["offset"],
			"variant": variant,
		})
	return true


func _variant_respects_ocean_boundary(
	variant: TerrainChunkVariant,
	coordinate: Vector2i,
) -> bool:
	var ocean_edges := variant.rotated_edge_mask(
		variant.definition.ocean_facing_edges
	)
	if (
		variant.definition.must_be_interior
		and _coordinate_is_on_boundary(coordinate)
	):
		return false
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var edge := edge_value as TerrainChunkTopology.Edge
		var ocean_coordinate := (
			coordinate
			+ TerrainChunkTopology.grid_offset(edge)
		)
		var edge_faces_ocean := (ocean_edges & (1 << edge_value)) != 0
		if _coordinate_is_inside_grid(ocean_coordinate):
			if edge_faces_ocean:
				return false
			continue
		if edge_faces_ocean:
			continue
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


func _definition_has_capacity(definition: TerrainChunkDefinition) -> bool:
	if definition.maximum_placements < 0:
		return true
	return _definition_placement_count(definition) < definition.maximum_placements


func _definition_placement_count(definition: TerrainChunkDefinition) -> int:
	if definition == null:
		return 0
	return int(_placement_counts.get(definition.stable_id, 0))


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
	var profiles_match := first.profile(first_edge).matches(
		second.profile(second_edge),
		edge_match_tolerance,
	)
	if not profiles_match and (
		_variant_edge_has_connector(
			first,
			first.definition.buried_cliff_seam_edges,
			first_edge,
		)
		or _variant_edge_has_connector(
			second,
			second.definition.buried_cliff_seam_edges,
			second_edge,
		)
	):
		profiles_match = first.profile(first_edge).matches_above_height(
			second.profile(second_edge),
			0.0,
			edge_match_tolerance,
		)
	if not profiles_match:
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
		_edge_surfaces_are_compatible(
			first,
			first_edge,
			second,
			second_edge,
		)
		and first.allows_non_water_neighbor_on_edge(second, first_edge)
		and second.allows_non_water_neighbor_on_edge(first, second_edge)
	)


func _edge_surfaces_are_compatible(
	first: TerrainChunkVariant,
	first_edge: TerrainChunkTopology.Edge,
	second: TerrainChunkVariant,
	second_edge: TerrainChunkTopology.Edge,
) -> bool:
	var first_tags := first.surface_tags(first_edge)
	var second_tags := second.surface_tags(second_edge)
	if first_tags.is_empty() or second_tags.is_empty():
		return true
	return TerrainChunkDefinition.has_any_tag(first_tags, second_tags)


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
	var definition_variants: Array = _solver_variants_by_definition.get(
		definition.stable_id,
		[],
	)
	if (
		_packed_solver_domains_are_available()
		and not definition_variants.is_empty()
	):
		var definition_mask := int(
			_definition_variant_masks.get(definition.stable_id, 0)
		)
		for index: int in _placements.size():
			if _placements[index] != null:
				continue
			var candidate_mask := (
				int(_static_cell_candidate_masks[index]) & definition_mask
			)
			if candidate_mask == 0:
				continue
			candidate_mask = _mask_matching_placed_neighbors(
				candidate_mask,
				index,
			)
			if (
				candidate_mask != 0
				and _candidate_dynamic_cell_rules_are_satisfied(
					definition_variants[0] as TerrainChunkVariant,
					index,
				)
			):
				return true
		return false
	for index: int in _placements.size():
		if _placements[index] != null:
			continue
		for candidate: TerrainChunkVariant in definition_variants:
			if _candidate_can_occupy_cell(candidate, index):
				return true
	return false


func _unfilled_cell_count() -> int:
	return _unfilled_cells


func _missing_required_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for required_id: StringName in _required_stable_ids:
		if (
			int(_placement_counts.get(required_id, 0)) <= 0
		):
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
	return int(_placement_counts.get(stable_id, 0)) <= 0


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
	if not _add_stacked_elevated_chunks(solution_root):
		solution_root.free()
		return null
	return solution_root


func _add_stacked_elevated_chunks(solution_root: Node3D) -> bool:
	for index: int in _stacked_elevated_placements.size():
		var record := _stacked_elevated_placements[index]
		var variant := record.get("variant") as TerrainChunkVariant
		var support_coordinate: Vector2i = record.get(
			"support_coordinate",
			Vector2i(-1, -1),
		)
		var support_root := _find_chunk_root_for_coordinate(
			solution_root,
			support_coordinate,
		)
		if variant == null or support_root == null:
			push_error("Stacked cliff feature lost its supporting terrain cell.")
			return false
		var stacked_root := variant.definition.packed_scene.instantiate() as Node3D
		if stacked_root == null:
			push_error(
				"%s does not instantiate as a stacked Node3D."
				% variant.stable_key()
			)
			return false
		stacked_root.name = "Stacked_%s_%d" % [
			variant.stable_key().replace("@", "r"),
			index,
		]
		var offset: Vector2 = record.get("offset", Vector2.ZERO)
		stacked_root.position = Vector3(
			offset.x * catalog.chunk_size,
			elevated_cliff_level_height,
			offset.y * catalog.chunk_size,
		)
		stacked_root.rotation.y = variant.rotation_radians()
		stacked_root.set_meta(&"terrain_stacked_elevation", true)
		stacked_root.set_meta(
			&"terrain_chunk_id",
			variant.definition.stable_id,
		)
		stacked_root.set_meta(
			&"terrain_chunk_coordinate",
			support_coordinate,
		)
		support_root.add_child(stacked_root)
		if build_collision:
			_add_collision(stacked_root, variant.definition)
		if show_chunk_labels:
			_add_chunk_label(stacked_root, variant)
	return true


func _find_chunk_root_for_coordinate(
	solution_root: Node3D,
	coordinate: Vector2i,
) -> Node3D:
	for child: Node in solution_root.get_children():
		if child.get_meta(&"terrain_chunk_coordinate", Vector2i(-1, -1)) == (
			coordinate
		):
			return child as Node3D
	return null


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
	base_layer_visual.rotation.y = (
		float(definition.base_layer_quarter_turns) * PI * 0.5
	)
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
		"stacked_elevated_placements": stacked_elevated_placement_keys(),
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
	fingerprint_input.append_array(stacked_elevated_placement_keys())
	return "\n".join(fingerprint_input).sha256_text()


func stacked_elevated_placement_keys() -> PackedStringArray:
	var result := PackedStringArray()
	for record: Dictionary in _stacked_elevated_placements:
		var variant := record.get("variant") as TerrainChunkVariant
		var offset: Vector2 = record.get("offset", Vector2.ZERO)
		if variant == null:
			continue
		result.append(
			"%s@%.2f,%.2f,+%.2fm"
			% [
				variant.stable_key(),
				offset.x,
				offset.y,
				elevated_cliff_level_height,
			]
		)
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
		for child: Node in chunk_root.get_children():
			if not bool(child.get_meta(&"terrain_stacked_elevation", false)):
				continue
			var definition := catalog.definition_for_id(
				StringName(child.get_meta(&"terrain_chunk_id", &""))
			)
			if definition == null:
				continue
			var stacked_mesh := TerrainChunkAnalyzer.find_primary_mesh(
				child,
				definition.primary_mesh_name,
			)
			if stacked_mesh != null and stacked_mesh.mesh != null:
				result.append(stacked_mesh)
	return result
