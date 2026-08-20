extends SceneTree

const BIOME_CATALOG: TerrainBiomeCatalog = preload(
	"res://world/generation/biomes/terrain_biome_catalog.tres"
)
const PROP_CATALOG: TerrainPropCatalog = preload(
	"res://world/generation/props/terrain_prop_catalog.tres"
)
const EXPECTED_BIOMES: Array[StringName] = [
	&"biome_plains",
	&"biome_forest",
	&"biome_pine_forest",
	&"biome_coast",
]
const TEST_SEED := 13001

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_validate_catalog()
	_validate_assignment()
	_finish()


func _validate_catalog() -> void:
	for error: String in BIOME_CATALOG.validation_errors():
		_check(false, error)
	_check(
		BIOME_CATALOG.definitions.size() == EXPECTED_BIOMES.size(),
		"The biome catalog must contain all initial authored profiles.",
	)
	for biome_id: StringName in EXPECTED_BIOMES:
		var biome := BIOME_CATALOG.definition_for_id(biome_id)
		_check(biome != null, "The biome catalog is missing %s." % biome_id)
		if biome == null:
			continue
		for rule: TerrainBiomePropRule in biome.prop_rules:
			for prop_id_value: String in rule.allowed_prop_ids:
				var prop := PROP_CATALOG.definition_for_id(
					StringName(prop_id_value)
				)
				_check(
					prop != null and rule.allows_prop(prop),
					"%s has an invalid %s prop rule."
					% [biome_id, prop_id_value],
				)


func _validate_assignment() -> void:
	var records := _synthetic_records()
	var first := TerrainBiomeAssigner.assign(
		BIOME_CATALOG,
		records,
		TEST_SEED,
	)
	var second := TerrainBiomeAssigner.assign(
		BIOME_CATALOG,
		records,
		TEST_SEED,
	)
	_check(first == second, "Biome assignment must be deterministic by seed.")
	_check(
		TerrainBiomeAssigner.fingerprint(first).length() == 64,
		"Biome assignments must expose a SHA-256 fingerprint.",
	)
	var counts := TerrainBiomeAssigner.counts(first)
	for biome_id: StringName in EXPECTED_BIOMES:
		_check(
			counts.get(biome_id, 0) > 0,
			"The synthetic map must contain %s." % biome_id,
		)
	_check(
		first.get(Vector2i(3, 3), &"") == &"biome_plains",
		"The spawn-tagged center must remain plains.",
	)
	for record: Dictionary in records:
		var coordinate: Vector2i = record["coordinate"]
		var tags: PackedStringArray = record["tags"]
		var biome_id: StringName = first.get(coordinate, &"")
		if "fresh_water" in tags:
			_check(
				biome_id == &"",
				"Freshwater-only chunks must not inherit a land-prop biome.",
			)
			continue
		var biome := BIOME_CATALOG.definition_for_id(biome_id)
		_check(
			biome != null and biome.supports_chunk_tags(tags),
			"Biome %s does not support chunk %s."
			% [biome_id, coordinate],
		)


func _synthetic_records() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: int in 7:
		for column: int in 7:
			var coordinate := Vector2i(column, row)
			var tags := PackedStringArray(["land", "walkable", "grass"])
			if row == 0:
				tags = PackedStringArray(["land", "walkable", "sand"])
			elif coordinate == Vector2i(0, 6):
				tags = PackedStringArray([
					"land",
					"walkable",
					"fresh_water",
					"pond",
				])
			elif coordinate == Vector2i(3, 3):
				tags.append("spawn")
			result.append({
				"coordinate": coordinate,
				"tags": tags,
			})
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Terrain biome validation: PASS")
		quit(0)
		return
	for failure: String in _failures:
		printerr("Terrain biome validation: ", failure)
	quit(1)
