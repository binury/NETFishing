class_name FishInventory
extends Node

const FishCatchType = preload("res://fish/fish_catch.gd")

signal contents_changed(fish_id: StringName, count: int)

var _catches: Array[FishCatchType] = []


func add_catch(fish_catch: FishCatchType) -> void:
	if fish_catch == null or not fish_catch.is_valid():
		return
	_catches.append(fish_catch)
	contents_changed.emit(
		fish_catch.fish_id,
		get_count(fish_catch.fish_id)
	)


func get_count(fish_id: StringName) -> int:
	return get_catches_by_fish_id(fish_id).size()


func get_all_catches() -> Array[FishCatchType]:
	return _catches.duplicate()


func get_catches_by_fish_id(fish_id: StringName) -> Array[FishCatchType]:
	var matching: Array[FishCatchType] = []
	for fish_catch: FishCatchType in _catches:
		if fish_catch.fish_id == fish_id:
			matching.append(fish_catch)
	return matching
