class_name NetworkFishingProtocol
extends RefCounted

const MAX_ID_LENGTH: int = 96
const MAX_EVIDENCE_FISH_IDS: int = 256
const MAX_CAST_DISTANCE: float = 30.0
const MAX_REEL_SPEED: float = 10.0
const MAX_BARRIER_DAMAGE: int = 128
const INPUT_CHANNEL: int = 3
const SNAPSHOT_CHANNEL: int = 4
const INPUT_RATE: float = 1.0 / 30.0
const SNAPSHOT_RATE: float = 1.0 / 20.0

enum Outcome {
	CATCH,
	ESCAPE,
	CANCELLED,
}


static func validate_cast_request(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "Malformed fishing request."
	var payload: Dictionary = data
	for key: String in [
		"request_id",
		"session_id",
		"origin",
		"target",
		"charge",
		"rod_id",
		"reel_speed",
		"barrier_damage",
		"bite_multiplier",
		"rarity_multipliers",
		"discovered_fish_ids",
		"capacity_available",
	]:
		if not payload.has(key):
			return "Malformed fishing request."
	if (
		typeof(payload["request_id"]) != TYPE_STRING
		or typeof(payload["session_id"]) != TYPE_STRING
		or typeof(payload["origin"]) != TYPE_ARRAY
		or typeof(payload["target"]) != TYPE_ARRAY
		or typeof(payload["charge"]) not in [TYPE_FLOAT, TYPE_INT]
		or typeof(payload["rod_id"]) not in [TYPE_STRING, TYPE_STRING_NAME]
		or typeof(payload["reel_speed"]) not in [TYPE_FLOAT, TYPE_INT]
		or typeof(payload["barrier_damage"]) != TYPE_INT
		or typeof(payload["bite_multiplier"]) not in [TYPE_FLOAT, TYPE_INT]
		or typeof(payload["rarity_multipliers"]) != TYPE_ARRAY
		or typeof(payload["discovered_fish_ids"]) != TYPE_ARRAY
		or typeof(payload["capacity_available"]) != TYPE_BOOL
	):
		return "Malformed fishing request."
	if payload.has("bait_id") and typeof(payload["bait_id"]) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return "Malformed fishing request."
	if payload.has("lure_id") and typeof(payload["lure_id"]) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return "Malformed fishing request."
	var request_id: String = payload["request_id"]
	var session_id: String = payload["session_id"]
	var origin: Array = payload["origin"]
	var target: Array = payload["target"]
	var charge: float = float(payload["charge"])
	var reel_speed: float = float(payload["reel_speed"])
	var barrier_damage: int = payload["barrier_damage"]
	var bite_multiplier: float = float(payload["bite_multiplier"])
	var rarity: Array = payload["rarity_multipliers"]
	var discovered: Array = payload["discovered_fish_ids"]
	if (
		request_id.is_empty()
		or request_id.length() > MAX_ID_LENGTH
		or session_id.is_empty()
		or session_id.length() > MAX_ID_LENGTH
		or origin.size() != 3
		or target.size() != 3
		or not _array_is_finite_vector3(origin)
		or not _array_is_finite_vector3(target)
		or not is_finite(charge)
		or charge < 0.0
		or charge > 1.01
		or not is_finite(reel_speed)
		or reel_speed <= 0.0
		or reel_speed > MAX_REEL_SPEED
		or barrier_damage < 1
		or barrier_damage > MAX_BARRIER_DAMAGE
		or not is_finite(bite_multiplier)
		or bite_multiplier < 0.1
		or bite_multiplier > 10.0
		or rarity.size() > 16
		or discovered.size() > MAX_EVIDENCE_FISH_IDS
		or str(payload["rod_id"]).is_empty()
		or str(payload["rod_id"]).length() > 96
		or str(payload.get("lure_id", "")).length() > 96
	):
		return "Fishing request values are outside allowed limits."
	for value: Variant in rarity:
		if (
			typeof(value) not in [TYPE_FLOAT, TYPE_INT]
			or not is_finite(float(value))
			or float(value) < 0.0
			or float(value) > 10.0
		):
			return "Fishing rarity evidence is invalid."
	for value: Variant in discovered:
		if (
			typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]
			or str(value).is_empty()
			or str(value).length() > 96
		):
			return "Fishing discovery evidence is invalid."
	return ""


static func validate_input(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var payload: Dictionary = data
	return (
		typeof(payload.get("attempt_id")) == TYPE_STRING
		and not str(payload["attempt_id"]).is_empty()
		and str(payload["attempt_id"]).length() <= MAX_ID_LENGTH
		and typeof(payload.get("sequence")) == TYPE_INT
		and int(payload["sequence"]) > 0
		and typeof(payload.get("held")) == TYPE_BOOL
		and typeof(payload.get("pressed")) == TYPE_BOOL
	)


static func vector3_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func array_to_vector3(value: Array) -> Vector3:
	if value.size() != 3:
		return Vector3.INF
	return Vector3(float(value[0]), float(value[1]), float(value[2]))


static func _array_is_finite_vector3(value: Array) -> bool:
	for component: Variant in value:
		if (
			typeof(component) not in [TYPE_FLOAT, TYPE_INT]
			or not is_finite(float(component))
		):
			return false
	return true
