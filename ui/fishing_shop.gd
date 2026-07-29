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
const FishBatchSelectionType = preload(
	"res://ui/fish_batch_selection.gd"
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
@onready var _selection_summary: Label = %SelectionSummary
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
var _network_session: NetworkSession
var _network_shop: NetworkShopService
var _fish_selection := FishBatchSelectionType.new()
var _confirmation_catch_ids: Array[StringName] = []
var _confirmation_generation: int = -1
var _prior_movement_enabled: bool = true
var _prior_camera_enabled: bool = true
var _prior_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _snapshot_stored: bool = false
var _mouse_snapshot_stored: bool = false
var _generation: int = 0
var _selection_input_generation: int = 0
var _transaction_in_progress: bool = false
var _closing: bool = false


func _ready() -> void:
	%CloseButton.pressed.connect(close_shop)
	_fish_list.item_selected.connect(_on_fish_selected)
	_fish_list.item_clicked.connect(_on_fish_clicked)
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
	network_session: NetworkSession,
	network_shop: NetworkShopService,
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
	_network_session = network_session
	_network_shop = network_shop
	if (
		_network_shop != null
		and not _network_shop.local_purchase_pending.is_connected(
			_on_network_purchase_pending
		)
	):
		_network_shop.local_purchase_pending.connect(
			_on_network_purchase_pending
		)
		_network_shop.local_purchase_finished.connect(
			_on_network_purchase_finished
		)
	_fish_selection.clear()
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
	_transaction_in_progress = (
		_network_shop != null
		and _network_shop.is_local_purchase_pending()
	)
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
	_fish_selection.clear()
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
		"wallet: $%d" % _wallet.get_balance()
		if _wallet != null
		else "wallet: $0"
	)


func _refresh_fish_list() -> void:
	_fish_list.clear()
	var catches: Array[FishCatchType] = (
		_inventory.get_all_catches() if _inventory != null else []
	)
	_sales_title.text = "cooler %d / %d • full base value" % [
		catches.size(),
		_cooler_capacity.get_capacity() if _cooler_capacity != null else 0,
	]
	catches.sort_custom(
		func(a: FishCatchType, b: FishCatchType) -> bool:
			return a.catch_sequence > b.catch_sequence
	)
	var visible_ids: Array[StringName] = []
	for fish_catch: FishCatchType in catches:
		if fish_catch != null and fish_catch.is_valid():
			visible_ids.append(fish_catch.catch_id)
	_fish_selection.set_visible_order(visible_ids)
	for fish_catch: FishCatchType in catches:
		if fish_catch == null or not fish_catch.is_valid():
			continue
		var marker: String = ""
		if _fish_selection.is_selected(fish_catch.catch_id):
			marker += "✓ "
		if fish_catch.catch_id == _fish_selection.get_focused_id():
			marker += "◆ "
		if fish_catch.is_favorited:
			marker += "★ "
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
				"favorited" if fish_catch.is_favorited else "available",
			]
		)
	_fish_empty.visible = _fish_list.item_count == 0
	_fish_list.deselect_all()
	for index: int in range(_fish_list.item_count):
		var catch_id := StringName(str(_fish_list.get_item_metadata(index)))
		if _fish_selection.is_selected(catch_id):
			_fish_list.select(index, false)


func _refresh_selected_fish() -> void:
	var fish_catch: FishCatchType = _get_selected_catch()
	_fish_texture.texture = (
		fish_catch.fish.display_texture if fish_catch != null else null
	)
	_fish_name.text = (
		fish_catch.fish.display_name if fish_catch != null else "select a fish"
	)
	if fish_catch == null:
		_fish_details.text = "choose one individual fish from your cooler."
		_update_sale_summary()
		return
	var individual_preview: FishSaleResultType = (
		_sale_service.preview_batch([fish_catch.catch_id], _buyer)
		if _sale_service != null
		else null
	)
	var offer: int = (
		individual_preview.payout if individual_preview != null else -1
	)
	_fish_details.text = (
		"%.2f lb • %s\nbase value: $%d\nmain-shop offer: $%d%s"
		% [
			fish_catch.weight_lb,
			fish_catch.fish.get_rarity_name(),
			fish_catch.sale_value,
			offer,
			"\nfavorited fish cannot be sold."
			if fish_catch.is_favorited
			else "",
		]
	)
	_update_sale_summary()


func _update_sale_summary() -> void:
	var selected_ids: Array[StringName] = _fish_selection.get_selected_ids()
	var selected_count: int = selected_ids.size()
	_sell_button.text = (
		"sell fish"
		if selected_count <= 1
		else "sell %d fish" % selected_count
	)
	if selected_count == 0:
		_selection_summary.text = "no fish selected"
		_sell_button.disabled = true
		return
	if _network_session != null and _network_session.is_joined_client():
		_selection_summary.text = (
			"1 fish selected"
			if selected_count == 1
			else "%d fish selected" % selected_count
		)
		_selection_summary.text += (
			"\nSell catches to the nearby pelicans."
		)
		_sell_button.disabled = true
		return
	var preview: FishSaleResultType = (
		_sale_service.preview_batch(selected_ids, _buyer)
		if _sale_service != null
		else null
	)
	_selection_summary.text = (
		"1 fish selected"
		if selected_count == 1
		else "%d fish selected" % selected_count
	)
	if (
		preview != null
		and (
			preview.is_success()
			or preview.status == FishSaleResultType.Status.FAVORITED
		)
	):
		_selection_summary.text += "\ntotal offer: $%d" % preview.payout
	if preview != null and preview.status == FishSaleResultType.Status.FAVORITED:
		_selection_summary.text += (
			"\nfavorited fish must be removed from the selection."
		)
	_sell_button.disabled = (
		preview == null
		or not preview.is_success()
		or _transaction_in_progress
		or _closing
	)


func _refresh_upgrades() -> void:
	if _upgrades == null:
		return
	var reel_level: int = _upgrades.get_reel_speed_level()
	var reel_cost: int = _upgrades.get_next_reel_speed_cost()
	_reel_level.text = "level %d" % reel_level
	_reel_purchase.disabled = (
		reel_cost < 0
		or _transaction_in_progress
		or _closing
		or not _upgrades.can_purchase_reel_speed(_wallet)
	)
	if reel_cost < 0:
		_reel_effect.text = "%.2f×" % _upgrades.get_reel_speed_multiplier()
		_reel_cost.text = "max"
	else:
		_reel_effect.text = (
			"%.2f× → %.2f×"
			% [
				_upgrades.get_reel_speed_multiplier(),
				1.0 + float(reel_level + 1) * 0.10,
			]
		)
		_reel_cost.text = "$%d" % reel_cost
	_reel_purchase.text = "max" if reel_cost < 0 else "purchase"
	var barrier_level: int = _upgrades.get_barrier_power_level()
	var barrier_cost: int = _upgrades.get_next_barrier_power_cost()
	_barrier_level.text = "level %d" % barrier_level
	_barrier_purchase.disabled = (
		barrier_cost < 0
		or _transaction_in_progress
		or _closing
		or not _upgrades.can_purchase_barrier_power(_wallet)
	)
	if barrier_cost < 0:
		_barrier_effect.text = "%d damage" % _upgrades.get_barrier_damage()
		_barrier_cost.text = "max"
	else:
		_barrier_effect.text = (
			"%d damage → %d damage"
			% [
				_upgrades.get_barrier_damage(),
				barrier_level + 2,
			]
		)
		_barrier_cost.text = "$%d" % barrier_cost
	_barrier_purchase.text = "max" if barrier_cost < 0 else "purchase"


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
		button.text = "%s\n$%d • owned %d" % [
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
	_cooler_level.text = "level %d" % level
	_cooler_purchase.disabled = (
		cost < 0
		or _transaction_in_progress
		or _closing
		or not _cooler_capacity.can_purchase(_wallet)
	)
	if cost < 0:
		_cooler_effect.text = "%d fish" % _cooler_capacity.get_capacity()
		_cooler_cost.text = "max"
		_cooler_purchase.text = "max"
	else:
		_cooler_effect.text = "%d → %d fish" % [
			_cooler_capacity.get_capacity(),
			next_capacity,
		]
		_cooler_cost.text = "$%d" % cost
		_cooler_purchase.text = "purchase"


func _on_fish_selected(index: int) -> void:
	if index < 0 or index >= _fish_list.item_count:
		return
	var input_generation: int = _selection_input_generation
	call_deferred(
		"_apply_keyboard_fish_selection",
		index,
		input_generation
	)


func _apply_keyboard_fish_selection(
	index: int,
	input_generation: int,
) -> void:
	if (
		input_generation != _selection_input_generation
		or index < 0
		or index >= _fish_list.item_count
	):
		return
	var catch_id := StringName(str(_fish_list.get_item_metadata(index)))
	_fish_selection.select_only(catch_id)
	_feedback.text = ""
	_refresh_fish_list()
	_refresh_selected_fish()


func _on_fish_clicked(
	index: int,
	_position: Vector2,
	mouse_button_index: int,
) -> void:
	if (
		mouse_button_index != MOUSE_BUTTON_LEFT
		or index < 0
		or index >= _fish_list.item_count
	):
		return
	_selection_input_generation += 1
	var catch_id := StringName(str(_fish_list.get_item_metadata(index)))
	_fish_selection.apply_click(
		catch_id,
		Input.is_key_pressed(KEY_CTRL),
		Input.is_key_pressed(KEY_SHIFT)
	)
	_feedback.text = ""
	_refresh_fish_list()
	_refresh_selected_fish()


func _open_sale_confirmation() -> void:
	if _network_session != null and _network_session.is_joined_client():
		_feedback.text = "Sell catches to the nearby pelicans."
		return
	var selected_ids: Array[StringName] = _fish_selection.get_selected_ids()
	if not _is_transaction_context_valid() or selected_ids.is_empty():
		_feedback.text = "the fish selection is no longer available."
		_refresh_all()
		return
	var preview: FishSaleResultType = _sale_service.preview_batch(
		selected_ids,
		_buyer
	)
	if not preview.is_success():
		_feedback.text = (
			"favorited fish cannot be sold. "
			+ "remove them from the selection first."
			if preview.status == FishSaleResultType.Status.FAVORITED
			else preview.get_message()
		)
		return
	_confirmation_catch_ids = selected_ids.duplicate()
	_confirmation_generation = _generation
	_confirmation_text.text = (
		"sell %d fish to the fishing shop for $%d?"
		% [preview.fish_count, preview.payout]
	)
	_confirmation.show()
	_cancel_sale.grab_focus()


func _close_sale_confirmation() -> void:
	_confirmation_catch_ids.clear()
	_confirmation_generation = -1
	_confirmation.hide()


func _on_confirm_sale() -> void:
	if (
		_transaction_in_progress
		or (
			_network_session != null
			and _network_session.is_joined_client()
		)
	):
		return
	var transaction_generation: int = _generation
	var catch_ids: Array[StringName] = _confirmation_catch_ids.duplicate()
	var confirmation_generation: int = _confirmation_generation
	_close_sale_confirmation()
	if (
		catch_ids.is_empty()
		or not _is_transaction_context_valid()
		or transaction_generation != _generation
		or confirmation_generation != transaction_generation
		or _buyer.id != MAIN_SHOP_BUYER_ID
	):
		_feedback.text = "unable to complete sale."
		return
	_transaction_in_progress = true
	var result: FishSaleResultType = _sale_service.sell_batch(
		catch_ids,
		_buyer
	)
	_transaction_in_progress = false
	if (
		transaction_generation != _generation
		or not visible
	):
		return
	if result.is_success():
		_feedback.text = (
			"fish sold for $%d."
			if result.fish_count == 1
			else "%d fish sold for $%d." % [
				result.fish_count,
				result.payout,
			]
		)
		_fish_selection.remove_ids(catch_ids)
	else:
		_feedback.text = result.get_message()
	_refresh_all()


func _purchase_reel_speed() -> void:
	_purchase_upgrade(true)


func _purchase_barrier_power() -> void:
	_purchase_upgrade(false)


func _purchase_supply(item_id: StringName) -> void:
	if _transaction_in_progress or not _is_transaction_context_valid():
		_feedback.text = "unable to complete purchase."
		return
	if not _bag.can_add_item(item_id, 1):
		_feedback.text = "Your Bag is full."
		return
	if not _wallet.can_afford(FishingShopStockType.get_price(item_id)):
		_feedback.text = "Not enough fish coin."
		return
	if _network_shop == null:
		_feedback.text = "Purchase could not be completed."
		return
	_network_shop.request_supply(item_id)


func _purchase_cooler_capacity() -> void:
	if _transaction_in_progress or not _is_transaction_context_valid():
		_feedback.text = "unable to complete purchase."
		return
	var cost: int = _cooler_capacity.get_next_cost()
	if cost < 0:
		_feedback.text = "Upgrade is already at maximum."
		return
	if not _wallet.can_afford(cost):
		_feedback.text = "Not enough fish coin."
		return
	if _network_shop == null:
		_feedback.text = "Purchase could not be completed."
		return
	_network_shop.request_cooler_capacity_upgrade()


func _purchase_upgrade(is_reel_speed: bool) -> void:
	if _transaction_in_progress or not _is_transaction_context_valid():
		_feedback.text = "unable to complete purchase."
		return
	var cost: int = (
		_upgrades.get_next_reel_speed_cost()
		if is_reel_speed
		else _upgrades.get_next_barrier_power_cost()
	)
	if cost < 0:
		_feedback.text = "Upgrade is already at maximum."
		return
	if not _wallet.can_afford(cost):
		_feedback.text = "Not enough fish coin."
		return
	if _network_shop == null:
		_feedback.text = "Purchase could not be completed."
		return
	if is_reel_speed:
		_network_shop.request_reel_speed_upgrade()
	else:
		_network_shop.request_barrier_power_upgrade()


func _on_network_purchase_pending(_request_id: String) -> void:
	_transaction_in_progress = true
	if visible:
		_feedback.text = "Purchasing…"
		_refresh_all()


func _on_network_purchase_finished(
	_request_id: String,
	accepted: bool,
	message: String,
	_product_id: StringName,
	_category: int,
	_quantity: int,
	total_cost: int,
) -> void:
	_transaction_in_progress = false
	if not visible:
		return
	_feedback.text = (
		"Purchase complete. $%d spent." % total_cost
		if accepted
		else message
	)
	_refresh_all()


func _get_selected_catch() -> FishCatchType:
	var focused_id: StringName = _fish_selection.get_focused_id()
	if _inventory == null or focused_id.is_empty():
		return null
	return _inventory.get_catch_by_id(focused_id)


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
	if not _confirmation_catch_ids.is_empty():
		var preview: FishSaleResultType = _sale_service.preview_batch(
			_confirmation_catch_ids,
			_buyer
		)
		if (
			_confirmation_generation != _generation
			or not preview.is_success()
		):
			_close_sale_confirmation()
			_feedback.text = (
				"favorited fish cannot be sold. "
				+ "remove them from the selection first."
				if preview.status == FishSaleResultType.Status.FAVORITED
				else preview.get_message()
			)
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
