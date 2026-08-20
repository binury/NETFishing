class_name TerrainBiomeAssigner
extends RefCounted

const BIOME_SEED_SALT := 0xB10E5
const SCORE_JITTER := 0.2


static func assign(
	catalog: TerrainBiomeCatalog,
	records: Array[Dictionary],
	generation_seed: int,
) -> Dictionary[Vector2i, StringName]:
	var assignments: Dictionary[Vector2i, StringName] = {}
	if catalog == null:
		return assignments
	var records_by_signature: Dictionary[String, Array] = {}
	var definitions_by_signature: Dictionary[String, Array] = {}
	for record: Dictionary in records:
		var tags: PackedStringArray = record.get("tags", PackedStringArray())
		var definitions := catalog.definitions_for_tags(tags)
		if definitions.is_empty():
			continue
		var signature := _definition_signature(definitions)
		var grouped_records: Array = records_by_signature.get(signature, [])
		grouped_records.append(record)
		records_by_signature[signature] = grouped_records
		definitions_by_signature[signature] = definitions

	var signatures := PackedStringArray()
	for signature_value: Variant in records_by_signature:
		signatures.append(str(signature_value))
	signatures.sort()
	for signature: String in signatures:
		var grouped_records: Array[Dictionary] = []
		grouped_records.assign(records_by_signature[signature])
		grouped_records.sort_custom(_record_less_than)
		var definitions: Array[TerrainBiomeDefinition] = []
		definitions.assign(definitions_by_signature[signature])
		if definitions.size() == 1:
			for record: Dictionary in grouped_records:
				assignments[record.get("coordinate", Vector2i.ZERO)] = (
					definitions[0].stable_id
				)
			continue
		_assign_clustered_group(
			assignments,
			grouped_records,
			definitions,
			generation_seed,
			signature,
		)
	return assignments


static func counts(
	assignments: Dictionary[Vector2i, StringName],
) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for biome_id: StringName in assignments.values():
		result[biome_id] = result.get(biome_id, 0) + 1
	return result


static func fingerprint(
	assignments: Dictionary[Vector2i, StringName],
) -> String:
	var coordinates: Array[Vector2i] = []
	coordinates.assign(assignments.keys())
	coordinates.sort_custom(_coordinate_less_than)
	var tokens := PackedStringArray()
	for coordinate: Vector2i in coordinates:
		tokens.append(
			"%d,%d:%s"
			% [coordinate.x, coordinate.y, assignments[coordinate]]
		)
	return "\n".join(tokens).sha256_text()


static func _assign_clustered_group(
	assignments: Dictionary[Vector2i, StringName],
	records: Array[Dictionary],
	definitions: Array[TerrainBiomeDefinition],
	generation_seed: int,
	signature: String,
) -> void:
	var anchors := _build_anchors(
		records,
		definitions,
		generation_seed,
		signature,
	)
	for record: Dictionary in records:
		var coordinate: Vector2i = record.get("coordinate", Vector2i.ZERO)
		var best_definition: TerrainBiomeDefinition
		var best_score := INF
		for definition: TerrainBiomeDefinition in definitions:
			var anchor: Vector2i = anchors.get(
				definition.stable_id,
				coordinate,
			)
			var delta := coordinate - anchor
			var score := (
				float(delta.length_squared())
				/ maxf(definition.region_weight, 0.1)
				+ _score_jitter(
					generation_seed,
					coordinate,
					definition.stable_id,
				)
			)
			if score < best_score:
				best_score = score
				best_definition = definition
		if best_definition != null:
			assignments[coordinate] = best_definition.stable_id


static func _build_anchors(
	records: Array[Dictionary],
	definitions: Array[TerrainBiomeDefinition],
	generation_seed: int,
	signature: String,
) -> Dictionary[StringName, Vector2i]:
	var anchors: Dictionary[StringName, Vector2i] = {}
	var available_coordinates: Array[Vector2i] = []
	for record: Dictionary in records:
		available_coordinates.append(
			record.get("coordinate", Vector2i.ZERO)
		)
	var random := RandomNumberGenerator.new()
	random.seed = (
		generation_seed
		^ int(signature.hash())
		^ BIOME_SEED_SALT
	)
	for definition: TerrainBiomeDefinition in definitions:
		if available_coordinates.is_empty():
			for record: Dictionary in records:
				available_coordinates.append(
					record.get("coordinate", Vector2i.ZERO)
				)
		var selected_index := 0
		if anchors.is_empty():
			selected_index = random.randi_range(
				0,
				available_coordinates.size() - 1,
			)
		else:
			selected_index = _most_separated_coordinate_index(
				available_coordinates,
				anchors.values(),
				random,
			)
		anchors[definition.stable_id] = available_coordinates[selected_index]
		available_coordinates.remove_at(selected_index)
	return anchors


static func _most_separated_coordinate_index(
	coordinates: Array[Vector2i],
	anchor_values: Array,
	random: RandomNumberGenerator,
) -> int:
	var best_distance := -1
	var best_indices: Array[int] = []
	for index: int in coordinates.size():
		var coordinate := coordinates[index]
		var nearest_distance := 1 << 30
		for anchor_value: Variant in anchor_values:
			var anchor: Vector2i = anchor_value
			nearest_distance = mini(
				nearest_distance,
				(coordinate - anchor).length_squared(),
			)
		if nearest_distance > best_distance:
			best_distance = nearest_distance
			best_indices = [index]
		elif nearest_distance == best_distance:
			best_indices.append(index)
	return best_indices[random.randi_range(0, best_indices.size() - 1)]


static func _score_jitter(
	generation_seed: int,
	coordinate: Vector2i,
	biome_id: StringName,
) -> float:
	var token := "%d:%d:%d:%s" % [
		generation_seed,
		coordinate.x,
		coordinate.y,
		biome_id,
	]
	return (
		float(posmod(token.hash(), 1000))
		/ 1000.0
		* SCORE_JITTER
	)


static func _definition_signature(
	definitions: Array[TerrainBiomeDefinition],
) -> String:
	var ids := PackedStringArray()
	for definition: TerrainBiomeDefinition in definitions:
		ids.append(String(definition.stable_id))
	return "|".join(ids)


static func _record_less_than(first: Dictionary, second: Dictionary) -> bool:
	return _coordinate_less_than(
		first.get("coordinate", Vector2i.ZERO),
		second.get("coordinate", Vector2i.ZERO),
	)


static func _coordinate_less_than(first: Vector2i, second: Vector2i) -> bool:
	if first.y == second.y:
		return first.x < second.x
	return first.y < second.y
