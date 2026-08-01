class_name NetworkFishShowcaseProtocol
extends RefCounted

const CAPABILITY: StringName = &"fish_showcase_v1"
const RELIABLE_CHANNEL: int = NetworkProtocol.ITEM_RELIABLE_CHANNEL
const MAX_SESSION_ID_LENGTH: int = 96
const MAX_FISH_ID_LENGTH: int = 96
const MAX_WEIGHT_LB: float = 1000.0
const MAX_DISPLAY_SCALE: float = 20.0


static func validate_state(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	for key: String in [
		"session_id",
		"owner_peer_id",
		"visible",
		"fish_id",
		"weight_lb",
		"display_scale",
		"revision",
	]:
		if not value.has(key):
			return false
	if (
		typeof(value["session_id"]) != TYPE_STRING
		or str(value["session_id"]).is_empty()
		or str(value["session_id"]).length() > MAX_SESSION_ID_LENGTH
		or typeof(value["owner_peer_id"]) != TYPE_INT
		or int(value["owner_peer_id"]) <= 0
		or typeof(value["visible"]) != TYPE_BOOL
		or typeof(value["fish_id"]) not in [TYPE_STRING, TYPE_STRING_NAME]
		or str(value["fish_id"]).length() > MAX_FISH_ID_LENGTH
		or typeof(value["weight_lb"]) not in [TYPE_FLOAT, TYPE_INT]
		or not is_finite(float(value["weight_lb"]))
		or typeof(value["display_scale"]) not in [TYPE_FLOAT, TYPE_INT]
		or not is_finite(float(value["display_scale"]))
		or typeof(value["revision"]) != TYPE_INT
		or int(value["revision"]) < 0
	):
		return false
	if bool(value["visible"]):
		return (
			not str(value["fish_id"]).is_empty()
			and float(value["weight_lb"]) > 0.0
			and float(value["weight_lb"]) <= MAX_WEIGHT_LB
			and float(value["display_scale"]) > 0.0
			and float(value["display_scale"]) <= MAX_DISPLAY_SCALE
		)
	return (
		str(value["fish_id"]).is_empty()
		and is_zero_approx(float(value["weight_lb"]))
		and is_zero_approx(float(value["display_scale"]))
	)
