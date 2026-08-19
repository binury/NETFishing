class_name TerrainChunkDefinition
extends Resource

@export var stable_id: StringName
@export var label := ""
@export var packed_scene: PackedScene
@export var primary_mesh_name: StringName
@export_flags("0 degrees", "90 degrees", "180 degrees", "270 degrees")
var allowed_rotation_mask := 15
@export_range(0.01, 100.0, 0.01) var selection_weight := 1.0
## Negative values allow unlimited placements; zero disables random placement.
@export_range(-1, 1024, 1) var maximum_placements := -1
@export var tags := PackedStringArray()
@export_flags("North", "East", "South", "West") var water_inlet_edges := 0
@export_flags("North", "East", "South", "West") var water_outlet_edges := 0
## Optional generated water footprint in the chunk's unrotated local X/Z plane.
## Zero means this chunk contributes no standalone water surface.
@export var water_surface_size := Vector2.ZERO
@export var water_surface_offset := Vector2.ZERO


func allows_quarter_turn(quarter_turns: int) -> bool:
	var normalized_turns := posmod(quarter_turns, 4)
	return (allowed_rotation_mask & (1 << normalized_turns)) != 0
