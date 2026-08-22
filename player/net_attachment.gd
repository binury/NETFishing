extends "res://player/tool_socket_attachment.gd"

@onready var _impact_marker: Marker3D = %ImpactMarker


func get_impact_world_position() -> Vector3:
	return _impact_marker.global_position
