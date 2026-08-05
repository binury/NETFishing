class_name GameUI
extends CanvasLayer

const CollectionLogType = preload("res://collection/collection_log.gd")
const FishBuyerProfileType = preload("res://economy/fish_buyer_profile.gd")
const FishSaleServiceType = preload("res://economy/fish_sale_service.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const FishQualityType = preload("res://fish/fish_quality.gd")
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
const QuickRadialMenuType = preload("res://ui/quick_radial_menu.gd")
const ControllerVirtualCursorType = preload(
	"res://ui/controller_virtual_cursor.gd"
)
const SurfaceDrawingToolbarType = preload(
	"res://ui/surface_drawing_toolbar.gd"
)
const PlayerSettingsManagerType = preload(
	"res://settings/player_settings_manager.gd"
)
const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const WorldTimeServiceType = preload("res://world/world_time_service.gd")
const WorldWeatherServiceType = preload(
	"res://world/world_weather_service.gd"
)
const PlayerExperienceType = preload(
	"res://progression/player_experience.gd"
)
const UIReferencePresentationType = preload(
	"res://ui/ui_reference_presentation.gd"
)

signal pixelation_settings_visibility_changed(is_visible: bool)
signal crisp_reset_focus_requested
signal interactive_pointer_ui_changed(is_open: bool)
signal passive_pointer_ui_changed(is_enabled: bool)
signal player_menu_backdrop_visibility_changed(is_visible: bool)
signal shop_backdrop_visibility_changed(is_visible: bool)

const VIRTUAL_MOUSE_INPUT_OWNER: StringName = &"controller_virtual_mouse"
const VIRTUAL_MOUSE_TRIGGER_THRESHOLD: float = 0.55
const VIRTUAL_MOUSE_TRIGGER_RELEASE_THRESHOLD: float = 0.35
const VIRTUAL_MOUSE_STICK_DEADZONE: float = 0.18
const VIRTUAL_MOUSE_SPEED: float = 720.0
const CONTROLLER_MENU_SCROLL_DEADZONE: float = 0.25
const CONTROLLER_MENU_SCROLL_SPEED: float = 660.0
# Android controller mappings may expose LT on its own axis or as the negative
# half of the same signed axis used by RT. Support both without letting the RT
# zoom direction enter virtual-pointer mode.
const VIRTUAL_MOUSE_TRIGGER_AXIS: JoyAxis = JOY_AXIS_TRIGGER_RIGHT
const VIRTUAL_MOUSE_SHARED_TRIGGER_AXIS: JoyAxis = JOY_AXIS_TRIGGER_LEFT
const VIRTUAL_MOUSE_SECONDARY_CLICK_AXIS: JoyAxis = JOY_AXIS_TRIGGER_LEFT
const FISHING_PANEL_DEFAULT_TOP_OFFSET: float = -210.0
const FISHING_PANEL_DEFAULT_BOTTOM_OFFSET: float = -140.0
const FISHING_PANEL_SHOWCASE_TOP_OFFSET: float = -174.0
const FISHING_PANEL_SHOWCASE_BOTTOM_OFFSET: float = -104.0

@onready var _status_label: Label = %StatusLabel
@onready var _gameplay_transient_hud: Control = %GameplayTransientHUD
@onready var _experience_presentation: Control = %ExperiencePresentation
@onready var _catch_track: Control = %CatchTrack
@onready var _green_catch_progress: ProgressBar = %GreenCatchProgress
@onready var _red_chase_progress: ProgressBar = %RedChaseProgress
@onready var _barrier_markers: Control = %BarrierMarkers
@onready var _barrier_prompt_panel: PanelContainer = %BarrierPromptPanel
@onready var _barrier_prompt: Label = %BarrierPrompt
@onready var _barrier_health: Label = %BarrierHealth
@onready var _showcase_details: Label = %ShowcaseDetails
@onready var _fishing_panel: PanelContainer = %FishingPanel
@onready var _experience_panel: PanelContainer = %ExperienceProgressPanel
@onready var _experience_level_label: Label = %ExperienceLevelLabel
@onready var _experience_award_label: Label = %ExperienceAwardLabel
@onready var _experience_progress: ProgressBar = %ExperienceProgress
@onready var _experience_bubble: PanelContainer = %ExperienceBubble
@onready var _experience_bubble_label: Label = %ExperienceBubbleLabel
@onready var _canonical_stage: Control = %CanonicalStage
@onready var _ui_root: Control = %UIRoot
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
@onready var _quick_radial_menu: QuickRadialMenuType = %QuickRadialMenu
@onready var _controller_virtual_cursor: ControllerVirtualCursorType = (
	%ControllerVirtualCursor
)
@onready var _surface_drawing_toolbar: SurfaceDrawingToolbarType = (
	%SurfaceDrawingToolbar
)
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
var _surface_drawing: NetworkSurfaceDrawingService
var _experience: PlayerExperienceType
var _experience_award_queue: Array[Dictionary] = []
var _experience_animation_active: bool = false
var _experience_animation_generation: int = 0
var _experience_panel_rest_y: float = 18.0
var _emote_prior_camera_input_enabled: bool = true
var _quick_prior_camera_input_enabled: bool = true
var _virtual_mouse_active: bool = false
var _virtual_mouse_prior_camera_input_enabled: bool = true
var _virtual_mouse_prior_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _virtual_mouse_window_position: Vector2 = Vector2.ZERO
var _virtual_mouse_button_mask: int = 0
var _virtual_mouse_right_pressed: bool = false
var _virtual_mouse_device_id: int = 0
var _virtual_mouse_trigger_strength: float = 0.0
var _virtual_mouse_stick: Vector2 = Vector2.ZERO
var _virtual_mouse_trigger_rest_by_device: Dictionary[int, float] = {}
var _shared_trigger_rest_by_device: Dictionary[int, float] = {}
var _controller_mapping_manager: ControllerMappingManagerType
var _settings_manager: PlayerSettingsManagerType


func _ready() -> void:
	# Reward feedback must remain above full-screen canonical menus. Keeping the
	# overlay as the final stage child makes that ownership explicit instead of
	# relying on scene declaration order when another menu adds high-z children.
	var presentation_parent: Node = _experience_presentation.get_parent()
	if presentation_parent != null:
		presentation_parent.move_child(
			_experience_presentation,
			presentation_parent.get_child_count() - 1,
		)
	_emote_radial_menu.emote_selected.connect(_on_emote_selected)
	_quick_radial_menu.action_selected.connect(_on_quick_action_selected)
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
	if not Input.joy_connection_changed.is_connected(
		_on_controller_connection_changed
	):
		Input.joy_connection_changed.connect(_on_controller_connection_changed)


func setup(
	player: PlayerType,
	inventory: FishInventoryType,
	collection_log: CollectionLogType,
	experience: PlayerExperienceType,
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
	surface_drawing: NetworkSurfaceDrawingService,
	art_unlocks: PlayerArtUnlocks,
	world_time: WorldTimeServiceType,
	world_weather: WorldWeatherServiceType,
	player_jobs: PlayerJobService,
	world_environment: WorldEnvironment,
	world_sun: DirectionalLight3D,
) -> void:
	_player = player
	_settings_manager = settings_manager
	_fishing_spot = fishing_spot
	_item_effects = item_effects
	_experience = experience
	if (
		_experience != null
		and not _experience.experience_awarded.is_connected(
			_on_experience_awarded
		)
	):
		_experience.experience_awarded.connect(_on_experience_awarded)
	_chat_ui.setup(
		network_chat_service, network_session, spawn_service, player,
		fishing_spot, settings_manager, world_time, world_weather
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
	fishing_spot.art_ui_toggle_requested.connect(_toggle_surface_drawing)
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
		experience,
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
		player_jobs,
		world_time,
		world_environment,
		world_sun,
	)
	if (
		_settings_manager != null
		and not _settings_manager.settings_changed.is_connected(
			_on_player_settings_changed
		)
	):
		_settings_manager.settings_changed.connect(_on_player_settings_changed)
	if _settings_manager != null:
		_on_player_settings_changed(_settings_manager.current_settings)
	_hotbar_ui.setup(hotbar, bag, item_catalog, fishing_spot, inventory)
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
		art_unlocks,
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
	_surface_drawing = surface_drawing
	_surface_drawing_toolbar.setup(_surface_drawing, art_unlocks)
	set_edge_docks(
		settings_manager.current_settings.chat_dock_right,
		settings_manager.current_settings.paint_dock_right,
		settings_manager.current_settings.chat_mobile_mode,
	)


func _input(event: InputEvent) -> void:
	if _handle_virtual_mouse_input(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_controller_chat_controls(event):
		get_viewport().set_input_as_handled()
		return
	if (
		_surface_drawing_toolbar != null
		and _surface_drawing_toolbar.owns_pointer_event(event)
	):
		return
	var drawing_can_open: bool = (
		_gameplay_ui_enabled
		and not _system_menu_open
		and not _player_menu_open
		and not _shop_open
		and not _chat_input_open
		and not _showcase_active
		and _fishing_spot != null
		and _fishing_spot.can_use_surface_drawing()
	)
	if (
		_surface_drawing != null
		and _surface_drawing.handle_input(
			event,
			drawing_can_open,
			_drawing_pointer_window_position(),
		)
	):
		get_viewport().set_input_as_handled()
		return
	if _emote_radial_menu == null or _quick_radial_menu == null:
		return
	var can_open: bool = (
		_gameplay_ui_enabled
		and not _system_menu_open
		and not _player_menu_open
		and not _shop_open
		and not _chat_input_open
		and not _showcase_active
		and not _virtual_mouse_active
	)
	var emote_was_open: bool = _emote_radial_menu.is_open()
	if _emote_radial_menu.handle_input(
		event,
		can_open and not _quick_radial_menu.is_open(),
	):
		var emote_is_open: bool = _emote_radial_menu.is_open()
		if emote_is_open != emote_was_open and _player != null:
			if emote_is_open:
				_emote_prior_camera_input_enabled = (
					_player.is_camera_input_enabled()
				)
				_player.set_camera_input_enabled(false)
			else:
				_player.set_camera_input_enabled(
					_emote_prior_camera_input_enabled
				)
		get_viewport().set_input_as_handled()
		return
	var quick_was_open: bool = _quick_radial_menu.is_open()
	if _quick_radial_menu.handle_input(
		event,
		can_open and not _emote_radial_menu.is_open(),
	):
		var quick_is_open: bool = _quick_radial_menu.is_open()
		if quick_is_open != quick_was_open and _player != null:
			if quick_is_open:
				_quick_prior_camera_input_enabled = (
					_player.is_camera_input_enabled()
				)
				_player.set_camera_input_enabled(false)
			else:
				_player.set_camera_input_enabled(
					_quick_prior_camera_input_enabled
				)
		get_viewport().set_input_as_handled()


func _handle_controller_chat_controls(event: InputEvent) -> bool:
	var button_event: InputEventJoypadButton = event as InputEventJoypadButton
	if (
		button_event == null
		or not button_event.pressed
		or not _gameplay_ui_enabled
		or _system_menu_open
		or _player_menu_open
		or _shop_open
	):
		return false
	var use_mapping: bool = (
		_controller_mapping_manager != null
	)
	var select_pressed: bool = (
		_controller_mapping_manager.event_matches_role(
			event, ControllerMappingManagerType.ROLE_SELECT
		)
		if use_mapping
		else button_event.button_index == JOY_BUTTON_BACK
	)
	var focus_pressed: bool = (
		_controller_mapping_manager.event_matches_role(
			event, ControllerMappingManagerType.ROLE_LB
		)
		if use_mapping
		else button_event.button_index == JOY_BUTTON_LEFT_SHOULDER
	)
	var accept_pressed: bool = (
		_controller_mapping_manager.event_matches_role(
			event, ControllerMappingManagerType.ROLE_A
		)
		if use_mapping
		else button_event.button_index == JOY_BUTTON_A
	)
	if select_pressed:
		# Handle Select before focused LineEdit controls consume it. Select owns
		# chat visibility while LB only returns input ownership to the world.
		_chat_ui.toggle_chat()
		return true
	if focus_pressed:
		_chat_ui.toggle_focus()
		return true
	if accept_pressed:
		return _chat_ui.request_virtual_keyboard()
	return false


func _on_emote_selected(emote_id: StringName) -> void:
	if emote_id == &"sit" and _player != null:
		_player.toggle_sitting()


func _on_quick_action_selected(action_id: StringName) -> void:
	match action_id:
		&"stuff":
			_player_menu.open_section(PlayerMenuType.Section.COOLER)
		&"logbook":
			_player_menu.open_section(PlayerMenuType.Section.LOGBOOK)
		&"fishnet":
			_player_menu.open_section(PlayerMenuType.Section.NET)
		&"mail":
			_player_menu.open_section(PlayerMenuType.Section.MAIL)
		&"profile":
			_player_menu.open_section(PlayerMenuType.Section.PROFILE)
		&"online":
			_player_menu.open_section(PlayerMenuType.Section.PLAYERS)
		&"paint":
			_toggle_surface_drawing()
		&"chat":
			_chat_ui.open_chat()


func _handle_virtual_mouse_input(event: InputEvent) -> bool:
	if (
		_controller_mapping_manager != null
		and _controller_mapping_manager.has_custom_mapping()
	):
		return _handle_mapped_virtual_mouse_input(event)
	var motion_event: InputEventJoypadMotion = event as InputEventJoypadMotion
	if motion_event != null:
		if motion_event.axis in [
			VIRTUAL_MOUSE_TRIGGER_AXIS,
			VIRTUAL_MOUSE_SHARED_TRIGGER_AXIS,
		]:
			if (
				_virtual_mouse_active
				and motion_event.device != _virtual_mouse_device_id
			):
				return false
			_sample_trigger_rest_values(motion_event.device)
			_virtual_mouse_trigger_strength = (
				_virtual_mouse_strength_for_device(motion_event.device)
			)
			var was_active: bool = _virtual_mouse_active
			if (
				_virtual_mouse_trigger_strength
				>= VIRTUAL_MOUSE_TRIGGER_THRESHOLD
			):
				if not _virtual_mouse_active and _can_start_virtual_mouse():
					_begin_virtual_mouse(motion_event.device)
			elif (
				_virtual_mouse_active
				and _virtual_mouse_trigger_strength
				< VIRTUAL_MOUSE_TRIGGER_RELEASE_THRESHOLD
			):
				_end_virtual_mouse()
			elif _virtual_mouse_active:
				_set_virtual_mouse_button(
					MOUSE_BUTTON_RIGHT,
					_secondary_click_strength_for_device(
						motion_event.device
					) >= VIRTUAL_MOUSE_TRIGGER_THRESHOLD,
				)
			return was_active or _virtual_mouse_active
		if (
			_virtual_mouse_active
			and motion_event.device == _virtual_mouse_device_id
			and motion_event.axis in [
				JOY_AXIS_RIGHT_X,
				JOY_AXIS_RIGHT_Y,
			]
		):
			if motion_event.axis == JOY_AXIS_RIGHT_X:
				_virtual_mouse_stick.x = motion_event.axis_value
			else:
				_virtual_mouse_stick.y = motion_event.axis_value
			return true
	var button_event: InputEventJoypadButton = event as InputEventJoypadButton
	if (
		button_event != null
		and button_event.button_index == JOY_BUTTON_RIGHT_SHOULDER
		and (
			_virtual_mouse_active
			or _virtual_mouse_trigger_strength
				>= VIRTUAL_MOUSE_TRIGGER_THRESHOLD
		)
	):
		if not _virtual_mouse_active and _can_start_virtual_mouse():
			_begin_virtual_mouse(button_event.device)
		if _virtual_mouse_active:
			_set_virtual_mouse_button(MOUSE_BUTTON_LEFT, button_event.pressed)
			return true
	return false


func _handle_mapped_virtual_mouse_input(event: InputEvent) -> bool:
	var uses_activation: bool = _controller_mapping_manager.event_uses_role(
		event,
		ControllerMappingManagerType.ROLE_POINTER_MODIFIER,
	)
	if uses_activation:
		var was_active: bool = _virtual_mouse_active
		_virtual_mouse_trigger_strength = (
			_controller_mapping_manager.get_role_strength(
				ControllerMappingManagerType.ROLE_POINTER_MODIFIER
			)
		)
		if (
			_virtual_mouse_trigger_strength
			>= VIRTUAL_MOUSE_TRIGGER_THRESHOLD
			and not _virtual_mouse_active
			and _can_start_virtual_mouse()
		):
			_begin_virtual_mouse(
				_controller_mapping_manager.get_active_device_id()
			)
		elif (
			_virtual_mouse_active
			and _virtual_mouse_trigger_strength
			< VIRTUAL_MOUSE_TRIGGER_RELEASE_THRESHOLD
		):
			_end_virtual_mouse()
		return was_active or _virtual_mouse_active
	if not _virtual_mouse_active:
		return false
	if (
		_controller_mapping_manager.event_uses_role(
			event,
			ControllerMappingManagerType.ROLE_RIGHT_STICK_X,
		)
		or _controller_mapping_manager.event_uses_role(
			event,
			ControllerMappingManagerType.ROLE_RIGHT_STICK_Y,
		)
	):
		_virtual_mouse_stick = _mapped_virtual_mouse_stick()
		return true
	var button_event := event as InputEventJoypadButton
	if button_event != null and _controller_mapping_manager.event_uses_role(
		event,
		ControllerMappingManagerType.ROLE_RB,
	):
		_set_virtual_mouse_button(MOUSE_BUTTON_LEFT, button_event.pressed)
		return true
	if _controller_mapping_manager.event_uses_role(
		event,
		ControllerMappingManagerType.ROLE_CAMERA_ZOOM,
	):
		_set_virtual_mouse_button(
			MOUSE_BUTTON_RIGHT,
			_controller_mapping_manager.get_role_strength(
				ControllerMappingManagerType.ROLE_CAMERA_ZOOM
			) >= VIRTUAL_MOUSE_TRIGGER_THRESHOLD,
		)
		return true
	return false


func _mapped_virtual_mouse_stick() -> Vector2:
	return Vector2(
		_controller_mapping_manager.get_role_axis(
			ControllerMappingManagerType.ROLE_RIGHT_STICK_X
		),
		_controller_mapping_manager.get_role_axis(
			ControllerMappingManagerType.ROLE_RIGHT_STICK_Y
		),
	)


func _can_start_virtual_mouse() -> bool:
	return (
		_gameplay_ui_enabled
		and not _showcase_active
		and not _system_menu_open
		and not _player_menu_open
		and not _shop_open
		and not _chat_input_open
		and _player != null
		and _fishing_spot != null
		and _fishing_spot.can_open_system_menu()
		and not _emote_radial_menu.is_open()
		and not _quick_radial_menu.is_open()
	)


func _begin_virtual_mouse(device_id: int) -> void:
	if _virtual_mouse_active:
		return
	_virtual_mouse_active = true
	_virtual_mouse_device_id = maxi(device_id, 0)
	_virtual_mouse_stick = (
		_mapped_virtual_mouse_stick()
		if (
			_controller_mapping_manager != null
			and _controller_mapping_manager.has_custom_mapping()
		)
		else Vector2(
			Input.get_joy_axis(_virtual_mouse_device_id, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(_virtual_mouse_device_id, JOY_AXIS_RIGHT_Y),
		)
	)
	_virtual_mouse_prior_camera_input_enabled = (
		_player.is_camera_input_enabled()
	)
	_player.set_camera_input_enabled(false)
	if _fishing_spot != null:
		_fishing_spot.set_local_menu_input_suppressed(
			VIRTUAL_MOUSE_INPUT_OWNER,
			true,
		)
	_virtual_mouse_prior_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_virtual_mouse_button_mask = 0
	_virtual_mouse_right_pressed = false
	_virtual_mouse_window_position = _clamp_virtual_mouse_window_position(
		Vector2(get_window().size) * 0.5
	)
	_controller_virtual_cursor.visible = true
	_update_virtual_cursor_position(_virtual_mouse_window_position)
	_emit_virtual_mouse_motion(Vector2.ZERO)


func _end_virtual_mouse() -> void:
	if not _virtual_mouse_active:
		return
	if (_virtual_mouse_button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_set_virtual_mouse_button(MOUSE_BUTTON_LEFT, false)
	if _virtual_mouse_right_pressed:
		_set_virtual_mouse_button(MOUSE_BUTTON_RIGHT, false)
	_virtual_mouse_active = false
	_virtual_mouse_trigger_strength = 0.0
	_virtual_mouse_stick = Vector2.ZERO
	_controller_virtual_cursor.visible = false
	if _fishing_spot != null:
		_fishing_spot.set_local_menu_input_suppressed(
			VIRTUAL_MOUSE_INPUT_OWNER,
			false,
		)
	if _player != null and is_instance_valid(_player):
		_player.set_camera_input_enabled(
			_virtual_mouse_prior_camera_input_enabled
		)
	Input.mouse_mode = _virtual_mouse_prior_mouse_mode


func _update_virtual_mouse(delta: float) -> void:
	if not _virtual_mouse_active:
		return
	if (
		_virtual_mouse_trigger_strength
		< VIRTUAL_MOUSE_TRIGGER_RELEASE_THRESHOLD
	):
		_end_virtual_mouse()
		return
	var stick: Vector2 = _virtual_mouse_stick
	var stick_length: float = stick.length()
	if stick_length <= VIRTUAL_MOUSE_STICK_DEADZONE:
		return
	var adjusted_strength: float = (
		(stick_length - VIRTUAL_MOUSE_STICK_DEADZONE)
		/ (1.0 - VIRTUAL_MOUSE_STICK_DEADZONE)
	)
	var display_scale: float = UIReferencePresentationType.get_scale(
		Vector2(get_window().size)
	)
	var relative_motion: Vector2 = (
		stick.normalized()
		* adjusted_strength
		* VIRTUAL_MOUSE_SPEED
		* display_scale
		* delta
	)
	_virtual_mouse_window_position = _clamp_virtual_mouse_window_position(
		_virtual_mouse_window_position + relative_motion
	)
	_update_virtual_cursor_position(_virtual_mouse_window_position)
	_emit_virtual_mouse_motion(relative_motion)


func _poll_virtual_mouse_controller_state() -> void:
	if (
		_controller_mapping_manager != null
		and _controller_mapping_manager.has_custom_mapping()
	):
		_poll_mapped_virtual_mouse_controller_state()
		return
	var device_ids: Array[int] = Input.get_connected_joypads()
	# Some Android controller backends deliver device-0 axes without including
	# that device in get_connected_joypads(). Player camera input already uses
	# this same primary-device fallback.
	if device_ids.is_empty():
		device_ids.append(0)
	for device_id: int in device_ids:
		_sample_trigger_rest_values(device_id)
	if _virtual_mouse_active:
		if not device_ids.has(_virtual_mouse_device_id):
			_end_virtual_mouse()
			return
		_virtual_mouse_trigger_strength = _virtual_mouse_strength_for_device(
			_virtual_mouse_device_id
		)
		_set_virtual_mouse_button(
			MOUSE_BUTTON_RIGHT,
			_secondary_click_strength_for_device(
				_virtual_mouse_device_id
			) >= VIRTUAL_MOUSE_TRIGGER_THRESHOLD,
		)
		_virtual_mouse_stick = Vector2(
			Input.get_joy_axis(
				_virtual_mouse_device_id,
				JOY_AXIS_RIGHT_X,
			),
			Input.get_joy_axis(
				_virtual_mouse_device_id,
				JOY_AXIS_RIGHT_Y,
			),
		)
		return
	if not _can_start_virtual_mouse():
		return
	for device_id: int in device_ids:
		var trigger_strength: float = _virtual_mouse_strength_for_device(
			device_id
		)
		if trigger_strength < VIRTUAL_MOUSE_TRIGGER_THRESHOLD:
			continue
		_virtual_mouse_trigger_strength = trigger_strength
		_begin_virtual_mouse(device_id)
		return


func _poll_mapped_virtual_mouse_controller_state() -> void:
	var trigger_strength: float = _controller_mapping_manager.get_role_strength(
		ControllerMappingManagerType.ROLE_POINTER_MODIFIER
	)
	if _virtual_mouse_active:
		_virtual_mouse_trigger_strength = trigger_strength
		if trigger_strength < VIRTUAL_MOUSE_TRIGGER_RELEASE_THRESHOLD:
			_end_virtual_mouse()
			return
		_virtual_mouse_stick = _mapped_virtual_mouse_stick()
		_set_virtual_mouse_button(
			MOUSE_BUTTON_RIGHT,
			_controller_mapping_manager.get_role_strength(
				ControllerMappingManagerType.ROLE_CAMERA_ZOOM
			) >= VIRTUAL_MOUSE_TRIGGER_THRESHOLD,
		)
		return
	if (
		trigger_strength >= VIRTUAL_MOUSE_TRIGGER_THRESHOLD
		and _can_start_virtual_mouse()
	):
		_virtual_mouse_trigger_strength = trigger_strength
		_begin_virtual_mouse(
			_controller_mapping_manager.get_active_device_id()
		)


func _sample_trigger_rest_values(device_id: int) -> void:
	if not _virtual_mouse_trigger_rest_by_device.has(device_id):
		_virtual_mouse_trigger_rest_by_device[device_id] = Input.get_joy_axis(
			device_id,
			VIRTUAL_MOUSE_TRIGGER_AXIS,
		)
	if not _shared_trigger_rest_by_device.has(device_id):
		_shared_trigger_rest_by_device[device_id] = Input.get_joy_axis(
			device_id,
			VIRTUAL_MOUSE_SHARED_TRIGGER_AXIS,
		)


func _virtual_mouse_strength_for_device(device_id: int) -> float:
	_sample_trigger_rest_values(device_id)
	var dedicated_rest: float = (
		_virtual_mouse_trigger_rest_by_device[device_id]
	)
	var shared_rest: float = _shared_trigger_rest_by_device[device_id]
	var dedicated_strength: float = normalized_trigger_strength(
		Input.get_joy_axis(device_id, VIRTUAL_MOUSE_TRIGGER_AXIS),
		dedicated_rest,
	)
	var shared_negative_strength: float = directional_trigger_strength(
		Input.get_joy_axis(device_id, VIRTUAL_MOUSE_SHARED_TRIGGER_AXIS),
		shared_rest,
		-1.0,
	)
	return maxf(dedicated_strength, shared_negative_strength)


func _secondary_click_strength_for_device(device_id: int) -> float:
	_sample_trigger_rest_values(device_id)
	return directional_trigger_strength(
		Input.get_joy_axis(device_id, VIRTUAL_MOUSE_SECONDARY_CLICK_AXIS),
		_shared_trigger_rest_by_device[device_id],
		1.0,
	)


static func normalized_trigger_strength(
	axis_value: float,
	resting_value: float,
) -> float:
	var negative_travel: float = absf(-1.0 - resting_value)
	var positive_travel: float = absf(1.0 - resting_value)
	var available_travel: float = maxf(negative_travel, positive_travel)
	if available_travel <= 0.001:
		return 0.0
	return clampf(
		absf(axis_value - resting_value) / available_travel,
		0.0,
		1.0,
	)


static func directional_trigger_strength(
	axis_value: float,
	resting_value: float,
	direction: float,
) -> float:
	var normalized_direction: float = signf(direction)
	if is_zero_approx(normalized_direction):
		return 0.0
	var endpoint: float = normalized_direction
	var available_travel: float = absf(endpoint - resting_value)
	if available_travel <= 0.001:
		return 0.0
	var directed_travel: float = (
		(axis_value - resting_value) * normalized_direction
	)
	return clampf(directed_travel / available_travel, 0.0, 1.0)


func _set_virtual_mouse_button(button: MouseButton, pressed: bool) -> void:
	var mask: int = (
		MOUSE_BUTTON_MASK_LEFT
		if button == MOUSE_BUTTON_LEFT
		else MOUSE_BUTTON_MASK_RIGHT
	)
	var already_pressed: bool = bool(_virtual_mouse_button_mask & mask)
	if already_pressed == pressed:
		return
	if pressed:
		_virtual_mouse_button_mask |= mask
	else:
		_virtual_mouse_button_mask &= ~mask
	if button == MOUSE_BUTTON_RIGHT:
		_virtual_mouse_right_pressed = pressed
	var mouse_event := InputEventMouseButton.new()
	mouse_event.position = _virtual_mouse_window_position
	mouse_event.global_position = _virtual_mouse_window_position
	mouse_event.button_index = button
	mouse_event.button_mask = _virtual_mouse_button_mask
	mouse_event.pressed = pressed
	mouse_event.factor = 1.0
	_parse_virtual_mouse_event(mouse_event)


func _emit_virtual_mouse_motion(relative_motion: Vector2) -> void:
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = _virtual_mouse_window_position
	motion_event.global_position = _virtual_mouse_window_position
	motion_event.relative = relative_motion
	motion_event.button_mask = _virtual_mouse_button_mask
	_parse_virtual_mouse_event(motion_event)


func _parse_virtual_mouse_event(event: InputEventMouse) -> void:
	Input.parse_input_event(event)


func _update_virtual_cursor_position(viewport_position: Vector2) -> void:
	var output_scale: float = UIReferencePresentationType.get_scale(
		Vector2(get_window().size)
	)
	_controller_virtual_cursor.set_pointer_position(
		viewport_position / output_scale
	)


func _clamp_virtual_mouse_window_position(
	window_position: Vector2,
) -> Vector2:
	var bounds: Rect2 = get_virtual_mouse_window_bounds(
		Vector2(get_window().size)
	)
	return Vector2(
		clampf(window_position.x, bounds.position.x, bounds.end.x),
		clampf(window_position.y, bounds.position.y, bounds.end.y),
	)


static func get_virtual_mouse_window_bounds(window_size: Vector2) -> Rect2:
	var output_scale: float = UIReferencePresentationType.get_scale(window_size)
	var cursor_margin: Vector2 = (
		ControllerVirtualCursorType.CURSOR_SIZE * output_scale * 0.5
	)
	var bounds_size: Vector2 = Vector2(
		maxf(window_size.x - cursor_margin.x * 2.0, 0.0),
		maxf(window_size.y - cursor_margin.y * 2.0, 0.0),
	)
	return Rect2(cursor_margin, bounds_size)


func _toggle_surface_drawing() -> void:
	if _surface_drawing == null:
		return
	if _surface_drawing.is_active():
		_surface_drawing.deactivate()
	elif _surface_drawing.can_activate():
		_surface_drawing.activate(_drawing_pointer_window_position())


func _drawing_pointer_window_position() -> Vector2:
	if _virtual_mouse_active:
		return _virtual_mouse_window_position
	return get_window().get_mouse_position()


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


func setup_controller_mapping(
	mapping_manager: ControllerMappingManagerType,
) -> void:
	_controller_mapping_manager = mapping_manager
	_player.set_controller_mapping_manager(_controller_mapping_manager)
	_emote_radial_menu.setup_controller_mapping(_controller_mapping_manager)
	_quick_radial_menu.setup_controller_mapping(_controller_mapping_manager)
	_player_menu.setup_controller_mapping(_controller_mapping_manager)
	for panel: SettingsPanelType in [
		_title_settings_panel, _pause_settings_panel
	]:
		panel.setup_controller_mapping(_controller_mapping_manager)


func is_controller_mapping_capturing() -> bool:
	return (
		_title_settings_panel.is_controller_mapping_capturing()
		or _pause_settings_panel.is_controller_mapping_capturing()
	)


func _process(delta: float) -> void:
	_poll_virtual_mouse_controller_state()
	_update_virtual_mouse(delta)
	_update_controller_menu_scroll(delta)
	_update_experience_bubble_position()
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


func _update_controller_menu_scroll(delta: float) -> void:
	if (
		_controller_mapping_manager == null
		or _virtual_mouse_active
		or is_controller_mapping_capturing()
	):
		return
	var stick_y: float = _controller_menu_scroll_axis()
	var magnitude: float = absf(stick_y)
	if magnitude <= CONTROLLER_MENU_SCROLL_DEADZONE:
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	var scroll: ScrollContainer = _focused_scroll_container(focus_owner)
	if scroll == null:
		return
	var adjusted_axis: float = (
		signf(stick_y)
		* (magnitude - CONTROLLER_MENU_SCROLL_DEADZONE)
		/ (1.0 - CONTROLLER_MENU_SCROLL_DEADZONE)
	)
	scroll.scroll_vertical += roundi(
		adjusted_axis * CONTROLLER_MENU_SCROLL_SPEED * delta
	)


func _focused_scroll_container(focus_owner: Control) -> ScrollContainer:
	if focus_owner == null or not focus_owner.is_visible_in_tree():
		return null
	var current: Node = focus_owner
	while current != null:
		var scroll := current as ScrollContainer
		if scroll != null:
			if _controller_scroll_container_is_available(scroll):
				return scroll
			return null
		var candidates: Array[ScrollContainer] = []
		_collect_controller_scroll_containers(current, candidates)
		if candidates.size() == 1:
			return candidates[0]
		if candidates.size() > 1:
			return null
		current = current.get_parent()
	return null


func _collect_controller_scroll_containers(
	root_node: Node,
	result: Array[ScrollContainer],
) -> void:
	for child: Node in root_node.get_children():
		var canvas_item := child as CanvasItem
		if canvas_item != null and not canvas_item.is_visible_in_tree():
			continue
		var scroll := child as ScrollContainer
		if scroll != null and _controller_scroll_container_is_available(scroll):
			result.append(scroll)
		_collect_controller_scroll_containers(child, result)


func _controller_scroll_container_is_available(
	scroll: ScrollContainer,
) -> bool:
	return (
		scroll.is_visible_in_tree()
		and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
	)


func _controller_menu_scroll_axis() -> float:
	if _controller_mapping_manager != null:
		return _controller_mapping_manager.get_role_axis(
			ControllerMappingManagerType.ROLE_RIGHT_STICK_Y
		)
	return Input.get_joy_axis(
		0,
		JOY_AXIS_RIGHT_Y,
	)


func _on_controller_connection_changed(
	device_id: int,
	connected: bool,
) -> void:
	_virtual_mouse_trigger_rest_by_device.erase(device_id)
	_shared_trigger_rest_by_device.erase(device_id)
	if not connected and _virtual_mouse_device_id == device_id:
		_end_virtual_mouse()


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
	_experience_presentation.visible = enabled
	_refresh_chat_availability()
	if not enabled:
		_end_virtual_mouse()
		if _emote_radial_menu != null and _emote_radial_menu.is_open():
			_emote_radial_menu.close_menu()
			if _player != null:
				_player.set_camera_input_enabled(
					_emote_prior_camera_input_enabled
				)
		if _quick_radial_menu != null and _quick_radial_menu.is_open():
			_quick_radial_menu.close_menu()
			if _player != null:
				_player.set_camera_input_enabled(
					_quick_prior_camera_input_enabled
				)
		if _surface_drawing != null:
			_surface_drawing.deactivate()
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
		call_deferred("_start_next_experience_animation")


func set_system_menu_open(is_open: bool) -> void:
	_system_menu_open = is_open
	if is_open and _surface_drawing != null:
		_surface_drawing.deactivate()
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


func _on_player_settings_changed(settings: PlayerSettings) -> void:
	if settings != null:
		_player_menu.set_profile_preview_world_pixel_size(
			settings.world_pixel_size
		)


func set_edge_docks(
	chat_dock_right: bool,
	paint_dock_right: bool,
	chat_mobile_mode: bool,
) -> void:
	_chat_ui.set_dock_right(chat_dock_right)
	_chat_ui.set_mobile_mode(chat_mobile_mode)
	_surface_drawing_toolbar.set_dock_right(paint_dock_right)


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
			else UIPalette.PRIMARY
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
	quality: int,
	visible: bool,
) -> void:
	_showcase_active = visible
	if not visible:
		_set_fishing_panel_showcase_position(false)
		_showcase_details.text = ""
		_showcase_details.visible = false
		_set_fishing_status("")
		call_deferred("_start_next_experience_animation")
		return
	_set_fishing_panel_showcase_position(true)
	_catch_track.visible = false
	_barrier_prompt_panel.visible = false
	_barrier_prompt.visible = false
	_barrier_health.visible = false
	_clear_barrier_markers()
	_showcase_details.text = (
		"%s • %.1f lb"
		% [rarity_name.to_lower(), weight_lb]
	)
	_showcase_details.visible = true
	_status_label.text = "You caught %s!" % (
		FishQualityType.qualified_name_with_article(fish_name, quality)
	)
	_status_label.visible = true
	_refresh_fishing_panel_visibility()


func _set_fishing_panel_showcase_position(showcase: bool) -> void:
	_fishing_panel.offset_top = (
		FISHING_PANEL_SHOWCASE_TOP_OFFSET
		if showcase
		else FISHING_PANEL_DEFAULT_TOP_OFFSET
	)
	_fishing_panel.offset_bottom = (
		FISHING_PANEL_SHOWCASE_BOTTOM_OFFSET
		if showcase
		else FISHING_PANEL_DEFAULT_BOTTOM_OFFSET
	)


func _on_experience_awarded(
	amount: int,
	previous_total: int,
	new_total: int,
	previous_level: int,
	new_level: int,
) -> void:
	if amount <= 0:
		return
	_experience_award_queue.append({
		"amount": amount,
		"previous_total": previous_total,
		"new_total": new_total,
		"previous_level": previous_level,
		"new_level": new_level,
	})
	_start_next_experience_animation()


func _start_next_experience_animation() -> void:
	if (
		_experience_animation_active
		or _showcase_active
		or _experience_award_queue.is_empty()
		or not _gameplay_ui_enabled
	):
		return
	var award: Dictionary = _experience_award_queue.pop_front()
	_experience_animation_active = true
	_experience_animation_generation += 1
	var generation: int = _experience_animation_generation
	_play_experience_animation(award, generation)


func _play_experience_animation(
	award: Dictionary,
	generation: int,
) -> void:
	var amount: int = int(award.get("amount", 0))
	var previous_total: int = int(award.get("previous_total", 0))
	var new_total: int = int(award.get("new_total", previous_total))
	_experience_award_label.text = "+%d xp" % amount
	_experience_bubble_label.text = "+%d xp!" % amount
	_update_experience_progress(previous_total)
	_experience_panel.position.y = -_experience_panel.size.y - 8.0
	_experience_panel.modulate.a = 0.0
	_experience_panel.show()
	_experience_bubble.modulate.a = 0.0
	_experience_bubble.scale = Vector2(0.72, 0.72)
	_experience_bubble.pivot_offset = _experience_bubble.size * 0.5
	_experience_bubble.show()

	var entry_tween: Tween = create_tween()
	entry_tween.set_parallel(true)
	entry_tween.tween_property(
		_experience_panel,
		"position:y",
		_experience_panel_rest_y,
		0.26,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	entry_tween.tween_property(
		_experience_panel,
		"modulate:a",
		1.0,
		0.18,
	)
	entry_tween.tween_property(
		_experience_bubble,
		"modulate:a",
		1.0,
		0.15,
	)
	entry_tween.tween_property(
		_experience_bubble,
		"scale",
		Vector2.ONE,
		0.28,
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await entry_tween.finished
	if generation != _experience_animation_generation:
		return

	var fill_duration: float = clampf(
		0.8 + float(amount) * 0.006,
		0.9,
		1.65,
	)
	var fill_tween: Tween = create_tween()
	fill_tween.tween_method(
		Callable(self, "_set_experience_animation_progress").bind(
			previous_total,
			new_total,
		),
		0.0,
		1.0,
		fill_duration,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await fill_tween.finished
	if generation != _experience_animation_generation:
		return
	await get_tree().create_timer(0.75).timeout
	if generation != _experience_animation_generation:
		return

	var exit_tween: Tween = create_tween()
	exit_tween.set_parallel(true)
	exit_tween.tween_property(
		_experience_panel,
		"modulate:a",
		0.0,
		0.24,
	)
	exit_tween.tween_property(
		_experience_bubble,
		"modulate:a",
		0.0,
		0.2,
	)
	exit_tween.tween_property(
		_experience_bubble,
		"scale",
		Vector2(0.82, 0.82),
		0.24,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await exit_tween.finished
	if generation != _experience_animation_generation:
		return
	_experience_panel.hide()
	_experience_bubble.hide()
	_experience_animation_active = false
	call_deferred("_start_next_experience_animation")


func _set_experience_animation_progress(
	progress: float,
	previous_total: int,
	new_total: int,
) -> void:
	var displayed_total: int = roundi(lerpf(
		float(previous_total),
		float(new_total),
		clampf(progress, 0.0, 1.0),
	))
	_update_experience_progress(displayed_total)


func _update_experience_progress(total_experience: int) -> void:
	var level: int = PlayerExperienceType.level_for_total_experience(
		total_experience
	)
	_experience_level_label.text = "level %d" % level
	_experience_progress.value = (
		PlayerExperienceType.progress_for_total_experience(total_experience)
		* 100.0
	)


func _update_experience_bubble_position() -> void:
	if not _experience_animation_active or _player == null:
		return
	if _player_menu_open:
		_experience_bubble.show()
		_experience_bubble.position = Vector2(
			(_canonical_stage.size.x - _experience_bubble.size.x) * 0.5,
			_experience_panel_rest_y + _experience_panel.size.y + 10.0,
		)
		return
	var camera: Camera3D = _player.get_gameplay_camera()
	var anchor_position: Vector3 = _player.get_chat_anchor_position()
	if camera == null or camera.is_position_behind(anchor_position):
		_experience_bubble.hide()
		return
	_experience_bubble.show()
	var window_size := Vector2(get_window().size)
	var output_scale: float = UIReferencePresentationType.get_scale(
		window_size
	)
	var stage_position: Vector2 = (
		camera.unproject_position(anchor_position) / output_scale
		- _canonical_stage.position
	)
	var desired: Vector2 = stage_position - Vector2(
		_experience_bubble.size.x * 0.5,
		_experience_bubble.size.y + 10.0,
	)
	_experience_bubble.position = Vector2(
		clampf(
			desired.x,
			8.0,
			_canonical_stage.size.x - _experience_bubble.size.x - 8.0,
		),
		clampf(
			desired.y,
			8.0,
			_canonical_stage.size.y - _experience_bubble.size.y - 8.0,
		),
	)


func _on_player_menu_visibility_changed(is_open: bool) -> void:
	_player_menu_open = is_open
	if is_open:
		_end_virtual_mouse()
	if is_open and _surface_drawing != null:
		_surface_drawing.deactivate()
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
	if is_open and _surface_drawing != null:
		_surface_drawing.deactivate()
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
	if active and _surface_drawing != null:
		_surface_drawing.deactivate()
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
