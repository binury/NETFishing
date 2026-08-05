extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var legacy_snapshot: Dictionary = (
		CharacterCustomizationCatalog.default_snapshot()
	)
	legacy_snapshot.erase(CharacterCustomizationCatalog.SCALE_CATEGORY_ID)
	var migrated: Dictionary = (
		CharacterCustomizationCatalog.sanitized_snapshot(legacy_snapshot)
	)
	assert(
		is_equal_approx(
			float(migrated[CharacterCustomizationCatalog.SCALE_CATEGORY_ID]),
			CharacterCustomizationCatalog.DEFAULT_CHARACTER_SCALE,
		)
	)
	assert(CharacterCustomizationCatalog.validate_snapshot(migrated))

	var small_snapshot := migrated.duplicate(true)
	small_snapshot[CharacterCustomizationCatalog.SCALE_CATEGORY_ID] = (
		CharacterCustomizationCatalog.MIN_CHARACTER_SCALE
	)
	assert(CharacterCustomizationCatalog.validate_snapshot(small_snapshot))
	var large_snapshot := migrated.duplicate(true)
	large_snapshot[CharacterCustomizationCatalog.SCALE_CATEGORY_ID] = (
		CharacterCustomizationCatalog.MAX_CHARACTER_SCALE
	)
	assert(CharacterCustomizationCatalog.validate_snapshot(large_snapshot))
	var invalid_snapshot := migrated.duplicate(true)
	invalid_snapshot[CharacterCustomizationCatalog.SCALE_CATEGORY_ID] = 2.0
	assert(not CharacterCustomizationCatalog.validate_snapshot(invalid_snapshot))

	var visuals: Node3D = PlayerVisualPresenter.instantiate_visuals()
	root.add_child(visuals)
	PlayerVisualPresenter.apply_appearance(visuals, large_snapshot)
	assert(visuals.scale.is_equal_approx(
		Vector3.ONE * CharacterCustomizationCatalog.MAX_CHARACTER_SCALE
	))
	var skeleton := visuals.find_child("Skeleton3D", true, false) as Skeleton3D
	assert(skeleton != null)
	var body := skeleton.get_node_or_null("body_main") as MeshInstance3D
	assert(body != null)
	var body_material := body.material_override as StandardMaterial3D
	assert(body_material != null)
	assert(body_material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED)
	assert(is_zero_approx(body_material.metallic))
	assert(is_zero_approx(body_material.metallic_specular))
	assert(is_equal_approx(body_material.roughness, 1.0))
	assert(body_material.diffuse_mode == BaseMaterial3D.DIFFUSE_LAMBERT)
	assert(not body_material.anisotropy_enabled)
	assert(not body_material.clearcoat_enabled)
	assert(not body_material.rim_enabled)

	var signed_small := {"appearance": small_snapshot}
	var signed_large := {"appearance": large_snapshot}
	assert(
		NetworkProfileProtocol.signature_fields(signed_small)
		!= NetworkProfileProtocol.signature_fields(signed_large)
	)

	assert(
		ProfilePreview.calculate_pixelated_grid_size(
			Vector2(260.0, 330.0),
			Vector2(1280.0, 720.0),
			3,
		) == Vector2i(130, 165)
	)
	assert(
		ProfilePreview.calculate_pixelated_grid_size(
			Vector2(260.0, 330.0),
			Vector2(640.0, 480.0),
			3,
		) == Vector2i(65, 83)
	)

	var profile_page := ProfilePage.new()
	root.add_child(profile_page)
	await process_frame
	profile_page.call(
		"_select_category",
		CharacterCustomizationCatalog.SCALE_CATEGORY_ID,
	)
	await process_frame
	var slider := profile_page.find_child(
		"CharacterScaleSlider", true, false
	) as HSlider
	assert(slider != null)
	assert(is_equal_approx(
		float(slider.min_value),
		CharacterCustomizationCatalog.MIN_CHARACTER_SCALE,
	))
	assert(is_equal_approx(
		float(slider.max_value),
		CharacterCustomizationCatalog.MAX_CHARACTER_SCALE,
	))
	slider.value = 1.15
	await process_frame
	var draft: Dictionary = profile_page.get("_draft_appearance")
	assert(is_equal_approx(
		float(draft[CharacterCustomizationCatalog.SCALE_CATEGORY_ID]),
		1.15,
	))

	print("Character scale validation: PASS")
	profile_page.queue_free()
	visuals.queue_free()
	await process_frame
	quit()
