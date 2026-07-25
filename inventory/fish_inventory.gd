class_name FishInventory
extends Node

const FishDataType = preload("res://fish/fish_data.gd")

signal contents_changed(fish_id: StringName, count: int)

var _fish_counts: Dictionary[StringName, int] = {}


func add_fish(fish: FishDataType, amount: int = 1) -> void:
	if fish == null or fish.id.is_empty() or amount <= 0:
		return

	var new_count: int = get_count(fish.id) + amount
	_fish_counts[fish.id] = new_count
	contents_changed.emit(fish.id, new_count)


func get_count(fish_id: StringName) -> int:
	return _fish_counts.get(fish_id, 0)
