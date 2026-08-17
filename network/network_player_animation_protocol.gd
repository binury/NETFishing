class_name NetworkPlayerAnimationProtocol
extends RefCounted

const FORMAT_VERSION: int = 1
const MAX_STATE_ID_LENGTH: int = 64
const MAX_ACTION_SEQUENCE: int = 2147483647
const MAX_ACTION_ELAPSED_SECONDS: float = 86400.0

const LOCOMOTION_IDLE: StringName = &"idle"
const LOCOMOTION_WALKING: StringName = &"walking"
const LOCOMOTION_RUNNING: StringName = &"running"
const LOCOMOTION_SNEAKING: StringName = &"sneaking"


static func make_state(
	locomotion_id: StringName,
	grounded: bool,
	action_id: StringName = &"",
	action_sequence: int = 0,
	action_elapsed: float = 0.0,
	action_paused: bool = false,
) -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"locomotion_id": String(locomotion_id),
		"grounded": grounded,
		"action": make_action_state(
			action_id,
			action_sequence,
			action_elapsed,
			action_paused,
		),
	}


static func make_action_state(
	action_id: StringName = &"",
	action_sequence: int = 0,
	action_elapsed: float = 0.0,
	paused: bool = false,
) -> Dictionary:
	return {
		"id": String(action_id),
		"sequence": action_sequence,
		"elapsed": action_elapsed,
		"paused": paused,
	}


static func validate_state(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var state: Dictionary = value
	return (
		typeof(state.get("format_version")) == TYPE_INT
		and int(state["format_version"]) == FORMAT_VERSION
		and valid_state_id(state.get("locomotion_id"), false)
		and typeof(state.get("grounded")) == TYPE_BOOL
		and validate_action_state(state.get("action"))
	)


static func validate_action_state(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var action: Dictionary = value
	if (
		not valid_state_id(action.get("id"), true)
		or typeof(action.get("sequence")) != TYPE_INT
		or typeof(action.get("elapsed")) not in [TYPE_FLOAT, TYPE_INT]
		or typeof(action.get("paused", false)) != TYPE_BOOL
	):
		return false
	var sequence: int = int(action["sequence"])
	var elapsed: float = float(action["elapsed"])
	return (
		sequence >= 0
		and sequence <= MAX_ACTION_SEQUENCE
		and is_finite(elapsed)
		and elapsed >= 0.0
		and elapsed <= MAX_ACTION_ELAPSED_SECONDS
	)


static func valid_state_id(value: Variant, allow_empty: bool) -> bool:
	if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return false
	var state_id: String = str(value)
	if state_id.is_empty():
		return allow_empty
	if state_id.length() > MAX_STATE_ID_LENGTH:
		return false
	for index: int in state_id.length():
		var codepoint: int = state_id.unicode_at(index)
		var valid_character: bool = (
			codepoint >= 97 and codepoint <= 122
			or codepoint >= 48 and codepoint <= 57
			or codepoint == 95
		)
		if not valid_character:
			return false
	return true
