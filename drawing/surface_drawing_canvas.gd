class_name SurfaceDrawingCanvas
extends Node3D

const GUIDED_PIXEL_FILL: float = 0.88
const FINISHED_PIXEL_FILL: float = 1.0
const SURFACE_OFFSET: float = 0.012
const LAYER_OFFSET_STEP: float = 0.0002
const SURFACE_SAMPLE_DEPTH: float = 0.45

var canvas_id: String = ""
var grid_width: int = 0
var grid_height: int = 0
var cell_size: float = 0.0
var revision: int = -1
var creator_fingerprint: String = ""

var _surface_origin: Vector3
var _surface_normal: Vector3
var _surface_tangent: Vector3
var _surface_bitangent: Vector3
var _cells: Dictionary[int, Dictionary] = {}
var _color_meshes: Dictionary[StringName, MultiMeshInstance3D] = {}
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
	_rebuild_pixels()
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
	revision = int(data["revision"])
	_rebuild_pixels()
	return true


func apply_guide_update(data: Dictionary) -> bool:
	if (
		not SurfaceDrawingProtocol.validate_guide_update(data)
		or str(data["canvas_id"]) != canvas_id
		or int(data["revision"]) <= revision
	):
		return false
	revision = int(data["revision"])
	_finalized = bool(data["finalized"])
	_guide_visible = bool(data["guide_visible"]) and not _finalized
	_refresh_grid_visibility()
	_rebuild_pixels()
	return true


func refresh_relationship_visibility() -> void:
	_rebuild_pixels()


func set_stencil_visible(should_be_visible: bool) -> void:
	_stencil_requested_visible = should_be_visible
	_refresh_grid_visibility()


func is_guide_visible() -> bool:
	return _guide_visible


func is_finalized() -> bool:
	return _finalized


func get_rendered_pixel_size() -> float:
	return cell_size * _pixel_fill()


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
	return global_transform * _sample_cell_transform(x, y, fill)


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
	var immediate := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.75, 0.94, 0.96, 0.38)
	material.no_depth_test = false
	immediate.surface_begin(Mesh.PRIMITIVE_LINES, material)
	var half_width: float = float(grid_width) * cell_size * 0.5
	var half_height: float = float(grid_height) * cell_size * 0.5
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
			)
			_add_grid_vertex(
				immediate,
				_surface_origin + _surface_tangent * horizontal
					+ _surface_bitangent * (start_vertical + cell_size),
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
			)
			_add_grid_vertex(
				immediate,
				_surface_origin
					+ _surface_tangent * (start_horizontal + cell_size)
					+ _surface_bitangent * vertical,
			)
	immediate.surface_end()
	_grid_instance = MeshInstance3D.new()
	_grid_instance.name = "PixelGrid"
	_grid_instance.mesh = immediate
	_grid_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_grid_instance)
	_refresh_grid_visibility()


func _add_grid_vertex(immediate: ImmediateMesh, world_point: Vector3) -> void:
	var sampled: Dictionary = _sample_surface(world_point)
	var point: Vector3 = sampled["position"]
	var normal: Vector3 = sampled["normal"]
	immediate.surface_add_vertex(
		to_local(point + normal * (_surface_offset() * 1.5))
	)


func _rebuild_pixels() -> void:
	for instance: MultiMeshInstance3D in _color_meshes.values():
		instance.queue_free()
	_color_meshes.clear()
	var cells_by_color: Dictionary[StringName, Array] = {}
	for cell: Dictionary in _cells.values():
		var author_fingerprint: String = str(cell.get("author_fingerprint", ""))
		if (
			_relationships != null
			and _relationships.is_blocked(author_fingerprint)
		):
			continue
		var color_id := StringName(str(cell.get("color_id", "")))
		if not SurfaceDrawingPalette.has_color(color_id):
			continue
		var color_cells: Array = cells_by_color.get(color_id, [])
		color_cells.append(cell)
		cells_by_color[color_id] = color_cells
	for color_id: StringName in cells_by_color:
		_create_color_mesh(color_id, cells_by_color[color_id])


func _create_color_mesh(color_id: StringName, cells: Array) -> void:
	if cells.is_empty():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = SurfaceDrawingPalette.get_color(color_id)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = quad
	multimesh.instance_count = cells.size()
	for cell_index: int in range(cells.size()):
		var cell: Dictionary = cells[cell_index]
		multimesh.set_instance_transform(
			cell_index,
			_sample_cell_transform(
				int(cell["x"]), int(cell["y"]), _pixel_fill()
			),
		)
	var instance := MultiMeshInstance3D.new()
	instance.name = "Pixels_%s" % color_id
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_color_meshes[color_id] = instance


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


func _pixel_fill() -> float:
	return GUIDED_PIXEL_FILL if _guide_visible else FINISHED_PIXEL_FILL


func _surface_offset() -> float:
	return SURFACE_OFFSET + float(_layer) * LAYER_OFFSET_STEP


func _refresh_grid_visibility() -> void:
	if _grid_instance != null:
		_grid_instance.visible = _stencil_requested_visible and _guide_visible


func _cell_key(x: int, y: int) -> int:
	return y * grid_width + x
