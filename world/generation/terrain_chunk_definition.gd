class_name TerrainChunkDefinition
extends Resource

@export var stable_id: StringName
@export var label := ""
@export var packed_scene: PackedScene
@export var primary_mesh_name: StringName
## Optional existing level-one chunk placed beneath an authored elevated
## overlay. This lets cliff edges leave their downhill side open while the
## ordinary base terrain remains present in the same generated cell.
@export_group("Layered Terrain")
@export var base_layer_scene: PackedScene
@export var base_layer_mesh_name: StringName
## Optional canonical rotation applied to a layered base before the authored
## chunk variant rotation. Coastal transition overlays use this to align one
## shared coastline scene with either downhill side of a corner.
@export_range(0, 3, 1) var base_layer_quarter_turns := 0
## Overlay-only chunks replace a reserved base-terrain placement after the
## ordinary terrain solve. Inland overlays normally provide base_layer_scene;
## complete coastal overlays can instead carry their own descent to sea level.
## They remain in placement manifests and runtime output, but do not inflate
## every cell's global solver domain.
@export var overlay_only := false
## Post-process pieces remain available as authored variants and in placement
## manifests, but do not participate in the ordinary base-terrain solve.
@export var participates_in_base_solver := true
@export_group("")
@export_flags("0 degrees", "90 degrees", "180 degrees", "270 degrees")
var allowed_rotation_mask := 15
@export_range(0.01, 100.0, 0.01) var selection_weight := 1.0
## Negative values allow unlimited placements; zero disables random placement.
@export_range(-1, 1024, 1) var maximum_placements := -1
@export var tags := PackedStringArray()
## Empty permits any non-water neighbor. Otherwise at least one listed tag
## must be present on the neighboring chunk. Water connectors are governed by
## their inlet/outlet topology instead.
@export var allowed_neighbor_tags := PackedStringArray()
## These tags always reject a non-water neighbor, even when it also carries an
## allowed tag.
@export var forbidden_neighbor_tags := PackedStringArray()
## Optional canonical per-edge overrides for allowed_neighbor_tags. Empty means
## the edge inherits the chunk-wide list. These describe the visible surface at
## a seam, such as a grass-backed coastline transition that must not meet sand.
@export_group("Directional Neighbor Rules")
@export var north_allowed_neighbor_tags := PackedStringArray()
@export var east_allowed_neighbor_tags := PackedStringArray()
@export var south_allowed_neighbor_tags := PackedStringArray()
@export var west_allowed_neighbor_tags := PackedStringArray()
@export_group("")
## Optional canonical descriptions of the visible terrain surface at each
## edge. Empty edges inherit the definition's ordinary tags. Mixed-surface
## chunks use these to prevent a visually grass edge from joining sand (or the
## reverse) even when the chunk itself carries both biome tags.
@export_group("Directional Surface Rules")
@export var north_surface_tags := PackedStringArray()
@export var east_surface_tags := PackedStringArray()
@export var south_surface_tags := PackedStringArray()
@export var west_surface_tags := PackedStringArray()
@export_group("")
## When non-empty, at least this many in-grid cardinal neighbors must carry one
## of the listed tags. This supports statements such as "three sides around the
## spawn must be safe grass" without hard-coding a particular chunk ID.
@export var required_neighbor_tags := PackedStringArray()
@export_range(0, 4, 1) var minimum_required_neighbors := 0
## Matching already-placed neighbors increase this definition's selection
## weight. This shapes regions without turning a visual preference into a hard
## generation constraint.
@export var preferred_neighbor_tags := PackedStringArray()
## Interior-only pieces may not occupy any outer grid cell. Coastal elevated
## pieces use separate authored definitions rather than weakening this rule.
@export var must_be_interior := false
## Coastal transition pieces should normally migrate toward the generated
## region's perimeter while remaining legal in the interior.
@export var prefers_map_boundary := false
## Edges that descend from land into the surrounding ocean. Every rotated edge
## in this mask must face outside the generated grid; it may never meet another
## terrain chunk.
@export_flags("North", "East", "South", "West") var ocean_facing_edges := 0
## Lateral seams where a deep coastal cliff may join its ordinary inland
## counterpart. Geometry below level-one ground is intentionally ignored on
## these authored edges because the neighboring base terrain buries it.
@export_flags("North", "East", "South", "West") var buried_cliff_seam_edges := 0
@export_flags("North", "East", "South", "West") var water_inlet_edges := 0
@export_flags("North", "East", "South", "West") var water_outlet_edges := 0
## Optional generated water footprint in the chunk's unrotated local X/Z plane.
## Zero means this chunk contributes no standalone water surface.
@export var water_surface_size := Vector2.ZERO
@export var water_surface_offset := Vector2.ZERO


func allows_quarter_turn(quarter_turns: int) -> bool:
	var normalized_turns := posmod(quarter_turns, 4)
	return (allowed_rotation_mask & (1 << normalized_turns)) != 0


func allows_non_water_neighbor(neighbor: TerrainChunkDefinition) -> bool:
	return _allows_neighbor_with_tags(neighbor, allowed_neighbor_tags)


func allows_non_water_neighbor_on_edge(
	neighbor: TerrainChunkDefinition,
	edge: TerrainChunkTopology.Edge,
) -> bool:
	return _allows_neighbor_with_tags(
		neighbor,
		allowed_neighbor_tags_for_edge(edge),
	)


func allowed_neighbor_tags_for_edge(
	edge: TerrainChunkTopology.Edge,
) -> PackedStringArray:
	var edge_tags := directional_allowed_neighbor_tags(edge)
	return allowed_neighbor_tags if edge_tags.is_empty() else edge_tags


func directional_allowed_neighbor_tags(
	edge: TerrainChunkTopology.Edge,
) -> PackedStringArray:
	match edge:
		TerrainChunkTopology.Edge.NORTH:
			return north_allowed_neighbor_tags
		TerrainChunkTopology.Edge.EAST:
			return east_allowed_neighbor_tags
		TerrainChunkTopology.Edge.SOUTH:
			return south_allowed_neighbor_tags
		TerrainChunkTopology.Edge.WEST:
			return west_allowed_neighbor_tags
	return PackedStringArray()


func surface_tags_for_edge(
	edge: TerrainChunkTopology.Edge,
) -> PackedStringArray:
	var edge_tags := directional_surface_tags(edge)
	return tags if edge_tags.is_empty() else edge_tags


func directional_surface_tags(
	edge: TerrainChunkTopology.Edge,
) -> PackedStringArray:
	match edge:
		TerrainChunkTopology.Edge.NORTH:
			return north_surface_tags
		TerrainChunkTopology.Edge.EAST:
			return east_surface_tags
		TerrainChunkTopology.Edge.SOUTH:
			return south_surface_tags
		TerrainChunkTopology.Edge.WEST:
			return west_surface_tags
	return PackedStringArray()


func _allows_neighbor_with_tags(
	neighbor: TerrainChunkDefinition,
	allowed_tags: PackedStringArray,
) -> bool:
	if neighbor == null:
		return false
	for forbidden_tag: String in forbidden_neighbor_tags:
		if forbidden_tag in neighbor.tags:
			return false
	if allowed_tags.is_empty():
		return true
	return has_any_tag(neighbor.tags, allowed_tags)


func prefers_neighbor(neighbor: TerrainChunkDefinition) -> bool:
	return (
		neighbor != null
		and has_any_tag(neighbor.tags, preferred_neighbor_tags)
	)


static func has_any_tag(
	available_tags: PackedStringArray,
	requested_tags: PackedStringArray,
) -> bool:
	for requested_tag: String in requested_tags:
		if requested_tag in available_tags:
			return true
	return false
