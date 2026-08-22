class_name SurfaceDrawingCanvas
extends Node3D

const GUIDED_PIXEL_FILL: float = 0.88
const SURFACE_OFFSET: float = 0.012
const LAYER_OFFSET_STEP: float = 0.0002
const SURFACE_SAMPLE_DEPTH: float = 0.45

var canvas_id: String = ""
var grid_width: int = 0
var grid_height: int = 0
var cell_size: float = 0.0
var revision: int = -1
var creator_fingerprint: String = ""
var participant_fingerprints: Array[String] = []

var _surface_origin: Vector3
var _surface_normal: Vector3
var _surface_tangent: Vector3
var _surface_bitangent: Vector3
var _cells: Dictionary[int, Dictionary] = {}
var _cell_surface_transforms: Array[Transform3D] = []
var _pixel_image: Image
var _pixel_texture: ImageTexture
var _pixel_instance: MeshInstance3D
var _grid_instance: MeshInstance3D
var _guide_visible: bool = true
var _finalized: bool = false
var _layer: int = 0
var _stencil_requested_visible: bool = false
var _relationships: PlayerRelationshipStore
var _solid_surface_mask: int = 1


func setup(
	data: Dictionary,
	relationships: PlayerRelationshipStore,
	solid_surface_mask: int = 1,
) -> bool:
	if not SurfaceDrawingProtocol.validate_canvas_state(data):
		return false
	canvas_id = str(data["canvas_id"])
	grid_width = int(data["width"])
	grid_height = int(data["height"])
	cell_size = float(data["cell_size"])
	revision = int(data["revision"])
	creator_fingerprint = str(data["creator_fingerprint"])
	participant_fingerprints = _participants_from_state(data)
	_finalized = bool(data.get("finalized", false))
	_guide_visible = bool(data.get("guide_visible", true)) and not _finalized
	_layer = int(data.get("layer", 0))
	_surface_origin = SurfaceDrawingProtocol.array_to_vector(data["origin"])
	_surface_normal = SurfaceDrawingProtocol.array_to_vector(
		data["normal"]
	).normalized()
	_surface_tangent = SurfaceDrawingProtocol.array_to_vector(
		data["tangent"]
	)
	_surface_tangent = (
		_surface_tangent - _surface_normal * _surface_tangent.dot(_surface_normal)
	).normalized()
	if _surface_normal.is_zero_approx() or _surface_tangent.is_zero_approx():
		return false
	_surface_bitangent = _surface_normal.cross(_surface_tangent).normalized()
	_relationships = relationships
	_solid_surface_mask = solid_surface_mask
	_cells.clear()
	for cell_value: Variant in data["cells"]:
		var cell: Dictionary = cell_value
		_cells[_cell_key(int(cell["x"]), int(cell["y"]))] = cell.duplicate(true)
	_build_grid()
	_build_pixel_renderer()
	return true


func apply_update(data: Dictionary) -> bool:
	if (
		not SurfaceDrawingProtocol.validate_canvas_update(data)
		or str(data["canvas_id"]) != canvas_id
		or int(data["revision"]) <= revision
	):
		return false
	for edit_value: Variant in data["edits"]:
		var edit: Dictionary = edit_value
		var key: int = _cell_key(int(edit["x"]), int(edit["y"]))
		if str(edit["color_id"]).is_empty():
			_cells.erase(key)
		else:
			_cells[key] = edit.duplicate(true)
	participant_fingerprints = _participants_from_update(
		data, participant_fingerprints
	)
	revision = int(data["revision"])
	if is_hidden_by_relationship():
		_rebuild_pixel_image()
	else:
		_apply_pixel_edits(data["edits"])
	_refresh_grid_visibility()
	return true


func apply_guide_update(data: Dictionary) -> bool:
	if (
		not SurfaceDrawingProtocol.validate_guide_update(data)
		or str(data["canvas_id"]) != canvas_id
		or int(data["revision"]) <= revision
	):
		return false
	revision = int(data["revision"])
	participant_fingerprints = _participants_from_update(
		data, participant_fingerprints
	)
	_finalized = bool(data["finalized"])
	_guide_visible = bool(data["guide_visible"]) and not _finalized
	if _finalized:
		_destroy_grid()
	else:
		_refresh_grid_visibility()
	return true


func refresh_relationship_visibility() -> void:
	_rebuild_pixel_image()
	if _pixel_instance != null:
		_pixel_instance.visible = not is_hidden_by_relationship()
	_refresh_grid_visibility()


func is_hidden_by_relationship() -> bool:
	if _relationships == null:
		return false
	for fingerprint: String in participant_fingerprints:
		if _relationships.is_blocked(fingerprint):
			return true
	return false


func set_stencil_visible(should_be_visible: bool) -> void:
	_stencil_requested_visible = should_be_visible
	_refresh_grid_visibility()


func is_guide_visible() -> bool:
	return _guide_visible


func is_finalized() -> bool:
	return _finalized


func get_rendered_pixel_size() -> float:
	return cell_size


func get_rendered_pixel_count() -> int:
	if is_hidden_by_relationship():
		return 0
	var count: int = 0
	for cell: Dictionary in _cells.values():
		if not _visible_cell_color(cell).is_equal_approx(Color.TRANSPARENT):
			count += 1
	return count


func get_export_image() -> Image:
	if _pixel_image == null or _pixel_image.is_empty():
		return null
	return _pixel_image.duplicate() as Image


func has_guide_geometry() -> bool:
	return _grid_instance != null and is_instance_valid(_grid_instance)


func contains_world_point(world_point: Vector3, tolerance: float = 0.3) -> bool:
	var relative: Vector3 = world_point - _surface_origin
	if absf(relative.dot(_surface_normal)) > tolerance:
		return false
	var half_width: float = float(grid_width) * cell_size * 0.5
	var half_height: float = float(grid_height) * cell_size * 0.5
	var horizontal: float = relative.dot(_surface_tangent)
	var vertical: float = relative.dot(_surface_bitangent)
	return (
		horizontal >= -half_width
		and horizontal < half_width
		and vertical >= -half_height
		and vertical < half_height
	)


func get_surface_plane_distance(world_point: Vector3) -> float:
	return absf((world_point - _surface_origin).dot(_surface_normal))


func cell_at_world_point(world_point: Vector3) -> Vector2i:
	var relative: Vector3 = world_point - _surface_origin
	var half_width: float = float(grid_width) * cell_size * 0.5
	var half_height: float = float(grid_height) * cell_size * 0.5
	var x: int = floori(
		(relative.dot(_surface_tangent) + half_width) / cell_size
	)
	var y: int = floori(
		(relative.dot(_surface_bitangent) + half_height) / cell_size
	)
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		return Vector2i(-1, -1)
	return Vector2i(x, y)


func get_cell_world_position(x: int, y: int) -> Vector3:
	var horizontal: float = (
		(float(x) + 0.5 - float(grid_width) * 0.5) * cell_size
	)
	var vertical: float = (
		(float(y) + 0.5 - float(grid_height) * 0.5) * cell_size
	)
	return (
		_surface_origin
		+ _surface_tangent * horizontal
		+ _surface_bitangent * vertical
	)


func get_surface_normal() -> Vector3:
	return _surface_normal


func get_surface_tangent() -> Vector3:
	return _surface_tangent


func get_surface_bitangent() -> Vector3:
	return _surface_bitangent


func get_cell_surface_transform(
	x: int,
	y: int,
	fill: float = 0.94,
) -> Transform3D:
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		return Transform3D.IDENTITY
	var key: int = _cell_key(x, y)
	var local_transform: Transform3D = (
		_cell_surface_transforms[key]
		if key >= 0 and key < _cell_surface_transforms.size()
		else _sample_cell_transform(x, y, 1.0)
	)
	var scaled_basis: Basis = local_transform.basis
	var resolved_fill: float = clampf(fill, 0.05, 1.0)
	scaled_basis.x *= resolved_fill
	scaled_basis.y *= resolved_fill
	local_transform.basis = scaled_basis
	return global_transform * local_transform


func get_authoritative_cells() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Dictionary in _cells.values():
		result.append(value.duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_key: int = _cell_key(int(a["x"]), int(a["y"]))
		var b_key: int = _cell_key(int(b["x"]), int(b["y"]))
		return a_key < b_key
	)
	return result


func _build_grid() -> void:
	if _grid_instance != null:
		_grid_instance.queue_free()
		_grid_instance = null
	if _finalized:
		return
	var immediate := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.75, 0.94, 0.96, 0.38)
	material.no_depth_test = false
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var half_width: float = float(grid_width) * cell_size * 0.5
	var half_height: float = float(grid_height) * cell_size * 0.5
	var sampled_vertices: Dictionary[Vector2i, Dictionary] = {}
	for x: int in range(grid_width + 1):
		var horizontal: float = -half_width + float(x) * cell_size
		for y_segment: int in range(grid_height):
			var start_vertical: float = (
				-half_height + float(y_segment) * cell_size
			)
			_add_grid_vertex(
				immediate,
				_surface_origin + _surface_tangent * horizontal
					+ _surface_bitangent * start_vertical,
				Vector2i(x, y_segment),
				sampled_vertices,
			)
			_add_grid_vertex(
				immediate,
				_surface_origin + _surface_tangent * horizontal
					+ _surface_bitangent * (start_vertical + cell_size),
				Vector2i(x, y_segment + 1),
				sampled_vertices,
			)
	for y: int in range(grid_height + 1):
		var vertical: float = -half_height + float(y) * cell_size
		for x_segment: int in range(grid_width):
			var start_horizontal: float = (
				-half_width + float(x_segment) * cell_size
			)
			_add_grid_vertex(
				immediate,
				_surface_origin + _surface_tangent * start_horizontal
					+ _surface_bitangent * vertical,
				Vector2i(x_segment, y),
				sampled_vertices,
			)
			_add_grid_vertex(
				immediate,
				_surface_origin
					+ _surface_tangent * (start_horizontal + cell_size)
					+ _surface_bitangent * vertical,
				Vector2i(x_segment + 1, y),
				sampled_vertices,
			)
	immediate.surface_end()
	_grid_instance = MeshInstance3D.new()
	_grid_instance.name = "PixelGrid"
	_grid_instance.mesh = immediate
	_grid_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid_instance)
	_refresh_grid_visibility()


func _add_grid_vertex(
	immediate: ImmediateMesh,
	world_point: Vector3,
	grid_point: Vector2i,
	sampled_vertices: Dictionary[Vector2i, Dictionary],
) -> void:
	var sampled: Dictionary = sampled_vertices.get(grid_point, {})
	if sampled.is_empty():
		sampled = _sample_surface(world_point)
		sampled_vertices[grid_point] = sampled
	var point: Vector3 = sampled["position"]
	var normal: Vector3 = sampled["normal"]
	immediate.surface_add_vertex(
		to_local(point + normal * (_surface_offset() * 1.5))
	)


func _build_pixel_renderer() -> void:
	if _pixel_instance != null:
		_pixel_instance.queue_free()
		_pixel_instance = null
	var cell_count: int = grid_width * grid_height
	var vertices := PackedVector3Array()
	var texture_coordinates := PackedVector2Array()
	var indices := PackedInt32Array()
	vertices.resize(cell_count * 4)
	texture_coordinates.resize(cell_count * 4)
	indices.resize(cell_count * 6)
	_cell_surface_transforms.clear()
	_cell_surface_transforms.resize(cell_count)
	for y: int in range(grid_height):
		for x: int in range(grid_width):
			var cell_index: int = _cell_key(x, y)
			var surface_transform := _sample_cell_transform(x, y, 1.0)
			_cell_surface_transforms[cell_index] = surface_transform
			var center: Vector3 = surface_transform.origin
			var horizontal: Vector3 = surface_transform.basis.x * 0.5
			var vertical: Vector3 = surface_transform.basis.y * 0.5
			var vertex_offset: int = cell_index * 4
			vertices[vertex_offset] = center - horizontal - vertical
			vertices[vertex_offset + 1] = center + horizontal - vertical
			vertices[vertex_offset + 2] = center + horizontal + vertical
			vertices[vertex_offset + 3] = center - horizontal + vertical
			var image_row: int = _image_y(y)
			var u_min: float = float(x) / float(grid_width)
			var u_max: float = float(x + 1) / float(grid_width)
			var v_min: float = float(image_row) / float(grid_height)
			var v_max: float = float(image_row + 1) / float(grid_height)
			texture_coordinates[vertex_offset] = Vector2(u_min, v_max)
			texture_coordinates[vertex_offset + 1] = Vector2(u_max, v_max)
			texture_coordinates[vertex_offset + 2] = Vector2(u_max, v_min)
			texture_coordinates[vertex_offset + 3] = Vector2(u_min, v_min)
			var index_offset: int = cell_index * 6
			indices[index_offset] = vertex_offset
			indices[index_offset + 1] = vertex_offset + 1
			indices[index_offset + 2] = vertex_offset + 2
			indices[index_offset + 3] = vertex_offset
			indices[index_offset + 4] = vertex_offset + 2
			indices[index_offset + 5] = vertex_offset + 3
	_rebuild_pixel_image()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = texture_coordinates
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color.WHITE
	material.albedo_texture = _pixel_texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	_pixel_instance = MeshInstance3D.new()
	_pixel_instance.name = "ArtworkTexture"
	_pixel_instance.mesh = mesh
	_pixel_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pixel_instance)
	_pixel_instance.visible = not is_hidden_by_relationship()


func _rebuild_pixel_image() -> void:
	if (
		_pixel_image == null
		or _pixel_image.get_width() != grid_width
		or _pixel_image.get_height() != grid_height
	):
		_pixel_image = Image.create(
			grid_width, grid_height, false, Image.FORMAT_RGBA8
		)
	_pixel_image.fill(Color.TRANSPARENT)
	if not is_hidden_by_relationship():
		for cell: Dictionary in _cells.values():
			_set_image_cell(int(cell["x"]), int(cell["y"]), cell)
	if _pixel_texture == null:
		_pixel_texture = ImageTexture.create_from_image(_pixel_image)
	else:
		_pixel_texture.update(_pixel_image)


func _apply_pixel_edits(edits: Array) -> void:
	if _pixel_image == null or _pixel_texture == null:
		_rebuild_pixel_image()
		return
	for edit_value: Variant in edits:
		var edit: Dictionary = edit_value
		var x: int = int(edit["x"])
		var y: int = int(edit["y"])
		var cell: Dictionary = _cells.get(_cell_key(x, y), {})
		_set_image_cell(x, y, cell)
	_pixel_texture.update(_pixel_image)


func _set_image_cell(x: int, y: int, cell: Dictionary) -> void:
	if (
		_pixel_image == null
		or x < 0
		or x >= grid_width
		or y < 0
		or y >= grid_height
	):
		return
	_pixel_image.set_pixel(x, _image_y(y), _visible_cell_color(cell))


func _visible_cell_color(cell: Dictionary) -> Color:
	if cell.is_empty():
		return Color.TRANSPARENT
	var color_id := StringName(str(cell.get("color_id", "")))
	return (
		SurfaceDrawingPalette.get_color(color_id)
		if SurfaceDrawingPalette.has_color(color_id)
		else Color.TRANSPARENT
	)


func _image_y(cell_y: int) -> int:
	return grid_height - 1 - cell_y


func _sample_cell_transform(
	x: int,
	y: int,
	fill: float = GUIDED_PIXEL_FILL,
) -> Transform3D:
	var expected: Vector3 = get_cell_world_position(x, y)
	var sampled: Dictionary = _sample_surface(expected)
	var point: Vector3 = sampled["position"]
	var normal: Vector3 = sampled["normal"]
	var tangent: Vector3 = (
		_surface_tangent - normal * _surface_tangent.dot(normal)
	).normalized()
	if tangent.is_zero_approx():
		tangent = normal.cross(Vector3.UP).normalized()
	if tangent.is_zero_approx():
		tangent = Vector3.RIGHT
	var bitangent: Vector3 = normal.cross(tangent).normalized()
	var pixel_size: float = cell_size * clampf(fill, 0.05, 1.0)
	var cell_basis := Basis(
		tangent * pixel_size,
		bitangent * pixel_size,
		normal,
	)
	return Transform3D(
		cell_basis,
		to_local(point + normal * _surface_offset()),
	)


func _sample_surface(expected: Vector3) -> Dictionary:
	var point: Vector3 = expected
	var normal: Vector3 = _surface_normal
	var world: World3D = get_world_3d()
	if world != null:
		var query := PhysicsRayQueryParameters3D.create(
			expected + _surface_normal * SURFACE_SAMPLE_DEPTH,
			expected - _surface_normal * SURFACE_SAMPLE_DEPTH,
			_solid_surface_mask,
		)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit: Dictionary = world.direct_space_state.intersect_ray(query)
		if (
			not hit.is_empty()
			and hit.get("collider") is StaticBody3D
		):
			var hit_normal: Vector3 = hit.get("normal", _surface_normal)
			if hit_normal.dot(_surface_normal) >= 0.35:
				var hit_position: Vector3 = hit.get("position", expected)
				point = hit_position
				normal = hit_normal.normalized()
	return {"position": point, "normal": normal}


func _surface_offset() -> float:
	return SURFACE_OFFSET + float(_layer) * LAYER_OFFSET_STEP


func _destroy_grid() -> void:
	if _grid_instance == null:
		return
	_grid_instance.queue_free()
	_grid_instance = null


func _refresh_grid_visibility() -> void:
	if _grid_instance != null:
		_grid_instance.visible = (
			_stencil_requested_visible
			and _guide_visible
			and not is_hidden_by_relationship()
		)


func _participants_from_state(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	_append_participant(result, str(data.get("creator_fingerprint", "")))
	for value: Variant in data.get("participant_fingerprints", []):
		_append_participant(result, str(value))
	for cell_value: Variant in data.get("cells", []):
		var cell: Dictionary = cell_value
		_append_participant(
			result, str(cell.get("author_fingerprint", ""))
		)
	return result


func _participants_from_update(
	data: Dictionary,
	fallback: Array[String],
) -> Array[String]:
	var result: Array[String] = fallback.duplicate()
	for value: Variant in data.get("participant_fingerprints", []):
		_append_participant(result, str(value))
	for edit_value: Variant in data.get("edits", []):
		var edit: Dictionary = edit_value
		_append_participant(
			result, str(edit.get("author_fingerprint", ""))
		)
	return result


func _append_participant(result: Array[String], fingerprint: String) -> void:
	if (
		NetworkIdentityCrypto.valid_fingerprint(fingerprint)
		and fingerprint not in result
	):
		result.append(fingerprint)


func _cell_key(x: int, y: int) -> int:
	return y * grid_width + x
