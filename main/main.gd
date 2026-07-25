extends Node3D

const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const GameUIType = preload("res://ui/game_ui.gd")
const PlayerType = preload("res://player/player.gd")

@onready var _player: PlayerType = %Player
@onready var _fishing_spot: FishingSpotType = %FishingSpot
@onready var _game_ui: GameUIType = %GameUI


func _ready() -> void:
	_fishing_spot.setup(
		_player,
		_player.inventory,
		_player.collection_log
	)
	_game_ui.setup(_player.inventory, _fishing_spot)
