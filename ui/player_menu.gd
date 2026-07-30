class_name PlayerMenu
extends Control

const INPUT_OWNER: StringName = &"player_menu"
const CollectionLogType = preload("res://collection/collection_log.gd")
const FishCatchType = preload("res://fish/fish_catch.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishBuyerProfileType = preload("res://economy/fish_buyer_profile.gd")
const FishSaleResultType = preload("res://economy/fish_sale_result.gd")
const FishSaleServiceType = preload("res://economy/fish_sale_service.gd")
const NetworkSessionType = preload("res://network/network_session.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
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
const FishBatchSelectionType = preload(
	"res://ui/fish_batch_selection.gd"
)
const BubbleButtonType = preload(
	"res://ui/components/bubble_menu/bubble_button.gd"
)
const BubbleClusterType = preload(
	"res://ui/components/bubble_menu/bubble_cluster.gd"
)
const BubbleContentShellType = preload(
	"res://ui/components/bubble_menu/bubble_content_shell.gd"
)
const BubbleStatusBubbleType = preload(
	"res://ui/components/bubble_menu/bubble_status_bubble.gd"
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
const LogbookEntryType = preload(
	"res://ui/components/bubble_menu/logbook_entry.gd"
)
const LogbookEntryScene = preload(
	"res://ui/components/bubble_menu/logbook_entry.tscn"
)

const PAGE_OUT_DURATION: float = 0.34
const PAGE_IN_DURATION: float = 0.42
const LOGBOOK_PAGE_DURATION: float = 0.18
const TRANSITION_SAFE_MARGIN: float = 28.0
const DESKTOP_REFERENCE_SIZE := Vector2(1280.0, 720.0)
const COMPACT_REFERENCE_SIZE := Vector2(640.0, 480.0)
const COMPACT_HEIGHT_THRESHOLD: float = 560.0
const NAVIGATION_PRESENTATION_SCALE: float = 0.60
const NAVIGATION_CANONICAL_POSITION := Vector2(424.0, 44.0)
const NAVIGATION_SELECTED_SCALE: float = 1.02
const COOLER_RARITY_COMMON := Color("e8eef0")
const COOLER_RARITY_UNCOMMON := Color("64c87c")
const COOLER_RARITY_RARE := Color("6098dd")
const COOLER_RARITY_EPIC := Color("a979cf")
const COOLER_RARITY_LEGENDARY := Color("db78a7")

signal menu_visibility_changed(is_open: bool)
signal inventory_hotbar_context_changed(show_hotbar: bool)
signal menu_exit_started

enum Section {
	COOLER,
	BAG,
	TACKLE_BOX,
	LOGBOOK,
	MAIL,
	PROFILE,
	PLAYERS,
}

enum BagView {
	EQUIPMENT,
	CONSUMABLES,
}

enum TackleView {
	BAIT,
	LURES,
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

@onready var _navigation_cluster: BubbleClusterType = %NavigationCluster
@onready var _presentation_scale_root: Control = %PlayerMenuPresentationScaleRoot
@onready var _cooler_page: Control = %CoolerPage
@onready var _cooler_outer_wall: PanelContainer = %CoolerOuterWall
@onready var _cooler_inner_liner: PanelContainer = %CoolerInnerLiner
@onready var _cooler_water_surface: ColorRect = %WaterSurface
@onready var _fish_field: Control = %FishField
@onready var _cooler_empty: Label = %CoolerEmpty
@onready var _cooler_sort_controls: HBoxContainer = %CoolerSortControls
@onready var _cooler_sort_option: NotepadInkChoiceType = %CoolerSortOption
@onready var _cooler_sort_direction: NotepadInkActionType = %CoolerSortDirection
@onready var _detail_constellation: Control = %DetailConstellation
@onready var _detail_bubble: Control = %DetailBubble
@onready var _notepad_binding: Label = %BindingDecoration
@onready var _notepad_title: Label = %NotepadTitle
@onready var _notepad_rule: ColorRect = %NotepadRule
@onready var _notepad_wallet_value: Label = %NotepadWalletValue
@onready var _notepad_capacity_value: Label = %NotepadCapacityValue
@onready var _cooler_detail_texture: TextureRect = %CoolerDetailTexture
@onready var _cooler_detail_name: Label = %CoolerDetailName
@onready var _cooler_detail_stats: Control = %CoolerDetailStats
@onready var _cooler_weight_row: HBoxContainer = %CoolerWeightRow
@onready var _cooler_weight_value: Label = %CoolerWeightValue
@onready var _cooler_weight_unit: Label = %CoolerWeightUnit
@onready var _cooler_offer_row: HBoxContainer = %CoolerOfferRow
@onready var _cooler_offer_label: Label = %CoolerOfferLabel
@onready var _cooler_offer_value: Label = %CoolerOfferValue
@onready var _cooler_selection_summary: Control = %CoolerSelectionSummary
@onready var _cooler_selection_empty: Label = %CoolerSelectionEmpty
@onready var _cooler_selected_count_row: HBoxContainer = %CoolerSelectedCountRow
@onready var _cooler_selected_count_value: Label = %CoolerSelectedCountValue
@onready var _cooler_selected_count_label: Label = %CoolerSelectedCountLabel
@onready var _cooler_combined_offer_row: HBoxContainer = %CoolerCombinedOfferRow
@onready var _cooler_combined_offer_label: Label = %CoolerCombinedOfferLabel
@onready var _cooler_combined_offer_value: Label = %CoolerCombinedOfferValue
@onready var _favorite_bubble: NotepadInkActionType = %FavoriteBubble
@onready var _sell_bubble: NotepadInkActionType = %SellBubble
@onready var _bag_page: Control = %BagPage
@onready var _tackle_box_page: Control = %TackleBoxPage
@onready var _inventory_sub_tabs: HBoxContainer = %InventorySubTabs
@onready var _cooler_sub_tab: Button = %CoolerSubTab
@onready var _bag_sub_tab: Button = %BagSubTab
@onready var _tackle_sub_tab: Button = %TackleSubTab
@onready var _bag_filter_tabs: HBoxContainer = %BagFilterTabs
@onready var _equipment_filter: Button = %EquipmentFilter
@onready var _consumables_filter: Button = %ConsumablesFilter
@onready var _tackle_main_panel: PanelContainer = %TackleMainPanel
@onready var _tackle_detail_panel: PanelContainer = %TackleDetailPanel
@onready var _bait_filter: Button = %BaitFilter
@onready var _lures_filter: Button = %LuresFilter
@onready var _tackle_empty: Label = %TackleEmpty
@onready var _tackle_detail_text: Label = %TackleDetailText
@onready var _tackle_item_list: VBoxContainer = %TackleItemList
@onready var _bag_outer_wall: PanelContainer = %BagOuterWall
@onready var _bag_inner_liner: PanelContainer = %BagInnerLiner
@onready var _bag_scroll: ScrollContainer = %BagScroll
@onready var _bag_host: Control = %BagHost
@onready var _bag_item_field: Control = %BagItemField
@onready var _bag_empty_state: Label = %BagEmptyState
@onready var _bag_detail_constellation: Control = %BagDetailConstellation
@onready var _bag_sprite_detail_bubble: Control = %BagDetailBubble
@onready var _bag_sprite_detail_texture: TextureRect = %BagSpriteDetailTexture
@onready var _bag_sprite_detail_name: Label = %BagSpriteDetailName
@onready var _bag_sprite_detail_data: Label = %BagSpriteDetailData
@onready var _logbook_page: Control = %LogbookPage
@onready var _mail_page: MailPage = %MailPage
@onready var _profile_page: ProfilePage = %ProfilePage
@onready var _players_page: PlayersPage = %PlayersPage
@onready var _book_backing: PanelContainer = %BookBacking
@onready var _book_spread: BoxContainer = %BookSpread
@onready var _left_page: PanelContainer = %LeftPage
@onready var _right_page: PanelContainer = %RightPage
@onready var _book_gutter: ColorRect = %BookGutter
@onready var _left_heading: Label = %LeftHeading
@onready var _right_heading: Label = %RightHeading
@onready var _left_entry_field: BoxContainer = %LeftEntryField
@onready var _right_entry_field: BoxContainer = %RightEntryField
@onready var _logbook_empty_state: Label = %LogbookEmptyState
@onready var _logbook_previous: BubbleButtonType = %LogbookPrevious
@onready var _logbook_next: BubbleButtonType = %LogbookNext
@onready var _logbook_page_status: BubbleStatusBubbleType = %LogbookPageStatus
@onready var _inventory_tab: BubbleButtonType = %InventoryTab
@onready var _logbook_tab: BubbleButtonType = %LogbookTab
@onready var _mail_tab: BubbleButtonType = %MailTab
@onready var _profile_tab: BubbleButtonType = %ProfileTab
@onready var _players_tab: BubbleButtonType = %PlayersTab
@onready var _mail_unread_badge: Label = %MailUnreadBadge
@onready var _close_button: BubbleButtonType = %CloseButton
@onready var _content_shell: BubbleContentShellType = %MenuPanel
@onready var _content_stage: Control = %Content
@onready var _cooler_scroll: ScrollContainer = %CoolerScroll
@onready var _cooler_host: Control = %CoolerHost
@onready var _wallet_balance: Label = %WalletBalance
@onready var _header: Control = %Header
@onready var _separator: Control = %Separator
@onready var _wallet_status: BubbleStatusBubbleType = %WalletStatus
@onready var _capacity_status: BubbleStatusBubbleType = %CapacityStatus
@onready var _held_value_status: BubbleStatusBubbleType = %HeldValueStatus
@onready var _selection_status: BubbleStatusBubbleType = %SelectionStatus
@onready var _offer_status: BubbleStatusBubbleType = %OfferStatus
@onready var _inventory_section: Control = %InventorySection
@onready var _bag_section: Control = %BagSection
@onready var _logbook_section: Control = %LogbookSection
@onready var _bag_empty: Label = %BagEmpty
@onready var _bag_grid: GridContainer = %BagGrid
@onready var _bag_list: Control = %BagList
@onready var _bag_detail: Control = %BagDetail
@onready var _bag_detail_texture: TextureRect = %BagDetailTexture
@onready var _bag_detail_name: Label = %BagDetailName
@onready var _bag_detail_data: Label = %BagDetailData
@onready var _sort_option: OptionButton = %SortOption
@onready var _sort_direction: Button = %SortDirection
@onready var _held_value: Label = %HeldValue
@onready var _cooler_count: Label = %CoolerCount
@onready var _inventory_empty: Label = %InventoryEmpty
@onready var _detail_texture: TextureRect = %DetailTexture
@onready var _detail_name: Label = %DetailName
@onready var _detail_data: Label = %DetailData
@onready var _selection_summary: Label = %SelectionSummary
@onready var _favorite_button: Button = %FavoriteButton
@onready var _sell_button: Button = %SellButton
@onready var _sale_unavailable: Label = %SaleUnavailable
@onready var _transaction_feedback: Label = %TransactionFeedback
@onready var _sale_confirmation: PanelContainer = %SaleConfirmation
@onready var _confirmation_message: Label = %ConfirmationMessage
@onready var _confirm_sale_button: Button = %ConfirmSaleButton
@onready var _cancel_sale_button: Button = %CancelSaleButton
@onready var _logbook_empty: Label = %LogbookEmpty
@onready var _logbook_grid: GridContainer = %LogbookGrid

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
var _default_buyer: FishBuyerProfileType
var _catalog: FishPoolType
var _fishing_spot: FishingSpotType
var _bag: PlayerBagType
var _hotbar: PlayerHotbarType
var _item_catalog: ItemCatalogType
var _cooler_capacity: PlayerCoolerCapacityType
var _current_section: Section = Section.COOLER
var _last_inventory_section: Section = Section.COOLER
var _bag_view: BagView = BagView.EQUIPMENT
var _tackle_view: TackleView = TackleView.BAIT
var _selected_tackle_item_id: StringName
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
var _presentation_rest_position: Vector2 = Vector2.ZERO
var _content_rest_position: Vector2 = Vector2.ZERO
var _cooler_rest_position: Vector2 = Vector2.ZERO
var _bag_rest_position: Vector2 = Vector2.ZERO
var _tackle_rest_position: Vector2 = Vector2.ZERO
var _logbook_rest_position: Vector2 = Vector2.ZERO
var _mail_rest_position: Vector2 = Vector2.ZERO
var _profile_rest_position: Vector2 = Vector2.ZERO
var _page_outgoing_root: Control
var _page_incoming_root: Control
var _page_hosts_shared: bool = false
var _fish_nodes: Dictionary[StringName, CoolerFishSpriteType] = {}
var _sorted_catches: Array[FishCatchType] = []
var _bag_item_nodes: Dictionary[StringName, BagItemSpriteType] = {}
var _sorted_bag_items: Array[OwnedItemType] = []
var _bag_drag_active: bool = false
var _motion_elapsed: float = 0.0
var _logbook_species: Array[FishDataType] = []
var _logbook_current_page: int = 0
var _logbook_page_count: int = 1
var _logbook_page_transitioning: bool = false
var _logbook_page_generation: int = 0
var _logbook_page_tween: Tween


func _ready() -> void:
	_inventory_tab.pressed.connect(_show_last_inventory_section)
	_cooler_sub_tab.pressed.connect(_show_section.bind(Section.COOLER))
	_bag_sub_tab.pressed.connect(_show_section.bind(Section.BAG))
	_tackle_sub_tab.pressed.connect(_show_section.bind(Section.TACKLE_BOX))
	_equipment_filter.pressed.connect(_set_bag_view.bind(BagView.EQUIPMENT))
	_consumables_filter.pressed.connect(
		_set_bag_view.bind(BagView.CONSUMABLES)
	)
	_bait_filter.pressed.connect(_set_tackle_view.bind(TackleView.BAIT))
	_lures_filter.pressed.connect(_set_tackle_view.bind(TackleView.LURES))
	_logbook_tab.pressed.connect(
		_show_section.bind(Section.LOGBOOK)
	)
	_mail_tab.pressed.connect(_show_section.bind(Section.MAIL))
	_profile_tab.pressed.connect(_show_section.bind(Section.PROFILE))
	_players_tab.pressed.connect(_show_section.bind(Section.PLAYERS))
	_close_button.pressed.connect(close_menu)
	_sort_option.item_selected.connect(_on_sort_selected.bind(_sort_option))
	_sort_direction.pressed.connect(_on_sort_direction_pressed)
	_cooler_sort_option.item_selected.connect(_on_cooler_sort_selected)
	_cooler_sort_direction.pressed.connect(_on_sort_direction_pressed)
	_favorite_button.pressed.connect(_on_favorite_pressed)
	_sell_button.pressed.connect(_on_sell_pressed)
	_favorite_bubble.pressed.connect(_on_favorite_pressed)
	_sell_bubble.pressed.connect(_on_sell_pressed)
	_confirm_sale_button.pressed.connect(_on_confirm_sale_pressed)
	_cancel_sale_button.pressed.connect(_close_sale_confirmation)
	_configure_sale_confirmation_focus()
	_sort_option.add_item("catch order", SortMode.CATCH_ORDER)
	_sort_option.add_item("name", SortMode.NAME)
	_sort_option.add_item("rarity", SortMode.RARITY)
	_sort_option.select(SortMode.CATCH_ORDER)
	_cooler_sort_option.add_item("catch order", SortMode.CATCH_ORDER)
	_cooler_sort_option.add_item("name", SortMode.NAME)
	_cooler_sort_option.add_item("rarity", SortMode.RARITY)
	_cooler_sort_option.select(SortMode.CATCH_ORDER)
	_update_sort_direction_text()
	_navigation_cluster.configure([
		_inventory_tab,
		_logbook_tab,
		_mail_tab,
		_profile_tab,
		_players_tab,
		_close_button,
	])
	_configure_navigation_focus()
	_apply_navigation_styles()
	_apply_inventory_styles()
	# Full-page Inventory controls are later siblings and otherwise win GUI
	# picking over the tab row even though the tabs draw above them.
	_inventory_sub_tabs.move_to_front()
	_apply_cooler_control_styles()
	_apply_cooler_wall_styles()
	_apply_cooler_notepad_style()
	_cooler_water_surface.resized.connect(_update_cooler_water_mask)
	_fish_field.gui_input.connect(_on_fish_field_gui_input)
	_apply_bag_styles()
	_bag_item_field.gui_input.connect(_on_bag_field_gui_input)
	_apply_logbook_styles()
	_apply_mail_notification_style()
	_logbook_previous.pressed.connect(_request_logbook_page.bind(-1))
	_logbook_next.pressed.connect(_request_logbook_page.bind(1))
	resized.connect(_update_shell_layout)
	_show_section_immediate(_current_section)
	call_deferred("_update_shell_layout")
	call_deferred("_update_cooler_water_mask")
	set_process(false)


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


func setup(
	player: PlayerType,
	inventory: FishInventoryType,
	collection_log: CollectionLogType,
	wallet: PlayerWalletType,
	sale_service: FishSaleServiceType,
	default_buyer: FishBuyerProfileType,
	catalog: FishPoolType,
	fishing_spot: FishingSpotType,
	bag: PlayerBagType,
	hotbar: PlayerHotbarType,
	item_catalog: ItemCatalogType,
	cooler_capacity: PlayerCoolerCapacityType,
	network_session: NetworkSessionType,
	network_sale_service: NetworkSaleService,
	network_mail_service: NetworkMailService,
	reservations: PlayerAssetReservationService,
	network_profile_service: NetworkProfileService,
	network_player_list: NetworkPlayerListService,
) -> void:
	_player = player
	_inventory = inventory
	_collection_log = collection_log
	_wallet = wallet
	_sale_service = sale_service
	_default_buyer = default_buyer
	_catalog = catalog
	_fishing_spot = fishing_spot
	_bag = bag
	_hotbar = hotbar
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
	_profile_page.setup(network_profile_service)
	_players_page.setup(network_player_list)
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
	if not _collection_log.fish_discovered.is_connected(_on_fish_discovered):
		_collection_log.fish_discovered.connect(_on_fish_discovered)
	if not _wallet.balance_changed.is_connected(_on_wallet_balance_changed):
		_wallet.balance_changed.connect(_on_wallet_balance_changed)
	if not _fishing_spot.bite_activated.is_connected(_on_bite_activated):
		_fishing_spot.bite_activated.connect(_on_bite_activated)
	if not _bag.contents_changed.is_connected(_on_bag_changed):
		_bag.contents_changed.connect(_on_bag_changed)
	if not _hotbar.slots_changed.is_connected(_on_hotbar_changed):
		_hotbar.slots_changed.connect(_on_hotbar_changed)
	if not _cooler_capacity.capacity_changed.is_connected(
		_on_cooler_capacity_changed
	):
		_cooler_capacity.capacity_changed.connect(_on_cooler_capacity_changed)
	_refresh_all()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if _handle_inventory_shortcut(event):
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


func _handle_inventory_shortcut(event: InputEvent) -> bool:
	var key_event := event as InputEventKey
	if (
		key_event == null
		or not key_event.pressed
		or _is_text_input_active()
	):
		return false
	var physical_key: Key = key_event.physical_keycode
	var inventory_requested: bool = physical_key == KEY_I
	var tackle_requested: bool = (
		physical_key == KEY_V
		or event.is_action_pressed("open_tacklebox")
	)
	if not inventory_requested and not tackle_requested:
		return false
	var requested_section: Section = (
		Section.TACKLE_BOX if tackle_requested else _last_inventory_section
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
	if _transitioning or _page_transitioning:
		return true
	if _sale_confirmation.visible:
		_close_sale_confirmation()
	elif _current_section == Section.MAIL and _mail_page.consume_escape():
		pass
	elif _current_section == Section.PROFILE and _profile_page.consume_escape():
		pass
	else:
		close_menu()
	return true


func open_menu() -> void:
	if (
		visible
		or _player == null
		or _fishing_spot == null
		or not _fishing_spot.can_open_player_menu()
	):
		return
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
	if (
		_current_section == Section.PROFILE
		and _profile_page.request_close_confirmation()
	):
		return
	_begin_page_transition(section)


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
	_mail_page.visible = section == Section.MAIL
	_profile_page.visible = section == Section.PROFILE
	_players_page.visible = section == Section.PLAYERS
	_content_shell.visible = false
	_inventory_section.visible = false
	_bag_section.visible = false
	_logbook_section.visible = section == Section.LOGBOOK
	_content_shell.set_background_visible(true)
	_header.visible = section != Section.COOLER
	_separator.visible = section != Section.COOLER
	if section == Section.COOLER:
		_refresh_inventory()
	else:
		_fish_selection.clear()
		_close_detail_constellation()
	if section != Section.BAG:
		_close_bag_detail()
	else:
		_update_bag_detail()
	_refresh_tackle_box()
	if section != Section.LOGBOOK:
		_cancel_logbook_page_transition(true)
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
	_cooler_sub_tab.button_pressed = section == Section.COOLER
	_bag_sub_tab.button_pressed = section == Section.BAG
	_tackle_sub_tab.button_pressed = section == Section.TACKLE_BOX
	_logbook_tab.button_pressed = section == Section.LOGBOOK
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


func _show_last_inventory_section() -> void:
	_show_section(_last_inventory_section)


func _focus_current_section() -> void:
	if _current_section == Section.COOLER:
		_cooler_sub_tab.grab_focus()
	elif _current_section == Section.BAG:
		_bag_sub_tab.grab_focus()
	elif _current_section == Section.TACKLE_BOX:
		_tackle_sub_tab.grab_focus()
	elif _current_section == Section.LOGBOOK:
		_logbook_tab.grab_focus()
	elif _current_section == Section.MAIL:
		_mail_tab.grab_focus()
	elif _current_section == Section.PLAYERS:
		_players_tab.grab_focus()
	else:
		_profile_tab.grab_focus()


func _process(delta: float) -> void:
	if visible:
		_motion_elapsed += delta
		_navigation_cluster.advance_motion(delta)
		_apply_navigation_selection_presentation()
		for fish_node: CoolerFishSpriteType in _fish_nodes.values():
			fish_node.advance_presentation(delta, _motion_elapsed)
		var bag_motion_enabled: bool = (
			not _bag_drag_active and not get_viewport().gui_is_dragging()
		)
		for item_node: BagItemSpriteType in _bag_item_nodes.values():
			item_node.advance_presentation(
				_motion_elapsed,
				bag_motion_enabled,
			)
		if _current_section == Section.LOGBOOK:
			_advance_logbook_page_controls(delta)


func _configure_navigation_focus() -> void:
	var navigation: Array[BubbleButtonType] = [
		_inventory_tab,
		_logbook_tab,
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
	var inventory_tabs: Array[Button] = [
		_cooler_sub_tab,
		_bag_sub_tab,
		_tackle_sub_tab,
	]
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
		inventory_tabs[int(_last_inventory_section)]
	)
	_tackle_sub_tab.focus_neighbor_bottom = _tackle_sub_tab.get_path_to(
		_bait_filter
	)


func _configure_sale_confirmation_focus() -> void:
	_confirm_sale_button.focus_neighbor_left = (
		_confirm_sale_button.get_path_to(_cancel_sale_button)
	)
	_confirm_sale_button.focus_neighbor_right = (
		_confirm_sale_button.focus_neighbor_left
	)
	_confirm_sale_button.focus_neighbor_top = (
		_confirm_sale_button.focus_neighbor_left
	)
	_confirm_sale_button.focus_neighbor_bottom = (
		_confirm_sale_button.focus_neighbor_left
	)
	_cancel_sale_button.focus_neighbor_left = (
		_cancel_sale_button.get_path_to(_confirm_sale_button)
	)
	_cancel_sale_button.focus_neighbor_right = (
		_cancel_sale_button.focus_neighbor_left
	)
	_cancel_sale_button.focus_neighbor_top = (
		_cancel_sale_button.focus_neighbor_left
	)
	_cancel_sale_button.focus_neighbor_bottom = (
		_cancel_sale_button.focus_neighbor_left
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
			_bait_filter.grab_focus()
		Section.LOGBOOK:
			_configure_logbook_focus()
		Section.MAIL:
			_mail_page.activate()
		Section.PROFILE:
			_profile_page.activate()


func _apply_inventory_styles() -> void:
	for button: Button in [
		_cooler_sub_tab,
		_bag_sub_tab,
		_tackle_sub_tab,
		_equipment_filter,
		_consumables_filter,
		_bait_filter,
		_lures_filter,
	]:
		UtilityPageStyle.apply_button(button)
	for panel: PanelContainer in [_tackle_main_panel, _tackle_detail_panel]:
		panel.add_theme_stylebox_override(
			"panel",
			UtilityPageStyle.panel_style(),
		)
	for label: Label in [_tackle_empty, _tackle_detail_text]:
		label.add_theme_font_override("font", UtilityPageStyle.TuffyFont)
		label.add_theme_color_override(
			"font_color",
			UtilityPageStyle.INK,
		)


func _set_bag_view(view: BagView) -> void:
	if _bag_view == view:
		return
	_bag_view = view
	_selected_bag_item_id = StringName()
	_refresh_bag()


func _set_tackle_view(view: TackleView) -> void:
	_tackle_view = view
	_selected_tackle_item_id = StringName()
	_refresh_tackle_box()


func _refresh_tackle_box() -> void:
	if not is_node_ready():
		return
	_bait_filter.button_pressed = _tackle_view == TackleView.BAIT
	_lures_filter.button_pressed = _tackle_view == TackleView.LURES
	for child: Node in _tackle_item_list.get_children():
		child.queue_free()
	var matching_items: Array[OwnedItemType] = []
	if _bag != null and _item_catalog != null:
		for owned: OwnedItemType in _bag.get_all_items():
			var item: ItemDataType = _item_catalog.get_item_by_id(
				owned.item_id
			)
			if item == null:
				continue
			if (
				_tackle_view == TackleView.BAIT
				and item.category == ItemDataType.Category.BAIT
			):
				matching_items.append(owned)
			elif (
				_tackle_view == TackleView.LURES
				and item.category == ItemDataType.Category.LURE
			):
				matching_items.append(owned)
	matching_items.sort_custom(_sort_bag_items)
	for owned: OwnedItemType in matching_items:
		var item: ItemDataType = _item_catalog.get_item_by_id(owned.item_id)
		var row := Button.new()
		row.text = "%s  ×%d" % [item.display_name, owned.quantity]
		row.icon = item.icon
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.toggle_mode = true
		row.button_pressed = owned.item_id == _selected_tackle_item_id
		UtilityPageStyle.apply_button(row)
		row.pressed.connect(_select_tackle_item.bind(owned.item_id))
		_tackle_item_list.add_child(row)
	_tackle_empty.text = (
		"No bait collected."
		if _tackle_view == TackleView.BAIT
		else "No lures collected."
	)
	_tackle_empty.visible = matching_items.is_empty()
	_update_tackle_detail()


func _select_tackle_item(item_id: StringName) -> void:
	_selected_tackle_item_id = item_id
	_refresh_tackle_box()


func _update_tackle_detail() -> void:
	var item: ItemDataType = (
		_item_catalog.get_item_by_id(_selected_tackle_item_id)
		if _item_catalog != null and not _selected_tackle_item_id.is_empty()
		else null
	)
	if item == null:
		_tackle_detail_text.text = (
			"Select bait for details."
			if _tackle_view == TackleView.BAIT
			else "Select a lure for details."
		)
		return
	var quantity: int = _bag.get_quantity(item.item_id) if _bag != null else 0
	var assigned_slot: int = -1
	if _hotbar != null:
		for slot_index: int in range(PlayerHotbarType.SLOT_COUNT):
			if _hotbar.get_item_id(slot_index) == item.item_id:
				assigned_slot = slot_index
				break
	var state_text: String = (
		"hotbar slot %d" % (assigned_slot + 1)
		if assigned_slot >= 0
		else "not assigned"
	)
	_tackle_detail_text.text = (
		"%s\n\nType: %s\nQuantity: %d\n%s\n\n%s"
		% [
			item.display_name,
			item.get_category_name(),
			quantity,
			state_text,
			item.description,
		]
	)


func _apply_cooler_control_styles() -> void:
	var profile: BubbleMenuProfile = _inventory_tab.profile
	if profile == null:
		return
	_sort_option.add_theme_stylebox_override(
		"normal",
		profile.make_normal_style(),
	)
	_sort_option.add_theme_stylebox_override(
		"hover",
		profile.make_hover_style(),
	)
	_sort_option.add_theme_stylebox_override(
		"focus",
		profile.make_hover_style(),
	)
	_sort_option.add_theme_stylebox_override(
		"pressed",
		profile.make_pressed_style(),
	)
	_sort_option.add_theme_color_override("font_color", profile.text_color)
	_sort_option.add_theme_color_override(
		"font_hover_color",
		profile.text_hover_color,
	)
	_sort_option.add_theme_color_override(
		"font_focus_color",
		profile.text_hover_color,
	)
func _apply_cooler_wall_styles() -> void:
	var outer := StyleBoxFlat.new()
	outer.bg_color = Color(0.76, 0.9, 0.96, 1.0)
	outer.border_color = Color(0.91, 0.98, 1.0, 1.0)
	outer.set_border_width_all(7)
	outer.set_corner_radius_all(58)
	_cooler_outer_wall.add_theme_stylebox_override("panel", outer)
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0.018, 0.16, 0.25, 1.0)
	inner.border_color = Color(0.56, 0.78, 0.86, 1.0)
	inner.set_border_width_all(5)
	inner.set_corner_radius_all(45)
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
	var paper := StyleBoxFlat.new()
	paper.bg_color = Color(0.93, 0.885, 0.73, 1.0)
	paper.border_color = Color(0.22, 0.19, 0.15, 1.0)
	paper.set_border_width_all(4)
	paper.corner_radius_top_left = 9
	paper.corner_radius_top_right = 7
	paper.corner_radius_bottom_right = 11
	paper.corner_radius_bottom_left = 8
	paper.shadow_color = Color(0.10, 0.08, 0.06, 0.46)
	paper.shadow_size = 4
	paper.shadow_offset = Vector2(3.0, 4.0)
	_detail_bubble.add_theme_stylebox_override("panel", paper)


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
		_mail_tab,
		_profile_tab,
		_players_tab,
	]:
		if not bubble.button_pressed:
			continue
		bubble.scale *= NAVIGATION_SELECTED_SCALE


func _apply_bag_styles() -> void:
	var outer := StyleBoxFlat.new()
	outer.bg_color = Color(0.39, 0.31, 0.2, 1.0)
	outer.border_color = Color(0.67, 0.54, 0.33, 1.0)
	outer.set_border_width_all(7)
	outer.corner_radius_top_left = 88
	outer.corner_radius_top_right = 64
	outer.corner_radius_bottom_right = 94
	outer.corner_radius_bottom_left = 70
	_bag_outer_wall.add_theme_stylebox_override("panel", outer)
	var inner := StyleBoxFlat.new()
	inner.bg_color = Color(0.92, 0.85, 0.68, 1.0)
	inner.border_color = Color(0.75, 0.62, 0.38, 1.0)
	inner.set_border_width_all(4)
	inner.corner_radius_top_left = 68
	inner.corner_radius_top_right = 48
	inner.corner_radius_bottom_right = 72
	inner.corner_radius_bottom_left = 52
	_bag_inner_liner.add_theme_stylebox_override("panel", inner)
	var bubble := StyleBoxFlat.new()
	bubble.bg_color = Color(0.96, 0.91, 0.78, 0.98)
	bubble.border_color = Color(0.55, 0.41, 0.23, 1.0)
	bubble.set_border_width_all(3)
	bubble.set_corner_radius_all(54)
	bubble.content_margin_left = 12.0
	bubble.content_margin_top = 9.0
	bubble.content_margin_right = 12.0
	bubble.content_margin_bottom = 9.0
	_bag_sprite_detail_bubble.add_theme_stylebox_override(
		"panel",
		bubble.duplicate(),
	)


func _apply_logbook_styles() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.54, 0.42, 0.27, 1.0)
	backing.border_color = Color(0.72, 0.59, 0.39, 1.0)
	backing.set_border_width_all(6)
	backing.corner_radius_top_left = 42
	backing.corner_radius_top_right = 34
	backing.corner_radius_bottom_right = 46
	backing.corner_radius_bottom_left = 36
	_book_backing.add_theme_stylebox_override("panel", backing)
	var left_paper := StyleBoxFlat.new()
	left_paper.bg_color = Color(0.95, 0.91, 0.79, 1.0)
	left_paper.border_color = Color(0.80, 0.70, 0.52, 1.0)
	left_paper.set_border_width_all(3)
	left_paper.corner_radius_top_left = 30
	left_paper.corner_radius_bottom_left = 38
	left_paper.corner_radius_top_right = 8
	left_paper.corner_radius_bottom_right = 6
	_left_page.add_theme_stylebox_override("panel", left_paper)
	var right_paper := StyleBoxFlat.new()
	right_paper.bg_color = Color(0.925, 0.875, 0.74, 1.0)
	right_paper.border_color = Color(0.77, 0.66, 0.48, 1.0)
	right_paper.set_border_width_all(3)
	right_paper.corner_radius_top_left = 8
	right_paper.corner_radius_bottom_left = 6
	right_paper.corner_radius_top_right = 34
	right_paper.corner_radius_bottom_right = 40
	_right_page.add_theme_stylebox_override("panel", right_paper)
	for label: Label in [_left_heading, _right_heading, _logbook_empty_state]:
		label.add_theme_color_override(
			"font_color",
			Color(0.22, 0.16, 0.09, 1.0),
		)
	var page_profile: BubbleMenuProfile = _logbook_previous.profile
	if page_profile != null:
		var disabled_style: StyleBoxFlat = page_profile.make_normal_style()
		disabled_style.bg_color.a = 0.82
		disabled_style.border_color.a = 0.72
		for control: BubbleButtonType in [
			_logbook_previous,
			_logbook_next,
		]:
			control.add_theme_stylebox_override(
				"disabled",
				disabled_style.duplicate(),
			)
			control.add_theme_color_override(
				"font_disabled_color",
				Color(0.035, 0.145, 0.22, 0.68),
			)
	_logbook_page_status.set_content("pages", "1 / 1")


func _update_navigation_selection() -> void:
	_set_navigation_target(_current_section)


func _on_mail_unread_count_changed(count: int) -> void:
	_mail_unread_badge.visible = count > 0
	_mail_unread_badge.text = "99+" if count > 99 else str(count)


func _set_navigation_target(section: Section) -> void:
	_inventory_tab.button_pressed = _is_inventory_section(section)
	_logbook_tab.button_pressed = section == Section.LOGBOOK
	_mail_tab.button_pressed = section == Section.MAIL
	_profile_tab.button_pressed = section == Section.PROFILE
	_players_tab.button_pressed = section == Section.PLAYERS


func _update_shell_layout() -> void:
	if not is_node_ready():
		return
	_cancel_logbook_page_transition(true)
	var compact: bool = false
	_compact_layout = compact
	var reference_size := DESKTOP_REFERENCE_SIZE
	_presentation_scale_root.size = reference_size
	_presentation_scale_root.scale = Vector2.ONE
	_presentation_scale_root.position = Vector2.ZERO
	_content_shell.position = Vector2(14.0, 92.0) if compact else Vector2(42.0, 104.0)
	_content_shell.size = Vector2(612.0, 286.0) if compact else Vector2(1196.0, 478.0)
	_presentation_rest_position = _content_shell.position
	var navigation_size := (
		Vector2(840.0, 75.0) if compact else Vector2(840.0, 100.0)
	)
	_navigation_cluster.position = NAVIGATION_CANONICAL_POSITION
	_navigation_cluster.size = navigation_size
	_navigation_cluster.scale = (
		Vector2.ONE * NAVIGATION_PRESENTATION_SCALE
	)
	_navigation_cluster.apply_layout(navigation_size, compact)
	_cooler_page.size = reference_size
	_cooler_page.position = Vector2.ZERO
	_cooler_rest_position = Vector2.ZERO
	_layout_cooler_fish(false)
	_cooler_outer_wall.position = (
		Vector2(14.0, 154.0) if compact else Vector2(54.0, 166.0)
	)
	_cooler_outer_wall.size = (
		Vector2(300.0, 218.0) if compact else Vector2(882.0, 484.0)
	)
	_detail_constellation.position = (
		Vector2(320.0, 154.0) if compact else Vector2(952.0, 166.0)
	)
	_detail_constellation.size = (
		Vector2(306.0, 196.0) if compact else Vector2(278.0, 436.0)
	)
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
	_cooler_sort_option.set_choice_font_size(12 if compact else 15)
	_cooler_sort_direction.add_theme_font_size_override(
		"font_size",
		12 if compact else 14,
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
	for status_value: Label in [
		_notepad_wallet_value,
		_notepad_capacity_value,
	]:
		status_value.add_theme_font_size_override(
			"font_size",
			10 if compact else 14,
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
		Vector2(214.0, 26.0) if compact else Vector2(252.0, 32.0)
	)
	_cooler_detail_name.add_theme_font_size_override(
		"font_size", 18 if compact else 25,
	)
	_cooler_detail_stats.position = (
		Vector2(82.0, 109.0) if compact else Vector2(18.0, 274.0)
	)
	_cooler_detail_stats.size = (
		Vector2(214.0, 39.0) if compact else Vector2(252.0, 65.0)
	)
	_layout_cooler_detail_text(compact)
	_cooler_selection_summary.position = (
		Vector2(10.0, 151.0) if compact else Vector2(18.0, 346.0)
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
		Vector2(144.0, 148.0) if compact else Vector2(26.0, 378.0)
	)
	_favorite_bubble.size = (
		Vector2(72.0, 42.0) if compact else Vector2(108.0, 50.0)
	)
	_sell_bubble.position = (
		Vector2(222.0, 148.0) if compact else Vector2(144.0, 378.0)
	)
	_sell_bubble.size = (
		Vector2(74.0, 42.0) if compact else Vector2(118.0, 50.0)
	)
	_favorite_bubble.add_theme_font_size_override(
		"font_size", 11 if compact else 17,
	)
	_sell_bubble.add_theme_font_size_override(
		"font_size", 11 if compact else 17,
	)
	_update_sort_direction_text()
	_bag_page.size = reference_size
	_bag_page.position = Vector2.ZERO
	_bag_rest_position = Vector2.ZERO
	_tackle_box_page.size = reference_size
	_tackle_box_page.position = Vector2.ZERO
	_tackle_rest_position = Vector2.ZERO
	_bag_outer_wall.position = (
		Vector2(14.0, 170.0) if compact else Vector2(54.0, 214.0)
	)
	_bag_outer_wall.size = (
		Vector2(612.0, 212.0) if compact else Vector2(882.0, 436.0)
	)
	_bag_host.custom_minimum_size = (
		Vector2(520.0, 152.0) if compact else Vector2(820.0, 380.0)
	)
	_bag_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bag_detail_constellation.position = (
		Vector2.ZERO if compact else Vector2(952.0, 166.0)
	)
	_bag_detail_constellation.size = (
		Vector2(640.0, 390.0) if compact else Vector2(278.0, 436.0)
	)
	_bag_sprite_detail_bubble.position = (
		Vector2(170.0, 164.0) if compact else Vector2.ZERO
	)
	_bag_sprite_detail_bubble.size = (
		Vector2(300.0, 188.0) if compact else Vector2(278.0, 436.0)
	)
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
	_tackle_main_panel.position = (
		Vector2(14.0, 154.0) if compact else Vector2(54.0, 166.0)
	)
	_tackle_main_panel.size = (
		Vector2(418.0, 218.0) if compact else Vector2(882.0, 484.0)
	)
	_tackle_detail_panel.position = (
		Vector2(438.0, 154.0) if compact else Vector2(952.0, 166.0)
	)
	_tackle_detail_panel.size = (
		Vector2(188.0, 218.0) if compact else Vector2(278.0, 484.0)
	)
	_logbook_page.size = reference_size
	_logbook_page.position = Vector2.ZERO
	_logbook_rest_position = Vector2.ZERO
	_mail_page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_mail_page.size = reference_size
	_mail_page.position = Vector2.ZERO
	_mail_rest_position = Vector2.ZERO
	_profile_page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_profile_page.position = Vector2(42.0, 104.0)
	_profile_page.size = Vector2(1196.0, 608.0)
	_profile_rest_position = _profile_page.position
	_players_page.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_players_page.position = Vector2.ZERO
	_players_page.size = reference_size
	_book_backing.position = (
		Vector2(14.0, 164.0) if compact else Vector2(58.0, 128.0)
	)
	_book_backing.size = (
		Vector2(612.0, 232.0) if compact else Vector2(1164.0, 522.0)
	)
	_right_page.visible = not compact
	_book_gutter.visible = not compact
	_left_entry_field.vertical = not compact
	_right_entry_field.vertical = true
	_left_heading.text = "field notes" if not compact else "field notes • page"
	_left_heading.add_theme_font_size_override(
		"font_size",
		17 if compact else 20,
	)
	_right_heading.add_theme_font_size_override("font_size", 20)
	_logbook_empty_state.position = (
		Vector2(120.0, 240.0) if compact else Vector2(402.0, 314.0)
	)
	_logbook_empty_state.size = (
		Vector2(400.0, 52.0) if compact else Vector2(476.0, 52.0)
	)
	_logbook_previous.apply_layout(
		Vector2(58.0, 332.0) if compact else Vector2(116.0, 622.0),
		Vector2(66.0, 62.0) if compact else Vector2(76.0, 72.0),
		0.18,
	)
	_logbook_next.apply_layout(
		Vector2(582.0, 332.0) if compact else Vector2(1164.0, 622.0),
		Vector2(66.0, 62.0) if compact else Vector2(76.0, 72.0),
		0.18,
	)
	_logbook_page_status.position = (
		Vector2(255.0, 308.0) if compact else Vector2(555.0, 608.0)
	)
	_logbook_page_status.size = (
		Vector2(130.0, 46.0) if compact else Vector2(170.0, 56.0)
	)
	_refresh_logbook_page(false)
	_sale_confirmation.position = (
		Vector2(70.0, 128.0) if compact else Vector2(320.0, 200.0)
	)
	_sale_confirmation.size = (
		Vector2(500.0, 250.0) if compact else Vector2(640.0, 320.0)
	)
	_cooler_host.custom_minimum_size = Vector2(
		520.0 if compact else 810.0,
		512.0 if compact else 420.0,
	)
	_bag_grid.columns = 2 if compact else 3
	_logbook_grid.columns = 3 if compact else 4
	_bag_list.custom_minimum_size.x = 300.0 if compact else 360.0
	_bag_detail.custom_minimum_size.x = 176.0 if compact else 220.0
	_content_stage.custom_minimum_size.y = 220.0 if compact else 260.0
	_content_rest_position = _content_stage.position
	if not _transitioning:
		_content_shell.position = _presentation_rest_position
		_cooler_page.position = _cooler_rest_position
		_bag_page.position = _bag_rest_position
		_tackle_box_page.position = _tackle_rest_position
		_logbook_page.position = _logbook_rest_position
		_mail_page.position = _mail_rest_position
		_profile_page.position = _profile_rest_position
		_players_page.position = Vector2.ZERO
		_cooler_page.modulate.a = 1.0
		_bag_page.modulate.a = 1.0
		_tackle_box_page.modulate.a = 1.0
		_logbook_page.modulate.a = 1.0
		_mail_page.modulate.a = 1.0
		_profile_page.modulate.a = 1.0
		_players_page.modulate.a = 1.0
	if not _page_transitioning:
		_content_stage.position = _content_rest_position
	_layout_cooler_fish(false)
	_layout_bag_items()


func _layout_cooler_detail_text(compact: bool) -> void:
	var weight_row_height: float = 17.0 if compact else 24.0
	_cooler_weight_row.position = Vector2.ZERO
	_cooler_weight_row.size = Vector2(
		_cooler_detail_stats.size.x,
		weight_row_height,
	)
	_cooler_offer_row.position = Vector2(
		0.0,
		17.0 if compact else 27.0,
	)
	_cooler_offer_row.size = Vector2(
		_cooler_detail_stats.size.x,
		22.0 if compact else 30.0,
	)
	_cooler_weight_value.add_theme_font_size_override(
		"font_size",
		9 if compact else 12,
	)
	_cooler_weight_unit.add_theme_font_size_override(
		"font_size",
		10 if compact else 14,
	)
	_cooler_offer_label.add_theme_font_size_override(
		"font_size",
		13 if compact else 18,
	)
	_cooler_offer_value.add_theme_font_size_override(
		"font_size",
		10 if compact else 15,
	)


func _layout_cooler_selection_text(compact: bool) -> void:
	var row_height: float = 17.5 if compact else 20.0
	for numeric_label: Label in [
		_cooler_selected_count_value,
		_cooler_combined_offer_value,
	]:
		numeric_label.add_theme_font_size_override(
			"font_size",
			10 if compact else 14,
		)
	for word_label: Label in [
		_cooler_selection_empty,
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
	set_process(true)
	var generation: int = _transition_generation
	var start_offset: float = (
		_presentation_scale_root.size.y + TRANSITION_SAFE_MARGIN
	)
	_content_shell.position = _presentation_rest_position + Vector2.DOWN * start_offset
	_cooler_page.position = _cooler_rest_position + Vector2.DOWN * start_offset
	_bag_page.position = _bag_rest_position + Vector2.DOWN * start_offset
	_tackle_box_page.position = (
		_tackle_rest_position + Vector2.DOWN * start_offset
	)
	_logbook_page.position = _logbook_rest_position + Vector2.DOWN * start_offset
	_mail_page.position = _mail_rest_position + Vector2.DOWN * start_offset
	_profile_page.position = _profile_rest_position + Vector2.DOWN * start_offset
	_players_page.position = Vector2.DOWN * start_offset
	var navigation_rest: Vector2 = _navigation_cluster.position
	_navigation_cluster.position = navigation_rest + Vector2.DOWN * start_offset
	var transition_duration := UIMotion.bubble_duration(start_offset)
	_presentation_tween = create_tween().set_parallel(true)
	_presentation_tween.tween_property(
		_content_shell,
		"position",
		_presentation_rest_position,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_cooler_page,
		"position",
		_cooler_rest_position,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_bag_page,
		"position",
		_bag_rest_position,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_tackle_box_page,
		"position",
		_tackle_rest_position,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_logbook_page,
		"position",
		_logbook_rest_position,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_mail_page,
		"position",
		_mail_rest_position,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_profile_page,
		"position",
		_profile_rest_position,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_players_page,
		"position",
		Vector2.ZERO,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_navigation_cluster,
		"position",
		navigation_rest,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.chain().tween_callback(
		_finish_menu_entry.bind(generation)
	)


func _finish_menu_entry(generation: int) -> void:
	if generation != _transition_generation or not visible:
		return
	_presentation_tween = null
	_transitioning = false
	_set_shell_interactive(true)
	_focus_current_section()


func _begin_menu_exit(reason: CloseReason, restore_controls: bool) -> void:
	if reason != CloseReason.USER:
		_finish_close(reason, restore_controls, _menu_generation)
		return
	_transition_generation += 1
	_cancel_presentation_tween()
	_transitioning = true
	_set_shell_interactive(false)
	get_viewport().gui_release_focus()
	var generation: int = _transition_generation
	var closing_generation: int = _menu_generation
	var end_y: float = -maxf(
		_content_shell.size.y,
		_navigation_cluster.size.y
	) - TRANSITION_SAFE_MARGIN
	var transition_duration := UIMotion.bubble_duration(
		end_y - _navigation_cluster.position.y
	)
	_presentation_tween = create_tween().set_parallel(true)
	_presentation_tween.tween_property(
		_content_shell,
		"position:y",
		end_y,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_cooler_page,
		"position:y",
		-_cooler_page.size.y - TRANSITION_SAFE_MARGIN,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_bag_page,
		"position:y",
		-_bag_page.size.y - TRANSITION_SAFE_MARGIN,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_tackle_box_page,
		"position:y",
		-_tackle_box_page.size.y - TRANSITION_SAFE_MARGIN,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_logbook_page,
		"position:y",
		-_logbook_page.size.y - TRANSITION_SAFE_MARGIN,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_mail_page,
		"position:y",
		-_mail_page.size.y - TRANSITION_SAFE_MARGIN,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_profile_page,
		"position:y",
		-_profile_page.size.y - TRANSITION_SAFE_MARGIN,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_players_page,
		"position:y",
		-_players_page.size.y - TRANSITION_SAFE_MARGIN,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_navigation_cluster,
		"position:y",
		-_navigation_cluster.size.y - TRANSITION_SAFE_MARGIN,
		transition_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
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
	_cancel_logbook_page_transition(true)
	_transitioning = false
	_page_transitioning = false
	_bag_drag_active = false
	_reset_page_transition_visuals()
	visible = false
	set_process(false)
	get_viewport().gui_release_focus()
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
		Section.MAIL:
			return _mail_rest_position
		Section.PROFILE:
			return _profile_rest_position
		_:
			return Vector2.ZERO


func _begin_page_transition(section: Section) -> void:
	_cancel_logbook_page_transition(true)
	_page_transition_generation += 1
	_cancel_page_tween()
	_page_transitioning = true
	_set_content_interactive(false)
	_set_navigation_target(section)
	var generation: int = _page_transition_generation
	_page_outgoing_root = _get_section_root(_current_section)
	_page_incoming_root = _get_section_root(section)
	_page_hosts_shared = _page_outgoing_root == _page_incoming_root
	var outgoing_rest: Vector2 = _get_section_rest_position(_current_section)
	var incoming_rest: Vector2 = _get_section_rest_position(section)
	if not _page_hosts_shared:
		_page_incoming_root.position = incoming_rest + Vector2.DOWN * 18.0
		_page_incoming_root.modulate.a = 0.0
	_page_tween = create_tween()
	_page_tween.tween_property(
		_page_outgoing_root,
		"modulate:a",
		0.0,
		PAGE_OUT_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_page_tween.parallel().tween_property(
		_page_outgoing_root,
		"position:y",
		outgoing_rest.y - 18.0,
		PAGE_OUT_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_page_tween.tween_callback(
		_swap_page.bind(section, generation)
	)
	_page_tween.tween_property(
		_page_incoming_root,
		"modulate:a",
		1.0,
		PAGE_IN_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_page_tween.parallel().tween_property(
		_page_incoming_root,
		"position",
		incoming_rest,
		PAGE_IN_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_page_tween.finished.connect(
		_finish_page_transition.bind(generation),
		CONNECT_ONE_SHOT
	)


func _swap_page(section: Section, generation: int) -> void:
	if generation != _page_transition_generation or not visible:
		return
	_show_section_immediate(section)
	if _page_hosts_shared:
		_page_incoming_root.position = (
			_presentation_rest_position + Vector2.DOWN * 18.0
		)
		_page_incoming_root.modulate.a = 0.0


func _finish_page_transition(generation: int) -> void:
	if generation != _page_transition_generation or not visible:
		return
	_page_tween = null
	_page_transitioning = false
	_reset_page_transition_visuals()
	_set_content_interactive(true)
	_focus_current_section()


func _set_shell_interactive(interactive: bool) -> void:
	_set_content_interactive(interactive)
	for bubble: BubbleButtonType in [
		_inventory_tab,
		_logbook_tab,
		_mail_tab,
		_profile_tab,
		_players_tab,
		_close_button,
	]:
		bubble.focus_mode = Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
		bubble.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if interactive
			else Control.MOUSE_FILTER_IGNORE
		)


func _set_content_interactive(interactive: bool) -> void:
	_content_stage.mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if interactive
		else Control.MOUSE_FILTER_IGNORE
	)
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
		_cooler_sub_tab, _bag_sub_tab, _tackle_sub_tab,
	]:
		var tab_interactive: bool = (
			interactive and _is_inventory_section(_current_section)
		)
		tab.focus_mode = (
			Control.FOCUS_ALL if tab_interactive else Control.FOCUS_NONE
		)
		tab.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if tab_interactive
			else Control.MOUSE_FILTER_IGNORE
		)
	_logbook_page.mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if interactive and _current_section == Section.LOGBOOK
		else Control.MOUSE_FILTER_IGNORE
	)
	_mail_page.set_interactive(
		interactive and _current_section == Section.MAIL
	)
	_profile_page.set_interactive(
		interactive and _current_section == Section.PROFILE
	)
	var cooler_interactive: bool = (
		interactive and _current_section == Section.COOLER
	)
	_cooler_sort_option.disabled = not cooler_interactive
	_cooler_sort_direction.disabled = not cooler_interactive
	_cooler_sort_option.refresh_ink_state()
	_cooler_sort_direction.refresh_ink_state()
	for fish_node: CoolerFishSpriteType in _fish_nodes.values():
		fish_node.focus_mode = (
			Control.FOCUS_ALL
			if cooler_interactive
			else Control.FOCUS_NONE
		)
		fish_node.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if cooler_interactive
			else Control.MOUSE_FILTER_IGNORE
		)
	var detail_interactive: bool = (
		cooler_interactive and _detail_constellation.visible
	)
	for action: NotepadInkActionType in [_favorite_bubble, _sell_bubble]:
		var action_interactive: bool = detail_interactive and not action.disabled
		action.focus_mode = (
			Control.FOCUS_ALL
			if action_interactive
			else Control.FOCUS_NONE
		)
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
	)
	for item_node: BagItemSpriteType in _bag_item_nodes.values():
		item_node.focus_mode = (
			Control.FOCUS_ALL if bag_interactive else Control.FOCUS_NONE
		)
		item_node.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if bag_interactive
			else Control.MOUSE_FILTER_IGNORE
		)
	var logbook_interactive: bool = (
		interactive
		and _current_section == Section.LOGBOOK
		and not _logbook_page_transitioning
	)
	_update_logbook_page_control_state(logbook_interactive)


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
		Section.MAIL,
		Section.PROFILE,
		Section.PLAYERS,
	]:
		var page: Control = _get_section_root(section)
		page.position = _get_section_rest_position(section)
		page.modulate.a = 1.0
	_page_outgoing_root = null
	_page_incoming_root = null


func _on_sort_selected(index: int, source: OptionButton) -> void:
	var selected_id: int = source.get_item_id(index)
	if selected_id < SortMode.CATCH_ORDER or selected_id > SortMode.RARITY:
		return
	_sort_mode = selected_id as SortMode
	_sort_option.select(_sort_mode)
	_cooler_sort_option.select(_sort_mode)
	_refresh_inventory()


func _on_cooler_sort_selected(sort_id: int) -> void:
	_sort_mode = sort_id
	_sort_option.select(_sort_mode)
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
	_sort_direction.text = direction_text
	_cooler_sort_direction.text = direction_text


func _refresh_all() -> void:
	_refresh_economy_summary()
	_refresh_inventory()
	_refresh_bag()
	_refresh_logbook()


func _on_bag_changed() -> void:
	_refresh_bag()
	_refresh_tackle_box()


func _on_hotbar_changed() -> void:
	_update_bag_detail()
	_update_tackle_detail()


func _refresh_bag() -> void:
	if not is_node_ready():
		return
	var owned_items: Array[OwnedItemType] = (
		_bag.get_all_items() if _bag != null else []
	)
	var filtered_items: Array[OwnedItemType] = []
	for owned: OwnedItemType in owned_items:
		var item: ItemDataType = (
			_item_catalog.get_item_by_id(owned.item_id)
			if _item_catalog != null
			else null
		)
		if item == null:
			continue
		var is_consumable: bool = (
			item.category == ItemDataType.Category.CONSUMABLE
		)
		if (
			(_bag_view == BagView.CONSUMABLES and is_consumable)
			or (
				_bag_view == BagView.EQUIPMENT
				and not is_consumable
				and item.category != ItemDataType.Category.BAIT
				and item.category != ItemDataType.Category.LURE
			)
		):
			filtered_items.append(owned)
	owned_items = filtered_items
	owned_items.sort_custom(_sort_bag_items)
	_sorted_bag_items = owned_items
	_equipment_filter.button_pressed = _bag_view == BagView.EQUIPMENT
	_consumables_filter.button_pressed = (
		_bag_view == BagView.CONSUMABLES
	)
	_bag_empty.visible = owned_items.is_empty()
	_bag_empty_state.visible = owned_items.is_empty()
	_bag_empty_state.text = (
		"No equipment in your Bag."
		if _bag_view == BagView.EQUIPMENT
		else "No consumables in your Bag."
	)
	if (
		not _selected_bag_item_id.is_empty()
		and (_bag == null or not _bag.owns_item(_selected_bag_item_id))
	):
		_selected_bag_item_id = StringName()
	_sync_bag_item_nodes(owned_items)
	_update_bag_detail()


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
			"drag to a hotbar slot."
			if item.hotbar_allowed
			else "this item cannot be assigned to the hotbar."
		)
		item_node.disabled = false
		item_node.set_selected(item.item_id == _selected_bag_item_id)
	for item_id: StringName in _bag_item_nodes.keys():
		if retained.has(item_id):
			continue
		var removed := _bag_item_nodes[item_id] as BagItemSpriteType
		_bag_item_nodes.erase(item_id)
		_release_focus_from(removed, _bag_sub_tab)
		removed.queue_free()
	_layout_bag_items()
	_configure_bag_item_focus()


func _layout_bag_items() -> void:
	if not is_node_ready() or _sorted_bag_items.is_empty():
		return
	_bag_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var columns: int = 3
	var cell_size := (
		Vector2(166.0, 72.0)
		if _compact_layout
		else Vector2(246.0, 154.0)
	)
	var item_size := (
		Vector2(86.0, 62.0)
		if _compact_layout
		else Vector2(138.0, 102.0)
	)
	var origin := (
		Vector2(16.0, 4.0)
		if _compact_layout
		else Vector2(54.0, 44.0)
	)
	_bag_item_field.custom_minimum_size = (
		Vector2(520.0, 140.0)
		if _compact_layout
		else Vector2(820.0, 240.0)
	)
	for index: int in _sorted_bag_items.size():
		var owned: OwnedItemType = _sorted_bag_items[index]
		var item_node := _bag_item_nodes.get(
			owned.item_id
		) as BagItemSpriteType
		if item_node == null:
			continue
		var identity_hash: int = absi(String(owned.item_id).hash())
		var column: int = index % columns
		var row: int = floori(float(index) / float(columns))
		var stable_offset := Vector2(
			float(identity_hash % 13) - 6.0,
			float(floori(float(identity_hash) / 19.0) % 11) - 5.0,
		)
		var lane_offset: float = 18.0 if row % 2 == 1 else 0.0
		item_node.custom_minimum_size = item_size
		item_node.size = item_size
		item_node.position = (
			origin
			+ Vector2(
				float(column) * cell_size.x + lane_offset,
				float(row) * cell_size.y,
			)
			+ stable_offset
		)


func _configure_bag_item_focus() -> void:
	if _current_section != Section.BAG:
		return
	var controls: Array[BagItemSpriteType] = []
	for owned: OwnedItemType in _sorted_bag_items:
		var item_node := _bag_item_nodes.get(
			owned.item_id
		) as BagItemSpriteType
		if item_node != null:
			controls.append(item_node)
	if controls.is_empty():
		_bag_sub_tab.focus_neighbor_bottom = NodePath()
		return
	_bag_sub_tab.focus_neighbor_bottom = _bag_sub_tab.get_path_to(
		controls.front()
	)
	for index: int in controls.size():
		var control: BagItemSpriteType = controls[index]
		var column: int = index % 3
		var row: int = floori(float(index) / 3.0)
		var left_index: int = row * 3 + maxi(column - 1, 0)
		var right_index: int = mini(index + 1, controls.size() - 1)
		control.focus_neighbor_left = control.get_path_to(
			controls[left_index]
		)
		control.focus_neighbor_right = control.get_path_to(
			controls[right_index]
		)
		control.focus_neighbor_top = (
			control.get_path_to(_bag_sub_tab)
			if index < 3
			else control.get_path_to(controls[index - 3])
		)
		control.focus_neighbor_bottom = control.get_path_to(
			controls[mini(index + 3, controls.size() - 1)]
		)


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


func _select_bag_item(item_id: StringName) -> void:
	if _bag_drag_active or get_viewport().gui_is_dragging():
		return
	_selected_bag_item_id = item_id
	for candidate_id: StringName in _bag_item_nodes:
		var item_node := _bag_item_nodes[candidate_id] as BagItemSpriteType
		item_node.set_selected(candidate_id == item_id)
	_update_bag_detail()


func _update_bag_detail() -> void:
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
	_bag_detail_texture.texture = item.icon if item != null else null
	_bag_detail_name.text = item.display_name if item != null else ""
	_bag_detail_data.text = (
		"%s\nquantity: %d\n%s\n%s\n%s"
		% [
			item.get_category_name(),
			quantity,
			item_state,
			hotbar_assignment,
			item.description,
		]
		if item != null
		else "select a bag item for details."
	)
	_bag_sprite_detail_texture.texture = item.icon if item != null else null
	_bag_sprite_detail_name.text = (
		item.display_name if item != null else "bag notes"
	)
	_bag_sprite_detail_data.text = (
		"%s • quantity: %d\n%s • %s\n%s"
		% [
			item.get_category_name(),
			quantity,
			item_state,
			hotbar_assignment,
			item.description,
		]
		if item != null
		else "select an item for details."
	)
	_bag_detail_constellation.visible = (
		_current_section == Section.BAG
	)


func _close_bag_detail() -> void:
	_bag_detail_constellation.visible = false


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
	_refresh_logbook()


func _on_fish_discovered(_fish_id: StringName) -> void:
	_refresh_logbook()


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
	_wallet_balance.text = "wallet: $%d" % balance
	_wallet_status.set_content("wallet", "$%d" % balance)
	_notepad_wallet_value.text = "$%d" % balance
	_capacity_status.set_content("cooler", "%d / %d" % [
		_inventory.get_all_catches().size() if _inventory != null else 0,
		_cooler_capacity.get_capacity() if _cooler_capacity != null else 0,
	])
	_notepad_capacity_value.text = "%d / %d" % [
		_inventory.get_all_catches().size() if _inventory != null else 0,
		_cooler_capacity.get_capacity() if _cooler_capacity != null else 0,
	]
	_held_value_status.set_content("held value", "$%d" % held_total)
	_held_value.text = "held fish base value: $%d" % held_total
	_cooler_count.text = "%d / %d" % [
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
	_inventory_empty.visible = catches.is_empty()
	_cooler_empty.visible = catches.is_empty()
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
		var identity_hash: int = absi(String(fish_catch.catch_id).hash())
		fish_node.configure(
			fish_catch.catch_id,
			fish_catch.fish.display_texture,
			float(identity_hash % 628) / 100.0,
			0.96 + float(identity_hash % 9) * 0.01,
			_get_cooler_rarity_color(fish_catch.fish.rarity),
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


func _get_cooler_rarity_color(rarity: int) -> Color:
	match rarity:
		FishDataType.Rarity.UNCOMMON:
			return COOLER_RARITY_UNCOMMON
		FishDataType.Rarity.RARE:
			return COOLER_RARITY_RARE
		FishDataType.Rarity.EPIC:
			return COOLER_RARITY_EPIC
		FishDataType.Rarity.LEGENDARY:
			return COOLER_RARITY_LEGENDARY
		_:
			return COOLER_RARITY_COMMON


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
		else Vector2(810.0, 280.0)
	)
	var side_margin: float = 2.0 if _compact_layout else 8.0
	var top_margin: float = 4.0 if _compact_layout else 6.0
	var required_rows: int = ceili(
		float(_sorted_catches.size()) / float(columns)
	) if not _sorted_catches.is_empty() else 0
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
		_cooler_sub_tab.focus_neighbor_bottom = NodePath()
		return
	_cooler_sub_tab.focus_neighbor_bottom = _cooler_sub_tab.get_path_to(
		controls.front()
	)
	for index: int in controls.size():
		var control: CoolerFishSpriteType = controls[index]
		control.focus_neighbor_left = control.get_path_to(
			controls[maxi(index - 1, 0)]
		)
		control.focus_neighbor_right = control.get_path_to(
			controls[mini(index + 1, controls.size() - 1)]
		)
		control.focus_neighbor_top = (
			control.get_path_to(_cooler_sub_tab)
			if index < columns
			else control.get_path_to(controls[index - columns])
		)
		control.focus_neighbor_bottom = (
			control.get_path_to(_favorite_bubble)
			if (
				not _favorite_bubble.disabled
				and index + columns >= controls.size()
			)
			else control.get_path_to(
				controls[mini(index + columns, controls.size() - 1)]
			)
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
	_transaction_feedback.text = ""
	_refresh_inventory()


func _on_fish_field_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and not get_viewport().gui_is_dragging()
	):
		_fish_selection.clear()
		_transaction_feedback.text = ""
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
	_sell_bubble.text = "sell fish"
	_sell_bubble.persistent_mark = false
	_favorite_bubble.focus_mode = Control.FOCUS_NONE
	_sell_bubble.focus_mode = Control.FOCUS_NONE
	_favorite_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sell_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_favorite_bubble.refresh_ink_state()
	_sell_bubble.refresh_ink_state()
	_configure_cooler_fish_focus()


func _clear_cooler_detail_stats() -> void:
	for label: Label in [
		_cooler_weight_value,
		_cooler_weight_unit,
		_cooler_offer_label,
		_cooler_offer_value,
	]:
		label.text = ""


func _set_cooler_selection_summary_empty() -> void:
	_cooler_selection_empty.visible = true
	_cooler_selected_count_row.visible = false
	_cooler_combined_offer_row.visible = false
	for label: Label in [
		_cooler_selected_count_value,
		_cooler_selected_count_label,
		_cooler_combined_offer_label,
		_cooler_combined_offer_value,
	]:
		label.visible = false
		label.text = ""


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
		_cooler_combined_offer_value.text = "$%d" % offer_value
	else:
		_cooler_combined_offer_label.text = "offer unavailable"
		_cooler_combined_offer_value.text = ""


func _update_inventory_detail(fish_catch: FishCatchType) -> void:
	if fish_catch == null:
		_cooler_detail_texture.texture = null
		_cooler_detail_texture.visible = false
		_cooler_detail_name.text = "select a fish"
		_clear_cooler_detail_stats()
		_favorite_button.disabled = true
		_favorite_button.text = "favorite"
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
		_configure_cooler_fish_focus()
		return
	_cooler_detail_texture.texture = fish_catch.fish.display_texture
	_cooler_detail_texture.visible = fish_catch.fish.display_texture != null
	_cooler_detail_name.text = fish_catch.fish.display_name
	var individual_preview: FishSaleResultType = (
		_sale_service.preview_batch([fish_catch.catch_id], _default_buyer)
		if _sale_service != null
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
	_cooler_weight_unit.text = "lb • %s" % fish_catch.fish.get_rarity_name()
	if buyer_offer >= 0 and _default_buyer != null:
		_cooler_offer_label.text = "%s offer" % _default_buyer.display_name
		_cooler_offer_value.text = "$%d" % buyer_offer
	else:
		_cooler_offer_label.text = "buyer unavailable"
		_cooler_offer_value.text = ""
	_favorite_button.disabled = false
	_favorite_button.text = (
		"unfavorite" if fish_catch.is_favorited else "favorite"
	)
	_favorite_bubble.disabled = false
	_favorite_bubble.text = _favorite_button.text
	_favorite_bubble.persistent_mark = fish_catch.is_favorited
	_favorite_bubble.refresh_ink_state()
	_detail_constellation.visible = _current_section == Section.COOLER
	_cooler_sort_controls.visible = true
	var detail_interactive: bool = (
		_detail_constellation.visible
		and not _transitioning
		and not _page_transitioning
	)
	for action: NotepadInkActionType in [_favorite_bubble, _sell_bubble]:
		var action_interactive: bool = detail_interactive and not action.disabled
		action.focus_mode = (
			Control.FOCUS_ALL
			if action_interactive
			else Control.FOCUS_NONE
		)
		action.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if action_interactive
			else Control.MOUSE_FILTER_IGNORE
		)
		action.refresh_ink_state()
	_configure_cooler_fish_focus()


func _update_sale_summary() -> void:
	var selected_ids: Array[StringName] = _fish_selection.get_selected_ids()
	var selected_count: int = selected_ids.size()
	_sell_button.text = (
		"sell fish"
		if selected_count == 1
		else "sell %d fish" % selected_count
	)
	_sell_bubble.text = _sell_button.text
	if selected_count == 0:
		_selection_summary.text = "no fish selected"
		_selection_status.set_content("selected", "none")
		_offer_status.set_content("pelican offer", "—")
		_sell_button.text = "sell fish"
		_sell_button.disabled = true
		_sell_bubble.disabled = true
		_sell_bubble.text = "sell fish"
		_sell_bubble.persistent_mark = false
		_sell_bubble.refresh_ink_state()
		_set_cooler_selection_summary_empty()
		_sale_unavailable.text = ""
		_sale_unavailable.visible = false
		return
	if (
		_sale_in_progress
		or (
			_network_sale_service != null
			and _network_sale_service.is_local_sale_pending()
		)
	):
		_selection_summary.text = (
			"1 fish selected"
			if selected_count == 1
			else "%d fish selected" % selected_count
		)
		_selection_status.set_content("selected", str(selected_count))
		_offer_status.set_content("pelican offer", "pending")
		_sell_button.disabled = true
		_sell_bubble.disabled = true
		_sale_unavailable.text = "Selling…"
		_sale_unavailable.visible = true
		return
	if (
		_network_sale_service == null
		or not _network_sale_service.can_request_sale()
	):
		_selection_summary.text = (
			"1 fish selected"
			if selected_count == 1
			else "%d fish selected" % selected_count
		)
		_selection_status.set_content("selected", str(selected_count))
		_offer_status.set_content("pelican offer", "unavailable")
		_sell_button.disabled = true
		_sell_bubble.disabled = true
		_sell_bubble.persistent_mark = false
		_sell_bubble.refresh_ink_state()
		_sale_unavailable.text = (
			"Selling is not supported by this server."
		)
		_sale_unavailable.visible = true
		return
	var preview: FishSaleResultType = (
		_sale_service.preview_batch(selected_ids, _default_buyer)
		if _sale_service != null
		else null
	)
	var count_text: String = (
		"1 fish selected"
		if selected_count == 1
		else "%d fish selected" % selected_count
	)
	_selection_summary.text = count_text
	_selection_status.set_content("selected", str(selected_count))
	if (
		preview != null
		and preview.payout >= 0
		and _default_buyer != null
		and (
			preview.is_success()
			or preview.status == FishSaleResultType.Status.FAVORITED
		)
	):
		_selection_summary.text += "\n%s total offer: $%d" % [
			_default_buyer.display_name,
			preview.payout,
		]
		_set_cooler_selection_summary(selected_count, preview.payout)
		_offer_status.set_content("pelican offer", "$%d" % preview.payout)
	else:
		_set_cooler_selection_summary(selected_count, -1)
		_offer_status.set_content("pelican offer", "unavailable")
	_sell_button.disabled = preview == null or not preview.is_success()
	_sell_bubble.disabled = _sell_button.disabled
	_sell_bubble.persistent_mark = false
	_sell_bubble.refresh_ink_state()
	if preview != null and preview.status == FishSaleResultType.Status.FAVORITED:
		_sale_unavailable.text = (
			"favorited fish cannot be sold. "
			+ "remove them from the selection first."
		)
	elif preview != null and not preview.is_success():
		_sale_unavailable.text = preview.get_message()
	else:
		_sale_unavailable.text = ""
	_sale_unavailable.visible = not _sale_unavailable.text.is_empty()


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
		_transaction_feedback.text = (
			"%s %s."
			% [
				fish_catch.fish.display_name,
				"favorited" if fish_catch.is_favorited else "unfavorited",
			]
		)


func _on_sell_pressed() -> void:
	if (
		_sale_in_progress
		or (
			_network_sale_service != null
			and _network_sale_service.is_local_sale_pending()
		)
	):
		_transaction_feedback.text = "Selling…"
		return
	if (
		_network_sale_service == null
		or not _network_sale_service.can_request_sale()
	):
		_transaction_feedback.text = (
			"Selling is not supported by this server."
		)
		return
	var selected_ids: Array[StringName] = _fish_selection.get_selected_ids()
	if (
		_inventory == null
		or _sale_service == null
		or _default_buyer == null
		or selected_ids.is_empty()
	):
		return
	var preview: FishSaleResultType = _sale_service.preview_batch(
		selected_ids,
		_default_buyer
	)
	if not preview.is_success():
		_transaction_feedback.text = (
			"favorited fish cannot be sold. "
			+ "remove them from the selection first."
			if preview.status == FishSaleResultType.Status.FAVORITED
			else preview.get_message()
		)
		_refresh_inventory()
		return
	_confirmation_catch_ids = selected_ids.duplicate()
	_confirmation_buyer = _default_buyer
	_confirmation_buyer_id = _default_buyer.id
	_confirmation_generation = _menu_generation
	var fish_label: String = "fish"
	_confirmation_message.text = (
		"sell %d %s to the %s for $%d?\ncombined base value: $%d"
		% [
			preview.fish_count,
			fish_label,
			_get_buyer_display_group(_default_buyer),
			preview.payout,
			preview.base_value,
		]
	)
	_sale_confirmation.visible = true
	_set_shell_interactive(false)
	for button: Button in [_confirm_sale_button, _cancel_sale_button]:
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_sale_button.disabled = false
	_cancel_sale_button.grab_focus()


func _on_confirm_sale_pressed() -> void:
	if (
		_sale_in_progress
		or _network_sale_service == null
		or not _network_sale_service.can_request_sale()
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
	var transaction_generation: int = _menu_generation
	_confirm_sale_button.disabled = true
	_close_sale_confirmation()
	var request_id: String = _network_sale_service.request_local_sale(
		requested_catch_ids
	)
	if request_id.is_empty():
		_sale_in_progress = false
		return
	if (
		_network_sale_service.is_local_sale_pending()
		and transaction_generation == _menu_generation
		and visible
	):
		_transaction_feedback.text = "Selling…"


func _can_use_shared_world_actions() -> bool:
	return (
		_network_sale_service != null
		and _network_sale_service.can_request_sale()
	)


func _on_network_sale_pending(_request_id: String) -> void:
	_sale_in_progress = true
	if visible:
		_transaction_feedback.text = "Selling…"
		_update_sale_summary()


func _on_network_sale_finished(
	_request_id: String,
	accepted: bool,
	message: String,
	catch_ids: Array[StringName],
	payout: int,
) -> void:
	_sale_in_progress = false
	if accepted:
		_fish_selection.remove_ids(catch_ids)
	if not visible:
		return
	_transaction_feedback.text = (
		"Sale complete. $%d received." % payout
		if accepted
		else message
	)
	_refresh_all()
	if _current_section == Section.COOLER:
		call_deferred("_restore_inventory_tab_focus")


func _restore_inventory_tab_focus() -> void:
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
	_confirmation_message.text = ""
	_confirm_sale_button.disabled = false
	for button: Button in [_confirm_sale_button, _cancel_sale_button]:
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if (
		was_visible
		and visible
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
		_transaction_feedback.text = "sale selection is no longer available."
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
		_transaction_feedback.text = (
			"favorited fish cannot be sold. "
			+ "remove them from the selection first."
			if preview.status == FishSaleResultType.Status.FAVORITED
			else preview.get_message()
		)


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


func _refresh_logbook() -> void:
	if not is_node_ready():
		return
	var valid_species: Array[FishDataType] = []
	if _catalog != null:
		for fish: FishDataType in _catalog.candidates:
			if fish != null and not fish.id.is_empty():
				valid_species.append(fish)
	_logbook_species = valid_species
	_logbook_empty.visible = valid_species.is_empty()
	_logbook_empty.text = (
		"no fish catalog configured."
		if valid_species.is_empty()
		else "no species discovered yet."
	)
	_logbook_empty_state.visible = valid_species.is_empty()
	_logbook_empty_state.text = (
		"no fish catalog configured"
		if valid_species.is_empty()
		else ""
	)
	_refresh_logbook_page(false)


func _refresh_logbook_page(keep_transition_state: bool = true) -> void:
	if not is_node_ready():
		return
	var entries_per_spread: int = 2 if _compact_layout else 4
	_logbook_page_count = maxi(
		1,
		ceili(float(_logbook_species.size()) / float(entries_per_spread)),
	)
	_logbook_current_page = clampi(
		_logbook_current_page,
		0,
		_logbook_page_count - 1,
	)
	_clear_logbook_entries()
	var start_index: int = _logbook_current_page * entries_per_spread
	var end_index: int = mini(
		start_index + entries_per_spread,
		_logbook_species.size(),
	)
	var visible_species: Array[FishDataType] = []
	for index: int in range(start_index, end_index):
		visible_species.append(_logbook_species[index])
	if _compact_layout:
		for fish: FishDataType in visible_species:
			_left_entry_field.add_child(_create_logbook_entry(fish))
	else:
		var left_count: int = mini(2, visible_species.size())
		for index: int in visible_species.size():
			var destination: BoxContainer = (
				_left_entry_field
				if index < left_count
				else _right_entry_field
			)
			destination.add_child(_create_logbook_entry(
				visible_species[index]
			))
	_logbook_page_status.set_content(
		"pages",
		"%d / %d" % [_logbook_current_page + 1, _logbook_page_count],
	)
	_logbook_page_status.visible = _logbook_page_count > 1
	_update_logbook_page_control_state(
		keep_transition_state
		and visible
		and _current_section == Section.LOGBOOK
		and not _transitioning
		and not _page_transitioning
		and not _logbook_page_transitioning
	)
	_configure_logbook_focus()


func _create_logbook_entry(fish: FishDataType) -> LogbookEntryType:
	var discovered: bool = (
		_collection_log != null
		and _collection_log.has_discovered(fish.id)
	)
	var entry := LogbookEntryScene.instantiate() as LogbookEntryType
	entry.set_meta("fish_id", fish.id)
	entry.configure(
		fish.display_texture,
		fish.display_name,
		fish.get_rarity_name(),
		_inventory.get_count(fish.id) if _inventory != null else 0,
		discovered,
	)
	entry.apply_compact_layout(_compact_layout)
	return entry


func _clear_logbook_entries() -> void:
	for field: BoxContainer in [_left_entry_field, _right_entry_field]:
		for child: Node in field.get_children():
			_release_focus_from(child, _logbook_tab)
			field.remove_child(child)
			child.queue_free()


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
	get_viewport().gui_release_focus()
	if (
		visible
		and not _transitioning
		and not _page_transitioning
		and fallback != null
		and fallback.focus_mode != Control.FOCUS_NONE
	):
		fallback.call_deferred("grab_focus")


func _request_logbook_page(direction: int) -> void:
	if (
		_current_section != Section.LOGBOOK
		or _logbook_page_transitioning
		or _transitioning
		or _page_transitioning
	):
		return
	var target_page: int = clampi(
		_logbook_current_page + direction,
		0,
		_logbook_page_count - 1,
	)
	if target_page == _logbook_current_page:
		return
	_logbook_page_generation += 1
	_logbook_page_transitioning = true
	_update_logbook_page_control_state(false)
	var generation: int = _logbook_page_generation
	var travel: float = -12.0 if direction > 0 else 12.0
	_logbook_page_tween = create_tween()
	_logbook_page_tween.tween_property(
		_book_spread,
		"modulate:a",
		0.0,
		LOGBOOK_PAGE_DURATION * 0.5,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_logbook_page_tween.parallel().tween_property(
		_book_spread,
		"position:x",
		travel,
		LOGBOOK_PAGE_DURATION * 0.5,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_logbook_page_tween.tween_callback(
		_swap_logbook_page.bind(target_page, travel, generation)
	)
	_logbook_page_tween.tween_property(
		_book_spread,
		"modulate:a",
		1.0,
		LOGBOOK_PAGE_DURATION * 0.5,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_logbook_page_tween.parallel().tween_property(
		_book_spread,
		"position:x",
		0.0,
		LOGBOOK_PAGE_DURATION * 0.5,
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_logbook_page_tween.finished.connect(
		_finish_logbook_page_transition.bind(generation),
		CONNECT_ONE_SHOT,
	)


func _swap_logbook_page(
	target_page: int,
	travel: float,
	generation: int,
) -> void:
	if (
		generation != _logbook_page_generation
		or not visible
		or _current_section != Section.LOGBOOK
	):
		return
	_logbook_current_page = target_page
	_refresh_logbook_page(false)
	_book_spread.position.x = -travel
	_book_spread.modulate.a = 0.0


func _finish_logbook_page_transition(generation: int) -> void:
	if generation != _logbook_page_generation:
		return
	_logbook_page_tween = null
	_logbook_page_transitioning = false
	_book_spread.position.x = 0.0
	_book_spread.modulate.a = 1.0
	_update_logbook_page_control_state(
		visible and _current_section == Section.LOGBOOK
	)
	_configure_logbook_focus()
	if _logbook_next.visible and not _logbook_next.disabled:
		_logbook_next.grab_focus()
	elif _logbook_previous.visible and not _logbook_previous.disabled:
		_logbook_previous.grab_focus()


func _cancel_logbook_page_transition(reset_visuals: bool) -> void:
	_logbook_page_generation += 1
	if _logbook_page_tween != null:
		_logbook_page_tween.kill()
		_logbook_page_tween = null
	_logbook_page_transitioning = false
	if reset_visuals and is_instance_valid(_book_spread):
		_book_spread.position.x = 0.0
		_book_spread.modulate.a = 1.0


func _update_logbook_page_control_state(interactive: bool) -> void:
	var has_multiple_pages: bool = _logbook_page_count > 1
	_logbook_previous.visible = has_multiple_pages
	_logbook_next.visible = has_multiple_pages
	_logbook_previous.disabled = (
		not interactive or _logbook_current_page <= 0
	)
	_logbook_next.disabled = (
		not interactive
		or _logbook_current_page >= _logbook_page_count - 1
	)
	for control: BubbleButtonType in [_logbook_previous, _logbook_next]:
		control.focus_mode = (
			Control.FOCUS_ALL
			if control.visible and not control.disabled
			else Control.FOCUS_NONE
		)
		control.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if control.visible and not control.disabled
			else Control.MOUSE_FILTER_IGNORE
		)


func _configure_logbook_focus() -> void:
	if _current_section != Section.LOGBOOK:
		return
	_logbook_tab.focus_neighbor_bottom = _logbook_tab.focus_neighbor_right
	if _logbook_page_count <= 1:
		return
	var first_control: BubbleButtonType = (
		_logbook_previous
		if not _logbook_previous.disabled
		else _logbook_next
	)
	_logbook_tab.focus_neighbor_bottom = _logbook_tab.get_path_to(
		first_control
	)
	for control: BubbleButtonType in [_logbook_previous, _logbook_next]:
		control.focus_neighbor_top = control.get_path_to(_logbook_tab)
		control.focus_neighbor_bottom = control.focus_neighbor_top
		control.focus_neighbor_left = control.get_path_to(
			_logbook_previous
		)
		control.focus_neighbor_right = control.get_path_to(_logbook_next)


func _advance_logbook_page_controls(delta: float) -> void:
	for control: BubbleButtonType in [_logbook_previous, _logbook_next]:
		if not control.visible:
			continue
		control.advance_emphasis(delta)
		control.apply_presentation(
			control.calculate_target(_motion_elapsed, 1.0, 1.0),
			control.calculate_visual_scale(_motion_elapsed, 1.0),
			minf(1.0, delta * 10.0),
		)


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
