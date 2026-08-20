extends SceneTree

const CATALOG: TerrainChunkCatalog = preload(
	"res://world/generation/chunks/terrain_chunk_catalog.tres"
)
const EXPECTED_IDS: Array[String] = [
	"chunk_0000",
	"chunk_0001",
	"chunk_0002",
	"chunk_0003",
	"chunk_0004",
	"chunk_0005",
	"chunk_0006",
	"chunk_0007",
	"chunk_0008",
	"chunk_0009",
	"chunk_0010",
	"chunk_0011",
	"chunk_0012",
	"chunk_spawn",
]
const REQUIRED_IDS: Array[String] = [
	"chunk_spawn",
	"chunk_0001",
	"chunk_0002",
	"chunk_0003",
	"chunk_0004",
	"chunk_0005",
	"chunk_0006",
	"chunk_0007",
	"chunk_0008",
]
const TEST_SEED := 13001
const CONNECTOR_STRESS_SEED := 287
const EXPECTED_SOLVER_VARIANT_COUNT := 31
const EXPECTED_VARIANT_COUNTS: Dictionary[StringName, int] = {
	&"chunk_0000": 4,
	&"chunk_0001": 4,
	&"chunk_0002": 4,
	&"chunk_0003": 4,
	&"chunk_0004": 4,
	&"chunk_0005": 4,
	&"chunk_0006": 4,
	&"chunk_0007": 4,
	&"chunk_0008": 4,
	&"chunk_0009": 4,
	&"chunk_0010": 4,
	&"chunk_0011": 4,
	&"chunk_0012": 4,
	&"chunk_spawn": 1,
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_validate_catalog()
	_validate_profiles()
	_validate_generation()
	_finish()


func _validate_catalog() -> void:
	for error: String in CATALOG.validation_errors():
		_check(false, error)
	_check(
		CATALOG.definitions.size() == EXPECTED_IDS.size(),
		"Catalog must contain the authored chunks and spawn definition.",
	)
	for stable_id: String in EXPECTED_IDS:
		var definition := CATALOG.definition_for_id(StringName(stable_id))
		_check(definition != null, "Catalog is missing %s." % stable_id)
		if definition == null:
			continue
		_check(
			definition.packed_scene != null,
			"%s must reference an imported GLB." % stable_id,
		)
	var grass := CATALOG.definition_for_id(&"chunk_0000")
	var sand := CATALOG.definition_for_id(&"chunk_0001")
	var beach := CATALOG.definition_for_id(&"chunk_0002")
	var grass_ocean_edge := CATALOG.definition_for_id(&"chunk_0005")
	var grass_beach_transition := CATALOG.definition_for_id(&"chunk_0006")
	var grass_ocean_corner := CATALOG.definition_for_id(&"chunk_0007")
	var beach_ocean_corner := CATALOG.definition_for_id(&"chunk_0008")
	var cliff_top := CATALOG.definition_for_id(&"chunk_0009")
	var cliff_corner := CATALOG.definition_for_id(&"chunk_0010")
	var cliff_edge := CATALOG.definition_for_id(&"chunk_0011")
	var cliff_ramp := CATALOG.definition_for_id(&"chunk_0012")
	var spawn := CATALOG.definition_for_id(&"chunk_spawn")
	_check(
		(
			grass != null
			and sand != null
			and beach != null
			and grass_ocean_edge != null
			and grass_beach_transition != null
			and grass_ocean_corner != null
			and beach_ocean_corner != null
			and cliff_top != null
			and cliff_corner != null
			and cliff_edge != null
			and cliff_ramp != null
			and spawn != null
		),
		"The authored biome-rule definitions must be available.",
	)
	if (
		grass != null
		and sand != null
		and beach != null
		and grass_ocean_edge != null
		and grass_beach_transition != null
		and grass_ocean_corner != null
		and beach_ocean_corner != null
		and cliff_top != null
		and cliff_corner != null
		and cliff_edge != null
		and cliff_ramp != null
		and spawn != null
	):
		_check(
			sand.allows_non_water_neighbor(beach),
			"Flat sand must permit an adjacent authored beach.",
		)
		_check(
			sand.allows_non_water_neighbor(grass),
			"Flat sand must permit the inland transition to grass.",
		)
		_check(
			grass.allows_non_water_neighbor(sand),
			"Grass must permit the inland side of a flat-sand transition.",
		)
		_check(
			"coast" in sand.required_neighbor_tags,
			"Every flat-sand chunk must remain attached to an authored beach.",
		)
		_check(
			spawn.minimum_required_neighbors == 3,
			"Spawn must retain its three-sided safe-grass requirement.",
		)
		_check(
			beach.ocean_facing_edges
			== (1 << int(TerrainChunkTopology.Edge.EAST)),
			"The authored beach must descend eastward into ocean before rotation.",
		)
		_check(
			grass_ocean_edge.ocean_facing_edges
			== (1 << int(TerrainChunkTopology.Edge.EAST)),
			"The authored grass cliff must face eastward ocean before rotation.",
		)
		_check(
			grass_beach_transition.ocean_facing_edges
			== (1 << int(TerrainChunkTopology.Edge.EAST)),
			"The authored grass/beach join must face eastward ocean before rotation.",
		)
		_check(
			grass_beach_transition.minimum_required_neighbors == 2
			and "coast" in grass_beach_transition.required_neighbor_tags,
			"The grass/beach join must remain between two coastline chunks.",
		)
		_check(
			grass_beach_transition.allows_non_water_neighbor_on_edge(
				grass,
				TerrainChunkTopology.Edge.WEST,
			)
			and not grass_beach_transition.allows_non_water_neighbor_on_edge(
				sand,
				TerrainChunkTopology.Edge.WEST,
			),
			"The grass-backed transition edge must accept grass and reject sand.",
		)
		_check(
			grass_beach_transition.allows_non_water_neighbor_on_edge(
				beach,
				TerrainChunkTopology.Edge.NORTH,
			)
			and grass_beach_transition.allows_non_water_neighbor_on_edge(
				grass_ocean_edge,
				TerrainChunkTopology.Edge.SOUTH,
			),
			"The transition's coastline seams must retain their authored roles.",
		)
		_check(
			not grass_ocean_edge.allows_non_water_neighbor_on_edge(
				sand,
				TerrainChunkTopology.Edge.WEST,
			),
			"The straight grass coast's inland edge must reject sand.",
		)
		_check(
			grass_ocean_corner.ocean_facing_edges
			== (
				(1 << int(TerrainChunkTopology.Edge.EAST))
				| (1 << int(TerrainChunkTopology.Edge.SOUTH))
			),
			"The authored grass corner must expose east and south to ocean.",
		)
		_check(
			grass_ocean_corner.minimum_required_neighbors == 2
			and (
				"grass_ocean_edge"
				in grass_ocean_corner.required_neighbor_tags
			),
			"The grass corner must join two straight grass ocean edges.",
		)
		_check(
			grass_ocean_corner.allows_non_water_neighbor_on_edge(
				grass_ocean_edge,
				TerrainChunkTopology.Edge.NORTH,
			)
			and grass_ocean_corner.allows_non_water_neighbor_on_edge(
				grass_ocean_edge,
				TerrainChunkTopology.Edge.WEST,
			),
			"Both corner land seams must accept straight grass ocean edges.",
		)
		_check(
			beach_ocean_corner.ocean_facing_edges
			== (
				(1 << int(TerrainChunkTopology.Edge.EAST))
				| (1 << int(TerrainChunkTopology.Edge.SOUTH))
			),
			"The authored beach corner must expose east and south to ocean.",
		)
		_check(
			beach_ocean_corner.minimum_required_neighbors == 2
			and (
				"beach_ocean_edge"
				in beach_ocean_corner.required_neighbor_tags
			),
			"The beach corner must join two straight beach ocean edges.",
		)
		for cliff_definition: TerrainChunkDefinition in [
			cliff_top,
			cliff_corner,
			cliff_edge,
			cliff_ramp,
		]:
			_check(
				cliff_definition.overlay_only
				and cliff_definition.must_be_interior
				and cliff_definition.base_layer_scene != null
				and cliff_definition.base_layer_mesh_name == &"chunk_0000",
				"Every second-tier piece must overlay level-one grass inland.",
			)
		_check(
			cliff_top.minimum_required_neighbors == 4
			and "elevation_2" in cliff_top.required_neighbor_tags,
			"The second-tier top must be enclosed on all four sides.",
		)
		_check(
			"ramp" in cliff_ramp.tags
			and cliff_ramp.maximum_placements > 0,
			"The second-tier ramp must remain available without being required.",
		)


func _validate_profiles() -> void:
	for definition: TerrainChunkDefinition in CATALOG.definitions:
		var variants := TerrainChunkAnalyzer.create_variants(
			definition,
			CATALOG.chunk_size,
		)
		_check(
			not variants.is_empty(),
			"%s must produce at least one rotation variant."
			% definition.stable_id,
		)
		for variant: TerrainChunkVariant in variants:
			_check(
				variant.edge_profiles.size() == 4,
				"%s must expose four edge profiles." % variant.stable_key(),
			)
			var ocean_edges := variant.rotated_edge_mask(
				definition.ocean_facing_edges
			)
			for edge_index: int in variant.edge_profiles.size():
				var profile := variant.edge_profiles[edge_index]
				_check(
					(
						not profile.points.is_empty()
						or (ocean_edges & (1 << edge_index)) != 0
					),
					(
						"%s has an empty non-ocean edge profile."
						% variant.stable_key()
					),
				)


func _validate_generation() -> void:
	var first := _make_generator()
	root.add_child(first)
	var first_solved := first.generate()
	_check(first_solved, "Generator must solve the prototype 7x7 grid.")
	if not first_solved:
		first.free()
		return
	var first_keys := first.placement_keys()
	_check(first_keys.size() == 49, "Generator must place exactly 49 chunks.")
	for stable_id: String in REQUIRED_IDS:
		_check(
			_placements_contain(first_keys, stable_id),
			"Generated diagnostic must contain %s." % stable_id,
		)
	_check(
		_all_neighbor_edges_match(first),
		"Every generated neighboring edge must match.",
	)
	_check(
		_count_placements(first_keys, "chunk_spawn") == 1,
		"Generated layouts must contain exactly one spawn chunk.",
	)
	_check(
		first_keys[24].begins_with("chunk_spawn@"),
		"The spawn chunk must occupy the center cell.",
	)
	_validate_layout_rules(first)
	_validate_authored_rotations(first)
	_validate_generation_summary(first)
	var first_generated_root := first.get_generated_chunks_root()
	_check(
		first.generate(),
		"Repeated generation on one generator must solve.",
	)
	_check(
		first.placement_keys() == first_keys,
		"Repeated generation on one generator must remain deterministic.",
	)
	_check(
		first.get_generated_chunks_root() != first_generated_root,
		"Successful regeneration must replace the generated scene atomically.",
	)

	var second := _make_generator()
	root.add_child(second)
	var second_solved := second.generate()
	_check(second_solved, "Repeated deterministic generation must solve.")
	if not second_solved:
		first.free()
		second.free()
		return
	_check(
		second.placement_keys() == first_keys,
		"The same seed and catalog must produce the same layout.",
	)
	var restored := _make_generator()
	restored.generation_seed = TEST_SEED + 999
	root.add_child(restored)
	_check(
		restored.generate_from_placement_keys(first_keys),
		"A resolved placement manifest must rebuild successfully.",
	)
	_check(
		restored.placement_keys() == first_keys,
		"A resolved placement manifest must preserve exact rotations.",
	)
	first.free()
	second.free()
	restored.free()

	for seed_offset: int in range(1, 6):
		var generator := _make_generator()
		generator.generation_seed = TEST_SEED + seed_offset
		root.add_child(generator)
		var solved := generator.generate()
		_check(
			solved,
			"Generator must solve seed %d." % generator.generation_seed,
		)
		if solved:
			var keys := generator.placement_keys()
			for stable_id: String in REQUIRED_IDS:
				_check(
					_placements_contain(keys, stable_id),
					"Seed %d must contain %s."
					% [generator.generation_seed, stable_id],
				)
				_check(
					_all_neighbor_edges_match(generator),
				"Seed %d has a mismatched neighboring edge."
					% generator.generation_seed,
				)
				_validate_layout_rules(generator)
		generator.free()

	var connector_stress := _make_generator()
	connector_stress.generation_seed = CONNECTOR_STRESS_SEED
	connector_stress.maximum_backtracks = 100
	root.add_child(connector_stress)
	_check(
		connector_stress.generate(),
		"Connector propagation must solve the known stress seed.",
	)
	_check(
		connector_stress._backtrack_count < 100,
		"Connector propagation must reject unsupported branches early.",
	)
	connector_stress.free()


func _validate_authored_rotations(generator: TerrainChunkGenerator) -> void:
	var counts: Dictionary[StringName, int] = {}
	for variant: TerrainChunkVariant in generator._variants:
		var stable_id := variant.definition.stable_id
		counts[stable_id] = counts.get(stable_id, 0) + 1
	for stable_id: StringName in EXPECTED_VARIANT_COUNTS:
		_check(
			counts.get(stable_id, 0) == EXPECTED_VARIANT_COUNTS[stable_id],
			"%s must preserve every explicitly allowed rotation." % stable_id,
		)

	var stream := CATALOG.definition_for_id(&"chunk_0003")
	_check(stream != null, "The stream definition must be available.")
	if stream == null:
		return
	for quarter_turns: int in 4:
		var stream_variant := _find_variant(
			generator,
			&"chunk_0003",
			quarter_turns,
		)
		_check(
			stream_variant != null,
			"The stream must support rotation %d." % quarter_turns,
		)
		if stream_variant == null:
			continue
		var expected_inlet := 1 << int(TerrainChunkTopology.rotated_edge(
			TerrainChunkTopology.Edge.NORTH,
			quarter_turns,
		))
		var expected_outlet := 1 << int(TerrainChunkTopology.rotated_edge(
			TerrainChunkTopology.Edge.SOUTH,
			quarter_turns,
		))
		_check(
			stream_variant.rotated_edge_mask(stream.water_inlet_edges)
			== expected_inlet,
			"The rotated stream inlet must follow its authored orientation.",
		)
		_check(
			stream_variant.rotated_edge_mask(stream.water_outlet_edges)
			== expected_outlet,
			"The rotated stream outlet must follow its authored orientation.",
		)

	var beach := CATALOG.definition_for_id(&"chunk_0002")
	_check(beach != null, "The beach definition must be available.")
	if beach == null:
		return
	for quarter_turns: int in 4:
		var beach_variant := _find_variant(
			generator,
			&"chunk_0002",
			quarter_turns,
		)
		_check(
			beach_variant != null,
			"The beach must support rotation %d." % quarter_turns,
		)
		if beach_variant == null:
			continue
		var expected_ocean_edge := 1 << int(
			TerrainChunkTopology.rotated_edge(
				TerrainChunkTopology.Edge.EAST,
				quarter_turns,
			)
		)
		_check(
			beach_variant.rotated_edge_mask(beach.ocean_facing_edges)
			== expected_ocean_edge,
			"The rotated beach must keep its low edge facing the ocean.",
		)
		_check(
			not generator._variant_respects_ocean_boundary(
				beach_variant,
				Vector2i(3, 3),
			),
			"A beach slope must never direct its low edge into the map.",
		)
		var boundary_coordinate := Vector2i(3, 3)
		match TerrainChunkTopology.rotated_edge(
			TerrainChunkTopology.Edge.EAST,
			quarter_turns,
		):
			TerrainChunkTopology.Edge.NORTH:
				boundary_coordinate.y = 0
			TerrainChunkTopology.Edge.EAST:
				boundary_coordinate.x = generator.grid_size.x - 1
			TerrainChunkTopology.Edge.SOUTH:
				boundary_coordinate.y = generator.grid_size.y - 1
			TerrainChunkTopology.Edge.WEST:
				boundary_coordinate.x = 0
		_check(
			generator._variant_respects_ocean_boundary(
				beach_variant,
				boundary_coordinate,
			),
			"A beach slope must be legal when its low edge faces open ocean.",
		)

	var grass_ocean_edge := CATALOG.definition_for_id(&"chunk_0005")
	var grass_beach_transition := CATALOG.definition_for_id(&"chunk_0006")
	var grass_ocean_corner := CATALOG.definition_for_id(&"chunk_0007")
	var beach_ocean_corner := CATALOG.definition_for_id(&"chunk_0008")
	_check(
		(
			grass_ocean_edge != null
			and grass_beach_transition != null
			and grass_ocean_corner != null
			and beach_ocean_corner != null
		),
		"The authored coastline additions must be available.",
	)
	if (
		grass_ocean_edge == null
		or grass_beach_transition == null
		or grass_ocean_corner == null
		or beach_ocean_corner == null
	):
		return
	var beach_zero := _find_variant(generator, &"chunk_0002", 0)
	var grass_edge_zero := _find_variant(generator, &"chunk_0005", 0)
	var grass_edge_south := _find_variant(generator, &"chunk_0005", 3)
	var transition_zero := _find_variant(generator, &"chunk_0006", 0)
	var corner_zero := _find_variant(generator, &"chunk_0007", 0)
	var beach_corner_zero := _find_variant(generator, &"chunk_0008", 0)
	_check(
		beach_zero != null
		and grass_edge_zero != null
		and grass_edge_south != null
		and transition_zero != null
		and corner_zero != null
		and beach_corner_zero != null,
		"The unrotated coastline variants must be available.",
	)
	if (
		beach_zero != null
		and grass_edge_zero != null
		and grass_edge_south != null
		and transition_zero != null
		and corner_zero != null
		and beach_corner_zero != null
	):
		_check(
			grass_edge_zero.profile(
				TerrainChunkTopology.Edge.EAST
			).points.is_empty(),
			"The grass cliff's authored east edge must remain open to ocean.",
		)
		_check(
			transition_zero.profile(
				TerrainChunkTopology.Edge.NORTH
			).matches(
				beach_zero.profile(TerrainChunkTopology.Edge.SOUTH),
				generator.edge_match_tolerance,
			),
			"The transition's north side must match the authored beach.",
		)
		_check(
			transition_zero.profile(
				TerrainChunkTopology.Edge.SOUTH
			).matches(
				grass_edge_zero.profile(TerrainChunkTopology.Edge.NORTH),
				generator.edge_match_tolerance,
			),
			"The transition's south side must match the grass cliff.",
		)
		_check(
			corner_zero.profile(TerrainChunkTopology.Edge.EAST).points.is_empty()
			and corner_zero.profile(
				TerrainChunkTopology.Edge.SOUTH
			).points.is_empty(),
			"The corner's authored east and south edges must remain open to ocean.",
		)
		_check(
			corner_zero.profile(TerrainChunkTopology.Edge.NORTH).matches(
				grass_edge_zero.profile(TerrainChunkTopology.Edge.SOUTH),
				generator.edge_match_tolerance,
			),
			"The corner's north side must join a straight grass ocean edge.",
		)
		_check(
			corner_zero.profile(TerrainChunkTopology.Edge.WEST).matches(
				grass_edge_south.profile(TerrainChunkTopology.Edge.EAST),
				generator.edge_match_tolerance,
			),
			"The corner's west side must join a straight grass ocean edge.",
		)
		_check(
			beach_corner_zero.profile(TerrainChunkTopology.Edge.NORTH).matches(
				beach_zero.profile(TerrainChunkTopology.Edge.SOUTH),
				generator.edge_match_tolerance,
			),
			"The beach corner's north side must join a straight beach.",
		)
		var beach_south := _find_variant(generator, &"chunk_0002", 3)
		_check(
			beach_south != null
			and beach_corner_zero.profile(
				TerrainChunkTopology.Edge.WEST
			).matches(
				beach_south.profile(TerrainChunkTopology.Edge.EAST),
				generator.edge_match_tolerance,
			),
			"The beach corner's west side must join a rotated straight beach.",
		)
	var flat_grass := _find_variant(generator, &"chunk_0000", 0)
	var flat_sand := _find_variant(generator, &"chunk_0001", 0)
	_check(
		flat_grass != null and flat_sand != null,
		"Flat grass and sand variants must be available for seam validation.",
	)
	if flat_grass != null and flat_sand != null:
		for quarter_turns: int in 4:
			var transition := _find_variant(
				generator,
				&"chunk_0006",
				quarter_turns,
			)
			if transition == null:
				continue
			var inland_edge := TerrainChunkTopology.rotated_edge(
				TerrainChunkTopology.Edge.WEST,
				quarter_turns,
			)
			var neighbor_edge := TerrainChunkTopology.opposite_edge(inland_edge)
			_check(
				generator._edges_are_compatible(
					transition,
					inland_edge,
					flat_grass,
					neighbor_edge,
				),
				"Every transition rotation must accept grass behind it.",
			)
			_check(
				not generator._edges_are_compatible(
					transition,
					inland_edge,
					flat_sand,
					neighbor_edge,
				),
				"No transition rotation may accept sand behind it.",
			)
	for stable_id: StringName in [
		&"chunk_0005",
		&"chunk_0006",
		&"chunk_0007",
		&"chunk_0008",
	]:
		for quarter_turns: int in 4:
			var coast_variant := _find_variant(
				generator,
				stable_id,
				quarter_turns,
			)
			_check(
				coast_variant != null,
				"%s must support rotation %d." % [stable_id, quarter_turns],
			)
			if coast_variant == null:
				continue
			_check(
				not generator._variant_respects_ocean_boundary(
					coast_variant,
					Vector2i(3, 3),
				),
				"%s must never place its ocean edge inside the map." % stable_id,
			)
			if stable_id != &"chunk_0007" and stable_id != &"chunk_0008":
				continue
			var boundary_coordinate := Vector2i(3, 3)
			var ocean_edges := coast_variant.rotated_edge_mask(
				(
					grass_ocean_corner.ocean_facing_edges
					if stable_id == &"chunk_0007"
					else beach_ocean_corner.ocean_facing_edges
				)
			)
			for edge_value: int in TerrainChunkTopology.Edge.values():
				if (ocean_edges & (1 << edge_value)) == 0:
					continue
				match edge_value as TerrainChunkTopology.Edge:
					TerrainChunkTopology.Edge.NORTH:
						boundary_coordinate.y = 0
					TerrainChunkTopology.Edge.EAST:
						boundary_coordinate.x = generator.grid_size.x - 1
					TerrainChunkTopology.Edge.SOUTH:
						boundary_coordinate.y = generator.grid_size.y - 1
					TerrainChunkTopology.Edge.WEST:
						boundary_coordinate.x = 0
			_check(
				generator._variant_respects_ocean_boundary(
					coast_variant,
					boundary_coordinate,
				),
				"Each coast corner rotation must fit its matching map corner.",
			)


func _validate_generation_summary(generator: TerrainChunkGenerator) -> void:
	var summary := generator._build_summary()
	_check(
		int(summary.get("variant_count", 0)) == 53,
		"The current catalog must expose all 53 authored rotations.",
	)
	_check(
		int(summary.get("solver_variant_count", 0))
		== EXPECTED_SOLVER_VARIANT_COUNT,
		"Equivalent visual rotations must share one solver constraint.",
	)
	_check(
		int(summary.get("adjacent_repeat_edges", -1))
		== generator._count_adjacent_repeat_edges(),
		"The summary must report adjacent repeated chunk definitions.",
	)
	_check(
		str(summary.get("layout_fingerprint", ""))
		== generator.placement_fingerprint(),
		"The summary must identify the exact resolved layout.",
	)
	_check(
		generator.placement_fingerprint().length() == 64,
		"The resolved layout fingerprint must be SHA-256.",
	)
	var variant_counts: Dictionary = summary.get("variant_counts", {})
	for stable_id: StringName in EXPECTED_VARIANT_COUNTS:
		_check(
			int(variant_counts.get(stable_id, 0))
			== EXPECTED_VARIANT_COUNTS[stable_id],
			"The summary must report %s rotation candidates." % stable_id,
		)


func _find_variant(
	generator: TerrainChunkGenerator,
	stable_id: StringName,
	quarter_turns: int,
) -> TerrainChunkVariant:
	for variant: TerrainChunkVariant in generator._variants:
		if (
			variant.definition.stable_id == stable_id
			and variant.quarter_turns == quarter_turns
		):
			return variant
	return null


func _make_generator() -> TerrainChunkGenerator:
	var generator := TerrainChunkGenerator.new()
	generator.catalog = CATALOG
	generator.grid_size = Vector2i(7, 7)
	generator.generation_seed = TEST_SEED
	generator.generate_on_ready = false
	generator.build_collision = false
	generator.force_center_chunk_id = &"chunk_spawn"
	generator.required_chunk_ids = PackedStringArray(REQUIRED_IDS)
	generator.maximum_backtracks = 100000
	return generator


func _placements_contain(keys: PackedStringArray, stable_id: String) -> bool:
	for key: String in keys:
		if key.begins_with(stable_id + "@"):
			return true
	return false


func _count_placements(keys: PackedStringArray, stable_id: String) -> int:
	var count := 0
	for key: String in keys:
		if key.begins_with(stable_id + "@"):
			count += 1
	return count


func _all_neighbor_edges_match(generator: TerrainChunkGenerator) -> bool:
	for index: int in generator._placements.size():
		var coordinate := Vector2i(
			index % generator.grid_size.x,
			index / generator.grid_size.x,
		)
		var current: TerrainChunkVariant = generator._placements[index]
		if coordinate.x > 0:
			var west: TerrainChunkVariant = generator._placements[index - 1]
			if not generator._edges_are_compatible(
				current,
				TerrainChunkTopology.Edge.WEST,
				west,
				TerrainChunkTopology.Edge.EAST,
			):
				return false
		if coordinate.y > 0:
			var north: TerrainChunkVariant = (
				generator._placements[index - generator.grid_size.x]
			)
			if not generator._edges_are_compatible(
				current,
				TerrainChunkTopology.Edge.NORTH,
				north,
				TerrainChunkTopology.Edge.SOUTH,
			):
				return false
	return true


func _validate_layout_rules(generator: TerrainChunkGenerator) -> void:
	_check(
		generator._neighbor_requirement_validation_error(
			generator._placements
		).is_empty(),
		"Every generated chunk must satisfy its authored neighbor count.",
	)
	_check(
		generator._walkable_connectivity_validation_error(
			generator._placements
		).is_empty(),
		"All walkable generated terrain must remain connected to spawn.",
	)
	var center := Vector2i(
		generator.grid_size.x / 2,
		generator.grid_size.y / 2,
	)
	var safe_spawn_neighbors := 0
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var neighbor_coordinate := (
			center
			+ TerrainChunkTopology.grid_offset(
				edge_value as TerrainChunkTopology.Edge
			)
		)
		var neighbor := generator._placements[
			neighbor_coordinate.y * generator.grid_size.x
			+ neighbor_coordinate.x
		]
		if "spawn_safe" in neighbor.definition.tags:
			safe_spawn_neighbors += 1
	_check(
		safe_spawn_neighbors >= 3,
		"At least three cardinal spawn neighbors must be safe flat grass.",
	)
	for index: int in generator._placements.size():
		var placement := generator._placements[index]
		var coordinate := Vector2i(
			index % generator.grid_size.x,
			index / generator.grid_size.x,
		)
		if "coast" in placement.definition.tags:
			_check(
				generator._variant_respects_ocean_boundary(
					placement,
					coordinate,
				),
				"Every coastline chunk must direct its ocean edge outside the grid.",
			)
		if placement.definition.stable_id == &"chunk_0006":
			var touches_beach := false
			var touches_grass_edge := false
			for edge_value: int in TerrainChunkTopology.Edge.values():
				var neighbor_coordinate := (
					coordinate
					+ TerrainChunkTopology.grid_offset(
						edge_value as TerrainChunkTopology.Edge
					)
				)
				if not generator._coordinate_is_inside_grid(neighbor_coordinate):
					continue
				var neighbor := generator._placements[
					neighbor_coordinate.y * generator.grid_size.x
					+ neighbor_coordinate.x
				]
				touches_beach = (
					touches_beach
					or neighbor.definition.stable_id == &"chunk_0002"
				)
				touches_grass_edge = (
					touches_grass_edge
					or neighbor.definition.stable_id == &"chunk_0005"
				)
			_check(
				touches_beach and touches_grass_edge,
				"Every grass/beach transition must join both authored edge types.",
			)
		if placement.definition.stable_id == &"chunk_0007":
			var straight_edge_neighbors := 0
			for edge_value: int in TerrainChunkTopology.Edge.values():
				var neighbor_coordinate := (
					coordinate
					+ TerrainChunkTopology.grid_offset(
						edge_value as TerrainChunkTopology.Edge
					)
				)
				if not generator._coordinate_is_inside_grid(neighbor_coordinate):
					continue
				var neighbor := generator._placements[
					neighbor_coordinate.y * generator.grid_size.x
					+ neighbor_coordinate.x
				]
				if neighbor.definition.stable_id == &"chunk_0005":
					straight_edge_neighbors += 1
			_check(
				straight_edge_neighbors == 2,
				"Every grass corner must join two straight grass ocean edges.",
			)
		if placement.definition.stable_id == &"chunk_0008":
			var straight_beach_neighbors := 0
			for edge_value: int in TerrainChunkTopology.Edge.values():
				var neighbor_coordinate := (
					coordinate
					+ TerrainChunkTopology.grid_offset(
						edge_value as TerrainChunkTopology.Edge
					)
				)
				if not generator._coordinate_is_inside_grid(neighbor_coordinate):
					continue
				var neighbor := generator._placements[
					neighbor_coordinate.y * generator.grid_size.x
					+ neighbor_coordinate.x
				]
				if neighbor.definition.stable_id == &"chunk_0002":
					straight_beach_neighbors += 1
			_check(
				straight_beach_neighbors == 2,
				"Every beach corner must join two straight beach ocean edges.",
			)
		if placement.definition.stable_id != &"chunk_0001":
			continue
		var touches_coast := false
		for edge_value: int in TerrainChunkTopology.Edge.values():
			var neighbor_coordinate := (
				coordinate
				+ TerrainChunkTopology.grid_offset(
					edge_value as TerrainChunkTopology.Edge
				)
			)
			if not generator._coordinate_is_inside_grid(neighbor_coordinate):
				continue
			var neighbor := generator._placements[
				neighbor_coordinate.y * generator.grid_size.x
				+ neighbor_coordinate.x
			]
			if "coast" in neighbor.definition.tags:
				touches_coast = true
		_check(
			touches_coast,
			"Every flat-sand chunk must remain directly attached to a beach.",
		)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Terrain chunk generator validation: PASS")
		quit(0)
		return
	for failure: String in _failures:
		printerr("Terrain chunk generator validation: ", failure)
	quit(1)
