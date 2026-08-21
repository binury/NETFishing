class_name WorldLayout
extends RefCounted

const GENERATED: StringName = &"generated_world"
const STARTER_ISLAND: StringName = &"starter_island"


static func is_valid(value: Variant) -> bool:
	if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return false
	var layout := StringName(str(value).strip_edges())
	return layout in [GENERATED, STARTER_ISLAND]


static func normalized(
	value: Variant,
	fallback: StringName = GENERATED,
) -> StringName:
	if not is_valid(value):
		return fallback
	return StringName(str(value).strip_edges())


static func display_name(value: Variant) -> String:
	match normalized(value):
		STARTER_ISLAND:
			return "starter island"
		_:
			return "generated world"
