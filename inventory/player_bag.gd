class_name PlayerBag
extends Node

const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const OwnedItemType = preload("res://items/owned_item.gd")

signal contents_changed

var _catalog: ItemCatalogType
var _items: Array[OwnedItemType] = []


func setup(catalog: ItemCatalogType) -> void:
	_catalog = catalog


func add_item(item_id: StringName, quantity: int = 1) -> bool:
	var item: ItemDataType = _resolve_valid_item(item_id)
	if item == null or quantity <= 0:
		return false
	var existing: OwnedItemType = get_owned_item(item_id)
	if existing != null:
		if not item.stackable:
			return false
		if existing.quantity + quantity > item.max_stack:
			return false
		existing.quantity += quantity
	else:
		if quantity > (item.max_stack if item.stackable else 1):
			return false
		var owned := OwnedItemType.new()
		owned.item_id = item_id
		owned.quantity = quantity
		_items.append(owned)
	contents_changed.emit()
	return true


func remove_item(item_id: StringName, quantity: int = 1) -> bool:
	if quantity <= 0:
		return false
	for index: int in range(_items.size()):
		var owned: OwnedItemType = _items[index]
		if owned.item_id != item_id or owned.quantity < quantity:
			continue
		owned.quantity -= quantity
		if owned.quantity == 0:
			_items.remove_at(index)
		contents_changed.emit()
		return true
	return false


func get_quantity(item_id: StringName) -> int:
	var owned: OwnedItemType = get_owned_item(item_id)
	return owned.quantity if owned != null else 0


func owns_item(item_id: StringName) -> bool:
	return get_quantity(item_id) > 0


func get_owned_item(item_id: StringName) -> OwnedItemType:
	if item_id.is_empty():
		return null
	for owned: OwnedItemType in _items:
		if owned != null and owned.item_id == item_id:
			return owned
	return null


func get_all_items() -> Array[OwnedItemType]:
	var result: Array[OwnedItemType] = []
	for owned: OwnedItemType in _items:
		if owned != null:
			result.append(owned.duplicate_record())
	return result


func replace_all_items(items: Array[OwnedItemType]) -> bool:
	var validated: Array[OwnedItemType] = []
	var seen: Dictionary[StringName, bool] = {}
	for owned: OwnedItemType in items:
		if owned == null or not owned.is_valid() or seen.has(owned.item_id):
			return false
		var item: ItemDataType = _resolve_valid_item(owned.item_id)
		if item == null:
			return false
		var maximum: int = item.max_stack if item.stackable else 1
		if owned.quantity > maximum:
			return false
		seen[owned.item_id] = true
		validated.append(owned.duplicate_record())
	_items = validated
	contents_changed.emit()
	return true


func _resolve_valid_item(item_id: StringName) -> ItemDataType:
	if _catalog == null:
		return null
	var item: ItemDataType = _catalog.get_item_by_id(item_id)
	return item if item != null and item.is_valid() else null
