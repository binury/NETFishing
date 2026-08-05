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
const FEATURE_FALLBACK_TEXTURES: Dictionary = {
	"eyes": {
		"simple_shine": "res://art/exported/characters/faces/eyes/eyes_simple_shine.png",
		"simple_shine_eyebrows": "res://art/exported/characters/faces/eyes/eyes_simple_shine_eyebrows.png",
	},
	"mouth": {
		"three": "res://art/exported/characters/faces/mouth/mouth_three.png",
	},
	"nose": {
		"dog_round": "res://art/exported/characters/faces/noses/nose_dog_round.png",
	},
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
		var options: Array = []
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

		if options.is_empty():
			for fallback: Dictionary in OPTIONS.get(category_id, []):
				var fallback_id := str(fallback.get("id", ""))
				options.append(fallback.duplicate(true))
				var fallback_path := str(
					(FEATURE_FALLBACK_TEXTURES.get(category_id, {}) as Dictionary).get(
						fallback_id, ""
					)
				)
				if not fallback_path.is_empty():
					var fallback_texture := ResourceLoader.load(
						fallback_path
					) as Texture2D
					if fallback_texture != null:
						textures[fallback_id] = fallback_texture

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
