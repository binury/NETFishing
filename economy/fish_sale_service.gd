class_name FishSaleService
extends Node

const FishCatchType = preload("res://fish/fish_catch.gd")
const FishBuyerProfileType = preload("res://economy/fish_buyer_profile.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishSaleResultType = preload("res://economy/fish_sale_result.gd")
const PlayerWalletType = preload("res://economy/player_wallet.gd")

signal sale_completed(result: FishSaleResultType)

var _inventory: FishInventoryType
var _wallet: PlayerWalletType
var _reservations: PlayerAssetReservationService


func setup(
	inventory: FishInventoryType,
	wallet: PlayerWalletType,
	reservations: PlayerAssetReservationService = null,
) -> void:
	_inventory = inventory
	_wallet = wallet
	_reservations = reservations


func can_sell(
	catch_id: StringName,
	buyer: FishBuyerProfileType,
) -> bool:
	return preview_batch([catch_id], buyer).is_success()


func can_sell_batch(
	catch_ids: Array[StringName],
	buyer: FishBuyerProfileType,
) -> bool:
	return preview_batch(catch_ids, buyer).is_success()


func preview_batch(
	catch_ids: Array[StringName],
	buyer: FishBuyerProfileType,
) -> FishSaleResultType:
	return _validate_batch(catch_ids, buyer)


func sell(
	catch_id: StringName,
	buyer: FishBuyerProfileType,
) -> FishSaleResultType:
	return sell_batch([catch_id], buyer)


func sell_batch(
	catch_ids: Array[StringName],
	buyer: FishBuyerProfileType,
) -> FishSaleResultType:
	var result: FishSaleResultType = _validate_batch(catch_ids, buyer)
	if not result.is_success():
		return result

	var inventory_snapshot: Array[FishCatchType] = _inventory.get_all_catches()
	var next_sequence_snapshot: int = _inventory.get_next_catch_sequence()
	var removed_catches: Array[FishCatchType] = (
		_inventory.remove_catches_by_ids(result.catch_ids)
	)
	if removed_catches.size() != result.catch_ids.size():
		result.success = false
		result.status = FishSaleResultType.Status.TRANSACTION_FAILED
		return result
	if not _wallet.credit(result.payout):
		if not _inventory.replace_all_catches(
			inventory_snapshot,
			next_sequence_snapshot
		):
			push_error("Unable to roll back a failed fish batch sale.")
		result.success = false
		result.status = FishSaleResultType.Status.TRANSACTION_FAILED
		return result
	sale_completed.emit(result)
	return result


func _validate_batch(
	catch_ids: Array[StringName],
	buyer: FishBuyerProfileType,
) -> FishSaleResultType:
	var result := FishSaleResultType.new()
	result.catch_ids = catch_ids.duplicate()
	result.fish_count = catch_ids.size()
	if _inventory == null or _wallet == null:
		result.status = FishSaleResultType.Status.TRANSACTION_FAILED
		return result
	if catch_ids.is_empty():
		result.status = FishSaleResultType.Status.INVALID_SELECTION
		return result
	if buyer == null or not buyer.is_valid():
		result.status = FishSaleResultType.Status.INVALID_BUYER
		return result
	result.buyer_id = buyer.id
	result.buyer_display_name = buyer.display_name
	result.buyer_animal_name = (
		buyer.animal_name_plural
		if not buyer.animal_name_plural.is_empty()
		else buyer.display_name
	)
	var seen_ids: Dictionary[StringName, bool] = {}
	var contains_favorite: bool = false
	const MAX_SAFE_TOTAL: int = 9223372036854775807
	for catch_id: StringName in catch_ids:
		if catch_id.is_empty() or seen_ids.has(catch_id):
			result.status = FishSaleResultType.Status.INVALID_SELECTION
			return result
		seen_ids[catch_id] = true
		var fish_catch: FishCatchType = _inventory.get_catch_by_id(catch_id)
		if fish_catch == null:
			result.status = FishSaleResultType.Status.NOT_FOUND
			return result
		if (
			_reservations != null
			and _reservations.is_fish_reserved(catch_id)
		):
			result.status = FishSaleResultType.Status.RESERVED
			return result
		if fish_catch.is_favorited:
			contains_favorite = true
		if fish_catch.sale_value < 0:
			result.status = FishSaleResultType.Status.INVALID_VALUE
			return result
		var offer: int = buyer.get_offer(fish_catch.sale_value)
		if offer < 0:
			result.status = FishSaleResultType.Status.INVALID_OFFER
			return result
		if (
			result.base_value > MAX_SAFE_TOTAL - fish_catch.sale_value
			or result.payout > MAX_SAFE_TOTAL - offer
		):
			result.status = FishSaleResultType.Status.TRANSACTION_FAILED
			return result
		result.base_value += fish_catch.sale_value
		result.payout += offer
		if result.fish_count == 1:
			result.catch_id = fish_catch.catch_id
			result.fish_name = fish_catch.fish.display_name
	if contains_favorite:
		result.status = FishSaleResultType.Status.FAVORITED
		return result
	if not _wallet.can_credit(result.payout):
		result.status = FishSaleResultType.Status.TRANSACTION_FAILED
		return result
	result.status = FishSaleResultType.Status.SUCCESS
	result.success = true
	if result.fish_count == 1:
		result.sale_message = buyer.get_sale_message(
			result.fish_name,
			result.payout
		)
	else:
		result.sale_message = "you sold %d fish to the %s for $%d." % [
			result.fish_count,
			result.buyer_animal_name,
			result.payout,
		]
	return result
