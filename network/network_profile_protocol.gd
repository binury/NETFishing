class_name NetworkProfileProtocol
extends RefCounted

const RELIABLE_CHANNEL: int = 0
const MAX_SUGGESTIONS: int = 3
const MAX_REQUEST_ID_LENGTH: int = 64


static func valid_request_id(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_STRING
		and not str(value).is_empty()
		and str(value).length() <= MAX_REQUEST_ID_LENGTH
	)


static func valid_snapshot(value: Variant) -> bool:
	return CharacterCustomizationCatalog.validate_snapshot(value)


static func valid_check_request(data: Variant) -> bool:
	return (
		typeof(data) == TYPE_DICTIONARY
		and valid_request_id(data.get("request_id"))
		and typeof(data.get("session_id")) == TYPE_STRING
		and typeof(data.get("display_name")) == TYPE_STRING
		and NetworkProfilePreferences.is_valid_display_name(data["display_name"])
	)


static func valid_apply_request(data: Variant) -> bool:
	return (
		valid_check_request(data)
		and typeof(data.get("appearance")) == TYPE_DICTIONARY
		and valid_snapshot(data["appearance"])
		and typeof(data.get("use_anyway")) == TYPE_BOOL
		and NetworkIdentityCrypto.valid_fingerprint(
			data.get("sender_fingerprint")
		)
		and typeof(data.get("sender_signature")) == TYPE_PACKED_BYTE_ARRAY
	)


static func signature_fields(data: Dictionary) -> Array:
	var appearance: Dictionary = data.get("appearance", {})
	return [
		str(data.get("session_id", "")),
		str(data.get("request_id", "")),
		str(data.get("sender_fingerprint", "")),
		str(data.get("display_name", "")),
		str(appearance.get("species", "")),
		str(appearance.get("fur_pattern", "")),
		str(appearance.get("ears", "")),
		str(appearance.get("eyes", "")),
		str(appearance.get("nose", "")),
		str(appearance.get("mouth", "")),
		str(appearance.get("tail", "")),
		bool(data.get("use_anyway", false)),
	]
