class_name PlayerVisualPresenter
extends RefCounted

const PlayerScene: PackedScene = preload("res://player/player.tscn")
const RUNTIME_MATERIAL_META: StringName = &"netfishing_runtime_material"
const EAR_MESH_NAMES: Array[String] = [
	"ears_antlers_round",
	"ears_bear",
	"ears_bunny",
	"ears_pointy_long",
	"ears_pointy_short",
	"ears_pointy_wide",
]
const TAIL_MESH_NAMES: Array[String] = [
	"tails_bear",
	"tails_bunny",
	"tails_cat",
	"tails_fox",
	"tails_gator",
	"tails_pointy",
]

static var _feature_uv_aspects: Dictionary = {}


static func feature_uv_aspect(feature_name: String) -> float:
	if _feature_uv_aspects.has(feature_name):
		return float(_feature_uv_aspects[feature_name])
	var visuals := instantiate_visuals()
	var skeleton := visuals.find_child("Skeleton3D", true, false) as Skeleton3D
	var aspects: Array[float] = []
	for head_name: String in ["head_round", "head_pointy"]:
		var mesh_instance := skeleton.get_node_or_null(
			"%s_%s" % [head_name, feature_name]
		) as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var arrays := mesh_instance.mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		if uv.is_empty():
			continue
		var min_uv := Vector2(INF, INF)
		var max_uv := Vector2(-INF, -INF)
		for value: Vector2 in uv:
			min_uv = min_uv.min(value)
			max_uv = max_uv.max(value)
		var size := max_uv - min_uv
		if size.y > 0.001:
			aspects.append(size.x / size.y)
	visuals.free()
	var result := 1.0
	if not aspects.is_empty():
		result = 0.0
		for aspect: float in aspects:
			result += aspect
		result /= aspects.size()
	result = clampf(result, 0.35, 2.5)
	_feature_uv_aspects[feature_name] = result
	return result


static func instantiate_visuals() -> Node3D:
	var source: Player = PlayerScene.instantiate()
	var visuals := source.get_node("Visuals") as Node3D
	var source_rod_attachment: Node = visuals.find_child(
		"FishingRodAttachment", true, false
	)
	var source_rod_parent: Node = null
	var source_rod_index: int = -1
	if source_rod_attachment != null:
		source_rod_parent = source_rod_attachment.get_parent()
		source_rod_index = source_rod_attachment.get_index()
		source_rod_attachment.owner = null
		source_rod_parent.remove_child(source_rod_attachment)
	var presentation := visuals.duplicate(
		Node.DUPLICATE_SIGNALS
		| Node.DUPLICATE_GROUPS
		| Node.DUPLICATE_SCRIPTS
		| Node.DUPLICATE_USE_INSTANTIATION
	) as Node3D
	if source_rod_attachment != null and source_rod_parent != null:
		source_rod_parent.add_child(source_rod_attachment)
		source_rod_parent.move_child(source_rod_attachment, source_rod_index)
	source.free()
	presentation.name = "PlayerVisuals"
	return presentation


static func apply_appearance(
	visuals: Node3D,
	snapshot: Dictionary,
) -> void:
	if not CharacterCustomizationCatalog.validate_snapshot(snapshot):
		return
	# Gameplay and preview deliberately share this presentation seam. Keep all
	# mesh selection here so profile previews and network avatars stay identical.
	var character_scale: float = CharacterCustomizationCatalog.character_scale(
		snapshot.get(
			CharacterCustomizationCatalog.SCALE_CATEGORY_ID,
			CharacterCustomizationCatalog.DEFAULT_CHARACTER_SCALE,
		)
	)
	visuals.scale = Vector3.ONE * character_scale
	var skeleton: Skeleton3D = visuals.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return

	var species_id: String = CharacterCustomizationCatalog.canonical_option_id(
		"species", str(snapshot.get("species", "round"))
	)
	var head_id: String = "head_pointy" if species_id == "pointy" else "head_round"
	var head_ids: Array[String] = ["head_pointy", "head_round"]
	for head_name: String in head_ids:
		var head: Node3D = skeleton.get_node_or_null(head_name) as Node3D
		if head != null:
			head.visible = head_name == head_id
		for feature: String in ["eyes", "mouth", "nose"]:
			var decal: Node3D = skeleton.get_node_or_null(
				"%s_%s" % [head_name, feature]
			) as Node3D
			if decal != null:
				var feature_id := CharacterCustomizationCatalog.canonical_option_id(
					feature, str(snapshot.get(feature, "none"))
				)
				decal.visible = (
					head_name == head_id and feature_id != "none"
				)

	var selected_ears: String = CharacterCustomizationCatalog.canonical_option_id(
		"ears", str(snapshot.get("ears", "none"))
	)
	for ear_name: String in EAR_MESH_NAMES:
		var ears: Node3D = skeleton.get_node_or_null(ear_name) as Node3D
		if ears != null:
			ears.visible = selected_ears == ear_name.trim_prefix("ears_")
	var selected_tail: String = CharacterCustomizationCatalog.canonical_option_id(
		"tail", str(snapshot.get("tail", "none"))
	)
	for tail_name: String in TAIL_MESH_NAMES:
		var tail: Node3D = skeleton.get_node_or_null(tail_name) as Node3D
		if tail != null:
			tail.visible = selected_tail == tail_name.trim_prefix("tails_")

	var fur_color: Color = CharacterCustomizationCatalog.option_color(
		"fur_pattern", str(snapshot.get("fur_pattern", "white"))
	)
	_set_mesh_color(skeleton, "body_arms", fur_color)
	_set_mesh_color(skeleton, "body_main", fur_color)
	_set_mesh_color(skeleton, "head_pointy", fur_color)
	_set_mesh_color(skeleton, "head_round", fur_color)
	for ear_name: String in EAR_MESH_NAMES:
		_set_mesh_color(skeleton, ear_name, fur_color)
	for tail_name: String in TAIL_MESH_NAMES:
		_set_mesh_color(skeleton, tail_name, fur_color)

	var eye_id: String = CharacterCustomizationCatalog.canonical_option_id(
		"eyes", str(snapshot.get("eyes", "simple_shine"))
	)
	var mouth_id: String = CharacterCustomizationCatalog.canonical_option_id(
		"mouth", str(snapshot.get("mouth", "three"))
	)
	var nose_id: String = CharacterCustomizationCatalog.canonical_option_id(
		"nose", str(snapshot.get("nose", "dog_round"))
	)
	_set_feature_texture(
		skeleton,
		"eyes",
		CharacterCustomizationCatalog.texture_for("eyes", eye_id),
	)
	_set_feature_texture(
		skeleton,
		"mouth",
		CharacterCustomizationCatalog.texture_for("mouth", mouth_id),
	)
	_set_feature_texture(
		skeleton,
		"nose",
		CharacterCustomizationCatalog.texture_for("nose", nose_id),
	)


static func _set_feature_texture(
	skeleton: Skeleton3D,
	feature_name: String,
	texture: Texture2D,
) -> void:
	for head_name: String in ["head_pointy", "head_round"]:
		var mesh_instance: MeshInstance3D = skeleton.get_node_or_null(
			"%s_%s" % [head_name, feature_name]
		) as MeshInstance3D
		if texture == null:
			if mesh_instance != null:
				mesh_instance.visible = false
			continue
		var material: StandardMaterial3D = _runtime_material(mesh_instance)
		if material != null:
			# Feature plates are transparent geometry. The exported base model may
			# have no preview texture, so enforce the runtime alpha mode when a
			# drop-in PNG is assigned.
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color.WHITE
			material.albedo_texture = texture


static func _set_mesh_color(
	skeleton: Skeleton3D,
	mesh_name: String,
	color: Color,
) -> void:
	var mesh_instance: MeshInstance3D = skeleton.get_node_or_null(
		mesh_name
	) as MeshInstance3D
	var material: StandardMaterial3D = _runtime_material(mesh_instance)
	if material != null:
		material.albedo_color = color


static func _runtime_material(
	mesh_instance: MeshInstance3D,
) -> StandardMaterial3D:
	if mesh_instance == null or mesh_instance.mesh == null:
		return null
	if mesh_instance.has_meta(RUNTIME_MATERIAL_META):
		var runtime := mesh_instance.material_override as StandardMaterial3D
		_configure_matte_material(runtime)
		return runtime
	var source: StandardMaterial3D = mesh_instance.mesh.surface_get_material(
		0
	) as StandardMaterial3D
	if source == null:
		return null
	var material: StandardMaterial3D = source.duplicate() as StandardMaterial3D
	_configure_matte_material(material)
	mesh_instance.material_override = material
	mesh_instance.set_meta(RUNTIME_MATERIAL_META, true)
	return material


static func _configure_matte_material(material: StandardMaterial3D) -> void:
	if material == null:
		return
	# Character artwork is deliberately graphic and flat. Unshaded rendering
	# keeps the authored fur and facial colors invariant across world weather,
	# time of day, and the isolated Profile preview.
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.metallic = 0.0
	material.metallic_specular = 0.0
	material.roughness = 1.0
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	material.anisotropy_enabled = false
	material.clearcoat_enabled = false
	material.rim_enabled = false
