extends SceneTree

const FEATURE_ASSET_ROOTS: Dictionary = {
	"eyes": "res://art/exported/characters/faces/eyes",
	"mouth": "res://art/exported/characters/faces/mouth",
	"nose": "res://art/exported/characters/faces/noses",
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
				assert(
					CharacterCustomizationCatalog.texture_for(
						category_id, option_id
					) != null
				)
		for expected_id: String in expected_ids:
			assert(seen_ids.has(expected_id))
	for mouth_id: String in ["open_ah", "open_oh", "open_smile"]:
		assert(CharacterCustomizationCatalog.texture_for(
			"mouth", mouth_id
		) != null)

	print("Exported decal hotfix validation: PASS")
	quit()


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
