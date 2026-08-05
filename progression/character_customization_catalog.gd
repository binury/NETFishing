class_name CharacterCustomizationCatalog
extends RefCounted

const CATEGORY_IDS: PackedStringArray = [
	"species",
	"scale",
	"fur_pattern",
	"ears",
	"eyes",
	"nose",
	"mouth",
	"tail",
]

const CATEGORY_LABELS: Dictionary = {
	"species": "head",
	"scale": "size",
	"fur_pattern": "fur color",
	"ears": "ears",
	"eyes": "eyes",
	"nose": "nose",
	"mouth": "mouth",
	"tail": "tail",
}

const SCALE_CATEGORY_ID: String = "scale"
const MIN_CHARACTER_SCALE: float = 0.75
const MAX_CHARACTER_SCALE: float = 1.25
const DEFAULT_CHARACTER_SCALE: float = 1.0
const CHARACTER_SCALE_STEP: float = 0.05

const FEATURE_CATEGORIES: PackedStringArray = ["eyes", "nose", "mouth"]
const FEATURE_ASSET_ROOTS: Dictionary = {
	"eyes": "res://art/exported/characters/faces/eyes",
	"nose": "res://art/exported/characters/faces/noses",
	"mouth": "res://art/exported/characters/faces/mouth",
}
const FEATURE_LABEL_OVERRIDES: Dictionary = {
	"simple_shine": "simple shine",
	"simple_shine_eyebrows": "simple shine + eyebrows",
	"dog_round": "round",
	"three": "three",
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

static var _feature_assets_ready: bool = false
static var _feature_options: Dictionary = {}
static var _feature_textures: Dictionary = {}


static func default_snapshot() -> Dictionary:
	_ensure_feature_assets()
	return {
		"species": "round",
		"scale": DEFAULT_CHARACTER_SCALE,
		"fur_pattern": "white",
		"ears": "none",
		"eyes": _default_feature_option("eyes", "simple_shine"),
		"nose": _default_feature_option("nose", "dog_round"),
		"mouth": _default_feature_option("mouth", "three"),
		"tail": "none",
	}


static func _default_feature_option(
	category_id: String,
	legacy_id: String,
) -> String:
	var options: Array = _feature_options.get(category_id, []) as Array
	for option: Dictionary in options:
		if str(option.get("id", "")) == legacy_id:
			return legacy_id
	for option: Dictionary in options:
		var option_id := str(option.get("id", ""))
		if option_id != "none":
			return option_id
	return "none"


static func options_for(category_id: String) -> Array:
	if category_id in FEATURE_CATEGORIES:
		_ensure_feature_assets()
		return _feature_options.get(category_id, []) as Array
	return OPTIONS.get(category_id, [])


static func texture_for(category_id: String, option_id: String) -> Texture2D:
	if category_id not in FEATURE_CATEGORIES:
		return null
	_ensure_feature_assets()
	var canonical_id := canonical_option_id(category_id, option_id)
	var textures: Dictionary = _feature_textures.get(category_id, {}) as Dictionary
	return textures.get(canonical_id) as Texture2D


static func refresh_feature_assets() -> void:
	_feature_assets_ready = false
	_feature_options.clear()
	_feature_textures.clear()
	_ensure_feature_assets()


static func _ensure_feature_assets() -> void:
	if _feature_assets_ready:
		return
	_feature_assets_ready = true
	for category_id: String in FEATURE_CATEGORIES:
		var options: Array = [{"id": "none", "label": "none"}]
		var textures: Dictionary = {}
		var root_path := str(FEATURE_ASSET_ROOTS[category_id])
		var directory := DirAccess.open(root_path)
		if directory != null:
			var files := directory.get_files()
			files.sort()
			for file_name: String in files:
				if not file_name.to_lower().ends_with(".png"):
					continue
				var option_id := _feature_id_from_filename(
					category_id, file_name
				)
				if option_id.is_empty() or textures.has(option_id):
					continue
				var resource_path := root_path.path_join(file_name)
				var texture := ResourceLoader.load(resource_path) as Texture2D
				if texture == null:
					push_warning(
						"Ignoring facial feature without a loadable texture: "
						+ resource_path
					)
					continue
				textures[option_id] = texture
				options.append({
					"id": option_id,
					"label": _feature_label(option_id),
				})

		_feature_options[category_id] = options
		_feature_textures[category_id] = textures


static func _feature_id_from_filename(
	category_id: String,
	file_name: String,
) -> String:
	var option_id := file_name.get_basename().to_lower()
	var prefix := category_id + "_"
	if option_id.begins_with(prefix):
		option_id = option_id.trim_prefix(prefix)
	option_id = option_id.replace("-", "_")
	option_id = option_id.replace(" ", "_")
	option_id = option_id.replace(".", "_")
	while option_id.contains("__"):
		option_id = option_id.replace("__", "_")
	while option_id.begins_with("_"):
		option_id = option_id.substr(1)
	while option_id.ends_with("_"):
		option_id = option_id.substr(0, option_id.length() - 1)
	return option_id


static func _feature_label(option_id: String) -> String:
	if FEATURE_LABEL_OVERRIDES.has(option_id):
		return str(FEATURE_LABEL_OVERRIDES[option_id])
	return option_id.replace("_", " ")


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
		if category_id == SCALE_CATEGORY_ID:
			if not is_valid_character_scale(snapshot.get(category_id)):
				return false
			continue
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
		if category_id == SCALE_CATEGORY_ID:
			result[category_id] = character_scale(
				snapshot.get(category_id, DEFAULT_CHARACTER_SCALE)
			)
			continue
		var option_id: String = canonical_option_id(
			category_id, str(snapshot.get(category_id, ""))
		)
		if is_valid_option(category_id, option_id):
			result[category_id] = option_id
	return result


static func character_scale(value: Variant) -> float:
	if typeof(value) not in [TYPE_FLOAT, TYPE_INT]:
		return DEFAULT_CHARACTER_SCALE
	var number: float = float(value)
	if not is_finite(number):
		return DEFAULT_CHARACTER_SCALE
	return clampf(
		snappedf(number, CHARACTER_SCALE_STEP),
		MIN_CHARACTER_SCALE,
		MAX_CHARACTER_SCALE,
	)


static func is_valid_character_scale(value: Variant) -> bool:
	if typeof(value) not in [TYPE_FLOAT, TYPE_INT]:
		return false
	var number: float = float(value)
	return (
		is_finite(number)
		and number >= MIN_CHARACTER_SCALE
		and number <= MAX_CHARACTER_SCALE
		and is_equal_approx(number, character_scale(number))
	)


static func character_scale_percent(value: Variant) -> int:
	return roundi(character_scale(value) * 100.0)
