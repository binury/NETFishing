class_name PlayerBag
extends Node

const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const OwnedItemType = preload("res://items/owned_item.gd")

const DEFAULT_UNLOCKED_BAIT_IDS: Array[StringName] = [&"worms"]
const MIN_STORAGE_SLOT_COUNT: int = 15
const MAX_STORAGE_SLOT_INDEX: int = 254

enum StorageGroup {
	NONE,
	EQUIPMENT,
	ITEMS,
}

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
		owned.storage_slot = _first_available_storage_slot(item, _items)
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


func get_storage_slot(item_id: StringName) -> int:
	var owned: OwnedItemType = get_owned_item(item_id)
	return owned.storage_slot if owned != null else -1


func move_item_to_storage_slot(item_id: StringName, target_slot: int) -> bool:
	if target_slot < 0 or target_slot > MAX_STORAGE_SLOT_INDEX:
		return false
	var owned: OwnedItemType = get_owned_item(item_id)
	var item: ItemDataType = _resolve_valid_item(item_id)
	var group: StorageGroup = _storage_group_for_item(item)
	if owned == null or group == StorageGroup.NONE:
		return false
	if owned.storage_slot == target_slot:
		return true
	var displaced: OwnedItemType
	for candidate: OwnedItemType in _items:
		if candidate == null or candidate == owned:
			continue
		var candidate_item: ItemDataType = _resolve_valid_item(
			candidate.item_id
		)
		if (
			_storage_group_for_item(candidate_item) == group
			and candidate.storage_slot == target_slot
		):
			displaced = candidate
			break
	var previous_slot: int = owned.storage_slot
	owned.storage_slot = target_slot
	if displaced != null:
		displaced.storage_slot = previous_slot
	contents_changed.emit()
	return true


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
	_normalize_storage_slots(validated)
	_items = validated
	contents_changed.emit()
	return true


func _normalize_storage_slots(items: Array[OwnedItemType]) -> void:
	var occupied: Dictionary[String, bool] = {}
	for owned: OwnedItemType in items:
		var item: ItemDataType = _resolve_valid_item(owned.item_id)
		var group: StorageGroup = _storage_group_for_item(item)
		if group == StorageGroup.NONE:
			owned.storage_slot = -1
			continue
		var key := _storage_slot_key(group, owned.storage_slot)
		if (
			owned.storage_slot < 0
			or owned.storage_slot > MAX_STORAGE_SLOT_INDEX
			or occupied.has(key)
		):
			owned.storage_slot = -1
			continue
		occupied[key] = true
	for owned: OwnedItemType in items:
		if owned.storage_slot >= 0:
			continue
		var item: ItemDataType = _resolve_valid_item(owned.item_id)
		var group: StorageGroup = _storage_group_for_item(item)
		if group == StorageGroup.NONE:
			continue
		for slot_index: int in range(MAX_STORAGE_SLOT_INDEX + 1):
			var key := _storage_slot_key(group, slot_index)
			if occupied.has(key):
				continue
			owned.storage_slot = slot_index
			occupied[key] = true
			break


func _first_available_storage_slot(
	item: ItemDataType,
	items: Array[OwnedItemType],
) -> int:
	var group: StorageGroup = _storage_group_for_item(item)
	if group == StorageGroup.NONE:
		return -1
	var occupied: Dictionary[int, bool] = {}
	for owned: OwnedItemType in items:
		var owned_item: ItemDataType = _resolve_valid_item(owned.item_id)
		if (
			_storage_group_for_item(owned_item) == group
			and owned.storage_slot >= 0
		):
			occupied[owned.storage_slot] = true
	for slot_index: int in range(MAX_STORAGE_SLOT_INDEX + 1):
		if not occupied.has(slot_index):
			return slot_index
	return -1


func _storage_group_for_item(item: ItemDataType) -> StorageGroup:
	if item == null or item.is_bait() or item.is_lure():
		return StorageGroup.NONE
	return (
		StorageGroup.ITEMS
		if item.category == ItemDataType.Category.CONSUMABLE
		else StorageGroup.EQUIPMENT
	)


func _storage_slot_key(group: StorageGroup, slot_index: int) -> String:
	return "%d:%d" % [int(group), slot_index]


func _resolve_valid_item(item_id: StringName) -> ItemDataType:
	if _catalog == null:
		return null
	var item: ItemDataType = _catalog.get_item_by_id(item_id)
	return item if item != null and item.is_valid() else null


func _resolve_available_item(item_id: StringName) -> ItemDataType:
	var item: ItemDataType = _resolve_valid_item(item_id)
	return item if item != null and item.active else null
