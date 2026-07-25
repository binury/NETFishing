class_name CollectionLog
extends Node

signal fish_discovered(fish_id: StringName)

var _discovered: Dictionary[StringName, bool] = {}


func has_discovered(fish_id: StringName) -> bool:
	return not fish_id.is_empty() and _discovered.has(fish_id)


func mark_discovered(fish_id: StringName) -> void:
	if fish_id.is_empty() or has_discovered(fish_id):
		return
	_discovered[fish_id] = true
	fish_discovered.emit(fish_id)
