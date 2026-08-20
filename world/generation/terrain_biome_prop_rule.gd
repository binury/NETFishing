class_name TerrainBiomePropRule
extends Resource

@export var procedural_group: StringName
@export_range(0, 10000, 1) var placement_chance := 0
@export_range(0, 10000, 1) var adjacency_bonus := 0
@export_range(0, 10000, 1) var maximum_density := 10000
@export_range(0, 64, 1) var minimum_placements := 0
## Empty permits every compatible prop in the procedural group.
@export var allowed_prop_ids := PackedStringArray()


func allows_prop(definition: TerrainPropDefinition) -> bool:
	return (
		definition != null
		and definition.procedural_group == procedural_group
		and (
			allowed_prop_ids.is_empty()
			or String(definition.stable_id) in allowed_prop_ids
		)
	)
