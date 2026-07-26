class_name GameUI
extends CanvasLayer

const CollectionLogType = preload("res://collection/collection_log.gd")
const FishBuyerProfileType = preload("res://economy/fish_buyer_profile.gd")
const FishSaleServiceType = preload("res://economy/fish_sale_service.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const PlayerMenuType = preload("res://ui/player_menu.gd")
const PlayerType = preload("res://player/player.gd")
const PlayerWalletType = preload("res://economy/player_wallet.gd")
const ItemCatalogType = preload("res://items/item_catalog.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const PlayerHotbarType = preload("res://inventory/player_hotbar.gd")
const HotbarUIType = preload("res://ui/hotbar.gd")
const TitleScreenType = preload("res://ui/title_screen.gd")
const PauseMenuType = preload("res://ui/pause_menu.gd")
const FishingShopType = preload("res://ui/fishing_shop.gd")
const PlayerFishingUpgradesType = preload(
	"res://progression/player_fishing_upgrades.gd"
)
const ShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)

@onready var _status_label: Label = %StatusLabel
@onready var _catch_track: Control = %CatchTrack
@onready var _green_catch_progress: ProgressBar = %GreenCatchProgress
@onready var _red_chase_progress: ProgressBar = %RedChaseProgress
@onready var _barrier_markers: Control = %BarrierMarkers
@onready var _barrier_summary: Label = %BarrierSummary
@onready var _barrier_health: Label = %BarrierHealth
@onready var _showcase_details: Label = %ShowcaseDetails
@onready var _fishing_panel: PanelContainer = %FishingPanel
@onready var _player_menu: PlayerMenuType = %PlayerMenu
@onready var _screen_fade: ScreenFade = %ScreenFade
@onready var _title_screen: TitleScreenType = %TitleScreen
@onready var _pause_menu: PauseMenuType = %PauseMenu
@onready var _hotbar_ui: HotbarUIType = %Hotbar
@onready var _fishing_shop: FishingShopType = %FishingShop
@onready var _shop_prompt: PanelContainer = %ShopPrompt

var _showcase_active: bool = false
var _player_menu_open: bool = false
var _gameplay_ui_enabled: bool = false
var _fishing_spot: FishingSpotType
var _system_menu_open: bool = false
var _shop_open: bool = false


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
	main_shop_buyer: FishBuyerProfileType,
	fishing_upgrades: PlayerFishingUpgradesType,
	shop_interaction: ShopInteractionType,
) -> void:
	_fishing_spot = fishing_spot
	fishing_spot.status_changed.connect(_on_fishing_status_changed)
	fishing_spot.catch_display_changed.connect(_on_catch_display_changed)
	fishing_spot.showcase_changed.connect(_on_showcase_changed)
	_player_menu.menu_visibility_changed.connect(
		_on_player_menu_visibility_changed
	)
	_player_menu.setup(
		player,
		inventory,
		collection_log,
		wallet,
		sale_service,
		default_buyer,
		catalog,
		fishing_spot,
		bag,
		hotbar,
		item_catalog
	)
	_hotbar_ui.setup(hotbar, bag, item_catalog, fishing_spot)
	_fishing_shop.setup(
		player,
		inventory,
		wallet,
		sale_service,
		main_shop_buyer,
		fishing_upgrades,
		fishing_spot,
		shop_interaction
	)
	_fishing_shop.menu_visibility_changed.connect(_on_shop_visibility_changed)


func close_player_menu() -> void:
	_player_menu.close_menu()


func close_player_menu_for_water_recovery() -> void:
	_player_menu.close_for_water_recovery()


func close_player_menu_for_game_menu() -> void:
	_player_menu.close_for_game_menu()


func close_player_menu_for_session_end() -> void:
	_player_menu.close_for_session_end()


func consume_player_menu_escape() -> bool:
	return _player_menu.consume_escape()


func get_pause_menu() -> PauseMenuType:
	return _pause_menu


func set_gameplay_ui_enabled(enabled: bool) -> void:
	_gameplay_ui_enabled = enabled
	if not enabled:
		close_player_menu_for_session_end()
		_fishing_shop.close_for_session_end()
		_fishing_panel.visible = false
		_shop_prompt.hide()
		_hotbar_ui.hide()
		_hotbar_ui.set_gameplay_input_enabled(false)
	else:
		_hotbar_ui.show()
		_hotbar_ui.set_gameplay_input_enabled(true)
		_refresh_fishing_panel_visibility()


func set_system_menu_open(is_open: bool) -> void:
	_system_menu_open = is_open
	_hotbar_ui.visible = (
		_gameplay_ui_enabled and not is_open and not _shop_open
	)
	_hotbar_ui.set_gameplay_input_enabled(
		_gameplay_ui_enabled
		and not is_open
		and not _player_menu_open
		and not _shop_open
	)
	_hotbar_ui.set_drag_enabled(_player_menu_open and not is_open)
	if is_open:
		_shop_prompt.hide()


func get_fishing_shop() -> FishingShopType:
	return _fishing_shop


func set_shop_prompt_visible(is_visible: bool) -> void:
	_shop_prompt.visible = (
		is_visible
		and _gameplay_ui_enabled
		and not _system_menu_open
		and not _player_menu_open
		and not _shop_open
	)


func get_screen_fade() -> ScreenFade:
	return _screen_fade


func get_title_screen() -> TitleScreenType:
	return _title_screen


func _on_fishing_status_changed(status: String) -> void:
	if _showcase_active:
		return
	if _fishing_spot != null and _fishing_spot.is_fighting():
		return
	_set_fishing_status(status)


func _set_fishing_status(text: String) -> void:
	var normalized_text: String = text.strip_edges()
	_status_label.text = normalized_text
	_status_label.visible = not normalized_text.is_empty()
	_refresh_fishing_panel_visibility()


func _refresh_fishing_panel_visibility() -> void:
	var has_content: bool = (
		not _status_label.text.strip_edges().is_empty()
		or not _showcase_details.text.strip_edges().is_empty()
		or _catch_track.visible
		or _barrier_summary.visible
		or _barrier_health.visible
	)
	_fishing_panel.visible = (
		_gameplay_ui_enabled
		and has_content
	)


func _on_catch_display_changed(
	progress: float,
	chase_progress: float,
	barrier_positions: PackedFloat32Array,
	barrier_health: PackedInt32Array,
	barrier_max_health: PackedInt32Array,
	active_barrier_index: int,
	visible: bool,
) -> void:
	var encounter_visible: bool = (
		visible
		and _fishing_spot != null
		and _fishing_spot.is_fighting()
	)
	_hotbar_ui.set_item_name_suppressed(encounter_visible)
	_green_catch_progress.value = progress * 100.0
	_red_chase_progress.value = maxf(chase_progress, 0.0) * 100.0
	_catch_track.visible = encounter_visible
	_barrier_summary.visible = encounter_visible
	_barrier_health.visible = encounter_visible
	if not encounter_visible:
		_barrier_health.visible = false
		_clear_barrier_markers()
		_barrier_summary.text = ""
		_barrier_health.text = ""
		_refresh_fishing_panel_visibility()
		return
	_status_label.text = ""
	_status_label.visible = false

	_update_barrier_markers(
		barrier_positions,
		barrier_health,
		active_barrier_index
	)
	var barrier_labels: PackedStringArray = []
	for barrier_index: int in range(barrier_positions.size()):
		var defeated: bool = (
			barrier_index < barrier_health.size()
			and barrier_health[barrier_index] <= 0
		)
		var marker: String = "✓" if defeated else "●"
		if barrier_index == active_barrier_index:
			marker = "[%s]" % marker
		barrier_labels.append(
			"%d%% %s"
			% [roundi(barrier_positions[barrier_index] * 100.0), marker]
		)
	_barrier_summary.text = "Barriers: %s" % "  ".join(barrier_labels)

	if (
		active_barrier_index >= 0
		and active_barrier_index < barrier_health.size()
		and active_barrier_index < barrier_max_health.size()
	):
		_barrier_health.text = (
			"Barrier: %d / %d"
			% [
				barrier_health[active_barrier_index],
				barrier_max_health[active_barrier_index],
			]
		)
	else:
		_barrier_health.text = "Hold left click to reel"

	var chase_gap: float = progress - chase_progress
	if chase_gap <= 0.05:
		_barrier_health.text = (
			"%s%s"
			% [
				_barrier_health.text,
				"\nRed is closing in!",
			]
		).strip_edges()
	_refresh_fishing_panel_visibility()


func _update_barrier_markers(
	positions: PackedFloat32Array,
	health: PackedInt32Array,
	active_index: int,
) -> void:
	_clear_barrier_markers()
	for barrier_index: int in range(positions.size()):
		var marker := ColorRect.new()
		var defeated: bool = (
			barrier_index < health.size()
			and health[barrier_index] <= 0
		)
		marker.color = (
			UIPalette.DISABLED
			if defeated
			else UIPalette.SECONDARY
		)
		if barrier_index == active_index:
			marker.color = UIPalette.TEXT
		marker.set_anchors_preset(Control.PRESET_TOP_LEFT)
		marker.anchor_left = positions[barrier_index]
		marker.anchor_right = positions[barrier_index]
		marker.offset_left = -2.0
		marker.offset_right = 2.0
		marker.offset_top = 0.0
		marker.offset_bottom = 18.0
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_barrier_markers.add_child(marker)


func _clear_barrier_markers() -> void:
	for marker: Node in _barrier_markers.get_children():
		marker.queue_free()


func _on_showcase_changed(
	fish_name: String,
	rarity_name: String,
	weight_lb: float,
	visible: bool,
) -> void:
	_showcase_active = visible
	if not visible:
		_showcase_details.text = ""
		_showcase_details.visible = false
		_set_fishing_status("")
		return
	_catch_track.visible = false
	_barrier_summary.visible = false
	_barrier_health.visible = false
	_clear_barrier_markers()
	_showcase_details.text = (
		"%.1f lb • %s\nLeft click or Escape to put away"
		% [weight_lb, rarity_name]
	)
	_showcase_details.visible = true
	_set_fishing_status("You caught a %s!" % fish_name)


func _on_player_menu_visibility_changed(is_open: bool) -> void:
	_player_menu_open = is_open
	_hotbar_ui.set_gameplay_input_enabled(
		_gameplay_ui_enabled and not is_open
	)
	_hotbar_ui.set_drag_enabled(is_open)
	_refresh_fishing_panel_visibility()
	if is_open:
		_shop_prompt.hide()


func _on_shop_visibility_changed(is_open: bool) -> void:
	_shop_open = is_open
	_hotbar_ui.visible = (
		_gameplay_ui_enabled and not is_open and not _system_menu_open
	)
	_hotbar_ui.set_gameplay_input_enabled(
		_gameplay_ui_enabled
		and not is_open
		and not _system_menu_open
		and not _player_menu_open
	)
	if is_open:
		_shop_prompt.hide()
