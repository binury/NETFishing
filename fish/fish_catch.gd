class_name FishCatch
extends Resource

const FishDataType = preload("res://fish/fish_data.gd")

@export var fish: FishDataType
@export var fish_id: StringName
@export var catch_id: StringName
@export var catch_sequence: int = 0
@export var weight_lb: float = 0.0
@export var display_scale: float = 1.0


func ensure_identity() -> void:
	if not catch_id.is_empty():
		return
	catch_id = StringName(
		"%s:%d:%d"
		% [fish_id, Time.get_ticks_usec(), get_instance_id()]
	)


func is_valid() -> bool:
	return (
		fish != null
		and not fish_id.is_empty()
		and not catch_id.is_empty()
		and fish.id == fish_id
		and weight_lb >= fish.get_minimum_weight()
		and weight_lb <= fish.get_maximum_weight()
		and display_scale > 0.0
	)
