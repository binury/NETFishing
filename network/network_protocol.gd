class_name NetworkProtocol
extends RefCounted

const PROTOCOL_VERSION: int = 3
const GAME_BUILD: String = "prealpha"
const MAX_DISPLAY_NAME_LENGTH: int = 24
const MAX_PROFILE_ID_LENGTH: int = 96
const MAX_NONCE_LENGTH: int = 96
const MAX_PUBLIC_KEY_LENGTH: int = 8192
const MAX_SIGNATURE_LENGTH: int = 2048
# ENet channels: 0 reliable lifecycle, 1 movement input, 2 movement
# snapshots, 3 fishing input, 4 fishing snapshots, 5 reliable sales,
# 6 reliable shop transactions, 7 reliable item/equipment/showcase/drawing,
# 8 reliable ordered session chat, 9 reliable private session mail.
const SALE_RELIABLE_CHANNEL: int = 5
const SHOP_RELIABLE_CHANNEL: int = 6
const ITEM_RELIABLE_CHANNEL: int = 7
const CHAT_RELIABLE_CHANNEL: int = 8
const MAIL_RELIABLE_CHANNEL: int = 9
const ENET_CHANNEL_COUNT: int = 10
const SURFACE_DRAWING_CAPABILITY: String = "surface_drawing_v2"
const ART_SHOP_CAPABILITY: String = "art_shop_v1"
const WORLD_TIME_CAPABILITY: String = "world_time_v1"
const WORLD_WEATHER_CAPABILITY: String = "world_weather_v1"
const FISH_QUALITY_CAPABILITY: String = "fish_quality_v1"
const JOBS_CAPABILITY: String = "jobs_v1"

enum RejectionCode {
	NONE,
	MALFORMED_HANDSHAKE,
	PROTOCOL_MISMATCH,
	SERVER_FULL,
	DUPLICATE_PROFILE,
	DUPLICATE_IDENTITY,
	INVALID_IDENTITY_PROOF,
	AUTHENTICATION_TIMEOUT,
	SERVER_SHUTTING_DOWN,
	UNSUPPORTED_CLIENT,
	BANNED,
}


static func make_identity_hello(
	public_key: String,
	fingerprint: String,
	client_nonce: String,
	attempt_id: String,
) -> Dictionary:
	return {
		"protocol_version": PROTOCOL_VERSION,
		"public_key": public_key,
		"fingerprint": fingerprint,
		"client_nonce": client_nonce,
		"attempt_id": attempt_id,
		"capability_flags": PackedStringArray(["identity_v1"]),
	}


static func validate_identity_hello(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	return (
		typeof(value.get("protocol_version")) == TYPE_INT
		and typeof(value.get("public_key")) == TYPE_STRING
		and str(value["public_key"]).to_utf8_buffer().size() <= MAX_PUBLIC_KEY_LENGTH
		and NetworkIdentityCrypto.valid_fingerprint(value.get("fingerprint"))
		and typeof(value.get("client_nonce")) == TYPE_STRING
		and str(value["client_nonce"]).length() == 64
		and typeof(value.get("attempt_id")) == TYPE_STRING
		and str(value["attempt_id"]).length() == 32
		and typeof(value.get("capability_flags")) in [
			TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY
		]
	)


static func make_client_hello(
	profile_id: String,
	display_name: String,
	client_nonce: String,
	cosmetic_snapshot: Dictionary = {},
	identity_fingerprint: String = "",
	identity_signature: PackedByteArray = PackedByteArray(),
) -> Dictionary:
	return {
		"protocol_version": PROTOCOL_VERSION,
		"game_build": GAME_BUILD,
		"local_profile_id": profile_id,
		"display_name": display_name,
		"client_nonce": client_nonce,
		"capability_flags": PackedStringArray([
			FISH_QUALITY_CAPABILITY,
			SURFACE_DRAWING_CAPABILITY,
			WORLD_TIME_CAPABILITY,
			WORLD_WEATHER_CAPABILITY,
			JOBS_CAPABILITY,
		]),
		"cosmetic_snapshot": cosmetic_snapshot,
		"identity_fingerprint": identity_fingerprint,
		"identity_signature": identity_signature,
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
		"identity_fingerprint",
		"identity_signature",
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
	var capabilities: Variant = payload["capability_flags"]
	if capabilities.size() > 32:
		return "Capabilities are invalid."
	for capability: Variant in capabilities:
		if (
			typeof(capability) not in [TYPE_STRING, TYPE_STRING_NAME]
			or str(capability).is_empty()
			or str(capability).length() > 64
		):
			return "Capabilities are invalid."
	if typeof(payload["cosmetic_snapshot"]) != TYPE_DICTIONARY:
		return "Cosmetic snapshot is invalid."
	if (
		not NetworkIdentityCrypto.valid_fingerprint(
			payload["identity_fingerprint"]
		)
		or typeof(payload["identity_signature"]) != TYPE_PACKED_BYTE_ARRAY
	):
		return "Profile identity proof is invalid."
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


static func client_profile_fields(data: Dictionary) -> Array:
	var appearance: Dictionary = data.get("cosmetic_snapshot", {})
	return [
		str(data.get("client_nonce", "")),
		str(data.get("identity_fingerprint", "")),
		str(data.get("local_profile_id", "")),
		str(data.get("display_name", "")),
		str(appearance.get("species", "")),
		CharacterCustomizationCatalog.character_scale_percent(
			appearance.get(
				CharacterCustomizationCatalog.SCALE_CATEGORY_ID,
				CharacterCustomizationCatalog.DEFAULT_CHARACTER_SCALE,
			)
		),
		str(appearance.get("fur_pattern", "")),
		str(appearance.get("ears", "")),
		str(appearance.get("eyes", "")),
		str(appearance.get("nose", "")),
		str(appearance.get("mouth", "")),
		str(appearance.get("tail", "")),
	]


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
		"server_display_name": "NETfishing",
		"player_count": player_count,
		"max_players": max_players,
		"capability_flags": PackedStringArray([
			"movement_v1",
			"fishing_v1",
			"sale_v1",
			"shop_v1",
			ART_SHOP_CAPABILITY,
			"item_use_v1",
			"equipment_v1",
			"fish_showcase_v1",
			FISH_QUALITY_CAPABILITY,
			SURFACE_DRAWING_CAPABILITY,
			WORLD_TIME_CAPABILITY,
			WORLD_WEATHER_CAPABILITY,
			JOBS_CAPABILITY,
			"chat_v1",
			"mail_v1",
			"profile_v1",
			"identity_v1",
		]),
	}


static func rejection_text(code: int) -> String:
	match code:
		RejectionCode.PROTOCOL_MISMATCH:
			return "The server uses a different network protocol."
		RejectionCode.SERVER_FULL:
			return "The server is full."
		RejectionCode.DUPLICATE_PROFILE:
			return "This legacy local profile is already connected."
		RejectionCode.DUPLICATE_IDENTITY:
			return "This player identity is already connected."
		RejectionCode.INVALID_IDENTITY_PROOF:
			return "Player identity authentication failed."
		RejectionCode.AUTHENTICATION_TIMEOUT:
			return "The server did not finish authentication."
		RejectionCode.SERVER_SHUTTING_DOWN:
			return "The server is shutting down."
		RejectionCode.UNSUPPORTED_CLIENT:
			return "This game build is not supported by the server."
		RejectionCode.BANNED:
			return "You are not permitted to join this server."
		_:
			return "The server rejected the connection."
