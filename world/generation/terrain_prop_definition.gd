class_name TerrainPropDefinition
extends Resource

@export var stable_id: StringName
@export var label := ""
@export var packed_scene: PackedScene
## Empty means the prop is available for deliberate placement only.
@export var procedural_group: StringName
@export var required_chunk_tags := PackedStringArray()
@export_range(0.01, 100.0, 0.01) var selection_weight := 1.0
## Manhattan distance in chunks from the forced center spawn. Two keeps the
## spawn chunk and its four immediate neighbors clear of this prop.
@export_range(0, 16, 1) var minimum_spawn_chunk_distance := 0
## These groups influence placement selection but are not a hard requirement.
## A nearby match multiplies this prop's weight; an absent match divides it by
## the same amount.
@export var preferred_nearby_prop_groups := PackedStringArray()
@export_range(0.0, 100.0, 0.5) var preferred_nearby_radius := 0.0
@export_range(1.0, 10.0, 0.1) var nearby_preference_weight_multiplier := 1.0
@export_range(0.0, 10.0, 0.05) var clearance_radius := 0.5
## Procedural instances use a deterministic uniform scale in this range.
@export_range(0.1, 4.0, 0.05) var minimum_visual_scale := 1.0
@export_range(0.1, 4.0, 0.05) var maximum_visual_scale := 1.0
## Presentation-only offset. The prop root remains exactly terrain-aligned.
@export var visual_offset := Vector3.ZERO
## A single material is chosen per prop and applied only to matching imported
## material slots. This keeps trunks untouched while varying foliage.
@export var variant_material_slot_names := PackedStringArray()
@export var material_variants: Array[Material] = []
@export_range(0.0, 5.0, 0.05) var collision_radius := 0.0
@export_range(0.0, 20.0, 0.05) var collision_height := 0.0
@export var collision_box_size := Vector3.ZERO
@export var collision_offset := Vector3.ZERO
## Values above zero add this prop to the tree-gathering anchor set.
@export_range(0.0, 20.0, 0.05) var gatherable_anchor_height := 0.0


func supports_chunk_tags(chunk_tags: PackedStringArray) -> bool:
	for required_tag: String in required_chunk_tags:
		if required_tag not in chunk_tags:
			return false
	return true


func has_collision() -> bool:
	return has_cylinder_collision() or has_box_collision()


func has_cylinder_collision() -> bool:
	return collision_radius > 0.0 and collision_height > 0.0


func has_box_collision() -> bool:
	return (
		collision_box_size.x > 0.0
		and collision_box_size.y > 0.0
		and collision_box_size.z > 0.0
	)


func is_procedural() -> bool:
	return procedural_group != &""
