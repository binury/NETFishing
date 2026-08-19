class_name PlayerMenu
extends Control

const INPUT_OWNER: StringName = &"player_menu"
const CollectionLogType = preload("res://collection/collection_log.gd")
const FishCatchType = preload("res://fish/fish_catch.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishQualityType = preload("res://fish/fish_quality.gd")
const FishBuyerProfileType = preload("res://economy/fish_buyer_profile.gd")
const FishSaleResultType = preload("res://economy/fish_sale_result.gd")
const FishSaleServiceType = preload("res://economy/fish_sale_service.gd")
const FishingShopStockType = preload(
	"res://economy/fishing_shop_stock.gd"
)
const NetworkSessionType = preload("res://network/network_session.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const InventoryNotepadType = preload(
	"res://ui/components/inventory_notepad.gd"
)
const CurrencyPresentationType = preload(
	"res://ui/currency_presentation.gd"
)
const OrganizerTabType = preload("res://ui/components/organizer_tab.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const PlayerType = preload("res://player/player.gd")
const PlayerWalletType = preload("res://economy/player_wallet.gd")
const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
const OwnedItemType = preload("res://items/owned_item.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const PlayerHotbarType = preload("res://inventory/player_hotbar.gd")
const PlayerCoolerCapacityType = preload(
	"res://progression/player_cooler_capacity.gd"
)
const PlayerExperienceType = preload(
	"res://progression/player_experience.gd"
)
const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const ControllerFocusNavigationType = preload(
	"res://ui/controller_focus_navigation.gd"
)
const FishBatchSelectionType = preload(
	"res://ui/fish_batch_selection.gd"
)
const BubbleButtonType = preload(
	"res://ui/components/bubble_menu/bubble_button.gd"
)
const BubbleClusterType = preload(
	"res://ui/components/bubble_menu/bubble_cluster.gd"
)
const NotepadInkActionType = preload(
	"res://ui/components/bubble_menu/notepad_ink_action.gd"
)
const NotepadInkChoiceType = preload(
	"res://ui/components/bubble_menu/notepad_ink_choice.gd"
)
const CoolerFishSpriteType = preload(
	"res://ui/components/bubble_menu/cooler_fish_sprite.gd"
)
const CoolerFishSpriteScene = preload(
	"res://ui/components/bubble_menu/cooler_fish_sprite.tscn"
)
const BagItemSpriteType = preload(
	"res://ui/components/bubble_menu/bag_item_sprite.gd"
)
const BagItemSpriteScene = preload(
	"res://ui/components/bubble_menu/bag_item_sprite.tscn"
)
const BagStorageSlotType = preload(
	"res://ui/components/bubble_menu/bag_storage_slot.gd"
)
const GeneralInventoryGridType = preload(
	"res://ui/components/general_inventory_grid.gd"
)
const GeneralInventorySlotType = preload(
	"res://ui/components/general_inventory_slot.gd"
)
const DESKTOP_REFERENCE_SIZE := Vector2(1280.0, 720.0)
const NAVIGATION_PRESENTATION_SCALE: float = 0.60
const NAVIGATION_REFERENCE_SIZE := Vector2(840.0, 100.0)
const NAVIGATION_CANONICAL_POSITION := Vector2(
	(DESKTOP_REFERENCE_SIZE.x
	- NAVIGATION_REFERENCE_SIZE.x * NAVIGATION_PRESENTATION_SCALE) * 0.5,
	44.0,
)
const NAVIGATION_SELECTED_SCALE: float = 1.02
const MAIN_SHOP_BUYER_ID: StringName = &"main_fishing_shop"
const PELICAN_BUYER_ID: StringName = &"pelicans"

signal menu_visibility_changed(is_open: bool)
signal inventory_hotbar_context_changed(show_hotbar: bool)
signal controller_hotbar_placement_requested(
	assignment_kind: PlayerHotbarType.AssignmentKind,
	identity: StringName,
	initial_slot: int,
)
signal controller_hotbar_placement_ended
signal controller_hotbar_management_requested(initial_slot: int)
signal controller_hotbar_management_ended
signal menu_exit_started
signal shop_cooler_modal_changed(is_open: bool)

enum Section {
	COOLER,
	BAG,
	TACKLE_BOX,
	LOGBOOK,
	NET,
	MAIL,
	PROFILE,
	PLAYERS,
}

enum BagView {
	EQUIPMENT,
	CONSUMABLES,
}

enum SortMode {
	CATCH_ORDER,
	NAME,
	RARITY,
}

enum CloseReason {
	USER,
	BITE_STARTED,
	WATER_RECOVERY,
	GAME_MENU,
	SESSION_END,
	TEARDOWN,
}

enum ControllerOwnership {
	INVENTORY_TABS,
	ITEM_LIST,
	NOTEPAD_ACTIONS,
	SORT_FILTER,
	HOTBAR_MANAGEMENT,
	HOTBAR_PLACEMENT,
	STORAGE_PLACEMENT,
	PAGE_CONTENT,
}

const COOLER_MAIN_POSITION := Vector2(54.0, 166.0)
const COOLER_MAIN_SIZE := Vector2(882.0, 484.0)
const COOLER_NOTEPAD_POSITION := Vector2(952.0, 166.0)
const INVENTORY_MAIN_SIZE := Vector2(882.0, 484.0)
const INVENTORY_MAIN_POSITION := Vector2(
	(DESKTOP_REFERENCE_SIZE.x - INVENTORY_MAIN_SIZE.x) * 0.5,
	166.0,
)
const INVENTORY_NOTEPAD_SIZE := Vector2(278.0, 484.0)
const INVENTORY_NOTEPAD_POSITION := Vector2(
	INVENTORY_MAIN_POSITION.x
	+ (INVENTORY_MAIN_SIZE.x - INVENTORY_NOTEPAD_SIZE.x) * 0.5,
	INVENTORY_MAIN_POSITION.y,
)
const INVENTORY_MAIN_CORNER_RADIUS: int = 58
const INVENTORY_INNER_CORNER_RADIUS: int = 45
const TACKLE_GRID_COLUMNS: int = 4
const INVENTORY_VISIBLE_TAB_WIDTH: float = 124.0 * 2.0 + 6.0
const BAG_STORAGE_COLUMNS: int = PlayerInventoryLayout.INVENTORY_COLUMNS
const BAG_STORAGE_MINIMUM_SLOTS: int = 15
const SALE_CONFIRMATION_SIZE := Vector2(520.0, 190.0)
const CONTROLLER_PICKUP_HOLD_SECONDS: float = 0.42
const LIGHT_COOLER_WATER_COLOR := Color(0.037, 0.27, 0.375, 1.0)

@onready var _navigation_cluster: BubbleClusterType = %NavigationCluster
@onready var _presentation_scale_root: Control = %PlayerMenuPresentationScaleRoot
@onready var _cooler_page: Control = %CoolerPage
@onready var _cooler_outer_wall: PanelContainer = %CoolerOuterWall
@onready var _cooler_inner_liner: PanelContainer = %CoolerInnerLiner
@onready var _cooler_water_surface: ColorRect = %WaterSurface
@onready var _fish_field: Control = %FishField
@onready var _cooler_sort_controls: HBoxContainer = %CoolerSortControls
@onready var _cooler_sort_option: NotepadInkChoiceType = %CoolerSortOption
@onready var _cooler_sort_direction: NotepadInkActionType = %CoolerSortDirection
@onready var _detail_constellation: Control = %DetailConstellation
@onready var _detail_bubble: Control = %DetailBubble
@onready var _notepad_binding: Label = %BindingDecoration
@onready var _notepad_title: Label = %NotepadTitle
@onready var _notepad_rule: ColorRect = %NotepadRule
@onready var _notepad_wallet_value: CurrencyAmount = %NotepadWalletValue
@onready var _notepad_capacity_value: Label = %NotepadCapacityValue
@onready var _cooler_detail_texture: TextureRect = %CoolerDetailTexture
@onready var _cooler_detail_name: Label = %CoolerDetailName
@onready var _cooler_detail_stats: Control = %CoolerDetailStats
@onready var _cooler_quality_label: Label = %CoolerQualityLabel
@onready var _cooler_rarity_label: Label = %CoolerRarityLabel
@onready var _cooler_weight_row: HBoxContainer = %CoolerWeightRow
@onready var _cooler_weight_value: Label = %CoolerWeightValue
@onready var _cooler_weight_unit: Label = %CoolerWeightUnit
@onready var _cooler_offer_value: CurrencyAmount = %CoolerOfferValue
@onready var _cooler_selection_summary: Control = %CoolerSelectionSummary
@onready var _cooler_selection_empty: Label = %CoolerSelectionEmpty
@onready var _cooler_selected_count_row: HBoxContainer = %CoolerSelectedCountRow
@onready var _cooler_selected_count_value: Label = %CoolerSelectedCountValue
@onready var _cooler_selected_count_label: Label = %CoolerSelectedCountLabel
@onready var _cooler_combined_offer_row: HBoxContainer = %CoolerCombinedOfferRow
@onready var _cooler_combined_offer_label: Label = %CoolerCombinedOfferLabel
@onready var _cooler_combined_offer_value: CurrencyAmount = %CoolerCombinedOfferValue
@onready var _favorite_bubble: NotepadInkActionType = %FavoriteBubble
@onready var _sell_bubble: NotepadInkActionType = %SellBubble
@onready var _bag_page: Control = %BagPage
@onready var _tackle_box_page: Control = %TackleBoxPage
@onready var _inventory_sub_tabs: HBoxContainer = %InventorySubTabs
@onready var _cooler_sub_tab: Button = %CoolerSubTab
@onready var _bag_sub_tab: Button = %BagSubTab
@onready var _items_sub_tab: Button = %ItemsSubTab
@onready var _tackle_sub_tab: Button = %TackleSubTab
@onready var _tackle_main_panel: PanelContainer = %TackleMainPanel
@onready var _tackle_detail_panel: PanelContainer = %TackleDetailPanel
@onready var _bait_heading: Label = %BaitHeading
@onready var _lure_heading: Label = %LureHeading
@onready var _bait_empty: Label = %BaitEmpty
@onready var _lure_empty: Label = %LureEmpty
@onready var _tackle_detail_text: Label = %TackleDetailText
@onready var _tackle_equip_button: NotepadInkActionType = %TackleEquipButton
@onready var _bait_item_list: GridContainer = %BaitItemList
@onready var _lure_item_list: GridContainer = %LureItemList
@onready var _bag_outer_wall: PanelContainer = %BagOuterWall
@onready var _bag_inner_liner: PanelContainer = %BagInnerLiner
@onready var _bag_scroll: ScrollContainer = %BagScroll
@onready var _bag_host: Control = %BagHost
@onready var _bag_item_field: Control = %BagItemField
@onready var _bag_empty_state: Label = %BagEmptyState
@onready var _bag_modal_blocker: Control = %BagModalBlocker
@onready var _bag_detail_constellation: Control = %BagDetailConstellation
@onready var _bag_sprite_detail_texture: TextureRect = %BagSpriteDetailTexture
@onready var _bag_sprite_detail_name: Label = %BagSpriteDetailName
@onready var _bag_sprite_detail_data: Label = %BagSpriteDetailData
@onready var _bag_sprite_detail_value_row: HBoxContainer = %BagSpriteDetailValueRow
@onready var _bag_sprite_detail_weight: Label = %BagSpriteDetailWeight
@onready var _bag_sprite_detail_value: CurrencyAmount = %BagSpriteDetailValue
@onready var _bag_detail_actions: HBoxContainer = %BagDetailActions
@onready var _bag_favorite_button: NotepadInkActionType = %BagFavoriteButton
@onready var _bag_sell_button: NotepadInkActionType = %BagSellButton
@onready var _tackle_modal_blocker: Control = %TackleModalBlocker
@onready var _logbook_page: Control = %LogbookPage
@onready var _catalog_logbook: LogbookPage = %CatalogLogbook
@onready var _the_net_page: TheNetPage = %TheNetPage
@onready var _mail_page: MailPage = %MailPage
@onready var _profile_page: ProfilePage = %ProfilePage
@onready var _players_page: PlayersPage = %PlayersPage
@onready var _inventory_tab: BubbleButtonType = %InventoryTab
@onready var _logbook_tab: BubbleButtonType = %LogbookTab
@onready var _the_net_tab: BubbleButtonType = %TheNetTab
@onready var _mail_tab: BubbleButtonType = %MailTab
@onready var _profile_tab: BubbleButtonType = %ProfileTab
@onready var _players_tab: BubbleButtonType = %PlayersTab
@onready var _mail_unread_badge: Label = %MailUnreadBadge
@onready var _close_button: BubbleButtonType = %CloseButton
@onready var _cooler_scroll: ScrollContainer = %CoolerScroll
@onready var _cooler_host: Control = %CoolerHost
@onready var _sale_confirmation: PanelContainer = %SaleConfirmation
@onready var _confirmation_message: RichTextLabel = %ConfirmationMessage
@onready var _confirm_sale_button: Button = %ConfirmSaleButton
@onready var _cancel_sale_button: Button = %CancelSaleButton

var _compact_layout: bool = false
var _player: PlayerType
var _inventory: FishInventoryType
var _collection_log: CollectionLogType
var _wallet: PlayerWalletType
var _sale_service: FishSaleServiceType
var _network_session: NetworkSessionType
var _network_sale_service: NetworkSaleService
var _network_mail_service: NetworkMailService
var _reservations: PlayerAssetReservationService
var _network_profile_service: NetworkProfileService
var _network_player_list: NetworkPlayerListService
var _controller_mapping_manager: ControllerMappingManagerType
var _default_buyer: FishBuyerProfileType
var _shop_buyer: FishBuyerProfileType
var _sale_buyer_override: FishBuyerProfileType
var _shop_cooler_context_active: bool = false
var _cooler_original_parent: Node
var _cooler_original_index: int = -1
var _authored_cooler_water_material: ShaderMaterial
var _confirmation_original_parent: Node
var _confirmation_original_index: int = -1
var _catalog: FishPoolType
var _fishing_spot: FishingSpotType
var _bag: PlayerBagType
var _hotbar: PlayerHotbarType
var _item_catalog: ItemCatalogType
var _inventory_layout: PlayerInventoryLayout
var _cooler_capacity: PlayerCoolerCapacityType
var _current_section: Section = Section.BAG
var _last_inventory_section: Section = Section.BAG
var _bag_view: BagView = BagView.EQUIPMENT
var _selected_tackle_item_id: StringName
var _tackle_item_buttons: Dictionary[StringName, Button] = {}
var _controller_ownership: ControllerOwnership = (
	ControllerOwnership.INVENTORY_TABS
)
var _controller_source_section: Section = Section.COOLER
var _controller_source_identity: StringName
var _controller_notepad_actions: Array[BaseButton] = []
var _controller_hotbar_assignment_kind: PlayerHotbarType.AssignmentKind = (
	PlayerHotbarType.AssignmentKind.EMPTY
)
var _controller_hotbar_identity: StringName
var _controller_storage_identity: StringName
var _controller_previous_hotbar_slot: int = 0
var _controller_previous_storage_slot: int = 0
var _controller_accept_held: bool = false
var _controller_accept_hold_elapsed: float = 0.0
var _content_interactive_enabled: bool = false
var _sort_mode: SortMode = SortMode.CATCH_ORDER
var _sort_descending: bool = true
var _fish_selection := FishBatchSelectionType.new()
var _selected_bag_item_id: StringName
var _prior_movement_enabled: bool = true
var _prior_camera_input_enabled: bool = true
var _prior_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _control_snapshot_stored: bool = false
var _mouse_snapshot_stored: bool = false
var _menu_generation: int = 0
var _confirmation_catch_ids: Array[StringName] = []
var _confirmation_buyer: FishBuyerProfileType
var _confirmation_buyer_id: StringName
var _confirmation_generation: int = -1
var _sale_in_progress: bool = false
var _presentation_tween: Tween
var _page_tween: Tween
var _transition_generation: int = 0
var _page_transition_generation: int = 0
var _transitioning: bool = false
var _page_transitioning: bool = false
var _cooler_rest_position: Vector2 = Vector2.ZERO
var _bag_rest_position: Vector2 = Vector2.ZERO
var _tackle_rest_position: Vector2 = Vector2.ZERO
var _logbook_rest_position: Vector2 = Vector2.ZERO
var _the_net_rest_position: Vector2 = Vector2.ZERO
var _mail_rest_position: Vector2 = Vector2.ZERO
var _profile_rest_position: Vector2 = Vector2.ZERO
var _page_outgoing_root: Control
var _page_incoming_root: Control
var _page_outgoing_content_root: Control
var _inventory_transition_group: Control
var _fish_nodes: Dictionary[StringName, CoolerFishSpriteType] = {}
var _cooler_slot_nodes: Array[Panel] = []
var _sorted_catches: Array[FishCatchType] = []
var _bag_item_nodes: Dictionary[StringName, BagItemSpriteType] = {}
var _bag_slot_nodes: Array[BagStorageSlotType] = []
var _general_inventory_grid: GeneralInventoryGridType
var _selected_inventory_kind: int = -1
var _selected_inventory_identity: StringName
var _inventory_move_kind: int = -1
var _inventory_move_identity: StringName
var _tackle_move_identity: StringName
var _context_tooltip: PanelContainer
var _context_tooltip_label: Label
var _context_tooltip_source: Control
var _sorted_bag_items: Array[OwnedItemType] = []
var _bag_drag_active: bool = false
var _motion_elapsed: float = 0.0


func _ready() -> void:
	_authored_cooler_water_material = (
		_cooler_water_surface.material as ShaderMaterial
	)
	_configure_inventory_transition_group()
	_cooler_original_parent = _cooler_page.get_parent()
	_cooler_original_index = _cooler_page.get_index()
	_confirmation_original_parent = _sale_confirmation.get_parent()
	_confirmation_original_index = _sale_confirmation.get_index()
	_cooler_sub_tab.visible = false
	_items_sub_tab.visible = false
	_bag_sub_tab.text = "Inventory"
	_general_inventory_grid = GeneralInventoryGridType.new()
	_general_inventory_grid.name = "GeneralInventoryGrid"
	_general_inventory_grid.set_slot_presentation(Vector2(78.0, 78.0), 10)
	_general_inventory_grid.slot_activated.connect(
		_on_general_inventory_slot_activated
	)
	_general_inventory_grid.context_requested.connect(
		_open_general_inventory_notepad
	)
	_general_inventory_grid.context_changed.connect(
		_on_inventory_context_changed
	)
	_bag_item_field.add_child(_general_inventory_grid)
	_create_inventory_context_tooltip()
	_inventory_tab.pressed.connect(_show_last_inventory_section)
	_cooler_sub_tab.pressed.connect(_show_section.bind(Section.COOLER))
	_bag_sub_tab.pressed.connect(_show_bag_view.bind(BagView.EQUIPMENT))
	_items_sub_tab.pressed.connect(_show_bag_view.bind(BagView.CONSUMABLES))
	_tackle_sub_tab.pressed.connect(_show_section.bind(Section.TACKLE_BOX))
	_tackle_equip_button.pressed.connect(_toggle_active_tackle)
	_bag_favorite_button.pressed.connect(_on_bag_favorite_pressed)
	_bag_sell_button.pressed.connect(_on_bag_sell_pressed)
	_bag_detail_constellation.visible = false
	_tackle_detail_panel.visible = false
	_bag_detail_constellation.z_index = 120
	_tackle_detail_panel.z_index = 120
	_bag_modal_blocker.z_index = 110
	_tackle_modal_blocker.z_index = 110
	_logbook_tab.pressed.connect(
		_show_section.bind(Section.LOGBOOK)
	)
	_the_net_tab.pressed.connect(_show_section.bind(Section.NET))
	_mail_tab.pressed.connect(_show_section.bind(Section.MAIL))
	_profile_tab.pressed.connect(_show_section.bind(Section.PROFILE))
	_players_tab.pressed.connect(_show_section.bind(Section.PLAYERS))
	_close_button.pressed.connect(close_menu)
	_cooler_sort_option.item_selected.connect(_on_cooler_sort_selected)
	_cooler_sort_direction.pressed.connect(_on_sort_direction_pressed)
	_favorite_bubble.pressed.connect(_on_favorite_pressed)
	_sell_bubble.pressed.connect(_on_sell_pressed)
	_confirm_sale_button.pressed.connect(_on_confirm_sale_pressed)
	_cancel_sale_button.pressed.connect(_close_sale_confirmation)
	_configure_sale_confirmation_focus()
	_cooler_sort_option.add_item("catch order", SortMode.CATCH_ORDER)
	_cooler_sort_option.add_item("name", SortMode.NAME)
	_cooler_sort_option.add_item("rarity", SortMode.RARITY)
	_cooler_sort_option.select(SortMode.CATCH_ORDER)
	_update_sort_direction_text()
	_navigation_cluster.configure([
		_inventory_tab,
		_logbook_tab,
		_the_net_tab,
		_mail_tab,
		_profile_tab,
		_players_tab,
		_close_button,
	])
	_configure_navigation_focus()
	_apply_navigation_styles()
	_apply_inventory_styles()
	# Keep the exposed tab hitboxes above the full-page roots. The individual
	# main panels retain a higher z-index and cover the tab bodies below y=166.
	_inventory_sub_tabs.move_to_front()
	_apply_cooler_wall_styles()
	_apply_cooler_notepad_style()
	_cooler_water_surface.resized.connect(_update_cooler_water_mask)
	_fish_field.gui_input.connect(_on_fish_field_gui_input)
	_apply_bag_styles()
	_bag_item_field.gui_input.connect(_on_bag_field_gui_input)
	_apply_mail_notification_style()
	resized.connect(_update_shell_layout)
	_show_section_immediate(_current_section)
	call_deferred("_update_shell_layout")
	call_deferred("_update_cooler_water_mask")
	set_process(false)


func _configure_inventory_transition_group() -> void:
	# Keep the organizer row and the panel that masks its lower flange under one
	# alpha owner. Top-level page crossfades can then never expose a complete tab.
	var original_layer_index: int = mini(
		_inventory_sub_tabs.get_index(),
		mini(
			_cooler_page.get_index(),
			mini(_bag_page.get_index(), _tackle_box_page.get_index()),
		),
	)
	_inventory_transition_group = Control.new()
	_inventory_transition_group.name = "InventoryTransitionGroup"
	_inventory_transition_group.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_inventory_transition_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_presentation_scale_root.add_child(_inventory_transition_group)
	# Adding a runtime container normally places it after NavigationCluster in
	# GUI picking order. Retain the pages' authored layer so their full-screen
	# PASS roots cannot cover the top-level navigation hitboxes.
	_presentation_scale_root.move_child(
		_inventory_transition_group,
		original_layer_index,
	)
	for control: Control in [
		_inventory_sub_tabs,
		_cooler_page,
		_bag_page,
		_tackle_box_page,
	]:
		control.reparent(_inventory_transition_group, true)


func _apply_mail_notification_style() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.95, 0.88, 0.63, 0.98)
	background.border_color = Color(0.20, 0.14, 0.08, 0.92)
	background.set_border_width_all(2)
	background.set_corner_radius_all(12)
	background.content_margin_left = 5
	background.content_margin_right = 5
	background.content_margin_top = 2
	background.content_margin_bottom = 2
	_mail_unread_badge.add_theme_stylebox_override("normal", background)
	_mail_unread_badge.add_theme_font_override(
		"font", UtilityPageStyle.TuffyFont
	)


func _update_cooler_water_mask() -> void:
	var shader_material := _cooler_water_surface.material as ShaderMaterial
	if shader_material == null:
		return
	shader_material.set_shader_parameter(
		"rendered_size",
		_cooler_water_surface.size,
	)


func set_light_performance_profile(light_profile: bool) -> void:
	_cooler_water_surface.material = (
		null if light_profile else _authored_cooler_water_material
	)
	_cooler_water_surface.color = (
		LIGHT_COOLER_WATER_COLOR if light_profile else Color.WHITE
	)
	if not light_profile:
		_update_cooler_water_mask()


func is_cooler_water_effect_enabled() -> bool:
	return _cooler_water_surface.material is ShaderMaterial


func setup(
	player: PlayerType,
	inventory: FishInventoryType,
	collection_log: CollectionLogType,
	experience: PlayerExperienceType,
	wallet: PlayerWalletType,
	sale_service: FishSaleServiceType,
	default_buyer: FishBuyerProfileType,
	shop_buyer: FishBuyerProfileType,
	catalog: FishPoolType,
	fishing_spot: FishingSpotType,
	bag: PlayerBagType,
	hotbar: PlayerHotbarType,
	inventory_layout: PlayerInventoryLayout,
	item_catalog: ItemCatalogType,
	cooler_capacity: PlayerCoolerCapacityType,
	network_session: NetworkSessionType,
	network_sale_service: NetworkSaleService,
	network_mail_service: NetworkMailService,
	reservations: PlayerAssetReservationService,
	network_profile_service: NetworkProfileService,
	network_player_list: NetworkPlayerListService,
	discovery: DiscoveryClient,
	player_jobs: PlayerJobService,
	world_time: WorldTimeService,
	world_environment: WorldEnvironment,
	world_sun: DirectionalLight3D,
) -> void:
	_player = player
	_inventory = inventory
	_collection_log = collection_log
	_wallet = wallet
	_sale_service = sale_service
	_default_buyer = default_buyer
	_shop_buyer = shop_buyer
	_catalog = catalog
	_fishing_spot = fishing_spot
	_bag = bag
	_hotbar = hotbar
	_inventory_layout = inventory_layout
	_item_catalog = item_catalog
	_cooler_capacity = cooler_capacity
	_network_session = network_session
	_network_sale_service = network_sale_service
	_network_mail_service = network_mail_service
	_reservations = reservations
	_network_profile_service = network_profile_service
	_network_player_list = network_player_list
	_mail_page.setup(
		network_mail_service, reservations, inventory, wallet, bag, item_catalog
	)
	_profile_page.setup(
		network_profile_service,
		experience,
		world_environment,
		world_sun,
	)
	_players_page.setup(network_player_list, discovery)
	_catalog_logbook.setup(collection_log, inventory, catalog)
	_the_net_page.setup(player_jobs, world_time)
	_network_mail_service.unread_count_changed.connect(
		_on_mail_unread_count_changed
	)
	_on_mail_unread_count_changed(_network_mail_service.get_unread_count())
	if (
		_network_sale_service != null
		and not _network_sale_service.local_sale_pending.is_connected(
			_on_network_sale_pending
		)
	):
		_network_sale_service.local_sale_pending.connect(
			_on_network_sale_pending
		)
		_network_sale_service.local_sale_finished.connect(
			_on_network_sale_finished
		)
	_fish_selection.clear()
	if not _inventory.catches_changed.is_connected(_on_inventory_changed):
		_inventory.catches_changed.connect(_on_inventory_changed)
	if not _wallet.balance_changed.is_connected(_on_wallet_balance_changed):
		_wallet.balance_changed.connect(_on_wallet_balance_changed)
	if not _fishing_spot.bite_activated.is_connected(_on_bite_activated):
		_fishing_spot.bite_activated.connect(_on_bite_activated)
	if not _bag.contents_changed.is_connected(_on_bag_changed):
		_bag.contents_changed.connect(_on_bag_changed)
	if not _player.active_bait_changed.is_connected(_on_active_bait_changed):
		_player.active_bait_changed.connect(_on_active_bait_changed)
	if not _player.active_lure_changed.is_connected(_on_active_lure_changed):
		_player.active_lure_changed.connect(_on_active_lure_changed)
	if not _hotbar.slots_changed.is_connected(_on_hotbar_changed):
		_hotbar.slots_changed.connect(_on_hotbar_changed)
	if (
		_inventory_layout != null
		and not _inventory_layout.layout_changed.is_connected(_refresh_bag)
	):
		_inventory_layout.layout_changed.connect(_refresh_bag)
	if not _cooler_capacity.capacity_changed.is_connected(
		_on_cooler_capacity_changed
	):
		_cooler_capacity.capacity_changed.connect(_on_cooler_capacity_changed)
	_general_inventory_grid.setup(
		_inventory_layout,
		_bag,
		_inventory,
		_hotbar,
		_item_catalog,
		PlayerInventoryLayout.InventoryContainer.INVENTORY,
	)
	_refresh_all()


func setup_controller_mapping(
	mapping_manager: ControllerMappingManagerType,
) -> void:
	_controller_mapping_manager = mapping_manager
	_profile_page.setup_controller_mapping(_controller_mapping_manager)
	_the_net_page.setup_controller_mapping(_controller_mapping_manager)


func set_profile_preview_world_pixel_size(pixel_size: int) -> void:
	_profile_page.set_world_pixel_size(pixel_size)


func allows_global_controller_scroll() -> bool:
	# The profile page owns the right stick for preview orbit, zoom, and its
	# color picker. The shared menu scroller must not interpret that axis too.
	return _current_section != Section.PROFILE


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if _handle_controller_ownership_input(event):
		get_viewport().set_input_as_handled()
		return
	if visible:
		_reserve_main_navigation_for_page_switching()
		_reserve_visible_secondary_navigation()
	if _handle_controller_page_switch(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_direct_page_shortcut(event):
		get_viewport().set_input_as_handled()
		return
	if visible:
		if event.is_action_pressed("open_backpack"):
			if not _transitioning and not _page_transitioning:
				close_menu()
			get_viewport().set_input_as_handled()
			return
	if (
		event.is_action_pressed("open_backpack")
		and _fishing_spot != null
		and _fishing_spot.can_open_player_menu()
	):
		open_menu()
		get_viewport().set_input_as_handled()


func _handle_controller_ownership_input(event: InputEvent) -> bool:
	if not visible:
		return false
	if not _is_inventory_section(_current_section):
		return _handle_active_page_controller_input(event)
	var button_event := event as InputEventJoypadButton
	var accept_event: bool = (
		button_event != null
		and _event_matches_controller_role(
			event,
			ControllerMappingManagerType.ROLE_A,
			JOY_BUTTON_A,
		)
	)
	var accept_pressed: bool = (
		accept_event
		and button_event.pressed
	)
	var cancel_pressed: bool = (
		button_event != null
		and button_event.pressed
		and _event_matches_controller_role(
			event,
			ControllerMappingManagerType.ROLE_B,
			JOY_BUTTON_B,
		)
	)
	if cancel_pressed:
		if _controller_ownership == ControllerOwnership.ITEM_LIST:
			if _cancel_active_item_move():
				return true
		return _consume_player_menu_back()
	if _controller_ownership == ControllerOwnership.INVENTORY_TABS:
		if accept_pressed:
			_enter_inventory_content_zone()
			return true
		if event.is_action_pressed("ui_left"):
			_switch_inventory_tab_direction(-1)
			return true
		if event.is_action_pressed("ui_right"):
			_switch_inventory_tab_direction(1)
			return true
		if (
			event.is_action_pressed("ui_up")
			or event.is_action_pressed("ui_down")
		):
			# Inventory tabs are a closed controller zone. Content is entered
			# only by accepting the active tab, never by directional spillover.
			return true
		return false
	if _controller_ownership == ControllerOwnership.HOTBAR_MANAGEMENT:
		if event.is_action_pressed("ui_up"):
			_release_controller_ownership(true, false)
			return true
		if accept_pressed:
			if _hotbar != null:
				_hotbar.clear_slot(_hotbar.get_selected_slot())
			return true
		return false
	if _controller_ownership == ControllerOwnership.HOTBAR_PLACEMENT:
		if event.is_action_pressed("ui_up"):
			if _return_controller_hotbar_placement_to_storage():
				return true
			_release_controller_ownership(true, true)
			return true
		if accept_pressed:
			_confirm_controller_hotbar_placement()
			return true
		return false
	if _controller_ownership == ControllerOwnership.STORAGE_PLACEMENT:
		if accept_pressed:
			_confirm_controller_storage_placement()
			return true
		if accept_event:
			return true
		if (
			event.is_action_pressed("ui_down")
			and _controller_storage_focus_is_on_last_row()
		):
			var focused_slot := (
				get_viewport().gui_get_focus_owner() as BagStorageSlotType
			)
			if focused_slot != null:
				_controller_previous_storage_slot = (
					focused_slot.storage_slot_index
				)
			return _begin_controller_hotbar_placement_for_item(
				_controller_storage_identity
			)
		return false
	if _controller_ownership == ControllerOwnership.NOTEPAD_ACTIONS:
		return false
	if _controller_ownership == ControllerOwnership.SORT_FILTER:
		return false
	if _controller_ownership == ControllerOwnership.ITEM_LIST:
		if (
			button_event != null
			and button_event.pressed
			and _event_matches_controller_role(
				event,
				ControllerMappingManagerType.ROLE_Y,
				JOY_BUTTON_Y,
			)
		):
			_cancel_active_item_move()
			return _try_enter_notepad_controller_ownership()
		if (
			event.is_action_pressed("ui_down")
			and _controller_focus_is_on_last_inventory_row()
		):
			_cancel_controller_accept_hold()
			return _enter_controller_hotbar_management()
		if _event_matches_controller_role(
			event,
			ControllerMappingManagerType.ROLE_SELECT,
			JOY_BUTTON_BACK,
		):
			if button_event != null and button_event.pressed:
				if _current_section == Section.COOLER:
					_enter_inventory_sort_zone()
				return true
		if accept_event:
			if button_event.pressed:
				_controller_accept_held = true
				_controller_accept_hold_elapsed = 0.0
			else:
				var was_pending: bool = _controller_accept_held
				_cancel_controller_accept_hold()
				if was_pending:
					_activate_inventory_selection()
			return true
	return false


func _handle_active_page_controller_input(event: InputEvent) -> bool:
	if _dispatch_active_page_controller_input(event):
		return true
	var button_event := event as InputEventJoypadButton
	if (
		button_event != null
		and button_event.pressed
		and _event_matches_controller_role(
			event,
			ControllerMappingManagerType.ROLE_B,
			JOY_BUTTON_B,
		)
	):
		return _consume_player_menu_back()
	return false


func _dispatch_active_page_controller_input(event: InputEvent) -> bool:
	match _current_section:
		Section.LOGBOOK:
			return _catalog_logbook.handle_controller_input(event)
		Section.NET:
			return _the_net_page.handle_controller_input(event)
		Section.MAIL:
			return _mail_page.handle_controller_input(event)
		Section.PROFILE:
			return _profile_page.handle_controller_input(event)
		Section.PLAYERS:
			return _players_page.handle_controller_input(event)
	return false


func _activate_inventory_selection() -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if _current_section == Section.BAG:
		var slot := focus_owner as GeneralInventorySlotType
		if slot != null:
			_on_general_inventory_slot_activated(slot)
	elif _current_section == Section.TACKLE_BOX:
		if focus_owner != null and focus_owner.has_meta(
			&"controller_tackle_item_id"
		):
			_activate_tackle_move(StringName(str(
				focus_owner.get_meta(&"controller_tackle_item_id")
			)))


func _cancel_controller_accept_hold() -> void:
	_controller_accept_held = false
	_controller_accept_hold_elapsed = 0.0


func _event_matches_controller_role(
	event: InputEvent,
	role: StringName,
	fallback_button: JoyButton,
) -> bool:
	if _controller_mapping_manager != null:
		return _controller_mapping_manager.event_matches_role(event, role)
	var button_event := event as InputEventJoypadButton
	return button_event != null and button_event.button_index == fallback_button


func _try_enter_notepad_controller_ownership() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return false
	var source_identity: StringName
	var actions: Array[BaseButton] = []
	if _current_section == Section.COOLER:
		var fish_node := focus_owner as CoolerFishSpriteType
		if fish_node == null or fish_node.catch_id.is_empty():
			return false
		source_identity = fish_node.catch_id
		_on_catch_card_pressed(source_identity)
		if not _favorite_bubble.disabled:
			actions.append(_favorite_bubble)
		if not _sell_bubble.disabled:
			actions.append(_sell_bubble)
	elif _current_section == Section.TACKLE_BOX:
		if not focus_owner.has_meta(&"controller_tackle_item_id"):
			return false
		source_identity = StringName(
			str(focus_owner.get_meta(&"controller_tackle_item_id"))
		)
		_select_tackle_item(source_identity)
		if _tackle_equip_button.visible and not _tackle_equip_button.disabled:
			actions.append(_tackle_equip_button)
	elif _current_section == Section.BAG:
		var inventory_slot := focus_owner as GeneralInventorySlotType
		if inventory_slot == null or inventory_slot.entry_identity.is_empty():
			return false
		source_identity = inventory_slot.entry_identity
		_on_general_inventory_entry_selected(
			inventory_slot.entry_kind,
			inventory_slot.entry_identity,
		)
		actions = _get_bag_notepad_actions()
	else:
		return false
	_set_inventory_notepad_visible(_current_section, true)
	_controller_source_section = _current_section
	_controller_source_identity = source_identity
	_controller_notepad_actions = actions
	_controller_ownership = ControllerOwnership.NOTEPAD_ACTIONS
	_apply_inventory_controller_zone_focus_modes()
	_refresh_inventory_modal_interactivity()
	if not actions.is_empty():
		_configure_controller_notepad_action_focus(actions)
		actions.front().call_deferred("grab_focus")
	return true


func _configure_controller_notepad_action_focus(
	actions: Array[BaseButton],
) -> void:
	ControllerFocusNavigationType.configure_spatial_neighbors(actions)
	if actions.is_empty():
		return
	var favorite: BaseButton = (
		_favorite_bubble if _favorite_bubble in actions else null
	)
	var sell: BaseButton = _sell_bubble if _sell_bubble in actions else null
	if favorite != null and sell != null:
		favorite.focus_neighbor_right = favorite.get_path_to(sell)
		sell.focus_neighbor_left = sell.get_path_to(favorite)


func _controller_focus_is_on_last_inventory_row() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return false
	if _current_section == Section.COOLER:
		var fish_node := focus_owner as CoolerFishSpriteType
		if fish_node == null:
			return false
		var fish_index: int = _sorted_catches.find_custom(
			func(fish_catch: FishCatchType) -> bool:
				return fish_catch.catch_id == fish_node.catch_id
		)
		var fish_columns: int = 3 if _compact_layout else 9
		return (
			fish_index >= 0
			and fish_index + fish_columns >= _sorted_catches.size()
		)
	if _current_section == Section.BAG:
		var slot := focus_owner as GeneralInventorySlotType
		if slot == null:
			return false
		return (
			slot.slot_index / BAG_STORAGE_COLUMNS
			>= (_inventory_layout.get_inventory_capacity() - 1)
			/ BAG_STORAGE_COLUMNS
		)
	return false


func _enter_controller_hotbar_management() -> bool:
	if _hotbar == null or _current_section not in [Section.COOLER, Section.BAG]:
		return false
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	var source_identity: StringName
	if _current_section == Section.COOLER:
		var fish_node := focus_owner as CoolerFishSpriteType
		if fish_node == null:
			return false
		source_identity = fish_node.catch_id
	else:
		var slot := focus_owner as GeneralInventorySlotType
		if slot == null:
			return false
		source_identity = slot.entry_identity
	if source_identity.is_empty():
		return false
	_controller_source_section = _current_section
	_controller_source_identity = source_identity
	_controller_previous_hotbar_slot = _hotbar.get_selected_slot()
	_controller_ownership = ControllerOwnership.HOTBAR_MANAGEMENT
	_apply_inventory_controller_zone_focus_modes()
	controller_hotbar_management_requested.emit(
		_controller_previous_hotbar_slot
	)
	return true


func _try_begin_controller_hotbar_placement() -> bool:
	if _hotbar == null:
		return false
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == null:
		return false
	var assignment_kind: PlayerHotbarType.AssignmentKind = (
		PlayerHotbarType.AssignmentKind.EMPTY
	)
	var identity: StringName
	if _current_section == Section.COOLER:
		var fish_node := focus_owner as CoolerFishSpriteType
		if fish_node == null or fish_node.catch_id.is_empty():
			return false
		assignment_kind = PlayerHotbarType.AssignmentKind.FISH
		identity = fish_node.catch_id
	elif _current_section == Section.BAG:
		var slot := focus_owner as GeneralInventorySlotType
		if slot == null or slot.entry_identity.is_empty():
			return false
		identity = slot.entry_identity
		if slot.entry_kind == PlayerInventoryLayout.EntryKind.CATCH:
			assignment_kind = PlayerHotbarType.AssignmentKind.FISH
		else:
			var item: ItemDataType = (
				_item_catalog.get_item_by_id(identity)
				if _item_catalog != null else null
			)
			if item == null or not item.hotbar_allowed:
				return true
			assignment_kind = PlayerHotbarType.AssignmentKind.ITEM
	else:
		return false
	return _begin_controller_hotbar_placement(assignment_kind, identity)


func _begin_controller_hotbar_placement_for_item(item_id: StringName) -> bool:
	var item: ItemDataType = (
		_item_catalog.get_item_by_id(item_id)
		if _item_catalog != null else null
	)
	if item == null or not item.hotbar_allowed:
		return true
	return _begin_controller_hotbar_placement(
		PlayerHotbarType.AssignmentKind.ITEM,
		item_id,
	)


func _begin_controller_hotbar_placement(
	assignment_kind: PlayerHotbarType.AssignmentKind,
	identity: StringName,
) -> bool:
	if _hotbar == null or identity.is_empty():
		return false
	_controller_source_section = _current_section
	_controller_source_identity = identity
	_controller_hotbar_assignment_kind = assignment_kind
	_controller_hotbar_identity = identity
	_controller_previous_hotbar_slot = _hotbar.get_selected_slot()
	var initial_slot: int = _find_controller_hotbar_assignment(
		assignment_kind,
		identity,
	)
	if initial_slot < 0:
		initial_slot = _controller_previous_hotbar_slot
	_controller_ownership = ControllerOwnership.HOTBAR_PLACEMENT
	_apply_inventory_controller_zone_focus_modes()
	controller_hotbar_placement_requested.emit(
		assignment_kind,
		identity,
		initial_slot,
	)
	return true


func _try_begin_controller_storage_placement() -> bool:
	if _current_section != Section.BAG or _bag == null:
		return false
	var item_node := get_viewport().gui_get_focus_owner() as BagItemSpriteType
	if item_node == null or item_node.item_id.is_empty():
		return false
	var source_slot: int = _bag.get_storage_slot(item_node.item_id)
	if source_slot < 0 or source_slot >= _bag_slot_nodes.size():
		return false
	_controller_source_section = Section.BAG
	_controller_source_identity = item_node.item_id
	_controller_storage_identity = item_node.item_id
	_controller_ownership = ControllerOwnership.STORAGE_PLACEMENT
	_apply_inventory_controller_zone_focus_modes()
	_configure_bag_storage_slot_focus()
	_bag_slot_nodes[source_slot].call_deferred("grab_focus")
	return true


func _confirm_controller_storage_placement() -> void:
	if (
		_controller_ownership != ControllerOwnership.STORAGE_PLACEMENT
		or _bag == null
		or _controller_storage_identity.is_empty()
	):
		return
	var slot := get_viewport().gui_get_focus_owner() as BagStorageSlotType
	if slot == null or slot.storage_slot_index < 0:
		return
	var moved: bool = _bag.move_item_to_storage_slot(
		_controller_storage_identity,
		slot.storage_slot_index,
	)
	if moved:
		_release_controller_ownership(true, false)


func _controller_storage_focus_is_on_last_row() -> bool:
	var slot := get_viewport().gui_get_focus_owner() as BagStorageSlotType
	if slot == null:
		return false
	return (
		slot.storage_slot_index / BAG_STORAGE_COLUMNS
		>= (_bag_slot_nodes.size() - 1) / BAG_STORAGE_COLUMNS
	)


func _find_controller_hotbar_assignment(
	assignment_kind: PlayerHotbarType.AssignmentKind,
	identity: StringName,
) -> int:
	for slot_index: int in range(PlayerHotbarType.SLOT_COUNT):
		if (
			assignment_kind == PlayerHotbarType.AssignmentKind.FISH
			and _hotbar.get_fish_catch_id(slot_index) == identity
		):
			return slot_index
		if (
			assignment_kind == PlayerHotbarType.AssignmentKind.ITEM
			and _hotbar.get_item_id(slot_index) == identity
		):
			return slot_index
	return -1


func _confirm_controller_hotbar_placement() -> void:
	if (
		_controller_ownership != ControllerOwnership.HOTBAR_PLACEMENT
		or _hotbar == null
	):
		return
	var slot_index: int = _hotbar.get_selected_slot()
	var assigned: bool = false
	if (
		_controller_hotbar_assignment_kind
		== PlayerHotbarType.AssignmentKind.FISH
	):
		assigned = _hotbar.assign_fish(
			slot_index,
			_controller_hotbar_identity,
		)
	elif (
		_controller_hotbar_assignment_kind
		== PlayerHotbarType.AssignmentKind.ITEM
	):
		assigned = _hotbar.assign_item(
			slot_index,
			_controller_hotbar_identity,
		)
	if assigned:
		_release_controller_ownership(true, false)


func _return_controller_hotbar_placement_to_storage() -> bool:
	if (
		_controller_ownership != ControllerOwnership.HOTBAR_PLACEMENT
		or _controller_source_section != Section.BAG
		or _controller_storage_identity.is_empty()
		or _bag_slot_nodes.is_empty()
	):
		return false
	if _hotbar != null:
		_hotbar.select_slot(_controller_previous_hotbar_slot)
	controller_hotbar_placement_ended.emit()
	_controller_ownership = ControllerOwnership.STORAGE_PLACEMENT
	_controller_hotbar_assignment_kind = PlayerHotbarType.AssignmentKind.EMPTY
	_controller_hotbar_identity = StringName()
	_apply_inventory_controller_zone_focus_modes()
	_configure_bag_storage_slot_focus()
	var target_index: int = clampi(
		_controller_previous_storage_slot,
		0,
		_bag_slot_nodes.size() - 1,
	)
	_bag_slot_nodes[target_index].call_deferred("grab_focus")
	return true


func _release_controller_ownership(
	restore_source_focus: bool,
	restore_previous_hotbar_slot: bool,
) -> void:
	if _controller_ownership == ControllerOwnership.ITEM_LIST:
		return
	var prior_ownership: ControllerOwnership = _controller_ownership
	var source_section: Section = _controller_source_section
	var source_identity: StringName = _controller_source_identity
	_controller_ownership = ControllerOwnership.ITEM_LIST
	_controller_notepad_actions.clear()
	_controller_source_identity = StringName()
	_controller_hotbar_assignment_kind = PlayerHotbarType.AssignmentKind.EMPTY
	_controller_hotbar_identity = StringName()
	_controller_storage_identity = StringName()
	if prior_ownership == ControllerOwnership.NOTEPAD_ACTIONS:
		_set_inventory_notepad_visible(source_section, false)
	_apply_inventory_controller_zone_focus_modes()
	_refresh_inventory_modal_interactivity()
	if prior_ownership == ControllerOwnership.HOTBAR_PLACEMENT:
		if restore_previous_hotbar_slot and _hotbar != null:
			_hotbar.select_slot(_controller_previous_hotbar_slot)
		controller_hotbar_placement_ended.emit()
	if prior_ownership == ControllerOwnership.HOTBAR_MANAGEMENT:
		controller_hotbar_management_ended.emit()
		inventory_hotbar_context_changed.emit(
			_current_section in [Section.COOLER, Section.BAG]
		)
	if restore_source_focus:
		call_deferred(
			"_restore_controller_item_focus",
			source_section,
			source_identity,
		)


func _restore_controller_item_focus(
	section: Section,
	identity: StringName,
) -> void:
	if not visible or section != _current_section:
		return
	if identity.is_empty():
		_focus_current_section()
		return
	var target: Control
	if section == Section.COOLER:
		target = _fish_nodes.get(identity) as CoolerFishSpriteType
	elif section == Section.BAG:
		if _general_inventory_grid != null:
			for slot: GeneralInventorySlotType in _general_inventory_grid.get_slots():
				if slot.entry_identity == identity:
					target = slot
					break
	elif section == Section.TACKLE_BOX:
		target = _tackle_item_buttons.get(identity) as Button
	if (
		target != null
		and is_instance_valid(target)
		and target.is_visible_in_tree()
		and target.focus_mode != Control.FOCUS_NONE
	):
		target.grab_focus()
	else:
		_focus_current_section()


func _handle_controller_page_switch(event: InputEvent) -> bool:
	var button_event := event as InputEventJoypadButton
	if button_event == null or not visible:
		return false
	var use_mapping: bool = _controller_mapping_manager != null
	var uses_left_bumper: bool = (
		_controller_mapping_manager.event_uses_role(
			event, ControllerMappingManagerType.ROLE_LB
		)
		if use_mapping
		else button_event.button_index == JOY_BUTTON_LEFT_SHOULDER
	)
	var uses_right_bumper: bool = (
		_controller_mapping_manager.event_uses_role(
			event, ControllerMappingManagerType.ROLE_RB
		)
		if use_mapping
		else button_event.button_index == JOY_BUTTON_RIGHT_SHOULDER
	)
	if not (uses_left_bumper or uses_right_bumper):
		return false
	if _controller_ownership == ControllerOwnership.NOTEPAD_ACTIONS:
		return true
	if not button_event.pressed:
		return true
	if (
		_transitioning
		or _page_transitioning
		or _sale_confirmation.visible
		or get_viewport().gui_is_dragging()
	):
		return true
	var sections: Array[Section] = [
		_last_inventory_section,
		Section.LOGBOOK,
		Section.NET,
		Section.MAIL,
		Section.PROFILE,
		Section.PLAYERS,
	]
	var current_index: int = 0
	if not _is_inventory_section(_current_section):
		current_index = sections.find(_current_section)
		if current_index < 0:
			current_index = 0
	var direction: int = -1 if uses_left_bumper else 1
	var next_index: int = clampi(
		current_index + direction,
		0,
		sections.size() - 1,
	)
	if next_index == current_index:
		return true
	_cancel_controller_accept_hold()
	_release_controller_ownership(false, true)
	_show_section(sections[next_index])
	return true


func _get_inventory_tab_index() -> int:
	return 1 if _current_section == Section.TACKLE_BOX else 0


func _show_inventory_tab(index: int) -> void:
	match clampi(index, 0, 1):
		0:
			_bag_view = BagView.EQUIPMENT
			_show_section(Section.BAG)
		_:
			_show_section(Section.TACKLE_BOX)


func _switch_inventory_tab_direction(direction: int) -> void:
	var current_index: int = _get_inventory_tab_index()
	var target_index: int = clampi(current_index + direction, 0, 1)
	if target_index == current_index:
		return
	_show_inventory_tab(target_index)


func _enter_inventory_tabs_zone() -> void:
	if not _is_inventory_section(_current_section):
		return
	_cancel_controller_accept_hold()
	_controller_ownership = ControllerOwnership.INVENTORY_TABS
	_apply_inventory_controller_zone_focus_modes()
	var active_tab: Button = _inventory_tab_for_section(_current_section)
	if (
		active_tab != null
		and active_tab.is_visible_in_tree()
		and active_tab.focus_mode != Control.FOCUS_NONE
	):
		active_tab.call_deferred("grab_focus")


func _enter_inventory_content_zone() -> void:
	if not _is_inventory_section(_current_section):
		return
	_cancel_controller_accept_hold()
	_controller_ownership = ControllerOwnership.ITEM_LIST
	_apply_inventory_controller_zone_focus_modes()
	call_deferred("_focus_current_section")


func _enter_inventory_sort_zone() -> void:
	if _current_section != Section.COOLER:
		return
	_cancel_controller_accept_hold()
	_controller_ownership = ControllerOwnership.SORT_FILTER
	_controller_source_section = _current_section
	_apply_inventory_controller_zone_focus_modes()
	var sort_controls: Array[Control] = [
		_cooler_sort_option,
		_cooler_sort_direction,
	]
	ControllerFocusNavigationType.configure_spatial_neighbors(
		sort_controls
	)
	_cooler_sort_option.call_deferred("grab_focus")


func _reset_controller_zone_for_section() -> void:
	_cancel_controller_accept_hold()
	if _is_inventory_section(_current_section):
		_enter_inventory_tabs_zone()
		return
	_controller_ownership = ControllerOwnership.PAGE_CONTENT
	match _current_section:
		Section.LOGBOOK:
			_catalog_logbook.reset_controller_zone()
		Section.NET:
			_the_net_page.reset_controller_zone()
		Section.MAIL:
			_mail_page.reset_controller_zone()
		Section.PROFILE:
			_profile_page.reset_controller_zone()
		Section.PLAYERS:
			_players_page.reset_controller_zone()


func _handle_direct_page_shortcut(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	if (
		key_event == null
		or not key_event.pressed
		or _is_text_input_active()
		or _shortcut_blocked_by_modal_state()
	):
		return false
	var physical_key: Key = key_event.physical_keycode
	var inventory_requested: bool = physical_key == KEY_I
	var logbook_requested: bool = physical_key == KEY_L
	var tackle_requested: bool = (
		physical_key == KEY_V
		or event.is_action_pressed("open_tacklebox")
	)
	if not inventory_requested and not tackle_requested and not logbook_requested:
		return false
	var requested_section: Section = (
		Section.LOGBOOK
		if logbook_requested
		else (
			Section.TACKLE_BOX
			if tackle_requested
			else _last_inventory_section
		)
	)
	if visible:
		if (
			_current_section == requested_section
			and not _transitioning
			and not _page_transitioning
		):
			close_menu()
		elif not _transitioning and not _page_transitioning:
			_show_section(requested_section)
	else:
		if (
			_fishing_spot == null
			or not _fishing_spot.can_open_player_menu()
		):
			return false
		_current_section = requested_section
		open_menu()
	return true


func _shortcut_blocked_by_modal_state() -> bool:
	return (
		_sale_confirmation.visible
		or _controller_ownership == ControllerOwnership.NOTEPAD_ACTIONS
		or (
			_current_section == Section.MAIL
			and _mail_page.is_composing_letter()
		)
		or (
			_current_section == Section.PROFILE
			and _profile_page.has_modal_confirmation()
		)
	)


func _is_text_input_active() -> bool:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	return (
		focus_owner != null
		and focus_owner.is_visible_in_tree()
		and (focus_owner is LineEdit or focus_owner is TextEdit)
	)


func consume_escape() -> bool:
	if not visible:
		return false
	return _consume_player_menu_back()


func _consume_player_menu_back() -> bool:
	if _transitioning or _page_transitioning:
		return true
	if _sale_confirmation.visible:
		_close_sale_confirmation()
		return true
	_cancel_controller_accept_hold()
	if _is_inventory_section(_current_section):
		match _controller_ownership:
			ControllerOwnership.NOTEPAD_ACTIONS:
				_release_controller_ownership(true, false)
			ControllerOwnership.SORT_FILTER:
				_enter_inventory_content_zone()
			ControllerOwnership.HOTBAR_MANAGEMENT:
				_release_controller_ownership(true, false)
			ControllerOwnership.HOTBAR_PLACEMENT:
				_release_controller_ownership(true, true)
			ControllerOwnership.STORAGE_PLACEMENT:
				_release_controller_ownership(true, false)
			ControllerOwnership.ITEM_LIST:
				_enter_inventory_tabs_zone()
			ControllerOwnership.INVENTORY_TABS:
				close_menu()
			_:
				close_menu()
		return true
	var cancel_event := InputEventAction.new()
	cancel_event.action = &"ui_cancel"
	cancel_event.pressed = true
	if _dispatch_active_page_controller_input(cancel_event):
		return true
	if _current_section == Section.MAIL and _mail_page.consume_escape():
		return true
	if _current_section == Section.PROFILE and _profile_page.consume_escape():
		return true
	close_menu()
	return true


func open_menu() -> void:
	if (
		visible
		or _shop_cooler_context_active
		or _player == null
		or _fishing_spot == null
		or not _fishing_spot.can_open_player_menu()
	):
		return
	_release_controller_ownership(false, true)
	_set_inventory_notepad_visible(Section.BAG, false)
	_set_inventory_notepad_visible(Section.TACKLE_BOX, false)
	_cancel_active_item_move()
	_hide_inventory_context_tooltip()
	_menu_generation += 1
	_transition_generation += 1
	_cancel_presentation_tween()
	_cancel_page_tween()
	_prior_movement_enabled = _player.is_movement_enabled()
	_prior_camera_input_enabled = _player.is_camera_input_enabled()
	_prior_mouse_mode = Input.mouse_mode
	_control_snapshot_stored = true
	_mouse_snapshot_stored = true
	_player.set_movement_enabled(false)
	_player.set_camera_input_enabled(false)
	_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_refresh_all()
	_show_section_immediate(_current_section)
	_update_shell_layout()
	_begin_menu_entry()
	menu_visibility_changed.emit(true)
	inventory_hotbar_context_changed.emit(
		_current_section in [Section.COOLER, Section.BAG]
	)


func open_section(section: Section) -> bool:
	if (
		_shop_cooler_context_active
		or _player == null
		or _fishing_spot == null
		or not _fishing_spot.can_open_player_menu()
	):
		return false
	if visible:
		if _transitioning or _page_transitioning or _sale_confirmation.visible:
			return false
		if section != _current_section:
			_show_section(section)
		return true
	_current_section = section
	open_menu()
	return visible


func mount_shop_cooler(
	host: Control,
	buyer: FishBuyerProfileType,
) -> bool:
	if (
		visible
		or _shop_cooler_context_active
		or host == null
		or not is_instance_valid(host)
		or buyer == null
		or not buyer.is_valid()
		or buyer.id != MAIN_SHOP_BUYER_ID
	):
		return false
	_menu_generation += 1
	_cancel_page_tween()
	_transitioning = false
	_page_transitioning = false
	_sale_buyer_override = buyer
	_shop_cooler_context_active = true
	_current_section = Section.BAG
	_last_inventory_section = Section.BAG
	_cooler_page.reparent(host, false)
	_sale_confirmation.reparent(host, false)
	_cooler_page.position = Vector2.ZERO
	_cooler_page.size = DESKTOP_REFERENCE_SIZE
	_cooler_page.scale = Vector2.ONE
	_cooler_page.modulate = Color.WHITE
	_cooler_page.visible = true
	_sale_confirmation.visible = false
	_update_shell_layout()
	_refresh_inventory()
	_set_content_interactive(true)
	_update_cooler_water_mask()
	set_process(true)
	_cooler_sort_option.call_deferred("grab_focus")
	return true


func unmount_shop_cooler() -> void:
	if not _shop_cooler_context_active:
		return
	_close_sale_confirmation()
	_set_content_interactive(false)
	_cooler_page.visible = false
	_cooler_page.reparent(_cooler_original_parent, false)
	_cooler_original_parent.move_child(
		_cooler_page,
		mini(_cooler_original_index, _cooler_original_parent.get_child_count() - 1),
	)
	_sale_confirmation.reparent(_confirmation_original_parent, false)
	_confirmation_original_parent.move_child(
		_sale_confirmation,
		mini(
			_confirmation_original_index,
			_confirmation_original_parent.get_child_count() - 1,
		),
	)
	_sale_buyer_override = null
	_shop_cooler_context_active = false
	_menu_generation += 1
	if not visible:
		set_process(false)


func is_shop_cooler_mounted() -> bool:
	return _shop_cooler_context_active


func cancel_shop_cooler_confirmation() -> void:
	if _shop_cooler_context_active and _sale_confirmation.visible:
		_close_sale_confirmation()


func _focus_shop_cooler() -> void:
	if not _shop_cooler_context_active or not _cooler_page.is_visible_in_tree():
		return
	var focused_node := _fish_nodes.get(
		_fish_selection.get_focused_id()
	) as CoolerFishSpriteType
	if focused_node != null and focused_node.focus_mode != Control.FOCUS_NONE:
		focused_node.grab_focus()
		return
	for fish_catch: FishCatchType in _sorted_catches:
		var fish_node := _fish_nodes.get(
			fish_catch.catch_id
		) as CoolerFishSpriteType
		if fish_node != null and fish_node.focus_mode != Control.FOCUS_NONE:
			fish_node.grab_focus()
			return
	_cooler_sort_option.grab_focus()


func close_menu(
	reason: CloseReason = CloseReason.USER,
	restore_controls: bool = true,
) -> void:
	if not visible:
		return
	if (
		reason == CloseReason.USER
		and _current_section == Section.PROFILE
		and _profile_page.request_close_confirmation()
	):
		return
	if _transitioning:
		if reason != CloseReason.USER:
			_finish_close(reason, restore_controls, _menu_generation)
		return
	_release_controller_ownership(false, true)
	get_viewport().gui_cancel_drag()
	_close_sale_confirmation()
	if reason in [
		CloseReason.BITE_STARTED,
		CloseReason.WATER_RECOVERY,
		CloseReason.SESSION_END,
		CloseReason.TEARDOWN,
	]:
		_fish_selection.clear()
	menu_exit_started.emit()
	_begin_menu_exit(reason, restore_controls)


func close_for_water_recovery() -> void:
	_fish_selection.clear()
	close_menu(CloseReason.WATER_RECOVERY, false)


func close_for_game_menu() -> void:
	close_menu(CloseReason.GAME_MENU)


func close_for_session_end() -> void:
	_fish_selection.clear()
	close_menu(CloseReason.SESSION_END, false)


func _exit_tree() -> void:
	_release_controller_ownership(false, true)
	_cancel_presentation_tween()
	_cancel_page_tween()
	if visible:
		_finish_close(CloseReason.TEARDOWN, false, _menu_generation)
	_fish_selection.clear()
	_menu_generation += 1


func _restore_player_controls(generation: int) -> void:
	if (
		generation != _menu_generation
		or not _control_snapshot_stored
	):
		return
	if _player != null and is_instance_valid(_player):
		_player.set_movement_enabled(_prior_movement_enabled)
		_player.set_camera_input_enabled(_prior_camera_input_enabled)
	_control_snapshot_stored = false


func _apply_mouse_close_policy(reason: CloseReason) -> void:
	if not _mouse_snapshot_stored:
		return
	match reason:
		CloseReason.USER, CloseReason.BITE_STARTED:
			Input.mouse_mode = _prior_mouse_mode
		CloseReason.GAME_MENU:
			# The Game Menu immediately assumes visible pointer ownership.
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		CloseReason.WATER_RECOVERY:
			# Recovery remains authoritative over local input.
			pass
		CloseReason.SESSION_END:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		CloseReason.TEARDOWN:
			pass
	_mouse_snapshot_stored = false


func _on_bite_activated() -> void:
	if visible:
		close_menu(CloseReason.BITE_STARTED)


func _show_section(section: Section) -> void:
	if (
		section == _current_section
		or _transitioning
		or _page_transitioning
		or _sale_confirmation.visible
		or get_viewport().gui_is_dragging()
	):
		return
	_cancel_active_item_move()
	_hide_inventory_context_tooltip()
	if (
		_current_section == Section.PROFILE
		and _profile_page.request_close_confirmation()
	):
		return
	var preserve_inventory_tab_zone: bool = (
		_controller_ownership == ControllerOwnership.INVENTORY_TABS
		and _is_inventory_section(_current_section)
		and _is_inventory_section(section)
	)
	if not preserve_inventory_tab_zone:
		_release_controller_ownership(false, true)
	_begin_page_transition(section)
	if preserve_inventory_tab_zone:
		_controller_ownership = ControllerOwnership.INVENTORY_TABS


func _show_section_immediate(section: Section) -> void:
	_current_section = section
	if _is_inventory_section(section):
		_last_inventory_section = section
	if not is_node_ready():
		return
	_configure_navigation_focus()
	_cooler_page.visible = section == Section.COOLER
	_bag_page.visible = section == Section.BAG
	_tackle_box_page.visible = section == Section.TACKLE_BOX
	_inventory_sub_tabs.visible = _is_inventory_section(section)
	_logbook_page.visible = section == Section.LOGBOOK
	_the_net_page.visible = section == Section.NET
	_mail_page.visible = section == Section.MAIL
	_profile_page.visible = section == Section.PROFILE
	_players_page.visible = section == Section.PLAYERS
	if section == Section.COOLER:
		_refresh_inventory()
	else:
		_fish_selection.clear()
		_close_detail_constellation()
	if section != Section.BAG:
		_close_bag_detail()
	else:
		# BagView can change while entering from another Inventory page. Rebuild
		# the filtered contents here so the visible list always matches its tab.
		_refresh_bag()
	_refresh_tackle_box()
	if section != Section.LOGBOOK:
		_catalog_logbook.deactivate()
	else:
		_catalog_logbook.activate()
	if section == Section.NET:
		_the_net_page.activate()
	else:
		_the_net_page.deactivate()
	if section == Section.MAIL:
		_mail_page.activate()
	else:
		_mail_page.deactivate()
	if section == Section.PROFILE:
		_profile_page.activate()
	else:
		_profile_page.deactivate()
	if section == Section.PLAYERS:
		_players_page.activate()
	else:
		_players_page.deactivate()
	_inventory_tab.button_pressed = _is_inventory_section(section)
	_cooler_sub_tab.set_selected(section == Section.COOLER)
	_bag_sub_tab.set_selected(
		section == Section.BAG and _bag_view == BagView.EQUIPMENT
	)
	_items_sub_tab.set_selected(
		section == Section.BAG and _bag_view == BagView.CONSUMABLES
	)
	_tackle_sub_tab.set_selected(section == Section.TACKLE_BOX)
	_refresh_inventory_organizer_tabs()
	_logbook_tab.button_pressed = section == Section.LOGBOOK
	_the_net_tab.button_pressed = section == Section.NET
	_mail_tab.button_pressed = section == Section.MAIL
	_profile_tab.button_pressed = section == Section.PROFILE
	_players_tab.button_pressed = section == Section.PLAYERS
	_update_navigation_selection()
	_configure_active_page_focus()
	inventory_hotbar_context_changed.emit(
		section in [Section.COOLER, Section.BAG]
	)


func _is_inventory_section(section: Section) -> bool:
	return section in [Section.COOLER, Section.BAG, Section.TACKLE_BOX]


func _refresh_inventory_organizer_tabs() -> void:
	for tab: OrganizerTabType in [
		_cooler_sub_tab,
		_bag_sub_tab,
		_items_sub_tab,
		_tackle_sub_tab,
	]:
		tab.refresh_state()


func _animate_inventory_tab_entry() -> void:
	if not _is_inventory_section(_current_section):
		return
	var tabs: Array[OrganizerTabType] = [
		_cooler_sub_tab,
		_bag_sub_tab,
		_items_sub_tab,
		_tackle_sub_tab,
	]
	for index: int in tabs.size():
		tabs[index].animate_entrance(float(index) * 0.025)


func _settle_inventory_tabs_for_close() -> void:
	for tab: OrganizerTabType in [
		_cooler_sub_tab,
		_bag_sub_tab,
		_items_sub_tab,
		_tackle_sub_tab,
	]:
		tab.settle_for_close()


func _show_last_inventory_section() -> void:
	_show_section(
		Section.TACKLE_BOX
		if _last_inventory_section == Section.TACKLE_BOX
		else Section.BAG
	)


func _focus_current_section() -> void:
	if _shop_cooler_context_active:
		_focus_shop_cooler()
		return
	var candidates: Array[Control] = _inventory_content_focus_candidates()
	if candidates.is_empty():
		_enter_inventory_tabs_zone()
		return
	ControllerFocusNavigationType.configure_spatial_neighbors(candidates)
	candidates.sort_custom(func(first: Control, second: Control) -> bool:
		if not is_equal_approx(first.global_position.y, second.global_position.y):
			return first.global_position.y < second.global_position.y
		return first.global_position.x < second.global_position.x
	)
	candidates[0].grab_focus()


func _inventory_content_focus_candidates() -> Array[Control]:
	var candidates: Array[Control] = []
	match _current_section:
		Section.COOLER:
			for fish_node: CoolerFishSpriteType in _fish_nodes.values():
				if ControllerFocusNavigationType.is_focusable(fish_node):
					candidates.append(fish_node)
		Section.BAG:
			if _general_inventory_grid != null:
				for slot: GeneralInventorySlotType in (
					_general_inventory_grid.get_slots()
				):
					if ControllerFocusNavigationType.is_focusable(slot):
						candidates.append(slot)
		Section.TACKLE_BOX:
			for tackle_button: Button in _tackle_item_buttons.values():
				if ControllerFocusNavigationType.is_focusable(tackle_button):
					candidates.append(tackle_button)
	return candidates


func _process(delta: float) -> void:
	if visible or _shop_cooler_context_active:
		if (
			visible
			and _controller_accept_held
			and _controller_ownership == ControllerOwnership.ITEM_LIST
			and _current_section in [Section.COOLER, Section.BAG]
		):
			_controller_accept_hold_elapsed += delta
			if (
				_controller_accept_hold_elapsed
				>= CONTROLLER_PICKUP_HOLD_SECONDS
			):
				_cancel_controller_accept_hold()
				_try_begin_controller_hotbar_placement()
		_motion_elapsed += delta
		if visible:
			_navigation_cluster.advance_motion(delta)
			_apply_navigation_selection_presentation()
		for fish_node: CoolerFishSpriteType in _fish_nodes.values():
			fish_node.advance_presentation(delta, _motion_elapsed)
		if not visible:
			return
		var bag_motion_enabled: bool = (
			not _bag_drag_active and not get_viewport().gui_is_dragging()
		)
		for item_node: BagItemSpriteType in _bag_item_nodes.values():
			item_node.advance_presentation(
				_motion_elapsed,
				bag_motion_enabled,
			)


func _configure_navigation_focus() -> void:
	_reserve_main_navigation_for_page_switching()
	var navigation: Array[BubbleButtonType] = [
		_inventory_tab,
		_logbook_tab,
		_the_net_tab,
		_mail_tab,
		_profile_tab,
		_players_tab,
		_close_button,
	]
	for index: int in navigation.size():
		var bubble: BubbleButtonType = navigation[index]
		var previous: BubbleButtonType = navigation[
			(index - 1 + navigation.size()) % navigation.size()
		]
		var next: BubbleButtonType = navigation[
			(index + 1) % navigation.size()
		]
		bubble.focus_neighbor_left = bubble.get_path_to(previous)
		bubble.focus_neighbor_right = bubble.get_path_to(next)
		bubble.focus_neighbor_top = bubble.focus_neighbor_left
		bubble.focus_neighbor_bottom = bubble.focus_neighbor_right


func _reserve_main_navigation_for_page_switching() -> void:
	var navigation_cluster := get_node_or_null("%NavigationCluster") as Control
	if navigation_cluster == null:
		return
	_set_descendant_focus_disabled(navigation_cluster)


func _set_descendant_focus_disabled(root: Node) -> void:
	for child: Node in root.get_children():
		var control := child as Control
		if control != null:
			control.focus_mode = Control.FOCUS_NONE
		_set_descendant_focus_disabled(child)


func _reserve_visible_secondary_navigation() -> void:
	if not _is_inventory_section(_current_section):
		return
	var inventory_tabs: Array[Button] = [_bag_sub_tab, _tackle_sub_tab]
	_set_inventory_tab_focus_enabled(
		_content_interactive_enabled
		and visible
		and not _transitioning
		and not _page_transitioning
		and _controller_ownership == ControllerOwnership.INVENTORY_TABS
	)
	for index: int in inventory_tabs.size():
		var tab: Button = inventory_tabs[index]
		tab.focus_neighbor_left = tab.get_path_to(
			inventory_tabs[maxi(index - 1, 0)]
		)
		tab.focus_neighbor_right = tab.get_path_to(
			inventory_tabs[mini(index + 1, inventory_tabs.size() - 1)]
		)
		tab.focus_neighbor_top = tab.get_path_to(_inventory_tab)
	_inventory_tab.focus_neighbor_bottom = _inventory_tab.get_path_to(
		_inventory_tab_for_section(_last_inventory_section)
	)
	_configure_tackle_item_focus()


func _set_inventory_tab_focus_enabled(enabled: bool) -> void:
	_cooler_sub_tab.focus_mode = Control.FOCUS_NONE
	_items_sub_tab.focus_mode = Control.FOCUS_NONE
	for tab: Button in [_bag_sub_tab, _tackle_sub_tab]:
		tab.focus_mode = (
			Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
		)


func _apply_inventory_controller_zone_focus_modes() -> void:
	if not is_node_ready():
		return
	var regular_active: bool = (
		_content_interactive_enabled
		and visible
		and _is_inventory_section(_current_section)
		and not _transitioning
		and not _page_transitioning
		and not _sale_confirmation.visible
	)
	var shop_active: bool = (
		_content_interactive_enabled
		and _shop_cooler_context_active
		and _current_section == Section.COOLER
	)
	_set_inventory_tab_focus_enabled(
		regular_active
		and _controller_ownership == ControllerOwnership.INVENTORY_TABS
	)
	var content_active: bool = (
		regular_active
		and _controller_ownership == ControllerOwnership.ITEM_LIST
	)
	var notepad_active: bool = (
		regular_active
		and _controller_ownership == ControllerOwnership.NOTEPAD_ACTIONS
	)
	var sort_active: bool = (
		regular_active
		and _controller_ownership == ControllerOwnership.SORT_FILTER
	)
	var storage_active: bool = (
		regular_active
		and _current_section == Section.BAG
		and _controller_ownership == ControllerOwnership.STORAGE_PLACEMENT
	)
	for sort_control: Control in [
		_cooler_sort_option,
		_cooler_sort_direction,
	]:
		sort_control.focus_mode = (
			Control.FOCUS_ALL
			if sort_active or shop_active
			else Control.FOCUS_NONE
		)
	for fish_node: CoolerFishSpriteType in _fish_nodes.values():
		fish_node.focus_mode = (
			Control.FOCUS_ALL
			if (
				shop_active
				or (
					content_active
					and _current_section == Section.COOLER
				)
			)
			else Control.FOCUS_NONE
		)
	for action: NotepadInkActionType in [
		_favorite_bubble,
		_sell_bubble,
	]:
		action.focus_mode = (
			Control.FOCUS_ALL
			if (
				(shop_active or notepad_active)
				and _detail_constellation.visible
				and not action.disabled
			)
			else Control.FOCUS_NONE
		)
	for action: NotepadInkActionType in [
		_bag_favorite_button,
		_bag_sell_button,
	]:
		action.focus_mode = (
			Control.FOCUS_ALL
			if (
				notepad_active
				and _current_section == Section.BAG
				and _bag_detail_constellation.visible
				and action.visible
				and not action.disabled
			)
			else Control.FOCUS_NONE
		)
	for item_node: BagItemSpriteType in _bag_item_nodes.values():
		item_node.focus_mode = (
			Control.FOCUS_ALL
			if (
				content_active
				and _current_section == Section.BAG
				and not _bag_drag_active
			)
			else Control.FOCUS_NONE
		)
		item_node.modulate.a = (
			0.24
			if (
				storage_active
				and item_node.item_id == _controller_storage_identity
			)
			else 1.0
		)
	if _general_inventory_grid != null:
		for slot: GeneralInventorySlotType in _general_inventory_grid.get_slots():
			slot.focus_mode = (
				Control.FOCUS_ALL
				if content_active and _current_section == Section.BAG
				else Control.FOCUS_NONE
			)
	for slot: BagStorageSlotType in _bag_slot_nodes:
		if not is_instance_valid(slot):
			continue
		slot.focus_mode = (
			Control.FOCUS_ALL if storage_active else Control.FOCUS_NONE
		)
		var preview_active: bool = (
			storage_active and slot.has_focus()
		)
		slot.set_placement_preview(
			_controller_storage_texture(),
			preview_active,
		)
	for button: Button in _tackle_item_buttons.values():
		button.focus_mode = (
			Control.FOCUS_ALL
			if content_active and _current_section == Section.TACKLE_BOX
			else Control.FOCUS_NONE
		)
	_tackle_equip_button.focus_mode = (
		Control.FOCUS_ALL
		if (
			notepad_active
			and _current_section == Section.TACKLE_BOX
			and _tackle_equip_button.visible
			and not _tackle_equip_button.disabled
		)
		else Control.FOCUS_NONE
	)


func _inventory_tab_for_section(section: Section) -> Button:
	return _tackle_sub_tab if section == Section.TACKLE_BOX else _bag_sub_tab


func _configure_sale_confirmation_focus() -> void:
	_confirm_sale_button.focus_neighbor_left = (
		_confirm_sale_button.get_path_to(_cancel_sale_button)
	)
	_confirm_sale_button.focus_neighbor_right = (
		_confirm_sale_button.focus_neighbor_left
	)
	_confirm_sale_button.focus_neighbor_top = (
		_confirm_sale_button.get_path_to(_confirm_sale_button)
	)
	_confirm_sale_button.focus_neighbor_bottom = (
		_confirm_sale_button.focus_neighbor_top
	)
	_cancel_sale_button.focus_neighbor_left = (
		_cancel_sale_button.get_path_to(_confirm_sale_button)
	)
	_cancel_sale_button.focus_neighbor_right = (
		_cancel_sale_button.focus_neighbor_left
	)
	_cancel_sale_button.focus_neighbor_top = (
		_cancel_sale_button.get_path_to(_cancel_sale_button)
	)
	_cancel_sale_button.focus_neighbor_bottom = (
		_cancel_sale_button.focus_neighbor_top
	)
	if not _sale_confirmation.visible:
		for button: Button in [_confirm_sale_button, _cancel_sale_button]:
			button.focus_mode = Control.FOCUS_NONE
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _configure_active_page_focus() -> void:
	match _current_section:
		Section.COOLER:
			_configure_cooler_fish_focus()
		Section.BAG:
			_configure_bag_item_focus()
		Section.TACKLE_BOX:
			_configure_tackle_item_focus()
		Section.LOGBOOK:
			_catalog_logbook.focus_initial()
		Section.NET:
			_the_net_page.focus_initial()
		Section.MAIL:
			_mail_page.activate()
		Section.PROFILE:
			_profile_page.activate()


func _apply_inventory_styles() -> void:
	for panel: PanelContainer in [_tackle_main_panel]:
		var panel_style := UtilityPageStyle.panel_style()
		panel_style.set_corner_radius_all(INVENTORY_MAIN_CORNER_RADIUS)
		panel.add_theme_stylebox_override(
			"panel",
			panel_style,
		)
	for label: Label in [
		_bait_heading,
		_lure_heading,
		_bait_empty,
		_lure_empty,
	]:
		label.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
		label.add_theme_color_override(
			"font_color",
			UtilityPageStyle.OCEAN_TEXT_PRIMARY,
		)
	_sale_confirmation.add_theme_stylebox_override(
		"panel",
		UtilityPageStyle.panel_style(),
	)
	_confirmation_message.add_theme_font_override(
		"normal_font",
		UtilityPageStyle.TuffyFont,
	)
	_confirmation_message.add_theme_color_override(
		"default_color",
		UtilityPageStyle.OCEAN_TEXT_PRIMARY,
	)
	UtilityPageStyle.apply_ocean_button(_confirm_sale_button)
	UtilityPageStyle.apply_ocean_button(_cancel_sale_button)


func _create_inventory_context_tooltip() -> void:
	_context_tooltip = PanelContainer.new()
	_context_tooltip.name = "InventoryContextTooltip"
	_context_tooltip.visible = false
	_context_tooltip.z_index = 140
	_context_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context_tooltip.custom_minimum_size = Vector2(310.0, 0.0)
	var bubble_style := UtilityPageStyle.rounded_style(
		Color(UtilityPageStyle.OCEAN_PANEL_DEEP, 0.98),
		14,
	)
	bubble_style.set_border_width_all(0)
	bubble_style.content_margin_left = 14.0
	bubble_style.content_margin_top = 10.0
	bubble_style.content_margin_right = 14.0
	bubble_style.content_margin_bottom = 10.0
	_context_tooltip.add_theme_stylebox_override("panel", bubble_style)
	_context_tooltip_label = Label.new()
	_context_tooltip_label.custom_minimum_size = Vector2(282.0, 0.0)
	_context_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_context_tooltip_label.add_theme_font_override(
		"font",
		UtilityPageStyle.TuffyFont,
	)
	_context_tooltip_label.add_theme_font_size_override("font_size", 16)
	_context_tooltip_label.add_theme_color_override(
		"font_color",
		UtilityPageStyle.OCEAN_TEXT_PRIMARY,
	)
	_context_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context_tooltip.add_child(_context_tooltip_label)
	_presentation_scale_root.add_child(_context_tooltip)


func _on_inventory_context_changed(
	source: GeneralInventorySlotType,
	text: String,
	active: bool,
) -> void:
	if active:
		_show_inventory_context_tooltip(source, text)
	else:
		_hide_inventory_context_tooltip_for(source)


func _show_inventory_context_tooltip(source: Control, text: String) -> void:
	if (
		source == null
		or text.strip_edges().is_empty()
		or _controller_ownership == ControllerOwnership.NOTEPAD_ACTIONS
	):
		return
	_context_tooltip_source = source
	_context_tooltip_label.text = text
	_context_tooltip.visible = true
	_context_tooltip.reset_size()
	call_deferred("_position_inventory_context_tooltip", source)


func _position_inventory_context_tooltip(source: Control) -> void:
	if (
		not _context_tooltip.visible
		or source == null
		or not is_instance_valid(source)
		or source != _context_tooltip_source
	):
		return
	_context_tooltip.reset_size()
	var inverse := (
		_presentation_scale_root.get_global_transform_with_canvas().affine_inverse()
	)
	var source_global: Rect2 = source.get_global_rect()
	var source_top_left: Vector2 = inverse * source_global.position
	var source_bottom_right: Vector2 = inverse * source_global.end
	var source_rect := Rect2(
		source_top_left,
		source_bottom_right - source_top_left,
	)
	var bubble_size: Vector2 = _context_tooltip.size
	var x: float = source_rect.end.x + 12.0
	if x + bubble_size.x > DESKTOP_REFERENCE_SIZE.x - 18.0:
		x = source_rect.position.x - bubble_size.x - 12.0
	var y: float = source_rect.get_center().y - bubble_size.y * 0.5
	_context_tooltip.position = Vector2(
		clampf(x, 18.0, DESKTOP_REFERENCE_SIZE.x - bubble_size.x - 18.0),
		clampf(y, 112.0, DESKTOP_REFERENCE_SIZE.y - bubble_size.y - 24.0),
	)


func _hide_inventory_context_tooltip_for(source: Control) -> void:
	if source != _context_tooltip_source:
		return
	if (
		source != null
		and (
			source.has_focus()
			or source.get_global_rect().has_point(
				get_viewport().get_mouse_position()
			)
		)
	):
		return
	_hide_inventory_context_tooltip()


func _hide_inventory_context_tooltip() -> void:
	if _context_tooltip == null:
		return
	_context_tooltip.visible = false
	_context_tooltip_source = null


func _show_bag_view(view: BagView) -> void:
	if (
		_transitioning
		or _page_transitioning
		or _sale_confirmation.visible
		or get_viewport().gui_is_dragging()
	):
		return
	if _current_section != Section.BAG:
		_bag_view = view
		_selected_bag_item_id = StringName()
		_show_section(Section.BAG)
		return
	if _bag_view == view:
		return
	var preserve_tab_zone: bool = (
		_controller_ownership == ControllerOwnership.INVENTORY_TABS
	)
	if not preserve_tab_zone:
		_release_controller_ownership(false, true)
	_bag_view = view
	_selected_bag_item_id = StringName()
	_refresh_bag()
	_bag_sub_tab.set_selected(view == BagView.EQUIPMENT)
	_items_sub_tab.set_selected(view == BagView.CONSUMABLES)
	_refresh_inventory_organizer_tabs()
	_reserve_visible_secondary_navigation()
	_set_content_interactive(true)
	if preserve_tab_zone:
		_enter_inventory_tabs_zone()
	else:
		call_deferred("_focus_current_section")


func _refresh_tackle_box() -> void:
	if not is_node_ready():
		return
	for item_list: GridContainer in [_bait_item_list, _lure_item_list]:
		for child: Node in item_list.get_children():
			child.queue_free()
	_tackle_item_buttons.clear()
	var bait_items: Array[OwnedItemType] = []
	var lure_items: Array[OwnedItemType] = []
	if _bag != null and _item_catalog != null:
		for owned: OwnedItemType in _bag.get_unlocked_bait_items():
			var item: ItemDataType = _item_catalog.get_item_by_id(
				owned.item_id
			)
			if item != null and item.category == ItemDataType.Category.BAIT:
				bait_items.append(owned)
		for owned: OwnedItemType in _bag.get_all_items():
			var item: ItemDataType = _item_catalog.get_item_by_id(
				owned.item_id
			)
			if item != null and item.category == ItemDataType.Category.LURE:
				lure_items.append(owned)
	bait_items.sort_custom(_sort_tackle_items)
	lure_items.sort_custom(_sort_tackle_items)
	_populate_tackle_column(bait_items, _bait_item_list)
	_populate_tackle_column(lure_items, _lure_item_list)
	if (
		not _selected_tackle_item_id.is_empty()
		and not _tackle_item_buttons.has(_selected_tackle_item_id)
	):
		_selected_tackle_item_id = StringName()
	_bait_empty.visible = bait_items.is_empty()
	_lure_empty.visible = lure_items.is_empty()
	_configure_tackle_item_focus()
	_update_tackle_detail()
	_apply_tackle_interactivity(_tackle_is_interactive())


func _populate_tackle_column(
	owned_items: Array[OwnedItemType],
	item_list: GridContainer,
) -> void:
	for owned: OwnedItemType in owned_items:
		var item: ItemDataType = _item_catalog.get_item_by_id(owned.item_id)
		if item == null:
			continue
		var button := Button.new()
		button.icon = item.icon
		var context_text: String = _tackle_context_text(item, owned.quantity)
		button.tooltip_text = ""
		button.set_meta(&"inventory_context_text", context_text)
		button.custom_minimum_size = Vector2(72, 72)
		button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		button.expand_icon = item.icon != null
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.text = "" if item.icon != null else item.display_name
		if item.icon == null:
			button.add_theme_font_size_override("font_size", 12)
		button.toggle_mode = true
		button.set_meta(&"controller_tackle_item_id", owned.item_id)
		button.button_pressed = owned.item_id == _selected_tackle_item_id
		_apply_tackle_bait_button_style(button)
		if item.is_bait():
			UtilityPageStyle.add_supply_quantity_badge(
				button,
				owned.quantity,
				item.max_stack,
				&"QuantityBadge",
			)
		button.pressed.connect(_activate_tackle_move.bind(owned.item_id))
		button.gui_input.connect(
			_on_tackle_button_gui_input.bind(owned.item_id, button)
		)
		button.focus_entered.connect(
			_show_inventory_context_tooltip.bind(
				button,
				context_text,
			)
		)
		button.focus_exited.connect(
			_hide_inventory_context_tooltip_for.bind(button)
		)
		button.mouse_entered.connect(
			_show_inventory_context_tooltip.bind(button, context_text)
		)
		button.mouse_exited.connect(
			_hide_inventory_context_tooltip_for.bind(button)
		)
		item_list.add_child(button)
		_tackle_item_buttons[owned.item_id] = button
	_refresh_tackle_move_presentation()


func _tackle_context_text(item: ItemDataType, quantity: int) -> String:
	var lines: Array[String] = [item.display_name]
	var quantity_text := str(quantity)
	if item.is_bait():
		quantity_text = "%d/%d" % [quantity, item.max_stack]
	lines.append(
		"%s • quantity %s" % [item.get_category_name(), quantity_text]
	)
	if not item.description.strip_edges().is_empty():
		lines.append(item.description.strip_edges())
	return "\n".join(lines)


func _activate_tackle_move(item_id: StringName) -> void:
	if _bag == null or item_id.is_empty():
		return
	var target_slot: int = _bag.get_storage_slot(item_id)
	if _tackle_move_identity.is_empty():
		if target_slot < 0:
			return
		_tackle_move_identity = item_id
		_selected_tackle_item_id = item_id
		_update_tackle_detail()
		_refresh_tackle_move_presentation()
		var button := _tackle_item_buttons.get(item_id) as Button
		if button != null:
			_show_inventory_context_tooltip(
				button,
				"moving %s\nchoose another %s • B cancels" % [
					button.accessibility_name
					if not button.accessibility_name.is_empty()
					else str(
						button.get_meta(&"inventory_context_text", "item")
					).get_slice("\n", 0),
					"bait" if _item_catalog.get_item_by_id(item_id).is_bait()
					else "lure",
				],
			)
		return
	var source_id: StringName = _tackle_move_identity
	_tackle_move_identity = StringName()
	_refresh_tackle_move_presentation()
	_hide_inventory_context_tooltip()
	if source_id == item_id or target_slot < 0:
		return
	_bag.move_item_to_storage_slot(source_id, target_slot)


func _refresh_tackle_move_presentation() -> void:
	for item_id: StringName in _tackle_item_buttons:
		var button: Button = _tackle_item_buttons[item_id]
		button.modulate = (
			Color(1.0, 1.0, 1.0, 0.42)
			if item_id == _tackle_move_identity
			else Color.WHITE
		)


func _on_tackle_button_gui_input(
	event: InputEvent,
	item_id: StringName,
	button: Button,
) -> void:
	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event == null
		or mouse_event.button_index != MOUSE_BUTTON_RIGHT
		or not mouse_event.pressed
	):
		return
	_cancel_active_item_move()
	_select_tackle_item(item_id)
	var actions: Array[BaseButton] = []
	if _tackle_equip_button.visible and not _tackle_equip_button.disabled:
		actions.append(_tackle_equip_button)
	_open_inventory_notepad(Section.TACKLE_BOX, item_id, actions)
	button.accept_event()


func _configure_tackle_item_focus() -> void:
	if not is_node_ready():
		return
	var bait_buttons: Array[Button] = _get_tackle_column_buttons(
		_bait_item_list
	)
	var lure_buttons: Array[Button] = _get_tackle_column_buttons(
		_lure_item_list
	)
	var first_button: Button = (
		bait_buttons.front()
		if not bait_buttons.is_empty()
		else (lure_buttons.front() if not lure_buttons.is_empty() else null)
	)
	_tackle_sub_tab.focus_neighbor_bottom = (
		_tackle_sub_tab.get_path_to(first_button)
		if first_button != null
		else NodePath()
	)
	_configure_tackle_column_focus(bait_buttons, lure_buttons, true)
	_configure_tackle_column_focus(lure_buttons, bait_buttons, false)


func _get_tackle_column_buttons(item_list: GridContainer) -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in item_list.get_children():
		var button := child as Button
		if button != null and not button.is_queued_for_deletion():
			buttons.append(button)
	return buttons


func _configure_tackle_column_focus(
	buttons: Array[Button],
	other_buttons: Array[Button],
	is_left_column: bool,
) -> void:
	for index: int in buttons.size():
		var button: Button = buttons[index]
		var column: int = index % TACKLE_GRID_COLUMNS
		var row: int = floori(float(index) / float(TACKLE_GRID_COLUMNS))
		var left_target: Button = button
		var right_target: Button = button
		if column > 0:
			left_target = buttons[index - 1]
		elif not is_left_column and not other_buttons.is_empty():
			left_target = other_buttons[mini(
				row * TACKLE_GRID_COLUMNS + TACKLE_GRID_COLUMNS - 1,
				other_buttons.size() - 1,
			)]
		if column < TACKLE_GRID_COLUMNS - 1 and index + 1 < buttons.size():
			right_target = buttons[index + 1]
		elif is_left_column and not other_buttons.is_empty():
			right_target = other_buttons[mini(
				row * TACKLE_GRID_COLUMNS,
				other_buttons.size() - 1,
			)]
		button.focus_neighbor_left = button.get_path_to(left_target)
		button.focus_neighbor_right = button.get_path_to(right_target)
		button.focus_neighbor_top = (
			button.get_path_to(button)
			if index < TACKLE_GRID_COLUMNS
			else button.get_path_to(buttons[index - TACKLE_GRID_COLUMNS])
		)
		button.focus_neighbor_bottom = button.get_path_to(
			buttons[mini(index + TACKLE_GRID_COLUMNS, buttons.size() - 1)]
		)


func _apply_tackle_bait_button_style(button: Button) -> void:
	var profile := BubbleMenuProfile.new()
	var normal_style: StyleBoxFlat = profile.make_normal_style()
	var hover_style: StyleBoxFlat = profile.make_hover_style()
	var pressed_style: StyleBoxFlat = profile.make_pressed_style()
	var disabled_style: StyleBoxFlat = profile.make_disabled_style()
	for style: StyleBoxFlat in [
		normal_style,
		hover_style,
		pressed_style,
		disabled_style,
	]:
		style.set_corner_radius_all(36)
		style.content_margin_left = 13.5
		style.content_margin_top = 13.5
		style.content_margin_right = 13.5
		style.content_margin_bottom = 13.5
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("focus", hover_style)
	button.add_theme_stylebox_override("pressed", pressed_style)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_color_override("icon_normal_color", Color.WHITE)
	button.add_theme_color_override("icon_hover_color", Color.WHITE)
	button.add_theme_color_override("icon_focus_color", Color.WHITE)
	button.add_theme_color_override("icon_pressed_color", Color.WHITE)


func _select_tackle_item(item_id: StringName) -> void:
	_selected_tackle_item_id = item_id
	for candidate_id: StringName in _tackle_item_buttons:
		var button: Button = _tackle_item_buttons[candidate_id]
		button.button_pressed = candidate_id == item_id
	_update_tackle_detail()


func _update_tackle_detail() -> void:
	var item: ItemDataType = (
		_item_catalog.get_item_by_id(_selected_tackle_item_id)
		if _item_catalog != null and not _selected_tackle_item_id.is_empty()
		else null
	)
	if item == null:
		_tackle_equip_button.visible = false
		_tackle_equip_button.persistent_mark = false
		_tackle_detail_text.text = "Select bait or a lure for details."
		_apply_tackle_interactivity(_tackle_is_interactive())
		return
	_tackle_equip_button.visible = item.is_bait() or item.is_lure()
	var quantity: int = _bag.get_quantity(item.item_id) if _bag != null else 0
	var assigned_slot: int = -1
	if _hotbar != null:
		for slot_index: int in range(PlayerHotbarType.SLOT_COUNT):
			if _hotbar.get_item_id(slot_index) == item.item_id:
				assigned_slot = slot_index
				break
	var detail_lines: Array[String] = [item.display_name, ""]
	if item.is_bait():
		detail_lines.append("quantity: %d/%d" % [quantity, item.max_stack])
	if assigned_slot >= 0:
		detail_lines.append("hotbar slot %d" % (assigned_slot + 1))
	detail_lines.append("")
	detail_lines.append(item.description)
	_tackle_detail_text.text = "\n".join(detail_lines)
	if item.is_bait() or item.is_lure():
		var is_equipped: bool = (
			_player != null
			and (
				_player.active_bait_id == item.item_id
				if item.is_bait()
				else _player.active_lure_id == item.item_id
			)
		)
		_tackle_equip_button.text = (
			"dequip %s" % item.display_name
			if is_equipped
			else "equip %s" % item.display_name
		)
		_tackle_equip_button.persistent_mark = is_equipped
		_tackle_equip_button.disabled = quantity <= 0
		_tackle_equip_button.refresh_ink_state()
	_apply_tackle_interactivity(_tackle_is_interactive())


func _tackle_is_interactive() -> bool:
	return (
		visible
		and _current_section == Section.TACKLE_BOX
		and not _transitioning
		and not _page_transitioning
		and not _sale_confirmation.visible
	)


func _apply_tackle_interactivity(interactive: bool) -> void:
	var item_interactive: bool = (
		interactive
		and _controller_ownership != ControllerOwnership.NOTEPAD_ACTIONS
	)
	for button: Button in _tackle_item_buttons.values():
		button.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if item_interactive
			else Control.MOUSE_FILTER_IGNORE
		)
	var action_interactive: bool = (
		interactive
		and _tackle_detail_panel.visible
		and _tackle_equip_button.visible
		and not _tackle_equip_button.disabled
	)
	_tackle_equip_button.mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if action_interactive
		else Control.MOUSE_FILTER_IGNORE
	)
	_apply_inventory_controller_zone_focus_modes()


func _toggle_active_tackle() -> void:
	if _player == null or _item_catalog == null:
		return
	var item: ItemDataType = _item_catalog.get_item_by_id(_selected_tackle_item_id)
	if item == null:
		return
	if item.is_bait():
		if _player.active_bait_id == item.item_id:
			_player.unequip_bait()
		else:
			_player.equip_bait(item)
	elif item.is_lure():
		if _player.active_lure_id == item.item_id:
			_player.unequip_lure()
		else:
			_player.equip_lure(item)
	else:
		return
	_update_tackle_detail()


func _on_active_bait_changed(_item_id: StringName) -> void:
	_update_tackle_detail()


func _on_active_lure_changed(_item_id: StringName) -> void:
	_update_tackle_detail()


func _apply_cooler_wall_styles() -> void:
	var outer := StyleBoxFlat.new()
	outer.bg_color = Color(0.76, 0.9, 0.96, 1.0)
	outer.border_color = Color(0.91, 0.98, 1.0, 1.0)
	outer.set_border_width_all(7)
	outer.set_corner_radius_all(INVENTORY_MAIN_CORNER_RADIUS)
	_cooler_outer_wall.add_theme_stylebox_override("panel", outer)
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0.018, 0.16, 0.25, 1.0)
	inner.border_color = Color(0.56, 0.78, 0.86, 1.0)
	inner.set_border_width_all(5)
	inner.set_corner_radius_all(INVENTORY_INNER_CORNER_RADIUS)
	_cooler_inner_liner.add_theme_stylebox_override("panel", inner)
	var scroll_bar := _cooler_scroll.get_v_scroll_bar()
	var scroll_grabber := StyleBoxFlat.new()
	scroll_grabber.bg_color = Color(0.56, 0.78, 0.86, 0.58)
	scroll_grabber.set_corner_radius_all(6)
	scroll_bar.add_theme_stylebox_override("grabber", scroll_grabber)
	scroll_bar.add_theme_stylebox_override("grabber_highlight", scroll_grabber)
	scroll_bar.add_theme_stylebox_override("grabber_pressed", scroll_grabber)
	var scroll_track := StyleBoxFlat.new()
	scroll_track.bg_color = Color(0.02, 0.1, 0.14, 0.28)
	scroll_track.set_corner_radius_all(6)
	scroll_bar.add_theme_stylebox_override("scroll", scroll_track)


func _apply_cooler_notepad_style() -> void:
	_detail_bubble.add_theme_stylebox_override(
		"panel",
		InventoryNotepadType.make_layout_style(false),
	)
	InventoryNotepadType.apply_handwritten_to(_detail_constellation)


func _apply_navigation_styles() -> void:
	var profile: BubbleMenuProfile = _inventory_tab.profile
	if profile == null:
		return
	var normal := _make_navigation_style(profile.normal_fill, 2, 0.24)
	var hover := _make_navigation_style(
		profile.hover_fill.lightened(0.025),
		4,
		0.34,
	)
	var pressed := _make_navigation_style(
		profile.pressed_fill.lightened(0.055),
		5,
		0.40,
	)
	var disabled := _make_navigation_style(profile.disabled_fill, 1, 0.14)
	for bubble: BubbleButtonType in [
		_inventory_tab,
		_logbook_tab,
		_the_net_tab,
		_mail_tab,
		_profile_tab,
		_players_tab,
		_close_button,
	]:
		bubble.add_theme_stylebox_override("normal", normal)
		bubble.add_theme_stylebox_override("hover", hover)
		bubble.add_theme_stylebox_override("focus", hover)
		bubble.add_theme_stylebox_override("pressed", pressed)
		bubble.add_theme_stylebox_override("disabled", disabled)


func _make_navigation_style(
	fill: Color,
	shadow_size: int,
	shadow_alpha: float,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_corner_radius_all(128)
	style.set_border_width_all(0)
	style.shadow_color = Color(0.015, 0.06, 0.09, shadow_alpha)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0.0, 2.0)
	return style


func _apply_navigation_selection_presentation() -> void:
	for bubble: BubbleButtonType in [
		_inventory_tab,
		_logbook_tab,
		_the_net_tab,
		_mail_tab,
		_profile_tab,
		_players_tab,
	]:
		if not bubble.button_pressed:
			continue
		bubble.scale *= NAVIGATION_SELECTED_SCALE


func _apply_bag_styles() -> void:
	var outer := StyleBoxFlat.new()
	outer.bg_color = UtilityPageStyle.OCEAN_PANEL_DEEP
	outer.set_border_width_all(0)
	outer.set_corner_radius_all(INVENTORY_MAIN_CORNER_RADIUS)
	_bag_outer_wall.add_theme_stylebox_override("panel", outer)
	var inner := StyleBoxFlat.new()
	inner.bg_color = UtilityPageStyle.OCEAN_PANEL_MID
	inner.set_border_width_all(0)
	inner.set_corner_radius_all(INVENTORY_INNER_CORNER_RADIUS)
	_bag_inner_liner.add_theme_stylebox_override("panel", inner)
func _update_navigation_selection() -> void:
	_set_navigation_target(_current_section)


func _on_mail_unread_count_changed(count: int) -> void:
	_mail_unread_badge.visible = count > 0
	_mail_unread_badge.text = "99+" if count > 99 else str(count)


func _set_navigation_target(section: Section) -> void:
	_inventory_tab.button_pressed = _is_inventory_section(section)
	_logbook_tab.button_pressed = section == Section.LOGBOOK
	_the_net_tab.button_pressed = section == Section.NET
	_mail_tab.button_pressed = section == Section.MAIL
	_profile_tab.button_pressed = section == Section.PROFILE
	_players_tab.button_pressed = section == Section.PLAYERS


func _update_shell_layout() -> void:
	if not is_node_ready():
		return
	var compact: bool = false
	_compact_layout = compact
	var reference_size := DESKTOP_REFERENCE_SIZE
	_presentation_scale_root.size = reference_size
	if not _transitioning:
		_presentation_scale_root.scale = Vector2.ONE
	_presentation_scale_root.position = Vector2.ZERO
	_presentation_scale_root.pivot_offset = reference_size * 0.5
	var navigation_size := NAVIGATION_REFERENCE_SIZE
	_navigation_cluster.position = NAVIGATION_CANONICAL_POSITION
	_navigation_cluster.size = navigation_size
	_navigation_cluster.scale = (
		Vector2.ONE * NAVIGATION_PRESENTATION_SCALE
	)
	_navigation_cluster.apply_layout(navigation_size, compact)
	_cooler_page.size = reference_size
	_cooler_page.position = Vector2.ZERO
	_cooler_rest_position = Vector2.ZERO
	_inventory_sub_tabs.position = Vector2(
		(DESKTOP_REFERENCE_SIZE.x - INVENTORY_VISIBLE_TAB_WIDTH) * 0.5,
		INVENTORY_MAIN_POSITION.y - 30.0,
	)
	_inventory_sub_tabs.size = Vector2(INVENTORY_VISIBLE_TAB_WIDTH, 38.0)
	_layout_cooler_fish(false)
	_cooler_outer_wall.position = COOLER_MAIN_POSITION
	_cooler_outer_wall.size = COOLER_MAIN_SIZE
	_detail_constellation.position = COOLER_NOTEPAD_POSITION
	_detail_constellation.size = INVENTORY_NOTEPAD_SIZE
	_notepad_binding.position = Vector2(44.0, 1.0) if compact else Vector2(28.0, 4.0)
	_notepad_binding.size = Vector2(218.0, 20.0) if compact else Vector2(232.0, 27.0)
	_notepad_binding.add_theme_font_size_override("font_size", 13 if compact else 20)
	_notepad_title.position = Vector2(10.0, 14.0) if compact else Vector2(20.0, 31.0)
	_notepad_title.size = Vector2(286.0, 18.0) if compact else Vector2(248.0, 28.0)
	_notepad_title.add_theme_font_size_override("font_size", 14 if compact else 20)
	_notepad_rule.position = Vector2(10.0, 49.0) if compact else Vector2(18.0, 87.0)
	_notepad_rule.size = Vector2(286.0, 2.0) if compact else Vector2(252.0, 2.0)
	_cooler_sort_controls.position = (
		Vector2(10.0, 51.0) if compact else Vector2(18.0, 98.0)
	)
	_cooler_sort_controls.size = (
		Vector2(286.0, 31.0) if compact else Vector2(252.0, 38.0)
	)
	_cooler_sort_controls.get_child(0).visible = false
	_cooler_sort_option.custom_minimum_size = (
		Vector2(140.0, 31.0) if compact else Vector2(123.0, 38.0)
	)
	_cooler_sort_direction.custom_minimum_size = (
		Vector2(140.0, 31.0) if compact else Vector2(123.0, 38.0)
	)
	_cooler_sort_option.set_choice_font_size(14 if compact else 17)
	_cooler_sort_direction.add_theme_font_size_override(
		"font_size",
		14 if compact else 17,
	)
	_notepad_wallet_value.position = (
		Vector2(10.0, 33.0) if compact else Vector2(18.0, 61.0)
	)
	_notepad_wallet_value.size = (
		Vector2(138.0, 17.0) if compact else Vector2(120.0, 23.0)
	)
	_notepad_capacity_value.position = (
		Vector2(154.0, 33.0) if compact else Vector2(146.0, 61.0)
	)
	_notepad_capacity_value.size = (
		Vector2(142.0, 17.0) if compact else Vector2(124.0, 23.0)
	)
	_notepad_wallet_value.icon_size = 10.0 if compact else 14.0
	_notepad_wallet_value.get_amount_label().add_theme_font_size_override(
		"font_size", 10 if compact else 14
	)
	_notepad_capacity_value.add_theme_font_size_override(
		"font_size", 10 if compact else 14
	)
	_cooler_detail_texture.position = (
		Vector2(5.0, 84.0) if compact else Vector2(80.0, 137.0)
	)
	_cooler_detail_texture.size = (
		Vector2(74.0, 58.0) if compact else Vector2(128.0, 100.0)
	)
	_cooler_detail_name.position = (
		Vector2(82.0, 82.0) if compact else Vector2(18.0, 241.0)
	)
	_cooler_detail_name.size = (
		Vector2(214.0, 40.0) if compact else Vector2(252.0, 48.0)
	)
	_cooler_detail_name.add_theme_font_size_override(
		"font_size", 18 if compact else 25,
	)
	_cooler_detail_stats.position = (
		Vector2(82.0, 123.0) if compact else Vector2(18.0, 290.0)
	)
	_cooler_detail_stats.size = (
		Vector2(214.0, 62.0) if compact else Vector2(252.0, 72.0)
	)
	_layout_cooler_detail_text(compact)
	_cooler_selection_summary.position = (
		Vector2(10.0, 190.0) if compact else Vector2(18.0, 365.0)
	)
	_cooler_selection_summary.size = (
		Vector2(130.0, 35.0) if compact else Vector2(252.0, 40.0)
	)
	_layout_cooler_selection_text(compact)
	_favorite_bubble.custom_minimum_size = (
		Vector2(72.0, 42.0) if compact else Vector2(108.0, 50.0)
	)
	_sell_bubble.custom_minimum_size = (
		Vector2(74.0, 42.0) if compact else Vector2(118.0, 50.0)
	)
	_favorite_bubble.position = (
		Vector2(144.0, 190.0) if compact else Vector2(26.0, 408.0)
	)
	_favorite_bubble.size = (
		Vector2(72.0, 42.0) if compact else Vector2(108.0, 50.0)
	)
	_sell_bubble.position = (
		Vector2(222.0, 190.0) if compact else Vector2(144.0, 408.0)
	)
	_sell_bubble.size = (
		Vector2(74.0, 42.0) if compact else Vector2(118.0, 50.0)
	)
	_favorite_bubble.add_theme_font_size_override(
		"font_size", 13 if compact else 19,
	)
	_sell_bubble.add_theme_font_size_override(
		"font_size", 13 if compact else 19,
	)
	_update_sort_direction_text()
	_bag_page.size = reference_size
	_bag_page.position = Vector2.ZERO
	_bag_rest_position = Vector2.ZERO
	_tackle_box_page.size = reference_size
	_tackle_box_page.position = Vector2.ZERO
	_tackle_rest_position = Vector2.ZERO
	_bag_outer_wall.position = INVENTORY_MAIN_POSITION
	_bag_outer_wall.size = INVENTORY_MAIN_SIZE
	# ScrollContainer reserves an 8 px vertical gutter even while disabled.
	# Account for it so the authored 882 px outer panel stays exact.
	_bag_host.custom_minimum_size = Vector2(810.0, 420.0)
	_bag_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	call_deferred("_layout_general_inventory_grid")
	_bag_detail_constellation.position = INVENTORY_NOTEPAD_POSITION
	_bag_detail_constellation.size = INVENTORY_NOTEPAD_SIZE
	_bag_sprite_detail_texture.custom_minimum_size = (
		Vector2(72.0, 48.0) if compact else Vector2(100.0, 72.0)
	)
	_bag_sprite_detail_name.add_theme_font_size_override(
		"font_size",
		18 if compact else 22,
	)
	_bag_sprite_detail_data.add_theme_font_size_override(
		"font_size",
		12 if compact else 15,
	)
	_bag_sprite_detail_weight.add_theme_font_size_override(
		"font_size",
		13 if compact else 16,
	)
	_bag_sprite_detail_value.icon_size = 13.0 if compact else 16.0
	_bag_sprite_detail_value.get_amount_label().add_theme_font_size_override(
		"font_size", 13 if compact else 16,
	)
	_tackle_main_panel.position = INVENTORY_MAIN_POSITION
	_tackle_main_panel.size = INVENTORY_MAIN_SIZE
	_tackle_detail_panel.position = INVENTORY_NOTEPAD_POSITION
	_tackle_detail_panel.size = INVENTORY_NOTEPAD_SIZE
	_bait_item_list.columns = TACKLE_GRID_COLUMNS
	_lure_item_list.columns = TACKLE_GRID_COLUMNS
	_logbook_page.size = reference_size
	_logbook_page.position = Vector2.ZERO
	_logbook_rest_position = Vector2.ZERO
	_the_net_page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_the_net_page.size = reference_size
	_the_net_page.position = Vector2.ZERO
	_the_net_rest_position = Vector2.ZERO
	_mail_page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_mail_page.size = reference_size
	_mail_page.position = Vector2.ZERO
	_mail_rest_position = Vector2.ZERO
	_profile_page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_profile_page.position = Vector2.ZERO
	_profile_page.size = reference_size
	_profile_rest_position = Vector2.ZERO
	_players_page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_players_page.position = Vector2.ZERO
	_players_page.size = reference_size
	_sale_confirmation.size = SALE_CONFIRMATION_SIZE
	_sale_confirmation.position = (
		(reference_size - SALE_CONFIRMATION_SIZE) * 0.5
	)
	_cooler_host.custom_minimum_size = Vector2(
		520.0 if compact else 800.0,
		512.0 if compact else 420.0,
	)
	if not _transitioning:
		_cooler_page.position = _cooler_rest_position
		_bag_page.position = _bag_rest_position
		_tackle_box_page.position = _tackle_rest_position
		_logbook_page.position = _logbook_rest_position
		_the_net_page.position = _the_net_rest_position
		_mail_page.position = _mail_rest_position
		_profile_page.position = _profile_rest_position
		_players_page.position = Vector2.ZERO
		_cooler_page.modulate.a = 1.0
		_bag_page.modulate.a = 1.0
		_tackle_box_page.modulate.a = 1.0
		_logbook_page.modulate.a = 1.0
		_the_net_page.modulate.a = 1.0
		_mail_page.modulate.a = 1.0
		_profile_page.modulate.a = 1.0
		_players_page.modulate.a = 1.0
	_layout_cooler_fish(false)


func _layout_cooler_detail_text(compact: bool) -> void:
	var text_row_height: float = 19.0 if compact else 22.0
	_cooler_quality_label.position = Vector2.ZERO
	_cooler_quality_label.size = Vector2(
		_cooler_detail_stats.size.x,
		text_row_height,
	)
	_cooler_rarity_label.position = Vector2(0.0, text_row_height)
	_cooler_rarity_label.size = Vector2(
		_cooler_detail_stats.size.x,
		text_row_height,
	)
	_cooler_weight_row.position = Vector2(0.0, text_row_height * 2.0)
	_cooler_weight_row.size = Vector2(
		_cooler_detail_stats.size.x,
		24.0 if compact else 28.0,
	)
	_cooler_quality_label.add_theme_font_size_override(
		"font_size",
		13 if compact else 17,
	)
	_cooler_rarity_label.add_theme_font_size_override(
		"font_size",
		13 if compact else 17,
	)
	_cooler_weight_value.add_theme_font_size_override(
		"font_size",
		9 if compact else 12,
	)
	_cooler_weight_unit.add_theme_font_size_override(
		"font_size",
		10 if compact else 14,
	)
	_cooler_offer_value.icon_size = 10.0 if compact else 15.0
	_cooler_offer_value.get_amount_label().add_theme_font_size_override(
		"font_size", 10 if compact else 15
	)


func _layout_cooler_selection_text(compact: bool) -> void:
	var row_height: float = 17.5 if compact else 20.0
	_cooler_selected_count_value.add_theme_font_size_override(
		"font_size", 10 if compact else 14
	)
	_cooler_combined_offer_value.icon_size = 10.0 if compact else 14.0
	_cooler_combined_offer_value.get_amount_label().add_theme_font_size_override(
		"font_size", 10 if compact else 14
	)
	_cooler_selection_empty.add_theme_font_size_override(
		"font_size", 14 if compact else 20
	)
	for word_label: Label in [
		_cooler_selected_count_label,
		_cooler_combined_offer_label,
	]:
		word_label.add_theme_font_size_override(
			"font_size",
			12 if compact else 18,
		)
	_cooler_selected_count_row.position = Vector2.ZERO
	_cooler_selected_count_row.size = Vector2(
		_cooler_selection_summary.size.x,
		row_height,
	)
	_cooler_combined_offer_row.position = Vector2(0.0, row_height)
	_cooler_combined_offer_row.size = Vector2(
		_cooler_selection_summary.size.x,
		row_height,
	)


func _begin_menu_entry() -> void:
	_transitioning = true
	_set_shell_interactive(false)
	_reset_page_transition_visuals()
	_animate_inventory_tab_entry()
	set_process(true)
	var generation: int = _transition_generation
	_presentation_scale_root.pivot_offset = (
		_presentation_scale_root.size * 0.5
	)
	_presentation_scale_root.modulate.a = 0.0
	_presentation_scale_root.scale = (
		Vector2.ONE * UIMotion.PLAYER_MENU_ENTER_SCALE
	)
	_presentation_tween = create_tween().set_parallel(true)
	_presentation_tween.tween_property(
		_presentation_scale_root,
		"modulate:a",
		1.0,
		UIMotion.PLAYER_MENU_ENTER_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_presentation_tween.tween_property(
		_presentation_scale_root,
		"scale",
		Vector2.ONE,
		UIMotion.PLAYER_MENU_ENTER_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_presentation_tween.chain().tween_callback(
		_finish_menu_entry.bind(generation)
	)


func _finish_menu_entry(generation: int) -> void:
	if generation != _transition_generation or not visible:
		return
	_presentation_tween = null
	_transitioning = false
	_set_shell_interactive(true)
	_reset_controller_zone_for_section()


func _begin_menu_exit(reason: CloseReason, restore_controls: bool) -> void:
	if reason != CloseReason.USER:
		_finish_close(reason, restore_controls, _menu_generation)
		return
	_transition_generation += 1
	_cancel_presentation_tween()
	_transitioning = true
	_set_shell_interactive(false)
	_settle_inventory_tabs_for_close()
	if _current_section == Section.LOGBOOK:
		_catalog_logbook.deactivate()
	elif _current_section == Section.NET:
		_the_net_page.deactivate()
	var current_viewport: Viewport = get_viewport()
	if current_viewport != null:
		current_viewport.gui_release_focus()
	var generation: int = _transition_generation
	var closing_generation: int = _menu_generation
	_presentation_tween = create_tween().set_parallel(true)
	_presentation_tween.tween_property(
		_presentation_scale_root,
		"modulate:a",
		0.0,
		UIMotion.PLAYER_MENU_EXIT_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_presentation_tween.tween_property(
		_presentation_scale_root,
		"scale",
		Vector2.ONE * UIMotion.PLAYER_MENU_EXIT_SCALE,
		UIMotion.PLAYER_MENU_EXIT_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_presentation_tween.chain().tween_callback(
		_finish_menu_exit.bind(
			generation,
			reason,
			restore_controls,
			closing_generation,
		)
	)


func _finish_menu_exit(
	generation: int,
	reason: CloseReason,
	restore_controls: bool,
	closing_generation: int,
) -> void:
	if generation != _transition_generation or not visible:
		return
	_presentation_tween = null
	_finish_close(reason, restore_controls, closing_generation)


func _finish_close(
	reason: CloseReason,
	restore_controls: bool,
	closing_generation: int,
) -> void:
	_cancel_presentation_tween()
	_cancel_page_tween()
	_the_net_page.deactivate()
	_transitioning = false
	_page_transitioning = false
	_bag_drag_active = false
	_cancel_active_item_move()
	_set_inventory_notepad_visible(Section.BAG, false)
	_set_inventory_notepad_visible(Section.TACKLE_BOX, false)
	_hide_inventory_context_tooltip()
	_reset_page_transition_visuals()
	_presentation_scale_root.modulate.a = 1.0
	_presentation_scale_root.scale = Vector2.ONE
	visible = false
	set_process(false)
	var current_viewport: Viewport = get_viewport()
	if current_viewport != null:
		current_viewport.gui_release_focus()
	if _fishing_spot != null and is_instance_valid(_fishing_spot):
		_fishing_spot.set_local_menu_input_suppressed(INPUT_OWNER, false)
	if restore_controls:
		_restore_player_controls(closing_generation)
	else:
		_control_snapshot_stored = false
	_apply_mouse_close_policy(reason)
	_menu_generation += 1
	_transition_generation += 1
	menu_visibility_changed.emit(false)


func _get_section_root(section: Section) -> Control:
	match section:
		Section.COOLER:
			return _cooler_page
		Section.BAG:
			return _bag_page
		Section.TACKLE_BOX:
			return _tackle_box_page
		Section.LOGBOOK:
			return _logbook_page
		Section.NET:
			return _the_net_page
		Section.MAIL:
			return _mail_page
		Section.PROFILE:
			return _profile_page
		_:
			return _players_page


func _get_section_rest_position(section: Section) -> Vector2:
	match section:
		Section.COOLER:
			return _cooler_rest_position
		Section.BAG:
			return _bag_rest_position
		Section.TACKLE_BOX:
			return _tackle_rest_position
		Section.LOGBOOK:
			return _logbook_rest_position
		Section.NET:
			return _the_net_rest_position
		Section.MAIL:
			return _mail_rest_position
		Section.PROFILE:
			return _profile_rest_position
		_:
			return Vector2.ZERO


func _begin_page_transition(section: Section) -> void:
	_page_transition_generation += 1
	_cancel_page_tween()
	_page_transitioning = true
	_set_content_interactive(false)
	var current_viewport: Viewport = get_viewport()
	if current_viewport != null:
		current_viewport.gui_release_focus()
	var outgoing_section: Section = _current_section
	var outgoing_inventory: bool = _is_inventory_section(outgoing_section)
	var incoming_inventory: bool = _is_inventory_section(section)
	if outgoing_inventory and not incoming_inventory:
		_settle_inventory_tabs_for_close()
	_set_navigation_target(section)
	var generation: int = _page_transition_generation
	_page_outgoing_content_root = _get_section_root(outgoing_section)
	_page_outgoing_root = (
		_inventory_transition_group
		if outgoing_inventory and not incoming_inventory
		else _page_outgoing_content_root
	)
	_page_incoming_root = (
		_inventory_transition_group
		if incoming_inventory and not outgoing_inventory
		else _get_section_root(section)
	)
	var outgoing_rest: Vector2 = _get_section_rest_position(outgoing_section)
	var incoming_rest: Vector2 = _get_section_rest_position(section)
	_show_section_immediate(section)
	if outgoing_inventory and not incoming_inventory:
		# Immediate page selection hides Inventory. Restore the outgoing content
		# beneath its still-opaque masking group for the coordinated fade-out.
		_page_outgoing_content_root.visible = true
		_inventory_sub_tabs.visible = true
	_inventory_transition_group.visible = true
	_page_outgoing_root.visible = true
	_page_incoming_root.visible = true
	_page_outgoing_root.position = outgoing_rest
	_page_incoming_root.position = incoming_rest
	_page_outgoing_root.modulate.a = 1.0
	_page_incoming_root.modulate.a = 0.0
	if incoming_inventory and not outgoing_inventory:
		_animate_inventory_tab_entry()
	var duration: float = (
		UIMotion.PLAYER_MENU_INVENTORY_DURATION
		if outgoing_inventory and incoming_inventory
		else UIMotion.PLAYER_MENU_PAGE_DURATION
	)
	_page_tween = create_tween().set_parallel(true)
	_page_tween.tween_property(
		_page_outgoing_root,
		"modulate:a",
		0.0,
		duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_page_tween.tween_property(
		_page_incoming_root,
		"modulate:a",
		1.0,
		duration,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_page_tween.finished.connect(
		_finish_page_transition.bind(generation),
		CONNECT_ONE_SHOT
	)


func _finish_page_transition(generation: int) -> void:
	if generation != _page_transition_generation or not visible:
		return
	_page_tween = null
	_page_transitioning = false
	if (
		_page_outgoing_root != null
		and _page_outgoing_root != _page_incoming_root
		and _page_outgoing_root != _inventory_transition_group
	):
		_page_outgoing_root.visible = false
	if (
		_page_outgoing_content_root != null
		and not _is_inventory_section(_current_section)
	):
		_page_outgoing_content_root.visible = false
	_inventory_sub_tabs.visible = _is_inventory_section(_current_section)
	_inventory_sub_tabs.modulate.a = 1.0
	_reset_page_transition_visuals()
	_set_content_interactive(true)
	_reset_controller_zone_for_section()


func _set_shell_interactive(interactive: bool) -> void:
	_set_content_interactive(interactive)
	var inventory_notepad_active: bool = (
		_controller_ownership == ControllerOwnership.NOTEPAD_ACTIONS
		and _current_section in [Section.BAG, Section.TACKLE_BOX]
	)
	for bubble: BubbleButtonType in [
		_inventory_tab,
		_logbook_tab,
		_the_net_tab,
		_mail_tab,
		_profile_tab,
		_players_tab,
		_close_button,
	]:
		bubble.focus_mode = (
			Control.FOCUS_ALL
			if interactive and not inventory_notepad_active
			else Control.FOCUS_NONE
		)
		bubble.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if interactive
			else Control.MOUSE_FILTER_IGNORE
		)


func _set_content_interactive(interactive: bool) -> void:
	_content_interactive_enabled = interactive
	_cooler_page.mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if interactive and _current_section == Section.COOLER
		else Control.MOUSE_FILTER_IGNORE
	)
	_bag_page.mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if interactive and _current_section == Section.BAG
		else Control.MOUSE_FILTER_IGNORE
	)
	_tackle_box_page.mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if interactive and _current_section == Section.TACKLE_BOX
		else Control.MOUSE_FILTER_IGNORE
	)
	for tab: Button in [
		_cooler_sub_tab,
		_bag_sub_tab,
		_items_sub_tab,
		_tackle_sub_tab,
	]:
		var tab_interactive: bool = (
			interactive and _is_inventory_section(_current_section)
		)
		tab.focus_mode = (
			Control.FOCUS_ALL
			if (
				tab_interactive
				and _controller_ownership
				== ControllerOwnership.INVENTORY_TABS
			)
			else Control.FOCUS_NONE
		)
		tab.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if tab_interactive and not tab.button_pressed
			else Control.MOUSE_FILTER_IGNORE
		)
	_logbook_page.mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if interactive and _current_section == Section.LOGBOOK
		else Control.MOUSE_FILTER_IGNORE
	)
	_catalog_logbook.set_interactive(
		interactive and _current_section == Section.LOGBOOK
	)
	_the_net_page.set_interactive(
		interactive and _current_section == Section.NET
	)
	_mail_page.set_interactive(
		interactive and _current_section == Section.MAIL
	)
	_profile_page.set_interactive(
		interactive and _current_section == Section.PROFILE
	)
	_players_page.set_interactive(
		interactive and _current_section == Section.PLAYERS
	)
	var cooler_interactive: bool = (
		interactive and _current_section == Section.COOLER
	)
	_cooler_sort_option.disabled = not cooler_interactive
	_cooler_sort_direction.disabled = not cooler_interactive
	_cooler_sort_option.refresh_ink_state()
	_cooler_sort_direction.refresh_ink_state()
	for fish_node: CoolerFishSpriteType in _fish_nodes.values():
		fish_node.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if cooler_interactive
			else Control.MOUSE_FILTER_IGNORE
		)
	var detail_interactive: bool = (
		cooler_interactive and _detail_constellation.visible
	)
	for action: NotepadInkActionType in [
		_favorite_bubble,
		_sell_bubble,
	]:
		var action_interactive: bool = detail_interactive and not action.disabled
		action.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if action_interactive
			else Control.MOUSE_FILTER_IGNORE
		)
		action.refresh_ink_state()
	var bag_interactive: bool = (
		interactive
		and _current_section == Section.BAG
		and not _bag_drag_active
		and _controller_ownership != ControllerOwnership.NOTEPAD_ACTIONS
	)
	for item_node: BagItemSpriteType in _bag_item_nodes.values():
		item_node.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if bag_interactive
			else Control.MOUSE_FILTER_IGNORE
		)
	if _general_inventory_grid != null:
		for slot: GeneralInventorySlotType in _general_inventory_grid.get_slots():
			slot.mouse_filter = (
				Control.MOUSE_FILTER_STOP
				if bag_interactive else Control.MOUSE_FILTER_IGNORE
			)
	var tackle_interactive: bool = (
		interactive and _current_section == Section.TACKLE_BOX
	)
	_apply_tackle_interactivity(tackle_interactive)
	_refresh_inventory_modal_interactivity()
	_apply_inventory_controller_zone_focus_modes()


func _cancel_presentation_tween() -> void:
	if _presentation_tween != null:
		_presentation_tween.kill()
		_presentation_tween = null


func _cancel_page_tween() -> void:
	if _page_tween != null:
		_page_tween.kill()
		_page_tween = null
	_reset_page_transition_visuals()


func _reset_page_transition_visuals() -> void:
	for section: Section in [
		Section.COOLER,
		Section.BAG,
		Section.TACKLE_BOX,
		Section.LOGBOOK,
		Section.NET,
		Section.MAIL,
		Section.PROFILE,
		Section.PLAYERS,
	]:
		var page: Control = _get_section_root(section)
		page.position = _get_section_rest_position(section)
		page.modulate.a = 1.0
	if _inventory_transition_group != null:
		_inventory_transition_group.modulate.a = 1.0
		_inventory_transition_group.visible = true
	_inventory_sub_tabs.modulate.a = 1.0
	_page_outgoing_root = null
	_page_incoming_root = null
	_page_outgoing_content_root = null


func _on_cooler_sort_selected(sort_id: int) -> void:
	_sort_mode = sort_id as SortMode
	_cooler_sort_option.select(_sort_mode)
	_refresh_inventory()


func _on_sort_direction_pressed() -> void:
	_sort_descending = not _sort_descending
	_update_sort_direction_text()
	_refresh_inventory()


func _update_sort_direction_text() -> void:
	var direction_text: String
	match _sort_mode:
		SortMode.CATCH_ORDER:
			if _compact_layout:
				direction_text = "newest" if _sort_descending else "oldest"
			else:
				direction_text = (
					"newest first" if _sort_descending else "oldest first"
				)
		SortMode.NAME:
			direction_text = "z–a" if _sort_descending else "a–z"
		SortMode.RARITY:
			if _compact_layout:
				direction_text = "high–low" if _sort_descending else "low–high"
			else:
				direction_text = (
					"high to low" if _sort_descending else "low to high"
				)
	_cooler_sort_direction.text = direction_text


func _refresh_all() -> void:
	_refresh_economy_summary()
	_refresh_inventory()
	_refresh_bag()


func _on_bag_changed() -> void:
	_refresh_bag()
	_refresh_tackle_box()


func _on_hotbar_changed() -> void:
	_update_bag_detail()
	_update_tackle_detail()


func _refresh_bag() -> void:
	if not is_node_ready():
		return
	for item_node: BagItemSpriteType in _bag_item_nodes.values():
		if is_instance_valid(item_node):
			item_node.queue_free()
	_bag_item_nodes.clear()
	for slot: BagStorageSlotType in _bag_slot_nodes:
		if is_instance_valid(slot):
			slot.queue_free()
	_bag_slot_nodes.clear()
	_bag_empty_state.visible = false
	if _general_inventory_grid != null:
		_general_inventory_grid.refresh()
		call_deferred("_layout_general_inventory_grid")
	if (
		not _selected_inventory_identity.is_empty()
		and _inventory_layout != null
		and _inventory_layout.get_container(
			_selected_inventory_kind,
			_selected_inventory_identity,
		) != PlayerInventoryLayout.InventoryContainer.INVENTORY
	):
		_selected_inventory_kind = -1
		_selected_inventory_identity = StringName()
		_selected_bag_item_id = StringName()
	_update_bag_detail()


func _layout_general_inventory_grid() -> void:
	if _general_inventory_grid == null or not is_instance_valid(_general_inventory_grid):
		return
	var available_size: Vector2 = _bag_item_field.size
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		available_size = _bag_host.size
	var grid_size: Vector2 = _general_inventory_grid.custom_minimum_size
	# Center against the canonical stage rather than the ScrollContainer's
	# left-aligned content host. Container margins and its reserved scrollbar
	# gutter otherwise compound into a visible leftward offset.
	var field_transform := _bag_item_field.get_global_transform_with_canvas()
	var stage_transform := (
		_presentation_scale_root.get_global_transform_with_canvas()
	)
	var field_center_global := field_transform * (available_size * 0.5)
	var stage_center_global := stage_transform * Vector2(
		DESKTOP_REFERENCE_SIZE.x * 0.5,
		0.0,
	)
	var desired_center_in_field := field_transform.affine_inverse() * Vector2(
		stage_center_global.x,
		field_center_global.y,
	)
	_general_inventory_grid.size = grid_size
	_general_inventory_grid.position = Vector2(
		maxf(
			0.0,
			desired_center_in_field.x - grid_size.x * 0.5,
		),
		maxf(0.0, (available_size.y - grid_size.y) * 0.5),
	)


func _on_general_inventory_entry_selected(
	kind: int,
	identity: StringName,
) -> void:
	_selected_inventory_kind = kind
	_selected_inventory_identity = identity
	_selected_bag_item_id = (
		identity if kind == PlayerInventoryLayout.EntryKind.ITEM
		else StringName()
	)
	_update_bag_detail()


func _on_general_inventory_slot_activated(
	slot: GeneralInventorySlotType,
) -> void:
	if (
		slot == null
		or slot.disabled
		or _controller_ownership == ControllerOwnership.NOTEPAD_ACTIONS
	):
		return
	if _inventory_move_identity.is_empty():
		if slot.entry_identity.is_empty():
			return
		_inventory_move_kind = slot.entry_kind
		_inventory_move_identity = slot.entry_identity
		_selected_inventory_kind = slot.entry_kind
		_selected_inventory_identity = slot.entry_identity
		_selected_bag_item_id = (
			slot.entry_identity
			if slot.entry_kind == PlayerInventoryLayout.EntryKind.ITEM
			else StringName()
		)
		slot.set_move_source(true)
		_show_inventory_context_tooltip(
			slot,
			"moving %s\nchoose a slot • B cancels" % _inventory_entry_name(
				slot.entry_kind,
				slot.entry_identity,
			),
		)
		return
	var move_kind: int = _inventory_move_kind
	var move_identity: StringName = _inventory_move_identity
	_cancel_inventory_move(false)
	if _inventory_layout == null:
		return
	_inventory_layout.move_entry(
		move_kind,
		move_identity,
		PlayerInventoryLayout.InventoryContainer.INVENTORY,
		slot.slot_index,
	)


func _open_general_inventory_notepad(
	slot: GeneralInventorySlotType,
) -> void:
	if slot == null or slot.entry_identity.is_empty():
		return
	_cancel_active_item_move()
	_on_general_inventory_entry_selected(slot.entry_kind, slot.entry_identity)
	_open_inventory_notepad(
		Section.BAG,
		slot.entry_identity,
		_get_bag_notepad_actions(),
	)


func _get_bag_notepad_actions() -> Array[BaseButton]:
	var actions: Array[BaseButton] = []
	if _selected_inventory_kind != PlayerInventoryLayout.EntryKind.CATCH:
		return actions
	if _bag_favorite_button.visible and not _bag_favorite_button.disabled:
		actions.append(_bag_favorite_button)
	if _bag_sell_button.visible and not _bag_sell_button.disabled:
		actions.append(_bag_sell_button)
	return actions


func _inventory_entry_name(kind: int, identity: StringName) -> String:
	if kind == PlayerInventoryLayout.EntryKind.ITEM:
		var item: ItemDataType = (
			_item_catalog.get_item_by_id(identity)
			if _item_catalog != null else null
		)
		return item.display_name if item != null else str(identity)
	var fish_catch: FishCatchType = (
		_inventory.get_catch_by_id(identity)
		if _inventory != null else null
	)
	return (
		FishQualityType.qualified_name(
			fish_catch.fish.display_name,
			fish_catch.quality,
		)
		if fish_catch != null else str(identity)
	)


func _cancel_inventory_move(hide_tooltip: bool = true) -> bool:
	if _inventory_move_identity.is_empty():
		return false
	_inventory_move_kind = -1
	_inventory_move_identity = StringName()
	if _general_inventory_grid != null:
		for slot: GeneralInventorySlotType in _general_inventory_grid.get_slots():
			slot.set_move_source(false)
	if hide_tooltip:
		_hide_inventory_context_tooltip()
	return true


func _cancel_active_item_move() -> bool:
	var canceled: bool = _cancel_inventory_move()
	if not _tackle_move_identity.is_empty():
		_tackle_move_identity = StringName()
		_refresh_tackle_move_presentation()
		_hide_inventory_context_tooltip()
		canceled = true
	return canceled


func _open_inventory_notepad(
	section: Section,
	identity: StringName,
	actions: Array[BaseButton],
) -> void:
	_controller_source_section = section
	_controller_source_identity = identity
	_controller_notepad_actions = actions
	_controller_ownership = ControllerOwnership.NOTEPAD_ACTIONS
	_set_inventory_notepad_visible(section, true)
	_hide_inventory_context_tooltip()
	_apply_inventory_controller_zone_focus_modes()
	_refresh_inventory_modal_interactivity()
	if not actions.is_empty():
		_configure_controller_notepad_action_focus(actions)
		actions.front().call_deferred("grab_focus")


func _set_inventory_notepad_visible(section: Section, shown: bool) -> void:
	if section == Section.BAG:
		_bag_detail_constellation.visible = shown
		_bag_modal_blocker.visible = shown
	elif section == Section.TACKLE_BOX:
		_tackle_detail_panel.visible = shown
		_tackle_modal_blocker.visible = shown


func _refresh_inventory_modal_interactivity() -> void:
	var modal_active: bool = (
		visible
		and _controller_ownership == ControllerOwnership.NOTEPAD_ACTIONS
		and _current_section in [Section.BAG, Section.TACKLE_BOX]
	)
	for navigation_button: BubbleButtonType in [
		_inventory_tab,
		_logbook_tab,
		_the_net_tab,
		_mail_tab,
		_profile_tab,
		_players_tab,
		_close_button,
	]:
		navigation_button.focus_mode = (
			Control.FOCUS_NONE
			if modal_active
			else (
				Control.FOCUS_ALL
				if _content_interactive_enabled and visible
				else Control.FOCUS_NONE
			)
		)
	var bag_interactive: bool = (
		_content_interactive_enabled
		and visible
		and _current_section == Section.BAG
		and _controller_ownership != ControllerOwnership.NOTEPAD_ACTIONS
	)
	if _general_inventory_grid != null:
		for slot: GeneralInventorySlotType in _general_inventory_grid.get_slots():
			slot.mouse_filter = (
				Control.MOUSE_FILTER_STOP
				if bag_interactive else Control.MOUSE_FILTER_IGNORE
			)
	var bag_action_interactive: bool = (
		_content_interactive_enabled
		and visible
		and _current_section == Section.BAG
		and _controller_ownership == ControllerOwnership.NOTEPAD_ACTIONS
	)
	for action: NotepadInkActionType in [
		_bag_favorite_button,
		_bag_sell_button,
	]:
		action.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if bag_action_interactive and action.visible and not action.disabled
			else Control.MOUSE_FILTER_IGNORE
		)
		action.refresh_ink_state()
	_apply_tackle_interactivity(
		_content_interactive_enabled
		and visible
		and _current_section == Section.TACKLE_BOX
	)


func _sync_bag_item_nodes(owned_items: Array[OwnedItemType]) -> void:
	var retained: Dictionary[StringName, bool] = {}
	for owned: OwnedItemType in owned_items:
		var item: ItemDataType = _item_catalog.get_item_by_id(owned.item_id)
		if item == null:
			continue
		retained[owned.item_id] = true
		var item_node := _bag_item_nodes.get(
			owned.item_id
		) as BagItemSpriteType
		if item_node == null:
			item_node = BagItemSpriteScene.instantiate()
			_bag_item_field.add_child(item_node)
			_bag_item_nodes[owned.item_id] = item_node
			item_node.pressed.connect(
				_select_bag_item.bind(owned.item_id)
			)
			item_node.focus_entered.connect(
				_select_bag_item.bind(owned.item_id)
			)
			item_node.drag_started.connect(_on_bag_drag_started)
			item_node.drag_finished.connect(_on_bag_drag_finished)
		var identity_hash: int = absi(String(owned.item_id).hash())
		item_node.configure_item(
			item.item_id,
			item.display_name,
			item.icon,
			owned.quantity,
			item.hotbar_allowed,
			float(identity_hash % 628) / 100.0,
			0.97 + float(identity_hash % 7) * 0.01,
		)
		item_node.tooltip_text = (
			"drag to another storage slot or the hotbar."
			if item.hotbar_allowed
			else "drag to another storage slot."
		)
		item_node.disabled = false
		item_node.set_selected(item.item_id == _selected_bag_item_id)
	for item_id: StringName in _bag_item_nodes.keys():
		if retained.has(item_id):
			continue
		var removed := _bag_item_nodes[item_id] as BagItemSpriteType
		_bag_item_nodes.erase(item_id)
		_release_focus_from(removed, _active_bag_tab())
		removed.queue_free()
	_layout_bag_items()
	_configure_bag_item_focus()


func _layout_bag_items() -> void:
	if not is_node_ready():
		return
	_bag_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var columns: int = BAG_STORAGE_COLUMNS
	var cell_size := (
		Vector2(102.0, 48.0)
		if _compact_layout
		else Vector2(154.0, 110.0)
	)
	var slot_size := (
		Vector2(90.0, 40.0)
		if _compact_layout
		else Vector2(140.0, 96.0)
	)
	var item_size := (
		Vector2(78.0, 36.0)
		if _compact_layout
		else Vector2(122.0, 82.0)
	)
	var origin := (
		Vector2(5.0, 4.0)
		if _compact_layout
		else Vector2(10.0, 9.0)
	)
	var highest_slot: int = -1
	for owned: OwnedItemType in _sorted_bag_items:
		highest_slot = maxi(highest_slot, owned.storage_slot)
	var slot_count: int = maxi(
		BAG_STORAGE_MINIMUM_SLOTS,
		highest_slot + 1,
	)
	slot_count = ceili(float(slot_count) / float(columns)) * columns
	var required_rows: int = ceili(float(slot_count) / float(columns))
	var content_size := Vector2(
		520.0 if _compact_layout else 788.0,
		maxf(
			152.0 if _compact_layout else 358.0,
			origin.y * 2.0 + float(required_rows) * cell_size.y,
		),
	)
	_bag_host.custom_minimum_size = content_size
	_bag_item_field.custom_minimum_size = content_size
	_sync_bag_storage_slots(
		slot_count,
		columns,
		cell_size,
		slot_size,
		origin,
	)
	for owned: OwnedItemType in _sorted_bag_items:
		var item_node := _bag_item_nodes.get(
			owned.item_id
		) as BagItemSpriteType
		if item_node == null or owned.storage_slot < 0:
			continue
		var column: int = owned.storage_slot % columns
		var row: int = floori(float(owned.storage_slot) / float(columns))
		var slot_position := origin + Vector2(
			float(column) * cell_size.x,
			float(row) * cell_size.y,
		)
		item_node.custom_minimum_size = item_size
		item_node.size = item_size
		item_node.position = (
			slot_position + (slot_size - item_size) * 0.5
		)
		item_node.z_index = 1


func _sync_bag_storage_slots(
	slot_count: int,
	columns: int,
	cell_size: Vector2,
	slot_size: Vector2,
	origin: Vector2,
) -> void:
	for slot: BagStorageSlotType in _bag_slot_nodes:
		if is_instance_valid(slot):
			slot.queue_free()
	_bag_slot_nodes.clear()
	for slot_index: int in slot_count:
		var row: int = floori(float(slot_index) / float(columns))
		var column: int = slot_index % columns
		var slot := BagStorageSlotType.new()
		slot.configure(slot_index)
		slot.size = slot_size
		slot.custom_minimum_size = slot_size
		slot.position = origin + Vector2(
			float(column) * cell_size.x,
			float(row) * cell_size.y,
		)
		slot.bag_item_dropped.connect(_on_bag_item_dropped)
		slot.pressed.connect(_on_bag_storage_slot_pressed.bind(slot))
		slot.focus_entered.connect(
			_on_bag_storage_slot_focus_entered.bind(slot)
		)
		_bag_item_field.add_child(slot)
		_bag_item_field.move_child(slot, 0)
		_bag_slot_nodes.append(slot)
	_configure_bag_storage_slot_focus()


func _sync_inventory_slot_visuals(
	parent: Control,
	slots: Array[Panel],
	slot_count: int,
	columns: int,
	cell_size: Vector2,
	slot_size: Vector2,
	origin: Vector2,
	alternate_lane_offset: float,
) -> void:
	for slot: Panel in slots:
		if is_instance_valid(slot):
			slot.queue_free()
	slots.clear()
	var slot_color: Color = UtilityPageStyle.OCEAN_PANEL_MID
	slot_color.a = 0.42
	for index: int in slot_count:
		var row: int = floori(float(index) / float(columns))
		var column: int = index % columns
		var slot := Panel.new()
		slot.name = "InventorySlot%d" % index
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.z_index = -1
		slot.size = slot_size
		slot.position = origin + Vector2(
			float(column) * cell_size.x
			+ (alternate_lane_offset if row % 2 == 1 else 0.0),
			float(row) * cell_size.y,
		)
		slot.add_theme_stylebox_override(
			"panel",
			UtilityPageStyle.rounded_style(slot_color, 14),
		)
		parent.add_child(slot)
		parent.move_child(slot, 0)
		slots.append(slot)


func _configure_bag_item_focus() -> void:
	if _current_section != Section.BAG:
		return
	var active_tab: Button = _active_bag_tab()
	var controls: Array[GeneralInventorySlotType] = (
		_general_inventory_grid.get_slots()
		if _general_inventory_grid != null
		else []
	)
	if controls.is_empty():
		active_tab.focus_neighbor_bottom = NodePath()
		return
	active_tab.focus_neighbor_bottom = active_tab.get_path_to(
		controls.front()
	)
	ControllerFocusNavigationType.configure_spatial_neighbors(controls)


func _configure_bag_storage_slot_focus() -> void:
	for index: int in _bag_slot_nodes.size():
		var slot: BagStorageSlotType = _bag_slot_nodes[index]
		if not is_instance_valid(slot):
			continue
		var column: int = index % BAG_STORAGE_COLUMNS
		var left_index: int = index - 1 if column > 0 else index
		var right_index: int = (
			index + 1
			if (
				column < BAG_STORAGE_COLUMNS - 1
				and index + 1 < _bag_slot_nodes.size()
			)
			else index
		)
		var top_index: int = (
			index - BAG_STORAGE_COLUMNS
			if index >= BAG_STORAGE_COLUMNS else index
		)
		var bottom_index: int = (
			index + BAG_STORAGE_COLUMNS
			if index + BAG_STORAGE_COLUMNS < _bag_slot_nodes.size()
			else index
		)
		slot.focus_neighbor_left = slot.get_path_to(
			_bag_slot_nodes[left_index]
		)
		slot.focus_neighbor_right = slot.get_path_to(
			_bag_slot_nodes[right_index]
		)
		slot.focus_neighbor_top = slot.get_path_to(
			_bag_slot_nodes[top_index]
		)
		slot.focus_neighbor_bottom = slot.get_path_to(
			_bag_slot_nodes[bottom_index]
		)


func _active_bag_tab() -> Button:
	return _bag_sub_tab


func _sort_bag_items(a: OwnedItemType, b: OwnedItemType) -> bool:
	var item_a: ItemDataType = _item_catalog.get_item_by_id(a.item_id)
	var item_b: ItemDataType = _item_catalog.get_item_by_id(b.item_id)
	if item_a == null:
		return false
	if item_b == null:
		return true
	if item_a.category != item_b.category:
		return item_a.category < item_b.category
	return item_a.display_name.naturalnocasecmp_to(item_b.display_name) < 0


func _sort_bag_storage_items(a: OwnedItemType, b: OwnedItemType) -> bool:
	if a.storage_slot >= 0 and b.storage_slot >= 0:
		return a.storage_slot < b.storage_slot
	if a.storage_slot >= 0:
		return true
	if b.storage_slot >= 0:
		return false
	return _sort_bag_items(a, b)


func _sort_tackle_items(a: OwnedItemType, b: OwnedItemType) -> bool:
	if a.storage_slot >= 0 and b.storage_slot >= 0:
		return a.storage_slot < b.storage_slot
	if a.storage_slot >= 0:
		return true
	if b.storage_slot >= 0:
		return false
	var order_a := FishingShopStockType.get_stock_order_index(a.item_id)
	var order_b := FishingShopStockType.get_stock_order_index(b.item_id)
	if order_a >= 0 and order_b >= 0 and order_a != order_b:
		return order_a < order_b
	if order_a >= 0 and order_b < 0:
		return true
	if order_b >= 0 and order_a < 0:
		return false
	return _sort_bag_items(a, b)


func _select_bag_item(item_id: StringName) -> void:
	if _bag_drag_active or get_viewport().gui_is_dragging():
		return
	_selected_bag_item_id = item_id
	for candidate_id: StringName in _bag_item_nodes:
		var item_node := _bag_item_nodes[candidate_id] as BagItemSpriteType
		item_node.set_selected(candidate_id == item_id)
	_update_bag_detail()


func _update_bag_detail() -> void:
	if _selected_inventory_kind == PlayerInventoryLayout.EntryKind.CATCH:
		var fish_catch: FishCatchType = (
			_inventory.get_catch_by_id(_selected_inventory_identity)
			if _inventory != null else null
		)
		_bag_sprite_detail_texture.texture = (
			fish_catch.fish.display_texture if fish_catch != null else null
		)
		_bag_sprite_detail_name.text = (
			fish_catch.fish.display_name if fish_catch != null else ""
		)
		_bag_sprite_detail_data.text = (
			"quality: %s\nrarity: %s"
			% [
				FishQualityType.display_name(fish_catch.quality),
				fish_catch.fish.get_rarity_name(),
			]
			if fish_catch != null
			else "select an item for details."
		)
		_bag_sprite_detail_value_row.visible = fish_catch != null
		_bag_sprite_detail_weight.text = (
			"%.2f lb" % fish_catch.weight_lb if fish_catch != null else ""
		)
		if fish_catch != null:
			_bag_sprite_detail_value.set_amount(fish_catch.sale_value)
		_update_bag_fish_actions(fish_catch)
		return
	_bag_sprite_detail_value_row.visible = false
	_bag_sprite_detail_weight.text = ""
	_bag_detail_actions.visible = false
	_bag_favorite_button.disabled = true
	_bag_sell_button.disabled = true
	_bag_favorite_button.refresh_ink_state()
	_bag_sell_button.refresh_ink_state()
	var item: ItemDataType = (
		_item_catalog.get_item_by_id(_selected_bag_item_id)
		if _item_catalog != null and not _selected_bag_item_id.is_empty()
		else null
	)
	var quantity: int = (
		_bag.get_quantity(_selected_bag_item_id)
		if _bag != null and item != null
		else 0
	)
	var hotbar_assignment: String = "not assigned"
	if item != null and _hotbar != null:
		for slot_index: int in range(PlayerHotbarType.SLOT_COUNT):
			if _hotbar.get_item_id(slot_index) == item.item_id:
				hotbar_assignment = "hotbar slot %d" % (slot_index + 1)
				break
	var item_state: String = ""
	if item != null:
		if item.equippable:
			item_state = "equippable"
		elif item.usable:
			item_state = "usable"
	_bag_sprite_detail_texture.texture = null
	if item != null:
		_bag_sprite_detail_texture.texture = item.icon
	_bag_sprite_detail_name.text = (
		item.display_name if item != null else ""
	)
	_bag_sprite_detail_data.text = (
		"%s • quantity: %d\n%s • %s\n%s"
		% [
			_item_category_display_name(item),
			quantity,
			item_state,
			hotbar_assignment,
			item.description,
		]
		if item != null
		else "select an item for details."
	)


func _update_bag_fish_actions(fish_catch: FishCatchType) -> void:
	_bag_detail_actions.visible = fish_catch != null
	_bag_favorite_button.visible = fish_catch != null
	_bag_sell_button.visible = fish_catch != null
	if fish_catch == null:
		_bag_favorite_button.disabled = true
		_bag_sell_button.disabled = true
		_bag_favorite_button.refresh_ink_state()
		_bag_sell_button.refresh_ink_state()
		return
	_bag_favorite_button.disabled = false
	_bag_favorite_button.text = (
		"unfavorite" if fish_catch.is_favorited else "favorite"
	)
	_bag_favorite_button.persistent_mark = fish_catch.is_favorited
	var active_buyer: FishBuyerProfileType = _get_active_sale_buyer()
	var sale_available: bool = (
		not _sale_in_progress
		and _network_sale_service != null
		and active_buyer != null
		and _network_sale_service.can_request_sale(active_buyer.id)
		and _sale_service != null
	)
	if sale_available:
		var preview: FishSaleResultType = _sale_service.preview_batch(
			[fish_catch.catch_id],
			active_buyer,
		)
		sale_available = preview != null and preview.is_success()
	_bag_sell_button.text = "sell"
	_bag_sell_button.disabled = not sale_available
	_bag_favorite_button.refresh_ink_state()
	_bag_sell_button.refresh_ink_state()
	_refresh_inventory_modal_interactivity()


func _on_bag_favorite_pressed() -> void:
	if (
		_inventory == null
		or _selected_inventory_kind
		!= PlayerInventoryLayout.EntryKind.CATCH
		or _selected_inventory_identity.is_empty()
	):
		return
	var fish_catch: FishCatchType = _inventory.get_catch_by_id(
		_selected_inventory_identity
	)
	if fish_catch == null:
		return
	if not _inventory.set_catch_favorited(
		fish_catch.catch_id,
		not fish_catch.is_favorited,
	):
		return
	_update_bag_detail()
	_controller_notepad_actions = _get_bag_notepad_actions()
	_configure_controller_notepad_action_focus(_controller_notepad_actions)


func _on_bag_sell_pressed() -> void:
	if (
		_selected_inventory_kind
		!= PlayerInventoryLayout.EntryKind.CATCH
		or _selected_inventory_identity.is_empty()
	):
		return
	_begin_sale_confirmation([_selected_inventory_identity])


func _item_category_display_name(item: ItemDataType) -> String:
	if item.category == ItemDataType.Category.CONSUMABLE:
		return "item"
	return item.get_category_name()


func _close_bag_detail() -> void:
	_bag_sprite_detail_value_row.visible = false
	_set_inventory_notepad_visible(Section.BAG, false)


func _on_bag_field_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and not get_viewport().gui_is_dragging()
	):
		_selected_bag_item_id = StringName()
		for item_node: BagItemSpriteType in _bag_item_nodes.values():
			item_node.set_selected(false)
		_update_bag_detail()


func _on_bag_drag_started() -> void:
	_bag_drag_active = true
	_close_bag_detail()
	_set_content_interactive(false)


func _on_bag_item_dropped(item_id: StringName, slot_index: int) -> void:
	if _bag == null or item_id.is_empty() or slot_index < 0:
		return
	if _bag.move_item_to_storage_slot(item_id, slot_index):
		_select_bag_item(item_id)


func _on_bag_storage_slot_pressed(slot: BagStorageSlotType) -> void:
	if (
		_controller_ownership == ControllerOwnership.STORAGE_PLACEMENT
		and slot != null
	):
		_confirm_controller_storage_placement()


func _on_bag_storage_slot_focus_entered(slot: BagStorageSlotType) -> void:
	if _controller_ownership != ControllerOwnership.STORAGE_PLACEMENT:
		return
	var texture := _controller_storage_texture()
	for candidate: BagStorageSlotType in _bag_slot_nodes:
		if is_instance_valid(candidate):
			candidate.set_placement_preview(texture, candidate == slot)


func _controller_storage_texture() -> Texture2D:
	var item: ItemDataType = (
		_item_catalog.get_item_by_id(_controller_storage_identity)
		if (
			_item_catalog != null
			and not _controller_storage_identity.is_empty()
		)
		else null
	)
	return item.icon if item != null else null


func _on_bag_drag_finished() -> void:
	_bag_drag_active = false
	if visible and _current_section == Section.BAG:
		_set_content_interactive(
			not _transitioning and not _page_transitioning
		)


func _on_inventory_changed() -> void:
	_refresh_economy_summary()
	_revalidate_confirmation()
	_refresh_inventory()


func _on_wallet_balance_changed(
	_new_balance: int,
	_delta: int,
) -> void:
	_refresh_economy_summary()


func _refresh_economy_summary() -> void:
	if not is_node_ready():
		return
	var balance: int = _wallet.get_balance() if _wallet != null else 0
	var held_total: int = (
		_inventory.get_total_sale_value()
		if _inventory != null
		else 0
	)
	_notepad_wallet_value.set_amount(balance)
	_notepad_capacity_value.text = "%d / %d" % [
		_inventory.get_all_catches().size() if _inventory != null else 0,
		_cooler_capacity.get_capacity() if _cooler_capacity != null else 0,
	]


func _on_cooler_capacity_changed(_level: int, _capacity: int) -> void:
	_refresh_economy_summary()


func _refresh_inventory() -> void:
	if not is_node_ready():
		return
	var catches: Array[FishCatchType] = []
	if _inventory != null:
		for fish_catch: FishCatchType in _inventory.get_all_catches():
			if fish_catch != null and fish_catch.is_valid():
				catches.append(fish_catch)
	catches.sort_custom(_compare_catches)
	_sorted_catches = catches
	var visible_ids: Array[StringName] = []
	for fish_catch: FishCatchType in catches:
		visible_ids.append(fish_catch.catch_id)
	_fish_selection.set_visible_order(visible_ids)

	_sync_cooler_fish_nodes(catches)
	var selected: FishCatchType = (
		_inventory.get_catch(_fish_selection.get_focused_id())
		if _inventory != null
		else null
	)
	_update_sale_summary()
	_update_inventory_detail(selected)
	_update_sort_direction_text()


func _sync_cooler_fish_nodes(catches: Array[FishCatchType]) -> void:
	var retained: Dictionary[StringName, bool] = {}
	for fish_catch: FishCatchType in catches:
		retained[fish_catch.catch_id] = true
		var fish_node := _fish_nodes.get(
			fish_catch.catch_id
		) as CoolerFishSpriteType
		var is_new: bool = fish_node == null
		if is_new:
			fish_node = CoolerFishSpriteScene.instantiate()
			_fish_field.add_child(fish_node)
			_fish_nodes[fish_catch.catch_id] = fish_node
			fish_node.set_meta("new_cooler_fish", true)
			fish_node.pressed.connect(
				_on_catch_card_pressed.bind(fish_catch.catch_id)
			)
			fish_node.focus_entered.connect(
				_on_catch_card_focused.bind(fish_catch.catch_id)
			)
		var identity_hash: int = absi(String(fish_catch.catch_id).hash())
		fish_node.configure(
			fish_catch.catch_id,
			FishQualityType.qualified_name(
				fish_catch.fish.display_name,
				fish_catch.quality,
			),
			fish_catch.fish.display_texture,
			float(identity_hash % 628) / 100.0,
			0.96 + float(identity_hash % 9) * 0.01,
			UIPalette.get_quality_color(fish_catch.quality),
		)
		fish_node.set_item_state(
			_fish_selection.is_selected(fish_catch.catch_id),
			fish_catch.catch_id == _fish_selection.get_focused_id(),
			fish_catch.is_favorited,
		)
	for catch_id: StringName in _fish_nodes.keys():
		if retained.has(catch_id):
			continue
		var removed := _fish_nodes[catch_id] as CoolerFishSpriteType
		_fish_nodes.erase(catch_id)
		_release_focus_from(removed, _inventory_tab)
		removed.queue_free()
	_layout_cooler_fish(true)
	_configure_cooler_fish_focus()


func _layout_cooler_fish(animate: bool = true) -> void:
	if not is_node_ready():
		return
	var columns: int = 3 if _compact_layout else 9
	var cell_size := (
		Vector2(68.0, 58.0) if _compact_layout else Vector2(84.0, 80.0)
	)
	var fish_size := (
		Vector2(52.0, 52.0) if _compact_layout else Vector2(72.0, 72.0)
	)
	var visible_field_size := (
		Vector2(218.0, 124.0)
		if _compact_layout
		else Vector2(800.0, 280.0)
	)
	var side_margin: float = 2.0 if _compact_layout else 8.0
	var top_margin: float = 4.0 if _compact_layout else 6.0
	var slot_count: int = maxi(
		_sorted_catches.size(),
		_cooler_capacity.get_capacity() if _cooler_capacity != null else 0,
	)
	var required_rows: int = ceili(
		float(slot_count) / float(columns)
	) if slot_count > 0 else 0
	var required_height: float = (
		top_margin * 2.0 + float(required_rows) * cell_size.y
	)
	var content_size := Vector2(
		visible_field_size.x,
		maxf(visible_field_size.y, required_height),
	)
	_cooler_host.custom_minimum_size = content_size
	_fish_field.custom_minimum_size = content_size
	_cooler_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_sync_inventory_slot_visuals(
		_fish_field,
		_cooler_slot_nodes,
		slot_count,
		columns,
		cell_size,
		fish_size,
		Vector2(side_margin, top_margin),
		5.0,
	)
	for index: int in _sorted_catches.size():
		var fish_catch: FishCatchType = _sorted_catches[index]
		var fish_node := _fish_nodes.get(
			fish_catch.catch_id
		) as CoolerFishSpriteType
		if fish_node == null:
			continue
		var identity_hash: int = absi(String(fish_catch.catch_id).hash())
		var column: int = index % columns
		var row: int = floori(float(index) / float(columns))
		var offset_span: int = 5 if _compact_layout else 7
		var offset_center: float = 2.0 if _compact_layout else 3.0
		var stable_offset := Vector2(
			float(identity_hash % offset_span) - offset_center,
			float(floori(float(identity_hash) / 17.0) % offset_span) - offset_center,
		)
		var lane_offset: float = 5.0 if row % 2 == 1 else 0.0
		var target := Vector2(
			side_margin + float(column) * cell_size.x + lane_offset,
			top_margin + float(row) * cell_size.y,
		) + stable_offset
		fish_node.custom_minimum_size = fish_size
		fish_node.size = fish_size
		var immediate: bool = (
			not animate or fish_node.has_meta("new_cooler_fish")
		)
		fish_node.set_target_position(target, immediate)
		if fish_node.has_meta("new_cooler_fish"):
			fish_node.remove_meta("new_cooler_fish")


func _configure_cooler_fish_focus() -> void:
	if _current_section != Section.COOLER:
		return
	var controls: Array[CoolerFishSpriteType] = []
	for fish_catch: FishCatchType in _sorted_catches:
		var fish_node := _fish_nodes.get(
			fish_catch.catch_id
		) as CoolerFishSpriteType
		if fish_node != null:
			controls.append(fish_node)
	var columns: int = 3 if _compact_layout else 9
	if controls.is_empty():
		if not _shop_cooler_context_active:
			_cooler_sub_tab.focus_neighbor_bottom = NodePath()
		return
	var top_control: Control
	if _shop_cooler_context_active:
		top_control = _cooler_sort_option
	else:
		top_control = _cooler_sub_tab
	if not _shop_cooler_context_active:
		_cooler_sub_tab.focus_neighbor_bottom = _cooler_sub_tab.get_path_to(
			controls.front()
		)
	for index: int in controls.size():
		var control: CoolerFishSpriteType = controls[index]
		var column: int = index % columns
		control.focus_neighbor_left = control.get_path_to(
			controls[index - 1] if column > 0 else control
		)
		control.focus_neighbor_right = control.get_path_to(
			controls[index + 1]
			if column < columns - 1 and index + 1 < controls.size()
			else control
		)
		control.focus_neighbor_top = (
			control.get_path_to(top_control)
			if _shop_cooler_context_active and index < columns
			else control.get_path_to(control)
			if index < columns
			else control.get_path_to(controls[index - columns])
		)
		control.focus_neighbor_bottom = (
			control.get_path_to(_favorite_bubble)
			if (
				_shop_cooler_context_active
				and not _favorite_bubble.disabled
				and index + columns >= controls.size()
			)
			else control.get_path_to(controls[index + columns])
			if index + columns < controls.size()
			else control.get_path_to(control)
		)
	var focused_node := _fish_nodes.get(
		_fish_selection.get_focused_id()
	) as CoolerFishSpriteType
	if focused_node == null:
		focused_node = controls.front()
	_favorite_bubble.focus_neighbor_left = (
		_favorite_bubble.get_path_to(focused_node)
	)
	_favorite_bubble.focus_neighbor_right = (
		_favorite_bubble.get_path_to(_sell_bubble)
	)
	_favorite_bubble.focus_neighbor_top = (
		_favorite_bubble.get_path_to(focused_node)
	)
	_sell_bubble.focus_neighbor_left = (
		_sell_bubble.get_path_to(_favorite_bubble)
	)
	_sell_bubble.focus_neighbor_right = (
		_sell_bubble.get_path_to(_close_button)
	)
	_sell_bubble.focus_neighbor_top = _sell_bubble.get_path_to(focused_node)
	_sell_bubble.focus_neighbor_bottom = _sell_bubble.get_path_to(_sell_bubble)


func _compare_catches(left: FishCatchType, right: FishCatchType) -> bool:
	var comparison: int = 0
	match _sort_mode:
		SortMode.CATCH_ORDER:
			comparison = left.catch_sequence - right.catch_sequence
		SortMode.NAME:
			comparison = left.fish.display_name.naturalnocasecmp_to(
				right.fish.display_name
			)
		SortMode.RARITY:
			comparison = left.fish.rarity - right.fish.rarity
	if comparison == 0:
		comparison = left.catch_sequence - right.catch_sequence
	return comparison > 0 if _sort_descending else comparison < 0


func _on_catch_card_pressed(catch_id: StringName) -> void:
	if _inventory == null:
		return
	var selected: FishCatchType = _inventory.get_catch(catch_id)
	if selected == null:
		return
	_fish_selection.apply_click(
		catch_id,
		Input.is_key_pressed(KEY_CTRL),
		Input.is_key_pressed(KEY_SHIFT)
	)
	_refresh_inventory()


func _on_catch_card_focused(catch_id: StringName) -> void:
	if _inventory == null or _inventory.get_catch(catch_id) == null:
		return
	_fish_selection.focus_only(catch_id)
	for visible_catch: FishCatchType in _sorted_catches:
		var fish_node := _fish_nodes.get(
			visible_catch.catch_id
		) as CoolerFishSpriteType
		if fish_node == null:
			continue
		fish_node.set_item_state(
			_fish_selection.is_selected(visible_catch.catch_id),
			visible_catch.catch_id == catch_id,
			visible_catch.is_favorited,
		)
	_update_inventory_detail(_inventory.get_catch(catch_id))


func _on_fish_field_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and not get_viewport().gui_is_dragging()
	):
		_fish_selection.clear()
		_refresh_inventory()


func _close_detail_constellation() -> void:
	_detail_constellation.visible = _current_section == Section.COOLER
	_cooler_detail_texture.texture = null
	_cooler_detail_texture.visible = false
	_cooler_detail_name.text = "select a fish"
	_clear_cooler_detail_stats()
	_set_cooler_selection_summary_empty()
	_favorite_bubble.disabled = true
	_favorite_bubble.text = "favorite"
	_favorite_bubble.persistent_mark = false
	_sell_bubble.disabled = true
	_sell_bubble.text = "sell"
	_sell_bubble.persistent_mark = false
	_favorite_bubble.focus_mode = Control.FOCUS_NONE
	_sell_bubble.focus_mode = Control.FOCUS_NONE
	_favorite_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_favorite_bubble.refresh_ink_state()
	_sell_bubble.refresh_ink_state()
	_refresh_cooler_notepad_action_interactivity()
	_configure_cooler_fish_focus()


func _clear_cooler_detail_stats() -> void:
	for label: Label in [
		_cooler_quality_label,
		_cooler_rarity_label,
		_cooler_weight_value,
		_cooler_weight_unit,
	]:
		label.text = ""
	_cooler_offer_value.visible = false


func _set_cooler_selection_summary_empty() -> void:
	_cooler_selection_empty.visible = true
	_cooler_selected_count_row.visible = false
	_cooler_combined_offer_row.visible = false
	for label: Label in [
		_cooler_selected_count_value,
		_cooler_selected_count_label,
		_cooler_combined_offer_label,
	]:
		label.visible = false
		label.text = ""
	_cooler_combined_offer_value.visible = false


func _set_cooler_selection_summary(
	selected_count: int,
	offer_value: int,
) -> void:
	_cooler_selection_empty.visible = false
	_cooler_selected_count_row.visible = true
	_cooler_combined_offer_row.visible = true
	_cooler_selected_count_value.visible = true
	_cooler_selected_count_label.visible = true
	_cooler_combined_offer_label.visible = true
	_cooler_combined_offer_value.visible = offer_value >= 0
	_cooler_selected_count_value.text = str(selected_count)
	_cooler_selected_count_label.text = "fish selected"
	if offer_value >= 0:
		_cooler_combined_offer_label.text = "combined offer"
		_cooler_combined_offer_value.set_amount(offer_value)
	else:
		_cooler_combined_offer_label.text = "offer unavailable"


func _update_inventory_detail(fish_catch: FishCatchType) -> void:
	if fish_catch == null:
		_cooler_detail_texture.texture = null
		_cooler_detail_texture.visible = false
		_cooler_detail_name.text = "select a fish"
		_clear_cooler_detail_stats()
		_favorite_bubble.disabled = true
		_favorite_bubble.text = "favorite"
		_favorite_bubble.persistent_mark = false
		_detail_constellation.visible = _current_section == Section.COOLER
		_favorite_bubble.focus_mode = Control.FOCUS_NONE
		_sell_bubble.focus_mode = Control.FOCUS_NONE
		_favorite_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sell_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_favorite_bubble.refresh_ink_state()
		_sell_bubble.refresh_ink_state()
		_refresh_cooler_notepad_action_interactivity()
		_configure_cooler_fish_focus()
		return
	_cooler_detail_texture.texture = fish_catch.fish.display_texture
	_cooler_detail_texture.visible = fish_catch.fish.display_texture != null
	_cooler_detail_name.text = fish_catch.fish.display_name
	var active_buyer: FishBuyerProfileType = _get_active_sale_buyer()
	var individual_preview: FishSaleResultType = (
		_sale_service.preview_batch([fish_catch.catch_id], active_buyer)
		if _sale_service != null and active_buyer != null
		else null
	)
	var buyer_offer: int = (
		individual_preview.payout
		if individual_preview != null
		else -1
	)
	_cooler_weight_value.text = "%.2f" % fish_catch.weight_lb
	if (
		_reservations != null
		and _reservations.is_fish_reserved(fish_catch.catch_id)
	):
		_cooler_detail_name.text += " • reserved in mail"
	_cooler_quality_label.text = "quality: %s" % (
		FishQualityType.display_name(fish_catch.quality)
	)
	_cooler_rarity_label.text = (
		"rarity: %s" % fish_catch.fish.get_rarity_name()
	)
	_cooler_weight_unit.text = "lb"
	if buyer_offer >= 0:
		_cooler_offer_value.visible = true
		_cooler_offer_value.set_amount(buyer_offer)
	else:
		_cooler_offer_value.visible = false
	_favorite_bubble.disabled = false
	_favorite_bubble.text = (
		"unfavorite" if fish_catch.is_favorited else "favorite"
	)
	_favorite_bubble.persistent_mark = fish_catch.is_favorited
	_favorite_bubble.refresh_ink_state()
	_detail_constellation.visible = _current_section == Section.COOLER
	_cooler_sort_controls.visible = true
	_refresh_cooler_notepad_action_interactivity()
	_configure_cooler_fish_focus()


func _refresh_cooler_notepad_action_interactivity() -> void:
	var detail_interactive: bool = (
		_detail_constellation.visible
		and _current_section == Section.COOLER
		and (visible or _shop_cooler_context_active)
		and not _transitioning
		and not _page_transitioning
		and not _sale_confirmation.visible
	)
	for action: NotepadInkActionType in [
		_favorite_bubble,
		_sell_bubble,
	]:
		var action_interactive: bool = detail_interactive and not action.disabled
		action.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if action_interactive
			else Control.MOUSE_FILTER_IGNORE
		)
		action.refresh_ink_state()
	_apply_inventory_controller_zone_focus_modes()


func _update_sale_summary() -> void:
	var active_buyer: FishBuyerProfileType = _get_active_sale_buyer()
	var buyer_id: StringName = (
		active_buyer.id if active_buyer != null else StringName()
	)
	var selected_ids: Array[StringName] = _fish_selection.get_selected_ids()
	var selected_count: int = selected_ids.size()
	_sell_bubble.text = "sell"
	if selected_count == 0:
		_sell_bubble.disabled = true
		_sell_bubble.text = "sell"
		_sell_bubble.persistent_mark = false
		_sell_bubble.refresh_ink_state()
		_set_cooler_selection_summary_empty()
		return
	if (
		_sale_in_progress
		or (
			_network_sale_service != null
			and _network_sale_service.is_local_sale_pending()
		)
	):
		_sell_bubble.disabled = true
		_set_cooler_selection_summary(selected_count, -1)
		return
	if (
		_network_sale_service == null
		or buyer_id.is_empty()
		or not _network_sale_service.can_request_sale(buyer_id)
	):
		_sell_bubble.disabled = true
		_sell_bubble.persistent_mark = false
		_sell_bubble.refresh_ink_state()
		_set_cooler_selection_summary(selected_count, -1)
		return
	var preview: FishSaleResultType = (
		_sale_service.preview_batch(selected_ids, active_buyer)
		if _sale_service != null and active_buyer != null
		else null
	)
	if (
		preview != null
		and preview.payout >= 0
		and active_buyer != null
		and (
			preview.is_success()
			or preview.status == FishSaleResultType.Status.FAVORITED
		)
	):
		_set_cooler_selection_summary(selected_count, preview.payout)
	else:
		_set_cooler_selection_summary(selected_count, -1)
	_sell_bubble.disabled = preview == null or not preview.is_success()
	_sell_bubble.persistent_mark = false
	_sell_bubble.refresh_ink_state()


func _on_favorite_pressed() -> void:
	var focused_id: StringName = _fish_selection.get_focused_id()
	if _inventory == null or focused_id.is_empty():
		return
	var fish_catch: FishCatchType = _inventory.get_catch_by_id(
		focused_id
	)
	if fish_catch == null:
		_refresh_inventory()
		return
	if _inventory.set_catch_favorited(
		fish_catch.catch_id,
		not fish_catch.is_favorited
	):
		_refresh_inventory()


func _on_sell_pressed() -> void:
	_begin_sale_confirmation(_fish_selection.get_selected_ids())


func _begin_sale_confirmation(catch_ids: Array[StringName]) -> void:
	var active_buyer: FishBuyerProfileType = _get_active_sale_buyer()
	var buyer_id: StringName = (
		active_buyer.id if active_buyer != null else StringName()
	)
	if (
		_sale_in_progress
		or (
			_network_sale_service != null
			and _network_sale_service.is_local_sale_pending()
		)
	):
		return
	if (
		_network_sale_service == null
		or buyer_id.is_empty()
		or not _network_sale_service.can_request_sale(buyer_id)
	):
		return
	if (
		_inventory == null
		or _sale_service == null
		or active_buyer == null
		or catch_ids.is_empty()
	):
		return
	var preview: FishSaleResultType = _sale_service.preview_batch(
		catch_ids,
		active_buyer
	)
	if not preview.is_success():
		_refresh_inventory()
		return
	_confirmation_catch_ids = catch_ids.duplicate()
	_confirmation_buyer = active_buyer
	_confirmation_buyer_id = active_buyer.id
	_confirmation_generation = _menu_generation
	var shop_payout: int = preview.base_value
	if _shop_buyer != null and _shop_buyer.is_valid():
		var shop_preview: FishSaleResultType = _sale_service.preview_batch(
			catch_ids,
			_shop_buyer,
		)
		if shop_preview != null and shop_preview.is_success():
			shop_payout = shop_preview.payout
	_confirmation_message.text = _sale_confirmation_text(
		preview,
		active_buyer,
		shop_payout,
	)
	_sale_confirmation.visible = true
	if _shop_cooler_context_active:
		shop_cooler_modal_changed.emit(true)
	_set_shell_interactive(false)
	for button: Button in [_confirm_sale_button, _cancel_sale_button]:
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_sale_button.disabled = false
	_cancel_sale_button.grab_focus()


func _sale_confirmation_text(
	preview: FishSaleResultType,
	buyer: FishBuyerProfileType,
	shop_payout: int,
) -> String:
	var catch_label: String = (
		"this fish"
		if preview.fish_count == 1
		else "these %d fish" % preview.fish_count
	)
	var payout_text: String = CurrencyPresentationType.bbcode_amount(
		preview.payout,
		22,
	)
	if buyer != null and buyer.id == PELICAN_BUYER_ID:
		return (
			"[center]You can sell %s to the pelicans now for %s, "
			+ "but the shop is willing to pay %s![/center]"
		) % [
			catch_label,
			payout_text,
			CurrencyPresentationType.bbcode_amount(shop_payout, 22),
		]
	return "[center]Sell %s to the %s now for %s?[/center]" % [
		catch_label,
		_get_buyer_display_group(buyer),
		payout_text,
	]


func _on_confirm_sale_pressed() -> void:
	if (
		_sale_in_progress
		or _network_sale_service == null
		or not _network_sale_service.can_request_sale(
			_confirmation_buyer_id
		)
		or _sale_service == null
		or _confirmation_catch_ids.is_empty()
		or _confirmation_buyer == null
		or _confirmation_buyer.id != _confirmation_buyer_id
		or _confirmation_generation != _menu_generation
	):
		return
	_sale_in_progress = true
	var requested_catch_ids: Array[StringName] = (
		_confirmation_catch_ids.duplicate()
	)
	var requested_buyer_id: StringName = _confirmation_buyer_id
	var transaction_generation: int = _menu_generation
	_confirm_sale_button.disabled = true
	_close_sale_confirmation()
	var request_id: String = _network_sale_service.request_local_sale(
		requested_catch_ids,
		requested_buyer_id,
	)
	if request_id.is_empty():
		_sale_in_progress = false
		return
	if (
		_network_sale_service.is_local_sale_pending()
		and transaction_generation == _menu_generation
		and (visible or _shop_cooler_context_active)
	):
		_update_sale_summary()


func _can_use_shared_world_actions() -> bool:
	return (
		_network_sale_service != null
		and _network_sale_service.can_request_sale()
	)


func _on_network_sale_pending(_request_id: String) -> void:
	_sale_in_progress = true
	if visible or _shop_cooler_context_active:
		_update_sale_summary()


func _on_network_sale_finished(
	_request_id: String,
	accepted: bool,
	_message: String,
	catch_ids: Array[StringName],
	_payout: int,
) -> void:
	_sale_in_progress = false
	var close_bag_notepad: bool = (
		accepted
		and _current_section == Section.BAG
		and _controller_ownership == ControllerOwnership.NOTEPAD_ACTIONS
		and _controller_source_section == Section.BAG
		and catch_ids.has(_controller_source_identity)
	)
	if accepted:
		_fish_selection.remove_ids(catch_ids)
	if not visible and not _shop_cooler_context_active:
		return
	_refresh_all()
	if close_bag_notepad:
		_release_controller_ownership(true, false)
	if _current_section == Section.COOLER:
		call_deferred("_restore_inventory_tab_focus")


func _restore_inventory_tab_focus() -> void:
	if _shop_cooler_context_active:
		_focus_shop_cooler()
		return
	if (
		visible
		and _current_section == Section.COOLER
		and _inventory_tab.focus_mode != Control.FOCUS_NONE
		and _inventory_tab.is_visible_in_tree()
	):
		_inventory_tab.grab_focus()


func _close_sale_confirmation() -> void:
	var was_visible: bool = _sale_confirmation.visible
	_confirmation_catch_ids.clear()
	_confirmation_buyer = null
	_confirmation_buyer_id = StringName()
	_confirmation_generation = -1
	_sale_confirmation.visible = false
	if was_visible and _shop_cooler_context_active:
		shop_cooler_modal_changed.emit(false)
	_confirmation_message.text = ""
	_confirm_sale_button.disabled = false
	for button: Button in [_confirm_sale_button, _cancel_sale_button]:
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if (
		was_visible
		and (visible or _shop_cooler_context_active)
		and not _transitioning
		and not _page_transitioning
	):
		_set_shell_interactive(true)
		_focus_current_section()


func _revalidate_confirmation() -> void:
	if not _sale_confirmation.visible:
		return
	if (
		_confirmation_generation != _menu_generation
		or _confirmation_catch_ids.is_empty()
		or _sale_service == null
		or _confirmation_buyer == null
		or _confirmation_buyer.id != _confirmation_buyer_id
	):
		_close_sale_confirmation()
		return
	var preview: FishSaleResultType = _sale_service.preview_batch(
		_confirmation_catch_ids,
		_confirmation_buyer
	)
	if (
		not preview.is_success()
		or (
		_confirmation_buyer == null
		or _confirmation_buyer.id != _confirmation_buyer_id
		or not _confirmation_buyer.is_valid()
		)
	):
		_close_sale_confirmation()


func _get_buyer_display_group(
	buyer: FishBuyerProfileType,
) -> String:
	if buyer == null:
		return "buyer"
	if not buyer.animal_name_plural.is_empty():
		return buyer.animal_name_plural
	if not buyer.display_name.is_empty():
		return buyer.display_name
	return "buyer"


func _get_active_sale_buyer() -> FishBuyerProfileType:
	if _sale_buyer_override != null and _sale_buyer_override.is_valid():
		return _sale_buyer_override
	return _default_buyer


func _release_focus_from(node: Node, fallback: Control) -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if (
		focus_owner == null
		or (
			focus_owner != node
			and not node.is_ancestor_of(focus_owner)
		)
	):
		return
	var current_viewport: Viewport = get_viewport()
	if current_viewport != null:
		current_viewport.gui_release_focus()
	if (
		visible
		and not _transitioning
		and not _page_transitioning
		and fallback != null
		and fallback.focus_mode != Control.FOCUS_NONE
	):
		fallback.call_deferred("grab_focus")


func _create_texture_frame(
	texture: Texture2D,
	minimum_size: Vector2,
) -> TextureRect:
	var texture_frame := TextureRect.new()
	texture_frame.custom_minimum_size = minimum_size
	texture_frame.texture = texture
	texture_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if texture == null:
		texture_frame.tooltip_text = "display texture unavailable"
	return texture_frame


func _clear_container(container: Container) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
