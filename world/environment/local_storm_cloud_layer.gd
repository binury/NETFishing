class_name LocalStormCloudLayer
extends Node3D

const CLOUD_SHADER: Shader = preload(
	"res://world/environment/local_storm_cloud.gdshader"
)
const MIN_CLOUD_ALTITUDE: float = 15.0
const MAX_CLOUD_ALTITUDE: float = 23.0
const GRID_AXIS_COUNT: int = 9
const GRID_SPACING: float = 70.0
const FIELD_HALF_EXTENT: float = GRID_AXIS_COUNT * GRID_SPACING * 0.5
const DISTANCE_FADE_START: float = 240.0
const DISTANCE_FADE_END: float = 300.0
const WRAP_RADIUS: float = FIELD_HALF_EXTENT
const MAXIMUM_OPACITY: float = 1.0
const BASE_VELOCITY := Vector2(0.825, -0.45)
const BODY_OUTLINE: Array[Vector2] = [
	Vector2(-6.9, -0.8),
	Vector2(-6.6, -2.0),
	Vector2(-5.7, -3.0),
	Vector2(-4.5, -3.5),
	Vector2(-3.0, -3.7),
	Vector2(-1.8, -4.2),
	Vector2(-0.5, -4.3),
	Vector2(0.7, -4.0),
	Vector2(2.0, -4.1),
	Vector2(3.0, -3.5),
	Vector2(4.6, -3.3),
	Vector2(5.8, -2.5),
	Vector2(6.6, -1.5),
	Vector2(7.0, -0.2),
	Vector2(6.8, 1.0),
	Vector2(6.1, 1.9),
	Vector2(6.0, 2.9),
	Vector2(5.1, 3.7),
	Vector2(3.8, 4.0),
	Vector2(2.7, 4.7),
	Vector2(1.4, 4.9),
	Vector2(0.2, 5.3),
	Vector2(-1.2, 5.0),
	Vector2(-2.1, 4.4),
	Vector2(-3.6, 4.2),
	Vector2(-4.9, 3.5),
	Vector2(-5.4, 2.5),
	Vector2(-6.3, 1.7),
	Vector2(-6.8, 0.6),
]

var _target: Node3D
var _material: ShaderMaterial
var _multimesh: MultiMesh
var _cloud_mesh: MultiMeshInstance3D
var _drift_offset := Vector2.ZERO
var _storm_amount: float = 0.0


func setup(target: Node3D) -> void:
	_target = target
	_build_cloud_field()
	_update_cloud_transforms()
	set_process(true)


func set_storm_amount(amount: float, color: Color) -> void:
	_storm_amount = clampf(amount, 0.0, 1.0)
	var should_be_visible: bool = _storm_amount > 0.001
	if should_be_visible and not visible:
		_update_cloud_transforms()
	visible = should_be_visible
	if _material == null:
		return
	_material.set_shader_parameter("weather_opacity", _storm_amount)
	_material.set_shader_parameter("cloud_color", color)


func get_storm_amount() -> float:
	return _storm_amount


func get_patch_count() -> int:
	return GRID_AXIS_COUNT * GRID_AXIS_COUNT


func _process(delta: float) -> void:
	if not visible or _target == null or not is_instance_valid(_target):
		return
	_drift_offset += BASE_VELOCITY * delta
	_drift_offset = Vector2(
		_wrap_axis(_drift_offset.x),
		_wrap_axis(_drift_offset.y),
	)
	_update_cloud_transforms()


func _build_cloud_field() -> void:
	_material = ShaderMaterial.new()
	_material.shader = CLOUD_SHADER
	_material.set_shader_parameter("weather_opacity", 0.0)
	_material.set_shader_parameter("maximum_opacity", MAXIMUM_OPACITY)
	_material.set_shader_parameter("distance_fade_start", DISTANCE_FADE_START)
	_material.set_shader_parameter("distance_fade_end", DISTANCE_FADE_END)

	var cloud_body_mesh: ArrayMesh = _build_cloud_body_mesh()
	cloud_body_mesh.surface_set_material(0, _material)

	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = cloud_body_mesh
	_multimesh.instance_count = get_patch_count()
	_multimesh.custom_aabb = AABB(
		Vector3(
			-FIELD_HALF_EXTENT - 60.0,
			MIN_CLOUD_ALTITUDE - 5.0,
			-FIELD_HALF_EXTENT - 60.0,
		),
		Vector3(
			(FIELD_HALF_EXTENT + 60.0) * 2.0,
			MAX_CLOUD_ALTITUDE - MIN_CLOUD_ALTITUDE + 10.0,
			(FIELD_HALF_EXTENT + 60.0) * 2.0,
		),
	)

	_cloud_mesh = MultiMeshInstance3D.new()
	_cloud_mesh.name = "CloudField"
	_cloud_mesh.multimesh = _multimesh
	_cloud_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cloud_mesh)
	visible = false


func _build_cloud_body_mesh() -> ArrayMesh:
	var outline := PackedVector2Array(BODY_OUTLINE)
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var face_indices: PackedInt32Array = Geometry2D.triangulate_polygon(
		outline
	)
	for triangle_offset: int in range(0, face_indices.size(), 3):
		var point_a: Vector2 = outline[face_indices[triangle_offset]]
		var point_b: Vector2 = outline[face_indices[triangle_offset + 1]]
		var point_c: Vector2 = outline[face_indices[triangle_offset + 2]]
		_add_oriented_triangle(
			surface_tool,
			_to_cloud_vertex(point_a),
			_to_cloud_vertex(point_b),
			_to_cloud_vertex(point_c),
			Vector3.DOWN,
		)
	surface_tool.index()
	return surface_tool.commit()


func _to_cloud_vertex(point: Vector2) -> Vector3:
	return Vector3(point.x, 0.0, point.y)


func _add_oriented_triangle(
	surface_tool: SurfaceTool,
	point_a: Vector3,
	point_b: Vector3,
	point_c: Vector3,
	expected_normal: Vector3,
) -> void:
	if (point_b - point_a).cross(point_c - point_a).dot(expected_normal) < 0.0:
		var swap: Vector3 = point_b
		point_b = point_c
		point_c = swap
	for point: Vector3 in [point_a, point_b, point_c]:
		surface_tool.set_normal(expected_normal)
		surface_tool.add_vertex(point)


func _update_cloud_transforms() -> void:
	if _target == null or _multimesh == null:
		return
	global_position = _target.global_position
	var target_xz := Vector2(
		_target.global_position.x,
		_target.global_position.z,
	)
	var grid_center: float = float(GRID_AXIS_COUNT - 1) * 0.5
	var instance_index: int = 0
	for grid_z: int in GRID_AXIS_COUNT:
		for grid_x: int in GRID_AXIS_COUNT:
			var patch_index: int = grid_z * GRID_AXIS_COUNT + grid_x
			var world_offset := Vector2(
				(float(grid_x) - grid_center) * GRID_SPACING,
				(float(grid_z) - grid_center) * GRID_SPACING,
			) + _drift_offset
			var relative := Vector2(
				_wrap_axis(world_offset.x - target_xz.x),
				_wrap_axis(world_offset.y - target_xz.y),
			)
			var altitude: float = lerpf(
				MIN_CLOUD_ALTITUDE,
				MAX_CLOUD_ALTITUDE,
				float(patch_index % 4) / 3.0,
			)
			var patch_scale: float = 2.20 + float(
				(patch_index * 7) % 10
			) * 0.10
			var width_variation: float = 0.90 + float(
				(patch_index * 5) % 7
			) * 0.04
			var depth_variation: float = 0.90 + float(
				(patch_index * 3 + 2) % 7
			) * 0.04
			var patch_basis := Basis(
				Vector3.UP,
				deg_to_rad(float(patch_index * 17 % 41) - 20.0),
			).scaled(Vector3(
				patch_scale * 2.35 * width_variation,
				patch_scale * 0.34,
				patch_scale * 2.65 * depth_variation,
			))
			_multimesh.set_instance_transform(
				instance_index,
				Transform3D(
					patch_basis,
					Vector3(relative.x, altitude, relative.y),
				),
			)
			instance_index += 1


func _wrap_axis(value: float) -> float:
	return fposmod(value + FIELD_HALF_EXTENT, FIELD_HALF_EXTENT * 2.0) \
		- FIELD_HALF_EXTENT
