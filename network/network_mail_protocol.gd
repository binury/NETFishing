class_name NetworkMailProtocol
extends RefCounted

const CAPABILITY: StringName = &"mail_v1"
const RELIABLE_CHANNEL: int = NetworkProtocol.MAIL_RELIABLE_CHANNEL
const MAX_ID_LENGTH: int = 96
const MAX_BODY_CHARACTERS: int = 2000
const MAX_BODY_BYTES: int = 8000
const MAX_RECIPIENT_LETTERS: int = 100
const MAX_SESSION_LETTERS: int = 200

const GREETINGS: PackedStringArray = ["dear", "to", "hey", "greetings"]
const SALUTATIONS: PackedStringArray = [
	"love", "from", "cheers", "salutations", "good_luck_have_fun",
]

enum State {
	SENT_UNREAD,
	READ,
	ACCEPTANCE_PENDING,
	ACCEPTED,
	DECLINED,
	ATTACHMENT_RECALLED,
	CANCELLED,
	SESSION_ENDED,
}


static func sanitize_body(value: Variant) -> String:
	if typeof(value) != TYPE_STRING:
		return ""
	var body := str(value).strip_edges(false, true)
	if (
		body.strip_edges().is_empty()
		or body.length() > MAX_BODY_CHARACTERS
		or body.to_utf8_buffer().size() > MAX_BODY_BYTES
	):
		return ""
	for index: int in body.length():
		var codepoint := body.unicode_at(index)
		if codepoint < 32 and codepoint not in [9, 10, 13]:
			return ""
		if codepoint == 127:
			return ""
	return body.replace("\r\n", "\n").replace("\r", "\n").replace("\t", "    ")


static func valid_id(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_STRING
		and not str(value).is_empty()
		and str(value).length() <= MAX_ID_LENGTH
	)


static func validate_send_request(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	return (
		valid_id(value.get("request_id"))
		and valid_id(value.get("session_id"))
		and typeof(value.get("recipient_peer_id")) == TYPE_INT
		and int(value["recipient_peer_id"]) > 0
		and typeof(value.get("greeting_id")) == TYPE_STRING
		and str(value["greeting_id"]) in GREETINGS
		and not sanitize_body(value.get("body")).is_empty()
		and typeof(value.get("salutation_id")) == TYPE_STRING
		and str(value["salutation_id"]) in SALUTATIONS
		and typeof(value.get("reservation_id")) == TYPE_STRING
		and str(value["reservation_id"]).length() <= MAX_ID_LENGTH
		and typeof(value.get("attachment")) == TYPE_DICTIONARY
		and Dictionary(value["attachment"]).size() <= 3
	)


static func validate_mail(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	return (
		valid_id(value.get("mail_id"))
		and valid_id(value.get("session_id"))
		and typeof(value.get("sequence")) == TYPE_INT
		and typeof(value.get("sender_peer_id")) == TYPE_INT
		and typeof(value.get("recipient_peer_id")) == TYPE_INT
		and typeof(value.get("sender_display_name")) == TYPE_STRING
		and str(value["sender_display_name"]).length() <= 24
		and str(value.get("greeting_id", "")) in GREETINGS
		and not sanitize_body(value.get("body")).is_empty()
		and str(value.get("salutation_id", "")) in SALUTATIONS
		and typeof(value.get("attachment")) == TYPE_DICTIONARY
		and Dictionary(value["attachment"]).size() <= 3
		and typeof(value.get("state")) == TYPE_INT
		and int(value["state"]) >= 0
		and int(value["state"]) < State.size()
	)
