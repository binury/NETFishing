class_name PlayerBag
extends Node

const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const OwnedItemType = preload("res://items/owned_item.gd")

const DEFAULT_UNLOCKED_BAIT_IDS: Array[StringName] = [&"worms"]

signal contents_changed

var _catalog: ItemCatalogType
var _items: Array[OwnedItemType] = []
var _unlocked_bait_ids: Array[StringName] = (
	DEFAULT_UNLOCKED_BAIT_IDS.duplicate()
)


func setup(catalog: ItemCatalogType) -> void:
	_catalog = catalog


func add_item(item_id: StringName, quantity: int = 1) -> bool:
	if not can_add_item(item_id, quantity):
		return false
	var item: ItemDataType = _resolve_valid_item(item_id)
	var existing: OwnedItemType = get_owned_item(item_id)
	if existing != null:
		existing.quantity += quantity
	else:
		var owned := OwnedItemType.new()
		owned.item_id = item_id
		owned.quantity = quantity
		_items.append(owned)
	if item.is_bait() and not _unlocked_bait_ids.has(item_id):
		_unlocked_bait_ids.append(item_id)
	contents_changed.emit()
	return true


func can_add_item(item_id: StringName, quantity: int = 1) -> bool:
	var item: ItemDataType = _resolve_available_item(item_id)
	if item == null or quantity <= 0:
		return false
	var existing: OwnedItemType = get_owned_item(item_id)
	if existing != null:
		return (
			item.stackable
			and existing.quantity + quantity <= item.max_stack
		)
	return quantity <= (item.max_stack if item.stackable else 1)


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


func get_unlocked_bait_ids() -> Array[StringName]:
	return _unlocked_bait_ids.duplicate()


func is_bait_unlocked(item_id: StringName) -> bool:
	return _unlocked_bait_ids.has(item_id)


func get_unlocked_bait_items() -> Array[OwnedItemType]:
	var result: Array[OwnedItemType] = []
	for item_id: StringName in _unlocked_bait_ids:
		var owned: OwnedItemType = get_owned_item(item_id)
		if owned != null:
			result.append(owned.duplicate_record())
			continue
		var empty_record := OwnedItemType.new()
		empty_record.item_id = item_id
		empty_record.quantity = 0
		result.append(empty_record)
	return result


func replace_unlocked_bait_ids(item_ids: Array[StringName]) -> bool:
	var validated: Array[StringName] = DEFAULT_UNLOCKED_BAIT_IDS.duplicate()
	var seen: Dictionary[StringName, bool] = {}
	for item_id: StringName in item_ids:
		if item_id.is_empty() or seen.has(item_id):
			return false
		seen[item_id] = true
		if validated.has(item_id):
			continue
		var item: ItemDataType = _resolve_valid_item(item_id)
		if item == null or not item.is_bait():
			return false
		validated.append(item_id)
	_unlocked_bait_ids = validated
	contents_changed.emit()
	return true


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


func _resolve_available_item(item_id: StringName) -> ItemDataType:
	var item: ItemDataType = _resolve_valid_item(item_id)
	return item if item != null and item.active else null
