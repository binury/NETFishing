extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	CharacterCustomizationCatalog.refresh_fur_pattern_assets()
	var legacy_snapshot := CharacterCustomizationCatalog.default_snapshot()
	legacy_snapshot[CharacterCustomizationCatalog.FUR_STYLE_ID] = "spots_bengal"
	for added_id: String in [
		CharacterCustomizationCatalog.FUR_STYLE_ARMS_ID,
		CharacterCustomizationCatalog.FUR_STYLE_HEAD_ID,
		CharacterCustomizationCatalog.FUR_STYLE_EARS_ID,
		CharacterCustomizationCatalog.FUR_STYLE_TAIL_ID,
	]:
		legacy_snapshot.erase(added_id)
	var migrated := CharacterCustomizationCatalog.sanitized_snapshot(
		legacy_snapshot
	)
	assert(CharacterCustomizationCatalog.validate_snapshot(migrated))
	for style_field: String in CharacterCustomizationCatalog.FUR_STYLE_IDS:
		assert(migrated[style_field] == "bengal")

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
	var custom_color := Color("2b91c7")
	var custom_color_id := CharacterCustomizationCatalog.custom_fur_color_id(
		custom_color
	)
	assert(custom_color_id == "custom_2b91c7")
	assert(
		CharacterCustomizationCatalog.custom_fur_color_id(
			Color(custom_color.r, custom_color.g, custom_color.b, 0.2)
		)
		== custom_color_id
	)
	for color_field: String in CharacterCustomizationCatalog.FUR_COLOR_IDS:
		assert(CharacterCustomizationCatalog.is_valid_option(
			color_field,
			custom_color_id,
		))
		assert(
			CharacterCustomizationCatalog.option_color(
				color_field, custom_color_id
			).is_equal_approx(custom_color)
		)
	assert(not CharacterCustomizationCatalog.is_valid_option(
		"fur_pattern", "custom_2b91cg"
	))
	assert(not CharacterCustomizationCatalog.is_valid_option(
		"fur_pattern", "custom_2b91c7ff"
	))

	var pattern_ids: Array[String] = []
	for option: Dictionary in CharacterCustomizationCatalog.options_for(
		CharacterCustomizationCatalog.FUR_STYLE_ID
	):
		pattern_ids.append(str(option.get("id", "")))
	assert(pattern_ids == [
		"solid",
		"bengal",
		"calico",
		"fox",
		"paws",
		"stripes",
		"tiger",
		"tummy",
	])

	var patterned := CharacterCustomizationCatalog.default_snapshot()
	patterned["species"] = "round"
	patterned["ears"] = "pointy_short"
	patterned["tail"] = "fox"
	patterned["fur_pattern"] = "orange"
	patterned[CharacterCustomizationCatalog.FUR_STYLE_ID] = "calico"
	patterned[CharacterCustomizationCatalog.FUR_STYLE_ARMS_ID] = "paws"
	patterned[CharacterCustomizationCatalog.FUR_STYLE_HEAD_ID] = "tiger"
	patterned[CharacterCustomizationCatalog.FUR_STYLE_EARS_ID] = "fox"
	patterned[CharacterCustomizationCatalog.FUR_STYLE_TAIL_ID] = "fox"
	patterned["fur_color_2"] = "cream"
	patterned["fur_color_3"] = "brown"
	patterned["fur_color_4"] = "red"
	assert(CharacterCustomizationCatalog.validate_snapshot(patterned))

	_assert_option_ids(
		CharacterCustomizationCatalog.fur_pattern_options_for_field(
			CharacterCustomizationCatalog.FUR_STYLE_ID, patterned
		),
		["solid", "bengal", "calico", "fox", "paws", "stripes", "tiger", "tummy"],
	)
	_assert_option_ids(
		CharacterCustomizationCatalog.fur_pattern_options_for_field(
			CharacterCustomizationCatalog.FUR_STYLE_ARMS_ID, patterned
		),
		["solid", "bengal", "fox", "paws"],
	)
	_assert_option_ids(
		CharacterCustomizationCatalog.fur_pattern_options_for_field(
			CharacterCustomizationCatalog.FUR_STYLE_HEAD_ID, patterned
		),
		["solid", "bengal", "fox", "tiger"],
	)
	_assert_option_ids(
		CharacterCustomizationCatalog.fur_pattern_options_for_field(
			CharacterCustomizationCatalog.FUR_STYLE_EARS_ID, patterned
		),
		["solid", "fox"],
	)
	_assert_option_ids(
		CharacterCustomizationCatalog.fur_pattern_options_for_field(
			CharacterCustomizationCatalog.FUR_STYLE_TAIL_ID, patterned
		),
		["solid", "fox"],
	)
	var pointy_snapshot := patterned.duplicate(true)
	pointy_snapshot["species"] = "pointy"
	_assert_option_ids(
		CharacterCustomizationCatalog.fur_pattern_options_for_field(
			CharacterCustomizationCatalog.FUR_STYLE_HEAD_ID, pointy_snapshot
		),
		["solid", "fox"],
	)
	var no_accessories := patterned.duplicate(true)
	no_accessories["ears"] = "none"
	no_accessories["tail"] = "none"
	_assert_option_ids(
		CharacterCustomizationCatalog.fur_pattern_options_for_field(
			CharacterCustomizationCatalog.FUR_STYLE_EARS_ID, no_accessories
		),
		["solid"],
	)
	_assert_option_ids(
		CharacterCustomizationCatalog.fur_pattern_options_for_field(
			CharacterCustomizationCatalog.FUR_STYLE_TAIL_ID, no_accessories
		),
		["solid"],
	)

	var body_texture := _assert_pattern_texture("calico", "body_main")
	var arms_texture := _assert_pattern_texture("paws", "body_arms")
	var head_texture := _assert_pattern_texture("tiger", "head_round")
	var ears_texture := _assert_pattern_texture("fox", "ears_pointy_short")
	var tail_texture := _assert_pattern_texture("fox", "tails_fox")
	_assert_pattern_texture("tummy", "body_main")
	_assert_pattern_texture("stripes", "body_main")
	_assert_pattern_texture("fox", "head_pointy")

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

	var body_material := _assert_mesh_pattern(
		skeleton, "body_main", body_texture
	)
	var arms_material := _assert_mesh_pattern(
		skeleton, "body_arms", arms_texture
	)
	var head_material := _assert_mesh_pattern(
		skeleton, "head_round", head_texture
	)
	var ears_material := _assert_mesh_pattern(
		skeleton, "ears_pointy_short", ears_texture
	)
	var tail_material := _assert_mesh_pattern(
		skeleton, "tails_fox", tail_texture
	)
	for material: ShaderMaterial in [
		body_material,
		arms_material,
		head_material,
		ears_material,
		tail_material,
	]:
		assert(material.shader == preload("res://player/fur_pattern.gdshader"))
		assert(material.get_shader_parameter("base_color") == Color("c86c36"))
		assert(material.get_shader_parameter("red_zone_color") == Color("e6d39b"))
		assert(material.get_shader_parameter("green_zone_color") == Color("7b4a32"))
		assert(material.get_shader_parameter("blue_zone_color") == Color("a9433f"))

	var recolored := patterned.duplicate(true)
	recolored["fur_color_3"] = "teal"
	PlayerVisualPresenter.apply_appearance(visuals, recolored)
	for material: ShaderMaterial in [
		body_material,
		arms_material,
		head_material,
		ears_material,
		tail_material,
	]:
		assert(material.get_shader_parameter("green_zone_color") == Color("3a8790"))
	assert(
		NetworkProfileProtocol.signature_fields({"appearance": patterned})
		!= NetworkProfileProtocol.signature_fields({"appearance": recolored})
	)
	var other_arms := patterned.duplicate(true)
	other_arms[CharacterCustomizationCatalog.FUR_STYLE_ARMS_ID] = "fox"
	assert(
		NetworkProfileProtocol.signature_fields({"appearance": patterned})
		!= NetworkProfileProtocol.signature_fields({"appearance": other_arms})
	)
	var custom_snapshot := patterned.duplicate(true)
	custom_snapshot["fur_pattern"] = custom_color_id
	assert(CharacterCustomizationCatalog.validate_snapshot(custom_snapshot))
	PlayerVisualPresenter.apply_appearance(visuals, custom_snapshot)
	for material: ShaderMaterial in [
		body_material,
		arms_material,
		head_material,
		ears_material,
		tail_material,
	]:
		assert(
			(material.get_shader_parameter("base_color") as Color).is_equal_approx(
				custom_color
			)
		)
	assert(
		NetworkProfileProtocol.signature_fields({"appearance": patterned})
		!= NetworkProfileProtocol.signature_fields({"appearance": custom_snapshot})
	)

	var solid := CharacterCustomizationCatalog.default_snapshot()
	PlayerVisualPresenter.apply_appearance(visuals, solid)
	assert(body.material_override is StandardMaterial3D)
	await _validate_fur_color_ui(patterned)

	print("Fur pattern validation: PASS")
	visuals.queue_free()
	await process_frame
	quit()


func _validate_fur_color_ui(snapshot: Dictionary) -> void:
	var profile_page := ProfilePage.new()
	profile_page.size = Vector2(1280.0, 720.0)
	root.add_child(profile_page)
	await process_frame
	profile_page.set("_draft_appearance", snapshot.duplicate(true))
	profile_page.call("_select_category", "fur_pattern")
	profile_page.call("_select_fur_section", "colors")
	await process_frame
	await process_frame
	var color_panel := profile_page.find_child(
		"FurColorOptionsPanel", true, false
	) as PanelContainer
	var channel_grid := profile_page.find_child(
		"FurColorChannelGrid", true, false
	) as GridContainer
	var palette_grid := profile_page.find_child(
		"FurPaletteGrid", true, false
	) as GridContainer
	var picker := profile_page.find_child(
		"FurCustomColorPicker", true, false
	) as ColorPickerButton
	var picker_popup := picker.get_popup()
	var picker_control := picker.get_picker()
	assert(color_panel != null and color_panel.size.x > 360.0)
	assert(channel_grid != null and channel_grid.columns == 4)
	assert(channel_grid.get_child_count() == 4)
	assert(palette_grid != null and palette_grid.columns == 10)
	assert(palette_grid.get_child_count() == 30)
	for option_button: Button in palette_grid.get_children():
		assert(
			option_button.custom_minimum_size
			== Vector2.ONE * ProfilePage.FUR_PALETTE_SWATCH_SIZE
		)
	for color_index: int in CharacterCustomizationCatalog.FUR_COLOR_IDS.size():
		var category_id: String = (
			CharacterCustomizationCatalog.FUR_COLOR_IDS[color_index]
		)
		var channel_button := profile_page.find_child(
			"FurColorSlot%d" % (color_index + 1), true, false
		) as Button
		assert(channel_button != null)
		var swatch := channel_button.get_node(
			"ChannelContents/ActiveColorSwatch"
		) as Panel
		var channel_label := channel_button.get_node(
			"ChannelContents/ChannelNumber"
		) as Label
		assert(swatch.size.is_equal_approx(
			Vector2.ONE * ProfilePage.FUR_CHANNEL_SWATCH_SIZE
		))
		assert(swatch.size.y <= channel_label.size.y)
		var swatch_style := swatch.get_theme_stylebox(
			"panel"
		) as StyleBoxFlat
		assert(swatch_style != null)
		assert(
			swatch_style.corner_radius_top_left
			== roundi(ProfilePage.FUR_CHANNEL_SWATCH_SIZE * 0.5)
		)
		assert(swatch_style.bg_color.is_equal_approx(
			CharacterCustomizationCatalog.option_color(
				category_id,
				str(snapshot[category_id]),
			)
		))
	var picker_style := picker.get_theme_stylebox("normal") as StyleBoxFlat
	assert(picker_style != null and picker_style.corner_radius_top_left == 14)
	var picker_window_size: Vector2i = profile_page.get_window().size
	var expected_picker_size := Vector2i(
		mini(
			ProfilePage.FUR_COLOR_PICKER_POPUP_SIZE.x,
			maxi(picker_window_size.x - 32, 420),
		),
		mini(
			ProfilePage.FUR_COLOR_PICKER_POPUP_SIZE.y,
			maxi(picker_window_size.y - 32, 340),
		),
	)
	assert(picker_popup.min_size == expected_picker_size)
	assert(picker_popup.theme.default_font == UtilityPageStyle.TuffyFont)
	var popup_style := picker_popup.get_theme_stylebox(
		"panel"
	) as StyleBoxFlat
	assert(popup_style != null)
	assert(popup_style.bg_color.a == 1.0)
	assert(popup_style.corner_radius_top_left == 20)
	assert(
		picker_control.get_theme_constant("sv_width")
		== mini(
			ProfilePage.FUR_COLOR_PICKER_SV_SIZE.x,
			expected_picker_size.x - 110,
		)
	)
	assert(
		picker_control.get_theme_constant("sv_height")
		== mini(
			ProfilePage.FUR_COLOR_PICKER_SV_SIZE.y,
			expected_picker_size.y - 180,
		)
	)
	assert(not picker_control.edit_alpha)
	assert(not picker_control.edit_intensity)
	var picker_display := picker.get_node("FurCustomColorDisplay") as Panel
	var display_style := picker_display.get_theme_stylebox(
		"panel"
	) as StyleBoxFlat
	assert(display_style != null and display_style.corner_radius_top_left == 11)
	var live_custom_color := Color("2b91c7")
	profile_page.call(
		"_select_custom_fur_color",
		live_custom_color,
		CharacterCustomizationCatalog.FUR_COLOR_IDS[0],
	)
	var first_swatch := profile_page.find_child(
		"FurColorSlot1", true, false
	).get_node("ChannelContents/ActiveColorSwatch") as Panel
	var first_swatch_style := first_swatch.get_theme_stylebox(
		"panel"
	) as StyleBoxFlat
	assert(first_swatch_style.bg_color.is_equal_approx(live_custom_color))
	picker_popup.popup_centered()
	for _frame: int in 2:
		await process_frame
	picker_popup.hide()
	for _frame: int in 3:
		await process_frame
	assert(is_instance_valid(picker))
	assert(picker.is_inside_tree())
	assert(
		profile_page.find_child(
			"FurCustomColorPicker", true, false
		) == picker
	)
	profile_page.free()
	await process_frame


func _assert_option_ids(options: Array, expected: Array[String]) -> void:
	var actual: Array[String] = []
	for option: Dictionary in options:
		actual.append(str(option.get("id", "")))
	assert(actual == expected)


func _assert_pattern_texture(
	pattern_id: String,
	component_id: String,
) -> Texture2D:
	var texture := CharacterCustomizationCatalog.fur_pattern_texture(
		pattern_id, component_id
	)
	assert(texture != null)
	assert(texture.get_width() == 1024)
	assert(texture.get_height() == 1024)
	return texture


func _assert_mesh_pattern(
	skeleton: Skeleton3D,
	mesh_name: String,
	expected_texture: Texture2D,
) -> ShaderMaterial:
	var mesh := skeleton.get_node_or_null(mesh_name) as MeshInstance3D
	assert(mesh != null)
	var material := mesh.material_override as ShaderMaterial
	assert(material != null)
	assert(material.get_shader_parameter("pattern_texture") == expected_texture)
	return material
