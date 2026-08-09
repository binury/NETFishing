class_name FishingShop
extends Control

const INPUT_OWNER: StringName = &"fishing_shop"
const MAIN_SHOP_BUYER_ID: StringName = &"main_fishing_shop"
const FishBuyerProfileType = preload("res://economy/fish_buyer_profile.gd")
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
const PlayerArtUnlocksType = preload(
	"res://progression/player_art_unlocks.gd"
)
const ArtShopStockType = preload("res://economy/art_shop_stock.gd")
const ShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)
const UtilityPageStyleType = preload("res://ui/utility_page_style.gd")
const OrganizerTabType = preload("res://ui/components/organizer_tab.gd")

signal menu_visibility_changed(is_open: bool)
signal sell_fish_requested
signal shop_cooler_return_requested
signal shop_cooler_confirmation_cancel_requested

enum CloseReason {
	USER,
	RANGE_EXIT,
	WATER_RECOVERY,
	SESSION_END,
	TEARDOWN,
}

enum ShopSection {
	UPGRADES,
	BAIT,
	SNACKS,
	EQUIPMENT,
	ART_SUPPLIES,
}

const SHOP_SECTION_LABELS: Array[String] = [
	"Upgrades",
	"Bait",
	"Snacks",
	"Equipment",
	"Art Supplies",
]

@onready var _wallet_label: Label = %WalletLabel
@onready var _shop_panel: PanelContainer = %ShopPanel
@onready var _shop_cooler_page: Control = %ShopCoolerPage
@onready var _shop_cooler_mount: Control = %ShopCoolerMount
@onready var _back_to_shop_button: Button = %BackToShopButton
@onready var _buy_mode_button: Button = %BuyModeButton
@onready var _sell_mode_button: Button = %SellModeButton
@onready var _feedback: Label = %Feedback
@onready var _shop_tab_bar: HBoxContainer = %ShopTabBar
@onready var _upgrades_content: VBoxContainer = %Upgrades
@onready var _supplies_content: VBoxContainer = %Supplies
@onready var _stock_title: Label = %StockTitle
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

var _player: PlayerType
var _wallet: PlayerWalletType
var _buyer: FishBuyerProfileType
var _upgrades: PlayerFishingUpgradesType
var _fishing_spot: FishingSpotType
var _interaction: ShopInteractionType
var _bag: PlayerBagType
var _item_catalog: ItemCatalogType
var _cooler_capacity: PlayerCoolerCapacityType
var _art_unlocks: PlayerArtUnlocksType
var _network_shop: NetworkShopService
var _prior_movement_enabled: bool = true
var _prior_camera_enabled: bool = true
var _prior_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _snapshot_stored: bool = false
var _mouse_snapshot_stored: bool = false
var _transaction_in_progress: bool = false
var _closing: bool = false
var _cooler_page_active: bool = false
var _cooler_modal_open: bool = false
var _shop_section: ShopSection = ShopSection.UPGRADES
var _shop_tabs: Array[OrganizerTab] = []


func _ready() -> void:
	UtilityPageStyleType.apply_page(self)
	_apply_shop_styles()
	_build_shop_tabs()
	%CloseButton.pressed.connect(close_shop)
	_buy_mode_button.pressed.connect(_focus_buy_page)
	_sell_mode_button.pressed.connect(_request_shop_cooler)
	_back_to_shop_button.pressed.connect(shop_cooler_return_requested.emit)
	_reel_purchase.pressed.connect(_purchase_reel_speed)
	_barrier_purchase.pressed.connect(_purchase_barrier_power)
	_cooler_purchase.pressed.connect(_purchase_cooler_capacity)


func _request_shop_cooler() -> void:
	if _transaction_in_progress:
		_feedback.text = "Finish the current transaction first."
		return
	if not _is_transaction_context_valid():
		_feedback.text = "The fishing shop is no longer available."
		return
	sell_fish_requested.emit()


func _focus_buy_page() -> void:
	_feedback.text = ""
	if _shop_section == ShopSection.UPGRADES:
		_reel_purchase.grab_focus()
		return
	for child: Node in _supplies_list.get_children():
		var stock_button := child as Button
		if stock_button != null and not stock_button.disabled:
			stock_button.grab_focus()
			return
	_buy_mode_button.grab_focus()


func _build_shop_tabs() -> void:
	for section_index: int in range(ShopSection.size()):
		var tab: OrganizerTab = OrganizerTabType.new()
		tab.text = SHOP_SECTION_LABELS[section_index]
		tab.palette_index = section_index
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_select_shop_section.bind(section_index, true))
		_shop_tab_bar.add_child(tab)
		_shop_tabs.append(tab)
	_select_shop_section(ShopSection.UPGRADES, false)


func _select_shop_section(section_index: int, focus_content: bool) -> void:
	_shop_section = section_index as ShopSection
	var showing_upgrades: bool = _shop_section == ShopSection.UPGRADES
	_upgrades_content.visible = showing_upgrades
	_supplies_content.visible = not showing_upgrades
	for tab_index: int in range(_shop_tabs.size()):
		_shop_tabs[tab_index].set_selected(tab_index == section_index, true)
	_refresh_supplies()
	if focus_content and visible:
		_focus_buy_page()


func _apply_shop_styles() -> void:
	var shop_panel := $ShopPanel as PanelContainer
	var shop_panel_style := UtilityPageStyleType.panel_style()
	shop_panel_style.set_corner_radius_all(24)
	shop_panel_style.content_margin_left = 0.0
	shop_panel_style.content_margin_top = 0.0
	shop_panel_style.content_margin_right = 0.0
	shop_panel_style.content_margin_bottom = 0.0
	shop_panel.add_theme_stylebox_override(
		"panel", shop_panel_style
	)
	for panel: PanelContainer in [
		$ShopPanel/Margin/Layout/Body/Upgrades/ReelCard,
		$ShopPanel/Margin/Layout/Body/Upgrades/BarrierCard,
		$ShopPanel/Margin/Layout/Body/Upgrades/CoolerCard,
	]:
		panel.add_theme_stylebox_override(
			"panel", UtilityPageStyleType.row_style()
		)
	for button: BaseButton in [
		%CloseButton,
		_buy_mode_button,
		_sell_mode_button,
		_reel_purchase,
		_barrier_purchase,
		_cooler_purchase,
		_back_to_shop_button,
	]:
		UtilityPageStyleType.apply_ocean_button(button)
	_buy_mode_button.add_theme_stylebox_override(
		"normal",
		UtilityPageStyleType.ocean_button_style(
			UtilityPageStyleType.OCEAN_SELECTED
		),
	)
	_feedback.add_theme_color_override(
		"font_color", UtilityPageStyleType.OCEAN_TEXT_SECONDARY
	)


func setup(
	player: PlayerType,
	wallet: PlayerWalletType,
	buyer: FishBuyerProfileType,
	upgrades: PlayerFishingUpgradesType,
	fishing_spot: FishingSpotType,
	interaction: ShopInteractionType,
	bag: PlayerBagType,
	item_catalog: ItemCatalogType,
	cooler_capacity: PlayerCoolerCapacityType,
	art_unlocks: PlayerArtUnlocksType,
	network_shop: NetworkShopService,
) -> void:
	_player = player
	_wallet = wallet
	_buyer = buyer
	_upgrades = upgrades
	_fishing_spot = fishing_spot
	_interaction = interaction
	_bag = bag
	_item_catalog = item_catalog
	_cooler_capacity = cooler_capacity
	_art_unlocks = art_unlocks
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
	if not _art_unlocks.unlocks_changed.is_connected(_on_art_unlocks_changed):
		_art_unlocks.unlocks_changed.connect(_on_art_unlocks_changed)
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
	deactivate_shop_cooler_page()
	show()
	_select_shop_section(ShopSection.UPGRADES, false)
	_refresh_all()
	_buy_mode_button.grab_focus()
	menu_visibility_changed.emit(true)
	return true


func consume_escape() -> bool:
	if not visible:
		return false
	if _cooler_page_active:
		if _cooler_modal_open:
			shop_cooler_confirmation_cancel_requested.emit()
		else:
			shop_cooler_return_requested.emit()
		return true
	close_shop()
	return true


func get_shop_cooler_mount() -> Control:
	return _shop_cooler_mount


func activate_shop_cooler_page() -> void:
	_cooler_page_active = true
	_shop_panel.hide()
	_shop_cooler_page.show()
	_back_to_shop_button.disabled = false


func deactivate_shop_cooler_page() -> void:
	_cooler_page_active = false
	_cooler_modal_open = false
	_back_to_shop_button.disabled = false
	_shop_cooler_page.hide()
	_shop_panel.show()
	if visible:
		_buy_mode_button.grab_focus()


func set_shop_cooler_modal_open(is_open: bool) -> void:
	_cooler_modal_open = is_open
	_back_to_shop_button.disabled = is_open


func close_shop(
	reason: CloseReason = CloseReason.USER,
	restore_controls: bool = true,
) -> void:
	if not visible:
		return
	_closing = true
	_transaction_in_progress = false
	hide()
	var current_viewport: Viewport = get_viewport()
	if current_viewport != null:
		current_viewport.gui_release_focus()
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
	deactivate_shop_cooler_page()


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
	_refresh_upgrades()
	_refresh_supplies()
	_refresh_cooler_capacity()


func _refresh_wallet() -> void:
	_wallet_label.text = (
		"wallet: $%d" % _wallet.get_balance()
		if _wallet != null
		else "wallet: $0"
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
		or _network_shop == null
		or not _network_shop.can_request_purchase()
		or not _upgrades.can_purchase_reel_speed(_wallet)
	)
	_reel_purchase.tooltip_text = (
		"Purchases are unavailable in this session."
		if _network_shop == null or not _network_shop.can_request_purchase()
		else ""
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
		or _network_shop == null
		or not _network_shop.can_request_purchase()
		or not _upgrades.can_purchase_barrier_power(_wallet)
	)
	_barrier_purchase.tooltip_text = _reel_purchase.tooltip_text
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
	if _shop_section == ShopSection.UPGRADES:
		return
	_stock_title.text = SHOP_SECTION_LABELS[int(_shop_section)]
	for item_id: StringName in FishingShopStockType.get_stock_item_ids():
		var item: ItemDataType = _item_catalog.get_item_by_id(item_id)
		if item == null or not _item_belongs_in_current_section(item):
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(195, 54)
		button.icon = item.icon
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var owned: int = _bag.get_quantity(item_id)
		var bait_topoff: bool = FishingShopStockType.is_bait_topoff(item_id)
		var bait_unlocked: bool = (
			not bait_topoff or _bag.is_bait_unlocked(item_id)
		)
		var quantity: int = FishingShopStockType.get_purchase_quantity(
			item_id, owned, item.max_stack
		)
		var total_cost: int = FishingShopStockType.get_purchase_cost(
			item_id, quantity, bait_unlocked
		)
		button.text = "%s\n$%d • owned %d" % [
			item.display_name,
			FishingShopStockType.get_price(item_id),
			owned,
		]
		var tooltip_text: String = item.description
		if bait_topoff:
			if item.icon != null:
				button.custom_minimum_size = Vector2(72, 72)
				button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				button.alignment = HORIZONTAL_ALIGNMENT_CENTER
				button.text = ""
			else:
				button.text = (
					"%s\nunlock $%d" % [item.display_name, total_cost]
					if not bait_unlocked
					else "%s\n$%d each • %d/%d" % [
						item.display_name,
						FishingShopStockType.get_price(item_id),
						owned,
						item.max_stack,
					]
				)
			tooltip_text = (
				"%s\nunlock $%d • fills to %d/%d\n%s" % [
					item.display_name,
					total_cost,
					item.max_stack,
					item.max_stack,
					item.description,
				]
				if not bait_unlocked
				else "%s\n$%d each • %d/%d\n%s" % [
					item.display_name,
					FishingShopStockType.get_price(item_id),
					owned,
					item.max_stack,
					item.description,
				]
			)
		button.disabled = (
			_transaction_in_progress
			or _closing
			or _network_shop == null
			or not _network_shop.can_request_purchase()
			or quantity <= 0
			or total_cost < 0
			or not _bag.can_add_item(item_id, quantity)
			or not _wallet.can_afford(total_cost)
		)
		button.tooltip_text = (
			"Purchases are unavailable in this session."
			if _network_shop == null or not _network_shop.can_request_purchase()
			else tooltip_text
		)
		UtilityPageStyleType.apply_ocean_button(button)
		button.pressed.connect(_purchase_supply.bind(item_id))
		_supplies_list.add_child(button)
	if _shop_section == ShopSection.ART_SUPPLIES:
		_add_stock_section("art kit")
		_add_art_kit_button()
		_add_stock_section("markers")
		for product_id: StringName in ArtShopStockType.MARKER_PRODUCTS:
			_add_art_upgrade_button(product_id)
		_add_stock_section("brushes")
		for product_id: StringName in ArtShopStockType.BRUSH_PRODUCTS:
			_add_art_upgrade_button(product_id)
		_add_stock_section("grids")
		for product_id: StringName in ArtShopStockType.GRID_PRODUCTS:
			_add_art_upgrade_button(product_id)


func _item_belongs_in_current_section(item: ItemDataType) -> bool:
	match _shop_section:
		ShopSection.BAIT:
			return item.is_bait()
		ShopSection.SNACKS:
			return item.category == ItemDataType.Category.CONSUMABLE
		ShopSection.EQUIPMENT:
			return item.category in [
				ItemDataType.Category.TOOL,
				ItemDataType.Category.LURE,
			]
	return false


func _add_stock_section(title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override(
		"font_color", UtilityPageStyleType.OCEAN_TEXT_SECONDARY
	)
	_supplies_list.add_child(label)


func _add_art_kit_button() -> void:
	var item: ItemDataType = _item_catalog.get_item_by_id(
		ArtShopStockType.ART_KIT_ITEM_ID
	)
	if item == null:
		return
	var owned: bool = _bag.get_quantity(ArtShopStockType.ART_KIT_ITEM_ID) > 0
	var button: Button = _make_stock_button(
		"%s\n$%d • %s" % [
			item.display_name,
			ArtShopStockType.ART_KIT_PRICE,
			"owned" if owned else "not owned",
		],
		item.description,
	)
	button.icon = item.icon
	button.expand_icon = true
	button.disabled = (
		owned
		or _transaction_in_progress
		or _closing
		or _network_shop == null
		or not _network_shop.can_request_art_purchase()
		or not _bag.can_add_item(ArtShopStockType.ART_KIT_ITEM_ID, 1)
		or not _wallet.can_afford(ArtShopStockType.ART_KIT_PRICE)
	)
	button.pressed.connect(_purchase_art_kit)


func _add_art_upgrade_button(product_id: StringName) -> void:
	var kit_owned: bool = (
		_bag.get_quantity(ArtShopStockType.ART_KIT_ITEM_ID) > 0
	)
	var unlocked: bool = _art_unlocks.owns_product(product_id)
	var button: Button = _make_stock_button(
		"%s\n$%d • %s" % [
			ArtShopStockType.get_display_name(product_id),
			ArtShopStockType.UPGRADE_PRICE,
			"unlocked" if unlocked else "locked",
		],
		ArtShopStockType.get_description(product_id),
	)
	button.disabled = (
		not kit_owned
		or unlocked
		or _transaction_in_progress
		or _closing
		or _network_shop == null
		or not _network_shop.can_request_art_purchase()
		or not _wallet.can_afford(ArtShopStockType.UPGRADE_PRICE)
	)
	button.pressed.connect(_purchase_art_upgrade.bind(product_id))


func _make_stock_button(button_text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(195, 54)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = button_text
	button.tooltip_text = tooltip
	UtilityPageStyleType.apply_ocean_button(button)
	_supplies_list.add_child(button)
	return button


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
		or _network_shop == null
		or not _network_shop.can_request_purchase()
		or not _cooler_capacity.can_purchase(_wallet)
	)
	_cooler_purchase.tooltip_text = _reel_purchase.tooltip_text
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


func _purchase_reel_speed() -> void:
	_purchase_upgrade(true)


func _purchase_barrier_power() -> void:
	_purchase_upgrade(false)


func _purchase_supply(item_id: StringName) -> void:
	if _transaction_in_progress or not _is_transaction_context_valid():
		_feedback.text = "unable to complete purchase."
		return
	var owned: int = _bag.get_quantity(item_id)
	var item: ItemDataType = _item_catalog.get_item_by_id(item_id)
	if item == null:
		_feedback.text = "Purchase could not be completed."
		return
	var quantity: int = FishingShopStockType.get_purchase_quantity(
		item_id, owned, item.max_stack
	)
	if quantity <= 0 or not _bag.can_add_item(item_id, quantity):
		_feedback.text = "Your Bag is full."
		return
	var total_cost: int = FishingShopStockType.get_purchase_cost(
		item_id, quantity, _bag.is_bait_unlocked(item_id)
	)
	if total_cost < 0 or not _wallet.can_afford(total_cost):
		_feedback.text = "Not enough fish coin."
		return
	if _network_shop == null:
		_feedback.text = "Purchase could not be completed."
		return
	_network_shop.request_supply(item_id)


func _purchase_art_kit() -> void:
	if _network_shop == null or not _is_transaction_context_valid():
		_feedback.text = "Purchase could not be completed."
		return
	_network_shop.request_art_kit()


func _purchase_art_upgrade(product_id: StringName) -> void:
	if _network_shop == null or not _is_transaction_context_valid():
		_feedback.text = "Purchase could not be completed."
		return
	_network_shop.request_art_upgrade(product_id)


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


func _on_art_unlocks_changed(_unlock_mask: int) -> void:
	_refresh_supplies()


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
