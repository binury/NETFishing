class_name TerrainBiomeCatalog
extends Resource

@export var definitions: Array[TerrainBiomeDefinition] = []


func definition_for_id(stable_id: StringName) -> TerrainBiomeDefinition:
	for definition: TerrainBiomeDefinition in definitions:
		if definition != null and definition.stable_id == stable_id:
			return definition
	return null


func definitions_for_tags(
	chunk_tags: PackedStringArray,
) -> Array[TerrainBiomeDefinition]:
	var result: Array[TerrainBiomeDefinition] = []
	for definition: TerrainBiomeDefinition in definitions:
		if definition != null and definition.supports_chunk_tags(chunk_tags):
			result.append(definition)
	return result


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary[StringName, bool] = {}
	for index: int in definitions.size():
		var definition := definitions[index]
		if definition == null:
			errors.append("Biome definition %d is empty." % index)
			continue
		if definition.stable_id == &"":
			errors.append("Biome definition %d has no stable ID." % index)
		elif seen_ids.has(definition.stable_id):
			errors.append("Biome ID %s is duplicated." % definition.stable_id)
		else:
			seen_ids[definition.stable_id] = true
		if definition.required_chunk_tags.is_empty():
			errors.append(
				"%s has no required chunk tags." % definition.stable_id
			)
		for required_tag: String in definition.required_chunk_tags:
			if required_tag in definition.forbidden_chunk_tags:
				errors.append(
					"%s both requires and forbids chunk tag '%s'."
					% [definition.stable_id, required_tag]
				)
		var seen_groups: Dictionary[StringName, bool] = {}
		for rule_index: int in definition.prop_rules.size():
			var rule := definition.prop_rules[rule_index]
			if rule == null:
				errors.append(
					"%s prop rule %d is empty."
					% [definition.stable_id, rule_index]
				)
				continue
			if rule.procedural_group == &"":
				errors.append(
					"%s prop rule %d has no group."
					% [definition.stable_id, rule_index]
				)
			elif seen_groups.has(rule.procedural_group):
				errors.append(
					"%s duplicates prop group %s."
					% [definition.stable_id, rule.procedural_group]
				)
			else:
				seen_groups[rule.procedural_group] = true
			if rule.minimum_placements > 0 and rule.placement_chance <= 0:
				errors.append(
					"%s requires %s props but gives them no placement chance."
					% [definition.stable_id, rule.procedural_group]
				)
	return errors
