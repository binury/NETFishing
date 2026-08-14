class_name ItemCatalog
extends Resource

const ItemDataType = preload("res://items/item_data.gd")

@export var items: Array[ItemDataType] = []


func get_item_by_id(item_id: StringName) -> ItemDataType:
	if item_id.is_empty():
		return null
	for item: ItemDataType in items:
		if item != null and item.item_id == item_id:
			return item
	return null


func get_valid_items() -> Array[ItemDataType]:
	var result: Array[ItemDataType] = []
	var seen: Dictionary[StringName, bool] = {}
	for item: ItemDataType in items:
		if (
			item == null
			or not item.is_valid()
			or seen.has(item.item_id)
		):
			continue
		seen[item.item_id] = true
		result.append(item)
	return result


func get_available_item_by_id(item_id: StringName) -> ItemDataType:
	var item: ItemDataType = get_item_by_id(item_id)
	return item if item != null and item.is_available() else null


func get_available_items() -> Array[ItemDataType]:
	var result: Array[ItemDataType] = []
	for item: ItemDataType in get_valid_items():
		if item.active:
			result.append(item)
	return result
