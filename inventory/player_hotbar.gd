class_name PlayerHotbar
extends Node

const SLOT_COUNT: int = 9
const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")

enum AssignmentKind {
	EMPTY,
	ITEM,
	FISH,
}

signal slots_changed
signal selected_slot_changed(slot_index: int, item_id: StringName)
signal selected_assignment_changed(
	slot_index: int,
	kind: AssignmentKind,
	identity: StringName,
)

var _bag: PlayerBagType
var _catalog: ItemCatalogType
var _fish_inventory: FishInventoryType
var _inventory_layout: PlayerInventoryLayout
var _slots: Array[StringName] = []
var _fish_slots: Array[StringName] = []
var _selected_slot: int = 0


func _init() -> void:
	_slots.resize(SLOT_COUNT)
	_slots.fill(StringName())
	_fish_slots.resize(SLOT_COUNT)
	_fish_slots.fill(StringName())


func setup(
	bag: PlayerBagType,
	catalog: ItemCatalogType,
	fish_inventory: FishInventoryType = null,
	inventory_layout: PlayerInventoryLayout = null,
) -> void:
	_bag = bag
	_catalog = catalog
	_fish_inventory = fish_inventory
	_inventory_layout = inventory_layout
	if _bag != null and not _bag.contents_changed.is_connected(
		_on_bag_contents_changed
	):
		_bag.contents_changed.connect(_on_bag_contents_changed)
	if (
		_fish_inventory != null
		and not _fish_inventory.catches_changed.is_connected(
			_on_fish_inventory_changed
		)
	):
		_fish_inventory.catches_changed.connect(_on_fish_inventory_changed)
	if (
		_inventory_layout != null
		and not _inventory_layout.layout_changed.is_connected(_validate_assignments)
	):
		_inventory_layout.layout_changed.connect(_validate_assignments)
	_validate_assignments()


func assign_item(slot_index: int, item_id: StringName) -> bool:
	if not _is_slot_valid(slot_index) or not _can_assign(item_id):
		return false
	if _slots[slot_index] == item_id:
		return true
	var source_index: int = _slots.find(item_id)
	var displaced_item: StringName = _slots[slot_index]
	var displaced_fish: StringName = _fish_slots[slot_index]
	if (
		_inventory_layout != null
		and not _inventory_layout.move_entry(
			PlayerInventoryLayout.EntryKind.ITEM,
			item_id,
			PlayerInventoryLayout.InventoryContainer.HOTBAR,
			slot_index,
		)
	):
		return false
	var selected_slot_was_affected: bool = slot_index == _selected_slot
	if source_index >= 0 and source_index != slot_index:
		_slots[source_index] = displaced_item
		_fish_slots[source_index] = displaced_fish
		selected_slot_was_affected = (
			selected_slot_was_affected or source_index == _selected_slot
		)
	_slots[slot_index] = item_id
	_fish_slots[slot_index] = StringName()
	slots_changed.emit()
	if selected_slot_was_affected:
		_emit_selected_assignment()
	return true


func assign_fish(slot_index: int, catch_id: StringName) -> bool:
	if not _is_slot_valid(slot_index) or not _can_assign_fish(catch_id):
		return false
	if _fish_slots[slot_index] == catch_id:
		return true
	var source_index: int = _fish_slots.find(catch_id)
	var displaced_item: StringName = _slots[slot_index]
	var displaced_fish: StringName = _fish_slots[slot_index]
	if (
		_inventory_layout != null
		and not _inventory_layout.move_entry(
			PlayerInventoryLayout.EntryKind.CATCH,
			catch_id,
			PlayerInventoryLayout.InventoryContainer.HOTBAR,
			slot_index,
		)
	):
		return false
	var selected_slot_was_affected: bool = slot_index == _selected_slot
	if source_index >= 0 and source_index != slot_index:
		_slots[source_index] = displaced_item
		_fish_slots[source_index] = displaced_fish
		selected_slot_was_affected = (
			selected_slot_was_affected or source_index == _selected_slot
		)
	_slots[slot_index] = StringName()
	_fish_slots[slot_index] = catch_id
	slots_changed.emit()
	if selected_slot_was_affected:
		_emit_selected_assignment()
	return true


func clear_slot(slot_index: int) -> bool:
	if (
		not _is_slot_valid(slot_index)
		or (
			_slots[slot_index].is_empty()
			and _fish_slots[slot_index].is_empty()
		)
	):
		return false
	if (
		_inventory_layout != null
		and not _inventory_layout.return_hotbar_entry_to_inventory(slot_index)
	):
		return false
	_slots[slot_index] = StringName()
	_fish_slots[slot_index] = StringName()
	slots_changed.emit()
	if slot_index == _selected_slot:
		_emit_selected_assignment()
	return true


func swap_slots(from_index: int, to_index: int) -> bool:
	if (
		not _is_slot_valid(from_index)
		or not _is_slot_valid(to_index)
		or from_index == to_index
	):
		return false
	if _inventory_layout != null:
		var kind: PlayerInventoryLayout.EntryKind
		var identity: StringName
		if not _fish_slots[from_index].is_empty():
			kind = PlayerInventoryLayout.EntryKind.CATCH
			identity = _fish_slots[from_index]
		elif not _slots[from_index].is_empty():
			kind = PlayerInventoryLayout.EntryKind.ITEM
			identity = _slots[from_index]
		else:
			kind = (
				PlayerInventoryLayout.EntryKind.CATCH
				if not _fish_slots[to_index].is_empty()
				else PlayerInventoryLayout.EntryKind.ITEM
			)
			identity = (
				_fish_slots[to_index]
				if not _fish_slots[to_index].is_empty()
				else _slots[to_index]
			)
			var temporary_index: int = from_index
			from_index = to_index
			to_index = temporary_index
		if (
			identity.is_empty()
			or not _inventory_layout.move_entry(
				kind,
				identity,
				PlayerInventoryLayout.InventoryContainer.HOTBAR,
				to_index,
			)
		):
			return false
	var temporary: StringName = _slots[from_index]
	_slots[from_index] = _slots[to_index]
	_slots[to_index] = temporary
	temporary = _fish_slots[from_index]
	_fish_slots[from_index] = _fish_slots[to_index]
	_fish_slots[to_index] = temporary
	slots_changed.emit()
	if from_index == _selected_slot or to_index == _selected_slot:
		_emit_selected_assignment()
	return true


func move_slot_to_container(
	slot_index: int,
	target_container: int,
	target_slot: int,
) -> bool:
	if not _is_slot_valid(slot_index) or _inventory_layout == null:
		return false
	var kind: PlayerInventoryLayout.EntryKind
	var identity: StringName
	if not _fish_slots[slot_index].is_empty():
		kind = PlayerInventoryLayout.EntryKind.CATCH
		identity = _fish_slots[slot_index]
	elif not _slots[slot_index].is_empty():
		kind = PlayerInventoryLayout.EntryKind.ITEM
		identity = _slots[slot_index]
	else:
		return false
	if not _inventory_layout.move_entry(
		kind,
		identity,
		target_container,
		target_slot,
	):
		return false
	_slots[slot_index] = StringName()
	_fish_slots[slot_index] = StringName()
	var replacement := _inventory_layout.get_entry_at(
		PlayerInventoryLayout.InventoryContainer.HOTBAR,
		slot_index,
	)
	if not replacement.is_empty():
		var replacement_identity := StringName(
			str(replacement.get("identity", ""))
		)
		if int(replacement.get("kind", -1)) == PlayerInventoryLayout.EntryKind.CATCH:
			_fish_slots[slot_index] = replacement_identity
		else:
			_slots[slot_index] = replacement_identity
	slots_changed.emit()
	if slot_index == _selected_slot:
		_emit_selected_assignment()
	return true


func select_slot(slot_index: int) -> bool:
	if not _is_slot_valid(slot_index):
		return false
	if _selected_slot == slot_index:
		return true
	_selected_slot = slot_index
	_emit_selected_assignment()
	return true


func cycle_selection(direction: int) -> bool:
	if direction == 0:
		return false
	return select_slot(
		posmod(_selected_slot + signi(direction), SLOT_COUNT)
	)


func get_selected_slot() -> int:
	return _selected_slot


func get_selected_item_id() -> StringName:
	return _slots[_selected_slot]


func get_selected_fish_catch_id() -> StringName:
	return _fish_slots[_selected_slot]


func get_selected_assignment_kind() -> AssignmentKind:
	return get_assignment_kind(_selected_slot)


func get_item_id(slot_index: int) -> StringName:
	return _slots[slot_index] if _is_slot_valid(slot_index) else StringName()


func get_fish_catch_id(slot_index: int) -> StringName:
	return (
		_fish_slots[slot_index]
		if _is_slot_valid(slot_index)
		else StringName()
	)


func get_assignment_kind(slot_index: int) -> AssignmentKind:
	if not _is_slot_valid(slot_index):
		return AssignmentKind.EMPTY
	if not _fish_slots[slot_index].is_empty():
		return AssignmentKind.FISH
	if not _slots[slot_index].is_empty():
		return AssignmentKind.ITEM
	return AssignmentKind.EMPTY


func get_slots() -> Array[StringName]:
	return _slots.duplicate()


func get_fish_slots() -> Array[StringName]:
	return _fish_slots.duplicate()


func replace_state(
	slots: Array[StringName],
	selected_slot: int,
	fish_slots: Array[StringName] = [],
	synchronize_layout: bool = true,
) -> bool:
	if (
		synchronize_layout and _inventory_layout != null
		and not _inventory_layout.return_all_hotbar_entries_to_inventory()
	):
		return false
	var normalized: Array[StringName] = []
	normalized.resize(SLOT_COUNT)
	normalized.fill(StringName())
	var normalized_fish: Array[StringName] = []
	normalized_fish.resize(SLOT_COUNT)
	normalized_fish.fill(StringName())
	var seen_assignments: Dictionary[StringName, bool] = {}
	for index: int in range(mini(slots.size(), SLOT_COUNT)):
		var item_id: StringName = slots[index]
		if item_id.is_empty():
			continue
		if _can_assign(item_id) and not seen_assignments.has(item_id):
			normalized[index] = item_id
			seen_assignments[item_id] = true
	var seen_fish: Dictionary[StringName, bool] = {}
	for index: int in range(mini(fish_slots.size(), SLOT_COUNT)):
		if not normalized[index].is_empty():
			continue
		var catch_id: StringName = fish_slots[index]
		if _can_assign_fish(catch_id) and not seen_fish.has(catch_id):
			normalized_fish[index] = catch_id
			seen_fish[catch_id] = true
	_slots = normalized
	_fish_slots = normalized_fish
	if _inventory_layout != null and synchronize_layout:
		for index: int in SLOT_COUNT:
			if not _slots[index].is_empty():
				_inventory_layout.move_entry(
					PlayerInventoryLayout.EntryKind.ITEM,
					_slots[index],
					PlayerInventoryLayout.InventoryContainer.HOTBAR,
					index,
				)
			elif not _fish_slots[index].is_empty():
				_inventory_layout.move_entry(
					PlayerInventoryLayout.EntryKind.CATCH,
					_fish_slots[index],
					PlayerInventoryLayout.InventoryContainer.HOTBAR,
					index,
				)
	_selected_slot = clampi(selected_slot, 0, SLOT_COUNT - 1)
	slots_changed.emit()
	_emit_selected_assignment()
	return true


func has_any_assignment() -> bool:
	for index: int in range(SLOT_COUNT):
		if (
			not _slots[index].is_empty()
			or not _fish_slots[index].is_empty()
		):
			return true
	return false


func _can_assign(item_id: StringName) -> bool:
	if item_id.is_empty() or _bag == null or not _bag.owns_item(item_id):
		return false
	if _catalog == null:
		return false
	var item: ItemDataType = _catalog.get_item_by_id(item_id)
	return (
		item != null
		and item.is_available()
		and item.hotbar_allowed
		and (
			_inventory_layout == null
			or _inventory_layout.get_container(
				PlayerInventoryLayout.EntryKind.ITEM, item_id
			) >= 0
		)
	)


func _can_assign_fish(catch_id: StringName) -> bool:
	return (
		not catch_id.is_empty()
		and _fish_inventory != null
		and _fish_inventory.contains_catch_id(catch_id)
		and (
			_inventory_layout == null
			or _inventory_layout.get_container(
				PlayerInventoryLayout.EntryKind.CATCH, catch_id
			) >= 0
		)
	)


func _validate_assignments() -> void:
	var changed: bool = false
	for index: int in range(SLOT_COUNT):
		if not _slots[index].is_empty() and not _can_assign(_slots[index]):
			_slots[index] = StringName()
			changed = true
		if (
			not _fish_slots[index].is_empty()
			and not _can_assign_fish(_fish_slots[index])
		):
			_fish_slots[index] = StringName()
			changed = true
	if changed:
		slots_changed.emit()
		_emit_selected_assignment()


func _on_bag_contents_changed() -> void:
	_validate_assignments()


func _on_fish_inventory_changed() -> void:
	_validate_assignments()


func _emit_selected_assignment() -> void:
	var kind: AssignmentKind = get_selected_assignment_kind()
	var identity: StringName = StringName()
	if kind == AssignmentKind.ITEM:
		identity = _slots[_selected_slot]
	elif kind == AssignmentKind.FISH:
		identity = _fish_slots[_selected_slot]
	selected_slot_changed.emit(_selected_slot, _slots[_selected_slot])
	selected_assignment_changed.emit(_selected_slot, kind, identity)


func _is_slot_valid(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < SLOT_COUNT
