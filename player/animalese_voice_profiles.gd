class_name AnimaleseVoiceProfiles
extends RefCounted

const DEFAULT_ID: String = "natural"
const DEFAULT_SPEED_ID: String = "normal"
const OPTIONS: Array[Dictionary] = [
	{"id": "tiny", "label": "tiny", "pitch": 1.24},
	{"id": "bright", "label": "bright", "pitch": 1.10},
	{"id": "natural", "label": "natural", "pitch": 1.0},
	{"id": "mellow", "label": "mellow", "pitch": 0.89},
	{"id": "deep", "label": "deep", "pitch": 0.77},
]
const SPEED_OPTIONS: Array[Dictionary] = [
	{"id": "slow", "label": "slow", "characters_per_second": 20.0},
	{"id": "relaxed", "label": "relaxed", "characters_per_second": 24.0},
	{"id": "normal", "label": "normal", "characters_per_second": 28.0},
	{"id": "quick", "label": "quick", "characters_per_second": 34.0},
	{"id": "rapid", "label": "rapid", "characters_per_second": 40.0},
]


static func is_valid(voice_id: String) -> bool:
	for option: Dictionary in OPTIONS:
		if str(option.get("id", "")) == voice_id:
			return true
	return false


static func sanitized_id(voice_id: String) -> String:
	return voice_id if is_valid(voice_id) else DEFAULT_ID


static func pitch_for(voice_id: String) -> float:
	var resolved_id := sanitized_id(voice_id)
	for option: Dictionary in OPTIONS:
		if str(option.get("id", "")) == resolved_id:
			return float(option.get("pitch", 1.0))
	return 1.0


static func is_valid_speed(speed_id: String) -> bool:
	for option: Dictionary in SPEED_OPTIONS:
		if str(option.get("id", "")) == speed_id:
			return true
	return false


static func sanitized_speed_id(speed_id: String) -> String:
	return speed_id if is_valid_speed(speed_id) else DEFAULT_SPEED_ID


static func speed_for(speed_id: String) -> float:
	var resolved_id := sanitized_speed_id(speed_id)
	for option: Dictionary in SPEED_OPTIONS:
		if str(option.get("id", "")) == resolved_id:
			return float(option.get("characters_per_second", 28.0))
	return 28.0
