class_name FishingShopInteraction
extends Area3D

signal local_player_range_changed(in_range: bool)

var _local_player: Player
var _local_player_in_range: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func setup_local_player(player: Player) -> void:
	_local_player = player
	_refresh_overlaps()


func is_local_player_in_range() -> bool:
	return _local_player_in_range


func _refresh_overlaps() -> void:
	var is_overlapping: bool = (
		_local_player != null
		and is_instance_valid(_local_player)
		and _local_player in get_overlapping_bodies()
	)
	_set_local_player_in_range(is_overlapping)


func _on_body_entered(body: Node3D) -> void:
	if body == _local_player:
		_set_local_player_in_range(true)


func _on_body_exited(body: Node3D) -> void:
	if body == _local_player:
		_set_local_player_in_range(false)


func _set_local_player_in_range(in_range: bool) -> void:
	if _local_player_in_range == in_range:
		return
	_local_player_in_range = in_range
	local_player_range_changed.emit(in_range)
