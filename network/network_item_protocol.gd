class_name NetworkItemProtocol
extends RefCounted

const ITEM_USE_CAPABILITY: StringName = &"item_use_v1"
const EQUIPMENT_CAPABILITY: StringName = &"equipment_v1"
const RELIABLE_CHANNEL: int = NetworkProtocol.ITEM_RELIABLE_CHANNEL
const MAX_ID_LENGTH: int = 96
const MAX_ITEM_ID_LENGTH: int = 96
const MAX_MESSAGE_LENGTH: int = 160


static func validate_use_request(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "Item use could not be completed."
	var value: Dictionary = data
	for key: String in [
		"request_id", "session_id", "item_id", "quantity",
	]:
		if not value.has(key):
			return "Item use could not be completed."
	if (
		not _valid_id(value["request_id"])
		or not _valid_id(value["session_id"])
		or typeof(value["item_id"]) not in [TYPE_STRING, TYPE_STRING_NAME]
		or str(value["item_id"]).is_empty()
		or str(value["item_id"]).length() > MAX_ITEM_ID_LENGTH
		or typeof(value["quantity"]) != TYPE_INT
		or int(value["quantity"]) < 1
		or int(value["quantity"]) > 99
	):
		return "Item use could not be completed."
	return ""


static func validate_use_result(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	return (
		_valid_id(value.get("result_id"))
		and _valid_id(value.get("request_id"))
		and _valid_id(value.get("session_id"))
		and typeof(value.get("target_peer_id")) == TYPE_INT
		and typeof(value.get("accepted")) == TYPE_BOOL
		and typeof(value.get("item_id")) in [TYPE_STRING, TYPE_STRING_NAME]
		and not str(value["item_id"]).is_empty()
		and str(value["item_id"]).length() <= MAX_ITEM_ID_LENGTH
		and typeof(value.get("quantity")) == TYPE_INT
		and int(value["quantity"]) >= 0
		and int(value["quantity"]) <= 1
		and typeof(value.get("duration")) in [TYPE_FLOAT, TYPE_INT]
		and is_finite(float(value["duration"]))
		and float(value["duration"]) >= 0.0
		and typeof(value.get("message")) == TYPE_STRING
		and str(value["message"]).length() <= MAX_MESSAGE_LENGTH
	)


static func validate_equipped_state(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	return (
		_valid_id(value.get("session_id"))
		and typeof(value.get("owner_peer_id")) == TYPE_INT
		and int(value["owner_peer_id"]) > 0
		and typeof(value.get("item_id")) in [TYPE_STRING, TYPE_STRING_NAME]
		and str(value["item_id"]).length() <= MAX_ITEM_ID_LENGTH
		and typeof(value.get("category")) == TYPE_INT
		and int(value["category"]) >= -1
		and int(value["category"]) < ItemData.Category.size()
		and typeof(value.get("revision")) == TYPE_INT
		and int(value["revision"]) >= 0
		and typeof(value.get("owns_item")) == TYPE_BOOL
	)


static func _valid_id(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_STRING
		and not str(value).is_empty()
		and str(value).length() <= MAX_ID_LENGTH
	)
