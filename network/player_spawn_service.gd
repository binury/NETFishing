class_name PlayerSpawnService
extends Node

const PlayerScene: PackedScene = preload("res://player/player.tscn")

signal avatar_spawned(peer_id: int, avatar: Player)
signal avatar_removed(peer_id: int)

var _players_root: Node3D
var _local_player: Player
var _spawn_transform: Transform3D
var _avatars: Dictionary[int, Player] = {}
var _local_peer_id: int = 1


func setup(
	players_root: Node3D,
	local_player: Player,
	spawn_transform: Transform3D,
) -> void:
	_players_root = players_root
	_local_player = local_player
	_spawn_transform = spawn_transform


func register_local_player(peer_id: int) -> void:
	if _local_player == null:
		return
	for existing_id: int in _avatars.keys():
		if _avatars[existing_id] == _local_player:
			_avatars.erase(existing_id)
	_local_peer_id = peer_id
	_avatars[peer_id] = _local_player
	_local_player.name = "Player_%d" % peer_id
	_local_player.set_local_control(true)
	_local_player.set_network_peer_id(peer_id)


func spawn_remote_player(
	peer_id: int,
	transform: Transform3D,
	authoritative_simulation: bool = false,
) -> Player:
	if peer_id <= 0 or peer_id == _local_peer_id:
		return null
	var existing: Player = _avatars.get(peer_id)
	if existing != null and is_instance_valid(existing):
		return existing
	var avatar := PlayerScene.instantiate() as Player
	avatar.name = "Player_%d" % peer_id
	avatar.set_local_control(false)
	avatar.set_network_peer_id(peer_id)
	_players_root.add_child(avatar)
	avatar.global_transform = transform
	avatar.configure_network_remote(authoritative_simulation)
	_avatars[peer_id] = avatar
	avatar_spawned.emit(peer_id, avatar)
	return avatar


func remove_peer(peer_id: int) -> void:
	if peer_id == _local_peer_id:
		return
	var avatar: Player = _avatars.get(peer_id)
	_avatars.erase(peer_id)
	if avatar != null and is_instance_valid(avatar):
		avatar.queue_free()
	avatar_removed.emit(peer_id)


func clear_remote_players() -> void:
	for peer_id: int in _avatars.keys():
		if peer_id != _local_peer_id:
			remove_peer(peer_id)


func get_avatar(peer_id: int) -> Player:
	return _avatars.get(peer_id)


func get_local_player() -> Player:
	return _local_player


func set_peer_presentation_visible(peer_id: int, should_be_visible: bool) -> void:
	var avatar: Player = _avatars.get(peer_id)
	if avatar != null and is_instance_valid(avatar):
		avatar.set_remote_presentation_visible(should_be_visible)


func get_peer_ids() -> Array[int]:
	var result: Array[int] = []
	for peer_id: int in _avatars:
		result.append(peer_id)
	result.sort()
	return result


func get_spawn_transform_for_index(index: int) -> Transform3D:
	if index <= 0:
		return _spawn_transform
	var angle: float = float(index) * 2.3999632297
	var ring: float = 1.4 + floor(float(index - 1) / 8.0) * 1.2
	var result: Transform3D = _spawn_transform
	result.origin += Vector3(cos(angle) * ring, 0.0, sin(angle) * ring)
	return result
