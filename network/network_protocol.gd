class_name NetworkProtocol
extends RefCounted

const PROTOCOL_VERSION: int = 2
const GAME_BUILD: String = "prealpha"
const MAX_DISPLAY_NAME_LENGTH: int = 48
const MAX_PROFILE_ID_LENGTH: int = 96
const MAX_NONCE_LENGTH: int = 96
# ENet channels: 0 reliable lifecycle, 1 movement input, 2 movement
# snapshots, 3 fishing input, 4 fishing snapshots, 5 reliable sales,
# 6 reliable shop transactions.
const SALE_RELIABLE_CHANNEL: int = 5
const SHOP_RELIABLE_CHANNEL: int = 6

enum RejectionCode {
	NONE,
	MALFORMED_HANDSHAKE,
	PROTOCOL_MISMATCH,
	SERVER_FULL,
	DUPLICATE_PROFILE,
	AUTHENTICATION_TIMEOUT,
	SERVER_SHUTTING_DOWN,
	UNSUPPORTED_CLIENT,
}


static func make_client_hello(
	profile_id: String,
	display_name: String,
	client_nonce: String,
) -> Dictionary:
	return {
		"protocol_version": PROTOCOL_VERSION,
		"game_build": GAME_BUILD,
		"local_profile_id": profile_id,
		"display_name": display_name,
		"client_nonce": client_nonce,
		"capability_flags": PackedStringArray(),
		"cosmetic_snapshot": {},
	}


static func validate_client_hello(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "Handshake payload is not a dictionary."
	var payload: Dictionary = data
	for key: String in [
		"protocol_version",
		"game_build",
		"local_profile_id",
		"display_name",
		"client_nonce",
		"capability_flags",
		"cosmetic_snapshot",
	]:
		if not payload.has(key):
			return "Handshake is missing %s." % key
	if typeof(payload["protocol_version"]) != TYPE_INT:
		return "Protocol version is invalid."
	if typeof(payload["game_build"]) != TYPE_STRING:
		return "Game build is invalid."
	if typeof(payload["local_profile_id"]) != TYPE_STRING:
		return "Profile ID is invalid."
	if typeof(payload["display_name"]) != TYPE_STRING:
		return "Display name is invalid."
	if typeof(payload["client_nonce"]) != TYPE_STRING:
		return "Client nonce is invalid."
	if typeof(payload["capability_flags"]) not in [
		TYPE_PACKED_STRING_ARRAY,
		TYPE_ARRAY,
	]:
		return "Capabilities are invalid."
	if typeof(payload["cosmetic_snapshot"]) != TYPE_DICTIONARY:
		return "Cosmetic snapshot is invalid."
	var profile_id: String = payload["local_profile_id"]
	var display_name: String = payload["display_name"]
	var nonce: String = payload["client_nonce"]
	if (
		profile_id.is_empty()
		or profile_id.length() > MAX_PROFILE_ID_LENGTH
		or display_name.is_empty()
		or display_name.length() > MAX_DISPLAY_NAME_LENGTH
		or nonce.is_empty()
		or nonce.length() > MAX_NONCE_LENGTH
	):
		return "Handshake strings are outside allowed limits."
	return ""


static func make_server_hello(
	accepted: bool,
	rejection_code: RejectionCode,
	session_id: String,
	assigned_peer_id: int,
	player_count: int,
	max_players: int,
) -> Dictionary:
	return {
		"accepted": accepted,
		"rejection_code": int(rejection_code),
		"protocol_version": PROTOCOL_VERSION,
		"session_id": session_id,
		"assigned_peer_id": assigned_peer_id,
		"server_display_name": "NETFISHING",
		"player_count": player_count,
		"max_players": max_players,
		"capability_flags": PackedStringArray([
			"movement_v1",
			"fishing_v1",
			"sale_v1",
			"shop_v1",
		]),
	}


static func rejection_text(code: int) -> String:
	match code:
		RejectionCode.PROTOCOL_MISMATCH:
			return "The server uses a different network protocol."
		RejectionCode.SERVER_FULL:
			return "The server is full."
		RejectionCode.DUPLICATE_PROFILE:
			return "This local profile is already connected."
		RejectionCode.AUTHENTICATION_TIMEOUT:
			return "The server did not finish authentication."
		RejectionCode.SERVER_SHUTTING_DOWN:
			return "The server is shutting down."
		RejectionCode.UNSUPPORTED_CLIENT:
			return "This game build is not supported by the server."
		_:
			return "The server rejected the connection."
