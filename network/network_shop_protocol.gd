class_name NetworkShopProtocol
extends RefCounted

const CAPABILITY: StringName = &"shop_v1"
const ART_CAPABILITY: StringName = &"art_shop_v1"
const RELIABLE_CHANNEL: int = NetworkProtocol.SHOP_RELIABLE_CHANNEL
const MAX_ID_LENGTH: int = 96
const MAX_MESSAGE_LENGTH: int = 160
const MAX_QUANTITY: int = 99

enum ProductCategory {
	SUPPLY,
	ROD,
	REEL_SPEED_UPGRADE,
	BARRIER_POWER_UPGRADE,
	COOLER_CAPACITY_UPGRADE,
	ART_KIT,
	ART_UPGRADE,
}


static func validate_request(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "Purchase could not be completed."
	var payload: Dictionary = data
	for key: String in [
		"request_id",
		"session_id",
		"shop_id",
		"product_id",
		"category",
		"quantity",
		"wallet_balance",
		"current_state",
	]:
		if not payload.has(key):
			return "Purchase could not be completed."
	if (
		typeof(payload["request_id"]) != TYPE_STRING
		or typeof(payload["session_id"]) != TYPE_STRING
		or typeof(payload["shop_id"]) not in [TYPE_STRING, TYPE_STRING_NAME]
		or typeof(payload["product_id"]) not in [
			TYPE_STRING, TYPE_STRING_NAME
		]
		or typeof(payload["category"]) != TYPE_INT
		or typeof(payload["quantity"]) != TYPE_INT
		or typeof(payload["wallet_balance"]) != TYPE_INT
		or typeof(payload["current_state"]) != TYPE_INT
	):
		return "Purchase could not be completed."
	var request_id: String = payload["request_id"]
	var session_id: String = payload["session_id"]
	var shop_id: String = str(payload["shop_id"])
	var product_id: String = str(payload["product_id"])
	var category: int = payload["category"]
	var quantity: int = payload["quantity"]
	var wallet_balance: int = payload["wallet_balance"]
	var current_state: int = payload["current_state"]
	if (
		payload.has("bait_unlocked")
		and typeof(payload["bait_unlocked"]) != TYPE_BOOL
	):
		return "Purchase could not be completed."
	if (
		request_id.is_empty()
		or request_id.length() > MAX_ID_LENGTH
		or session_id.is_empty()
		or session_id.length() > MAX_ID_LENGTH
		or shop_id.is_empty()
		or shop_id.length() > MAX_ID_LENGTH
		or product_id.is_empty()
		or product_id.length() > MAX_ID_LENGTH
		or category < 0
		or category >= ProductCategory.size()
		or quantity < 1
		or quantity > MAX_QUANTITY
		or wallet_balance < 0
		or current_state < 0
	):
		return "Purchase could not be completed."
	return ""


static func validate_result(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = data
	return (
		_valid_id(payload.get("result_id"))
		and _valid_id(payload.get("request_id"))
		and typeof(payload.get("session_id")) == TYPE_STRING
		and typeof(payload.get("target_peer_id")) == TYPE_INT
		and typeof(payload.get("accepted")) == TYPE_BOOL
		and typeof(payload.get("product_id")) in [
			TYPE_STRING, TYPE_STRING_NAME
		]
		and not str(payload["product_id"]).is_empty()
		and str(payload["product_id"]).length() <= MAX_ID_LENGTH
		and typeof(payload.get("category")) == TYPE_INT
		and int(payload["category"]) >= 0
		and int(payload["category"]) < ProductCategory.size()
		and typeof(payload.get("quantity")) == TYPE_INT
		and int(payload["quantity"]) >= 0
		and int(payload["quantity"]) <= MAX_QUANTITY
		and typeof(payload.get("total_cost")) == TYPE_INT
		and int(payload["total_cost"]) >= 0
		and typeof(payload.get("expected_wallet")) == TYPE_INT
		and int(payload["expected_wallet"]) >= 0
		and typeof(payload.get("expected_state")) == TYPE_INT
		and int(payload["expected_state"]) >= 0
		and typeof(payload.get("resulting_state")) == TYPE_INT
		and int(payload["resulting_state"]) >= 0
		and typeof(payload.get("message")) == TYPE_STRING
		and str(payload["message"]).length() <= MAX_MESSAGE_LENGTH
	)


static func _valid_id(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_STRING
		and not str(value).is_empty()
		and str(value).length() <= MAX_ID_LENGTH
	)
