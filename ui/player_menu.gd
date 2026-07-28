class_name PlayerMenu
extends Control

const INPUT_OWNER: StringName = &"player_menu"
const CollectionLogType = preload("res://collection/collection_log.gd")
const FishCatchType = preload("res://fish/fish_catch.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishBuyerProfileType = preload("res://economy/fish_buyer_profile.gd")
const FishSaleResultType = preload("res://economy/fish_sale_result.gd")
const FishSaleServiceType = preload("res://economy/fish_sale_service.gd")
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
const ItemDragSourceType = preload("res://ui/item_drag_source.gd")
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
const BubbleInventoryCellType = preload(
	"res://ui/components/bubble_menu/bubble_inventory_cell.gd"
)
const BubbleInventoryCellScene = preload(
	"res://ui/components/bubble_menu/bubble_inventory_cell.tscn"
)
const BubbleStatusBubbleType = preload(
	"res://ui/components/bubble_menu/bubble_status_bubble.gd"
)

const MENU_ENTER_DURATION: float = 0.58
const MENU_EXIT_DURATION: float = 0.52
const PAGE_OUT_DURATION: float = 0.34
const PAGE_IN_DURATION: float = 0.42
const TRANSITION_SAFE_MARGIN: float = 28.0

signal menu_visibility_changed(is_open: bool)

enum Section {
	COOLER,
	BAG,
	LOGBOOK,
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
@onready var _inventory_tab: BubbleButtonType = %InventoryTab
@onready var _bag_tab: BubbleButtonType = %BagTab
@onready var _logbook_tab: BubbleButtonType = %LogbookTab
@onready var _close_button: BubbleButtonType = %CloseButton
@onready var _content_shell: BubbleContentShellType = %MenuPanel
@onready var _content_stage: Control = %Content
@onready var _cooler_scroll: ScrollContainer = %CoolerScroll
@onready var _cooler_host: VBoxContainer = %CoolerHost
@onready var _wallet_balance: Label = %WalletBalance
@onready var _header: Control = %Header
@onready var _separator: Control = %Separator
@onready var _wallet_status: BubbleStatusBubbleType = %WalletStatus
@onready var _capacity_status: BubbleStatusBubbleType = %CapacityStatus
@onready var _held_value_status: BubbleStatusBubbleType = %HeldValueStatus
@onready var _selection_status: BubbleStatusBubbleType = %SelectionStatus
@onready var _offer_status: BubbleStatusBubbleType = %OfferStatus
@onready var _inventory_section: Control = %InventorySection
@onready var _inventory_body: BoxContainer = %InventoryBody
@onready var _inventory_scroll: ScrollContainer = %InventoryScroll
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
@onready var _inventory_grid: GridContainer = %InventoryGrid
@onready var _inventory_list: Control = %InventoryList
@onready var _detail_panel: Control = %DetailPanel
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
@onready var _status_shoal: HBoxContainer = %StatusShoal
@onready var _sort_bar: HBoxContainer = %SortBar

var _compact_layout: bool = false
var _player: PlayerType
var _inventory: FishInventoryType
var _collection_log: CollectionLogType
var _wallet: PlayerWalletType
var _sale_service: FishSaleServiceType
var _default_buyer: FishBuyerProfileType
var _catalog: FishPoolType
var _fishing_spot: FishingSpotType
var _bag: PlayerBagType
var _hotbar: PlayerHotbarType
var _item_catalog: ItemCatalogType
var _cooler_capacity: PlayerCoolerCapacityType
var _current_section: Section = Section.COOLER
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


func _ready() -> void:
	_inventory_section.reparent(_cooler_host)
	_inventory_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inventory_section.move_child(
		_sort_bar,
		_inventory_section.get_child_count() - 1,
	)
	_inventory_tab.pressed.connect(
		_show_section.bind(Section.COOLER)
	)
	_bag_tab.pressed.connect(_show_section.bind(Section.BAG))
	_logbook_tab.pressed.connect(
		_show_section.bind(Section.LOGBOOK)
	)
	_close_button.pressed.connect(close_menu)
	_sort_option.item_selected.connect(_on_sort_selected)
	_sort_direction.pressed.connect(_on_sort_direction_pressed)
	_favorite_button.pressed.connect(_on_favorite_pressed)
	_sell_button.pressed.connect(_on_sell_pressed)
	_confirm_sale_button.pressed.connect(_on_confirm_sale_pressed)
	_cancel_sale_button.pressed.connect(_close_sale_confirmation)
	_sort_option.add_item("catch order", SortMode.CATCH_ORDER)
	_sort_option.add_item("name", SortMode.NAME)
	_sort_option.add_item("rarity", SortMode.RARITY)
	_sort_option.select(SortMode.CATCH_ORDER)
	_update_sort_direction_text()
	_navigation_cluster.configure([
		_inventory_tab,
		_bag_tab,
		_logbook_tab,
		_close_button,
	])
	_configure_navigation_focus()
	_apply_cooler_control_styles()
	resized.connect(_update_shell_layout)
	_show_section_immediate(_current_section)
	call_deferred("_update_shell_layout")
	set_process(false)


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
	if not _cooler_capacity.capacity_changed.is_connected(
		_on_cooler_capacity_changed
	):
		_cooler_capacity.capacity_changed.connect(_on_cooler_capacity_changed)
	_refresh_all()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
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


func consume_escape() -> bool:
	if not visible:
		return false
	if _transitioning or _page_transitioning:
		return true
	if _sale_confirmation.visible:
		_close_sale_confirmation()
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
	_begin_page_transition(section)


func _show_section_immediate(section: Section) -> void:
	_current_section = section
	if not is_node_ready():
		return
	_inventory_section.visible = section == Section.COOLER
	_cooler_scroll.visible = section == Section.COOLER
	_bag_section.visible = section == Section.BAG
	_logbook_section.visible = section == Section.LOGBOOK
	_content_shell.set_background_visible(section != Section.COOLER)
	_header.visible = section != Section.COOLER
	_separator.visible = section != Section.COOLER
	_inventory_tab.button_pressed = section == Section.COOLER
	_bag_tab.button_pressed = section == Section.BAG
	_logbook_tab.button_pressed = section == Section.LOGBOOK
	_update_navigation_selection()


func _focus_current_section() -> void:
	if _current_section == Section.COOLER:
		_inventory_tab.grab_focus()
	elif _current_section == Section.BAG:
		_bag_tab.grab_focus()
	else:
		_logbook_tab.grab_focus()


func _process(delta: float) -> void:
	if visible:
		_navigation_cluster.advance_motion(delta)


func _configure_navigation_focus() -> void:
	var navigation: Array[BubbleButtonType] = [
		_inventory_tab,
		_bag_tab,
		_logbook_tab,
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


func _update_navigation_selection() -> void:
	_set_navigation_target(_current_section)


func _set_navigation_target(section: Section) -> void:
	_inventory_tab.button_pressed = section == Section.COOLER
	_bag_tab.button_pressed = section == Section.BAG
	_logbook_tab.button_pressed = section == Section.LOGBOOK


func _update_shell_layout() -> void:
	if not is_node_ready():
		return
	var compact: bool = size.y < 560.0 or size.x < 760.0
	_compact_layout = compact
	var side_margin: float = 10.0 if compact else 42.0
	var top_margin: float = 96.0 if compact else 104.0
	var bottom_margin: float = 96.0 if compact else 138.0
	_content_shell.position = Vector2(side_margin, top_margin)
	_content_shell.size = Vector2(
		maxf(1.0, size.x - side_margin * 2.0),
		maxf(1.0, size.y - top_margin - bottom_margin)
	)
	_presentation_rest_position = _content_shell.position
	var navigation_size := Vector2(
		minf(size.x - 20.0, 610.0 if compact else 760.0),
		52.0 if compact else 96.0
	)
	_navigation_cluster.position = Vector2(
		(size.x - navigation_size.x) * 0.5,
		4.0 if compact else 14.0
	)
	_navigation_cluster.size = navigation_size
	_navigation_cluster.apply_layout(navigation_size, compact)
	_inventory_grid.columns = 2 if compact else 3
	_bag_grid.columns = 2 if compact else 3
	_logbook_grid.columns = 3 if compact else 4
	_inventory_list.custom_minimum_size.x = 292.0 if compact else 350.0
	_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.custom_minimum_size.x = 176.0 if compact else 210.0
	_bag_list.custom_minimum_size.x = 300.0 if compact else 360.0
	_bag_detail.custom_minimum_size.x = 176.0 if compact else 220.0
	_content_stage.custom_minimum_size.y = 220.0 if compact else 260.0
	call_deferred("_sync_cooler_width")
	_inventory_body.vertical = compact
	_inventory_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
		if compact
		else ScrollContainer.SCROLL_MODE_AUTO
	)
	_inventory_list.custom_minimum_size.y = 240.0 if compact else 0.0
	_detail_panel.custom_minimum_size = (
		Vector2(0.0, 310.0)
		if compact
		else Vector2(430.0, 0.0)
	)
	_status_shoal.add_theme_constant_override(
		"separation",
		4 if compact else 8,
	)
	_inventory_body.queue_sort()
	_content_rest_position = _content_stage.position
	if not _transitioning:
		_content_shell.position = _presentation_rest_position
	if not _page_transitioning:
		_content_stage.position = _content_rest_position


func _sync_cooler_width() -> void:
	if not is_node_ready():
		return
	_cooler_host.custom_minimum_size.x = minf(
		_content_stage.size.x,
		1380.0,
	)
	_cooler_host.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _begin_menu_entry() -> void:
	_transitioning = true
	_set_shell_interactive(false)
	set_process(true)
	var generation: int = _transition_generation
	var start_offset: float = size.y + TRANSITION_SAFE_MARGIN
	_content_shell.position = _presentation_rest_position + Vector2.DOWN * start_offset
	var navigation_rest: Vector2 = _navigation_cluster.position
	_navigation_cluster.position = navigation_rest + Vector2.DOWN * start_offset
	_presentation_tween = create_tween().set_parallel(true)
	_presentation_tween.tween_property(
		_content_shell,
		"position",
		_presentation_rest_position,
		MENU_ENTER_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_navigation_cluster,
		"position",
		navigation_rest,
		MENU_ENTER_DURATION
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
	_presentation_tween = create_tween().set_parallel(true)
	_presentation_tween.tween_property(
		_content_shell,
		"position:y",
		end_y,
		MENU_EXIT_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_presentation_tween.tween_property(
		_navigation_cluster,
		"position:y",
		-_navigation_cluster.size.y - TRANSITION_SAFE_MARGIN,
		MENU_EXIT_DURATION
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
	_transitioning = false
	_page_transitioning = false
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


func _begin_page_transition(section: Section) -> void:
	_page_transition_generation += 1
	_cancel_page_tween()
	_page_transitioning = true
	_set_content_interactive(false)
	_set_navigation_target(section)
	var generation: int = _page_transition_generation
	_page_tween = create_tween()
	_page_tween.tween_property(
		_content_stage,
		"modulate:a",
		0.0,
		PAGE_OUT_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_page_tween.parallel().tween_property(
		_content_stage,
		"position:y",
		_content_rest_position.y - 18.0,
		PAGE_OUT_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_page_tween.tween_callback(
		_swap_page.bind(section, generation)
	)
	_page_tween.tween_property(
		_content_stage,
		"modulate:a",
		1.0,
		PAGE_IN_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_page_tween.parallel().tween_property(
		_content_stage,
		"position",
		_content_rest_position,
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
	_content_stage.position = _content_rest_position + Vector2.DOWN * 18.0


func _finish_page_transition(generation: int) -> void:
	if generation != _page_transition_generation or not visible:
		return
	_page_tween = null
	_page_transitioning = false
	_content_stage.position = _content_rest_position
	_content_stage.modulate.a = 1.0
	_set_content_interactive(true)
	_focus_current_section()


func _set_shell_interactive(interactive: bool) -> void:
	_set_content_interactive(interactive)
	for bubble: BubbleButtonType in [
		_inventory_tab,
		_bag_tab,
		_logbook_tab,
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


func _cancel_presentation_tween() -> void:
	if _presentation_tween != null:
		_presentation_tween.kill()
		_presentation_tween = null


func _cancel_page_tween() -> void:
	if _page_tween != null:
		_page_tween.kill()
		_page_tween = null


func _on_sort_selected(index: int) -> void:
	_sort_mode = _sort_option.get_item_id(index)
	_refresh_inventory()


func _on_sort_direction_pressed() -> void:
	_sort_descending = not _sort_descending
	_update_sort_direction_text()
	_refresh_inventory()


func _update_sort_direction_text() -> void:
	match _sort_mode:
		SortMode.CATCH_ORDER:
			_sort_direction.text = "newest first" if _sort_descending else "oldest first"
		SortMode.NAME:
			_sort_direction.text = "z–a" if _sort_descending else "a–z"
		SortMode.RARITY:
			_sort_direction.text = "high to low" if _sort_descending else "low to high"


func _refresh_all() -> void:
	_refresh_economy_summary()
	_refresh_inventory()
	_refresh_bag()
	_refresh_logbook()


func _on_bag_changed() -> void:
	_refresh_bag()


func _refresh_bag() -> void:
	if not is_node_ready():
		return
	_clear_container(_bag_grid)
	var owned_items: Array[OwnedItemType] = (
		_bag.get_all_items() if _bag != null else []
	)
	owned_items.sort_custom(_sort_bag_items)
	_bag_empty.visible = owned_items.is_empty()
	if (
		not _selected_bag_item_id.is_empty()
		and (_bag == null or not _bag.owns_item(_selected_bag_item_id))
	):
		_selected_bag_item_id = StringName()
	for owned: OwnedItemType in owned_items:
		var item: ItemDataType = _item_catalog.get_item_by_id(owned.item_id)
		if item == null:
			continue
		var card := ItemDragSourceType.new()
		card.custom_minimum_size = Vector2(140, 88)
		card.expand_icon = true
		card.icon = item.icon
		card.text = "%s%s\n%s" % [
			item.display_name,
			" ×%d" % owned.quantity if owned.quantity > 1 else "",
			item.get_category_name(),
		]
		card.tooltip_text = (
			"drag to a hotbar slot."
			if item.hotbar_allowed
			else "this item cannot be assigned to the hotbar."
		)
		card.setup(item.item_id, item.display_name, item.icon)
		card.pressed.connect(_select_bag_item.bind(item.item_id))
		_bag_grid.add_child(card)
	_update_bag_detail()


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
	_selected_bag_item_id = item_id
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
	_bag_detail_texture.texture = item.icon if item != null else null
	_bag_detail_name.text = item.display_name if item != null else ""
	_bag_detail_data.text = (
		"%s\nquantity: %d\n%s\n%s"
		% [
			item.get_category_name(),
			quantity,
			item.description,
			(
				"can be assigned to the hotbar."
				if item.hotbar_allowed
				else "cannot be assigned to the hotbar."
			),
		]
		if item != null
		else "select a bag item for details."
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
	_capacity_status.set_content("cooler", "%d / %d" % [
		_inventory.get_all_catches().size() if _inventory != null else 0,
		_cooler_capacity.get_capacity() if _cooler_capacity != null else 0,
	])
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
	_clear_container(_inventory_grid)
	var catches: Array[FishCatchType] = []
	if _inventory != null:
		for fish_catch: FishCatchType in _inventory.get_all_catches():
			if fish_catch != null and fish_catch.is_valid():
				catches.append(fish_catch)
	catches.sort_custom(_compare_catches)
	_inventory_empty.visible = catches.is_empty()
	var visible_ids: Array[StringName] = []
	for fish_catch: FishCatchType in catches:
		visible_ids.append(fish_catch.catch_id)
	_fish_selection.set_visible_order(visible_ids)

	var selected: FishCatchType
	if _inventory != null:
		selected = _inventory.get_catch(_fish_selection.get_focused_id())
	for fish_catch: FishCatchType in catches:
		_inventory_grid.add_child(_create_inventory_card(fish_catch))
	_configure_inventory_card_focus()
	_update_inventory_detail(selected)
	_update_sale_summary()
	_update_sort_direction_text()


func _configure_inventory_card_focus() -> void:
	var cards: Array[Control] = []
	for child: Node in _inventory_grid.get_children():
		if child is Control:
			cards.append(child as Control)
	var columns: int = maxi(_inventory_grid.columns, 1)
	for index: int in cards.size():
		var card: Control = cards[index]
		var row: int = floori(float(index) / float(columns))
		var column: int = index % columns
		var left_index: int = row * columns + maxi(column - 1, 0)
		var right_index: int = mini(index + 1, cards.size() - 1)
		var top_index: int = maxi(index - columns, 0)
		var bottom_index: int = mini(index + columns, cards.size() - 1)
		card.focus_neighbor_left = card.get_path_to(cards[left_index])
		card.focus_neighbor_right = card.get_path_to(cards[right_index])
		card.focus_neighbor_top = card.get_path_to(cards[top_index])
		card.focus_neighbor_bottom = card.get_path_to(cards[bottom_index])


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


func _create_inventory_card(fish_catch: FishCatchType) -> Button:
	var card := BubbleInventoryCellScene.instantiate() as BubbleInventoryCellType
	card.set_compact(_compact_layout)
	var is_selected: bool = _fish_selection.is_selected(fish_catch.catch_id)
	var is_focused: bool = (
		fish_catch.catch_id == _fish_selection.get_focused_id()
	)
	card.configure(
		fish_catch.fish.display_texture,
		fish_catch.fish.display_name,
		"%.2f lb" % fish_catch.weight_lb,
	)
	card.set_item_state(
		is_selected,
		is_focused,
		fish_catch.is_favorited,
	)
	card.pressed.connect(_on_catch_card_pressed.bind(fish_catch.catch_id))
	return card


func _apply_inventory_card_styles(
	card: Button,
	rarity_color: Color,
	is_selected: bool,
	is_focused: bool,
) -> void:
	card.add_theme_stylebox_override(
		"normal",
		_create_inventory_card_style(
			rarity_color,
			0,
			is_selected,
			is_focused
		)
	)
	card.add_theme_stylebox_override(
		"hover",
		_create_inventory_card_style(
			rarity_color,
			1,
			is_selected,
			is_focused
		)
	)
	card.add_theme_stylebox_override(
		"focus",
		_create_inventory_card_style(
			rarity_color,
			1,
			is_selected,
			true
		)
	)
	card.add_theme_stylebox_override(
		"pressed",
		_create_inventory_card_style(rarity_color, 2, true, is_focused)
	)


func _create_inventory_card_style(
	rarity_color: Color,
	state_index: int,
	is_selected: bool,
	is_focused: bool,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	match state_index:
		1:
			style.bg_color = UIPalette.ELEVATED_PANEL.lightened(0.1)
		2:
			style.bg_color = UIPalette.PRIMARY.darkened(0.48)
		_:
			style.bg_color = (
				UIPalette.PRIMARY.darkened(0.55)
				if is_selected
				else UIPalette.ELEVATED_PANEL
			)
	style.border_color = rarity_color
	var border_width: int = 4 if state_index == 2 or is_focused else 2
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(8)
	style.content_margin_left = 7.0
	style.content_margin_top = 7.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 7.0
	return style


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


func _update_inventory_detail(fish_catch: FishCatchType) -> void:
	if fish_catch == null:
		_detail_texture.texture = null
		_detail_texture.visible = false
		_detail_name.text = ""
		_detail_data.text = ""
		_favorite_button.disabled = true
		_favorite_button.text = "favorite"
		return
	_detail_texture.texture = fish_catch.fish.display_texture
	_detail_texture.visible = fish_catch.fish.display_texture != null
	_detail_name.text = fish_catch.fish.display_name
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
	var buyer_offer_text: String = "buyer unavailable"
	if buyer_offer >= 0 and _default_buyer != null:
		buyer_offer_text = "%s offer: $%d" % [
			_default_buyer.display_name,
			buyer_offer,
		]
	_detail_data.text = "%.2f lb\n%s\nbase value: $%d\n%s" % [
		fish_catch.weight_lb,
		fish_catch.fish.get_rarity_name(),
		fish_catch.sale_value,
		buyer_offer_text,
	]
	_favorite_button.disabled = false
	_favorite_button.text = (
		"unfavorite" if fish_catch.is_favorited else "favorite"
	)


func _update_sale_summary() -> void:
	var selected_ids: Array[StringName] = _fish_selection.get_selected_ids()
	var selected_count: int = selected_ids.size()
	_sell_button.text = (
		"sell fish"
		if selected_count == 1
		else "sell %d fish" % selected_count
	)
	if selected_count == 0:
		_selection_summary.text = "no fish selected"
		_selection_status.set_content("selected", "none")
		_offer_status.set_content("pelican offer", "—")
		_sell_button.text = "sell fish"
		_sell_button.disabled = true
		_sale_unavailable.text = ""
		_sale_unavailable.visible = false
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
		_offer_status.set_content("pelican offer", "$%d" % preview.payout)
	else:
		_offer_status.set_content("pelican offer", "unavailable")
	_sell_button.disabled = preview == null or not preview.is_success()
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
	_confirm_sale_button.disabled = false
	_confirm_sale_button.grab_focus()


func _on_confirm_sale_pressed() -> void:
	if (
		_sale_in_progress
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
	var transaction_buyer: FishBuyerProfileType = _confirmation_buyer
	_confirm_sale_button.disabled = true
	var result: FishSaleResultType = _sale_service.sell_batch(
		requested_catch_ids,
		transaction_buyer
	)
	_close_sale_confirmation()
	_sale_in_progress = false
	if transaction_generation != _menu_generation or not visible:
		return
	_transaction_feedback.text = result.get_message()
	if result.is_success():
		_fish_selection.remove_ids(requested_catch_ids)
	_refresh_all()
	_inventory_tab.grab_focus()


func _close_sale_confirmation() -> void:
	_confirmation_catch_ids.clear()
	_confirmation_buyer = null
	_confirmation_buyer_id = StringName()
	_confirmation_generation = -1
	_sale_confirmation.visible = false
	_confirmation_message.text = ""
	_confirm_sale_button.disabled = false


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
	_clear_container(_logbook_grid)
	var valid_species: Array[FishDataType] = []
	if _catalog != null:
		for fish: FishDataType in _catalog.candidates:
			if fish != null and not fish.id.is_empty():
				valid_species.append(fish)
	_logbook_empty.visible = valid_species.is_empty()
	_logbook_empty.text = (
		"no fish catalog configured."
		if valid_species.is_empty()
		else "no species discovered yet."
	)
	if not valid_species.is_empty() and _collection_log != null:
		var any_discovered: bool = false
		for fish: FishDataType in valid_species:
			if _collection_log.has_discovered(fish.id):
				any_discovered = true
				break
		_logbook_empty.visible = not any_discovered
	for fish: FishDataType in valid_species:
		_logbook_grid.add_child(_create_logbook_card(fish))


func _create_logbook_card(fish: FishDataType) -> Control:
	var discovered: bool = (
		_collection_log != null
		and _collection_log.has_discovered(fish.id)
	)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(158.0, 154.0)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 4)
	card.add_child(content)
	var texture_frame: TextureRect = _create_texture_frame(
		fish.display_texture,
		Vector2(142.0, 82.0)
	)
	if not discovered:
		texture_frame.modulate = UIPalette.PANEL
	content.add_child(texture_frame)
	var name_label := Label.new()
	name_label.text = fish.display_name if discovered else "???"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)
	var details := Label.new()
	if discovered:
		var owned_count: int = (
			_inventory.get_count(fish.id) if _inventory != null else 0
		)
		details.text = "%s\nowned: %d" % [
			fish.get_rarity_name(),
			owned_count,
		]
	else:
		details.text = "undiscovered"
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(details)
	return card


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
