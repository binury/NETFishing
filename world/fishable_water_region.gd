@tool
class_name FishableWaterRegion
extends Area3D

const FishPoolType = preload("res://fish/fish_pool.gd")

enum SurfaceHeightMode {
	EXPLICIT,
	PARENT_GLOBAL_Y,
}

@export var location_tags: Array[StringName] = []
@export var water_type: WaterType.Type = WaterType.Type.FRESH_WATER
@export var fish_pool: FishPoolType
@export var selection_priority: int = 0
@export_group("Surface")
@export var surface_height_mode: SurfaceHeightMode = SurfaceHeightMode.EXPLICIT:
	set(value):
		surface_height_mode = value
		if Engine.is_editor_hint():
			notify_property_list_changed()
## Legacy explicit height used when Surface Height Mode is Explicit.
@export var surface_height: float = 0.3


func get_surface_height() -> float:
	if surface_height_mode == SurfaceHeightMode.PARENT_GLOBAL_Y:
		var surface_owner := get_parent() as Node3D
		if surface_owner != null:
			return surface_owner.global_position.y
	return surface_height


func _validate_property(property: Dictionary) -> void:
	if (
		property.name == "surface_height"
		and surface_height_mode == SurfaceHeightMode.PARENT_GLOBAL_Y
	):
		property.usage = int(property.usage) & ~PROPERTY_USAGE_EDITOR
