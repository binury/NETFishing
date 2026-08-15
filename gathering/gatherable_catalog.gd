class_name GatherableCatalog
extends Resource

const GatherableDataType = preload("res://gathering/gatherable_data.gd")

@export var entries: Array[GatherableDataType] = []


func get_entry(type_id: StringName) -> GatherableDataType:
	if type_id.is_empty():
		return null
	for entry: GatherableDataType in entries:
		if entry != null and entry.type_id == type_id:
			return entry
	return null


func get_available_entries() -> Array[GatherableDataType]:
	var available: Array[GatherableDataType] = []
	for entry: GatherableDataType in entries:
		if entry != null and entry.is_available():
			available.append(entry)
	return available
