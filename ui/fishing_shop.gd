class_name FishingShop
extends Control

const INPUT_OWNER: StringName = &"fishing_shop"
const MAIN_SHOP_BUYER_ID: StringName = &"main_fishing_shop"
const FishBuyerProfileType = preload("res://economy/fish_buyer_profile.gd")
const FishCatchType = preload("res://fish/fish_catch.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishSaleResultType = preload("res://economy/fish_sale_result.gd")
const FishSaleServiceType = preload("res://economy/fish_sale_service.gd")
const PlayerWalletType = preload("res://economy/player_wallet.gd")
const FishingShopStockType = preload("res://economy/fishing_shop_stock.gd")
const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const PlayerFishingUpgradesType = preload(
	"res://progression/player_fishing_upgrades.gd"
)
const PlayerType = preload("res://player/player.gd")
const PlayerCoolerCapacityType = preload(
	"res://progression/player_cooler_capacity.gd"
)
const ShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)

signal menu_visibility_changed(is_open: bool)

enum CloseReason {
	USER,
	RANGE_EXIT,
	WATER_RECOVERY,
	SESSION_END,
	TEARDOWN,
}

@onready var _wallet_label: Label = %WalletLabel
@onready var _fish_list: ItemList = %FishList
@onready var _sales_title: Label = %SalesTitle
@onready var _fish_empty: Label = %FishEmpty
@onready var _fish_texture: TextureRect = %FishTexture
@onready var _fish_name: Label = %FishName
@onready var _fish_details: Label = %FishDetails
@onready var _sell_button: Button = %SellButton
@onready var _feedback: Label = %Feedback
@onready var _reel_level: Label = %ReelLevel
@onready var _reel_effect: Label = %ReelEffect
@onready var _reel_cost: Label = %ReelCost
@onready var _reel_purchase: Button = %ReelPurchase
@onready var _barrier_level: Label = %BarrierLevel
@onready var _barrier_effect: Label = %BarrierEffect
@onready var _barrier_cost: Label = %BarrierCost
@onready var _barrier_purchase: Button = %BarrierPurchase
@onready var _supplies_list: VBoxContainer = %SuppliesList
@onready var _cooler_level: Label = %CoolerLevel
@onready var _cooler_effect: Label = %CoolerEffect
@onready var _cooler_cost: Label = %CoolerCost
@onready var _cooler_purchase: Button = %CoolerPurchase
@onready var _confirmation: PanelContainer = %SaleConfirmation
@onready var _confirmation_text: Label = %ConfirmationText
@onready var _confirm_sale: Button = %ConfirmSale
@onready var _cancel_sale: Button = %CancelSale

var _player: PlayerType
var _inventory: FishInventoryType
var _wallet: PlayerWalletType
var _sale_service: FishSaleServiceType
var _buyer: FishBuyerProfileType
var _upgrades: PlayerFishingUpgradesType
var _fishing_spot: FishingSpotType
var _interaction: ShopInteractionType
var _bag: PlayerBagType
var _item_catalog: ItemCatalogType
var _cooler_capacity: PlayerCoolerCapacityType
var _selected_catch_id: StringName
var _confirmation_catch_id: StringName
var _prior_movement_enabled: bool = true
var _prior_camera_enabled: bool = true
var _prior_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _snapshot_stored: bool = false
var _mouse_snapshot_stored: bool = false
var _generation: int = 0
var _transaction_in_progress: bool = false
var _closing: bool = false


func _ready() -> void:
	%CloseButton.pressed.connect(close_shop)
	_fish_list.item_selected.connect(_on_fish_selected)
	_sell_button.pressed.connect(_open_sale_confirmation)
	_confirm_sale.pressed.connect(_on_confirm_sale)
	_cancel_sale.pressed.connect(_close_sale_confirmation)
	_reel_purchase.pressed.connect(_purchase_reel_speed)
	_barrier_purchase.pressed.connect(_purchase_barrier_power)
	_cooler_purchase.pressed.connect(_purchase_cooler_capacity)


func setup(
	player: PlayerType,
	inventory: FishInventoryType,
	wallet: PlayerWalletType,
	sale_service: FishSaleServiceType,
	buyer: FishBuyerProfileType,
	upgrades: PlayerFishingUpgradesType,
	fishing_spot: FishingSpotType,
	interaction: ShopInteractionType,
	bag: PlayerBagType,
	item_catalog: ItemCatalogType,
	cooler_capacity: PlayerCoolerCapacityType,
) -> void:
	_player = player
	_inventory = inventory
	_wallet = wallet
	_sale_service = sale_service
	_buyer = buyer
	_upgrades = upgrades
	_fishing_spot = fishing_spot
	_interaction = interaction
	_bag = bag
	_item_catalog = item_catalog
	_cooler_capacity = cooler_capacity
	if not _inventory.catches_changed.is_connected(_on_inventory_changed):
		_inventory.catches_changed.connect(_on_inventory_changed)
	if not _wallet.balance_changed.is_connected(_on_wallet_changed):
		_wallet.balance_changed.connect(_on_wallet_changed)
	if not _upgrades.upgrades_changed.is_connected(_on_upgrades_changed):
		_upgrades.upgrades_changed.connect(_on_upgrades_changed)
	if not _bag.contents_changed.is_connected(_on_bag_changed):
		_bag.contents_changed.connect(_on_bag_changed)
	if not _cooler_capacity.capacity_changed.is_connected(
		_on_cooler_capacity_changed
	):
		_cooler_capacity.capacity_changed.connect(_on_cooler_capacity_changed)
	_refresh_all()


func open_shop() -> bool:
	if (
		visible
		or _player == null
		or _interaction == null
		or not _interaction.is_local_player_in_range()
		or _fishing_spot == null
		or not _fishing_spot.can_open_fishing_shop()
		or _buyer == null
		or not _buyer.is_valid()
		or _buyer.id != MAIN_SHOP_BUYER_ID
	):
		return false
	_generation += 1
	_closing = false
	_transaction_in_progress = false
	_prior_movement_enabled = _player.is_movement_enabled()
	_prior_camera_enabled = _player.is_camera_input_enabled()
	_prior_mouse_mode = Input.mouse_mode
	_snapshot_stored = true
	_mouse_snapshot_stored = true
	_player.set_movement_enabled(false)
	_player.set_camera_input_enabled(false)
	_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_feedback.text = ""
	_close_sale_confirmation()
	show()
	_refresh_all()
	%CloseButton.grab_focus()
	menu_visibility_changed.emit(true)
	return true


func consume_escape() -> bool:
	if not visible:
		return false
	if _confirmation.visible:
		_close_sale_confirmation()
	else:
		close_shop()
	return true


func close_shop(
	reason: CloseReason = CloseReason.USER,
	restore_controls: bool = true,
) -> void:
	if not visible:
		return
	_closing = true
	_generation += 1
	_transaction_in_progress = false
	_close_sale_confirmation()
	_selected_catch_id = StringName()
	hide()
	get_viewport().gui_release_focus()
	if _fishing_spot != null and is_instance_valid(_fishing_spot):
		_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, false)
	if (
		restore_controls
		and _snapshot_stored
		and _fishing_spot != null
		and _fishing_spot.is_ready_for_shop_transaction()
	):
		_player.set_movement_enabled(_prior_movement_enabled)
		_player.set_camera_input_enabled(_prior_camera_enabled)
	_snapshot_stored = false
	_apply_mouse_close_policy(reason)
	_closing = false
	menu_visibility_changed.emit(false)


func close_for_range_exit() -> void:
	close_shop(CloseReason.RANGE_EXIT)


func close_for_water_recovery() -> void:
	# Recovery emits its starting signal immediately before it captures the
	# player's current control state. Restore our local snapshot synchronously
	# so recovery captures the pre-shop state, then becomes the new authority
	# before another frame can process gameplay input.
	close_shop(CloseReason.WATER_RECOVERY, true)


func close_for_session_end() -> void:
	close_shop(CloseReason.SESSION_END, false)


func _exit_tree() -> void:
	if visible:
		close_shop(CloseReason.TEARDOWN, false)


func _refresh_all() -> void:
	if not is_node_ready():
		return
	_refresh_wallet()
	_refresh_fish_list()
	_refresh_selected_fish()
	_refresh_upgrades()
	_refresh_supplies()
	_refresh_cooler_capacity()


func _refresh_wallet() -> void:
	_wallet_label.text = (
		"Wallet: $%d" % _wallet.get_balance()
		if _wallet != null
		else "Wallet: $0"
	)


func _refresh_fish_list() -> void:
	_fish_list.clear()
	var catches: Array[FishCatchType] = (
		_inventory.get_all_catches() if _inventory != null else []
	)
	_sales_title.text = "Cooler %d / %d • Full base value" % [
		catches.size(),
		_cooler_capacity.get_capacity() if _cooler_capacity != null else 0,
	]
	catches.sort_custom(
		func(a: FishCatchType, b: FishCatchType) -> bool:
			return a.catch_sequence > b.catch_sequence
	)
	var selected_index: int = -1
	for fish_catch: FishCatchType in catches:
		if fish_catch == null or not fish_catch.is_valid():
			continue
		var marker: String = "★ " if fish_catch.is_favorited else ""
		var index: int = _fish_list.add_item(
			"%s%s — %.2f lb"
			% [marker, fish_catch.fish.display_name, fish_catch.weight_lb],
			fish_catch.fish.display_texture
		)
		_fish_list.set_item_metadata(index, String(fish_catch.catch_id))
		_fish_list.set_item_tooltip(
			index,
			"%s • %s"
			% [
				fish_catch.fish.get_rarity_name(),
				"Favorited" if fish_catch.is_favorited else "Available",
			]
		)
		if fish_catch.catch_id == _selected_catch_id:
			selected_index = index
	_fish_empty.visible = _fish_list.item_count == 0
	if selected_index >= 0:
		_fish_list.select(selected_index)
	elif not _selected_catch_id.is_empty():
		_selected_catch_id = StringName()


func _refresh_selected_fish() -> void:
	var fish_catch: FishCatchType = _get_selected_catch()
	_fish_texture.texture = (
		fish_catch.fish.display_texture if fish_catch != null else null
	)
	_fish_name.text = (
		fish_catch.fish.display_name if fish_catch != null else "Select a fish"
	)
	if fish_catch == null:
		_fish_details.text = "Choose one individual fish from your Cooler."
		_sell_button.disabled = true
		return
	var offer: int = _buyer.get_offer(fish_catch.sale_value)
	_fish_details.text = (
		"%.2f lb • %s\nBase value: $%d\nMain-shop offer: $%d%s"
		% [
			fish_catch.weight_lb,
			fish_catch.fish.get_rarity_name(),
			fish_catch.sale_value,
			offer,
			"\nFavorited fish cannot be sold."
			if fish_catch.is_favorited
			else "",
		]
	)
	_sell_button.disabled = (
		fish_catch.is_favorited
		or _transaction_in_progress
		or _closing
	)


func _refresh_upgrades() -> void:
	if _upgrades == null:
		return
	var reel_level: int = _upgrades.get_reel_speed_level()
	var reel_cost: int = _upgrades.get_next_reel_speed_cost()
	_reel_level.text = "Level %d" % reel_level
	_reel_purchase.disabled = (
		reel_cost < 0
		or _transaction_in_progress
		or _closing
		or not _upgrades.can_purchase_reel_speed(_wallet)
	)
	if reel_cost < 0:
		_reel_effect.text = "%.2f×" % _upgrades.get_reel_speed_multiplier()
		_reel_cost.text = "MAX"
	else:
		_reel_effect.text = (
			"%.2f× → %.2f×"
			% [
				_upgrades.get_reel_speed_multiplier(),
				1.0 + float(reel_level + 1) * 0.10,
			]
		)
		_reel_cost.text = "$%d" % reel_cost
	_reel_purchase.text = "MAX" if reel_cost < 0 else "Purchase"
	var barrier_level: int = _upgrades.get_barrier_power_level()
	var barrier_cost: int = _upgrades.get_next_barrier_power_cost()
	_barrier_level.text = "Level %d" % barrier_level
	_barrier_purchase.disabled = (
		barrier_cost < 0
		or _transaction_in_progress
		or _closing
		or not _upgrades.can_purchase_barrier_power(_wallet)
	)
	if barrier_cost < 0:
		_barrier_effect.text = "%d damage" % _upgrades.get_barrier_damage()
		_barrier_cost.text = "MAX"
	else:
		_barrier_effect.text = (
			"%d damage → %d damage"
			% [
				_upgrades.get_barrier_damage(),
				barrier_level + 2,
			]
		)
		_barrier_cost.text = "$%d" % barrier_cost
	_barrier_purchase.text = "MAX" if barrier_cost < 0 else "Purchase"


func _refresh_supplies() -> void:
	if _supplies_list == null:
		return
	for child: Node in _supplies_list.get_children():
		_supplies_list.remove_child(child)
		child.queue_free()
	for item_id: StringName in FishingShopStockType.get_stock_item_ids():
		var item: ItemDataType = _item_catalog.get_item_by_id(item_id)
		if item == null:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(195, 54)
		button.icon = item.icon
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text = "%s\n$%d • Owned %d" % [
			item.display_name,
			FishingShopStockType.get_price(item_id),
			_bag.get_quantity(item_id),
		]
		button.tooltip_text = item.description
		button.disabled = (
			_transaction_in_progress
			or _closing
			or not _bag.can_add_item(item_id, 1)
			or not _wallet.can_afford(
				FishingShopStockType.get_price(item_id)
			)
		)
		button.pressed.connect(_purchase_supply.bind(item_id))
		_supplies_list.add_child(button)


func _refresh_cooler_capacity() -> void:
	if _cooler_capacity == null:
		return
	var level: int = _cooler_capacity.get_level()
	var cost: int = _cooler_capacity.get_next_cost()
	var next_capacity: int = _cooler_capacity.get_next_capacity()
	_cooler_level.text = "Level %d" % level
	_cooler_purchase.disabled = (
		cost < 0
		or _transaction_in_progress
		or _closing
		or not _cooler_capacity.can_purchase(_wallet)
	)
	if cost < 0:
		_cooler_effect.text = "%d fish" % _cooler_capacity.get_capacity()
		_cooler_cost.text = "MAX"
		_cooler_purchase.text = "MAX"
	else:
		_cooler_effect.text = "%d → %d fish" % [
			_cooler_capacity.get_capacity(),
			next_capacity,
		]
		_cooler_cost.text = "$%d" % cost
		_cooler_purchase.text = "Purchase"


func _on_fish_selected(index: int) -> void:
	if index < 0 or index >= _fish_list.item_count:
		return
	_selected_catch_id = StringName(str(_fish_list.get_item_metadata(index)))
	_feedback.text = ""
	_refresh_selected_fish()


func _open_sale_confirmation() -> void:
	var fish_catch: FishCatchType = _get_selected_catch()
	if not _is_transaction_context_valid() or fish_catch == null:
		_feedback.text = "This fish is no longer available."
		_refresh_all()
		return
	if fish_catch.is_favorited:
		_feedback.text = "Favorited fish cannot be sold."
		return
	_confirmation_catch_id = fish_catch.catch_id
	var offer: int = _buyer.get_offer(fish_catch.sale_value)
	_confirmation_text.text = (
		"Sell this %.2f lb %s to the Fishing Shop for $%d?"
		% [fish_catch.weight_lb, fish_catch.fish.display_name, offer]
	)
	_confirmation.show()
	_cancel_sale.grab_focus()


func _close_sale_confirmation() -> void:
	_confirmation_catch_id = StringName()
	_confirmation.hide()


func _on_confirm_sale() -> void:
	if _transaction_in_progress:
		return
	var transaction_generation: int = _generation
	var catch_id: StringName = _confirmation_catch_id
	_close_sale_confirmation()
	if (
		catch_id.is_empty()
		or not _is_transaction_context_valid()
		or transaction_generation != _generation
		or _buyer.id != MAIN_SHOP_BUYER_ID
	):
		_feedback.text = "Unable to complete sale."
		return
	_transaction_in_progress = true
	var result: FishSaleResultType = _sale_service.sell(catch_id, _buyer)
	_transaction_in_progress = false
	if (
		transaction_generation != _generation
		or not visible
	):
		return
	if result.is_success():
		_feedback.text = "Fish sold for $%d." % result.payout
		_selected_catch_id = StringName()
	else:
		_feedback.text = result.get_message()
	_refresh_all()


func _purchase_reel_speed() -> void:
	_purchase_upgrade(true)


func _purchase_barrier_power() -> void:
	_purchase_upgrade(false)


func _purchase_supply(item_id: StringName) -> void:
	if _transaction_in_progress or not _is_transaction_context_valid():
		_feedback.text = "Unable to complete purchase."
		return
	var price: int = FishingShopStockType.get_price(item_id)
	if not _bag.can_add_item(item_id, 1):
		_feedback.text = "Bag cannot accept this item."
		return
	if not _wallet.can_afford(price):
		_feedback.text = "Not enough money."
		return
	var transaction_generation: int = _generation
	_transaction_in_progress = true
	var purchased: bool = FishingShopStockType.purchase_one(
		item_id,
		_wallet,
		_bag,
		_item_catalog
	)
	_transaction_in_progress = false
	if transaction_generation != _generation or not visible:
		return
	_feedback.text = (
		"Item purchased." if purchased else "Unable to complete purchase."
	)
	_refresh_all()


func _purchase_cooler_capacity() -> void:
	if _transaction_in_progress or not _is_transaction_context_valid():
		_feedback.text = "Unable to complete purchase."
		return
	var cost: int = _cooler_capacity.get_next_cost()
	if cost < 0:
		_feedback.text = "Maximum level reached."
		return
	if not _wallet.can_afford(cost):
		_feedback.text = "Not enough money."
		return
	var transaction_generation: int = _generation
	_transaction_in_progress = true
	var purchased: bool = _cooler_capacity.purchase(_wallet)
	_transaction_in_progress = false
	if transaction_generation != _generation or not visible:
		return
	_feedback.text = (
		"Upgrade purchased."
		if purchased
		else "Unable to complete purchase."
	)
	_refresh_all()


func _purchase_upgrade(is_reel_speed: bool) -> void:
	if _transaction_in_progress or not _is_transaction_context_valid():
		_feedback.text = "Unable to complete purchase."
		return
	var cost: int = (
		_upgrades.get_next_reel_speed_cost()
		if is_reel_speed
		else _upgrades.get_next_barrier_power_cost()
	)
	if cost < 0:
		_feedback.text = "Maximum level reached."
		return
	if not _wallet.can_afford(cost):
		_feedback.text = "Not enough money."
		return
	var transaction_generation: int = _generation
	_transaction_in_progress = true
	var purchased: bool = (
		_upgrades.purchase_reel_speed(_wallet)
		if is_reel_speed
		else _upgrades.purchase_barrier_power(_wallet)
	)
	_transaction_in_progress = false
	if transaction_generation != _generation or not visible:
		return
	_feedback.text = (
		"Upgrade purchased."
		if purchased
		else "Unable to complete purchase."
	)
	_refresh_all()


func _get_selected_catch() -> FishCatchType:
	if _inventory == null or _selected_catch_id.is_empty():
		return null
	return _inventory.get_catch_by_id(_selected_catch_id)


func _is_transaction_context_valid() -> bool:
	return (
		visible
		and not _closing
		and _interaction != null
		and _interaction.is_local_player_in_range()
		and _fishing_spot != null
		and _fishing_spot.is_ready_for_shop_transaction()
		and _buyer != null
		and _buyer.is_valid()
		and _buyer.id == MAIN_SHOP_BUYER_ID
	)


func _on_inventory_changed() -> void:
	_refresh_fish_list()
	if (
		not _confirmation_catch_id.is_empty()
		and _inventory.get_catch_by_id(_confirmation_catch_id) == null
	):
		_close_sale_confirmation()
		_feedback.text = "This fish is no longer available."
	_refresh_selected_fish()


func _on_wallet_changed(_balance: int, _delta: int) -> void:
	_refresh_wallet()
	_refresh_upgrades()
	_refresh_supplies()
	_refresh_cooler_capacity()


func _on_upgrades_changed(
	_reel_speed_level: int,
	_barrier_power_level: int,
) -> void:
	_refresh_upgrades()


func _on_bag_changed() -> void:
	_refresh_supplies()


func _on_cooler_capacity_changed(_level: int, _capacity: int) -> void:
	_refresh_cooler_capacity()
	_refresh_fish_list()


func _apply_mouse_close_policy(reason: CloseReason) -> void:
	if not _mouse_snapshot_stored:
		return
	match reason:
		CloseReason.USER, CloseReason.RANGE_EXIT:
			Input.mouse_mode = _prior_mouse_mode
		CloseReason.WATER_RECOVERY:
			Input.mouse_mode = _prior_mouse_mode
		CloseReason.SESSION_END:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		CloseReason.TEARDOWN:
			pass
	_mouse_snapshot_stored = false
