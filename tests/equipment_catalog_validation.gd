extends SceneTree

const FishingShopStockType = preload("res://economy/fishing_shop_stock.gd")
const FishingShopType = preload("res://ui/fishing_shop.gd")
const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const PlayerWalletType = preload("res://economy/player_wallet.gd")

const ItemCatalogResource: ItemCatalogType = preload(
	"res://items/catalog/item_catalog.tres"
)


func _initialize() -> void:
	var shop := FishingShopType.new()
	assert(shop.call("_unlock_status", false) == "locked")
	assert(shop.call("_unlock_status", true) == "unlocked")
	shop.free()

	var magnet: ItemDataType = ItemCatalogResource.get_available_item_by_id(
		&"magnet"
	)
	assert(magnet != null)
	assert(magnet.category == ItemDataType.Category.TOOL)
	assert(magnet.icon == null)
	assert(not magnet.usable)
	assert(not magnet.equippable)
	assert(not magnet.hotbar_allowed)
	assert(FishingShopStockType.get_price(&"magnet") == 250)
	assert(FishingShopStockType.get_stock_item_ids().has(&"magnet"))
	assert(FishingShopStockType.is_permanent_unlock(&"magnet", magnet))

	var wallet := PlayerWalletType.new()
	wallet.current_balance = 250
	var bag := PlayerBagType.new()
	bag.setup(ItemCatalogResource)
	assert(FishingShopStockType.purchase_one(
		&"magnet", wallet, bag, ItemCatalogResource
	))
	assert(bag.owns_item(&"magnet"))
	assert(wallet.get_balance() == 0)
	assert(not FishingShopStockType.purchase_one(
		&"magnet", wallet, bag, ItemCatalogResource
	))
	bag.free()
	wallet.free()
	print("Equipment catalog validation: PASS")
	quit()
