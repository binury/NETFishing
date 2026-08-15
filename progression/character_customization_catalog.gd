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

# CATEGORY_IDS controls the visible Profile navigation. The additional fur
# fields are edited together on the existing fur page, but remain explicit in
# saves and signed multiplayer appearance snapshots.
const SNAPSHOT_IDS: PackedStringArray = [
	"species",
	"scale",
	"fur_pattern",
	"fur_style",
	"fur_color_2",
	"fur_color_3",
	"fur_color_4",
	"ears",
	"eyes",
	"nose",
	"mouth",
	"tail",
]

const CATEGORY_LABELS: Dictionary = {
	"species": "head",
	"scale": "size",
	"fur_pattern": "fur",
	"ears": "ears",
	"eyes": "eyes",
	"nose": "nose",
	"mouth": "mouth",
	"tail": "tail",
}

const SCALE_CATEGORY_ID: String = "scale"
const MIN_CHARACTER_SCALE: float = 0.5
const MAX_CHARACTER_SCALE: float = 1.5
const DEFAULT_CHARACTER_SCALE: float = 1.0
const CHARACTER_SCALE_STEP: float = 0.05
const FUR_STYLE_ID: String = "fur_style"
const FUR_COLOR_IDS: PackedStringArray = [
	"fur_pattern",
	"fur_color_2",
	"fur_color_3",
	"fur_color_4",
]
const FUR_COLOR_LABELS: Dictionary = {
	"fur_pattern": "primary",
	"fur_color_2": "secondary",
	"fur_color_3": "accent",
	"fur_color_4": "detail",
}
const DEFAULT_FUR_STYLE: String = "solid"
const FEATURE_TEXTURE_CACHE_LIMIT: int = 24

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
const FUR_COLOR_OPTIONS: Array = [
	{"id": "white", "label": "white", "color": Color("f2f0e8")},
	{"id": "ivory", "label": "ivory", "color": Color("f0e2c2")},
	{"id": "cream", "label": "cream", "color": Color("e6d39b")},
	{"id": "sand", "label": "sand", "color": Color("c6a66f")},
	{"id": "tan", "label": "tan", "color": Color("ad7c55")},
	{"id": "taupe", "label": "taupe", "color": Color("89756a")},
	{"id": "silver", "label": "silver", "color": Color("b8c3c1")},
	{"id": "gray", "label": "gray", "color": Color("819398")},
	{"id": "slate", "label": "slate", "color": Color("58686c")},
	{"id": "charcoal", "label": "charcoal", "color": Color("34444a")},
	{"id": "black", "label": "black", "color": Color("192126")},
	{"id": "dark_brown", "label": "dark brown", "color": Color("432a25")},
	{"id": "chocolate", "label": "chocolate", "color": Color("603b2c")},
	{"id": "brown", "label": "brown", "color": Color("7b4a32")},
	{"id": "chestnut", "label": "chestnut", "color": Color("98513d")},
	{"id": "ginger", "label": "ginger", "color": Color("d28742")},
	{"id": "orange", "label": "orange", "color": Color("c86c36")},
	{"id": "red", "label": "red", "color": Color("a9433f")},
	{"id": "pink", "label": "pink", "color": Color("d8899e")},
	{"id": "yellow", "label": "yellow", "color": Color("d8c545")},
	{"id": "gold", "label": "gold", "color": Color("c29a3d")},
	{"id": "sage", "label": "sage", "color": Color("8fa16b")},
	{"id": "green", "label": "green", "color": Color("6f913c")},
	{"id": "forest", "label": "forest", "color": Color("3f6945")},
	{"id": "aqua", "label": "aqua", "color": Color("69aeb0")},
	{"id": "teal", "label": "teal", "color": Color("3a8790")},
	{"id": "blue", "label": "blue", "color": Color("4d76a8")},
	{"id": "navy", "label": "navy", "color": Color("344b78")},
	{"id": "lavender", "label": "lavender", "color": Color("9a7eaa")},
	{"id": "purple", "label": "purple", "color": Color("76558f")},
]
const OPTIONS: Dictionary = {
	"species": [
		{"id": "round", "label": "round"},
		{"id": "pointy", "label": "pointy"},
	],
	# `fur_pattern` remains the primary color key for compatibility with
	# existing appearance saves. The actual authored pattern has its own field.
	"fur_pattern": FUR_COLOR_OPTIONS,
	"fur_color_2": FUR_COLOR_OPTIONS,
	"fur_color_3": FUR_COLOR_OPTIONS,
	"fur_color_4": FUR_COLOR_OPTIONS,
	"fur_style": [
		{"id": "solid", "label": "solid"},
		{
			"id": "spots_bengal",
			"label": "bengal spots",
			"textures": {
				"body_main": (
					"res://art/exported/characters/patterns/"
					+ "bengal/body_main_bengal.png"
				),
				"body_arms": (
					"res://art/exported/characters/patterns/"
					+ "bengal/body_arms_bengal.png"
				),
				"head_round": (
					"res://art/exported/characters/patterns/"
					+ "bengal/head_round_bengal.png"
				),
			},
		},
		{
			"id": "fox",
			"label": "fox",
			"textures": {
				"body_main": (
					"res://art/exported/characters/patterns/"
					+ "fox/body_main_fox.png"
				),
				"body_arms": (
					"res://art/exported/characters/patterns/"
					+ "fox/body_arms_fox.png"
				),
				"head_pointy": (
					"res://art/exported/characters/patterns/"
					+ "fox/head_pointy_fox.png"
				),
				"head_round": (
					"res://art/exported/characters/patterns/"
					+ "fox/head_round_fox.png"
				),
				"tails_fox": (
					"res://art/exported/characters/patterns/"
					+ "fox/tails_fox_fox.png"
				),
			},
		},
	],
	"ears": [
		{"id": "none", "label": "none"},
		{"id": "antlers_round", "label": "antlers"},
		{"id": "bear", "label": "bear"},
		{"id": "bunny", "label": "bunny"},
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
	"tail": [
		{"id": "none", "label": "none"},
		{"id": "bear", "label": "bear"},
		{"id": "bunny", "label": "bunny"},
		{"id": "cat", "label": "cat"},
		{"id": "fox", "label": "fox"},
		{"id": "gator", "label": "gator"},
		{"id": "pointy", "label": "pointy"},
	],
}

const LEGACY_OPTION_ALIASES: Dictionary = {
	"species": {"default": "round"},
	"fur_pattern": {"solid": "white"},
	"fur_style": {"bengal": "spots_bengal"},
	"ears": {"default": "none"},
	"tail": {"default": "none"},
	"eyes": {"default": "simple_shine"},
	"nose": {"default": "dog_round"},
	"mouth": {"default": "three"},
}

static var _feature_assets_ready: bool = false
static var _feature_options: Dictionary = {}
static var _feature_resource_paths: Dictionary = {}
static var _feature_textures: Dictionary = {}
static var _feature_texture_cache_order: Array[String] = []
static var _fur_pattern_textures: Dictionary = {}


static func default_snapshot() -> Dictionary:
	_ensure_feature_assets()
	return {
		"species": "round",
		"scale": DEFAULT_CHARACTER_SCALE,
		"fur_pattern": "white",
		"fur_style": DEFAULT_FUR_STYLE,
		"fur_color_2": "cream",
		"fur_color_3": "brown",
		"fur_color_4": "red",
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


static func feature_option_groups(category_id: String) -> Array:
	if category_id not in FEATURE_CATEGORIES:
		return []
	var options: Array = options_for(category_id)
	var option_ids: Array[String] = []
	for option: Dictionary in options:
		option_ids.append(str(option.get("id", "")))
	var grouped_options: Dictionary = {}
	var group_order: Array[String] = []
	for option: Dictionary in options:
		var option_id := str(option.get("id", ""))
		var group_id := _feature_variant_root(option_id, option_ids)
		if not grouped_options.has(group_id):
			grouped_options[group_id] = []
			group_order.append(group_id)
		var group: Array = grouped_options[group_id] as Array
		group.append(option)
		grouped_options[group_id] = group
	var result: Array = []
	for group_id: String in group_order:
		result.append({
			"id": group_id,
			"options": grouped_options[group_id],
		})
	return result


static func _feature_variant_root(
	option_id: String,
	option_ids: Array[String],
) -> String:
	if option_id == "none":
		return option_id
	# Prefer the shortest authored base option. This keeps nested names such as
	# `beady_extra_shine` in the `beady` drawer rather than creating drawers
	# inside drawers.
	var authored_root := ""
	for candidate_id: String in option_ids:
		if candidate_id == "none":
			continue
		if (
			option_id != candidate_id
			and not option_id.begins_with(candidate_id + "_")
		):
			continue
		var has_descendant := false
		for descendant_id: String in option_ids:
			if descendant_id.begins_with(candidate_id + "_"):
				has_descendant = true
				break
		if (
			has_descendant
			and (
				authored_root.is_empty()
				or candidate_id.length() < authored_root.length()
			)
		):
			authored_root = candidate_id
	if not authored_root.is_empty():
		return authored_root

	# Some families have no unqualified base asset. Group those siblings by
	# their leading name segment, making the sorted first asset representative.
	var separator_index := option_id.find("_")
	if separator_index <= 0:
		return option_id
	var leading_segment := option_id.substr(0, separator_index)
	var sibling_count := 0
	for candidate_id: String in option_ids:
		if candidate_id.begins_with(leading_segment + "_"):
			sibling_count += 1
	if sibling_count >= 2:
		return leading_segment
	return option_id


static func texture_for(category_id: String, option_id: String) -> Texture2D:
	if category_id not in FEATURE_CATEGORIES:
		return null
	_ensure_feature_assets()
	var canonical_id := canonical_option_id(category_id, option_id)
	var cache_id := "%s:%s" % [category_id, canonical_id]
	if _feature_textures.has(cache_id):
		_touch_feature_texture(cache_id)
		return _feature_textures[cache_id] as Texture2D
	var resource_path := feature_texture_path(category_id, canonical_id)
	if resource_path.is_empty():
		return null
	var texture := ResourceLoader.load(
		resource_path,
		"Texture2D",
		ResourceLoader.CACHE_MODE_IGNORE,
	) as Texture2D
	if texture == null:
		return null
	_feature_textures[cache_id] = texture
	_touch_feature_texture(cache_id)
	_trim_feature_texture_cache()
	return texture


static func feature_texture_path(category_id: String, option_id: String) -> String:
	if category_id not in FEATURE_CATEGORIES:
		return ""
	_ensure_feature_assets()
	var canonical_id := canonical_option_id(category_id, option_id)
	var paths: Dictionary = (
		_feature_resource_paths.get(category_id, {}) as Dictionary
	)
	return str(paths.get(canonical_id, ""))


static func _touch_feature_texture(cache_id: String) -> void:
	var existing_index := _feature_texture_cache_order.find(cache_id)
	if existing_index >= 0:
		_feature_texture_cache_order.remove_at(existing_index)
	_feature_texture_cache_order.append(cache_id)


static func _trim_feature_texture_cache() -> void:
	while _feature_texture_cache_order.size() > FEATURE_TEXTURE_CACHE_LIMIT:
		var oldest_id: String = str(_feature_texture_cache_order.pop_front())
		_feature_textures.erase(oldest_id)


static func refresh_feature_assets() -> void:
	_feature_assets_ready = false
	_feature_options.clear()
	_feature_resource_paths.clear()
	_feature_textures.clear()
	_feature_texture_cache_order.clear()
	_ensure_feature_assets()


static func _ensure_feature_assets() -> void:
	if _feature_assets_ready:
		return
	_feature_assets_ready = true
	for category_id: String in FEATURE_CATEGORIES:
		var options: Array = [{"id": "none", "label": "none"}]
		var resource_paths: Dictionary = {}
		var root_path := str(FEATURE_ASSET_ROOTS[category_id])
		var directory := DirAccess.open(root_path)
		if directory != null:
			var files := directory.get_files()
			files.sort()
			var normalized_paths: Dictionary = {}
			for file_name: String in files:
				var normalized_file_name := _canonical_feature_filename(file_name)
				if (
					normalized_file_name.is_empty()
					or normalized_paths.has(normalized_file_name)
				):
					continue
				normalized_paths[normalized_file_name] = true
				var option_id := _feature_id_from_filename(
					category_id, normalized_file_name
				)
				if option_id.is_empty() or resource_paths.has(option_id):
					continue
				var resource_path := root_path.path_join(normalized_file_name)
				if not ResourceLoader.exists(resource_path, "Texture2D"):
					push_warning(
						"Ignoring facial feature without a loadable texture: "
						+ resource_path
					)
					continue
				resource_paths[option_id] = resource_path
				options.append({
					"id": option_id,
					"label": _feature_label(option_id),
				})

		_feature_options[category_id] = options
		_feature_resource_paths[category_id] = resource_paths


static func _canonical_feature_filename(file_name: String) -> String:
	var lower_name := file_name.to_lower()
	for sidecar_suffix: String in [".import", ".remap"]:
		if lower_name.ends_with(".png" + sidecar_suffix):
			return file_name.substr(
				0, file_name.length() - sidecar_suffix.length()
			)
	if lower_name.ends_with(".png"):
		return file_name
	return ""


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


static func fur_color_label(category_id: String) -> String:
	return str(FUR_COLOR_LABELS.get(category_id, category_id))


static func fur_pattern_texture(
	option_id: String,
	component_id: String = "body_main",
) -> Texture2D:
	var canonical_id := canonical_option_id(FUR_STYLE_ID, option_id)
	if canonical_id == DEFAULT_FUR_STYLE:
		return null
	var cache_id := "%s:%s" % [canonical_id, component_id]
	if _fur_pattern_textures.has(cache_id):
		return _fur_pattern_textures[cache_id] as Texture2D
	for option: Dictionary in options_for(FUR_STYLE_ID):
		if str(option.get("id", "")) != canonical_id:
			continue
		var textures := option.get("textures", {}) as Dictionary
		var resource_path := str(textures.get(component_id, ""))
		if resource_path.is_empty():
			return null
		var texture := ResourceLoader.load(resource_path) as Texture2D
		if texture != null:
			_fur_pattern_textures[cache_id] = texture
		return texture
	return null


static func validate_snapshot(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var snapshot: Dictionary = value
	if snapshot.size() != SNAPSHOT_IDS.size():
		return false
	for category_id: String in SNAPSHOT_IDS:
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
	for category_id: String in SNAPSHOT_IDS:
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
