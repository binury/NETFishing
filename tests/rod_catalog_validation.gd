extends SceneTree

const FishingRodDataType = preload("res://items/fishing_rod_data.gd")
const FishingShopStockType = preload("res://economy/fishing_shop_stock.gd")
const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const OwnedItemType = preload("res://items/owned_item.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const PlayerWalletType = preload("res://economy/player_wallet.gd")

const ItemCatalogResource: ItemCatalogType = preload(
	"res://items/catalog/item_catalog.tres"
)
const RodAttachmentScene = preload(
	"res://player/fishing_rod_attachment.tscn"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_catalog_activation()
	_validate_shop_stock()
	_validate_inactive_save_compatibility()
	_validate_fallback_attachment()
	print("Rod catalog validation: PASS")
	quit()


func _validate_catalog_activation() -> void:
	var rods: Array[FishingRodDataType] = []
	for item: ItemDataType in ItemCatalogResource.get_valid_items():
		var rod := item as FishingRodDataType
		if rod == null:
			continue
		rods.append(rod)
		assert(rod.is_valid())
		if rod.icon == null:
			assert(not rod.active)
	assert(rods.size() == 21)
	var available_rods: Array[FishingRodDataType] = []
	for rod: FishingRodDataType in rods:
		if rod.is_available():
			available_rods.append(rod)
	assert(available_rods.size() == 1)
	var basic: FishingRodDataType = available_rods.front()
	assert(basic.item_id == &"basic_fishing_rod")
	assert(basic.icon != null)
	assert(basic.rod_model_scene == null)
	assert(
		ItemCatalogResource.get_available_item_by_id(&"aurora_rod") == null
	)
	assert(ItemCatalogResource.get_item_by_id(&"aurora_rod") != null)


func _validate_shop_stock() -> void:
	var stock: Array[FishingRodDataType] = (
		FishingShopStockType.get_rod_stock(ItemCatalogResource)
	)
	assert(stock.size() == 1)
	assert(stock.front().item_id == &"basic_fishing_rod")
	var wallet := PlayerWalletType.new()
	wallet.current_balance = 100
	var bag := PlayerBagType.new()
	bag.setup(ItemCatalogResource)
	assert(
		FishingShopStockType.purchase_one(
			&"basic_fishing_rod",
			wallet,
			bag,
			ItemCatalogResource,
		)
	)
	assert(bag.owns_item(&"basic_fishing_rod"))
	assert(wallet.get_balance() == 100)
	assert(
		not FishingShopStockType.purchase_one(
			&"aurora_rod",
			wallet,
			bag,
			ItemCatalogResource,
		)
	)
	bag.free()
	wallet.free()


func _validate_inactive_save_compatibility() -> void:
	var bag := PlayerBagType.new()
	bag.setup(ItemCatalogResource)
	assert(not bag.can_add_item(&"aurora_rod", 1))
	assert(not bag.add_item(&"aurora_rod", 1))
	var legacy_record := OwnedItemType.new()
	legacy_record.item_id = &"aurora_rod"
	legacy_record.quantity = 1
	var legacy_items: Array[OwnedItemType] = [legacy_record]
	assert(bag.replace_all_items(legacy_items))
	assert(bag.owns_item(&"aurora_rod"))
	bag.free()


func _validate_fallback_attachment() -> void:
	var attachment := RodAttachmentScene.instantiate()
	assert(attachment.get_node_or_null("FishingRod/FallbackRodMesh") != null)
	assert(attachment.get_node_or_null("FishingRod/ModelMount") != null)
	assert(attachment.get_node_or_null("FishingRod/FishingRodTip") != null)
	attachment.free()
