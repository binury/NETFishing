class_name FishInventory
extends Node

const FishCatchType = preload("res://fish/fish_catch.gd")

signal contents_changed(fish_id: StringName, count: int)
signal catches_changed

var _catches: Array[FishCatchType] = []
var _next_catch_sequence: int = 1
var _reservation_service: PlayerAssetReservationService
var _inventory_layout: PlayerInventoryLayout


func set_reservation_service(
	reservation_service: PlayerAssetReservationService,
) -> void:
	_reservation_service = reservation_service


func set_inventory_layout(layout: PlayerInventoryLayout) -> void:
	_inventory_layout = layout


func can_accept_catch(catch_id: StringName = StringName()) -> bool:
	return (
		_inventory_layout == null
		or _inventory_layout.can_accept_catch(catch_id)
	)


func add_catch(fish_catch: FishCatchType) -> bool:
	if fish_catch == null or not fish_catch.is_valid():
		return false
	if get_catch_by_id(fish_catch.catch_id) != null:
		return false
	if not can_accept_catch(fish_catch.catch_id):
		return false
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
	return true


func get_count(fish_id: StringName) -> int:
	return get_catches_by_fish_id(fish_id).size()


func get_all_catches() -> Array[FishCatchType]:
	return _catches.duplicate()


func get_next_catch_sequence() -> int:
	return _next_catch_sequence


func replace_all_catches(
	catches: Array[FishCatchType],
	requested_next_sequence: int,
) -> bool:
	var validated: Array[FishCatchType] = []
	var seen_ids: Dictionary[StringName, bool] = {}
	var seen_sequences: Dictionary[int, bool] = {}
	var maximum_sequence: int = 0
	for fish_catch: FishCatchType in catches:
		if (
			fish_catch == null
			or not fish_catch.is_valid()
			or fish_catch.catch_sequence <= 0
			or seen_ids.has(fish_catch.catch_id)
			or seen_sequences.has(fish_catch.catch_sequence)
		):
			return false
		seen_ids[fish_catch.catch_id] = true
		seen_sequences[fish_catch.catch_sequence] = true
		maximum_sequence = maxi(
			maximum_sequence,
			fish_catch.catch_sequence
		)
		validated.append(fish_catch)

	_catches = validated
	_next_catch_sequence = maxi(
		maxi(requested_next_sequence, 1),
		maximum_sequence + 1
	)
	catches_changed.emit()
	return true


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
	var removed: Array[FishCatchType] = remove_catches_by_ids([catch_id])
	return removed.front() if removed.size() == 1 else null


func remove_catches_by_ids(
	catch_ids: Array[StringName],
) -> Array[FishCatchType]:
	return _remove_catches_by_ids(catch_ids, "", "")


func remove_reserved_catch_for_mail_transfer(
	catch_id: StringName,
	reservation_id: String,
	transfer_id: String,
) -> FishCatchType:
	var removed := _remove_catches_by_ids(
		[catch_id], reservation_id, transfer_id
	)
	return removed.front() if removed.size() == 1 else null


func _remove_catches_by_ids(
	catch_ids: Array[StringName],
	mail_reservation_id: String,
	mail_transfer_id: String,
) -> Array[FishCatchType]:
	var removed: Array[FishCatchType] = []
	if catch_ids.is_empty():
		return removed
	var requested_ids: Dictionary[StringName, bool] = {}
	for catch_id: StringName in catch_ids:
		if catch_id.is_empty() or requested_ids.has(catch_id):
			return removed
		requested_ids[catch_id] = true
	for catch_id: StringName in catch_ids:
		var fish_catch: FishCatchType = get_catch_by_id(catch_id)
		if fish_catch == null:
			removed.clear()
			return removed
		if (
			_reservation_service != null
			and _reservation_service.is_fish_reserved(catch_id)
			and not _reservation_service.authorize_mail_fish_removal(
				mail_reservation_id,
				catch_id,
				mail_transfer_id,
			)
		):
			removed.clear()
			return removed
		removed.append(fish_catch)

	var remaining: Array[FishCatchType] = []
	var affected_species: Dictionary[StringName, bool] = {}
	for fish_catch: FishCatchType in _catches:
		if requested_ids.has(fish_catch.catch_id):
			affected_species[fish_catch.fish_id] = true
		else:
			remaining.append(fish_catch)
	_catches = remaining
	for fish_id: StringName in affected_species:
		contents_changed.emit(fish_id, get_count(fish_id))
	catches_changed.emit()
	return removed


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
