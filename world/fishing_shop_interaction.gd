class_name FishingShopInteraction
extends Area3D

signal local_player_range_changed(in_range: bool)

@export_node_path("Node3D") var look_character_path: NodePath = ^"../Shopkeeper"

var _local_player: Player
var _local_player_in_range: bool = false
var _look_character: WorldCharacterDisplay


func _ready() -> void:
	_look_character = get_node_or_null(
		look_character_path
	) as WorldCharacterDisplay
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func setup_local_player(player: Player) -> void:
	_local_player = player
	if _look_character != null:
		_look_character.set_head_look_target(player)
	_refresh_overlaps()


func is_local_player_in_range() -> bool:
	return _local_player_in_range


func is_avatar_in_range(avatar: Player) -> bool:
	return (
		avatar != null
		and is_instance_valid(avatar)
		and avatar in get_overlapping_bodies()
	)


func get_prompt_anchor_position() -> Vector3:
	if _look_character != null:
		return _look_character.get_head_anchor_position()
	return global_position + Vector3.UP * 1.25


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
	if _look_character != null:
		_look_character.set_head_look_active(in_range)
	if _local_player_in_range == in_range:
		return
	_local_player_in_range = in_range
	local_player_range_changed.emit(in_range)
