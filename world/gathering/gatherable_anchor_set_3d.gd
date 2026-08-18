@tool
class_name GatherableAnchorSet3D
extends Node3D

@export var anchor_set_id: StringName


func get_spawn_positions() -> PackedVector3Array:
	var positions := PackedVector3Array()
	_collect_marker_positions(self, positions)
	return positions


func _collect_marker_positions(
	root_node: Node,
	positions: PackedVector3Array,
) -> void:
	for child: Node in root_node.get_children():
		if child is Marker3D:
			positions.append((child as Marker3D).global_position)
		_collect_marker_positions(child, positions)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if anchor_set_id.is_empty():
		warnings.append("Gatherable anchor-set ID is required.")
	if get_spawn_positions().is_empty():
		warnings.append("Add at least one Marker3D spawn anchor.")
	return warnings
