class_name AnimaleseVoiceProfiles
extends RefCounted

const DEFAULT_ID: String = "natural"
const DEFAULT_SAMPLE_SET_ID: String = "robot"
const DEFAULT_SPEED_ID: String = "normal"
const DEFAULT_CALL_ID: String = "meow"
const CALL_AUDIO_DIRECTORY: String = "res://sound/dialogue/calls"
const SAMPLE_SET_OPTIONS: Array[Dictionary] = [
	{
		"id": "robot",
		"label": "robot",
		"directory": "res://sound/dialogue/animalese/robot",
	},
]
const OPTIONS: Array[Dictionary] = [
	{"id": "tiny", "label": "tiny", "pitch": 1.24},
	{"id": "bright", "label": "bright", "pitch": 1.10},
	{"id": "natural", "label": "natural", "pitch": 1.0},
	{"id": "mellow", "label": "mellow", "pitch": 0.89},
	{"id": "deep", "label": "deep", "pitch": 0.77},
]


static func is_valid_sample_set(sample_set_id: String) -> bool:
	for option: Dictionary in SAMPLE_SET_OPTIONS:
		if str(option.get("id", "")) == sample_set_id:
			return true
	return false


static func sanitized_sample_set_id(sample_set_id: String) -> String:
	return (
		sample_set_id
		if is_valid_sample_set(sample_set_id)
		else DEFAULT_SAMPLE_SET_ID
	)


static func sample_directory_for(sample_set_id: String) -> String:
	var resolved_id := sanitized_sample_set_id(sample_set_id)
	for option: Dictionary in SAMPLE_SET_OPTIONS:
		if str(option.get("id", "")) == resolved_id:
			return str(option.get("directory", ""))
	return ""


const SPEED_OPTIONS: Array[Dictionary] = [
	{"id": "slow", "label": "slow", "characters_per_second": 20.0},
	{"id": "relaxed", "label": "relaxed", "characters_per_second": 24.0},
	{"id": "normal", "label": "normal", "characters_per_second": 28.0},
	{"id": "quick", "label": "quick", "characters_per_second": 34.0},
	{"id": "rapid", "label": "rapid", "characters_per_second": 40.0},
]
const CALL_OPTIONS: Array[Dictionary] = [
	{"id": "meow", "label": "meow"},
	{"id": "bark", "label": "bark"},
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


static func is_valid_call(call_id: String) -> bool:
	for option: Dictionary in CALL_OPTIONS:
		if str(option.get("id", "")) == call_id:
			return true
	return false


static func sanitized_call_id(call_id: String) -> String:
	return call_id if is_valid_call(call_id) else DEFAULT_CALL_ID


static func call_audio_path(call_id: String) -> String:
	return "%s/%s.wav" % [
		CALL_AUDIO_DIRECTORY,
		sanitized_call_id(call_id),
	]
