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
	"species": "species",
	"fur_pattern": "fur pattern",
	"ears": "ears",
	"eyes": "eyes",
	"nose": "nose",
	"mouth": "mouth",
	"tail": "tail",
}

const OPTIONS: Dictionary = {
	"species": [{"id": "default", "label": "default"}],
	"fur_pattern": [{"id": "solid", "label": "solid"}],
	"ears": [{"id": "default", "label": "default"}],
	"eyes": [{"id": "default", "label": "default"}],
	"nose": [{"id": "default", "label": "default"}],
	"mouth": [{"id": "default", "label": "default"}],
	"tail": [{"id": "none", "label": "none"}],
}


static func default_snapshot() -> Dictionary:
	return {
		"species": "default",
		"fur_pattern": "solid",
		"ears": "default",
		"eyes": "default",
		"nose": "default",
		"mouth": "default",
		"tail": "none",
	}


static func options_for(category_id: String) -> Array:
	return OPTIONS.get(category_id, [])


static func category_label(category_id: String) -> String:
	return str(CATEGORY_LABELS.get(category_id, category_id))


static func is_valid_option(category_id: String, option_id: String) -> bool:
	for option: Dictionary in options_for(category_id):
		if str(option.get("id", "")) == option_id:
			return true
	return false


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
		var option_id := str(snapshot.get(category_id, ""))
		if is_valid_option(category_id, option_id):
			result[category_id] = option_id
	return result
