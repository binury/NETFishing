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

@export var fish_catalog: FishPoolType
@export var pelican_buyer_profile: FishBuyerProfileType

@onready var _test_world: TestWorldType = $TestWorld
@onready var _player: PlayerType = %Player
@onready var _fishing_spot: FishingSpotType = %FishingSpot
@onready var _game_ui: GameUIType = %GameUI
@onready var _water_recovery: WaterRecoveryControllerType = %WaterRecovery
@onready var _save_manager: PlayerSaveManagerType = %PlayerSaveManager
@onready var _settings_manager: PlayerSettingsManagerType = %PlayerSettingsManager

var _gameplay_started: bool = false


func _ready() -> void:
	_player.fish_sale_service.setup(
		_player.inventory,
		_player.wallet
	)
	_save_manager.setup(
		_player.inventory,
		_player.collection_log,
		_player.wallet,
		fish_catalog
	)
	_save_manager.set_autosave_enabled(false)
	_fishing_spot.setup(
		_player,
		_player.inventory,
		_player.collection_log
	)
	_game_ui.setup(
		_player,
		_player.inventory,
		_player.collection_log,
		_player.wallet,
		_player.fish_sale_service,
		pelican_buyer_profile,
		fish_catalog,
		_fishing_spot
	)
	_water_recovery.setup(
		_player,
		_fishing_spot,
		_game_ui,
		_game_ui.get_screen_fade(),
		_test_world.get_player_water_trigger(),
		_test_world.get_safe_respawn_points()
	)
	if not _settings_manager.settings_changed.is_connected(
		_apply_runtime_settings
	):
		_settings_manager.settings_changed.connect(_apply_runtime_settings)
	_settings_manager.load_settings()
	_apply_runtime_settings(_settings_manager.current_settings)
	_set_gameplay_active(false)
	var title_screen: TitleScreenType = _game_ui.get_title_screen()
	title_screen.gameplay_requested.connect(_on_gameplay_requested)
	title_screen.quit_requested.connect(_on_quit_requested)
	title_screen.setup(_save_manager, _settings_manager)
	var pause_menu: PauseMenuType = _game_ui.get_pause_menu()
	pause_menu.setup(
		_player,
		_save_manager,
		_settings_manager,
		_fishing_spot
	)
	pause_menu.return_to_title_requested.connect(
		_on_return_to_title_requested
	)
	pause_menu.reset_progress_requested.connect(
		_on_reset_progress_requested
	)
	pause_menu.quit_requested.connect(_on_quit_requested)
	_water_recovery.recovery_starting.connect(
		_on_water_recovery_starting
	)


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


func _apply_runtime_settings(settings: PlayerSettingsType) -> void:
	if settings == null:
		return
	_player.apply_camera_settings(
		settings.mouse_camera_sensitivity,
		settings.controller_camera_sensitivity,
		settings.invert_camera_y
	)
	_fishing_spot.configure_accessibility_auto_click(
		settings.auto_click_enabled,
		settings.auto_click_interval
	)


func _set_gameplay_active(active: bool) -> void:
	_gameplay_started = active
	_player.set_movement_enabled(active)
	_player.set_camera_input_enabled(active)
	_fishing_spot.set_gameplay_input_enabled(active)
	_water_recovery.set_recovery_enabled(active)
	_game_ui.set_gameplay_ui_enabled(active)
	_save_manager.set_autosave_enabled(active)


func _on_gameplay_requested() -> void:
	if _gameplay_started:
		return
	_game_ui.get_title_screen().hide()
	_set_gameplay_active(true)


func _on_return_to_title_requested() -> void:
	var pause_menu: PauseMenuType = _game_ui.get_pause_menu()
	pause_menu.close_for_title_transition()
	_set_gameplay_active(false)
	_game_ui.get_title_screen().reopen()


func _on_reset_progress_requested() -> void:
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


func _on_water_recovery_starting() -> void:
	_game_ui.close_player_menu_for_water_recovery()
	_game_ui.get_pause_menu().close_for_water_recovery()


func _on_quit_requested() -> void:
	_settings_manager.save_if_dirty()
	if _gameplay_started:
		_save_manager.save_if_dirty()
	get_tree().quit()
