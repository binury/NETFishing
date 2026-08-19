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
	"chunk_spawn",
]
const REQUIRED_IDS: Array[String] = [
	"chunk_spawn",
	"chunk_0001",
	"chunk_0002",
	"chunk_0003",
	"chunk_0004",
]
const TEST_SEED := 13001

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
			for profile: TerrainChunkEdgeProfile in variant.edge_profiles:
				_check(
					not profile.points.is_empty(),
					"%s has an empty edge profile." % variant.stable_key(),
				)


func _validate_generation() -> void:
	var first := _make_generator()
	root.add_child(first)
	var first_solved := first.generate()
	_check(first_solved, "Generator must solve the prototype 5x5 grid.")
	if not first_solved:
		first.free()
		return
	var first_keys := first.placement_keys()
	_check(first_keys.size() == 25, "Generator must place exactly 25 chunks.")
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
		first_keys[12].begins_with("chunk_spawn@"),
		"The spawn chunk must occupy the center cell.",
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
	first.free()
	second.free()

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
		generator.free()


func _make_generator() -> TerrainChunkGenerator:
	var generator := TerrainChunkGenerator.new()
	generator.catalog = CATALOG
	generator.grid_size = Vector2i(5, 5)
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
