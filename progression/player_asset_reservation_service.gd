class_name PlayerAssetReservationService
extends Node

enum AttachmentType { NONE, FISH_COIN, FISH, CONSUMABLE }

signal reservations_changed

var _wallet: PlayerWallet
var _inventory: FishInventory
var _bag: PlayerBag
var _catalog: ItemCatalog
var _reservations: Dictionary[String, Dictionary] = {}
var _mail_transfer_authorizations: Dictionary[String, Dictionary] = {}


func setup(
	wallet: PlayerWallet,
	inventory: FishInventory,
	bag: PlayerBag,
	catalog: ItemCatalog,
) -> void:
	_wallet = wallet
	_inventory = inventory
	_bag = bag
	_catalog = catalog


func reserve(reservation_id: String, attachment: Dictionary) -> bool:
	if (
		reservation_id.is_empty()
		or reservation_id.length() > 96
		or _reservations.has(reservation_id)
		or not validate_attachment(attachment)
	):
		return false
	var kind: int = attachment["type"]
	match kind:
		AttachmentType.NONE:
			return true
		AttachmentType.FISH_COIN:
			if int(attachment["amount"]) > get_available_fish_coin():
				return false
		AttachmentType.FISH:
			var catch_id := StringName(str(attachment["catch_id"]))
			var fish_catch := _inventory.get_catch_by_id(catch_id)
			if (
				fish_catch == null
				or fish_catch.is_favorited
				or is_fish_reserved(catch_id)
			):
				return false
		AttachmentType.CONSUMABLE:
			var item_id := StringName(str(attachment["item_id"]))
			if (
				int(attachment["quantity"])
				> get_available_item_quantity(item_id)
			):
				return false
	_reservations[reservation_id] = attachment.duplicate(true)
	reservations_changed.emit()
	return true


func release(reservation_id: String) -> bool:
	if not _reservations.erase(reservation_id):
		return false
	_mail_transfer_authorizations.erase(reservation_id)
	reservations_changed.emit()
	return true


func release_all() -> void:
	if _reservations.is_empty():
		return
	_reservations.clear()
	_mail_transfer_authorizations.clear()
	reservations_changed.emit()


func authorize_mail_transfer(
	reservation_id: String,
	catch_id: StringName,
	transfer_id: String,
) -> bool:
	var attachment := get_reservation(reservation_id)
	if (
		transfer_id.is_empty()
		or transfer_id.length() > 96
		or attachment.is_empty()
		or int(attachment.get("type", 0)) != AttachmentType.FISH
		or StringName(str(attachment.get("catch_id", ""))) != catch_id
	):
		return false
	_mail_transfer_authorizations[reservation_id] = {
		"catch_id": catch_id,
		"transfer_id": transfer_id,
	}
	return true


func authorize_mail_fish_removal(
	reservation_id: String,
	catch_id: StringName,
	transfer_id: String,
) -> bool:
	var authorization: Dictionary = _mail_transfer_authorizations.get(
		reservation_id, {}
	)
	return (
		not authorization.is_empty()
		and StringName(authorization.get("catch_id", StringName())) == catch_id
		and str(authorization.get("transfer_id", "")) == transfer_id
	)


func has_reservation(reservation_id: String) -> bool:
	return _reservations.has(reservation_id)


func get_reservation(reservation_id: String) -> Dictionary:
	return _reservations.get(reservation_id, {}).duplicate(true)


func get_available_fish_coin() -> int:
	return maxi(_wallet.get_balance() - get_reserved_fish_coin(), 0)


func get_reserved_fish_coin() -> int:
	var total := 0
	for attachment: Dictionary in _reservations.values():
		if int(attachment.get("type", 0)) == AttachmentType.FISH_COIN:
			total += int(attachment.get("amount", 0))
	return total


func get_available_item_quantity(item_id: StringName) -> int:
	return maxi(_bag.get_quantity(item_id) - get_reserved_item_quantity(item_id), 0)


func get_reserved_item_quantity(item_id: StringName) -> int:
	var total := 0
	for attachment: Dictionary in _reservations.values():
		if (
			int(attachment.get("type", 0)) == AttachmentType.CONSUMABLE
			and StringName(str(attachment.get("item_id", ""))) == item_id
		):
			total += int(attachment.get("quantity", 0))
	return total


func is_fish_reserved(catch_id: StringName) -> bool:
	for attachment: Dictionary in _reservations.values():
		if (
			int(attachment.get("type", 0)) == AttachmentType.FISH
			and StringName(str(attachment.get("catch_id", ""))) == catch_id
		):
			return true
	return false


func can_commit(reservation_id: String) -> bool:
	var attachment := get_reservation(reservation_id)
	if attachment.is_empty():
		return false
	match int(attachment["type"]):
		AttachmentType.FISH_COIN:
			return _wallet.can_afford(int(attachment["amount"]))
		AttachmentType.FISH:
			return _inventory.get_catch_by_id(
				StringName(str(attachment["catch_id"]))
			) != null
		AttachmentType.CONSUMABLE:
			return (
				_bag.get_quantity(StringName(str(attachment["item_id"])))
				>= int(attachment["quantity"])
			)
	return false


func commit_removal(
	reservation_id: String,
	mail_transfer_id: String = "",
) -> bool:
	var attachment := get_reservation(reservation_id)
	if attachment.is_empty() or not can_commit(reservation_id):
		return false
	var applied := false
	match int(attachment["type"]):
		AttachmentType.FISH_COIN:
			applied = _wallet.debit(int(attachment["amount"]))
		AttachmentType.FISH:
			var catch_id := StringName(str(attachment["catch_id"]))
			if authorize_mail_transfer(
				reservation_id, catch_id, mail_transfer_id
			):
				applied = (
					_inventory.remove_reserved_catch_for_mail_transfer(
						catch_id, reservation_id, mail_transfer_id
					)
					!= null
				)
		AttachmentType.CONSUMABLE:
			applied = _bag.remove_item(
				StringName(str(attachment["item_id"])),
				int(attachment["quantity"])
			)
	if applied:
		release(reservation_id)
	else:
		_mail_transfer_authorizations.erase(reservation_id)
	return applied


func validate_attachment(attachment: Dictionary) -> bool:
	if typeof(attachment.get("type")) != TYPE_INT:
		return false
	match int(attachment["type"]):
		AttachmentType.NONE:
			return attachment.size() == 1
		AttachmentType.FISH_COIN:
			return (
				attachment.size() == 2
				and
				typeof(attachment.get("amount")) == TYPE_INT
				and int(attachment["amount"]) >= 1
				and int(attachment["amount"]) <= 1000000000
			)
		AttachmentType.FISH:
			return (
				attachment.size() == 3
				and
				typeof(attachment.get("catch_id")) == TYPE_STRING
				and not str(attachment["catch_id"]).is_empty()
				and str(attachment["catch_id"]).length() <= 160
				and typeof(attachment.get("catch")) == TYPE_DICTIONARY
			)
		AttachmentType.CONSUMABLE:
			if (
				attachment.size() != 3
				or
				typeof(attachment.get("item_id")) != TYPE_STRING
				or typeof(attachment.get("quantity")) != TYPE_INT
				or int(attachment["quantity"]) < 1
				or int(attachment["quantity"]) > 999
			):
				return false
			var item := _catalog.get_item_by_id(
				StringName(str(attachment["item_id"]))
			)
			return item != null and item.category == ItemData.Category.CONSUMABLE
	return false
