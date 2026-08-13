extends SceneTree

const POLICY := preload("res://main/texture_sampling_policy.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_runtime_policy()
	_validate_repository_files("res://")
	if failures.is_empty():
		print("Texture sampling validation passed.")
		quit(0)
		return
	for failure: String in failures:
		printerr("Texture sampling validation: ", failure)
	quit(1)


func _validate_runtime_policy() -> void:
	var texture_rect := TextureRect.new()
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	POLICY.enforce_node(texture_rect)
	_check(
		texture_rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"CanvasItem policy must replace linear sampling with nearest sampling.",
	)
	texture_rect.free()

	var sprite := Sprite3D.new()
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	POLICY.enforce_node(sprite)
	_check(
		sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST,
		"Sprite3D policy must replace linear sampling with nearest sampling.",
	)
	sprite.free()

	var material := StandardMaterial3D.new()
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var quad := QuadMesh.new()
	quad.material = material
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = quad
	POLICY.enforce_node(mesh_instance)
	_check(
		material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST,
		"3D material policy must replace linear sampling with nearest sampling.",
	)
	mesh_instance.free()


func _validate_repository_files(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		failures.append("Could not scan %s." % path)
		return
	directory.list_dir_begin()
	while true:
		var name := directory.get_next()
		if name.is_empty():
			break
		if name == ".godot" or name == ".git":
			continue
		var child_path := path.path_join(name)
		if directory.current_is_dir():
			_validate_repository_files(child_path)
			continue
		if name.ends_with(".import"):
			_validate_import_file(child_path)
		elif name.ends_with(".gdshader"):
			_validate_shader_file(child_path)
		elif name.ends_with(".tscn") or name.ends_with(".tres"):
			_validate_serialized_resource(child_path)
		elif name.ends_with(".gd") and child_path != get_script().resource_path:
			_validate_script_file(child_path)
	directory.list_dir_end()


func _validate_import_file(path: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	_check(
		"mipmaps/generate=true" not in source,
		"Texture import generates mipmaps: %s" % path,
	)


func _validate_shader_file(path: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	var declaration_start := source.find("uniform sampler")
	while declaration_start >= 0:
		var declaration_end := source.find(";", declaration_start)
		if declaration_end < 0:
			_check(false, "Incomplete sampler declaration in %s." % path)
			return
		var declaration := source.substr(
			declaration_start,
			declaration_end - declaration_start,
		)
		_check(
			"filter_nearest" in declaration,
			"Shader sampler must declare filter_nearest: %s" % path,
		)
		declaration_start = source.find("uniform sampler", declaration_end + 1)


func _validate_serialized_resource(path: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	var uses_3d_filter_enum := false
	for line: String in source.split("\n"):
		if line.begins_with("["):
			uses_3d_filter_enum = (
				("type=\"Sprite3D\"" in line)
				or ("type=\"AnimatedSprite3D\"" in line)
				or ("type=\"StandardMaterial3D\"" in line)
				or ("type=\"ORMMaterial3D\"" in line)
			)
		if not line.begins_with("texture_filter = "):
			continue
		var value := int(line.trim_prefix("texture_filter = "))
		if uses_3d_filter_enum:
			_check(
				value == BaseMaterial3D.TEXTURE_FILTER_NEAREST,
				"3D resource declares non-nearest filtering: %s" % path,
			)
		else:
			_check(
				value == CanvasItem.TEXTURE_FILTER_PARENT_NODE
				or value == CanvasItem.TEXTURE_FILTER_NEAREST,
				"Canvas resource declares non-nearest filtering: %s" % path,
			)


func _validate_script_file(path: String) -> void:
	var source := FileAccess.get_file_as_string(path)
	_check(
		"TEXTURE_FILTER_LINEAR" not in source,
		"Script explicitly requests linear texture filtering: %s" % path,
	)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
