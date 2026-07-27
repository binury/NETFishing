@tool
class_name WorldProp
extends Node3D

@export_group("Owned Nodes")
@export_node_path("Node3D")
var visual_root_path: NodePath = ^"Visual"
@export_node_path("Node3D")
var collision_root_path: NodePath
@export_node_path("Area3D")
var interaction_area_path: NodePath
@export_node_path("Marker3D")
var entrance_marker_path: NodePath

@export_group("Scaling")
## Enable only when this prop explicitly supports non-uniform root scaling.
@export var allow_non_uniform_scale: bool = false


func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	set_notify_transform(true)
	update_configuration_warnings()


func _notification(what: int) -> void:
	if Engine.is_editor_hint() and what == NOTIFICATION_TRANSFORM_CHANGED:
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if get_node_or_null(visual_root_path) == null:
		warnings.append("Assign a valid Visual root.")
	if (
		not collision_root_path.is_empty()
		and get_node_or_null(collision_root_path) == null
	):
		warnings.append("Assign a valid Collision root.")
	if (
		not interaction_area_path.is_empty()
		and get_node_or_null(interaction_area_path) == null
	):
		warnings.append("Assign a valid InteractionArea.")
	if (
		not entrance_marker_path.is_empty()
		and get_node_or_null(entrance_marker_path) == null
	):
		warnings.append("Assign a valid EntranceMarker.")
	if not allow_non_uniform_scale and not _has_uniform_scale():
		warnings.append(
			"Use uniform root scale so visuals and collision stay aligned."
		)
	return warnings


func _has_uniform_scale() -> bool:
	return (
		is_equal_approx(scale.x, scale.y)
		and is_equal_approx(scale.y, scale.z)
	)
