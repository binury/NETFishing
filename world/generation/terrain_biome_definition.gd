class_name TerrainBiomeDefinition
extends Resource

@export var stable_id: StringName
@export var label := ""
@export var required_chunk_tags := PackedStringArray()
@export var forbidden_chunk_tags := PackedStringArray()
## Larger values give this biome more territory around its seeded anchor.
@export_range(0.1, 10.0, 0.1) var region_weight := 1.0
@export var prop_rules: Array[TerrainBiomePropRule] = []


func supports_chunk_tags(chunk_tags: PackedStringArray) -> bool:
	for required_tag: String in required_chunk_tags:
		if required_tag not in chunk_tags:
			return false
	for forbidden_tag: String in forbidden_chunk_tags:
		if forbidden_tag in chunk_tags:
			return false
	return true


func prop_rule_for_group(group: StringName) -> TerrainBiomePropRule:
	for rule: TerrainBiomePropRule in prop_rules:
		if rule != null and rule.procedural_group == group:
			return rule
	return null
