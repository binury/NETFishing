extends Node3D

const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const FishBuyerProfileType = preload("res://economy/fish_buyer_profile.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const GameUIType = preload("res://ui/game_ui.gd")
const PlayerType = preload("res://player/player.gd")

@export var fish_catalog: FishPoolType
@export var pelican_buyer_profile: FishBuyerProfileType

@onready var _player: PlayerType = %Player
@onready var _fishing_spot: FishingSpotType = %FishingSpot
@onready var _game_ui: GameUIType = %GameUI


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
