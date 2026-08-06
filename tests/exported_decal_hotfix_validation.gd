extends SceneTree


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

	var expected_counts := {"eyes": 22, "mouth": 17, "nose": 17}
	for category_id: String in expected_counts:
		var options := CharacterCustomizationCatalog.options_for(category_id)
		assert(options.size() == int(expected_counts[category_id]) + 1)
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

	print("Exported decal hotfix validation: PASS")
	quit()
