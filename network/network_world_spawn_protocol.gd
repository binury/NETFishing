class_name NetworkWorldSpawnProtocol
extends RefCounted

const CAPABILITY: StringName = &"world_spawn_envelope_v1"
const ENVELOPE_VERSION: int = 1
const RELIABLE_CHANNEL: int = NetworkProtocol.ITEM_RELIABLE_CHANNEL
const SNAPSHOT_CHANNEL: int = 4
const MAX_SESSION_ID_LENGTH: int = 96
const MAX_EVENT_ID_LENGTH: int = 48
const MAX_ENTITY_ID_LENGTH: int = 128
const MAX_TYPE_ID_LENGTH: int = 96
const MAX_ENTITIES_PER_SNAPSHOT: int = 128
## Keeps unreliable movement envelopes below ENet's practical MTU while
## allowing reliable population envelopes to carry a larger initial state.
const SNAPSHOT_ENTITIES_PER_ENVELOPE: int = 4


static func make_envelope(
	session_id: String,
	sequence: int,
	event_id: StringName,
	payload: Dictionary,
) -> Dictionary:
	return {
		"envelope_version": ENVELOPE_VERSION,
		"session_id": session_id,
		"sequence": sequence,
		"event_id": str(event_id),
		"payload": payload.duplicate(true),
	}


static func validate_envelope(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = value
	return (
		typeof(data.get("envelope_version")) == TYPE_INT
		and int(data["envelope_version"]) == ENVELOPE_VERSION
		and typeof(data.get("session_id")) == TYPE_STRING
		and not str(data["session_id"]).is_empty()
		and str(data["session_id"]).length() <= MAX_SESSION_ID_LENGTH
		and typeof(data.get("sequence")) == TYPE_INT
		and int(data["sequence"]) >= 0
		and typeof(data.get("event_id")) == TYPE_STRING
		and not str(data["event_id"]).is_empty()
		and str(data["event_id"]).length() <= MAX_EVENT_ID_LENGTH
		and typeof(data.get("payload")) == TYPE_DICTIONARY
	)


static func validate_entity_state(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = value
	var position: Variant = data.get("position")
	if typeof(position) != TYPE_ARRAY or position.size() != 3:
		return false
	for component: Variant in position:
		if typeof(component) not in [TYPE_FLOAT, TYPE_INT]:
			return false
		if not is_finite(float(component)):
			return false
	return (
		typeof(data.get("entity_id")) == TYPE_STRING
		and not str(data["entity_id"]).is_empty()
		and str(data["entity_id"]).length() <= MAX_ENTITY_ID_LENGTH
		and typeof(data.get("type_id")) == TYPE_STRING
		and not str(data["type_id"]).is_empty()
		and str(data["type_id"]).length() <= MAX_TYPE_ID_LENGTH
		and typeof(data.get("yaw")) in [TYPE_FLOAT, TYPE_INT]
		and is_finite(float(data["yaw"]))
		and typeof(data.get("revision")) == TYPE_INT
		and int(data["revision"]) >= 0
	)


static func vector3_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func array_to_vector3(value: Variant) -> Vector3:
	if typeof(value) != TYPE_ARRAY or value.size() != 3:
		return Vector3(INF, INF, INF)
	for component: Variant in value:
		if typeof(component) not in [TYPE_FLOAT, TYPE_INT]:
			return Vector3(INF, INF, INF)
		if not is_finite(float(component)):
			return Vector3(INF, INF, INF)
	return _array_to_vector3(value)


static func _array_to_vector3(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))
