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


func setup(
	inventory: FishInventoryType,
	wallet: PlayerWalletType,
) -> void:
	_inventory = inventory
	_wallet = wallet


func can_sell(
	catch_id: StringName,
	buyer: FishBuyerProfileType,
) -> bool:
	return _validate_sale(catch_id, buyer).is_success()


func sell(
	catch_id: StringName,
	buyer: FishBuyerProfileType,
) -> FishSaleResultType:
	var result: FishSaleResultType = _validate_sale(catch_id, buyer)
	if not result.is_success():
		return result

	var removed_catch: FishCatchType = _inventory.remove_catch_by_id(catch_id)
	if removed_catch == null:
		result.success = false
		result.status = FishSaleResultType.Status.NOT_FOUND
		return result
	if not _wallet.credit(result.payout):
		_inventory.add_catch(removed_catch)
		result.success = false
		result.status = FishSaleResultType.Status.TRANSACTION_FAILED
		return result
	sale_completed.emit(result)
	return result


func _validate_sale(
	catch_id: StringName,
	buyer: FishBuyerProfileType,
) -> FishSaleResultType:
	var result := FishSaleResultType.new()
	result.catch_id = catch_id
	if (
		catch_id.is_empty()
		or _inventory == null
		or _wallet == null
	):
		result.status = FishSaleResultType.Status.NOT_FOUND
		return result
	if buyer == null or not buyer.is_valid():
		result.status = FishSaleResultType.Status.INVALID_BUYER
		return result
	var fish_catch: FishCatchType = _inventory.get_catch_by_id(catch_id)
	if fish_catch == null:
		result.status = FishSaleResultType.Status.NOT_FOUND
		return result
	result.fish_name = fish_catch.fish.display_name
	result.buyer_id = buyer.id
	result.buyer_display_name = buyer.display_name
	result.buyer_animal_name = (
		buyer.animal_name_plural
		if not buyer.animal_name_plural.is_empty()
		else buyer.display_name
	)
	result.base_value = fish_catch.sale_value
	result.payout = buyer.get_offer(result.base_value)
	if fish_catch.is_favorited:
		result.status = FishSaleResultType.Status.FAVORITED
	elif fish_catch.sale_value < 0:
		result.status = FishSaleResultType.Status.INVALID_VALUE
	elif result.payout < 0:
		result.status = FishSaleResultType.Status.INVALID_OFFER
	elif not _wallet.can_credit(result.payout):
		result.status = FishSaleResultType.Status.TRANSACTION_FAILED
	else:
		result.status = FishSaleResultType.Status.SUCCESS
		result.success = true
		result.sale_message = buyer.get_sale_message(
			result.fish_name,
			result.payout
		)
	return result
