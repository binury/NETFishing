extends Node3D

const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const FishBuyerProfileType = preload("res://economy/fish_buyer_profile.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const GameUIType = preload("res://ui/game_ui.gd")
const PlayerType = preload("res://player/player.gd")
const TestWorldType = preload("res://world/test_world.gd")
const WaterRecoveryControllerType = preload(
	"res://world/water_recovery_controller.gd"
)
const PlayerSaveManagerType = preload(
	"res://save/player_save_manager.gd"
)
const PlayerSettingsManagerType = preload(
	"res://settings/player_settings_manager.gd"
)
const PlayerSettingsType = preload("res://settings/player_settings.gd")
const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const TitleScreenType = preload("res://ui/title_screen.gd")
const PauseMenuType = preload("res://ui/pause_menu.gd")
const ItemCatalogType = preload("res://items/item_catalog.gd")
const ArtShopStockType = preload("res://economy/art_shop_stock.gd")
const ItemDataType = preload("res://items/item_data.gd")
const FishingRodDataType = preload("res://items/fishing_rod_data.gd")
const FishingShopStockType = preload("res://economy/fishing_shop_stock.gd")
const FishingShopType = preload("res://ui/fishing_shop.gd")
const FishingShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)
const UIPixelationPresenterType = preload(
	"res://ui/ui_pixelation_presenter.gd"
)
const PixelationResetOverlayType = preload(
	"res://ui/pixelation_reset_overlay.gd"
)
const WorldPixelationPostprocessType = preload(
	"res://main/world_pixelation_postprocess.gd"
)
const RuntimePerformanceProfileType = preload(
	"res://main/runtime_performance_profile.gd"
)
const NetworkSessionType = preload("res://network/network_session.gd")
const DiscoveryClientType = preload("res://network/discovery_client.gd")
const DedicatedServerConfigType = preload(
	"res://server/dedicated_server_config.gd"
)
const NetworkProfilePreferencesType = preload(
	"res://network/network_profile_preferences.gd"
)
const SavedServerStoreType = preload(
	"res://network/saved_server_store.gd"
)
const PlayerSpawnServiceType = preload(
	"res://network/player_spawn_service.gd"
)
const NetworkFishingServiceType = preload(
	"res://network/network_fishing_service.gd"
)
const PlayerHotbarType = preload("res://inventory/player_hotbar.gd")
const NetworkSaleServiceType = preload(
	"res://network/network_sale_service.gd"
)
const NetworkShopServiceType = preload(
	"res://network/network_shop_service.gd"
)
const NetworkItemUseServiceType = preload(
	"res://network/network_item_use_service.gd"
)
const NetworkFishShowcaseServiceType = preload(
	"res://network/network_fish_showcase_service.gd"
)
const NetworkSurfaceDrawingServiceType = preload(
	"res://network/network_surface_drawing_service.gd"
)
const NetworkChatServiceType = preload(
	"res://network/network_chat_service.gd"
)
const NetworkMailServiceType = preload(
	"res://network/network_mail_service.gd"
)
const PlayerAssetReservationServiceType = preload(
	"res://progression/player_asset_reservation_service.gd"
)
const PlayerAppearanceStoreType = preload(
	"res://progression/player_appearance_store.gd"
)
const NetworkProfileServiceType = preload(
	"res://network/network_profile_service.gd"
)
const WorldTimeServiceType = preload("res://world/world_time_service.gd")
const WorldTimeVisualControllerType = preload(
	"res://world/world_time_visual_controller.gd"
)
const NetworkWorldTimeServiceType = preload(
	"res://network/network_world_time_service.gd"
)
const WorldWeatherServiceType = preload("res://world/world_weather_service.gd")
const NetworkWorldWeatherServiceType = preload(
	"res://network/network_world_weather_service.gd"
)
const RainAmbienceType = preload("res://world/rain_ambience.gd")
const PlayerJobServiceType = preload("res://jobs/player_job_service.gd")
const NetworkJobServiceType = preload("res://network/network_job_service.gd")
const GatherableCatalogType = preload(
	"res://gathering/gatherable_catalog.gd"
)
const GatheringControllerType = preload(
	"res://gathering/gathering_controller.gd"
)
const NetworkWorldSpawnServiceType = preload(
	"res://network/network_world_spawn_service.gd"
)

const TITLE_MUSIC_SILENCE_DB: float = -80.0
const TIME_CROSSING_EPSILON_HOURS: float = 0.000001
const PLAYER_MENU_PATTERN_SCALE: float = 0.85
const PLAYER_MENU_PATTERN_SCROLL_VELOCITY := Vector2(-7.0, -5.0)
const SHOP_PATTERN_SCALE: float = 1.75

@export var fish_catalog: FishPoolType
@export var pelican_buyer_profile: FishBuyerProfileType
@export var main_shop_buyer_profile: FishBuyerProfileType
@export var item_catalog: ItemCatalogType
@export var gatherable_catalog: GatherableCatalogType
@export_category("Title Music")
@export_range(-40.0, 0.0, 0.5) var title_music_volume_db: float = -6.0
@export_range(0.0, 10.0, 0.05) var title_music_fade_out_seconds: float = 5.0

@onready var _test_world: TestWorldType = $TestWorld
@onready var _player: PlayerType = %Player
@onready var _fishing_spot: FishingSpotType = %FishingSpot
@onready var _game_ui: GameUIType = %GameUI
@onready var _water_recovery: WaterRecoveryControllerType = %WaterRecovery
@onready var _save_manager: PlayerSaveManagerType = %PlayerSaveManager
@onready var _settings_manager: PlayerSettingsManagerType = %PlayerSettingsManager
@onready var _controller_mapping_manager: ControllerMappingManagerType = (
	%ControllerMappingManager
)
@onready var _interface_fonts: InterfaceFontController = %InterfaceFontController
@onready var _title_music: AudioStreamPlayer = %TitleMusic
@onready var _dusk_music: AudioStreamPlayer = %DuskMusic
@onready var _ui_pixelation: UIPixelationPresenterType = %UIPresentation
@onready var _pixelation_reset: PixelationResetOverlayType = (
	%PixelationResetOverlay
)
@onready var _world_pixelation: WorldPixelationPostprocessType = (
	%WorldPixelationPostprocess
)
@onready var _network_session: NetworkSessionType = %NetworkSession
@onready var _discovery: DiscoveryClientType = %DiscoveryClient
@onready var _world_time: WorldTimeServiceType = %WorldTimeService
@onready var _world_time_visuals: WorldTimeVisualControllerType = (
	%WorldTimeVisualController
)
@onready var _network_world_time: NetworkWorldTimeServiceType = (
	%NetworkWorldTimeService
)
@onready var _world_weather: WorldWeatherServiceType = %WorldWeatherService
@onready var _network_world_weather: NetworkWorldWeatherServiceType = (
	%NetworkWorldWeatherService
)
@onready var _player_jobs: PlayerJobServiceType = %PlayerJobService
@onready var _network_jobs: NetworkJobServiceType = %NetworkJobService
@onready var _network_world_spawns: NetworkWorldSpawnServiceType = (
	%NetworkWorldSpawnService
)
@onready var _gathering_controller: GatheringControllerType = (
	%GatheringController
)
@onready var _data_root: PlayerDataRoot = %PlayerDataRoot
@onready var _identity_backups: IdentityBackupService = %IdentityBackupService
@onready var _network_profile: NetworkProfilePreferencesType = (
	%NetworkProfilePreferences
)
@onready var _player_identity: PlayerIdentityStore = %PlayerIdentityStore
@onready var _host_identity: HostIdentityStore = %HostIdentityStore
@onready var _known_players: KnownPlayerStore = %KnownPlayerStore
@onready var _server_trust: ServerTrustStore = %ServerTrustStore
@onready var _relationships: PlayerRelationshipStore = %PlayerRelationshipStore
@onready var _host_bans: HostBanStore = %HostBanStore
@onready var _saved_servers: SavedServerStoreType = %SavedServerStore
@onready var _player_spawn_service: PlayerSpawnServiceType = (
	%PlayerSpawnService
)
@onready var _network_fishing: NetworkFishingServiceType = (
	%NetworkFishingService
)
@onready var _network_sale: NetworkSaleServiceType = %NetworkSaleService
@onready var _network_shop: NetworkShopServiceType = %NetworkShopService
@onready var _network_item_use: NetworkItemUseServiceType = (
	%NetworkItemUseService
)
@onready var _network_fish_showcase: NetworkFishShowcaseServiceType = (
	%NetworkFishShowcaseService
)
@onready var _network_surface_drawing: NetworkSurfaceDrawingServiceType = (
	%NetworkSurfaceDrawingService
)
@onready var _network_chat: NetworkChatServiceType = %NetworkChatService
@onready var _network_mail: NetworkMailServiceType = %NetworkMailService
@onready var _network_player_list: NetworkPlayerListService = %NetworkPlayerListService
@onready var _asset_reservations: PlayerAssetReservationServiceType = (
	%PlayerAssetReservationService
)
@onready var _appearance_store: PlayerAppearanceStoreType = %PlayerAppearanceStore
@onready var _network_profile_service: NetworkProfileServiceType = (
	%NetworkProfileService
)
@onready var _players_root: Node3D = $Players
@onready var _surface_drawings_root: Node3D = $SurfaceDrawings
@onready var _world_gatherables_root: Node3D = $WorldGatherables
@onready var _title_background: ColorRect = %TitleBackground
@onready var _player_menu_backdrop: ColorRect = %PlayerMenuBackdrop
@onready var _shop_backdrop: ColorRect = %ShopBackdrop

var _gameplay_started: bool = false
var _shop_interaction: FishingShopInteractionType
var _title_music_tween: Tween
var _title_music_transition_generation: int = 0
var _title_music_requested: bool = false
var _dusk_music_played_for_natural_day: bool = false
var _quit_in_progress: bool = false
var _join_requested_from_title: bool = false
var _join_requested_from_pause: bool = false
var _player_menu_backdrop_tween: Tween
var _shop_backdrop_tween: Tween
var _pending_join_endpoint: String = ""
var _server_trust_dialog: ConfirmationDialog
var _pending_trust_changed: bool = false
var _identity_notice_dialog: AcceptDialog
var _data_setup_dialog: ConfirmationDialog
var _data_setup_choose_button: Button
var _data_setup_current_button: Button
var _data_folder_dialog: FileDialog
var _data_folder_picker_generation: int = 0
var _restore_data_setup_after_picker: bool = false
var _application_initialized := false
var _performance_profile: RuntimePerformanceProfileType
var _pending_existing_root_path := ""
var _local_recovery_attempt_id: String = ""
var _dedicated_runtime: bool = false

@onready var _shoreline_ambience: ShorelineAmbience = %ShorelineAmbience
var _rain_ambience: RainAmbienceType


func _ready() -> void:
	_performance_profile = RuntimePerformanceProfileType.from_environment()
	_dedicated_runtime = _is_dedicated_server_runtime()
	if _dedicated_runtime:
		call_deferred("_start_dedicated_server")
		return
	_world_pixelation.set_light_performance_profile(
		_performance_profile.is_light()
	)
	_test_world.set_light_performance_profile(
		_performance_profile.is_light()
	)
	_configure_presentation_performance_profile(
		_performance_profile.is_light()
	)
	DisplayServer.window_set_title("NETfishing")
	_rain_ambience = RainAmbienceType.new()
	_rain_ambience.name = "RainAmbience"
	add_child(_rain_ambience)
	_rain_ambience.configure(_world_weather)
	_shoreline_ambience.configure(
		_player,
		_test_world.get_saltwater_shoreline_mesh(),
	)
	get_window().size_changed.connect(_resize_native_overlays)
	_resize_native_overlays()
	if not _settings_manager.settings_changed.is_connected(
		_apply_runtime_settings
	):
		_settings_manager.settings_changed.connect(_apply_runtime_settings)
	_settings_manager.load_settings()
	_interface_fonts.enforce_standard_font()
	if _data_root.resolve():
		_configure_portable_stores()
		_initialize_after_data_root()
		return
	_show_data_root_setup()


func _configure_presentation_performance_profile(light_profile: bool) -> void:
	var title_water_material := _title_background.material as ShaderMaterial
	if title_water_material != null:
		title_water_material.set_shader_parameter(
			"animation_enabled",
			not light_profile,
		)
	var menu_pattern_material := (
		_player_menu_backdrop.material as ShaderMaterial
	)
	if menu_pattern_material != null:
		menu_pattern_material.set_shader_parameter(
			"animation_enabled",
			not light_profile,
		)
		menu_pattern_material.set_shader_parameter(
			"display_scale",
			PLAYER_MENU_PATTERN_SCALE,
		)
		menu_pattern_material.set_shader_parameter(
			"scroll_velocity_pixels",
			(
				Vector2.ZERO
				if light_profile
				else PLAYER_MENU_PATTERN_SCROLL_VELOCITY
			),
		)
	var shop_pattern_material := _shop_backdrop.material as ShaderMaterial
	if shop_pattern_material != null:
		shop_pattern_material.set_shader_parameter(
			"animation_enabled",
			not light_profile,
		)
		shop_pattern_material.set_shader_parameter(
			"display_scale",
			SHOP_PATTERN_SCALE,
		)
		shop_pattern_material.set_shader_parameter(
			"scroll_velocity_pixels",
			(
				Vector2.ZERO
				if light_profile
				else PLAYER_MENU_PATTERN_SCROLL_VELOCITY
			),
		)


func _is_dedicated_server_runtime() -> bool:
	if OS.has_feature("dedicated_server"):
		return true
	return "--dedicated-server" in OS.get_cmdline_user_args()


func _start_dedicated_server() -> void:
	var config: DedicatedServerConfigType = DedicatedServerConfigType.from_runtime()
	if not config.is_valid():
		_fail_dedicated_server(config.error_message)
		return
	var data_path: String = config.data_directory
	var manifest_path: String = data_path.path_join(
		PlayerDataRoot.MANIFEST_FILENAME
	)
	if not FileAccess.file_exists(manifest_path):
		var created: Dictionary = _data_root.create_unbound_root(data_path)
		if not bool(created.get("ok", false)):
			_fail_dedicated_server(str(created.get(
				"message", "Could not create the server data directory."
			)))
			return
	if not _data_root.activate_process_root(data_path):
		_fail_dedicated_server(_data_root.error_message)
		return
	var identity_directory: String = data_path.path_join("server")
	if DirAccess.make_dir_recursive_absolute(identity_directory) != OK:
		_fail_dedicated_server("Could not create the server identity directory.")
		return
	_host_identity.configure("host_identity", true, identity_directory)
	if not _discovery.set_base_url_override(config.discovery_url):
		_fail_dedicated_server("The discovery URL is invalid.")
		return
	if not _network_session.configure_dedicated_operators(
		config.operator_fingerprints
	):
		_fail_dedicated_server("The server operator list is invalid.")
		return
	_configure_portable_stores()
	if not _discovery.configure_dedicated_runtime(config.server_name):
		_fail_dedicated_server("The server room name is invalid.")
		return
	_initialize_application(true)
	_player.set_local_control(false)
	_player.visible = false
	_player.collision_layer = 0
	_player.collision_mask = 0
	_player.set_physics_process(false)
	if not _network_session.start_dedicated_host(
		config.port,
		config.max_players,
		config.bind_address,
	):
		_fail_dedicated_server("Could not start the dedicated server.")
		return
	_network_session.set_session_display_name(config.server_name)
	if not _network_session.set_host_open(true):
		_fail_dedicated_server("Could not open the dedicated server.")
		return
	_player_jobs.begin_progression_session()
	if config.public_listing and not _discovery.set_discoverable(true):
		_network_session.disconnect_session("Discovery setup failed.")
		_fail_dedicated_server(_discovery.get_host_status_message())
		return
	print(
		"NETfishing dedicated server ready: %s on %s:%d (%d players, %s)"
		% [
			config.server_name,
			config.bind_address,
			config.port,
			config.max_players,
			"public" if config.public_listing else "unlisted",
		]
	)
	print(
		"Server identity: %s"
		% _network_session.get_host_identity_fingerprint()
	)


func _fail_dedicated_server(message: String) -> void:
	push_error("Dedicated server startup failed: %s" % message)
	get_tree().quit(1)


func _configure_portable_stores() -> void:
	_save_manager.configure_storage(
		_data_root.path_for(&"player_save"), _data_root
	)
	_network_profile.configure_storage(
		_data_root.path_for(&"network_profile"), _data_root
	)
	_appearance_store.configure_storage(
		_data_root.path_for(&"player_appearance"), _data_root
	)
	_saved_servers.configure_storage(
		_data_root.path_for(&"saved_servers"), _data_root
	)
	_known_players.configure_storage(
		_data_root.path_for(&"known_players"), _data_root
	)
	_relationships.configure_storage(
		_data_root.path_for(&"player_relationships"), _data_root
	)
	_server_trust.configure_storage(
		_data_root.path_for(&"server_trust"), _data_root
	)
	_host_bans.configure_storage(
		_data_root.path_for(&"host_bans"), _data_root
	)


func _initialize_after_data_root() -> void:
	_initialize_application(false)


func _initialize_application(dedicated: bool) -> void:
	if _application_initialized:
		return
	_application_initialized = true
	_player.global_transform = _test_world.get_player_spawn_transform()
	_player.velocity = Vector3.ZERO
	_player_spawn_service.setup(
		_players_root,
		_player,
		_test_world.get_player_spawn_transform()
	)
	_network_session.setup(
		_network_profile,
		_saved_servers,
		_player_spawn_service,
		_player_identity,
		_host_identity,
		_known_players,
		_server_trust,
		_host_bans,
		dedicated,
	)
	_discovery.setup(_network_session)
	if not dedicated:
		_world_time_visuals.setup(
			_world_time,
			_test_world.get_world_environment(),
			_test_world.get_sun(),
			_world_weather,
			_player,
			Callable(_player, "get_active_gameplay_camera"),
			_performance_profile.is_light(),
		)
		if not _world_time.natural_time_advanced.is_connected(
			_on_natural_time_advanced
		):
			_world_time.natural_time_advanced.connect(
				_on_natural_time_advanced
			)
	_network_world_time.setup(_network_session, _world_time)
	_network_world_weather.setup(_network_session, _world_weather)
	_player_jobs.setup(
		_player.wallet,
		_player.experience,
		_player.collection_log,
		fish_catalog,
		_world_time,
		_world_weather,
		_network_session,
	)
	_network_jobs.setup(_network_session, _player_jobs)
	_identity_backups.setup(_data_root, _player_identity, _host_identity)
	_network_profile_service.setup(
		_network_session,
		_network_profile,
		_appearance_store,
		_player_spawn_service,
	)
	_network_player_list.setup(
		_network_session,
		_relationships,
		_host_bans,
		_known_players,
		_player_spawn_service,
		_network_chat,
		_network_mail,
	)
	if not dedicated:
		_network_session.set_local_appearance_snapshot(
			_appearance_store.get_snapshot()
		)
		_network_session.join_authenticated.connect(
			_on_network_join_authenticated
		)
		_network_session.connection_error.connect(
			_on_network_connection_error
		)
		_network_session.server_trust_required.connect(
			_on_server_trust_required
		)
		_network_session.server_lost.connect(_on_network_server_lost)
	_network_session.peer_identity_observed.connect(
		_on_peer_identity_observed
	)
	_network_session.remote_recovery_requested.connect(
		_on_remote_recovery_requested
	)
	_network_session.remote_recovery_presentation_changed.connect(
		_on_remote_recovery_presentation_changed
	)


	_player.fish_sale_service.setup(
		_player.inventory,
		_player.wallet,
		_asset_reservations
	)
	_player.bag.setup(item_catalog)
	_player.hotbar.setup(_player.bag, item_catalog, _player.inventory)
	_shop_interaction = _test_world.get_fishing_shop()
	if not dedicated:
		_shop_interaction.setup_local_player(_player)
		_shop_interaction.local_player_range_changed.connect(
			_on_shop_range_changed
		)
		_game_ui.set_shop_npc_player_in_range(
			_shop_interaction.is_local_player_in_range()
		)
	_save_manager.setup(
		_player.inventory,
		_player.collection_log,
		_player.wallet,
		fish_catalog,
		_player.bag,
		_player.hotbar,
		item_catalog,
		_player.fishing_upgrades,
		_player.cooler_capacity,
		_player.art_unlocks,
		_player.experience,
		_world_time,
		_world_weather,
		_player_jobs,
	)
	_player_jobs.set_save_manager(_save_manager)
	_save_manager.set_autosave_enabled(false)
	_asset_reservations.setup(
		_player.wallet, _player.inventory, _player.bag, item_catalog
	)
	_player.inventory.set_reservation_service(_asset_reservations)
	_network_mail.setup(
		_network_session,
		_asset_reservations,
		_player.wallet,
		_player.inventory,
		_player.bag,
		_player.collection_log,
		_player.cooler_capacity,
		item_catalog,
		fish_catalog,
		_save_manager
	)
	_network_item_use.setup(
		_network_session,
		_player_spawn_service,
		item_catalog,
		_player.bag,
		_player.item_effects,
		_save_manager,
		_asset_reservations
	)
	_network_world_spawns.setup(
		_network_session,
		_player_spawn_service,
		_test_world,
		_world_gatherables_root,
		gatherable_catalog,
		fish_catalog,
		_player.inventory,
		_player.collection_log,
		_player.cooler_capacity,
		_player.experience,
		_save_manager,
		_network_item_use,
	)
	_gathering_controller.setup(
		_player,
		_player.bag,
		_player.hotbar,
		_fishing_spot,
		_network_world_spawns,
	)
	_network_world_spawns.local_capture_received.connect(
		_fishing_spot.present_external_catch
	)
	_gathering_controller.status_changed.connect(
		_fishing_spot.report_external_status
	)
	_network_fish_showcase.setup(
		_network_session,
		_player_spawn_service,
		fish_catalog,
		_player.inventory,
		_player.hotbar,
	)
	_network_surface_drawing.setup(
		_network_session,
		_player_spawn_service,
		_relationships,
		_player,
		_surface_drawings_root,
		_player.bag,
		_player.hotbar,
		_player.art_unlocks,
	)
	_network_player_list.set_surface_drawing_service(
		_network_surface_drawing
	)
	_network_chat.setup(_network_session, _world_time, _world_weather)
	_network_fishing.setup(
		_network_session,
		_player_spawn_service,
		_fishing_spot,
		_player.inventory,
		_player.bag,
		_player.collection_log,
		_player.cooler_capacity,
		_player.experience,
		_save_manager,
		item_catalog,
		fish_catalog,
		_network_item_use
	)
	var sale_buyers: Array[FishBuyerProfileType] = [
		pelican_buyer_profile,
		main_shop_buyer_profile,
	]
	_network_sale.setup(
		_network_session,
		_player_spawn_service,
		_network_fishing,
		_shop_interaction,
		_player.inventory,
		_player.wallet,
		_player.fish_sale_service,
		_save_manager,
		fish_catalog,
		sale_buyers,
		_asset_reservations
	)
	_player_jobs.bind_authoritative_services(_network_fishing, _network_sale)
	_network_shop.setup(
		_network_session,
		_player_spawn_service,
		_network_fishing,
		_shop_interaction,
		_player.wallet,
		_player.bag,
		item_catalog,
		_player.fishing_upgrades,
		_player.cooler_capacity,
		_player.art_unlocks,
		_save_manager,
		_asset_reservations
	)
	_fishing_spot.setup(
		_player,
		_player.inventory,
		_player.collection_log,
		_player.experience,
		_player.bag,
		_player.hotbar,
		item_catalog,
		_player.fishing_upgrades,
		_player.item_effects,
		_network_item_use,
		_player.cooler_capacity,
		_network_session,
		_network_fishing,
		_world_time,
		_world_weather,
	)
	if dedicated:
		return
	_game_ui.setup(
		_player,
		_player.inventory,
		_player.collection_log,
		_player.experience,
		_player.wallet,
		_player.fish_sale_service,
		pelican_buyer_profile,
		fish_catalog,
		_fishing_spot,
		_player.bag,
		_player.hotbar,
		item_catalog,
		main_shop_buyer_profile,
		_player.fishing_upgrades,
		_shop_interaction,
		_player.item_effects,
		_player.cooler_capacity,
		_network_session,
		_network_sale,
		_network_shop,
		_network_chat,
		_network_profile,
		_player_spawn_service,
		_network_mail,
		_asset_reservations,
		_network_profile_service,
		_network_player_list,
		_discovery,
		_settings_manager,
		_network_surface_drawing,
		_player.art_unlocks,
		_world_time,
		_world_weather,
		_player_jobs,
		_test_world.get_world_environment(),
		_test_world.get_sun(),
	)
	_game_ui.setup_data_and_identity(
		_data_root,
		_identity_backups,
		_player_identity,
		_host_identity,
		_network_session,
		_interface_fonts,
	)
	_game_ui.setup_controller_mapping(_controller_mapping_manager)
	_data_root.conflict_detected.connect(_on_portable_conflict)
	_data_root.status_changed.connect(_on_data_root_status)
	if (
		PortableFileGuard.has_syncthing_conflict(
			_data_root.root_path.path_join("player")
		)
		or PortableFileGuard.has_syncthing_conflict(
			_data_root.root_path.path_join("social")
		)
	):
		call_deferred(
			"_on_data_root_status",
			"Syncthing conflict copies were found. Review the data folder.",
		)
	_water_recovery.setup(
		_player,
		_fishing_spot,
		_game_ui,
		_game_ui.get_screen_fade(),
		_test_world.get_player_water_triggers(),
		_test_world.get_safe_respawn_points()
	)
	_ui_pixelation.effective_pixel_size_changed.connect(
		_on_effective_ui_pixel_size_changed
	)
	_game_ui.pixelation_settings_visibility_changed.connect(
		_pixelation_reset.set_settings_open
	)
	_game_ui.crisp_reset_focus_requested.connect(
		_pixelation_reset.focus_reset_button
	)
	_game_ui.interactive_pointer_ui_changed.connect(
		_ui_pixelation.set_interactive_ui_open
	)
	_game_ui.passive_pointer_ui_changed.connect(
		_ui_pixelation.set_passive_pointer_ui_enabled
	)
	_game_ui.player_menu_backdrop_visibility_changed.connect(
		_set_player_menu_backdrop_visible
	)
	_game_ui.shop_backdrop_visibility_changed.connect(
		_set_shop_backdrop_visible
	)
	_pixelation_reset.return_to_settings_requested.connect(
		_game_ui.focus_open_settings_back_button
	)
	_pixelation_reset.reset_requested.connect(_reset_pixelation)
	_apply_runtime_settings(_settings_manager.current_settings)
	_set_gameplay_active(false)
	var title_screen: TitleScreenType = _game_ui.get_title_screen()
	title_screen.new_game_requested.connect(_on_new_game_requested)
	title_screen.continue_game_requested.connect(_on_continue_game_requested)
	title_screen.quit_requested.connect(_on_quit_requested)
	title_screen.setup(
		_save_manager,
		_settings_manager,
		_network_session,
		_saved_servers,
		_server_trust,
		_discovery,
	)
	var pause_menu: PauseMenuType = _game_ui.get_pause_menu()
	pause_menu.setup(
		_player,
		_save_manager,
		_settings_manager,
		_fishing_spot,
		_network_session,
		_saved_servers,
		_server_trust,
		_discovery,
	)
	title_screen.join_game_requested.connect(_on_title_join_game_requested)
	pause_menu.join_game_requested.connect(_on_pause_join_game_requested)
	pause_menu.return_to_title_requested.connect(
		_on_return_to_title_requested
	)
	pause_menu.reset_progress_requested.connect(
		_on_reset_progress_requested
	)
	pause_menu.quit_requested.connect(_on_quit_requested)
	pause_menu.menu_visibility_changed.connect(
		_game_ui.set_system_menu_open
	)
	_player.hotbar.selected_assignment_changed.connect(
		_on_active_hotbar_item_changed
	)
	_player.bag.contents_changed.connect(_refresh_active_hotbar_item)
	_fishing_spot.ready_for_equipment_refresh.connect(
		_refresh_active_hotbar_item
	)
	_water_recovery.recovery_starting.connect(
		_on_water_recovery_starting
	)
	_water_recovery.recovery_finished.connect(
		_on_water_recovery_finished
	)
	_water_recovery.local_respawn_completed.connect(
		_on_local_respawn_completed
	)
	_refresh_active_hotbar_item()
	_show_title_music(true)


func _show_data_root_setup() -> void:
	if _data_setup_dialog == null:
		_data_setup_dialog = ConfirmationDialog.new()
		_data_setup_dialog.title = "NETfishing player data"
		_data_setup_dialog.ok_button_text = "Use This Folder"
		_data_setup_dialog.cancel_button_text = "Quit"
		_data_setup_dialog.confirmed.connect(_use_default_data_root)
		_data_setup_dialog.canceled.connect(get_tree().quit)
		_data_setup_choose_button = _data_setup_dialog.add_button(
			"Choose Another Folder", false, "choose"
		)
		_data_setup_current_button = _data_setup_dialog.add_button(
			"Keep Current Location", false, "current"
		)
		_data_setup_dialog.custom_action.connect(_on_data_setup_action)
		_interface_fonts.apply_utility_theme(_data_setup_dialog)
		add_child(_data_setup_dialog)
	var default_path: String = _data_root.default_visible_path()
	var legacy: bool = PortableDataMigration.legacy_files_present()
	_data_setup_dialog.dialog_text = (
		("Move your existing NETfishing data to an easy-to-find folder."
		if legacy else "Choose where NETfishing stores your player data.")
		+ "\n\n%s\n\nYou can choose a Syncthing folder."
		% (default_path if not default_path.is_empty() else "Choose a folder")
	)
	_data_setup_dialog.ok_button_text = (
		(
			"Move to Documents/NETFISHING"
			if legacy else "Use This Folder"
		)
		if not default_path.is_empty()
		else "Keep Current Location"
	)
	_data_setup_current_button.visible = not default_path.is_empty()
	if not _data_root.error_message.is_empty():
		_data_setup_dialog.dialog_text = (
			"Your NETfishing data folder is unavailable.\n\n%s"
			% _data_root.error_message
		)
	_data_setup_dialog.popup_centered(Vector2i(640, 360))
	_focus_data_setup_actions.call_deferred()


func _focus_data_setup_actions() -> void:
	if _data_setup_dialog == null or not _data_setup_dialog.visible:
		return
	var actions: Array[Button] = [
		_data_setup_dialog.get_ok_button(),
		_data_setup_choose_button,
	]
	if _data_setup_current_button.visible:
		actions.append(_data_setup_current_button)
	actions.append(_data_setup_dialog.get_cancel_button())
	for index: int in actions.size():
		var action: Button = actions[index]
		var previous: Button = actions[posmod(index - 1, actions.size())]
		var next: Button = actions[(index + 1) % actions.size()]
		action.focus_mode = Control.FOCUS_ALL
		action.focus_neighbor_left = action.get_path_to(previous)
		action.focus_neighbor_top = action.focus_neighbor_left
		action.focus_neighbor_right = action.get_path_to(next)
		action.focus_neighbor_bottom = action.focus_neighbor_right
	_data_setup_dialog.get_ok_button().grab_focus()


func _use_default_data_root() -> void:
	var path: String = _data_root.default_visible_path()
	if path.is_empty():
		_activate_selected_data_path(
			ProjectSettings.globalize_path(
				PlayerDataRoot.APP_DATA_PORTABLE_PATH
			),
			true,
		)
		return
	_activate_selected_data_path(path)


func _on_data_setup_action(action: StringName) -> void:
	if action == &"choose":
		_show_folder_picker()
	elif action == &"current":
		_activate_selected_data_path(
			ProjectSettings.globalize_path(PlayerDataRoot.APP_DATA_PORTABLE_PATH), true
		)


func _show_folder_picker() -> void:
	if _data_folder_dialog == null:
		_data_folder_dialog = FileDialog.new()
		_data_folder_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_data_folder_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_data_folder_dialog.use_native_dialog = false
		_data_folder_dialog.dir_selected.connect(_activate_selected_data_path)
		_data_folder_dialog.canceled.connect(_on_data_folder_picker_canceled)
		_interface_fonts.apply_utility_theme(_data_folder_dialog)
		add_child(_data_folder_dialog)
	if _data_folder_dialog.visible:
		return
	_data_folder_picker_generation += 1
	var generation: int = _data_folder_picker_generation
	_restore_data_setup_after_picker = (
		_data_setup_dialog != null and _data_setup_dialog.visible
	)
	if _data_setup_dialog != null:
		_data_setup_dialog.hide()
	_open_folder_picker_after_modal.call_deferred(generation)


func _open_folder_picker_after_modal(generation: int) -> void:
	await get_tree().process_frame
	if (
		generation != _data_folder_picker_generation
		or _data_folder_dialog == null
		or _data_folder_dialog.visible
	):
		return
	_data_folder_dialog.current_dir = (
		_data_root.default_visible_path().get_base_dir()
		if not _data_root.default_visible_path().is_empty()
		else OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	)
	_interface_fonts.popup_file_dialog(_data_folder_dialog)


func _on_data_folder_picker_canceled() -> void:
	_data_folder_picker_generation += 1
	var generation: int = _data_folder_picker_generation
	var should_restore_setup: bool = _restore_data_setup_after_picker
	_restore_data_setup_after_picker = false
	if _data_folder_dialog != null:
		_data_folder_dialog.hide()
	if should_restore_setup:
		_restore_data_setup_after_picker_after_modal.call_deferred(generation)


func _restore_data_setup_after_picker_after_modal(generation: int) -> void:
	await get_tree().process_frame
	if generation != _data_folder_picker_generation:
		return
	_show_data_root_setup()


func _activate_selected_data_path(path: String, app_data: bool = false) -> void:
	_restore_data_setup_after_picker = false
	var ok: bool = false
	if PortableDataMigration.legacy_files_present():
		var result: Dictionary = (
			PortableDataMigration.adopt_legacy_app_data(_data_root)
			if app_data
			else PortableDataMigration.migrate_legacy_to(_data_root, path)
		)
		ok = bool(result.get("ok", false))
		if not ok:
			if bool(result.get("requires_existing_root_decision", false)):
				_show_existing_root_choice(path)
				return
			_show_data_error(str(result.get("message", "Migration failed.")))
			return
	else:
		ok = _data_root.select_new_root(path, app_data)
	if not ok:
		_show_data_error(_data_root.error_message)
		return
	_data_setup_dialog.hide()
	_configure_portable_stores()
	_initialize_after_data_root()


func _show_existing_root_choice(path: String) -> void:
	_pending_existing_root_path = path
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Existing NETfishing data"
	dialog.ok_button_text = "Use Data Already in Selected Folder"
	dialog.cancel_button_text = "Cancel"
	dialog.dialog_text = (
		"This folder already contains NETfishing player data.\n\n"
		+ "Choose which complete data set to use. Data is never merged automatically."
	)
	dialog.add_button(
		"Replace with This Device's Data", false, "replace"
	)
	dialog.confirmed.connect(func() -> void:
		if _data_root.use_existing_root(_pending_existing_root_path):
			dialog.queue_free()
			_data_setup_dialog.hide()
			_configure_portable_stores()
			_initialize_after_data_root()
		else:
			_show_data_error(_data_root.error_message)
	)
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action != &"replace":
			return
		var result: Dictionary = PortableDataMigration.replace_existing_with_legacy(
			_data_root, _pending_existing_root_path
		)
		if bool(result.get("ok", false)):
			dialog.queue_free()
			_data_setup_dialog.hide()
			_configure_portable_stores()
			_initialize_after_data_root()
		else:
			_show_data_error(str(result.get("message", "Migration failed.")))
	)
	_interface_fonts.apply_utility_theme(dialog)
	add_child(dialog)
	dialog.popup_centered(Vector2i(680, 360))


func _show_data_error(message: String) -> void:
	if _data_setup_dialog != null:
		_data_setup_dialog.dialog_text = message
		_data_setup_dialog.popup_centered(Vector2i(640, 300))


func _on_portable_conflict(message: String, _path: String) -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	_interface_fonts.apply_utility_theme(dialog)
	dialog.title = "Player data conflict"
	dialog.dialog_text = (
		message
		+ "\n\nDo not play the same profile on two devices at the same time."
	)
	dialog.add_button("Open Data Folder", false, "open")
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"open":
			_data_root.open_folder()
	)
	dialog.confirmed.connect(dialog.queue_free)
	_game_ui.add_child(dialog)
	dialog.popup_centered(Vector2i(560, 300))


func _on_data_root_status(message: String) -> void:
	if "Syncthing conflict" not in message:
		return
	var dialog: AcceptDialog = AcceptDialog.new()
	_interface_fonts.apply_utility_theme(dialog)
	dialog.title = "Synced data needs review"
	dialog.dialog_text = message
	dialog.add_button("Open Data Folder", false, "open")
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"open":
			_data_root.open_folder()
	)
	dialog.confirmed.connect(dialog.queue_free)
	_game_ui.add_child(dialog)
	dialog.popup_centered(Vector2i(560, 260))


func _on_server_trust_required(
	endpoint: String,
	expected_fingerprint: String,
	received_fingerprint: String,
	is_changed: bool,
) -> void:
	if _server_trust_dialog == null:
		_server_trust_dialog = ConfirmationDialog.new()
		_server_trust_dialog.title = "Server identity"
		_server_trust_dialog.ok_button_text = "Trust & Connect"
		_server_trust_dialog.cancel_button_text = "Cancel"
		_server_trust_dialog.confirmed.connect(_confirm_server_trust)
		_server_trust_dialog.canceled.connect(
			_network_session.resolve_server_trust.bind(false)
		)
		_game_ui.add_child(_server_trust_dialog)
	_pending_trust_changed = is_changed
	if is_changed:
		_server_trust_dialog.dialog_text = (
			"Server identity changed.\n\n"
			+ "This may mean the server was reinstalled, moved, or is being "
			+ "impersonated.\n\nExpected:\n%s\n\nReceived:\n%s"
			% [
				NetworkIdentityCrypto.format_fingerprint(expected_fingerprint),
				NetworkIdentityCrypto.format_fingerprint(received_fingerprint),
			]
		)
		_server_trust_dialog.ok_button_text = "Trust New Identity"
	else:
		_server_trust_dialog.dialog_text = (
			"First time connecting to this server.\n\n%s\n\nHost identity:\n%s"
			% [
				endpoint,
				NetworkIdentityCrypto.format_fingerprint(received_fingerprint),
			]
		)
		_server_trust_dialog.ok_button_text = "Trust & Connect"
	_server_trust_dialog.popup_centered(Vector2i(560, 360))


func _confirm_server_trust() -> void:
	if _pending_trust_changed:
		_pending_trust_changed = false
		_server_trust_dialog.dialog_text = (
			"Replace the saved server identity pin?\n\n"
			+ "Only continue if you expected this server identity to change."
		)
		_server_trust_dialog.ok_button_text = "Replace Pin"
		_server_trust_dialog.popup_centered(Vector2i(520, 260))
		return
	if _server_trust_dialog != null:
		_server_trust_dialog.hide()
	_network_session.resolve_server_trust(true)


func _on_peer_identity_observed(_peer_id: int, status: String) -> void:
	if status != "New identity using a familiar name":
		return
	if _identity_notice_dialog == null:
		_identity_notice_dialog = AcceptDialog.new()
		_identity_notice_dialog.title = "Player identity"
		_game_ui.add_child(_identity_notice_dialog)
	_identity_notice_dialog.dialog_text = (
		"New identity using a familiar name.\n\n"
		+ "This may be a different player using the same display name."
	)
	_identity_notice_dialog.popup_centered(Vector2i(480, 240))


func _input(event: InputEvent) -> void:
	if _handle_data_root_controller_input(event):
		get_viewport().set_input_as_handled()
		return
	if _game_ui.is_controller_mapping_capturing():
		return
	if (
		not (
			event.is_action_pressed("ui_cancel")
			or event.is_action_pressed("open_system_menu")
		)
		or (event is InputEventKey and event.echo)
	):
		return
	var pause_open_requested: bool = _is_pause_open_request(event)
	var title_screen: TitleScreenType = _game_ui.get_title_screen()
	if title_screen.visible or not _gameplay_started:
		return
	var pause_menu: PauseMenuType = _game_ui.get_pause_menu()
	var fishing_shop: FishingShopType = _game_ui.get_fishing_shop()
	if fishing_shop.consume_escape():
		get_viewport().set_input_as_handled()
		return
	if pause_menu.handle_escape():
		get_viewport().set_input_as_handled()
		return
	if _game_ui.consume_player_menu_escape():
		get_viewport().set_input_as_handled()
		return
	if _fishing_spot.handle_escape_action():
		get_viewport().set_input_as_handled()
		return
	if (
		pause_open_requested
		and not _water_recovery.is_recovery_active()
		and _fishing_spot.can_open_system_menu()
	):
		_game_ui.close_player_menu_for_game_menu()
		pause_menu.open_menu()
		get_viewport().set_input_as_handled()


func _handle_data_root_controller_input(event: InputEvent) -> bool:
	var button_event := event as InputEventJoypadButton
	if button_event == null or not button_event.pressed:
		return false
	var setup_visible: bool = (
		_data_setup_dialog != null and _data_setup_dialog.visible
	)
	var picker_visible: bool = (
		_data_folder_dialog != null and _data_folder_dialog.visible
	)
	if not setup_visible and not picker_visible:
		return false
	var use_mapping: bool = _controller_mapping_manager != null
	var accept_pressed: bool = (
		_controller_mapping_manager.event_matches_role(
			event,
			ControllerMappingManagerType.ROLE_A,
		)
		if use_mapping
		else (
			button_event.button_index == JOY_BUTTON_A
			or event.is_action_pressed("ui_accept")
		)
	)
	var cancel_pressed: bool = (
		_controller_mapping_manager.event_matches_role(
			event,
			ControllerMappingManagerType.ROLE_B,
		)
		if use_mapping
		else (
			button_event.button_index == JOY_BUTTON_B
			or event.is_action_pressed("ui_cancel")
		)
	)
	if cancel_pressed:
		if picker_visible:
			_on_data_folder_picker_canceled()
		else:
			_data_setup_dialog.get_cancel_button().pressed.emit()
		return true
	if not accept_pressed:
		return false
	var focused: Control = (
		_data_folder_dialog.gui_get_focus_owner()
		if picker_visible
		else _data_setup_dialog.gui_get_focus_owner()
	)
	var focused_button := focused as BaseButton
	if focused_button != null and not focused_button.disabled:
		focused_button.pressed.emit()
		return true
	if setup_visible:
		_data_setup_dialog.get_ok_button().pressed.emit()
		return true
	return false


func _is_pause_open_request(event: InputEvent) -> bool:
	return (
		event.is_action_pressed("open_system_menu")
		or event is InputEventKey
	)


func _unhandled_input(event: InputEvent) -> void:
	if (
		not _gameplay_started
		or not event.is_action_pressed("interact")
		or (event is InputEventKey and event.echo)
	):
		return
	if (
		_shop_interaction != null
		and _shop_interaction.is_local_player_in_range()
		and _fishing_spot.can_open_fishing_shop()
		and _game_ui.get_fishing_shop().open_shop()
	):
		_game_ui.set_shop_prompt_visible(false)
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton and _player != null:
		_player.hotbar.clear_slot(_player.hotbar.get_selected_slot())
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _dedicated_runtime:
		return
	var show_shop_prompt := _can_show_shop_prompt()
	var shop_prompt_anchor := (
		_shop_interaction.get_prompt_anchor_position()
		if _shop_interaction != null
		else Vector3.ZERO
	)
	_game_ui.set_shop_prompt_visible(
		show_shop_prompt,
		shop_prompt_anchor,
	)


func _apply_runtime_settings(settings: PlayerSettingsType) -> void:
	if settings == null:
		return
	var requested_window_mode: DisplayServer.WindowMode = (
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if settings.fullscreen_enabled
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	if DisplayServer.window_get_mode() != requested_window_mode:
		DisplayServer.window_set_mode(requested_window_mode)
	_apply_world_pixelation(settings.world_pixel_size)
	_ui_pixelation.set_pixel_size(settings.ui_pixel_size)
	_ui_pixelation.set_on_screen_keyboard_enabled(
		settings.on_screen_keyboard_enabled
	)
	_game_ui.get_title_screen().set_world_pixelation(
		settings.world_pixel_size
	)
	_player.apply_camera_settings(
		settings.mouse_camera_sensitivity,
		settings.controller_camera_sensitivity,
		settings.invert_camera_y
	)
	_fishing_spot.configure_accessibility_auto_click(
		settings.auto_click_enabled,
		settings.auto_click_interval
	)
	_game_ui.set_edge_docks(
		settings.chat_dock_right,
		settings.paint_dock_right,
		settings.chat_mobile_mode,
	)


func _apply_world_pixelation(pixel_size: int) -> void:
	var root_viewport: Viewport = get_viewport()
	root_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
	root_viewport.scaling_3d_scale = (
		_performance_profile.get_world_render_scale()
	)
	root_viewport.msaa_3d = Viewport.MSAA_DISABLED
	root_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	root_viewport.use_taa = false
	_world_pixelation.set_pixel_size(pixel_size)


func _on_effective_ui_pixel_size_changed(
	_requested_pixel_size: int,
	effective_pixel_size: int,
) -> void:
	_game_ui.set_effective_ui_pixel_size(effective_pixel_size)


func _reset_pixelation() -> void:
	if _settings_manager.apply_pixelation(
		PlayerSettingsType.DEFAULT_WORLD_PIXEL_SIZE,
		PlayerSettingsType.DEFAULT_UI_PIXEL_SIZE
	):
		_game_ui.refresh_open_settings_panel()


func _set_gameplay_active(active: bool) -> void:
	var was_gameplay_started: bool = _gameplay_started
	_gameplay_started = active
	_shoreline_ambience.set_active(active)
	_rain_ambience.set_active(active)
	if active and not was_gameplay_started:
		var current_hour: float = _world_time.get_time_hours()
		_dusk_music_played_for_natural_day = (
			current_hour >= WorldTimeServiceType.DUSK_START_HOUR
			or current_hour < WorldTimeServiceType.DAWN_START_HOUR
		)
	elif not active:
		_dusk_music.stop()
	_title_background.visible = not active
	_world_pixelation.set_gameplay_active(active)
	_ui_pixelation.set_gameplay_active(active)
	if not active:
		_player.item_effects.reset_all()
	_player.set_movement_enabled(active)
	_player.set_camera_input_enabled(active)
	_player.set_camera_active(active)
	_fishing_spot.set_gameplay_input_enabled(active)
	_gathering_controller.set_gameplay_input_enabled(active)
	_water_recovery.set_recovery_enabled(active)
	_game_ui.set_gameplay_ui_enabled(active)
	_save_manager.set_autosave_enabled(active)
	if active:
		_player_jobs.begin_progression_session()
		_refresh_active_hotbar_item()
	else:
		_player_jobs.end_progression_session()
		_set_player_menu_backdrop_visible(false)
		_set_shop_backdrop_visible(false)


func _on_natural_time_advanced(advanced_hours: float) -> void:
	if not _gameplay_started or advanced_hours <= 0.0:
		return
	var current_hour: float = _world_time.get_time_hours()
	var previous_hour: float = fposmod(
		current_hour - advanced_hours,
		WorldTimeServiceType.HOURS_PER_DAY,
	)
	if _natural_interval_crosses_hour(
		previous_hour,
		advanced_hours,
		WorldTimeServiceType.DAWN_START_HOUR,
	):
		_dusk_music_played_for_natural_day = false
	if (
		not _dusk_music_played_for_natural_day
		and _natural_interval_crosses_hour(
			previous_hour,
			advanced_hours,
			WorldTimeServiceType.DUSK_START_HOUR,
		)
	):
		_dusk_music_played_for_natural_day = true
		_dusk_music.play(0.0)


static func _natural_interval_crosses_hour(
	previous_hour: float,
	advanced_hours: float,
	target_hour: float,
) -> bool:
	if advanced_hours >= WorldTimeServiceType.HOURS_PER_DAY:
		return true
	var distance_to_target: float = fposmod(
		target_hour - previous_hour,
		WorldTimeServiceType.HOURS_PER_DAY,
	)
	return (
		distance_to_target > 0.0
		and distance_to_target
		<= advanced_hours + TIME_CROSSING_EPSILON_HOURS
	)


func _set_player_menu_backdrop_visible(requested_visible: bool) -> void:
	if _player_menu_backdrop_tween != null:
		_player_menu_backdrop_tween.kill()
		_player_menu_backdrop_tween = null
	var should_show: bool = requested_visible and _gameplay_started
	if should_show:
		var was_visible: bool = _player_menu_backdrop.visible
		_player_menu_backdrop.visible = true
		if not was_visible:
			_player_menu_backdrop.modulate.a = 0.0
		_player_menu_backdrop_tween = create_tween()
		_player_menu_backdrop_tween.tween_property(
			_player_menu_backdrop,
			"modulate:a",
			1.0,
			UIMotion.PLAYER_MENU_ENTER_DURATION,
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return
	if not _player_menu_backdrop.visible:
		return
	_player_menu_backdrop_tween = create_tween()
	_player_menu_backdrop_tween.tween_property(
		_player_menu_backdrop,
		"modulate:a",
		0.0,
		UIMotion.PLAYER_MENU_EXIT_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_player_menu_backdrop_tween.finished.connect(
		func() -> void:
			_player_menu_backdrop.visible = false
			_player_menu_backdrop.modulate.a = 1.0
			_player_menu_backdrop_tween = null
	)


func _set_shop_backdrop_visible(requested_visible: bool) -> void:
	if _shop_backdrop_tween != null:
		_shop_backdrop_tween.kill()
		_shop_backdrop_tween = null
	var should_show: bool = requested_visible and _gameplay_started
	if should_show:
		var was_visible: bool = _shop_backdrop.visible
		_shop_backdrop.visible = true
		if not was_visible:
			_shop_backdrop.modulate.a = 0.0
		_shop_backdrop_tween = create_tween()
		_shop_backdrop_tween.tween_property(
			_shop_backdrop,
			"modulate:a",
			1.0,
			UIMotion.PLAYER_MENU_ENTER_DURATION,
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return
	if not _shop_backdrop.visible:
		return
	_shop_backdrop_tween = create_tween()
	_shop_backdrop_tween.tween_property(
		_shop_backdrop,
		"modulate:a",
		0.0,
		UIMotion.PLAYER_MENU_EXIT_DURATION,
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shop_backdrop_tween.finished.connect(
		func() -> void:
			_shop_backdrop.visible = false
			_shop_backdrop.modulate.a = 1.0
			_shop_backdrop_tween = null
	)


func _resize_native_overlays() -> void:
	if not is_node_ready():
		return
	_player_menu_backdrop.position = Vector2.ZERO
	_player_menu_backdrop.size = Vector2(get_window().size)
	_shop_backdrop.position = Vector2.ZERO
	_shop_backdrop.size = Vector2(get_window().size)


func _on_new_game_requested() -> void:
	if _gameplay_started or _quit_in_progress:
		return
	if not _prepare_private_host():
		return
	if (
		not _save_manager.delete_progression_save()
		or not _save_manager.initialize_new_game()
	):
		_network_session.disconnect_session("New Game setup failed.")
		_game_ui.get_title_screen().report_network_error(
			"Could not initialize local progression. Existing data was preserved where possible."
		)
		return
	_enter_gameplay()


func _on_continue_game_requested() -> void:
	if _gameplay_started or _quit_in_progress:
		return
	if not _prepare_private_host():
		return
	if not _save_manager.load_player_data():
		_network_session.disconnect_session("Continue failed.")
		_game_ui.get_title_screen().report_network_error(
			"Failed to load save. The original was preserved."
		)
		return
	_enter_gameplay()


func _prepare_private_host() -> bool:
	_join_requested_from_title = false
	_join_requested_from_pause = false
	if _network_session.state in [
		NetworkSessionType.State.CONNECTION_FAILED,
		NetworkSessionType.State.SERVER_LOST,
	]:
		_network_session.reset_failure()
	if not _network_session.start_private_host(
		NetworkSessionType.DEFAULT_PORT,
		NetworkSessionType.DEFAULT_PRIVATE_HOST_PORT_ATTEMPTS,
	):
		_game_ui.get_title_screen().report_network_error(
			"Could not start the private multiplayer session."
		)
		return false
	return true


func _enter_gameplay() -> void:
	_fade_out_title_music()
	_game_ui.get_title_screen().hide()
	_set_gameplay_active(true)


func _on_return_to_title_requested() -> void:
	if _quit_in_progress:
		return
	var pause_menu: PauseMenuType = _game_ui.get_pause_menu()
	if not _save_manager.save_world_time_checkpoint():
		pause_menu.report_network_error(
			"Could not save progression before returning to title."
		)
		return
	pause_menu.close_for_title_transition()
	_network_session.disconnect_session("Returned to title.")
	_set_gameplay_active(false)
	_game_ui.get_title_screen().reopen()
	_show_title_music(true)


func _on_title_join_game_requested(endpoint: String) -> void:
	if _quit_in_progress or _gameplay_started:
		return
	if _network_session.state != NetworkSessionType.State.INACTIVE:
		_network_session.disconnect_session("Preparing direct connection.")
	_join_requested_from_title = true
	_join_requested_from_pause = false
	_pending_join_endpoint = endpoint
	if not _network_session.join_direct(endpoint):
		_join_requested_from_title = false


func _on_pause_join_game_requested(endpoint: String) -> void:
	if _quit_in_progress or not _gameplay_started:
		return
	if not _save_manager.save_world_time_checkpoint():
		_game_ui.get_pause_menu().report_network_error(
			"Could not save progression before leaving this session."
		)
		return
	_join_requested_from_pause = true
	_join_requested_from_title = false
	_pending_join_endpoint = endpoint
	_game_ui.get_pause_menu().close_for_title_transition()
	var preserved_public_join: bool = (
		_discovery.preserve_public_join_for_session_switch()
	)
	_network_session.disconnect_session("Connecting to another game.")
	if not _network_session.join_direct(endpoint):
		if preserved_public_join:
			_discovery.cancel_pending_public_join()
		_handle_failed_session_switch(
			"Could not begin the direct connection."
		)


func _on_network_join_authenticated() -> void:
	var connected_endpoint: ConnectionEndpoint = (
		_network_session.get_current_endpoint()
	)
	var server_metadata: Dictionary = (
		_network_session.get_last_server_metadata()
	)
	if connected_endpoint != null:
		_saved_servers.record_successful_connection(
			connected_endpoint,
			int(server_metadata.get("max_players", 0)),
			str(server_metadata.get("server_display_name", "")),
			int(server_metadata.get("protocol_version", 0)),
			int(server_metadata.get("player_count", 0)),
		)
	if _join_requested_from_title:
		var inspection = _save_manager.inspect_save()
		var progression_ready: bool = (
			_save_manager.load_player_data()
			if inspection.can_continue()
			else _save_manager.initialize_new_game()
		)
		if not progression_ready:
			_network_session.disconnect_session(
				"Local progression could not be prepared."
			)
			_game_ui.get_title_screen().report_network_error(
				"Your local progression could not be prepared."
			)
			_join_requested_from_title = false
			return
		_fade_out_title_music()
		_game_ui.get_title_screen().hide()
		_set_gameplay_active(true)
	elif _join_requested_from_pause:
		_set_gameplay_active(true)
	_join_requested_from_title = false
	_join_requested_from_pause = false
	_pending_join_endpoint = ""


func _on_network_connection_error(message: String) -> void:
	var failed_endpoint: ConnectionEndpoint = (
		_network_session.get_current_endpoint()
	)
	if failed_endpoint != null:
		_saved_servers.record_connection_failure(
			failed_endpoint,
			_connection_result_code(message),
		)
	if _join_requested_from_title:
		_game_ui.get_title_screen().report_network_error(message)
	elif _join_requested_from_pause:
		_handle_failed_session_switch(message)


func _connection_result_code(message: String) -> String:
	var lowered: String = message.to_lower()
	if lowered.contains("protocol"):
		return "PROTOCOL_MISMATCH"
	if lowered.contains("full"):
		return "SERVER_FULL"
	if lowered.contains("cancel"):
		return "CANCELLED"
	if lowered.contains("timed out"):
		return "TIMEOUT"
	return "UNAVAILABLE"


func _handle_failed_session_switch(message: String) -> void:
	_join_requested_from_pause = false
	_set_gameplay_active(false)
	var title_screen: TitleScreenType = _game_ui.get_title_screen()
	title_screen.reopen()
	title_screen.open_join_game_page(_pending_join_endpoint)
	title_screen.report_network_error(message)
	_show_title_music(true)


func _on_network_server_lost(message: String) -> void:
	if not _gameplay_started:
		return
	_join_requested_from_title = false
	_join_requested_from_pause = false
	_pending_join_endpoint = ""
	_set_gameplay_active(false)
	var title_screen: TitleScreenType = _game_ui.get_title_screen()
	title_screen.reopen_to_menu()
	title_screen.report_network_error(message)
	_show_title_music(true)


func _on_local_respawn_completed(entry_position: Vector3) -> void:
	if _network_session.is_host():
		_network_session.publish_authoritative_teleport(
			_player.get_network_peer_id()
		)
	elif _network_session.is_joined_client():
		_network_session.request_safe_respawn(entry_position)


func _on_remote_recovery_requested(
	peer_id: int,
	entry_position: Vector3,
) -> void:
	if not _network_session.is_host():
		return
	var avatar: PlayerType = _player_spawn_service.get_avatar(peer_id)
	if avatar == null:
		return
	_network_fishing.cancel_peer_attempt(
		peer_id,
		"Fishing attempt ended."
	)
	var target_position: Vector3 = _test_world.get_player_spawn_transform().origin
	var nearest_distance: float = INF
	for point: SafeRespawnPoint in _test_world.get_safe_respawn_points():
		if point == null or not point.enabled:
			continue
		var distance: float = point.get_horizontal_distance_squared(
			entry_position
		)
		if distance < nearest_distance:
			nearest_distance = distance
			target_position = point.global_position
	target_position.y += _water_recovery.respawn_height_offset
	avatar.global_position = target_position
	avatar.velocity = Vector3.ZERO
	_network_session.publish_authoritative_teleport(peer_id)


func _on_reset_progress_requested() -> void:
	if _quit_in_progress:
		return
	var pause_menu: PauseMenuType = _game_ui.get_pause_menu()
	if not _save_manager.delete_progression_save():
		pause_menu.report_reset_failure()
		return
	if not _save_manager.initialize_new_game():
		pause_menu.report_reset_failure()
		return
	pause_menu.close_for_title_transition()
	_set_gameplay_active(false)
	_game_ui.get_title_screen().reopen()
	_show_title_music(true)


func _on_water_recovery_starting() -> void:
	_local_recovery_attempt_id = (
		"recovery:%s"
		% Crypto.new().generate_random_bytes(16).hex_encode()
	)
	_network_session.request_recovery_presentation(
		true, _local_recovery_attempt_id
	)
	_game_ui.close_player_menu_for_water_recovery()
	_game_ui.get_pause_menu().close_for_water_recovery()
	_game_ui.get_fishing_shop().close_for_water_recovery()


func _on_water_recovery_finished() -> void:
	if _local_recovery_attempt_id.is_empty():
		return
	_network_session.request_recovery_presentation(
		false, _local_recovery_attempt_id
	)
	_local_recovery_attempt_id = ""


func _on_remote_recovery_presentation_changed(
	peer_id: int,
	active: bool,
	_attempt_id: String,
) -> void:
	var avatar: PlayerType = _player_spawn_service.get_avatar(peer_id)
	if avatar == null or avatar == _player:
		return
	avatar.set_water_recovery_active(active)
	avatar.set_remote_recovery_presentation(active)


func _on_active_hotbar_item_changed(
	_slot_index: int,
	kind: int,
	identity: StringName,
) -> void:
	if _fishing_spot.state != FishingSpotType.FishingState.READY:
		return
	var item_id: StringName = (
		identity
		if kind == PlayerHotbarType.AssignmentKind.ITEM
		else StringName()
	)
	var item = item_catalog.get_item_by_id(item_id)
	var active_is_rod: bool = (
		item != null
		and item.is_available()
		and item.category == ItemDataType.Category.ROD
		and _player.bag.owns_item(item_id)
	)
	var active_is_art_kit: bool = (
		item_id == ArtShopStockType.ART_KIT_ITEM_ID
		and item != null
		and item.is_available()
		and _player.bag.owns_item(item_id)
	)
	var active_is_catching_net: bool = (
		item_id == FishingShopStockType.CRAB_NET_ID
		and item != null
		and item.is_available()
		and _player.bag.owns_item(item_id)
	)
	_player.set_active_fishing_rod(
		item as FishingRodDataType if active_is_rod else null,
		true,
	)
	_player.set_active_art_kit(
		item.icon if item != null else null,
		active_is_art_kit,
	)
	_player.set_active_catching_net(active_is_catching_net)
	_game_ui.set_surface_drawing_hotbar_selected(active_is_art_kit)
	_network_item_use.submit_local_equipped(item_id, active_is_rod or (
		item != null and _player.bag.owns_item(item_id)
	))
	_fishing_spot.refresh_active_item_status()


func _refresh_active_hotbar_item() -> void:
	var kind: int = (
		_player.hotbar.get_selected_assignment_kind()
	)
	var identity: StringName = StringName()
	if kind == PlayerHotbarType.AssignmentKind.ITEM:
		identity = _player.hotbar.get_selected_item_id()
	elif kind == PlayerHotbarType.AssignmentKind.FISH:
		identity = _player.hotbar.get_selected_fish_catch_id()
	_on_active_hotbar_item_changed(
		_player.hotbar.get_selected_slot(),
		kind,
		identity,
	)


func _on_quit_requested() -> void:
	if _quit_in_progress:
		return
	_quit_in_progress = true
	_settings_manager.save_if_dirty()
	if _gameplay_started:
		_save_manager.save_world_time_checkpoint()
	_network_session.disconnect_session("Application closing.")
	_title_music_requested = false
	_replace_title_music_transition()
	_finish_quit()


func _show_title_music(restart_from_beginning: bool = false) -> void:
	_title_music_requested = true
	_replace_title_music_transition()
	if restart_from_beginning:
		_title_music.stop()
	_title_music.volume_db = title_music_volume_db
	if restart_from_beginning or not _title_music.playing:
		_title_music.play(0.0)


func _fade_out_title_music(on_complete: Callable = Callable()) -> void:
	_title_music_requested = false
	var generation: int = _replace_title_music_transition()
	if not _title_music.playing:
		_title_music.volume_db = title_music_volume_db
		if on_complete.is_valid():
			on_complete.call()
		return
	if title_music_fade_out_seconds <= 0.0:
		_complete_title_music_fade_out(generation, on_complete)
		return
	_title_music_tween = create_tween()
	_title_music_tween.set_trans(Tween.TRANS_CUBIC)
	_title_music_tween.set_ease(Tween.EASE_IN)
	_title_music_tween.tween_property(
		_title_music,
		"volume_db",
		TITLE_MUSIC_SILENCE_DB,
		title_music_fade_out_seconds
	)
	_title_music_tween.finished.connect(
		_complete_title_music_fade_out.bind(generation, on_complete),
		CONNECT_ONE_SHOT
	)


func _replace_title_music_transition() -> int:
	_title_music_transition_generation += 1
	if _title_music_tween != null:
		_title_music_tween.kill()
		_title_music_tween = null
	return _title_music_transition_generation


func _complete_title_music_fade_out(
	generation: int,
	on_complete: Callable,
) -> void:
	if (
		generation != _title_music_transition_generation
		or _title_music_requested
	):
		return
	_title_music_tween = null
	_title_music.stop()
	_title_music.volume_db = title_music_volume_db
	if on_complete.is_valid():
		on_complete.call()


func _finish_quit() -> void:
	_title_music.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _exit_tree() -> void:
	if _dedicated_runtime and _network_session != null:
		_network_session.disconnect_session("Dedicated server stopping.")
	if _title_music_tween != null:
		_title_music_tween.kill()
		_title_music_tween = null
	if is_instance_valid(_title_music):
		_title_music.stop()
		_title_music.stream = null
	if is_instance_valid(_dusk_music):
		_dusk_music.stop()
		_dusk_music.stream = null


func _on_shop_range_changed(in_range: bool) -> void:
	_game_ui.set_shop_npc_player_in_range(in_range)
	if not in_range:
		_game_ui.get_fishing_shop().close_for_range_exit()
	_game_ui.set_shop_prompt_visible(_can_show_shop_prompt())


func _can_show_shop_prompt() -> bool:
	return (
		_gameplay_started
		and _shop_interaction != null
		and _shop_interaction.is_local_player_in_range()
		and not _game_ui.get_fishing_shop().visible
		and not _water_recovery.is_recovery_active()
		and _fishing_spot.can_open_fishing_shop()
	)
