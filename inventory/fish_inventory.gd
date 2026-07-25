class_name FishInventory
extends Node

const FishCatchType = preload("res://fish/fish_catch.gd")

signal contents_changed(fish_id: StringName, count: int)
signal catches_changed

var _catches: Array[FishCatchType] = []
var _next_catch_sequence: int = 1


func add_catch(fish_catch: FishCatchType) -> void:
	if fish_catch == null or not fish_catch.is_valid():
		return
	if get_catch_by_id(fish_catch.catch_id) != null:
		return
	if fish_catch.catch_sequence <= 0:
		fish_catch.catch_sequence = _next_catch_sequence
	_next_catch_sequence = maxi(
		_next_catch_sequence,
		fish_catch.catch_sequence + 1
	)
	_catches.append(fish_catch)
	contents_changed.emit(
		fish_catch.fish_id,
		get_count(fish_catch.fish_id)
	)
	catches_changed.emit()


func get_count(fish_id: StringName) -> int:
	return get_catches_by_fish_id(fish_id).size()


func get_all_catches() -> Array[FishCatchType]:
	return _catches.duplicate()


func get_catch_by_id(catch_id: StringName) -> FishCatchType:
	if catch_id.is_empty():
		return null
	for fish_catch: FishCatchType in _catches:
		if fish_catch != null and fish_catch.catch_id == catch_id:
			return fish_catch
	return null


func get_catch(catch_id: StringName) -> FishCatchType:
	return get_catch_by_id(catch_id)


func contains_catch_id(catch_id: StringName) -> bool:
	return get_catch_by_id(catch_id) != null


func remove_catch_by_id(catch_id: StringName) -> FishCatchType:
	if catch_id.is_empty():
		return null
	for index: int in range(_catches.size()):
		var fish_catch: FishCatchType = _catches[index]
		if fish_catch == null or fish_catch.catch_id != catch_id:
			continue
		_catches.remove_at(index)
		contents_changed.emit(
			fish_catch.fish_id,
			get_count(fish_catch.fish_id)
		)
		catches_changed.emit()
		return fish_catch
	return null


func set_catch_favorited(
	catch_id: StringName,
	is_favorited: bool,
) -> bool:
	var fish_catch: FishCatchType = get_catch_by_id(catch_id)
	if fish_catch == null:
		return false
	if fish_catch.is_favorited == is_favorited:
		return true
	fish_catch.is_favorited = is_favorited
	catches_changed.emit()
	return true


func get_total_sale_value() -> int:
	var total: int = 0
	for fish_catch: FishCatchType in _catches:
		if fish_catch == null or fish_catch.sale_value < 0:
			continue
		total += fish_catch.sale_value
	return total


func get_catches_by_fish_id(fish_id: StringName) -> Array[FishCatchType]:
	var matching: Array[FishCatchType] = []
	for fish_catch: FishCatchType in _catches:
		if fish_catch.fish_id == fish_id:
			matching.append(fish_catch)
	return matching
