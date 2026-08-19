extends SceneTree

const CATALOG: TerrainChunkCatalog = preload(
	"res://world/generation/chunks/terrain_chunk_catalog.tres"
)
const MATCH_TOLERANCE := 0.01


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var variants: Array[TerrainChunkVariant] = []
	for definition: TerrainChunkDefinition in CATALOG.definitions:
		var seen: Dictionary[String, bool] = {}
		for variant: TerrainChunkVariant in TerrainChunkAnalyzer.create_variants(
			definition,
			CATALOG.chunk_size,
		):
			var signature := variant.topology_signature(0.001)
			if seen.has(signature):
				continue
			seen[signature] = true
			variants.append(variant)

	print("Terrain chunk variants: %d" % variants.size())
	for variant: TerrainChunkVariant in variants:
		print("\n", variant.stable_key())
		for edge_value: int in TerrainChunkTopology.Edge.values():
			var edge := edge_value as TerrainChunkTopology.Edge
			var matches := PackedStringArray()
			for other: TerrainChunkVariant in variants:
				var opposite := TerrainChunkTopology.opposite_edge(edge)
				if variant.profile(edge).matches(
					other.profile(opposite),
					MATCH_TOLERANCE,
				):
					matches.append(
						"%s.%s"
						% [
							other.stable_key(),
							TerrainChunkTopology.edge_name(opposite),
						]
					)
			print(
				"  %s [%d points]: %s"
				% [
					TerrainChunkTopology.edge_name(edge),
					variant.profile(edge).points.size(),
					", ".join(matches) if not matches.is_empty() else "NONE",
				]
			)

	var generator := TerrainChunkGenerator.new()
	generator.catalog = CATALOG
	generator.grid_size = Vector2i(5, 5)
	generator.generation_seed = 13001
	generator.generate_on_ready = false
	generator.build_collision = false
	generator.force_center_chunk_id = &"chunk_spawn"
	generator.required_chunk_ids = PackedStringArray(
		[
			"chunk_spawn",
			"chunk_0001",
			"chunk_0002",
			"chunk_0003",
			"chunk_0004",
		]
	)
	root.add_child(generator)
	if generator.generate():
		print("\nSeeded diagnostic layout:")
		var keys := generator.placement_keys()
		for row: int in generator.grid_size.y:
			var cells := PackedStringArray()
			for column: int in generator.grid_size.x:
				cells.append(keys[row * generator.grid_size.x + column])
			print("  ", "  ".join(cells))
	generator.free()
	quit(0)
