class_name TerrainChunkVariant
extends RefCounted

var definition: TerrainChunkDefinition
var quarter_turns := 0
var edge_profiles: Array[TerrainChunkEdgeProfile] = []


func profile(edge: TerrainChunkTopology.Edge) -> TerrainChunkEdgeProfile:
	return edge_profiles[int(edge)]


func rotation_radians() -> float:
	return float(posmod(quarter_turns, 4)) * PI * 0.5


func stable_key() -> String:
	return "%s@%d" % [definition.stable_id, posmod(quarter_turns, 4)]


func source_edge(edge: TerrainChunkTopology.Edge) -> TerrainChunkTopology.Edge:
	return TerrainChunkTopology.rotated_edge(edge, -quarter_turns)


func allows_non_water_neighbor_on_edge(
	neighbor: TerrainChunkVariant,
	edge: TerrainChunkTopology.Edge,
) -> bool:
	return (
		neighbor != null
		and definition.allows_non_water_neighbor_on_edge(
			neighbor.definition,
			source_edge(edge),
		)
	)


func surface_tags(edge: TerrainChunkTopology.Edge) -> PackedStringArray:
	return definition.surface_tags_for_edge(source_edge(edge))


func topology_signature(quantization: float) -> String:
	var tokens := PackedStringArray()
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var edge := edge_value as TerrainChunkTopology.Edge
		tokens.append(profile(edge).signature(quantization))
	return "|".join(tokens)


func constraint_signature(quantization: float) -> String:
	return (
		"%s|neighbors:%s|surfaces:%s|ocean:%d|buried:%d|in:%d|out:%d"
		% [
		topology_signature(quantization),
		_neighbor_rule_signature(),
		_surface_rule_signature(),
		rotated_edge_mask(definition.ocean_facing_edges),
		rotated_edge_mask(definition.buried_cliff_seam_edges),
		rotated_edge_mask(definition.water_inlet_edges),
		rotated_edge_mask(definition.water_outlet_edges),
		]
	)


func _neighbor_rule_signature() -> String:
	var edge_tokens := PackedStringArray()
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var edge := edge_value as TerrainChunkTopology.Edge
		var tags: PackedStringArray = definition.allowed_neighbor_tags_for_edge(
			source_edge(edge)
		).duplicate()
		tags.sort()
		edge_tokens.append(",".join(tags))
	return "/".join(edge_tokens)


func _surface_rule_signature() -> String:
	var edge_tokens := PackedStringArray()
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var edge := edge_value as TerrainChunkTopology.Edge
		var edge_tags: PackedStringArray = surface_tags(edge).duplicate()
		edge_tags.sort()
		edge_tokens.append(",".join(edge_tags))
	return "/".join(edge_tokens)


func rotated_edge_mask(source_mask: int) -> int:
	var result := 0
	for edge_value: int in TerrainChunkTopology.Edge.values():
		if (source_mask & (1 << edge_value)) == 0:
			continue
		var rotated := TerrainChunkTopology.rotated_edge(
			edge_value as TerrainChunkTopology.Edge,
			quarter_turns,
		)
		result |= 1 << int(rotated)
	return result
