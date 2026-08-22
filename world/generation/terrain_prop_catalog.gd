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
			definition.gatherable_anchor_height > 0.0
			and definition.gatherable_anchor_surface_radius() <= 0.0
		):
			errors.append(
				"%s is gatherable but has no trunk-surface radius."
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
		if definition.minimum_visual_scale > definition.maximum_visual_scale:
			errors.append(
				"%s has an inverted visual scale range."
				% definition.stable_id
			)
		if definition.minimum_cluster_size > definition.maximum_cluster_size:
			errors.append(
				"%s has an inverted cluster size range."
				% definition.stable_id
			)
		if (
			definition.maximum_cluster_size > 1
			and (
				definition.minimum_cluster_radius <= 0.0
				or definition.minimum_cluster_radius
				> definition.maximum_cluster_radius
			)
		):
			errors.append(
				"%s has an invalid loose-cluster radius."
				% definition.stable_id
			)
		if (
			not definition.material_variants.is_empty()
			and definition.variant_material_slot_names.is_empty()
		):
			errors.append(
				"%s has material variants but no target material slots."
				% definition.stable_id
			)
		for material: Material in definition.material_variants:
			if material == null:
				errors.append(
					"%s contains an empty material variant."
					% definition.stable_id
				)
		if (
			not definition.secondary_material_variants.is_empty()
			and definition.secondary_variant_material_slot_names.is_empty()
		):
			errors.append(
				"%s has secondary variants but no target material slots."
				% definition.stable_id
			)
		for material: Material in definition.secondary_material_variants:
			if material == null:
				errors.append(
					"%s contains an empty secondary material variant."
					% definition.stable_id
				)
		if (
			definition.prefer_ocean_facing
			and definition.local_overhang_direction.is_zero_approx()
		):
			errors.append(
				"%s prefers the ocean but has no local overhang direction."
				% definition.stable_id
			)
	return errors
