class_name NetworkTransport
extends Node

signal transport_error(message: String)

var _peer: MultiplayerPeer
var _route_description: String = ""


func start_host(
	_port: int,
	_max_clients: int,
	_bind_address: String = "*",
) -> Error:
	return ERR_UNAVAILABLE


func connect_to_route(_route: ConnectionRoute) -> Error:
	return ERR_UNAVAILABLE


func disconnect_transport() -> void:
	if _peer != null:
		_peer.close()
	_peer = null
	_route_description = ""


func get_multiplayer_peer() -> MultiplayerPeer:
	return _peer


func get_route_description() -> String:
	return _route_description
