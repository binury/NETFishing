@tool
class_name BelowWorldFailsafe
extends PlayerWaterTrigger

@export_group("Failsafe Authoring")
## Saved coverage volume that catches players below the playable world.
@export_node_path("CollisionShape3D")
var coverage_shape_path: NodePath = ^"Coverage"


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var coverage := get_node_or_null(coverage_shape_path) as CollisionShape3D
	if coverage == null:
		warnings.append("Add the saved Coverage collision shape.")
	elif coverage.shape == null:
		warnings.append("Assign a shape to the failsafe Coverage node.")
	return warnings
