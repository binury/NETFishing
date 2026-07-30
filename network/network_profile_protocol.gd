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
	)
