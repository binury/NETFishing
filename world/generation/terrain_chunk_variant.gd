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


func topology_signature(quantization: float) -> String:
	var tokens := PackedStringArray()
	for edge_value: int in TerrainChunkTopology.Edge.values():
		var edge := edge_value as TerrainChunkTopology.Edge
		tokens.append(profile(edge).signature(quantization))
	return "|".join(tokens)


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
