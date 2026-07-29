class_name FishCatch
extends Resource

const FishDataType = preload("res://fish/fish_data.gd")

const MAX_SAFE_WEIGHT_LB: float = 1000000.0
const MAX_SAFE_DISPLAY_SCALE: float = 10000.0
const MAX_SAFE_SALE_VALUE: int = 1000000000
const MAX_SAFE_SEQUENCE: int = 2147483647

@export var fish: FishDataType
@export var fish_id: StringName
@export var catch_id: StringName
@export var catch_sequence: int = 0
@export var weight_lb: float = 0.0
@export var display_scale: float = 1.0
@export var sale_value: int = 0
@export var is_favorited: bool = false


func ensure_identity() -> void:
	if not catch_id.is_empty():
		return
	var random_bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	var identity_suffix: String = random_bytes.hex_encode()
	if identity_suffix.is_empty():
		identity_suffix = "%d:%d:%d" % [
			int(Time.get_unix_time_from_system()),
			Time.get_ticks_usec(),
			get_instance_id(),
		]
	catch_id = StringName(
		"%s:%s" % [fish_id, identity_suffix]
	)


func is_valid() -> bool:
	return (
		fish != null
		and not fish_id.is_empty()
		and not catch_id.is_empty()
		and fish.id == fish_id
		and catch_sequence >= 0
		and catch_sequence < MAX_SAFE_SEQUENCE
		and is_finite(weight_lb)
		and weight_lb > 0.0
		and weight_lb <= MAX_SAFE_WEIGHT_LB
		and is_finite(display_scale)
		and display_scale > 0.0
		and display_scale <= MAX_SAFE_DISPLAY_SCALE
		and sale_value >= 0
		and sale_value <= MAX_SAFE_SALE_VALUE
	)


func to_save_dict() -> Dictionary:
	return {
		"catch_id": String(catch_id),
		"catch_sequence": catch_sequence,
		"fish_id": String(fish_id),
		"weight_lb": weight_lb,
		"display_scale": display_scale,
		"sale_value": sale_value,
		"is_favorited": is_favorited,
	}


func to_network_dict() -> Dictionary:
	return {
		"catch_id": String(catch_id),
		"fish_id": String(fish_id),
		"weight_lb": weight_lb,
		"display_scale": display_scale,
		"sale_value": sale_value,
		"is_favorited": is_favorited,
	}


static func from_save_dict(
	data: Dictionary,
	resolved_fish: FishDataType,
) -> FishCatch:
	if resolved_fish == null:
		return null
	for required_key: String in [
		"catch_id",
		"catch_sequence",
		"fish_id",
		"weight_lb",
		"display_scale",
		"sale_value",
		"is_favorited",
	]:
		if not data.has(required_key):
			return null
	if (
		typeof(data["catch_id"]) not in [TYPE_STRING, TYPE_STRING_NAME]
		or typeof(data["fish_id"]) not in [TYPE_STRING, TYPE_STRING_NAME]
	):
		return null

	var loaded_catch_id: StringName = StringName(str(data["catch_id"]))
	var loaded_fish_id: StringName = StringName(str(data["fish_id"]))
	var loaded_sequence: int = _read_safe_integer(
		data["catch_sequence"],
		-1,
		MAX_SAFE_SEQUENCE
	)
	var loaded_sale_value: int = _read_safe_integer(
		data["sale_value"],
		-1,
		MAX_SAFE_SALE_VALUE
	)
	var loaded_weight: float = _read_safe_float(
		data["weight_lb"],
		0.0,
		MAX_SAFE_WEIGHT_LB
	)
	var loaded_scale: float = _read_safe_float(
		data["display_scale"],
		0.0,
		MAX_SAFE_DISPLAY_SCALE
	)
	var loaded_favorite: Variant = data["is_favorited"]
	if (
		loaded_catch_id.is_empty()
		or loaded_fish_id != resolved_fish.id
		or loaded_sequence <= 0
		or loaded_sequence >= MAX_SAFE_SEQUENCE
		or loaded_sale_value < 0
		or loaded_weight <= 0.0
		or loaded_scale <= 0.0
		or typeof(loaded_favorite) != TYPE_BOOL
	):
		return null

	var fish_catch := FishCatch.new()
	fish_catch.fish = resolved_fish
	fish_catch.fish_id = loaded_fish_id
	fish_catch.catch_id = loaded_catch_id
	fish_catch.catch_sequence = loaded_sequence
	fish_catch.weight_lb = loaded_weight
	fish_catch.display_scale = loaded_scale
	fish_catch.sale_value = loaded_sale_value
	fish_catch.is_favorited = bool(loaded_favorite)
	return fish_catch if fish_catch.is_valid() else null


static func from_network_dict(
	data: Dictionary,
	resolved_fish: FishDataType,
) -> FishCatch:
	if resolved_fish == null:
		return null
	for required_key: String in [
		"catch_id",
		"fish_id",
		"weight_lb",
		"display_scale",
		"sale_value",
	]:
		if not data.has(required_key):
			return null
	var loaded_id := StringName(str(data.get("catch_id", "")))
	var loaded_fish_id := StringName(str(data.get("fish_id", "")))
	var loaded_weight: float = _read_safe_float(
		data.get("weight_lb"), 0.0, MAX_SAFE_WEIGHT_LB
	)
	var loaded_scale: float = _read_safe_float(
		data.get("display_scale"), 0.0, MAX_SAFE_DISPLAY_SCALE
	)
	var loaded_value: int = _read_safe_integer(
		data.get("sale_value"), -1, MAX_SAFE_SALE_VALUE
	)
	if (
		loaded_id.is_empty()
		or loaded_id.length() > 160
		or loaded_fish_id != resolved_fish.id
		or loaded_weight <= 0.0
		or loaded_scale <= 0.0
		or loaded_value < 0
	):
		return null
	var fish_catch := FishCatch.new()
	fish_catch.fish = resolved_fish
	fish_catch.fish_id = loaded_fish_id
	fish_catch.catch_id = loaded_id
	fish_catch.catch_sequence = 0
	fish_catch.weight_lb = loaded_weight
	fish_catch.display_scale = loaded_scale
	fish_catch.sale_value = loaded_value
	fish_catch.is_favorited = false
	return fish_catch if fish_catch.is_valid() else null


static func _read_safe_integer(
	value: Variant,
	invalid_value: int,
	maximum_value: int,
) -> int:
	if typeof(value) == TYPE_INT:
		var integer_value: int = int(value)
		if integer_value >= 0 and integer_value <= maximum_value:
			return integer_value
	elif typeof(value) == TYPE_FLOAT:
		var float_value: float = float(value)
		if (
			is_finite(float_value)
			and float_value >= 0.0
			and float_value <= float(maximum_value)
			and is_equal_approx(float_value, round(float_value))
		):
			return int(round(float_value))
	return invalid_value


static func _read_safe_float(
	value: Variant,
	invalid_value: float,
	maximum_value: float,
) -> float:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return invalid_value
	var float_value: float = float(value)
	if (
		not is_finite(float_value)
		or float_value <= 0.0
		or float_value > maximum_value
	):
		return invalid_value
	return float_value
