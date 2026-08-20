extends SceneTree

const CATALOG: TerrainChunkCatalog = preload(
	"res://world/generation/chunks/terrain_chunk_catalog.tres"
)
const BIOME_CATALOG: TerrainBiomeCatalog = preload(
	"res://world/generation/biomes/terrain_biome_catalog.tres"
)


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var generator := _make_generator()
	root.add_child(generator)
	if not generator._prepare_catalog():
		generator.free()
		quit(1)
		return
	var variants: Array[TerrainChunkVariant] = []
	variants.assign(generator._solver_variants)

	print(
		"Terrain chunk rotations: %d authored, %d distinct constraints"
		% [generator._variants.size(), variants.size()]
	)
	for variant: TerrainChunkVariant in variants:
		print("\n", variant.stable_key())
		var ocean_edges := variant.rotated_edge_mask(
			variant.definition.ocean_facing_edges
		)
		for edge_value: int in TerrainChunkTopology.Edge.values():
			var edge := edge_value as TerrainChunkTopology.Edge
			var matches := PackedStringArray()
			for other: TerrainChunkVariant in variants:
				var opposite := TerrainChunkTopology.opposite_edge(edge)
				if generator._edges_are_compatible(
					variant,
					edge,
					other,
					opposite,
				):
					matches.append(
						"%s.%s"
						% [
							other.stable_key(),
							TerrainChunkTopology.edge_name(opposite),
						]
					)
			print(
				"  %s%s [%d points]: %s"
				% [
					TerrainChunkTopology.edge_name(edge),
					(
						" [ocean]"
						if (ocean_edges & (1 << edge_value)) != 0
						else ""
					),
					variant.profile(edge).points.size(),
					", ".join(matches) if not matches.is_empty() else "NONE",
				]
			)

	if generator.generate():
		var summary := generator._build_summary()
		print(
			(
				"\nSeeded diagnostic layout %s "
				+ "(%d backtracks, %d repeated edges):"
			)
			% [
				str(summary["layout_fingerprint"]).substr(0, 12),
				int(summary["backtracks"]),
				int(summary["adjacent_repeat_edges"]),
			]
		)
		var keys := generator.placement_keys()
		for row: int in generator.grid_size.y:
			var cells := PackedStringArray()
			for column: int in generator.grid_size.x:
				cells.append(keys[row * generator.grid_size.x + column])
			print("  ", "  ".join(cells))
		var biomes := TerrainBiomeAssigner.assign(
			BIOME_CATALOG,
			generator.placement_records(),
			generator.generation_seed,
		)
		print("\nBiome layout:")
		for row: int in generator.grid_size.y:
			var cells := PackedStringArray()
			for column: int in generator.grid_size.x:
				var biome_id: StringName = biomes.get(
					Vector2i(column, row),
					&"",
				)
				cells.append(String(biome_id).trim_prefix("biome_"))
			print("  ", "  ".join(cells))
	generator.free()
	quit(0)


func _make_generator() -> TerrainChunkGenerator:
	var generator := TerrainChunkGenerator.new()
	generator.catalog = CATALOG
	generator.grid_size = Vector2i(7, 7)
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
			"chunk_0005",
			"chunk_0006",
			"chunk_0007",
		]
	)
	return generator
