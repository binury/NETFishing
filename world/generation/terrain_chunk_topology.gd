class_name TerrainChunkTopology
extends RefCounted

enum Edge {
	NORTH,
	EAST,
	SOUTH,
	WEST,
}


static func opposite_edge(edge: Edge) -> Edge:
	return ((int(edge) + 2) % 4) as Edge


static func edge_name(edge: Edge) -> String:
	match edge:
		Edge.NORTH:
			return "north"
		Edge.EAST:
			return "east"
		Edge.SOUTH:
			return "south"
		Edge.WEST:
			return "west"
	return "unknown"


static func edge_normal(edge: Edge) -> Vector3:
	match edge:
		Edge.NORTH:
			return Vector3.FORWARD
		Edge.EAST:
			return Vector3.RIGHT
		Edge.SOUTH:
			return Vector3.BACK
		Edge.WEST:
			return Vector3.LEFT
	return Vector3.ZERO


static func rotated_edge(edge: Edge, quarter_turns: int) -> Edge:
	var angle := float(posmod(quarter_turns, 4)) * PI * 0.5
	var normal := edge_normal(edge).rotated(Vector3.UP, angle)
	var best_edge := Edge.NORTH
	var best_dot := -INF
	for candidate_value: int in Edge.values():
		var candidate := candidate_value as Edge
		var alignment := normal.dot(edge_normal(candidate))
		if alignment > best_dot:
			best_dot = alignment
			best_edge = candidate
	return best_edge
