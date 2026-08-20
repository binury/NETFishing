class_name TerrainPropCatalog
extends Resource

@export var definitions: Array[TerrainPropDefinition] = []


func definition_for_id(stable_id: StringName) -> TerrainPropDefinition:
	for definition: TerrainPropDefinition in definitions:
		if definition != null and definition.stable_id == stable_id:
			return definition
	return null


func procedural_definitions(
	group: StringName,
	chunk_tags: PackedStringArray,
) -> Array[TerrainPropDefinition]:
	var result: Array[TerrainPropDefinition] = []
	for definition: TerrainPropDefinition in definitions:
		if (
			definition != null
			and definition.procedural_group == group
			and definition.supports_chunk_tags(chunk_tags)
		):
			result.append(definition)
	return result


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary[StringName, bool] = {}
	for index: int in definitions.size():
		var definition := definitions[index]
		if definition == null:
			errors.append("Prop definition %d is empty." % index)
			continue
		if definition.stable_id == &"":
			errors.append("Prop definition %d has no stable ID." % index)
		elif seen_ids.has(definition.stable_id):
			errors.append("Prop ID %s is duplicated." % definition.stable_id)
		else:
			seen_ids[definition.stable_id] = true
		if definition.packed_scene == null:
			errors.append("%s has no PackedScene." % definition.stable_id)
		if (
			definition.is_procedural()
			and definition.required_chunk_tags.is_empty()
		):
			errors.append(
				"%s is procedural but has no required chunk tags."
				% definition.stable_id
			)
		if (
			not definition.preferred_nearby_prop_groups.is_empty()
			and definition.preferred_nearby_radius <= 0.0
		):
			errors.append(
				"%s prefers nearby props but defines no search radius."
				% definition.stable_id
			)
		var has_collision_radius := definition.collision_radius > 0.0
		var has_collision_height := definition.collision_height > 0.0
		if has_collision_radius != has_collision_height:
			errors.append(
				"%s must define both collision radius and height."
				% definition.stable_id
			)
		if (
			definition.has_cylinder_collision()
			and definition.has_box_collision()
		):
			errors.append(
				"%s defines more than one collision shape."
				% definition.stable_id
			)
		if (
			definition.collision_box_size.x < 0.0
			or definition.collision_box_size.y < 0.0
			or definition.collision_box_size.z < 0.0
		):
			errors.append(
				"%s has a negative box collision dimension."
				% definition.stable_id
			)
	return errors
