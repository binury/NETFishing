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
		if (
			(definition.base_layer_scene == null)
			!= (definition.base_layer_mesh_name == &"")
		):
			errors.append(
				"%s must define both base-layer scene and mesh name."
				% definition.stable_id
			)
		if definition.overlay_only and definition.base_layer_scene == null:
			errors.append(
				"%s is overlay-only but has no base-layer scene."
				% definition.stable_id
			)
		if definition.allowed_rotation_mask == 0:
			errors.append("%s allows no rotations." % definition.stable_id)
		var has_coast := "coast" in definition.tags
		var has_ocean_edge := definition.ocean_facing_edges != 0
		if has_coast and not has_ocean_edge:
			errors.append(
				"%s is coastal but has no ocean-facing edge."
				% definition.stable_id
			)
		elif not has_coast and has_ocean_edge:
			errors.append(
				"%s has an ocean-facing edge without the coast tag."
				% definition.stable_id
			)
		if definition.must_be_interior and definition.prefers_map_boundary:
			errors.append(
				"%s cannot require the interior and prefer the boundary."
				% definition.stable_id
			)
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
		for allowed_tag: String in definition.allowed_neighbor_tags:
			if allowed_tag in definition.forbidden_neighbor_tags:
				errors.append(
					(
						"%s both allows and forbids neighbor tag '%s'."
						% [definition.stable_id, allowed_tag]
					)
				)
		for edge_value: int in TerrainChunkTopology.Edge.values():
			var edge := edge_value as TerrainChunkTopology.Edge
			for allowed_tag: String in (
				definition.directional_allowed_neighbor_tags(edge)
			):
				if allowed_tag not in definition.forbidden_neighbor_tags:
					continue
				errors.append(
					(
						"%s both allows and forbids neighbor tag '%s' on its %s edge."
						% [
							definition.stable_id,
							allowed_tag,
							TerrainChunkTopology.edge_name(edge),
						]
					)
				)
		if (
			definition.minimum_required_neighbors > 0
			and definition.required_neighbor_tags.is_empty()
		):
			errors.append(
				"%s requires neighbors but defines no required neighbor tags."
				% definition.stable_id
			)
	return errors
