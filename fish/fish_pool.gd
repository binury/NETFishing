class_name FishPool
extends Resource

const FishDataType = preload("res://fish/fish_data.gd")

@export var candidates: Array[FishDataType] = []


func get_fish_by_id(fish_id: StringName) -> FishDataType:
	if fish_id.is_empty():
		return null
	for fish: FishDataType in candidates:
		if fish != null and fish.id == fish_id:
			return fish
	return null
