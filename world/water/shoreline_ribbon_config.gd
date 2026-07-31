class_name ShorelineRibbonConfig
extends Resource

@export_node_path("CollisionShape3D", "MeshInstance3D") var terrain_source: NodePath
@export var water_type: WaterType.Type = WaterType.Type.FRESH_WATER
@export var water_height := 0.0
@export var generation_bounds := Rect2()
@export var water_reference := Vector2.ZERO
@export var water_is_inside := true
@export_file("*.tres") var output_resource_path := ""
@export_group("Optional Smoothing Overrides")
@export var simplification_tolerance := -1.0
@export_range(-1, 4, 1) var smoothing_iterations := -1
@export var resample_spacing := -1.0
