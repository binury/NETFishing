class_name RemoteFishingPresentation
extends Node3D

var _owner: Player
var _bobber: MeshInstance3D
var _line: MeshInstance3D
var _line_mesh := ImmediateMesh.new()
var _target: Vector3
var _active: bool = false


func setup(owner: Player) -> void:
	_owner = owner
	_bobber = MeshInstance3D.new()
	var bobber_mesh := SphereMesh.new()
	bobber_mesh.radius = 0.12
	bobber_mesh.height = 0.24
	_bobber.mesh = bobber_mesh
	var bobber_material := StandardMaterial3D.new()
	bobber_material.albedo_color = Color(0.92, 0.12, 0.08, 1.0)
	bobber_material.roughness = 0.45
	_bobber.material_override = bobber_material
	add_child(_bobber)
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	var line_material := StandardMaterial3D.new()
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.albedo_color = Color(0.9, 0.9, 0.82, 1.0)
	_line.material_override = line_material
	add_child(_line)
	cleanup()


func show_cast(target: Vector3) -> void:
	if _owner == null or not target.is_finite():
		return
	_active = true
	_target = target
	_bobber.global_position = target
	_bobber.visible = true
	_line.visible = true
	_owner.set_active_item_is_rod(true)
	_redraw_line()


func update_bobber(position: Vector3) -> void:
	if not _active or not position.is_finite():
		return
	_target = position
	_bobber.global_position = position
	_redraw_line()


func show_bite() -> void:
	if not _active:
		return
	var tween: Tween = create_tween()
	tween.tween_property(_bobber, "scale", Vector3.ONE * 0.7, 0.08)
	tween.tween_property(_bobber, "scale", Vector3.ONE, 0.12)


func cleanup() -> void:
	_active = false
	if _bobber != null:
		_bobber.visible = false
		_bobber.scale = Vector3.ONE
	if _line != null:
		_line.visible = false
	_line_mesh.clear_surfaces()


func _process(_delta: float) -> void:
	if _owner != null and not _owner.is_remote_presentation_visible():
		_bobber.visible = false
		_line.visible = false
		return
	if _active:
		_redraw_line()


func _redraw_line() -> void:
	if _owner == null or not is_instance_valid(_owner):
		cleanup()
		return
	var tip: Marker3D = _owner.get_fishing_rod_tip()
	if tip == null:
		return
	_line_mesh.clear_surfaces()
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	_line_mesh.surface_add_vertex(to_local(tip.global_position))
	var midpoint: Vector3 = tip.global_position.lerp(_target, 0.5)
	midpoint.y -= 0.12
	_line_mesh.surface_add_vertex(to_local(midpoint))
	_line_mesh.surface_add_vertex(to_local(_target))
	_line_mesh.surface_end()
