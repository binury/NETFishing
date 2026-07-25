class_name CollectionLog
extends Node

signal fish_discovered(fish_id: StringName)
signal collection_changed

var _discovered: Dictionary[StringName, bool] = {}


func has_discovered(fish_id: StringName) -> bool:
	return not fish_id.is_empty() and _discovered.has(fish_id)


func mark_discovered(fish_id: StringName) -> void:
	if fish_id.is_empty() or has_discovered(fish_id):
		return
	_discovered[fish_id] = true
	fish_discovered.emit(fish_id)
	collection_changed.emit()


func get_discovered_ids() -> Array[StringName]:
	var discovered_ids: Array[StringName] = []
	for fish_id: StringName in _discovered:
		discovered_ids.append(fish_id)
	discovered_ids.sort()
	return discovered_ids


func replace_discovered_ids(fish_ids: Array[StringName]) -> bool:
	var replacement: Dictionary[StringName, bool] = {}
	for fish_id: StringName in fish_ids:
		if fish_id.is_empty():
			return false
		replacement[fish_id] = true
	_discovered = replacement
	collection_changed.emit()
	return true
