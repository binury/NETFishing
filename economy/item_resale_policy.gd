class_name ItemResalePolicy
extends RefCounted

const FishingShopStockType = preload("res://economy/fishing_shop_stock.gd")
const ItemDataType = preload("res://items/item_data.gd")


static func is_sellable(item: ItemDataType) -> bool:
	# Bait and lures live in their own tackle collection. Rods, tools, and
	# utility gear are permanent equipment. The unified sell tray currently
	# accepts ordinary consumable supplies only.
	return item != null and item.is_available() and (
		item.category == ItemDataType.Category.CONSUMABLE
	)


static func get_unit_value(item: ItemDataType) -> int:
	if not is_sellable(item):
		return -1
	var purchase_price := FishingShopStockType.get_price(item.item_id)
	return purchase_price / 2 if purchase_price >= 0 else -1
