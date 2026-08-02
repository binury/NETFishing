class_name SurfaceDrawingProtocol
extends RefCounted

const CAPABILITY: StringName = &"surface_drawing_v2"
const RELIABLE_CHANNEL: int = NetworkProtocol.ITEM_RELIABLE_CHANNEL
const GRID_SIZES: Array[int] = [16, 32, 64, 128]
const DEFAULT_GRID_SIZE: int = 16
const MAX_GRID_SIZE: int = 128
# Compatibility aliases for callers that only need the default dimensions.
const GRID_WIDTH: int = DEFAULT_GRID_SIZE
const GRID_HEIGHT: int = DEFAULT_GRID_SIZE
const CELL_SIZE: float = 0.075
const MAX_ACTIVE_CANVASES: int = 24
const MAX_CANVASES: int = 48
const MAX_SESSION_GRID_CELLS: int = 49152
const MAX_EDITS_PER_REQUEST: int = 16
const MAX_CANVAS_ID_LENGTH: int = 64
const MAX_REQUEST_ID_LENGTH: int = 64
const MAX_STROKE_ID_LENGTH: int = 64
const MAX_SESSION_ID_LENGTH: int = 96
const MAX_COORDINATE: float = 10000.0


static func validate_canvas_request(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	return (
		_valid_common(value)
		and _valid_vector(value.get("origin"))
		and _valid_vector(value.get("normal"))
		and _valid_vector(value.get("tangent"))
		and typeof(value.get("width")) == TYPE_INT
		and int(value["width"]) in GRID_SIZES
		and typeof(value.get("height")) == TYPE_INT
		and int(value["height"]) == int(value["width"])
		and typeof(value.get("cell_size")) in [TYPE_FLOAT, TYPE_INT]
		and is_equal_approx(float(value["cell_size"]), CELL_SIZE)
	)


static func validate_edit_request(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	if (
		not _valid_common(value)
		or typeof(value.get("canvas_id")) != TYPE_STRING
		or str(value["canvas_id"]).is_empty()
		or str(value["canvas_id"]).length() > MAX_CANVAS_ID_LENGTH
		or not _valid_stroke_id(value.get("stroke_id"))
		or typeof(value.get("brush_size")) != TYPE_INT
		or int(value["brush_size"]) < 1
		or int(value["brush_size"]) > 4
		or typeof(value.get("edits")) != TYPE_ARRAY
	):
		return false
	var edits: Array = value["edits"]
	if edits.is_empty() or edits.size() > MAX_EDITS_PER_REQUEST:
		return false
	for edit_value: Variant in edits:
		if not validate_cell_edit(edit_value):
			return false
	return true


static func validate_guide_request(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	return (
		_valid_common(value)
		and _valid_canvas_id(value.get("canvas_id"))
		and typeof(value.get("guide_visible")) == TYPE_BOOL
		and typeof(value.get("finalized")) == TYPE_BOOL
	)


static func validate_undo_request(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	return _valid_common(value) and _valid_stroke_id(value.get("stroke_id"))


static func validate_canvas_state(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	if (
		typeof(value.get("session_id")) != TYPE_STRING
		or str(value["session_id"]).is_empty()
		or str(value["session_id"]).length() > MAX_SESSION_ID_LENGTH
		or typeof(value.get("canvas_id")) != TYPE_STRING
		or str(value["canvas_id"]).is_empty()
		or str(value["canvas_id"]).length() > MAX_CANVAS_ID_LENGTH
		or not _valid_vector(value.get("origin"))
		or not _valid_vector(value.get("normal"))
		or not _valid_vector(value.get("tangent"))
		or typeof(value.get("width")) != TYPE_INT
		or int(value["width"]) not in GRID_SIZES
		or typeof(value.get("height")) != TYPE_INT
		or int(value["height"]) != int(value["width"])
		or typeof(value.get("cell_size")) not in [TYPE_FLOAT, TYPE_INT]
		or not is_equal_approx(float(value["cell_size"]), CELL_SIZE)
		or typeof(value.get("revision")) != TYPE_INT
		or int(value["revision"]) < 0
		or typeof(value.get("guide_visible", true)) != TYPE_BOOL
		or typeof(value.get("finalized", false)) != TYPE_BOOL
		or typeof(value.get("layer", 0)) != TYPE_INT
		or int(value.get("layer", 0)) < 0
		or not NetworkIdentityCrypto.valid_fingerprint(
			value.get("creator_fingerprint")
		)
		or typeof(value.get("cells")) != TYPE_ARRAY
	):
		return false
	var cells: Array = value["cells"]
	var grid_width: int = int(value["width"])
	var grid_height: int = int(value["height"])
	if cells.size() > grid_width * grid_height:
		return false
	for cell_value: Variant in cells:
		if (
			not validate_authoritative_cell(cell_value)
			or int((cell_value as Dictionary)["x"]) >= grid_width
			or int((cell_value as Dictionary)["y"]) >= grid_height
		):
			return false
	return true


static func validate_guide_update(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	return (
		typeof(value.get("session_id")) == TYPE_STRING
		and not str(value["session_id"]).is_empty()
		and str(value["session_id"]).length() <= MAX_SESSION_ID_LENGTH
		and _valid_canvas_id(value.get("canvas_id"))
		and typeof(value.get("revision")) == TYPE_INT
		and int(value["revision"]) >= 1
		and typeof(value.get("guide_visible")) == TYPE_BOOL
		and typeof(value.get("finalized")) == TYPE_BOOL
	)


static func validate_canvas_update(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	if (
		typeof(value.get("session_id")) != TYPE_STRING
		or str(value["session_id"]).is_empty()
		or str(value["session_id"]).length() > MAX_SESSION_ID_LENGTH
		or typeof(value.get("canvas_id")) != TYPE_STRING
		or str(value["canvas_id"]).is_empty()
		or str(value["canvas_id"]).length() > MAX_CANVAS_ID_LENGTH
		or typeof(value.get("revision")) != TYPE_INT
		or int(value["revision"]) < 1
		or typeof(value.get("edits")) != TYPE_ARRAY
	):
		return false
	var edits: Array = value["edits"]
	if edits.is_empty() or edits.size() > MAX_EDITS_PER_REQUEST:
		return false
	for edit_value: Variant in edits:
		if not validate_authoritative_cell(edit_value, true):
			return false
	return true


static func validate_cell_edit(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var value: Dictionary = data
	if (
		typeof(value.get("x")) != TYPE_INT
		or int(value["x"]) < 0
		or int(value["x"]) >= MAX_GRID_SIZE
		or typeof(value.get("y")) != TYPE_INT
		or int(value["y"]) < 0
		or int(value["y"]) >= MAX_GRID_SIZE
		or typeof(value.get("color_id")) not in [TYPE_STRING, TYPE_STRING_NAME]
	):
		return false
	var color_id := StringName(str(value["color_id"]))
	return color_id.is_empty() or SurfaceDrawingPalette.has_color(color_id)


static func validate_authoritative_cell(
	data: Variant,
	allow_erased: bool = false,
) -> bool:
	if not validate_cell_edit(data):
		return false
	var value: Dictionary = data
	var color_id := StringName(str(value["color_id"]))
	if color_id.is_empty():
		return allow_erased and str(value.get("author_fingerprint", "")).is_empty()
	return NetworkIdentityCrypto.valid_fingerprint(
		value.get("author_fingerprint")
	)


static func vector_to_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func array_to_vector(value: Variant) -> Vector3:
	if not _valid_vector(value):
		return Vector3.ZERO
	var array: Array = value
	return Vector3(float(array[0]), float(array[1]), float(array[2]))


static func _valid_common(value: Dictionary) -> bool:
	return (
		typeof(value.get("request_id")) == TYPE_STRING
		and not str(value["request_id"]).is_empty()
		and str(value["request_id"]).length() <= MAX_REQUEST_ID_LENGTH
		and typeof(value.get("session_id")) == TYPE_STRING
		and not str(value["session_id"]).is_empty()
		and str(value["session_id"]).length() <= MAX_SESSION_ID_LENGTH
	)


static func _valid_canvas_id(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_STRING
		and not str(value).is_empty()
		and str(value).length() <= MAX_CANVAS_ID_LENGTH
	)


static func _valid_stroke_id(value: Variant) -> bool:
	return (
		typeof(value) == TYPE_STRING
		and not str(value).is_empty()
		and str(value).length() <= MAX_STROKE_ID_LENGTH
	)


static func _valid_vector(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var array: Array = value
	if array.size() != 3:
		return false
	for component: Variant in array:
		if typeof(component) not in [TYPE_FLOAT, TYPE_INT]:
			return false
		var number: float = float(component)
		if not is_finite(number) or absf(number) > MAX_COORDINATE:
			return false
	return true
