class_name FishingShopStock
extends RefCounted

const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const PlayerWalletType = preload("res://economy/player_wallet.gd")

const ITEM_PRICES: Dictionary[StringName, int] = {
	&"coffee": 20,
	&"energy_drink": 35,
	&"snack": 30,
	&"fish_finder": 60,
}
const ITEM_ORDER: Array[StringName] = [
	&"coffee",
	&"energy_drink",
	&"snack",
	&"fish_finder",
]


static func get_price(item_id: StringName) -> int:
	return ITEM_PRICES.get(item_id, -1)


static func get_stock_item_ids() -> Array[StringName]:
	return ITEM_ORDER.duplicate()


static func purchase_one(
	item_id: StringName,
	wallet: PlayerWalletType,
	bag: PlayerBagType,
	catalog: ItemCatalogType,
) -> bool:
	if wallet == null or bag == null or catalog == null:
		return false
	var price: int = get_price(item_id)
	var item: ItemDataType = catalog.get_item_by_id(item_id)
	if (
		price < 0
		or item == null
		or not item.is_valid()
		or item.category != ItemDataType.Category.CONSUMABLE
		or not item.stackable
		or not item.usable
		or not bag.can_add_item(item_id, 1)
		or not wallet.can_afford(price)
	):
		return false
	if not wallet.debit(price):
		return false
	if bag.add_item(item_id, 1):
		return true
	if not wallet.credit(price):
		push_error("Fishing Shop failed to roll back an item purchase.")
	return false
