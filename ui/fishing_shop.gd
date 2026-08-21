class_name FishingShop
extends Control

const INPUT_OWNER: StringName = &"fishing_shop"
const MAIN_SHOP_BUYER_ID: StringName = &"main_fishing_shop"
const FishBuyerProfileType = preload("res://economy/fish_buyer_profile.gd")
const PlayerWalletType = preload("res://economy/player_wallet.gd")
const FishingShopStockType = preload("res://economy/fishing_shop_stock.gd")
const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const FishingRodDataType = preload("res://items/fishing_rod_data.gd")
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
const LockedContentPresentationType = preload(
	"res://ui/components/locked_content_presentation.gd"
)
const UIMotionType = preload("res://ui/ui_motion.gd")
const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const ControllerFocusNavigationType = preload(
	"res://ui/controller_focus_navigation.gd"
)
const FALLBACK_SUPPLY_ICON: Texture2D = preload(
	"res://ui/icons/pictograms/x_light.png"
)
const ART_KIT_MARKER_ICON: Texture2D = preload(
	"res://items/icons/art/art_kit_marker.png"
)
const ART_KIT_MARKER_SHADER: Shader = preload(
	"res://ui/art_kit_marker_icon.gdshader"
)
const ART_UPGRADE_ICONS: Dictionary[StringName, Texture2D] = {
	&"brush_2x": preload(
		"res://items/icons/art/art_kit_marker_tip_thin.png"
	),
	&"brush_3x": preload(
		"res://items/icons/art/art_kit_marker_tip_mid.png"
	),
	&"brush_4x": preload(
		"res://items/icons/art/art_kit_marker_tip_thick.png"
	),
	&"grid_32x": preload(
		"res://items/icons/art/art_kit_grid_medium_light.png"
	),
	&"grid_64x": preload(
		"res://items/icons/art/art_kit_grid_large_light.png"
	),
	&"grid_128x": preload(
		"res://items/icons/art/art_kit_grid_xl_light.png"
	),
}
const CURRENCY_ICON: Texture2D = preload(
	"res://items/icons/shop/32_currency.png"
)

signal menu_visibility_changed(is_open: bool)
signal menu_exit_started
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
	SELL_FISH,
}

enum ControllerZone {
	TABS,
	CONTENT,
}

const SHOP_SECTION_LABELS: Array[String] = [
	"Upgrades",
	"Bait and Lures",
	"Snacks",
	"Equipment",
	"Art Supplies",
	"Sell",
]
const SUPPLY_ICON_GRID_COLUMNS: int = 9
const SUPPLY_ICON_TILE_SIZE := Vector2(72.0, 72.0)
const SUPPLY_ICON_HOST_SIZE := Vector2(72.0, 84.0)
const SHOP_SLOT_SEPARATION: int = 28
const SUPPLY_PRICE_COLOR := Color("c3dfe6")
const SUPPLY_PRICE_FONT_SIZE: int = 15
const SUPPLY_PRICE_Y: float = 60.0
const SUPPLY_PRICE_HEIGHT: float = 24.0
const SUPPLY_PRICE_HORIZONTAL_PADDING: float = 12.0
const SUPPLY_PRICE_ICON_SIZE: float = 18.0
const SUPPLY_PRICE_ICON_GAP: float = 3.0
const BAIT_SUPPLY_BADGE_Y: float = (
	UtilityPageStyleType.SUPPLY_BADGE_EDGE_MARGIN
)
const LOCK_BADGE_SIZE := Vector2(30.0, 30.0)
const LOCK_BADGE_MARGIN := Vector2(4.0, 4.0)
const LOCK_BADGE_ICON_SIZE := Vector2(18.0, 18.0)
const LOCK_BADGE_ALPHA: float = 0.9
const LOCK_BADGE_ICON_ALPHA: float = 0.88
const ROD_CARD_TILE_SIZE := Vector2(144.0, 144.0)
const ROD_CARD_HOST_SIZE := Vector2(152.0, 198.0)
const ROD_CAROUSEL_HEIGHT: float = 206.0
const ROD_CAROUSEL_SEPARATION: int = SHOP_SLOT_SEPARATION
const ROD_CAROUSEL_STEP: float = 328.0
const ROD_PRICE_Y: float = 128.0
const ROD_PRICE_HEIGHT: float = 30.0
const ROD_PRICE_FONT_SIZE: int = 18
const ROD_PRICE_ICON_SIZE: float = 22.0

@onready var _wallet_label: Label = %WalletLabel
@onready var _shop_panel: PanelContainer = %ShopPanel
@onready var _shop_panel_margin: MarginContainer = $ShopPanel/Margin
@onready var _shop_panel_layout: VBoxContainer = $ShopPanel/Margin/Layout
@onready var _shop_cooler_page: Control = %ShopCoolerPage
@onready var _shop_cooler_mount: Control = %ShopCoolerMount
@onready var _shop_body: HBoxContainer = $ShopPanel/Margin/Layout/Body
@onready var _feedback: RichTextLabel = %Feedback
@onready var _shop_tab_bar: HBoxContainer = %ShopTabBar
@onready var _upgrades_content: VBoxContainer = %Upgrades
@onready var _supplies_content: VBoxContainer = %Supplies
@onready var _stock_title: Label = %StockTitle
@onready var _reel_cost: CurrencyAmount = %ReelCost
@onready var _reel_price_bubble: PanelContainer = %ReelPriceBubble
@onready var _reel_purchase: Button = %ReelPurchase
@onready var _barrier_cost: CurrencyAmount = %BarrierCost
@onready var _barrier_price_bubble: PanelContainer = %BarrierPriceBubble
@onready var _barrier_purchase: Button = %BarrierPurchase
@onready var _supplies_list: VBoxContainer = %SuppliesList
@onready var _cooler_cost: CurrencyAmount = %CoolerCost
@onready var _cooler_price_bubble: PanelContainer = %CoolerPriceBubble
@onready var _cooler_purchase: Button = %CoolerPurchase
@onready var _backpack_cost: CurrencyAmount = %BackpackCost
@onready var _backpack_price_bubble: PanelContainer = %BackpackPriceBubble
@onready var _backpack_purchase: Button = %BackpackPurchase

var _player: PlayerType
var _wallet: PlayerWalletType
var _buyer: FishBuyerProfileType
var _upgrades: PlayerFishingUpgradesType
var _fishing_spot: FishingSpotType
var _interaction: ShopInteractionType
var _bag: PlayerBagType
var _inventory: FishInventory
var _hotbar: PlayerHotbar
var _inventory_layout: PlayerInventoryLayout
var _item_catalog: ItemCatalogType
var _cooler_capacity: PlayerCoolerCapacityType
var _art_unlocks: PlayerArtUnlocksType
var _network_shop: NetworkShopService
var _network_sale: NetworkSaleService
var _reservations: PlayerAssetReservationService
var _sell_inventory: ShopSellInventory
var _prior_movement_enabled: bool = true
var _prior_camera_enabled: bool = true
var _prior_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _snapshot_stored: bool = false
var _mouse_snapshot_stored: bool = false
var _transaction_in_progress: bool = false
var _closing: bool = false
var _close_generation: int = 0
var _close_tween: Tween
var _cooler_page_active: bool = false
var _cooler_modal_open: bool = false
var _shop_section: ShopSection = ShopSection.UPGRADES
var _shop_tabs: Array[OrganizerTab] = []
var _controller_mapping_manager: ControllerMappingManagerType
var _controller_zone: ControllerZone = ControllerZone.TABS


func _ready() -> void:
	UtilityPageStyleType.apply_page(self)
	_apply_shop_styles()
	_build_shop_tabs()
	%CloseButton.pressed.connect(close_shop)
	_reel_purchase.pressed.connect(_purchase_reel_speed)
	_barrier_purchase.pressed.connect(_purchase_barrier_power)
	_cooler_purchase.pressed.connect(_purchase_cooler_capacity)
	_backpack_purchase.pressed.connect(_purchase_backpack_capacity)


func setup_controller_mapping(
	mapping_manager: ControllerMappingManagerType,
) -> void:
	_controller_mapping_manager = mapping_manager


func _input(event: InputEvent) -> void:
	if (
		not visible
		or _closing
		or _cooler_page_active
		or _cooler_modal_open
	):
		return
	var button_event := event as InputEventJoypadButton
	if button_event == null:
		return
	var uses_accept: bool = (
		_controller_mapping_manager.event_matches_role(
			event,
			ControllerMappingManagerType.ROLE_A,
		)
		if _controller_mapping_manager != null
		else button_event.button_index == JOY_BUTTON_A
	)
	var uses_cancel: bool = (
		_controller_mapping_manager.event_matches_role(
			event,
			ControllerMappingManagerType.ROLE_B,
		)
		if _controller_mapping_manager != null
		else button_event.button_index == JOY_BUTTON_B
	)
	if uses_cancel:
		get_viewport().set_input_as_handled()
		if not button_event.pressed:
			return
		if _controller_zone == ControllerZone.CONTENT:
			_enter_shop_tabs_zone()
		else:
			close_shop()
		return
	if uses_accept:
		if _controller_zone != ControllerZone.TABS:
			# Content buttons use Godot's native ui_accept activation. Keeping a
			# second manual pressed.emit() path here allowed one controller press
			# to be interpreted by two different owners.
			return
		get_viewport().set_input_as_handled()
		if not button_event.pressed or _transaction_in_progress:
			return
		_enter_shop_content_zone()
		return
	var uses_left_bumper: bool = (
		_controller_mapping_manager.event_uses_role(
			event,
			ControllerMappingManagerType.ROLE_LB,
		)
		if _controller_mapping_manager != null
		else button_event.button_index == JOY_BUTTON_LEFT_SHOULDER
	)
	var uses_right_bumper: bool = (
		_controller_mapping_manager.event_uses_role(
			event,
			ControllerMappingManagerType.ROLE_RB,
		)
		if _controller_mapping_manager != null
		else button_event.button_index == JOY_BUTTON_RIGHT_SHOULDER
	)
	if not (uses_left_bumper or uses_right_bumper):
		return
	get_viewport().set_input_as_handled()
	if not button_event.pressed or _transaction_in_progress:
		return
	var direction: int = -1 if uses_left_bumper else 1
	var current_section: int = _focused_shop_tab_index()
	if current_section < 0:
		current_section = int(_shop_section)
	var next_section: int = wrapi(
		current_section + direction,
		0,
		ShopSection.size(),
	)
	if _controller_zone == ControllerZone.TABS:
		_focus_shop_tab(next_section)
	else:
		_select_shop_section(next_section, true)


func _enter_shop_tabs_zone() -> void:
	_controller_zone = ControllerZone.TABS
	_apply_shop_controller_zone_focus_modes()
	_configure_controller_focus()
	_focus_shop_tab(int(_shop_section))


func _enter_shop_content_zone() -> void:
	var section_index: int = _focused_shop_tab_index()
	if section_index < 0:
		section_index = int(_shop_section)
	_controller_zone = ControllerZone.CONTENT
	_select_shop_section(section_index, true)


func _focused_shop_tab_index() -> int:
	var focused: Control = get_viewport().gui_get_focus_owner()
	for tab_index: int in _shop_tabs.size():
		if _shop_tabs[tab_index] == focused:
			return tab_index
	return -1


func _is_shop_tab(control: Control) -> bool:
	for tab: OrganizerTab in _shop_tabs:
		if tab == control:
			return true
	return false


func _focus_shop_tab(section_index: int) -> void:
	if section_index < 0 or section_index >= _shop_tabs.size():
		return
	var tab: OrganizerTab = _shop_tabs[section_index]
	if tab.focus_mode != Control.FOCUS_NONE and not tab.disabled:
		tab.call_deferred("grab_focus")


func _request_shop_cooler() -> bool:
	if _transaction_in_progress:
		_set_feedback("Finish the current transaction first.")
		return false
	if not _is_transaction_context_valid():
		_set_feedback("The fishing shop is no longer available.")
		return false
	activate_shop_cooler_page()
	if _sell_inventory != null:
		_sell_inventory.activate()
	return _cooler_page_active


func _focus_shop_section() -> void:
	_set_feedback("")
	_configure_controller_focus()
	if _shop_section == ShopSection.UPGRADES:
		for upgrade_button: Button in [
			_reel_purchase,
			_barrier_purchase,
			_cooler_purchase,
			_backpack_purchase,
		]:
			if not upgrade_button.disabled:
				upgrade_button.grab_focus()
				return
	if _shop_section == ShopSection.SELL_FISH:
		return
	for child: Node in _supplies_list.find_children(
		"*", "Button", true, false
	):
		var stock_button := child as Button
		if stock_button != null and not stock_button.disabled:
			stock_button.grab_focus()
			return
	var close_button := %CloseButton as Button
	if close_button.focus_mode != Control.FOCUS_NONE:
		close_button.grab_focus()


func _build_shop_tabs() -> void:
	_shop_tab_bar.custom_minimum_size.y = 44.0
	_shop_tab_bar.show()
	for section_index: int in range(ShopSection.size()):
		if section_index == ShopSection.SELL_FISH:
			var tab_group_spacer := Control.new()
			tab_group_spacer.name = "SellTabSpacer"
			tab_group_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tab_group_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_shop_tab_bar.add_child(tab_group_spacer)
		var tab: OrganizerTab = OrganizerTabType.new()
		tab.text = SHOP_SECTION_LABELS[section_index]
		tab.palette_index = section_index
		tab.custom_minimum_size = Vector2(132.0, 42.0)
		tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		tab.focus_mode = Control.FOCUS_ALL
		tab.mouse_filter = Control.MOUSE_FILTER_STOP
		tab.pressed.connect(_select_shop_section.bind(section_index, true))
		_shop_tab_bar.add_child(tab)
		tab.show()
		_shop_tabs.append(tab)
	_select_shop_section(ShopSection.UPGRADES, false)


func _select_shop_section(section_index: int, focus_content: bool) -> void:
	if _closing:
		return
	if focus_content:
		_controller_zone = ControllerZone.CONTENT
	if section_index == int(_shop_section):
		if section_index != ShopSection.SELL_FISH:
			var showing_upgrades := section_index == ShopSection.UPGRADES
			_upgrades_content.visible = showing_upgrades
			_supplies_content.visible = not showing_upgrades
		_update_shop_tab_selection()
		if focus_content:
			_focus_shop_section()
		return
	if section_index == ShopSection.SELL_FISH:
		if not _request_shop_cooler():
			_update_shop_tab_selection()
			return
		_shop_section = ShopSection.SELL_FISH
		_update_shop_tab_selection()
		return
	if _cooler_page_active:
		deactivate_shop_cooler_page()
	_shop_section = section_index as ShopSection
	var showing_upgrades: bool = _shop_section == ShopSection.UPGRADES
	_upgrades_content.visible = showing_upgrades
	_supplies_content.visible = not showing_upgrades
	_update_shop_tab_selection()
	_refresh_supplies()
	if focus_content and visible:
		_focus_shop_section()
	call_deferred("_configure_controller_focus")


func _configure_controller_focus() -> void:
	if not visible or _cooler_page_active:
		return
	_apply_shop_controller_zone_focus_modes()
	var candidates: Array[Control] = _active_shop_controller_controls()
	ControllerFocusNavigationType.configure_spatial_neighbors(candidates)


func _active_shop_controller_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if _controller_zone == ControllerZone.TABS:
		for tab: OrganizerTab in _shop_tabs:
			if ControllerFocusNavigationType.is_focusable(tab):
				controls.append(tab)
		return controls
	var active_root: Control = (
		_upgrades_content
		if _shop_section == ShopSection.UPGRADES
		else _supplies_content
	)
	for node: Node in active_root.find_children(
		"*", "BaseButton", true, false
	):
		var button := node as BaseButton
		if ControllerFocusNavigationType.is_focusable(button):
			controls.append(button)
	var close_button := %CloseButton as Button
	if ControllerFocusNavigationType.is_focusable(close_button):
		controls.append(close_button)
	return controls


func _apply_shop_controller_zone_focus_modes() -> void:
	var tabs_active: bool = _controller_zone == ControllerZone.TABS
	for tab: OrganizerTab in _shop_tabs:
		tab.focus_mode = (
			Control.FOCUS_ALL if tabs_active else Control.FOCUS_NONE
		)
	var content_focus_mode := (
		Control.FOCUS_NONE if tabs_active else Control.FOCUS_ALL
	)
	for content_root: Control in [_upgrades_content, _supplies_content]:
		_set_descendant_button_focus_mode(content_root, content_focus_mode)
	(%CloseButton as Button).focus_mode = content_focus_mode


func _set_descendant_button_focus_mode(
	root_control: Control,
	focus_mode: Control.FocusMode,
) -> void:
	for child: Node in root_control.find_children("*", "BaseButton", true, false):
		var button := child as BaseButton
		if button != null:
			button.focus_mode = focus_mode


func _update_shop_tab_selection() -> void:
	for tab_index: int in range(_shop_tabs.size()):
		_shop_tabs[tab_index].set_selected(
			tab_index == int(_shop_section),
			true,
		)


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
		_reel_price_bubble,
		_barrier_price_bubble,
		_cooler_price_bubble,
		_backpack_price_bubble,
	]:
		var price_style := UtilityPageStyleType.rounded_style(
			UtilityPageStyleType.OCEAN_FIELD,
			18,
		)
		price_style.content_margin_left = 8.0
		price_style.content_margin_right = 8.0
		price_style.content_margin_top = 2.0
		price_style.content_margin_bottom = 2.0
		panel.add_theme_stylebox_override(
			"panel", price_style
		)
	for price: CurrencyAmount in [
		_reel_cost,
		_barrier_cost,
		_cooler_cost,
		_backpack_cost,
	]:
		var amount_label := price.get_amount_label()
		amount_label.add_theme_color_override(
			"font_color", SUPPLY_PRICE_COLOR
		)
		amount_label.add_theme_font_size_override("font_size", 18)
	for button: BaseButton in [
		%CloseButton,
		_reel_purchase,
		_barrier_purchase,
		_cooler_purchase,
		_backpack_purchase,
	]:
		UtilityPageStyleType.apply_ocean_button(button)
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
	inventory: FishInventory,
	hotbar: PlayerHotbar,
	inventory_layout: PlayerInventoryLayout,
	item_catalog: ItemCatalogType,
	cooler_capacity: PlayerCoolerCapacityType,
	art_unlocks: PlayerArtUnlocksType,
	network_shop: NetworkShopService,
	network_sale: NetworkSaleService,
	reservations: PlayerAssetReservationService,
) -> void:
	_player = player
	_wallet = wallet
	_buyer = buyer
	_upgrades = upgrades
	_fishing_spot = fishing_spot
	_interaction = interaction
	_bag = bag
	_inventory = inventory
	_hotbar = hotbar
	_inventory_layout = inventory_layout
	_item_catalog = item_catalog
	_cooler_capacity = cooler_capacity
	_art_unlocks = art_unlocks
	_network_shop = network_shop
	_network_sale = network_sale
	_reservations = reservations
	_sell_inventory = ShopSellInventory.new()
	_sell_inventory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shop_cooler_mount.add_child(_sell_inventory)
	_sell_inventory.setup(
		_inventory_layout,
		_bag,
		_inventory,
		_hotbar,
		_item_catalog,
		_buyer,
		_reservations,
		_network_sale,
	)
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
	if not _inventory_layout.backpack_capacity_changed.is_connected(
		_on_backpack_capacity_changed
	):
		_inventory_layout.backpack_capacity_changed.connect(
			_on_backpack_capacity_changed
		)
	if not _art_unlocks.unlocks_changed.is_connected(_on_art_unlocks_changed):
		_art_unlocks.unlocks_changed.connect(_on_art_unlocks_changed)
	_refresh_all()


func set_world_interaction(interaction: ShopInteractionType) -> void:
	_interaction = interaction


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
	_cancel_close_tween()
	_close_generation += 1
	_closing = false
	modulate.a = 1.0
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
	_set_feedback("")
	deactivate_shop_cooler_page()
	if _sell_inventory != null:
		_sell_inventory.clear_staged()
	show()
	_shop_tab_bar.show()
	_controller_zone = ControllerZone.TABS
	_select_shop_section(ShopSection.UPGRADES, false)
	_refresh_all()
	call_deferred("_configure_controller_focus")
	_focus_shop_tab(int(ShopSection.UPGRADES))
	menu_visibility_changed.emit(true)
	return true


func consume_escape() -> bool:
	if not visible:
		return false
	if _closing:
		return true
	if _cooler_page_active:
		if _cooler_modal_open:
			shop_cooler_confirmation_cancel_requested.emit()
		else:
			_select_shop_section(ShopSection.UPGRADES, true)
		return true
	close_shop()
	return true


func get_shop_cooler_mount() -> Control:
	return _shop_cooler_mount


func activate_shop_cooler_page() -> void:
	_cooler_page_active = true
	_shop_panel.show()
	_set_shop_panel_background_pointer_blocking(false)
	_shop_body.hide()
	_feedback.hide()
	_shop_cooler_page.show()


func deactivate_shop_cooler_page() -> void:
	if visible:
		_shop_tab_bar.show()
	_cooler_page_active = false
	_cooler_modal_open = false
	_set_shop_panel_background_pointer_blocking(true)
	for tab: OrganizerTab in _shop_tabs:
		tab.disabled = false
	_shop_cooler_page.hide()
	_shop_panel.show()
	_shop_body.show()
	_feedback.show()


func _set_shop_panel_background_pointer_blocking(blocking: bool) -> void:
	var mouse_filter := (
		Control.MOUSE_FILTER_STOP
		if blocking
		else Control.MOUSE_FILTER_IGNORE
	)
	_shop_panel.mouse_filter = mouse_filter
	_shop_panel_margin.mouse_filter = mouse_filter
	_shop_panel_layout.mouse_filter = mouse_filter


func set_shop_cooler_modal_open(is_open: bool) -> void:
	_cooler_modal_open = is_open
	for tab: OrganizerTab in _shop_tabs:
		tab.disabled = is_open


func close_shop(
	reason: CloseReason = CloseReason.USER,
	restore_controls: bool = true,
) -> void:
	if not visible:
		return
	if _closing:
		if reason in [
			CloseReason.WATER_RECOVERY,
			CloseReason.SESSION_END,
			CloseReason.TEARDOWN,
		]:
			_finish_close(reason, restore_controls, _close_generation)
		return
	_closing = true
	_transaction_in_progress = false
	var current_viewport: Viewport = get_viewport()
	if current_viewport != null:
		current_viewport.gui_release_focus()
	menu_exit_started.emit()
	_close_generation += 1
	var generation: int = _close_generation
	if reason in [CloseReason.USER, CloseReason.RANGE_EXIT]:
		_close_tween = create_tween()
		_close_tween.tween_property(
			self,
			"modulate:a",
			0.0,
			UIMotionType.PLAYER_MENU_EXIT_DURATION,
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_close_tween.finished.connect(
			_finish_close.bind(reason, restore_controls, generation)
		)
		return
	_finish_close(reason, restore_controls, generation)


func _finish_close(
	reason: CloseReason,
	restore_controls: bool,
	generation: int,
) -> void:
	if generation != _close_generation or not visible:
		return
	_cancel_close_tween()
	hide()
	modulate.a = 1.0
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


func _cancel_close_tween() -> void:
	if _close_tween == null:
		return
	_close_tween.kill()
	_close_tween = null


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
	_refresh_backpack_capacity()


func _refresh_wallet() -> void:
	_wallet_label.text = (
		str(_wallet.get_balance())
		if _wallet != null
		else "0"
	)


func _refresh_upgrades() -> void:
	if _upgrades == null:
		return
	var reel_level: int = _upgrades.get_reel_speed_level()
	var reel_cost: int = _upgrades.get_next_reel_speed_cost()
	_reel_purchase.disabled = (
		reel_cost < 0
		or _transaction_in_progress
		or _closing
		or _network_shop == null
		or not _network_shop.can_request_purchase()
		or not _upgrades.can_purchase_reel_speed(_wallet)
	)
	var reel_effect: String
	if reel_cost < 0:
		reel_effect = "%.2f× reel speed · maximum level" % (
			_upgrades.get_reel_speed_multiplier()
		)
		_reel_price_bubble.hide()
	else:
		_reel_price_bubble.show()
		reel_effect = (
			"%.2f× → %.2f×"
			% [
				_upgrades.get_reel_speed_multiplier(),
				1.0 + float(reel_level + 1) * 0.10,
			]
		)
		_reel_cost.set_amount(reel_cost)
	_reel_purchase.tooltip_text = _upgrade_tooltip(
		"reel speed",
		reel_level,
		reel_effect,
	)
	_reel_purchase.accessibility_name = _reel_purchase.tooltip_text
	var barrier_level: int = _upgrades.get_barrier_power_level()
	var barrier_cost: int = _upgrades.get_next_barrier_power_cost()
	_barrier_purchase.disabled = (
		barrier_cost < 0
		or _transaction_in_progress
		or _closing
		or _network_shop == null
		or not _network_shop.can_request_purchase()
		or not _upgrades.can_purchase_barrier_power(_wallet)
	)
	var barrier_effect: String
	if barrier_cost < 0:
		barrier_effect = "%d damage · maximum level" % (
			_upgrades.get_barrier_damage()
		)
		_barrier_price_bubble.hide()
	else:
		_barrier_price_bubble.show()
		barrier_effect = (
			"%d damage → %d damage"
			% [
				_upgrades.get_barrier_damage(),
				PlayerFishingUpgradesType.get_barrier_damage_for_level(
					barrier_level + 1
				),
			]
		)
		_barrier_cost.set_amount(barrier_cost)
	_barrier_purchase.tooltip_text = _upgrade_tooltip(
		"rod power",
		barrier_level,
		barrier_effect,
	)
	_barrier_purchase.accessibility_name = _barrier_purchase.tooltip_text


func _upgrade_tooltip(
	upgrade_name: String,
	level: int,
	effect: String,
) -> String:
	var tooltip := "%s\nlevel %d\n%s" % [upgrade_name, level, effect]
	if _network_shop == null or not _network_shop.can_request_purchase():
		tooltip += "\nPurchases are unavailable in this session."
	return tooltip


func _refresh_supplies() -> void:
	if _supplies_list == null:
		return
	for child: Node in _supplies_list.get_children():
		_supplies_list.remove_child(child)
		child.queue_free()
	if _shop_section in [ShopSection.UPGRADES, ShopSection.SELL_FISH]:
		call_deferred("_configure_controller_focus")
		return
	_stock_title.text = SHOP_SECTION_LABELS[int(_shop_section)]
	var stock_item_ids: Array[StringName] = (
		FishingShopStockType.get_stock_item_ids()
	)
	if _shop_section == ShopSection.BAIT:
		var grouped_item_ids: Array[StringName] = []
		for item_id: StringName in stock_item_ids:
			var bait_item: ItemDataType = _item_catalog.get_item_by_id(item_id)
			if bait_item != null and bait_item.is_bait():
				grouped_item_ids.append(item_id)
		for item_id: StringName in stock_item_ids:
			var lure_item: ItemDataType = _item_catalog.get_item_by_id(item_id)
			if lure_item != null and lure_item.is_lure():
				grouped_item_ids.append(item_id)
		stock_item_ids = grouped_item_ids
	var current_stock_group: StringName = StringName()
	var current_stock_grid: GridContainer
	if _shop_section == ShopSection.SNACKS:
		current_stock_grid = _add_stock_icon_grid()
	elif _shop_section == ShopSection.EQUIPMENT:
		_add_stock_section("rods")
		_add_rod_carousel()
		_add_stock_section("equipment")
		current_stock_grid = _add_stock_icon_grid()
	for item_id: StringName in stock_item_ids:
		var item: ItemDataType = _item_catalog.get_item_by_id(item_id)
		if item == null or not _item_belongs_in_current_section(item):
			continue
		if _shop_section == ShopSection.BAIT:
			var stock_group: StringName = (
				&"bait" if item.is_bait() else &"lures"
			)
			if stock_group != current_stock_group:
				_add_stock_section(str(stock_group))
				current_stock_grid = _add_stock_icon_grid()
				current_stock_group = stock_group
		var button := Button.new()
		button.name = "Supply_%s" % str(item_id)
		button.set_meta(&"item_id", item_id)
		button.custom_minimum_size = Vector2(195, 54)
		button.icon = item.icon if item.icon != null else FALLBACK_SUPPLY_ICON
		button.expand_icon = true
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var owned: int = _bag.get_quantity(item_id)
		var bait_topoff: bool = FishingShopStockType.is_bait_topoff(item_id)
		var permanent_unlock: bool = (
			FishingShopStockType.is_permanent_unlock(item_id, item)
		)
		var unlock_status: String = _unlock_status(owned > 0)
		var bait_unlocked: bool = (
			not bait_topoff or _bag.is_bait_unlocked(item_id)
		)
		var quantity: int = FishingShopStockType.get_purchase_quantity(
			item_id, owned, item.max_stack
		)
		var total_cost: int = FishingShopStockType.get_purchase_cost(
			item_id, quantity, bait_unlocked
		)
		var use_icon_tile: bool = (
			current_stock_grid != null
		)
		button.text = (
			"%s\n%s" % [item.display_name, unlock_status]
			if permanent_unlock
			else "%s\nowned %d" % [item.display_name, owned]
		)
		var item_tooltip_text: String = item.description
		if bait_topoff:
			var unit_price: int = FishingShopStockType.get_price(item_id)
			var unit_price_description: String = (
				"%d fish coin%s per bait piece"
				% [unit_price, "" if unit_price == 1 else "s"]
			)
			if use_icon_tile:
				button.custom_minimum_size = SUPPLY_ICON_TILE_SIZE
				button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				button.alignment = HORIZONTAL_ALIGNMENT_CENTER
				button.text = ""
			else:
				button.text = (
					"%s\nunlock and fill" % item.display_name
					if not bait_unlocked
					else "%s\n%d/%d owned" % [
						item.display_name,
						owned,
						item.max_stack,
					]
				)
			item_tooltip_text = (
				"%s\nunlock and fill\n%s\n%s" % [
					item.display_name,
					unit_price_description,
					item.description,
				]
				if not bait_unlocked
				else "%s\n%s\n%s" % [
					item.display_name,
					unit_price_description,
					item.description,
				]
			)
		elif use_icon_tile:
			button.custom_minimum_size = SUPPLY_ICON_TILE_SIZE
			button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			button.alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.text = ""
			item_tooltip_text = (
				"%s\n%s\n%s" % [
					item.display_name,
					unlock_status,
					item.description,
				]
				if permanent_unlock
				else "%s\nowned %d\n%s" % [
					item.display_name,
					owned,
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
			else item_tooltip_text
		)
		UtilityPageStyleType.apply_ocean_button(button)
		if permanent_unlock or bait_topoff:
			_add_unlock_state_icon(
				button,
				bait_unlocked if bait_topoff else owned > 0,
				(
					SUPPLY_ICON_TILE_SIZE
					if use_icon_tile
					else button.custom_minimum_size
				),
			)
		if bait_topoff and bait_unlocked:
			UtilityPageStyleType.add_supply_quantity_badge(
				button,
				owned,
				item.max_stack,
				&"SupplyQuantityBadge",
				BAIT_SUPPLY_BADGE_Y,
			)
		button.pressed.connect(_purchase_supply.bind(item_id))
		if current_stock_grid != null:
			_add_supply_icon_tile(
				current_stock_grid,
				button,
				(
					maxi(total_cost, 0)
					if bait_topoff
					else FishingShopStockType.get_price(item_id)
				),
			)
		else:
			_supplies_list.add_child(button)
	if _shop_section == ShopSection.ART_SUPPLIES:
		_add_stock_section("art kit")
		var art_kit_grid := _add_stock_icon_grid()
		_add_art_kit_button(art_kit_grid)
		_add_stock_section("markers")
		var marker_grid := _add_stock_icon_grid()
		for product_id: StringName in ArtShopStockType.MARKER_PRODUCTS:
			_add_art_upgrade_button(product_id, marker_grid)
		_add_stock_section("brushes")
		var brush_grid := _add_stock_icon_grid()
		for product_id: StringName in ArtShopStockType.BRUSH_PRODUCTS:
			_add_art_upgrade_button(product_id, brush_grid)
		_add_stock_section("grids")
		var canvas_grid := _add_stock_icon_grid()
		for product_id: StringName in ArtShopStockType.GRID_PRODUCTS:
			_add_art_upgrade_button(product_id, canvas_grid)
	call_deferred("_configure_controller_focus")


func _item_belongs_in_current_section(item: ItemDataType) -> bool:
	if not item.is_available():
		return false
	match _shop_section:
		ShopSection.BAIT:
			return item.is_bait() or item.is_lure()
		ShopSection.SNACKS:
			return item.category == ItemDataType.Category.CONSUMABLE
		ShopSection.EQUIPMENT:
			return item.category == ItemDataType.Category.TOOL
	return false


func _unlock_status(unlocked: bool) -> String:
	return "unlocked" if unlocked else "locked"


func _add_stock_section(title: String) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override(
		"font_color", UtilityPageStyleType.OCEAN_TEXT_SECONDARY
	)
	_supplies_list.add_child(label)


func _add_stock_icon_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = SUPPLY_ICON_GRID_COLUMNS
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override(
		"h_separation", SHOP_SLOT_SEPARATION
	)
	grid.add_theme_constant_override(
		"v_separation", SHOP_SLOT_SEPARATION
	)
	_supplies_list.add_child(grid)
	return grid


func _add_rod_carousel() -> void:
	var shell := HBoxContainer.new()
	shell.name = "RodCarousel"
	shell.custom_minimum_size.y = ROD_CAROUSEL_HEIGHT
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.alignment = BoxContainer.ALIGNMENT_CENTER
	shell.add_theme_constant_override("separation", 8)
	_supplies_list.add_child(shell)
	var previous := Button.new()
	previous.name = "PreviousRod"
	previous.text = "‹"
	previous.tooltip_text = "Previous rods"
	previous.custom_minimum_size = Vector2(42.0, 72.0)
	previous.focus_mode = Control.FOCUS_ALL
	UtilityPageStyleType.apply_ocean_button(previous)
	shell.add_child(previous)
	var scroll := ScrollContainer.new()
	scroll.name = "RodScroll"
	scroll.custom_minimum_size.y = ROD_CAROUSEL_HEIGHT
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	shell.add_child(scroll)
	var row := HBoxContainer.new()
	row.name = "RodCards"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override(
		"separation", ROD_CAROUSEL_SEPARATION
	)
	scroll.add_child(row)
	var rods: Array[FishingRodDataType] = (
		FishingShopStockType.get_rod_stock(_item_catalog)
	)
	for rod: FishingRodDataType in rods:
		_add_rod_card(row, rod)
	var next := Button.new()
	next.name = "NextRod"
	next.text = "›"
	next.tooltip_text = "Next rods"
	next.custom_minimum_size = Vector2(42.0, 72.0)
	next.focus_mode = Control.FOCUS_ALL
	UtilityPageStyleType.apply_ocean_button(next)
	shell.add_child(next)
	previous.disabled = rods.size() <= 1
	next.disabled = rods.size() <= 1
	previous.pressed.connect(
		_scroll_rod_carousel.bind(scroll, -ROD_CAROUSEL_STEP)
	)
	next.pressed.connect(
		_scroll_rod_carousel.bind(scroll, ROD_CAROUSEL_STEP)
	)


func _add_rod_card(parent: HBoxContainer, rod: FishingRodDataType) -> void:
	var owned: bool = _bag.owns_item(rod.item_id)
	var level: int = _player.experience.get_level()
	var level_locked: bool = level < rod.unlock_level
	var tooltip := "%s\n%s" % [rod.display_name, rod.description]
	if not rod.effect_summary.strip_edges().is_empty():
		tooltip += "\n%s" % rod.effect_summary
	if not rod.tradeoff.strip_edges().is_empty():
		tooltip += "\ntradeoff: %s" % rod.tradeoff
	tooltip += "\nlevel %d" % rod.unlock_level
	tooltip += "\n%s" % _unlock_status(owned)
	var button := _make_stock_button("", tooltip)
	button.name = "Rod_%s" % str(rod.item_id)
	button.custom_minimum_size = ROD_CARD_TILE_SIZE
	button.size = ROD_CARD_TILE_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.icon = rod.icon
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add_unlock_state_icon(
		button, owned, ROD_CARD_TILE_SIZE, ROD_PRICE_Y
	)
	button.disabled = (
		owned
		or level_locked
		or _transaction_in_progress
		or _closing
		or _network_shop == null
		or not _network_shop.can_request_purchase()
		or not _wallet.can_afford(rod.shop_price)
		or not _bag.can_add_item(rod.item_id, 1)
	)
	button.pressed.connect(_purchase_rod.bind(rod.item_id))
	var host: Control = _add_supply_icon_tile(
		parent,
		button,
		rod.shop_price,
		ROD_CARD_TILE_SIZE,
		ROD_CARD_HOST_SIZE,
		ROD_PRICE_Y,
		ROD_PRICE_HEIGHT,
		ROD_PRICE_FONT_SIZE,
		ROD_PRICE_ICON_SIZE,
	)
	var name_label := Label.new()
	name_label.name = "RodName"
	name_label.position = Vector2(0.0, 162.0)
	name_label.size = Vector2(ROD_CARD_HOST_SIZE.x, 30.0)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = rod.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_override("font", UtilityPageStyleType.TuffyFont)
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override(
		"font_color", UtilityPageStyleType.OCEAN_TEXT_PRIMARY
	)
	host.add_child(name_label)


func _scroll_rod_carousel(scroll: ScrollContainer, amount: float) -> void:
	var target: float = clampf(
		float(scroll.scroll_horizontal) + amount,
		0.0,
		maxf(
			scroll.get_h_scroll_bar().max_value
			- scroll.get_h_scroll_bar().page,
			0.0,
		),
	)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(value: float) -> void:
			scroll.scroll_horizontal = roundi(value),
		float(scroll.scroll_horizontal),
		target,
		0.15,
	)


func _add_art_kit_button(parent: GridContainer) -> void:
	var item: ItemDataType = _item_catalog.get_item_by_id(
		ArtShopStockType.ART_KIT_ITEM_ID
	)
	if item == null or not item.is_available():
		return
	var owned: bool = _bag.get_quantity(ArtShopStockType.ART_KIT_ITEM_ID) > 0
	var button: Button = _make_stock_button(
		"%s\n%s" % [
			item.display_name,
			_unlock_status(owned),
		],
		"%s\n%s\n%s" % [
			item.display_name,
			_unlock_status(owned),
			item.description,
		],
	)
	_configure_supply_icon_tile(button, item.icon)
	_add_unlock_state_icon(button, owned, SUPPLY_ICON_TILE_SIZE)
	_add_supply_icon_tile(
		parent,
		button,
		ArtShopStockType.ART_KIT_PRICE,
	)
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


func _add_art_upgrade_button(
	product_id: StringName,
	parent: GridContainer,
) -> void:
	var kit_owned: bool = (
		_bag.get_quantity(ArtShopStockType.ART_KIT_ITEM_ID) > 0
	)
	var unlocked: bool = _art_unlocks.owns_product(product_id)
	var button: Button = _make_stock_button(
		"%s\n%s" % [
			ArtShopStockType.get_display_name(product_id),
			"unlocked" if unlocked else "locked",
		],
		"%s\n%s\n%s" % [
			ArtShopStockType.get_display_name(product_id),
			"unlocked" if unlocked else "locked",
			ArtShopStockType.get_description(product_id),
		],
	)
	button.accessibility_name = ArtShopStockType.get_display_name(product_id)
	button.set_meta(&"art_product_id", product_id)
	var marker_color_id: StringName = (
		PlayerArtUnlocksType.color_id_for_product(product_id)
	)
	if marker_color_id.is_empty():
		var upgrade_icon: Texture2D = ART_UPGRADE_ICONS.get(
			product_id,
			FALLBACK_SUPPLY_ICON,
		)
		_configure_supply_icon_tile(button, upgrade_icon)
	else:
		_configure_marker_icon_tile(
			button,
			SurfaceDrawingPalette.get_color(marker_color_id),
		)
	_add_unlock_state_icon(button, unlocked, SUPPLY_ICON_TILE_SIZE)
	_add_supply_icon_tile(
		parent,
		button,
		ArtShopStockType.UPGRADE_PRICE,
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


func _make_stock_button(
	button_text: String,
	tooltip: String,
) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(195, 54)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.text = button_text
	button.tooltip_text = tooltip
	UtilityPageStyleType.apply_ocean_button(button)
	return button


func _configure_supply_icon_tile(
	button: Button,
	icon: Texture2D,
) -> void:
	button.custom_minimum_size = SUPPLY_ICON_TILE_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.icon = icon if icon != null else FALLBACK_SUPPLY_ICON
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.text = ""


func _configure_marker_icon_tile(
	button: Button,
	marker_color: Color,
) -> void:
	button.custom_minimum_size = SUPPLY_ICON_TILE_SIZE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.icon = null
	button.text = ""
	var icon := TextureRect.new()
	icon.name = "MarkerIcon"
	icon.position = Vector2(4.0, 4.0)
	icon.size = Vector2(64.0, 64.0)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var marker_material := ShaderMaterial.new()
	marker_material.shader = ART_KIT_MARKER_SHADER
	marker_material.set_shader_parameter("marker_color", marker_color)
	icon.material = marker_material
	icon.texture = ART_KIT_MARKER_ICON
	button.add_child(icon)


func _add_unlock_state_icon(
	button: Button,
	unlocked: bool,
	_tile_size: Vector2,
	_price_bubble_y: float = SUPPLY_PRICE_Y,
) -> void:
	if unlocked:
		return
	var badge := Panel.new()
	badge.name = "UnlockStateBadge"
	badge.position = LOCK_BADGE_MARGIN
	badge.size = LOCK_BADGE_SIZE
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.z_index = 3
	var badge_style := UtilityPageStyleType.rounded_style(
		Color(UtilityPageStyleType.OCEAN_FIELD, LOCK_BADGE_ALPHA),
		int(LOCK_BADGE_SIZE.x * 0.5),
	)
	badge.add_theme_stylebox_override("panel", badge_style)
	button.add_child(badge)
	var icon := TextureRect.new()
	icon.name = "UnlockStateIcon"
	icon.texture = LockedContentPresentationType.ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta(&"unlocked", false)
	icon.size = LOCK_BADGE_ICON_SIZE
	icon.position = Vector2(
		(LOCK_BADGE_SIZE.x - LOCK_BADGE_ICON_SIZE.x) * 0.5,
		(LOCK_BADGE_SIZE.y - LOCK_BADGE_ICON_SIZE.y) * 0.5,
	)
	icon.modulate = Color(
		UtilityPageStyleType.OCEAN_TEXT_PRIMARY,
		LOCK_BADGE_ICON_ALPHA,
	)
	badge.add_child(icon)


func _add_supply_icon_tile(
	parent: Container,
	button: Button,
	price: int,
	tile_size: Vector2 = SUPPLY_ICON_TILE_SIZE,
	host_size: Vector2 = SUPPLY_ICON_HOST_SIZE,
	price_y: float = SUPPLY_PRICE_Y,
	price_height: float = SUPPLY_PRICE_HEIGHT,
	price_font_size: int = SUPPLY_PRICE_FONT_SIZE,
	price_icon_size: float = SUPPLY_PRICE_ICON_SIZE,
) -> Control:
	var tile_host := Control.new()
	tile_host.custom_minimum_size = host_size
	tile_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tile_host)
	button.position = Vector2.ZERO
	button.size = tile_size
	tile_host.add_child(button)
	var price_text := str(price)
	var price_text_width: float = UtilityPageStyleType.TuffyFont.get_string_size(
		price_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		price_font_size,
	).x
	var price_width: float = minf(
		tile_size.x,
		ceilf(
			price_text_width
			+ price_icon_size
			+ SUPPLY_PRICE_ICON_GAP
			+ SUPPLY_PRICE_HORIZONTAL_PADDING
		),
	)
	var price_bubble := PanelContainer.new()
	price_bubble.name = "PriceBubble"
	price_bubble.position = Vector2(
		(tile_size.x - price_width) * 0.5,
		price_y,
	)
	price_bubble.size = Vector2(price_width, price_height)
	price_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_bubble.z_index = 2
	var price_style := UtilityPageStyleType.rounded_style(
		UtilityPageStyleType.OCEAN_FIELD,
		12,
	)
	price_style.content_margin_left = 6.0
	price_style.content_margin_right = 6.0
	price_style.content_margin_top = 0.0
	price_style.content_margin_bottom = 0.0
	price_bubble.add_theme_stylebox_override("panel", price_style)
	tile_host.add_child(price_bubble)
	var price_row := HBoxContainer.new()
	price_row.name = "CurrencyAmount"
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override(
		"separation", int(SUPPLY_PRICE_ICON_GAP)
	)
	price_bubble.add_child(price_row)
	var price_icon := TextureRect.new()
	price_icon.name = "CurrencyIcon"
	price_icon.custom_minimum_size = Vector2.ONE * price_icon_size
	price_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_icon.texture = CURRENCY_ICON
	price_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	price_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	price_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	price_row.add_child(price_icon)
	var price_label := Label.new()
	price_label.name = "Price"
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_label.text = price_text
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_label.add_theme_font_override(
		"font", UtilityPageStyleType.TuffyFont
	)
	price_label.add_theme_font_size_override(
		"font_size", price_font_size
	)
	price_label.add_theme_color_override(
		"font_color", SUPPLY_PRICE_COLOR
	)
	price_label.add_theme_constant_override("outline_size", 0)
	price_row.add_child(price_label)
	return tile_host


func _refresh_cooler_capacity() -> void:
	if _cooler_capacity == null:
		return
	var level: int = _cooler_capacity.get_level()
	var cost: int = _cooler_capacity.get_next_cost()
	var next_capacity: int = _cooler_capacity.get_next_capacity()
	_cooler_purchase.disabled = (
		cost < 0
		or _transaction_in_progress
		or _closing
		or _network_shop == null
		or not _network_shop.can_request_purchase()
		or not _cooler_capacity.can_purchase(_wallet)
	)
	var cooler_effect: String
	if cost < 0:
		cooler_effect = "%d slots · maximum level" % (
			_cooler_capacity.get_capacity()
		)
		_cooler_price_bubble.hide()
	else:
		_cooler_price_bubble.show()
		cooler_effect = "%d → %d slots" % [
			_cooler_capacity.get_capacity(),
			next_capacity,
		]
		_cooler_cost.set_amount(cost)
	_cooler_purchase.tooltip_text = _upgrade_tooltip(
		"storage capacity",
		level,
		cooler_effect,
	)
	_cooler_purchase.accessibility_name = _cooler_purchase.tooltip_text


func _refresh_backpack_capacity() -> void:
	if _inventory_layout == null:
		return
	var level := _inventory_layout.get_backpack_level()
	var cost := _inventory_layout.get_next_backpack_cost()
	var next_capacity := _inventory_layout.get_next_inventory_capacity()
	_backpack_purchase.disabled = (
		cost < 0
		or _transaction_in_progress
		or _closing
		or _network_shop == null
		or not _network_shop.can_request_backpack_purchase()
		or not _inventory_layout.can_purchase_backpack(_wallet)
	)
	var effect: String
	if cost < 0:
		effect = "%d slots · maximum level" % (
			_inventory_layout.get_inventory_capacity()
		)
		_backpack_price_bubble.hide()
	else:
		_backpack_price_bubble.show()
		effect = "%d → %d slots" % [
			_inventory_layout.get_inventory_capacity(),
			next_capacity,
		]
		_backpack_cost.set_amount(cost)
	_backpack_purchase.tooltip_text = _upgrade_tooltip(
		"backpack capacity",
		level,
		effect,
	)
	_backpack_purchase.accessibility_name = _backpack_purchase.tooltip_text


func _purchase_reel_speed() -> void:
	_purchase_upgrade(true)


func _purchase_barrier_power() -> void:
	_purchase_upgrade(false)


func _purchase_supply(item_id: StringName) -> void:
	if _transaction_in_progress or not _is_transaction_context_valid():
		_set_feedback("unable to complete purchase.")
		return
	var owned: int = _bag.get_quantity(item_id)
	var item: ItemDataType = _item_catalog.get_item_by_id(item_id)
	if item == null or not item.is_available():
		_set_feedback("Purchase could not be completed.")
		return
	var quantity: int = FishingShopStockType.get_purchase_quantity(
		item_id, owned, item.max_stack
	)
	if quantity <= 0 or not _bag.can_add_item(item_id, quantity):
		_set_feedback("Your inventory is full.")
		return
	var total_cost: int = FishingShopStockType.get_purchase_cost(
		item_id, quantity, _bag.is_bait_unlocked(item_id)
	)
	if total_cost < 0 or not _wallet.can_afford(total_cost):
		_set_feedback("Insufficient funds.")
		return
	if _network_shop == null:
		_set_feedback("Purchase could not be completed.")
		return
	_network_shop.request_supply(item_id)


func _purchase_rod(item_id: StringName) -> void:
	if _network_shop == null or not _is_transaction_context_valid():
		_set_feedback("Purchase could not be completed.")
		return
	var rod := _item_catalog.get_item_by_id(item_id) as FishingRodDataType
	if (
		rod == null
		or not rod.is_shop_available()
		or _bag.owns_item(item_id)
		or not _wallet.can_afford(rod.shop_price)
		or not _bag.can_add_item(item_id, 1)
	):
		_set_feedback("Purchase could not be completed.")
		return
	_network_shop.request_rod(item_id)


func _purchase_art_kit() -> void:
	if _network_shop == null or not _is_transaction_context_valid():
		_set_feedback("Purchase could not be completed.")
		return
	_network_shop.request_art_kit()


func _purchase_art_upgrade(product_id: StringName) -> void:
	if _network_shop == null or not _is_transaction_context_valid():
		_set_feedback("Purchase could not be completed.")
		return
	_network_shop.request_art_upgrade(product_id)


func _purchase_cooler_capacity() -> void:
	if _transaction_in_progress or not _is_transaction_context_valid():
		_set_feedback("unable to complete purchase.")
		return
	var cost: int = _cooler_capacity.get_next_cost()
	if cost < 0:
		_set_feedback("Upgrade is already at maximum.")
		return
	if not _wallet.can_afford(cost):
		_set_feedback("Insufficient funds.")
		return
	if _network_shop == null:
		_set_feedback("Purchase could not be completed.")
		return
	_network_shop.request_cooler_capacity_upgrade()


func _purchase_backpack_capacity() -> void:
	if _transaction_in_progress or not _is_transaction_context_valid():
		_set_feedback("unable to complete purchase.")
		return
	var cost := _inventory_layout.get_next_backpack_cost()
	if cost < 0:
		_set_feedback("Upgrade is already at maximum.")
		return
	if not _wallet.can_afford(cost):
		_set_feedback("Insufficient funds.")
		return
	if _network_shop == null:
		_set_feedback("Purchase could not be completed.")
		return
	_network_shop.request_backpack_capacity_upgrade()


func _purchase_upgrade(is_reel_speed: bool) -> void:
	if _transaction_in_progress or not _is_transaction_context_valid():
		_set_feedback("unable to complete purchase.")
		return
	var cost: int = (
		_upgrades.get_next_reel_speed_cost()
		if is_reel_speed
		else _upgrades.get_next_barrier_power_cost()
	)
	if cost < 0:
		_set_feedback("Upgrade is already at maximum.")
		return
	if not _wallet.can_afford(cost):
		_set_feedback("Insufficient funds.")
		return
	if _network_shop == null:
		_set_feedback("Purchase could not be completed.")
		return
	if is_reel_speed:
		_network_shop.request_reel_speed_upgrade()
	else:
		_network_shop.request_barrier_power_upgrade()


func _on_network_purchase_pending(_request_id: String) -> void:
	_transaction_in_progress = true
	if visible:
		_set_feedback("Purchasing…")
		_refresh_all()


func _on_network_purchase_finished(
	_request_id: String,
	accepted: bool,
	message: String,
	product_id: StringName,
	category: int,
	quantity: int,
	total_cost: int,
) -> void:
	_transaction_in_progress = false
	if not visible:
		return
	_set_feedback(
		_purchase_success_feedback(
			product_id,
			category,
			quantity,
			total_cost,
		)
		if accepted
		else message
	)
	_refresh_all()


func _purchase_success_feedback(
	product_id: StringName,
	category: int,
	quantity: int,
	total_cost: int,
) -> String:
	if (
		category == NetworkShopProtocol.ProductCategory.SUPPLY
		and FishingShopStockType.is_bait_topoff(product_id)
	):
		var item: ItemDataType = _item_catalog.get_item_by_id(product_id)
		var item_name: String = (
			item.display_name if item != null else str(product_id).capitalize()
		)
		return "Bait Restocked\n%s spent on %d %s" % [
			CurrencyPresentation.bbcode_amount(total_cost, 18),
			quantity,
			item_name,
		]
	return (
		"Purchase complete • %s spent."
		% CurrencyPresentation.bbcode_amount(total_cost, 18)
	)


func _set_feedback(message: String) -> void:
	_feedback.text = "[center]%s[/center]" % message


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
	_refresh_backpack_capacity()


func _on_upgrades_changed(
	_reel_speed_level: int,
	_barrier_power_level: int,
) -> void:
	_refresh_upgrades()


func _on_bag_changed() -> void:
	_refresh_supplies()


func _on_cooler_capacity_changed(_level: int, _capacity: int) -> void:
	_refresh_cooler_capacity()


func _on_backpack_capacity_changed(_level: int, _capacity: int) -> void:
	_refresh_backpack_capacity()


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
