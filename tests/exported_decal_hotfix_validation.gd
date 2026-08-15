extends SceneTree

const FEATURE_ASSET_ROOTS: Dictionary = {
	"eyes": "res://art/exported/characters/faces/eyes",
	"mouth": "res://art/exported/characters/faces/mouth",
	"nose": "res://art/exported/characters/faces/noses",
}
const FACIAL_FEATURE_SIZE_LIMIT: int = 512


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	CharacterCustomizationCatalog.refresh_feature_assets()
	assert(CharacterCustomizationCatalog._feature_textures.is_empty())
	assert(
		CharacterCustomizationCatalog._canonical_feature_filename(
			"eyes_alligator_eyes.png"
		) == "eyes_alligator_eyes.png"
	)
	assert(
		CharacterCustomizationCatalog._canonical_feature_filename(
			"eyes_alligator_eyes.png.import"
		) == "eyes_alligator_eyes.png"
	)
	assert(
		CharacterCustomizationCatalog._canonical_feature_filename(
			"eyes_alligator_eyes.png.remap"
		) == "eyes_alligator_eyes.png"
	)
	assert(
		CharacterCustomizationCatalog._canonical_feature_filename(
			"eyes_alligator_eyes.jpg"
		).is_empty()
	)

	var load_candidates: Array[Dictionary] = []
	for category_id: String in FEATURE_ASSET_ROOTS:
		var options := CharacterCustomizationCatalog.options_for(category_id)
		var expected_ids: Dictionary = _feature_ids_on_disk(category_id)
		assert(options.size() == expected_ids.size() + 1)
		var seen_ids: Dictionary = {}
		for option: Dictionary in options:
			var option_id := str(option.get("id", ""))
			assert(not seen_ids.has(option_id))
			seen_ids[option_id] = true
			if option_id != "none":
				var texture_path := (
					CharacterCustomizationCatalog.feature_texture_path(
						category_id, option_id
					)
				)
				assert(not texture_path.is_empty())
				assert(ResourceLoader.exists(texture_path, "Texture2D"))
				_validate_feature_import(texture_path)
				load_candidates.append({
					"category_id": category_id,
					"option_id": option_id,
				})
		for expected_id: String in expected_ids:
			assert(seen_ids.has(expected_id))
	assert(CharacterCustomizationCatalog._feature_textures.is_empty())
	assert(
		load_candidates.size()
		> CharacterCustomizationCatalog.FEATURE_TEXTURE_CACHE_LIMIT
	)
	for candidate_index: int in range(
		CharacterCustomizationCatalog.FEATURE_TEXTURE_CACHE_LIMIT + 1
	):
		var candidate: Dictionary = load_candidates[candidate_index]
		assert(CharacterCustomizationCatalog.texture_for(
			str(candidate["category_id"]),
			str(candidate["option_id"]),
		) != null)
	assert(
		CharacterCustomizationCatalog._feature_textures.size()
		== CharacterCustomizationCatalog.FEATURE_TEXTURE_CACHE_LIMIT
	)
	for mouth_id: String in ["open_ah", "open_oh", "open_smile"]:
		assert(CharacterCustomizationCatalog.texture_for(
			"mouth", mouth_id
		) != null)
	assert(
		CharacterCustomizationCatalog._feature_textures.size()
		<= CharacterCustomizationCatalog.FEATURE_TEXTURE_CACHE_LIMIT
	)

	_validate_linux_arm64_texture_format()
	await _validate_incremental_profile_previews()

	print("Exported decal hotfix validation: PASS")
	quit()


func _validate_feature_import(texture_path: String) -> void:
	var import_config := ConfigFile.new()
	assert(import_config.load(texture_path + ".import") == OK)
	assert(int(import_config.get_value("params", "compress/mode", -1)) == 2)
	assert(not bool(import_config.get_value(
		"params", "mipmaps/generate", true
	)))
	assert(int(import_config.get_value(
		"params", "process/size_limit", 0
	)) == FACIAL_FEATURE_SIZE_LIMIT)
	assert(int(import_config.get_value(
		"params", "detect_3d/compress_to", -1
	)) == 0)


func _validate_linux_arm64_texture_format() -> void:
	var export_config := ConfigFile.new()
	assert(export_config.load("res://export_presets.cfg") == OK)
	assert(not bool(export_config.get_value(
		"preset.3.options", "texture_format/s3tc_bptc", true
	)))
	assert(bool(export_config.get_value(
		"preset.3.options", "texture_format/etc2_astc", false
	)))


func _validate_incremental_profile_previews() -> void:
	var profile_page := ProfilePage.new()
	root.add_child(profile_page)
	await process_frame
	for category_id: String in CharacterCustomizationCatalog.FEATURE_CATEGORIES:
		var cached_before: int = (
			(profile_page.get("_feature_preview_cache") as Dictionary).size()
		)
		profile_page.call("_select_category", category_id)
		var initial_requests: int = (
			(profile_page.get("_feature_preview_requests") as Array).size()
		)
		assert(initial_requests > 3)
		for _frame: int in 4:
			await process_frame
		var cached_after: int = (
			(profile_page.get("_feature_preview_cache") as Dictionary).size()
		)
		assert(cached_after > cached_before)
		assert(cached_after - cached_before < initial_requests)
	profile_page.queue_free()
	for _frame: int in 8:
		await process_frame


func _feature_ids_on_disk(category_id: String) -> Dictionary:
	var result: Dictionary = {}
	var root_path: String = str(FEATURE_ASSET_ROOTS[category_id])
	var directory := DirAccess.open(root_path)
	assert(directory != null)
	for file_name: String in directory.get_files():
		if not file_name.to_lower().ends_with(".png"):
			continue
		var option_id: String = (
			CharacterCustomizationCatalog._feature_id_from_filename(
				category_id, file_name
			)
		)
		if not option_id.is_empty():
			result[option_id] = true
	return result
