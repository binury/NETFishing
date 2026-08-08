class_name FishingShopStock
extends RefCounted

const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const PlayerWalletType = preload("res://economy/player_wallet.gd")
const WORM_MAX_STACK: int = 10

const ITEM_PRICES: Dictionary[StringName, int] = {
	&"worms": 1,
	&"snails": 3,
	&"shrimp": 7,
	&"squid_chunks": 15,
	&"whole_anchovy": 30,
	&"whole_sardine": 60,
	&"luminous_roe": 125,
	&"coffee": 20,
	&"energy_drink": 35,
	&"snack": 30,
	&"fish_finder": 60,
}
const BAIT_UNLOCK_PRICES: Dictionary[StringName, int] = {
	&"snails": 400,
	&"shrimp": 1200,
	&"squid_chunks": 3500,
	&"whole_anchovy": 9000,
	&"whole_sardine": 22000,
	&"luminous_roe": 50000,
}
const ITEM_ORDER: Array[StringName] = [
	&"worms",
	&"snails",
	&"shrimp",
	&"squid_chunks",
	&"whole_anchovy",
	&"whole_sardine",
	&"luminous_roe",
	&"coffee",
	&"energy_drink",
	&"snack",
	&"fish_finder",
]


static func get_price(item_id: StringName) -> int:
	return ITEM_PRICES.get(item_id, -1)


static func get_stock_item_ids() -> Array[StringName]:
	return ITEM_ORDER.duplicate()


static func get_unlock_price(item_id: StringName) -> int:
	return BAIT_UNLOCK_PRICES.get(item_id, -1)


static func get_purchase_quantity(
	item_id: StringName,
	owned: int,
	maximum_stack: int = WORM_MAX_STACK,
) -> int:
	if is_bait_topoff(item_id):
		return maxi(maximum_stack - owned, 0)
	return 1


static func is_bait_topoff(item_id: StringName) -> bool:
	return item_id == &"worms" or BAIT_UNLOCK_PRICES.has(item_id)


static func get_purchase_cost(
	item_id: StringName,
	quantity: int,
	bait_unlocked: bool,
) -> int:
	if quantity <= 0:
		return -1
	if is_bait_topoff(item_id) and item_id != &"worms" and not bait_unlocked:
		return get_unlock_price(item_id)
	var unit_price: int = get_price(item_id)
	return unit_price * quantity if unit_price >= 0 else -1


static func purchase_one(
	item_id: StringName,
	wallet: PlayerWalletType,
	bag: PlayerBagType,
	catalog: ItemCatalogType,
) -> bool:
	if wallet == null or bag == null or catalog == null:
		return false
	var item: ItemDataType = catalog.get_item_by_id(item_id)
	var bait_topoff: bool = is_bait_topoff(item_id)
	var quantity: int = get_purchase_quantity(
		item_id,
		bag.get_quantity(item_id),
		item.max_stack if item != null else WORM_MAX_STACK,
	)
	var price: int = get_purchase_cost(
		item_id,
		quantity,
		bag.is_bait_unlocked(item_id),
	)
	if (
		price < 0
		or item == null
		or not item.is_valid()
		or (item.category != ItemDataType.Category.CONSUMABLE and not bait_topoff)
		or not item.stackable
		or (not item.usable and not bait_topoff)
		or not bag.can_add_item(item_id, quantity)
		or not wallet.can_afford(price)
	):
		return false
	if not wallet.debit(price):
		return false
	if bag.add_item(item_id, quantity):
		return true
	if not wallet.credit(price):
		push_error("Fishing Shop failed to roll back an item purchase.")
	return false
