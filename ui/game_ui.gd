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
const NetworkSessionType = preload("res://network/network_session.gd")
const FishingShopType = preload("res://ui/fishing_shop.gd")
const SettingsPanelType = preload("res://ui/settings_panel.gd")
const PlayerFishingUpgradesType = preload(
	"res://progression/player_fishing_upgrades.gd"
)
const ShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)
const PlayerItemEffectsType = preload(
	"res://progression/player_item_effects.gd"
)
const PlayerCoolerCapacityType = preload(
	"res://progression/player_cooler_capacity.gd"
)
const ChatUIType = preload("res://ui/chat_ui.gd")
const EmoteRadialMenuType = preload("res://ui/emote_radial_menu.gd")
const PlayerSettingsManagerType = preload(
	"res://settings/player_settings_manager.gd"
)

signal pixelation_settings_visibility_changed(is_visible: bool)
signal crisp_reset_focus_requested
signal interactive_pointer_ui_changed(is_open: bool)
signal passive_pointer_ui_changed(is_enabled: bool)
signal player_menu_backdrop_visibility_changed(is_visible: bool)
signal shop_backdrop_visibility_changed(is_visible: bool)

@onready var _status_label: Label = %StatusLabel
@onready var _gameplay_transient_hud: Control = %GameplayTransientHUD
@onready var _catch_track: Control = %CatchTrack
@onready var _green_catch_progress: ProgressBar = %GreenCatchProgress
@onready var _red_chase_progress: ProgressBar = %RedChaseProgress
@onready var _barrier_markers: Control = %BarrierMarkers
@onready var _barrier_prompt_panel: PanelContainer = %BarrierPromptPanel
@onready var _barrier_prompt: Label = %BarrierPrompt
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
@onready var _effect_status: Label = %EffectStatus
@onready var _chat_ui: ChatUIType = %ChatUI
@onready var _emote_radial_menu: EmoteRadialMenuType = %EmoteRadialMenu
@onready var _title_settings_panel: SettingsPanelType = (
	$UIRoot/TitleScreen/ResponsiveTitleStage/TitlePresentationScaleRoot/SettingsPanel
)
@onready var _pause_settings_panel: SettingsPanelType = (
	$UIRoot/CanonicalStage/PauseMenu/ResponsivePauseStage/PausePresentationScaleRoot/SettingsCenter/SettingsPanel
)

var _showcase_active: bool = false
var _player: PlayerType
var _player_menu_open: bool = false
var _gameplay_ui_enabled: bool = false
var _fishing_spot: FishingSpotType
var _system_menu_open: bool = false
var _shop_open: bool = false
var _chat_input_open: bool = false
var _player_menu_hotbar_visible: bool = false
var _item_effects: PlayerItemEffectsType
var _main_shop_buyer: FishBuyerProfileType
var _shop_interaction: ShopInteractionType


func _ready() -> void:
	_emote_radial_menu.emote_selected.connect(_on_emote_selected)
	_chat_ui.text_entry_ownership_changed.connect(
		_on_chat_text_entry_ownership_changed
	)
	_hotbar_ui.presentation_transition_finished.connect(
		_on_hotbar_presentation_transition_finished
	)
	_title_settings_panel.panel_visibility_changed.connect(
		_on_settings_visibility_changed
	)
	_pause_settings_panel.panel_visibility_changed.connect(
		_on_settings_visibility_changed
	)
	_title_settings_panel.crisp_reset_focus_requested.connect(
		crisp_reset_focus_requested.emit
	)
	_pause_settings_panel.crisp_reset_focus_requested.connect(
		crisp_reset_focus_requested.emit
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
	main_shop_buyer: FishBuyerProfileType,
	fishing_upgrades: PlayerFishingUpgradesType,
	shop_interaction: ShopInteractionType,
	item_effects: PlayerItemEffectsType,
	cooler_capacity: PlayerCoolerCapacityType,
	network_session: NetworkSessionType,
	network_sale_service: NetworkSaleService,
	network_shop_service: NetworkShopService,
	network_chat_service: NetworkChatService,
	network_profile: NetworkProfilePreferences,
	spawn_service: PlayerSpawnService,
	network_mail_service: NetworkMailService,
	reservations: PlayerAssetReservationService,
	network_profile_service: NetworkProfileService,
	network_player_list: NetworkPlayerListService,
	settings_manager: PlayerSettingsManagerType,
) -> void:
	_player = player
	_fishing_spot = fishing_spot
	_item_effects = item_effects
	_chat_ui.setup(
		network_chat_service, network_session, spawn_service, player,
		fishing_spot, settings_manager
	)
	_title_settings_panel.setup_network_profile(
		network_profile, network_session
	)
	_pause_settings_panel.setup_network_profile(
		network_profile, network_session
	)
	fishing_spot.status_changed.connect(_on_fishing_status_changed)
	fishing_spot.catch_display_changed.connect(_on_catch_display_changed)
	fishing_spot.showcase_changed.connect(_on_showcase_changed)
	_player_menu.menu_visibility_changed.connect(
		_on_player_menu_visibility_changed
	)
	_player_menu.menu_exit_started.connect(_on_player_menu_exit_started)
	_player_menu.inventory_hotbar_context_changed.connect(
		_on_inventory_hotbar_context_changed
	)
	_player_menu.shop_cooler_modal_changed.connect(
		_on_shop_cooler_modal_changed
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
		item_catalog,
		cooler_capacity,
		network_session,
		network_sale_service,
		network_mail_service,
		reservations,
		network_profile_service,
		network_player_list,
	)
	_hotbar_ui.setup(hotbar, bag, item_catalog, fishing_spot)
	_fishing_shop.setup(
		player,
		wallet,
		main_shop_buyer,
		fishing_upgrades,
		fishing_spot,
		shop_interaction,
		bag,
		item_catalog,
		cooler_capacity,
		network_shop_service,
	)
	_fishing_shop.menu_visibility_changed.connect(_on_shop_visibility_changed)
	_fishing_shop.sell_fish_requested.connect(_on_shop_sell_fish_requested)
	_fishing_shop.shop_cooler_return_requested.connect(
		_on_shop_cooler_return_requested
	)
	_fishing_shop.shop_cooler_confirmation_cancel_requested.connect(
		_player_menu.cancel_shop_cooler_confirmation
	)
	_main_shop_buyer = main_shop_buyer
	_shop_interaction = shop_interaction


func _input(event: InputEvent) -> void:
	if _emote_radial_menu == null:
		return
	var can_open: bool = (
		_gameplay_ui_enabled
		and not _system_menu_open
		and not _player_menu_open
		and not _shop_open
		and not _chat_input_open
		and not _showcase_active
	)
	if _emote_radial_menu.handle_input(event, can_open):
		get_viewport().set_input_as_handled()


func _on_emote_selected(emote_id: StringName) -> void:
	if emote_id == &"sit" and _player != null:
		_player.toggle_sitting()


func setup_data_and_identity(
	data_root: PlayerDataRoot,
	identity_backups: IdentityBackupService,
	player_identity: PlayerIdentityStore,
	host_identity: HostIdentityStore,
	network_session: NetworkSession,
	interface_fonts: InterfaceFontController,
) -> void:
	for panel: SettingsPanelType in [
		_title_settings_panel, _pause_settings_panel
	]:
		panel.setup_data_and_identity(
			data_root,
			identity_backups,
			player_identity,
			host_identity,
			network_session,
			interface_fonts,
		)


func _process(_delta: float) -> void:
	if _item_effects == null or not _gameplay_ui_enabled:
		_effect_status.hide()
		return
	var parts: Array[String] = []
	for item_id: StringName in [
		PlayerItemEffectsType.COFFEE_ID,
		PlayerItemEffectsType.ENERGY_DRINK_ID,
		PlayerItemEffectsType.SNACK_ID,
		PlayerItemEffectsType.FISH_FINDER_ID,
	]:
		var remaining: float = _item_effects.get_remaining(item_id)
		if remaining <= 0.0:
			continue
		var label: String = {
			PlayerItemEffectsType.COFFEE_ID: "coffee",
			PlayerItemEffectsType.ENERGY_DRINK_ID: "energy",
			PlayerItemEffectsType.SNACK_ID: "snack",
			PlayerItemEffectsType.FISH_FINDER_ID: "finder",
		}.get(item_id, "")
		parts.append(
			"%s %d:%02d"
			% [label, floori(remaining / 60.0), int(remaining) % 60]
		)
	_effect_status.text = "  ".join(parts)
	_effect_status.visible = not parts.is_empty()


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
	_gameplay_transient_hud.visible = enabled and not _player_menu_open
	_refresh_chat_availability()
	if not enabled:
		close_player_menu_for_session_end()
		_fishing_shop.close_for_session_end()
		_fishing_panel.visible = false
		_shop_prompt.hide()
		_hotbar_ui.set_presentation_visible(false, false)
		_hotbar_ui.set_gameplay_input_enabled(false)
	else:
		_refresh_hotbar_visibility()
		_hotbar_ui.set_gameplay_input_enabled(true)
		_refresh_fishing_panel_visibility()


func set_system_menu_open(is_open: bool) -> void:
	_system_menu_open = is_open
	_refresh_chat_availability()
	_refresh_hotbar_visibility()
	_hotbar_ui.set_gameplay_input_enabled(
		_gameplay_ui_enabled
		and not is_open
		and not _player_menu_open
		and not _shop_open
	)
	_hotbar_ui.set_drag_enabled(_player_menu_open and not is_open)
	if is_open:
		_hotbar_ui.set_drag_enabled(false)
		_shop_prompt.hide()
	_emit_interactive_pointer_ui_changed()


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


func set_effective_ui_pixel_size(pixel_size: int) -> void:
	_title_settings_panel.set_effective_ui_pixel_size(pixel_size)
	_pause_settings_panel.set_effective_ui_pixel_size(pixel_size)


func focus_open_settings_back_button() -> void:
	if _title_settings_panel.visible:
		_title_settings_panel.focus_back_button()
	elif _pause_settings_panel.visible:
		_pause_settings_panel.focus_back_button()


func refresh_open_settings_panel() -> void:
	_title_settings_panel.refresh_open_panel()
	_pause_settings_panel.refresh_open_panel()


func _on_settings_visibility_changed(_is_visible: bool) -> void:
	pixelation_settings_visibility_changed.emit(
		_title_settings_panel.visible or _pause_settings_panel.visible
	)


func _on_fishing_status_changed(status: String) -> void:
	if _showcase_active:
		return
	if _fishing_spot != null and _fishing_spot.is_fighting():
		return
	var normalized_status: String = status.strip_edges().to_lower()
	if normalized_status in [
		"fishing cancelled.",
		"fishing cancelled",
		"fishing failed.",
		"fishing failed",
		"fishing attempt ended.",
		"fishing attempt ended",
	]:
		_set_fishing_status("")
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
	_barrier_max_health: PackedInt32Array,
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
	_barrier_prompt_panel.visible = false
	_barrier_prompt.visible = false
	_barrier_health.visible = false
	if not encounter_visible:
		_barrier_health.visible = false
		_barrier_prompt.visible = false
		_clear_barrier_markers()
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
	if (
		active_barrier_index >= 0
		and active_barrier_index < barrier_health.size()
	):
		_barrier_prompt_panel.visible = true
		_barrier_prompt.visible = true
		_barrier_health.visible = true
		_barrier_health.text = "%d" % barrier_health[active_barrier_index]
	else:
		_barrier_prompt.visible = false
		_barrier_health.visible = false
		_barrier_health.text = ""
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
	_barrier_prompt_panel.visible = false
	_barrier_prompt.visible = false
	_barrier_health.visible = false
	_clear_barrier_markers()
	_showcase_details.text = (
		"%.1f lb • %s"
		% [weight_lb, rarity_name]
	)
	_showcase_details.visible = true
	_status_label.text = "You caught a %s!" % fish_name
	_status_label.visible = true
	_refresh_fishing_panel_visibility()


func _on_player_menu_visibility_changed(is_open: bool) -> void:
	_player_menu_open = is_open
	_gameplay_transient_hud.visible = _gameplay_ui_enabled and not is_open
	if is_open:
		_hotbar_ui.set_drag_enabled(false)
		_hotbar_ui.set_presentation_visible(false, false)
		if _player_menu_hotbar_visible:
			_hotbar_ui.set_player_menu_context(true)
			_hotbar_ui.set_presentation_visible(
				true,
				true,
				UIMotion.PLAYER_MENU_ENTER_DURATION,
			)
		player_menu_backdrop_visibility_changed.emit(true)
	else:
		_player_menu_hotbar_visible = false
		_hotbar_ui.set_presentation_visible(false, false)
		_hotbar_ui.set_player_menu_context(false)
	_refresh_chat_availability()
	_hotbar_ui.set_gameplay_input_enabled(
		_gameplay_ui_enabled and not is_open
	)
	if not is_open:
		_hotbar_ui.set_drag_enabled(false)
		_refresh_hotbar_visibility()
	_refresh_fishing_panel_visibility()
	_emit_interactive_pointer_ui_changed()
	if is_open:
		_shop_prompt.hide()
	else:
		_refresh_fishing_panel_visibility()


func _on_player_menu_exit_started() -> void:
	if not _player_menu_open:
		return
	_hotbar_ui.set_drag_enabled(false)
	_hotbar_ui.set_presentation_visible(
		false,
		true,
		UIMotion.PLAYER_MENU_EXIT_DURATION,
	)
	player_menu_backdrop_visibility_changed.emit(false)


func _on_shop_visibility_changed(is_open: bool) -> void:
	_shop_open = is_open
	shop_backdrop_visibility_changed.emit(is_open)
	if not is_open and _player_menu.is_shop_cooler_mounted():
		_player_menu.unmount_shop_cooler()
	_refresh_chat_availability()
	_refresh_hotbar_visibility()
	_hotbar_ui.set_gameplay_input_enabled(
		_gameplay_ui_enabled
		and not is_open
		and not _system_menu_open
		and not _player_menu_open
	)
	if is_open:
		_shop_prompt.hide()
	_emit_interactive_pointer_ui_changed()


func _on_shop_sell_fish_requested() -> void:
	if (
		not _fishing_shop.visible
		or _main_shop_buyer == null
		or not _main_shop_buyer.is_valid()
		or _shop_interaction == null
		or not _shop_interaction.is_local_player_in_range()
		or _fishing_spot == null
		or not _fishing_spot.is_ready_for_shop_transaction()
	):
		return
	if _player_menu.mount_shop_cooler(
		_fishing_shop.get_shop_cooler_mount(),
		_main_shop_buyer,
	):
		_fishing_shop.activate_shop_cooler_page()


func _on_shop_cooler_return_requested() -> void:
	_player_menu.unmount_shop_cooler()
	_fishing_shop.deactivate_shop_cooler_page()


func _on_shop_cooler_modal_changed(is_open: bool) -> void:
	_fishing_shop.set_shop_cooler_modal_open(is_open)


func _on_inventory_hotbar_context_changed(show_hotbar: bool) -> void:
	var context_changed: bool = _player_menu_hotbar_visible != show_hotbar
	_player_menu_hotbar_visible = show_hotbar
	if _player_menu_open and context_changed:
		_hotbar_ui.set_drag_enabled(false)
		if show_hotbar:
			_hotbar_ui.set_presentation_visible(false, false)
			_hotbar_ui.set_player_menu_context(true)
			_hotbar_ui.set_presentation_visible(
				true,
				true,
				UIMotion.PLAYER_MENU_INVENTORY_DURATION,
			)
		else:
			_hotbar_ui.set_presentation_visible(
				false,
				true,
				UIMotion.PLAYER_MENU_INVENTORY_DURATION,
			)
	elif _player_menu_open and show_hotbar:
		_hotbar_ui.set_drag_enabled(true)
	if not context_changed:
		return
	if not _player_menu_open:
		_refresh_hotbar_visibility()


func _on_hotbar_presentation_transition_finished(
	is_visible: bool,
) -> void:
	_hotbar_ui.set_drag_enabled(
		is_visible
		and _player_menu_open
		and _player_menu_hotbar_visible
		and not _system_menu_open
	)


func _refresh_hotbar_visibility() -> void:
	_hotbar_ui.set_presentation_visible(
		_gameplay_ui_enabled
		and not _system_menu_open
		and not _shop_open
		and (
			not _player_menu_open
			or _player_menu_hotbar_visible
		),
		_player_menu_open,
	)


func _emit_interactive_pointer_ui_changed() -> void:
	interactive_pointer_ui_changed.emit(
		_system_menu_open or _player_menu_open or _shop_open or _chat_input_open
	)


func _on_chat_text_entry_ownership_changed(active: bool) -> void:
	_chat_input_open = active
	_emit_interactive_pointer_ui_changed()


func _refresh_chat_availability() -> void:
	if _chat_ui == null:
		return
	var chat_available := (
		_gameplay_ui_enabled
		and not _system_menu_open
		and not _player_menu_open
		and not _shop_open
	)
	_chat_ui.set_available(chat_available)
	passive_pointer_ui_changed.emit(chat_available)
