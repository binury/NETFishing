class_name NetworkSaleProtocol
extends RefCounted

const CAPABILITY: StringName = &"sale_v1"
const RELIABLE_CHANNEL: int = NetworkProtocol.SALE_RELIABLE_CHANNEL
const MAX_ID_LENGTH: int = 96
const MAX_CATCH_ID_LENGTH: int = 160
const MAX_CATCHES_PER_REQUEST: int = 64
const MAX_ITEM_STACKS_PER_REQUEST: int = 20
const MAX_ITEM_QUANTITY: int = 999
const MAX_MESSAGE_LENGTH: int = 160

enum Rejection {
	NONE,
	MALFORMED,
	STALE_SESSION,
	UNAUTHENTICATED,
	ALREADY_PENDING,
	BUYER_UNAVAILABLE,
	TOO_FAR,
	INVALID_CATCH,
	FAVORITED,
	UNSUPPORTED,
}


static func validate_request(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "Sale could not be completed."
	var payload: Dictionary = data
	for key: String in ["request_id", "session_id", "buyer_id", "catches"]:
		if not payload.has(key):
			return "Sale could not be completed."
	if (
		typeof(payload["request_id"]) != TYPE_STRING
		or typeof(payload["session_id"]) != TYPE_STRING
		or typeof(payload["buyer_id"]) not in [TYPE_STRING, TYPE_STRING_NAME]
		or typeof(payload["catches"]) != TYPE_ARRAY
	):
		return "Sale could not be completed."
	var request_id: String = payload["request_id"]
	var session_id: String = payload["session_id"]
	var buyer_id: String = str(payload["buyer_id"])
	var catches: Array = payload["catches"]
	var items: Array = payload.get("items", [])
	if (
		request_id.is_empty()
		or request_id.length() > MAX_ID_LENGTH
		or session_id.is_empty()
		or session_id.length() > MAX_ID_LENGTH
		or buyer_id.is_empty()
		or buyer_id.length() > MAX_ID_LENGTH
		or typeof(items) != TYPE_ARRAY
		or (catches.is_empty() and items.is_empty())
		or catches.size() > MAX_CATCHES_PER_REQUEST
		or items.size() > MAX_ITEM_STACKS_PER_REQUEST
	):
		return "Sale could not be completed."
	var seen: Dictionary[String, bool] = {}
	for value: Variant in catches:
		if typeof(value) != TYPE_DICTIONARY:
			return "Sale could not be completed."
		var evidence: Dictionary = value
		for key: String in [
			"catch_id", "fish_id", "weight_lb", "display_scale",
			"quality", "sale_value", "is_favorited",
		]:
			if not evidence.has(key):
				return "Sale could not be completed."
		var catch_id: String = str(evidence["catch_id"])
		if (
			catch_id.is_empty()
			or catch_id.length() > MAX_CATCH_ID_LENGTH
			or seen.has(catch_id)
			or typeof(evidence["fish_id"]) not in [
				TYPE_STRING, TYPE_STRING_NAME
			]
			or typeof(evidence["is_favorited"]) != TYPE_BOOL
		):
			return "Sale could not be completed."
		seen[catch_id] = true
	var seen_items: Dictionary[String, bool] = {}
	for value: Variant in items:
		if typeof(value) != TYPE_DICTIONARY:
			return "Sale could not be completed."
		var item: Dictionary = value
		var item_id := str(item.get("item_id", ""))
		var quantity := int(item.get("quantity", 0))
		if (
			item_id.is_empty()
			or item_id.length() > MAX_ID_LENGTH
			or seen_items.has(item_id)
			or typeof(item.get("quantity")) != TYPE_INT
			or quantity < 1
			or quantity > MAX_ITEM_QUANTITY
		):
			return "Sale could not be completed."
		seen_items[item_id] = true
	return ""


static func validate_result(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = data
	if not (
		typeof(payload.get("result_id")) == TYPE_STRING
		and not str(payload["result_id"]).is_empty()
		and str(payload["result_id"]).length() <= MAX_ID_LENGTH
		and typeof(payload.get("request_id")) == TYPE_STRING
		and not str(payload["request_id"]).is_empty()
		and str(payload["request_id"]).length() <= MAX_ID_LENGTH
		and typeof(payload.get("session_id")) == TYPE_STRING
		and typeof(payload.get("target_peer_id")) == TYPE_INT
		and typeof(payload.get("accepted")) == TYPE_BOOL
		and typeof(payload.get("catch_ids")) == TYPE_ARRAY
		and payload["catch_ids"].size() <= MAX_CATCHES_PER_REQUEST
		and typeof(payload.get("items", [])) == TYPE_ARRAY
		and payload.get("items", []).size() <= MAX_ITEM_STACKS_PER_REQUEST
		and typeof(payload.get("payout")) == TYPE_INT
		and int(payload["payout"]) >= 0
		and typeof(payload.get("base_value")) == TYPE_INT
		and int(payload["base_value"]) >= 0
		and typeof(payload.get("message")) == TYPE_STRING
		and str(payload["message"]).length() <= MAX_MESSAGE_LENGTH
	):
		return false
	if payload.has("buyer_id") and (
		typeof(payload["buyer_id"]) not in [TYPE_STRING, TYPE_STRING_NAME]
		or str(payload["buyer_id"]).is_empty()
		or str(payload["buyer_id"]).length() > MAX_ID_LENGTH
	):
		return false
	var seen: Dictionary[String, bool] = {}
	for value: Variant in payload["catch_ids"]:
		if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return false
		var catch_id: String = str(value)
		if (
			catch_id.is_empty()
			or catch_id.length() > MAX_CATCH_ID_LENGTH
			or seen.has(catch_id)
		):
			return false
		seen[catch_id] = true
	var seen_items: Dictionary[String, bool] = {}
	for value: Variant in payload.get("items", []):
		if typeof(value) != TYPE_DICTIONARY:
			return false
		var item := value as Dictionary
		var item_id := str(item.get("item_id", ""))
		if (
			item_id.is_empty()
			or item_id.length() > MAX_ID_LENGTH
			or seen_items.has(item_id)
			or typeof(item.get("quantity")) != TYPE_INT
			or int(item["quantity"]) < 1
			or int(item["quantity"]) > MAX_ITEM_QUANTITY
		):
			return false
		seen_items[item_id] = true
	return true
