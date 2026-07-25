class_name FishCatch
extends Resource

const FishDataType = preload("res://fish/fish_data.gd")

@export var fish: FishDataType
@export var fish_id: StringName
@export var weight_lb: float = 0.0
@export var display_scale: float = 1.0


func is_valid() -> bool:
	return (
		fish != null
		and not fish_id.is_empty()
		and fish.id == fish_id
		and weight_lb >= fish.get_minimum_weight()
		and weight_lb <= fish.get_maximum_weight()
		and display_scale > 0.0
	)
