class_name TerrainChunkCatalog
extends Resource

@export_range(1.0, 100.0, 0.5) var chunk_size := 10.0
@export var definitions: Array[TerrainChunkDefinition] = []


func definition_for_id(stable_id: StringName) -> TerrainChunkDefinition:
	for definition: TerrainChunkDefinition in definitions:
		if definition != null and definition.stable_id == stable_id:
			return definition
	return null


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen_ids: Dictionary[StringName, bool] = {}
	for index: int in definitions.size():
		var definition := definitions[index]
		if definition == null:
			errors.append("Definition %d is empty." % index)
			continue
		if definition.stable_id == &"":
			errors.append("Definition %d has no stable ID." % index)
		elif seen_ids.has(definition.stable_id):
			errors.append("Stable ID %s is duplicated." % definition.stable_id)
		else:
			seen_ids[definition.stable_id] = true
		if definition.packed_scene == null:
			errors.append("%s has no PackedScene." % definition.stable_id)
		if definition.primary_mesh_name == &"":
			errors.append("%s has no primary mesh name." % definition.stable_id)
		if definition.allowed_rotation_mask == 0:
			errors.append("%s allows no rotations." % definition.stable_id)
		var has_fresh_water := "fresh_water" in definition.tags
		var has_water_footprint := (
			definition.water_surface_size.x > 0.0
			and definition.water_surface_size.y > 0.0
		)
		if has_fresh_water and not has_water_footprint:
			errors.append(
				"%s is freshwater but has no water footprint."
				% definition.stable_id
			)
		elif not has_fresh_water and has_water_footprint:
			errors.append(
				"%s has a water footprint without the freshwater tag."
				% definition.stable_id
			)
	return errors
