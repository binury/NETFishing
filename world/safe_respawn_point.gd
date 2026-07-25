class_name SafeRespawnPoint
extends Marker3D

@export var enabled: bool = true


func get_horizontal_distance_squared(world_position: Vector3) -> float:
	var offset: Vector3 = global_position - world_position
	return Vector2(offset.x, offset.z).length_squared()
