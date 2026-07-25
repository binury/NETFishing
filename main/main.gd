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

@export var fish_catalog: FishPoolType
@export var pelican_buyer_profile: FishBuyerProfileType

@onready var _test_world: TestWorldType = $TestWorld
@onready var _player: PlayerType = %Player
@onready var _fishing_spot: FishingSpotType = %FishingSpot
@onready var _game_ui: GameUIType = %GameUI
@onready var _water_recovery: WaterRecoveryControllerType = %WaterRecovery


func _ready() -> void:
	_player.fish_sale_service.setup(
		_player.inventory,
		_player.wallet
	)
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
