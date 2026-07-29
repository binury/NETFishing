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
const TitleScreenType = preload("res://ui/title_screen.gd")
const PauseMenuType = preload("res://ui/pause_menu.gd")
const ItemCatalogType = preload("res://items/item_catalog.gd")
const ItemDataType = preload("res://items/item_data.gd")
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
const NetworkSessionType = preload("res://network/network_session.gd")
const NetworkProfilePreferencesType = preload(
	"res://network/network_profile_preferences.gd"
)
const SavedServerStoreType = preload(
	"res://network/saved_server_store.gd"
)
const PlayerSpawnServiceType = preload(
	"res://network/player_spawn_service.gd"
)

const TITLE_MUSIC_SILENCE_DB: float = -80.0

@export var fish_catalog: FishPoolType
@export var pelican_buyer_profile: FishBuyerProfileType
@export var main_shop_buyer_profile: FishBuyerProfileType
@export var item_catalog: ItemCatalogType
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
@onready var _title_music: AudioStreamPlayer = %TitleMusic
@onready var _ui_pixelation: UIPixelationPresenterType = %UIPresentation
@onready var _pixelation_reset: PixelationResetOverlayType = (
	%PixelationResetOverlay
)
@onready var _world_pixelation: WorldPixelationPostprocessType = (
	%WorldPixelationPostprocess
)
@onready var _network_session: NetworkSessionType = %NetworkSession
@onready var _network_profile: NetworkProfilePreferencesType = (
	%NetworkProfilePreferences
)
@onready var _saved_servers: SavedServerStoreType = %SavedServerStore
@onready var _player_spawn_service: PlayerSpawnServiceType = (
	%PlayerSpawnService
)
@onready var _players_root: Node3D = $Players

var _gameplay_started: bool = false
var _shop_interaction: FishingShopInteractionType
var _title_music_tween: Tween
var _title_music_transition_generation: int = 0
var _title_music_requested: bool = false
var _quit_in_progress: bool = false
var _join_requested_from_title: bool = false
var _join_requested_from_pause: bool = false
var _pending_join_endpoint: String = ""


func _ready() -> void:
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
		_player_spawn_service
	)
	_network_session.join_authenticated.connect(
		_on_network_join_authenticated
	)
	_network_session.connection_error.connect(
		_on_network_connection_error
	)
	_network_session.server_lost.connect(_on_network_server_lost)
	_network_session.remote_recovery_requested.connect(
		_on_remote_recovery_requested
	)
	_player.fish_sale_service.setup(
		_player.inventory,
		_player.wallet
	)
	_player.bag.setup(item_catalog)
	_player.hotbar.setup(_player.bag, item_catalog)
	_shop_interaction = _test_world.get_fishing_shop()
	_shop_interaction.setup_local_player(_player)
	_shop_interaction.local_player_range_changed.connect(
		_on_shop_range_changed
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
		_player.cooler_capacity
	)
	_save_manager.set_autosave_enabled(false)
	_fishing_spot.setup(
		_player,
		_player.inventory,
		_player.collection_log,
		_player.bag,
		_player.hotbar,
		item_catalog,
		_player.fishing_upgrades,
		_player.item_effects,
		_player.cooler_capacity,
		_network_session
	)
	_game_ui.setup(
		_player,
		_player.inventory,
		_player.collection_log,
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
		_network_session
	)
	_water_recovery.setup(
		_player,
		_fishing_spot,
		_game_ui,
		_game_ui.get_screen_fade(),
		_test_world.get_player_water_triggers(),
		_test_world.get_safe_respawn_points()
	)
	if not _settings_manager.settings_changed.is_connected(
		_apply_runtime_settings
	):
		_settings_manager.settings_changed.connect(_apply_runtime_settings)
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
	_pixelation_reset.return_to_settings_requested.connect(
		_game_ui.focus_open_settings_back_button
	)
	_pixelation_reset.reset_requested.connect(_reset_pixelation)
	_settings_manager.load_settings()
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
		_saved_servers
	)
	var pause_menu: PauseMenuType = _game_ui.get_pause_menu()
	pause_menu.setup(
		_player,
		_save_manager,
		_settings_manager,
		_fishing_spot,
		_network_session,
		_saved_servers
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
	_player.hotbar.selected_slot_changed.connect(
		_on_active_hotbar_item_changed
	)
	_fishing_spot.ready_for_equipment_refresh.connect(
		_refresh_active_hotbar_item
	)
	_water_recovery.recovery_starting.connect(
		_on_water_recovery_starting
	)
	_water_recovery.local_respawn_completed.connect(
		_on_local_respawn_completed
	)
	_on_active_hotbar_item_changed(
		_player.hotbar.get_selected_slot(),
		_player.hotbar.get_selected_item_id()
	)
	_show_title_music(true)


func _input(event: InputEvent) -> void:
	if (
		not event.is_action_pressed("ui_cancel")
		or (event is InputEventKey and event.echo)
	):
		return
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
		not _water_recovery.is_recovery_active()
		and _fishing_spot.can_open_system_menu()
	):
		_game_ui.close_player_menu_for_game_menu()
		pause_menu.open_menu()
		get_viewport().set_input_as_handled()


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


func _process(_delta: float) -> void:
	_game_ui.set_shop_prompt_visible(_can_show_shop_prompt())


func _apply_runtime_settings(settings: PlayerSettingsType) -> void:
	if settings == null:
		return
	_apply_world_pixelation(settings.world_pixel_size)
	_ui_pixelation.set_pixel_size(settings.ui_pixel_size)
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


func _apply_world_pixelation(pixel_size: int) -> void:
	var root_viewport: Viewport = get_viewport()
	root_viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_NEAREST
	root_viewport.scaling_3d_scale = 1.0
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
	_gameplay_started = active
	_world_pixelation.set_gameplay_active(active)
	_ui_pixelation.set_gameplay_active(active)
	if not active:
		_player.item_effects.reset_all()
	_player.set_movement_enabled(active)
	_player.set_camera_input_enabled(active)
	_fishing_spot.set_gameplay_input_enabled(active)
	_water_recovery.set_recovery_enabled(active)
	_game_ui.set_gameplay_ui_enabled(active)
	_save_manager.set_autosave_enabled(active)


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
	if not _network_session.start_private_host():
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
	if not _save_manager.save_if_dirty():
		_game_ui.get_pause_menu().report_network_error(
			"Could not save progression before leaving this session."
		)
		return
	_join_requested_from_pause = true
	_join_requested_from_title = false
	_pending_join_endpoint = endpoint
	_game_ui.get_pause_menu().close_for_title_transition()
	_network_session.disconnect_session("Connecting to another game.")
	if not _network_session.join_direct(endpoint):
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


func _on_network_server_lost() -> void:
	if not _gameplay_started:
		return
	_set_gameplay_active(false)
	var title_screen: TitleScreenType = _game_ui.get_title_screen()
	title_screen.reopen()
	title_screen.open_join_game_page(_pending_join_endpoint)
	title_screen.report_network_error("The server connection was lost.")
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
	_game_ui.close_player_menu_for_water_recovery()
	_game_ui.get_pause_menu().close_for_water_recovery()
	_game_ui.get_fishing_shop().close_for_water_recovery()


func _on_active_hotbar_item_changed(
	_slot_index: int,
	item_id: StringName,
) -> void:
	if _fishing_spot.state != FishingSpotType.FishingState.READY:
		return
	var item = item_catalog.get_item_by_id(item_id)
	var active_is_rod: bool = (
		item != null
		and item.category == ItemDataType.Category.ROD
		and _player.bag.owns_item(item_id)
	)
	_player.set_active_item_is_rod(active_is_rod)
	_fishing_spot.refresh_active_item_status()


func _refresh_active_hotbar_item() -> void:
	_on_active_hotbar_item_changed(
		_player.hotbar.get_selected_slot(),
		_player.hotbar.get_selected_item_id()
	)


func _on_quit_requested() -> void:
	if _quit_in_progress:
		return
	_quit_in_progress = true
	_settings_manager.save_if_dirty()
	if _gameplay_started:
		_save_manager.save_if_dirty()
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
	if _title_music_tween != null:
		_title_music_tween.kill()
		_title_music_tween = null
	if is_instance_valid(_title_music):
		_title_music.stop()
		_title_music.stream = null


func _on_shop_range_changed(in_range: bool) -> void:
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
