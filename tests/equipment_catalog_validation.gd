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
	var locked_button := Button.new()
	shop.call(
		"_add_unlock_state_icon", locked_button, false, Vector2(72.0, 72.0)
	)
	var locked_icon := locked_button.get_node(
		"UnlockStateIcon"
	) as TextureRect
	assert(locked_icon.texture.resource_path.ends_with("/lock_light.png"))
	assert(locked_icon.size == Vector2(48.0, 48.0))
	assert(locked_icon.position == Vector2(12.0, 6.0))
	assert(is_equal_approx(locked_icon.modulate.a, 0.75))
	assert(not bool(locked_icon.get_meta(&"unlocked")))
	locked_button.free()
	var unlocked_button := Button.new()
	shop.call(
		"_add_unlock_state_icon", unlocked_button, true, Vector2(72.0, 72.0)
	)
	assert(unlocked_button.get_node_or_null("UnlockStateIcon") == null)
	unlocked_button.free()
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
	var crab_net: ItemDataType = ItemCatalogResource.get_available_item_by_id(
		&"crab_net"
	)
	assert(crab_net != null)
	assert(crab_net.icon != null)
	assert(crab_net.icon.resource_path.ends_with("/equipment/temp_net.png"))
	var shovel: ItemDataType = ItemCatalogResource.get_available_item_by_id(
		&"standard_shovel"
	)
	assert(shovel != null)
	assert(shovel.category == ItemDataType.Category.TOOL)
	assert(shovel.icon != null)
	assert(shovel.equippable)
	assert(shovel.hotbar_allowed)
	assert(FishingShopStockType.get_price(&"standard_shovel") == 75)
	assert(FishingShopStockType.get_stock_item_ids().has(&"standard_shovel"))
	assert(FishingShopStockType.is_permanent_unlock(&"standard_shovel", shovel))

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
