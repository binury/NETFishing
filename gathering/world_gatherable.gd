class_name WorldGatherable
extends Node3D

const GatherableDataType = preload("res://gathering/gatherable_data.gd")
const REFERENCE_SPRITE_PIXEL_SIZE: float = 0.001
const REFERENCE_SPRITE_HEIGHT: float = 0.22
const WATER_SPURT_INTERVAL_SECONDS: float = 1.15
const WATER_SPURT_COLOR := Color(0.48, 0.82, 0.84, 1.0)
const WATER_SPURT_HOLE_COLOR := Color(0.23, 0.27, 0.24, 1.0)

var entity_id: String = ""
var type_id: StringName
var data: GatherableDataType
var _sprite: Sprite3D
var _water_spurt_root: Node3D
var _water_spurt_elapsed: float = 0.0
var _target_position: Vector3
var _target_yaw: float = 0.0
var _has_state: bool = false
var _despawning: bool = false


func configure(
	configured_entity_id: String,
	configured_data: GatherableDataType,
	position: Vector3,
	yaw: float,
) -> void:
	entity_id = configured_entity_id
	data = configured_data
	type_id = data.type_id if data != null else StringName()
	if data != null and data.is_stationary_hotspot():
		_ensure_water_spurt_visual()
		_water_spurt_elapsed = (
			float(abs(hash(entity_id)) % 1000) / 1000.0
			* WATER_SPURT_INTERVAL_SECONDS
		)
	else:
		_ensure_visual()
	if data != null and data.catch_data != null and _sprite != null:
		_sprite.texture = data.catch_data.display_texture
		_sprite.pixel_size = data.sprite_pixel_size
		_sprite.position.y = (
			0.0
			if not data.spawn_anchor_set_id.is_empty()
			else (
				REFERENCE_SPRITE_HEIGHT
				* data.sprite_pixel_size
				/ REFERENCE_SPRITE_PIXEL_SIZE
			)
		)
		_sprite.rotation_degrees.x = data.sprite_tilt_degrees
	apply_network_state(position, yaw, true)


func apply_network_state(
	position: Vector3,
	yaw: float,
	immediate: bool = false,
) -> void:
	if _despawning or not position.is_finite() or not is_finite(yaw):
		return
	_target_position = position
	_target_yaw = yaw
	if immediate or not _has_state:
		global_position = position
		rotation.y = yaw
	_has_state = true


func play_despawn(with_dust: bool) -> void:
	if _despawning:
		return
	_despawning = true
	if with_dust:
		_emit_dust()
	if _water_spurt_root != null:
		_water_spurt_root.visible = false
		queue_free()
		return
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	if _sprite != null:
		tween.tween_property(_sprite, "position:y", -0.3, 0.3)
		tween.tween_property(_sprite, "scale", Vector3(0.75, 0.75, 0.75), 0.3)
	tween.chain().tween_callback(queue_free)


func _process(delta: float) -> void:
	if not _has_state or _despawning:
		return
	global_position = global_position.lerp(
		_target_position,
		1.0 - exp(-10.0 * delta),
	)
	rotation.y = lerp_angle(
		rotation.y,
		_target_yaw,
		1.0 - exp(-8.0 * delta),
	)
	if _water_spurt_root != null:
		_water_spurt_elapsed += delta
		if _water_spurt_elapsed >= WATER_SPURT_INTERVAL_SECONDS:
			_water_spurt_elapsed = fmod(
				_water_spurt_elapsed,
				WATER_SPURT_INTERVAL_SECONDS,
			)
			_emit_water_spurt()


func _ensure_visual() -> void:
	if _sprite != null:
		return
	_sprite = Sprite3D.new()
	_sprite.name = "GatherableSprite"
	_sprite.position.y = REFERENCE_SPRITE_HEIGHT
	_sprite.shaded = false
	_sprite.double_sided = true
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


func _ensure_water_spurt_visual() -> void:
	if _water_spurt_root != null:
		return
	_water_spurt_root = Node3D.new()
	_water_spurt_root.name = "WaterSpurt"
	add_child(_water_spurt_root)
	var hole_material := StandardMaterial3D.new()
	hole_material.albedo_color = WATER_SPURT_HOLE_COLOR
	hole_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hole_material.roughness = 1.0
	hole_material.metallic = 0.0
	var hole_mesh := CylinderMesh.new()
	hole_mesh.top_radius = 0.035
	hole_mesh.bottom_radius = 0.035
	hole_mesh.height = 0.004
	hole_mesh.radial_segments = 12
	hole_mesh.rings = 1
	hole_mesh.material = hole_material
	var hole := MeshInstance3D.new()
	hole.name = "BurrowMark"
	hole.position.y = 0.008
	hole.mesh = hole_mesh
	hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water_spurt_root.add_child(hole)
	_emit_water_spurt()


func _emit_water_spurt() -> void:
	if _water_spurt_root == null or not _water_spurt_root.visible:
		return
	var particles := CPUParticles3D.new()
	particles.name = "WaterDroplets"
	particles.position.y = 0.035
	particles.amount = 6
	particles.lifetime = 0.42
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 32.0
	particles.gravity = Vector3(0.0, -3.4, 0.0)
	particles.initial_velocity_min = 0.8
	particles.initial_velocity_max = 1.2
	particles.scale_amount_min = 0.75
	particles.scale_amount_max = 1.0
	var water_material := StandardMaterial3D.new()
	water_material.albedo_color = WATER_SPURT_COLOR
	water_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	water_material.roughness = 1.0
	water_material.metallic = 0.0
	var droplet_mesh := BoxMesh.new()
	droplet_mesh.size = Vector3(0.022, 0.035, 0.022)
	droplet_mesh.material = water_material
	particles.mesh = droplet_mesh
	_water_spurt_root.add_child(particles)
	particles.emitting = true
	var cleanup := create_tween()
	cleanup.tween_interval(0.55)
	cleanup.tween_callback(particles.queue_free)


func _emit_dust() -> void:
	var particles := CPUParticles3D.new()
	particles.name = "DustPoof"
	particles.amount = 9
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 58.0
	particles.gravity = Vector3(0.0, -2.4, 0.0)
	particles.initial_velocity_min = 0.65
	particles.initial_velocity_max = 1.25
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.35
	var dust_material := StandardMaterial3D.new()
	dust_material.albedo_color = Color(0.58, 0.46, 0.31, 0.85)
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var dust_mesh := BoxMesh.new()
	dust_mesh.size = Vector3(0.1, 0.1, 0.1)
	dust_mesh.material = dust_material
	particles.mesh = dust_mesh
	add_child(particles)
	particles.emitting = true
