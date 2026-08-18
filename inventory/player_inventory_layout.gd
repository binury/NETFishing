class_name PlayerInventoryLayout
extends Node

const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const PlayerCoolerCapacityType = preload(
	"res://progression/player_cooler_capacity.gd"
)
const PlayerWalletType = preload("res://economy/player_wallet.gd")

const INVENTORY_COLUMNS: int = 9
const INVENTORY_CAPACITIES: Array[int] = [9, 18, 27, 36]
const BACKPACK_EXPANSION_COSTS: Array[int] = [1500, 4500, 9000]
const MAX_BACKPACK_LEVEL: int = 3
const MAX_INVENTORY_SLOT_COUNT: int = 36
const MAX_STORAGE_SLOT_COUNT: int = PlayerCoolerCapacityType.MAX_CAPACITY
const HOTBAR_SLOT_COUNT: int = 9

enum EntryKind {
	ITEM,
	CATCH,
}

enum InventoryContainer {
	INVENTORY,
	STORAGE,
	HOTBAR,
}

signal layout_changed
signal backpack_capacity_changed(level: int, capacity: int)

var _bag: PlayerBagType
var _fish_inventory: FishInventoryType
var _item_catalog: ItemCatalogType
var _storage_capacity: PlayerCoolerCapacityType
var _placements: Dictionary[String, Dictionary] = {}
var _reconciling: bool = false
var _backpack_level: int = 0


func setup(
	bag: PlayerBagType,
	fish_inventory: FishInventoryType,
	item_catalog: ItemCatalogType,
	storage_capacity: PlayerCoolerCapacityType,
) -> void:
	_bag = bag
	_fish_inventory = fish_inventory
	_item_catalog = item_catalog
	_storage_capacity = storage_capacity
	if _bag != null and not _bag.contents_changed.is_connected(_on_contents_changed):
		_bag.contents_changed.connect(_on_contents_changed)
	if (
		_fish_inventory != null
		and not _fish_inventory.catches_changed.is_connected(_on_contents_changed)
	):
		_fish_inventory.catches_changed.connect(_on_contents_changed)
	if (
		_storage_capacity != null
		and not _storage_capacity.capacity_changed.is_connected(
			_on_storage_capacity_changed
		)
	):
		_storage_capacity.capacity_changed.connect(_on_storage_capacity_changed)
	_reconcile(true)


func can_accept_item(item_id: StringName) -> bool:
	if not is_managed_item(item_id):
		return true
	var key := item_key(item_id)
	return _placements.has(key) or _first_free_slot(InventoryContainer.INVENTORY) >= 0


func can_accept_catch(catch_id: StringName = StringName()) -> bool:
	if not catch_id.is_empty() and _placements.has(catch_key(catch_id)):
		return true
	return _first_free_slot(InventoryContainer.INVENTORY) >= 0


func is_managed_item(item_id: StringName) -> bool:
	var item: ItemDataType = (
		_item_catalog.get_item_by_id(item_id)
		if _item_catalog != null else null
	)
	return item != null and not item.is_bait() and not item.is_lure()


func is_item_in_inventory(item_id: StringName) -> bool:
	return _is_entry_in_container(item_key(item_id), InventoryContainer.INVENTORY)


func is_catch_in_inventory(catch_id: StringName) -> bool:
	return _is_entry_in_container(catch_key(catch_id), InventoryContainer.INVENTORY)


func is_item_carried(item_id: StringName) -> bool:
	return _is_entry_carried(item_key(item_id))


func is_catch_carried(catch_id: StringName) -> bool:
	return _is_entry_carried(catch_key(catch_id))


func get_inventory_count() -> int:
	return get_entries(InventoryContainer.INVENTORY).size()


func get_inventory_capacity() -> int:
	return INVENTORY_CAPACITIES[_backpack_level]


func get_backpack_level() -> int:
	return _backpack_level


func get_next_inventory_capacity() -> int:
	if _backpack_level >= MAX_BACKPACK_LEVEL:
		return -1
	return INVENTORY_CAPACITIES[_backpack_level + 1]


func get_next_backpack_cost() -> int:
	if _backpack_level >= MAX_BACKPACK_LEVEL:
		return -1
	return BACKPACK_EXPANSION_COSTS[_backpack_level]


func can_purchase_backpack(wallet: PlayerWalletType) -> bool:
	var cost := get_next_backpack_cost()
	return wallet != null and cost >= 0 and wallet.can_afford(cost)


func purchase_backpack(wallet: PlayerWalletType) -> bool:
	if not can_purchase_backpack(wallet):
		return false
	var cost := get_next_backpack_cost()
	if not wallet.debit(cost):
		return false
	_backpack_level += 1
	backpack_capacity_changed.emit(_backpack_level, get_inventory_capacity())
	layout_changed.emit()
	return true


func restore_backpack_level(level: int) -> bool:
	var validated := clampi(level, 0, MAX_BACKPACK_LEVEL)
	var changed := _backpack_level != validated
	_backpack_level = validated
	if changed:
		backpack_capacity_changed.emit(_backpack_level, get_inventory_capacity())
	_reconcile(changed)
	return true


func get_storage_count() -> int:
	return get_entries(InventoryContainer.STORAGE).size()


func get_hotbar_count() -> int:
	return get_entries(InventoryContainer.HOTBAR).size()


func get_storage_capacity() -> int:
	return _storage_capacity.get_capacity() if _storage_capacity != null else 0


func get_entries(container: InventoryContainer) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for key: String in _placements:
		var placement: Dictionary = _placements[key]
		if int(placement.get("container", -1)) != int(container):
			continue
		var entry: Dictionary = placement.duplicate(true)
		entry["key"] = key
		entries.append(entry)
	entries.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			return int(left.get("slot", -1)) < int(right.get("slot", -1))
	)
	return entries


func get_entry(kind: EntryKind, identity: StringName) -> Dictionary:
	var key := _entry_key(kind, identity)
	return _placements.get(key, {}).duplicate(true)


func get_container(kind: EntryKind, identity: StringName) -> int:
	return int(
		get_entry(kind, identity).get("container", -1)
	)


func get_key_at(container: InventoryContainer, slot: int) -> String:
	return _key_at(container, slot)


func get_entry_at(container: InventoryContainer, slot: int) -> Dictionary:
	var key := _key_at(container, slot)
	if key.is_empty():
		return {}
	var entry: Dictionary = _placements[key].duplicate(true)
	entry["key"] = key
	return entry


func move_entry(
	kind: EntryKind,
	identity: StringName,
	target_container: InventoryContainer,
	target_slot: int,
) -> bool:
	var key := _entry_key(kind, identity)
	if not _placements.has(key) or not _is_slot_valid(target_container, target_slot):
		return false
	var source: Dictionary = _placements[key]
	if (
		int(source.get("container", -1)) == int(target_container)
		and int(source.get("slot", -1)) == target_slot
	):
		return true
	var displaced_key := _key_at(target_container, target_slot)
	var source_container: int = int(source.get("container", InventoryContainer.INVENTORY))
	var source_slot: int = int(source.get("slot", -1))
	source["container"] = int(target_container)
	source["slot"] = target_slot
	_placements[key] = source
	if not displaced_key.is_empty():
		var displaced: Dictionary = _placements[displaced_key]
		displaced["container"] = source_container
		displaced["slot"] = source_slot
		_placements[displaced_key] = displaced
	layout_changed.emit()
	return true


func move_entry_to_first_free(
	kind: EntryKind,
	identity: StringName,
	target_container: InventoryContainer,
) -> bool:
	var slot := _first_free_slot(target_container)
	return slot >= 0 and move_entry(kind, identity, target_container, slot)


func return_hotbar_entry_to_inventory(slot: int) -> bool:
	var key := _key_at(InventoryContainer.HOTBAR, slot)
	if key.is_empty():
		return true
	var placement: Dictionary = _placements[key]
	return move_entry_to_first_free(
		int(placement.get("kind", -1)) as EntryKind,
		StringName(str(placement.get("identity", ""))),
		InventoryContainer.INVENTORY,
	)


func return_all_hotbar_entries_to_inventory() -> bool:
	var entries := get_entries(InventoryContainer.HOTBAR)
	if get_inventory_count() + entries.size() > get_inventory_capacity():
		return false
	for entry: Dictionary in entries:
		if not move_entry_to_first_free(
			int(entry.get("kind", -1)) as EntryKind,
			StringName(str(entry.get("identity", ""))),
			InventoryContainer.INVENTORY,
		):
			return false
	return true


func to_save_data() -> Dictionary:
	var serialized: Array[Dictionary] = []
	var keys: Array[String] = []
	keys.assign(_placements.keys())
	keys.sort()
	for key: String in keys:
		var placement: Dictionary = _placements[key]
		serialized.append({
			"kind": int(placement.get("kind", EntryKind.ITEM)),
			"identity": str(placement.get("identity", "")),
			"container": int(placement.get("container", InventoryContainer.INVENTORY)),
			"slot": int(placement.get("slot", -1)),
		})
	return {
		"backpack_level": _backpack_level,
		"placements": serialized,
	}


func restore_from_save_data(data: Dictionary) -> bool:
	var level_value: Variant = data.get("backpack_level", 0)
	if (
		typeof(level_value) not in [TYPE_INT, TYPE_FLOAT]
		or not is_equal_approx(float(level_value), floorf(float(level_value)))
	):
		return false
	_backpack_level = clampi(int(level_value), 0, MAX_BACKPACK_LEVEL)
	var restored: Dictionary[String, Dictionary] = {}
	var values: Variant = data.get("placements", [])
	if typeof(values) != TYPE_ARRAY:
		return false
	for value: Variant in values as Array:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var record := value as Dictionary
		var kind: int = int(record.get("kind", -1))
		var identity := StringName(str(record.get("identity", "")))
		var container: int = int(record.get("container", -1))
		var slot: int = int(record.get("slot", -1))
		if (
			kind not in [EntryKind.ITEM, EntryKind.CATCH]
			or identity.is_empty()
			or container not in [
				InventoryContainer.INVENTORY,
				InventoryContainer.STORAGE,
				InventoryContainer.HOTBAR,
			]
			or not _is_slot_valid(container as InventoryContainer, slot)
		):
			continue
		var key := _entry_key(kind as EntryKind, identity)
		if restored.has(key) or _placement_slot_occupied(restored, container, slot):
			continue
		restored[key] = {
			"kind": kind,
			"identity": identity,
			"container": container,
			"slot": slot,
		}
	_placements = restored
	_reconcile(true)
	return true


func reset_to_defaults() -> void:
	var capacity_changed := _backpack_level != 0
	_backpack_level = 0
	_placements.clear()
	_reconcile(true)
	if capacity_changed:
		backpack_capacity_changed.emit(_backpack_level, get_inventory_capacity())


static func item_key(item_id: StringName) -> String:
	return "item:%s" % String(item_id)


static func catch_key(catch_id: StringName) -> String:
	return "catch:%s" % String(catch_id)


func _entry_key(kind: EntryKind, identity: StringName) -> String:
	return item_key(identity) if kind == EntryKind.ITEM else catch_key(identity)


func _is_entry_in_container(key: String, container: InventoryContainer) -> bool:
	var placement: Dictionary = _placements.get(key, {})
	return int(placement.get("container", -1)) == int(container)


func _is_entry_carried(key: String) -> bool:
	var placement: Dictionary = _placements.get(key, {})
	var container: int = int(placement.get("container", -1))
	return container in [InventoryContainer.INVENTORY, InventoryContainer.HOTBAR]


func _on_contents_changed() -> void:
	_reconcile(false)


func _on_storage_capacity_changed(_level: int, _capacity: int) -> void:
	_reconcile(true)


func _reconcile(force_signal: bool) -> void:
	if _reconciling or _bag == null or _fish_inventory == null:
		return
	_reconciling = true
	var expected: Dictionary[String, Dictionary] = {}
	for owned in _bag.get_all_items():
		if owned == null or not is_managed_item(owned.item_id):
			continue
		var key := item_key(owned.item_id)
		expected[key] = {"kind": EntryKind.ITEM, "identity": owned.item_id}
	for fish_catch in _fish_inventory.get_all_catches():
		if fish_catch == null or not fish_catch.is_valid():
			continue
		var key := catch_key(fish_catch.catch_id)
		expected[key] = {"kind": EntryKind.CATCH, "identity": fish_catch.catch_id}
	var changed: bool = false
	for key: String in _placements.keys():
		if expected.has(key):
			continue
		_placements.erase(key)
		changed = true
	_normalize_existing_placements()
	for key: String in expected:
		if _placements.has(key):
			continue
		var target_container := InventoryContainer.INVENTORY
		var target_slot := _first_free_slot(target_container)
		if target_slot < 0:
			target_container = InventoryContainer.STORAGE
			target_slot = _first_free_slot(target_container)
		if target_slot < 0:
			push_error("Inventory and storage cannot fit owned entry '%s'." % key)
			continue
		var placement: Dictionary = expected[key].duplicate(true)
		placement["container"] = int(target_container)
		placement["slot"] = target_slot
		_placements[key] = placement
		changed = true
	_reconciling = false
	if changed or force_signal:
		layout_changed.emit()


func _normalize_existing_placements() -> void:
	var occupied_inventory: Dictionary[int, bool] = {}
	var occupied_storage: Dictionary[int, bool] = {}
	var occupied_hotbar: Dictionary[int, bool] = {}
	var invalid_keys: Array[String] = []
	var keys: Array[String] = []
	keys.assign(_placements.keys())
	keys.sort()
	for key: String in keys:
		var placement: Dictionary = _placements[key]
		var container: int = int(placement.get("container", -1))
		var slot: int = int(placement.get("slot", -1))
		var occupied: Dictionary[int, bool]
		match container:
			InventoryContainer.INVENTORY:
				occupied = occupied_inventory
			InventoryContainer.STORAGE:
				occupied = occupied_storage
			InventoryContainer.HOTBAR:
				occupied = occupied_hotbar
			_:
				occupied = {}
		if (
			container not in [
				InventoryContainer.INVENTORY,
				InventoryContainer.STORAGE,
				InventoryContainer.HOTBAR,
			]
			or not _is_slot_valid(container as InventoryContainer, slot)
			or occupied.has(slot)
		):
			invalid_keys.append(key)
			continue
		occupied[slot] = true
	for key: String in invalid_keys:
		# Invalid records must stop occupying their old slot before free-space
		# lookup. Otherwise a duplicate can incorrectly reserve a valid slot.
		var placement: Dictionary = _placements[key]
		_placements.erase(key)
		var target := InventoryContainer.INVENTORY
		var slot := _first_free_slot(target)
		if slot < 0:
			target = InventoryContainer.STORAGE
			slot = _first_free_slot(target)
		if slot < 0:
			_placements.erase(key)
			continue
		placement["container"] = int(target)
		placement["slot"] = slot
		_placements[key] = placement


func _first_free_slot(container: InventoryContainer) -> int:
	var capacity := (
		get_inventory_capacity() if container == InventoryContainer.INVENTORY
		else HOTBAR_SLOT_COUNT if container == InventoryContainer.HOTBAR
		else get_storage_capacity()
	)
	for slot: int in capacity:
		if _key_at(container, slot).is_empty():
			return slot
	return -1


func _key_at(container: InventoryContainer, slot: int) -> String:
	for key: String in _placements:
		var placement: Dictionary = _placements[key]
		if (
			int(placement.get("container", -1)) == int(container)
			and int(placement.get("slot", -1)) == slot
		):
			return key
	return ""


func _is_slot_valid(container: InventoryContainer, slot: int) -> bool:
	if slot < 0:
		return false
	return slot < (
		get_inventory_capacity() if container == InventoryContainer.INVENTORY
		else HOTBAR_SLOT_COUNT if container == InventoryContainer.HOTBAR
		else get_storage_capacity()
	)


func _placement_slot_occupied(
	placements: Dictionary[String, Dictionary],
	container: int,
	slot: int,
) -> bool:
	for placement: Dictionary in placements.values():
		if (
			int(placement.get("container", -1)) == container
			and int(placement.get("slot", -1)) == slot
		):
			return true
	return false
