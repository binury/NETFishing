class_name DirectEnetTransport
extends NetworkTransport


func start_host(
	port: int,
	max_clients: int,
	bind_address: String = "*",
) -> Error:
	disconnect_transport()
	var enet_peer := ENetMultiplayerPeer.new()
	if not bind_address.is_empty() and bind_address != "*":
		enet_peer.set_bind_ip(bind_address)
	var error: Error = enet_peer.create_server(
		port, max_clients, NetworkProtocol.ENET_CHANNEL_COUNT
	)
	if error != OK:
		transport_error.emit("Unable to host UDP port %d." % port)
		return error
	_peer = enet_peer
	_route_description = "UDP *:%d" % port
	return OK


func connect_to_route(route: ConnectionRoute) -> Error:
	disconnect_transport()
	if route == null or not route.is_valid():
		transport_error.emit("The direct connection route is invalid.")
		return ERR_INVALID_PARAMETER
	var endpoint: ConnectionEndpoint = route.direct_endpoint
	var enet_peer := ENetMultiplayerPeer.new()
	var error: Error = enet_peer.create_client(
		endpoint.host, endpoint.port, NetworkProtocol.ENET_CHANNEL_COUNT
	)
	if error != OK:
		transport_error.emit(
			"Unable to connect to %s." % endpoint.normalized_display
		)
		return error
	_peer = enet_peer
	_route_description = endpoint.normalized_display
	return OK


func send_raw_packet(
	destination_address: String,
	destination_port: int,
	packet: PackedByteArray,
) -> bool:
	var enet_peer := _peer as ENetMultiplayerPeer
	if (
		enet_peer == null
		or enet_peer.host == null
		or destination_address.is_empty()
		or destination_port < 1
		or destination_port > 65535
		or packet.is_empty()
	):
		return false
	enet_peer.host.socket_send(destination_address, destination_port, packet)
	return true
