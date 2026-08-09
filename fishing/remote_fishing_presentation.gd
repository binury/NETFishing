class_name RemoteFishingPresentation
extends Node3D

const WaterSurfaceMotionType = preload(
	"res://world/water_surface_motion.gd"
)

signal return_completed

var _owner: Player
var _bobber: MeshInstance3D
var _line: MeshInstance3D
var _line_mesh := ImmediateMesh.new()
var _target: Vector3
var _pending_target: Vector3
var _active: bool = false
var _cast_tween: Tween
var _return_tween: Tween
var _showcase_tween: Tween
var _return_showcase_catch: FishCatch
var _bobber_idle_elapsed: float = 0.0
var _bobber_base_scale: Vector3 = Vector3.ONE


func setup(owning_player: Player) -> void:
	_owner = owning_player
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


func show_cast(origin: Vector3, target: Vector3) -> void:
	if (
		_owner == null
		or not origin.is_finite()
		or not target.is_finite()
	):
		return
	_kill_cast_tween()
	_active = true
	_bobber_base_scale = Vector3.ONE * _owner.get_character_visual_scale()
	_target = origin
	_pending_target = target
	_bobber_idle_elapsed = 0.0
	_bobber.global_position = origin
	_bobber.scale = _bobber_base_scale
	_bobber.visible = true
	_line.visible = true
	_owner.set_active_item_is_rod(true)
	_owner.set_release_visual()
	_redraw_line()
	_cast_tween = create_tween()
	_cast_tween.set_trans(Tween.TRANS_SINE)
	_cast_tween.set_ease(Tween.EASE_IN_OUT)
	_cast_tween.tween_method(
		_set_cast_sample.bind(origin, target),
		0.0,
		1.0,
		0.65,
	)
	_cast_tween.finished.connect(_on_cast_finished)


func update_bobber(world_position: Vector3) -> void:
	if not _active or not world_position.is_finite():
		return
	_pending_target = world_position
	if _cast_tween != null:
		return
	_target = world_position
	_bobber.global_position = world_position
	_redraw_line()


func show_bite() -> void:
	if not _active:
		return
	if _owner != null and is_instance_valid(_owner):
		_owner.set_fighting_visual(true)
	var tween: Tween = create_tween()
	tween.tween_property(_bobber, "scale", _bobber_base_scale * 0.7, 0.08)
	tween.tween_property(_bobber, "scale", _bobber_base_scale, 0.12)


func play_return(showcase_catch: FishCatch = null) -> void:
	if _owner != null and is_instance_valid(_owner):
		_owner.set_fighting_visual(false)
		_owner.set_retract_visual()
	if not _active or _bobber == null:
		cleanup()
		return_completed.emit()
		return
	_kill_cast_tween()
	_kill_return_tween()
	_return_showcase_catch = showcase_catch
	var start: Vector3 = _bobber.global_position
	var target: Vector3 = start
	if _owner != null and is_instance_valid(_owner):
		var tip: Marker3D = _owner.get_fishing_rod_tip()
		if tip != null:
			target = tip.global_position
	_return_tween = create_tween()
	_return_tween.set_trans(Tween.TRANS_QUAD)
	_return_tween.set_ease(Tween.EASE_IN)
	_return_tween.tween_method(
		_set_return_sample.bind(start, target),
		0.0,
		1.0,
		0.42,
	)
	_return_tween.tween_property(_bobber, "scale", Vector3.ZERO, 0.1)
	_return_tween.finished.connect(_on_return_finished)


func cleanup() -> void:
	_kill_cast_tween()
	_kill_return_tween()
	_kill_showcase_tween()
	_active = false
	_pending_target = Vector3.ZERO
	_return_showcase_catch = null
	_bobber_idle_elapsed = 0.0
	if _owner != null and is_instance_valid(_owner):
		_owner.set_fighting_visual(false)
		_owner.set_fishing_visual(false)
		_owner.end_catch_showcase(Callable(), true)
	if _bobber != null:
		_bobber.visible = false
		_bobber.scale = Vector3.ONE
	_bobber_base_scale = Vector3.ONE
	if _line != null:
		_line.visible = false
	_line_mesh.clear_surfaces()


func _set_cast_sample(
	progress: float,
	start: Vector3,
	target: Vector3,
) -> void:
	_target = start.lerp(target, progress)
	_target.y += sin(progress * PI) * 2.0
	_target.y += (
		WaterSurfaceMotionType.get_default_height_offset()
		* smoothstep(0.72, 1.0, progress)
	)
	_bobber.global_position = _target


func _on_cast_finished() -> void:
	_cast_tween = null
	_bobber_idle_elapsed = 0.0
	if _owner != null and is_instance_valid(_owner):
		_owner.set_fishing_visual(true)
	_apply_bobber_idle_motion()
	_redraw_line()


func _apply_bobber_idle_motion() -> void:
	var phase: float = _bobber_idle_elapsed * 0.7 * TAU
	_target = _pending_target + Vector3.UP * (
		WaterSurfaceMotionType.get_default_height_offset()
		+ sin(phase) * 0.035
	)
	_bobber.global_position = _target
	_bobber.rotation.z = deg_to_rad(4.0) * sin(phase * 0.73)


func _set_return_sample(
	progress: float,
	start: Vector3,
	target: Vector3,
) -> void:
	var eased_progress: float = 1.0 - pow(1.0 - progress, 3.0)
	_target = start.lerp(target, eased_progress)
	_target.y += sin(eased_progress * PI) * 1.3
	_bobber.global_position = _target
	_bobber.rotation = Vector3.ZERO


func _on_return_finished() -> void:
	_return_tween = null
	_active = false
	_bobber.visible = false
	_line.visible = false
	_line_mesh.clear_surfaces()
	if (
		_owner != null
		and is_instance_valid(_owner)
		and not _owner.is_retract_visual_complete()
	):
		await _owner.retract_visual_finished
	if (
		_return_showcase_catch != null
		and _owner != null
		and is_instance_valid(_owner)
	):
		_owner.begin_remote_catch_showcase(_return_showcase_catch)
		_return_showcase_catch = null
		_showcase_tween = create_tween()
		_showcase_tween.tween_interval(2.5)
		_showcase_tween.finished.connect(_on_showcase_finished)
		return
	return_completed.emit()


func _on_showcase_finished() -> void:
	_showcase_tween = null
	if _owner != null and is_instance_valid(_owner):
		_owner.end_catch_showcase(_on_showcase_put_away_finished)
		return
	_on_showcase_put_away_finished()


func _on_showcase_put_away_finished() -> void:
	return_completed.emit()


func _kill_cast_tween() -> void:
	if _cast_tween != null and _cast_tween.is_valid():
		_cast_tween.kill()
	_cast_tween = null


func _kill_return_tween() -> void:
	if _return_tween != null and _return_tween.is_valid():
		_return_tween.kill()
	_return_tween = null


func _kill_showcase_tween() -> void:
	if _showcase_tween != null and _showcase_tween.is_valid():
		_showcase_tween.kill()
	_showcase_tween = null


func _process(delta: float) -> void:
	if _owner != null and not _owner.is_remote_presentation_visible():
		_bobber.visible = false
		_line.visible = false
		return
	if _active:
		if _cast_tween == null and _return_tween == null:
			_bobber_idle_elapsed += delta
			_apply_bobber_idle_motion()
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
