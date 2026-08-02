class_name SurfaceDrawingPalette
extends RefCounted

const DEFAULT_COLOR_ID: StringName = &"chalk_white"

# Stable IDs are the network and future progression boundary. New colors may
# be appended without changing drawings created with an older palette.
const COLORS: Array[Dictionary] = [
	{"id": &"chalk_white", "name": "Chalk white", "color": Color("f5eed9")},
	{"id": &"ocean_teal", "name": "Ocean teal", "color": Color("35b9c7")},
	{"id": &"coral", "name": "Coral", "color": Color("ef5b62")},
	{"id": &"sunny", "name": "Sunny", "color": Color("ffd166")},
	{"id": &"leaf", "name": "Leaf", "color": Color("46c878")},
	{"id": &"blue", "name": "Blue", "color": Color("5596f6")},
	{"id": &"violet", "name": "Violet", "color": Color("b176e8")},
	{"id": &"charcoal", "name": "Charcoal", "color": Color("28251f")},
]


static func has_color(color_id: StringName) -> bool:
	return not get_entry(color_id).is_empty()


static func get_entry(color_id: StringName) -> Dictionary:
	for entry: Dictionary in COLORS:
		if StringName(entry.get("id", &"")) == color_id:
			return entry
	return {}


static func get_color(color_id: StringName) -> Color:
	var entry: Dictionary = get_entry(color_id)
	var value: Variant = entry.get("color", Color.WHITE)
	return value if typeof(value) == TYPE_COLOR else Color.WHITE


static func get_display_name(color_id: StringName) -> String:
	return str(get_entry(color_id).get("name", "Unknown"))


static func get_color_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry: Dictionary in COLORS:
		result.append(StringName(entry.get("id", &"")))
	return result


static func filter_unlocked_ids(
	unlocked_ids: Array[StringName],
) -> Array[StringName]:
	var result: Array[StringName] = []
	for color_id: StringName in unlocked_ids:
		if has_color(color_id) and color_id not in result:
			result.append(color_id)
	if result.is_empty():
		result.append(DEFAULT_COLOR_ID)
	return result
