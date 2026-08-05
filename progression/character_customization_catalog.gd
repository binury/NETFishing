class_name CharacterCustomizationCatalog
extends RefCounted

const CATEGORY_IDS: PackedStringArray = [
	"species",
	"fur_pattern",
	"ears",
	"eyes",
	"nose",
	"mouth",
	"tail",
]

const CATEGORY_LABELS: Dictionary = {
	"species": "head",
	"fur_pattern": "fur color",
	"ears": "ears",
	"eyes": "eyes",
	"nose": "nose",
	"mouth": "mouth",
	"tail": "tail",
}

const OPTIONS: Dictionary = {
	"species": [
		{"id": "round", "label": "round"},
		{"id": "pointy", "label": "pointy"},
	],
	# The serialized field remains `fur_pattern` for save and network
	# compatibility. It holds the initial solid fur-color selection until the
	# authored pattern layer is ready.
	"fur_pattern": [
		{"id": "white", "label": "white", "color": Color("f2f0e8")},
		{"id": "gray", "label": "gray", "color": Color("819398")},
		{"id": "charcoal", "label": "charcoal", "color": Color("34444a")},
		{"id": "brown", "label": "brown", "color": Color("7b4a32")},
		{"id": "orange", "label": "orange", "color": Color("c86c36")},
		{"id": "yellow", "label": "yellow", "color": Color("d8c545")},
		{"id": "green", "label": "green", "color": Color("6f913c")},
		{"id": "teal", "label": "teal", "color": Color("3a8790")},
	],
	"ears": [
		{"id": "none", "label": "none"},
		{"id": "pointy_long", "label": "long"},
		{"id": "pointy_short", "label": "short"},
		{"id": "pointy_wide", "label": "wide"},
	],
	"eyes": [
		{"id": "simple_shine", "label": "simple shine"},
		{
			"id": "simple_shine_eyebrows",
			"label": "simple shine + eyebrows",
		},
	],
	"nose": [{"id": "dog_round", "label": "round"}],
	"mouth": [{"id": "three", "label": "three"}],
	"tail": [{"id": "none", "label": "none"}],
}

const LEGACY_OPTION_ALIASES: Dictionary = {
	"species": {"default": "round"},
	"fur_pattern": {"solid": "white"},
	"ears": {"default": "none"},
	"eyes": {"default": "simple_shine"},
	"nose": {"default": "dog_round"},
	"mouth": {"default": "three"},
}


static func default_snapshot() -> Dictionary:
	return {
		"species": "round",
		"fur_pattern": "white",
		"ears": "none",
		"eyes": "simple_shine",
		"nose": "dog_round",
		"mouth": "three",
		"tail": "none",
	}


static func options_for(category_id: String) -> Array:
	return OPTIONS.get(category_id, [])


static func category_label(category_id: String) -> String:
	return str(CATEGORY_LABELS.get(category_id, category_id))


static func is_valid_option(category_id: String, option_id: String) -> bool:
	option_id = canonical_option_id(category_id, option_id)
	for option: Dictionary in options_for(category_id):
		if str(option.get("id", "")) == option_id:
			return true
	return false


static func canonical_option_id(category_id: String, option_id: String) -> String:
	var aliases: Dictionary = LEGACY_OPTION_ALIASES.get(category_id, {})
	return str(aliases.get(option_id, option_id))


static func option_color(category_id: String, option_id: String) -> Color:
	var canonical_id: String = canonical_option_id(category_id, option_id)
	for option: Dictionary in options_for(category_id):
		if str(option.get("id", "")) == canonical_id:
			return option.get("color", Color.WHITE) as Color
	return Color.WHITE


static func validate_snapshot(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var snapshot: Dictionary = value
	if snapshot.size() != CATEGORY_IDS.size():
		return false
	for category_id: String in CATEGORY_IDS:
		if (
			typeof(snapshot.get(category_id)) != TYPE_STRING
			or not is_valid_option(category_id, str(snapshot[category_id]))
		):
			return false
	return true


static func sanitized_snapshot(value: Variant) -> Dictionary:
	var result := default_snapshot()
	if typeof(value) != TYPE_DICTIONARY:
		return result
	var snapshot: Dictionary = value
	for category_id: String in CATEGORY_IDS:
		var option_id: String = canonical_option_id(
			category_id, str(snapshot.get(category_id, ""))
		)
		if is_valid_option(category_id, option_id):
			result[category_id] = option_id
	return result
