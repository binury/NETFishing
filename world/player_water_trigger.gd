class_name PlayerWaterTrigger
extends Area3D

signal recovery_requested(player: Player, surface_height: float)

@export var surface_height: float = 0.2
@export_range(0.0, 2.0, 0.05) var entry_depth_threshold: float = 0.35

var _tracked_players: Array[Player] = []
var _triggered_players: Dictionary[StringName, bool] = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	for player: Player in _tracked_players.duplicate():
		if not is_instance_valid(player):
			_tracked_players.erase(player)
			continue
		var player_key: StringName = StringName(str(player.get_instance_id()))
		if _triggered_players.has(player_key):
			continue
		if (
			player.get_body_center_position().y
			<= surface_height - entry_depth_threshold
		):
			_triggered_players[player_key] = true
			recovery_requested.emit(player, surface_height)


func _on_body_entered(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null or player in _tracked_players:
		return
	_tracked_players.append(player)


func _on_body_exited(body: Node3D) -> void:
	var player: Player = body as Player
	if player == null:
		return
	_tracked_players.erase(player)
	_triggered_players.erase(StringName(str(player.get_instance_id())))
