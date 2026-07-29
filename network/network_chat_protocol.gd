class_name NetworkChatProtocol
extends RefCounted

const CAPABILITY: StringName = &"chat_v1"
const RELIABLE_CHANNEL: int = NetworkProtocol.CHAT_RELIABLE_CHANNEL
const MAX_VISIBLE_CHARACTERS: int = 300
const MAX_UTF8_BYTES: int = 1200
const MAX_HISTORY: int = 100
const LATE_JOIN_HISTORY: int = 50
const MAX_ID_LENGTH: int = 96

enum Kind { PLAYER, SYSTEM }


static func sanitize_body(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	var result: String = str(value).replace("\r", " ").replace("\n", " ")
	result = result.replace("\t", " ").strip_edges()
	if result.is_empty() or result.length() > MAX_VISIBLE_CHARACTERS:
		return ""
	if result.to_utf8_buffer().size() > MAX_UTF8_BYTES:
		return ""
	for index: int in result.length():
		var codepoint: int = result.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			return ""
	return result


static func validate_request(data: Variant) -> bool:
	return (
		typeof(data) == TYPE_DICTIONARY
		and _valid_id(data.get("request_id"))
		and _valid_id(data.get("session_id"))
		and not sanitize_body(data.get("body")).is_empty()
	)


static func validate_message(data: Variant) -> bool:
	return (
		typeof(data) == TYPE_DICTIONARY
		and _valid_id(data.get("message_id"))
		and _valid_id(data.get("session_id"))
		and typeof(data.get("sequence")) == TYPE_INT
		and int(data["sequence"]) >= 0
		and typeof(data.get("kind")) == TYPE_INT
		and int(data["kind"]) in [Kind.PLAYER, Kind.SYSTEM]
		and typeof(data.get("sender_peer_id")) == TYPE_INT
		and typeof(data.get("sender_display_name")) == TYPE_STRING
		and str(data["sender_display_name"]).length() <= 24
		and not sanitize_body(data.get("body")).is_empty()
	)


static func _valid_id(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_STRING
		and not str(value).is_empty()
		and str(value).length() <= MAX_ID_LENGTH
	)
