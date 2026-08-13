extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var legacy_snapshot := CharacterCustomizationCatalog.default_snapshot()
	for added_id: String in [
		"fur_style",
		"fur_color_2",
		"fur_color_3",
		"fur_color_4",
	]:
		legacy_snapshot.erase(added_id)
	var migrated := CharacterCustomizationCatalog.sanitized_snapshot(
		legacy_snapshot
	)
	assert(CharacterCustomizationCatalog.validate_snapshot(migrated))
	assert(migrated["fur_style"] == "solid")
	var fur_colors := CharacterCustomizationCatalog.options_for("fur_pattern")
	assert(fur_colors.size() == 30)
	for natural_color_id: String in [
		"ivory",
		"sand",
		"tan",
		"taupe",
		"black",
		"dark_brown",
		"chocolate",
		"chestnut",
		"ginger",
		"sage",
		"forest",
	]:
		assert(CharacterCustomizationCatalog.is_valid_option(
			"fur_pattern",
			natural_color_id,
		))

	var pattern_texture := CharacterCustomizationCatalog.fur_pattern_texture(
		"spots_bengal"
	)
	assert(pattern_texture != null)
	assert(pattern_texture.get_width() == 1024)
	assert(pattern_texture.get_height() == 1024)
	var arm_pattern_texture := CharacterCustomizationCatalog.fur_pattern_texture(
		"spots_bengal",
		"body_arms",
	)
	assert(arm_pattern_texture != null)
	assert(arm_pattern_texture.get_width() == 1024)
	assert(arm_pattern_texture.get_height() == 1024)
	var fox_pattern_texture := CharacterCustomizationCatalog.fur_pattern_texture(
		"fox",
		"body_main",
	)
	assert(fox_pattern_texture != null)
	assert(fox_pattern_texture.get_width() == 1024)
	assert(fox_pattern_texture.get_height() == 1024)
	var fox_arm_pattern_texture := (
		CharacterCustomizationCatalog.fur_pattern_texture(
			"fox", "body_arms"
		)
	)
	assert(fox_arm_pattern_texture != null)
	assert(fox_arm_pattern_texture.get_width() == 1024)
	assert(fox_arm_pattern_texture.get_height() == 1024)
	var bengal_head_texture := (
		CharacterCustomizationCatalog.fur_pattern_texture(
			"spots_bengal", "head_round"
		)
	)
	assert(bengal_head_texture != null)
	assert(bengal_head_texture.get_width() == 1024)
	assert(bengal_head_texture.get_height() == 1024)
	var fox_head_texture := CharacterCustomizationCatalog.fur_pattern_texture(
		"fox", "head_pointy"
	)
	assert(fox_head_texture != null)
	assert(fox_head_texture.get_width() == 1024)
	assert(fox_head_texture.get_height() == 1024)
	var fox_tail_texture := CharacterCustomizationCatalog.fur_pattern_texture(
		"fox", "tails_fox"
	)
	assert(fox_tail_texture != null)
	assert(fox_tail_texture.get_width() == 1024)
	assert(fox_tail_texture.get_height() == 1024)

	var patterned := migrated.duplicate(true)
	patterned["fur_pattern"] = "orange"
	patterned["fur_style"] = "spots_bengal"
	patterned["fur_color_2"] = "cream"
	patterned["fur_color_3"] = "brown"
	patterned["fur_color_4"] = "red"
	assert(CharacterCustomizationCatalog.validate_snapshot(patterned))

	var visuals := PlayerVisualPresenter.instantiate_visuals()
	root.add_child(visuals)
	PlayerVisualPresenter.apply_appearance(visuals, patterned)
	var skeleton := visuals.find_child("Skeleton3D", true, false) as Skeleton3D
	assert(skeleton != null)
	var body := skeleton.get_node_or_null("body_main") as MeshInstance3D
	assert(body != null)
	var body_arrays := body.mesh.surface_get_arrays(0)
	var body_uvs := body_arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	assert(not body_uvs.is_empty())
	var uv_min := Vector2(INF, INF)
	var uv_max := Vector2(-INF, -INF)
	for uv: Vector2 in body_uvs:
		uv_min = uv_min.min(uv)
		uv_max = uv_max.max(uv)
	assert(uv_min.x < 0.05 and uv_min.y < 0.05)
	assert(uv_max.x > 0.95 and uv_max.y > 0.95)
	var material := body.material_override as ShaderMaterial
	assert(material != null)
	assert(material.shader == preload("res://player/fur_pattern.gdshader"))
	assert(material.get_shader_parameter("pattern_texture") == pattern_texture)
	assert(material.get_shader_parameter("base_color") == Color("c86c36"))
	assert(material.get_shader_parameter("red_zone_color") == Color("e6d39b"))
	assert(material.get_shader_parameter("green_zone_color") == Color("7b4a32"))
	assert(material.get_shader_parameter("blue_zone_color") == Color("a9433f"))
	var arms := skeleton.get_node_or_null("body_arms") as MeshInstance3D
	assert(arms != null)
	var arm_material := arms.material_override as ShaderMaterial
	assert(arm_material != null)
	assert(
		arm_material.get_shader_parameter("pattern_texture")
		== arm_pattern_texture
	)
	var round_head := skeleton.get_node_or_null("head_round") as MeshInstance3D
	assert(round_head != null)
	var round_head_material := round_head.material_override as ShaderMaterial
	assert(round_head_material != null)
	assert(
		round_head_material.get_shader_parameter("pattern_texture")
		== bengal_head_texture
	)

	var fox_snapshot := patterned.duplicate(true)
	fox_snapshot["species"] = "pointy"
	fox_snapshot["fur_style"] = "fox"
	fox_snapshot["tail"] = "fox"
	PlayerVisualPresenter.apply_appearance(visuals, fox_snapshot)
	var pointy_head := (
		skeleton.get_node_or_null("head_pointy") as MeshInstance3D
	)
	assert(pointy_head != null)
	var pointy_head_material := pointy_head.material_override as ShaderMaterial
	assert(pointy_head_material != null)
	assert(
		pointy_head_material.get_shader_parameter("pattern_texture")
		== fox_head_texture
	)
	var fox_tail := skeleton.get_node_or_null("tails_fox") as MeshInstance3D
	assert(fox_tail != null)
	var fox_tail_material := fox_tail.material_override as ShaderMaterial
	assert(fox_tail_material != null)
	assert(
		fox_tail_material.get_shader_parameter("pattern_texture")
		== fox_tail_texture
	)

	var recolored := patterned.duplicate(true)
	recolored["fur_color_3"] = "teal"
	assert(
		NetworkProfileProtocol.signature_fields({"appearance": patterned})
		!= NetworkProfileProtocol.signature_fields({"appearance": recolored})
	)

	PlayerVisualPresenter.apply_appearance(visuals, migrated)
	assert(body.material_override is StandardMaterial3D)

	print("Fur pattern validation: PASS")
	visuals.queue_free()
	await process_frame
	quit()
