class_name WorldGatherable
extends Node3D

const GatherableDataType = preload("res://gathering/gatherable_data.gd")

var entity_id: String = ""
var type_id: StringName
var data: GatherableDataType
var _sprite: Sprite3D
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
	_ensure_visual()
	if data != null and data.catch_data != null:
		_sprite.texture = data.catch_data.display_texture
		_sprite.pixel_size = data.sprite_pixel_size
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


func _ensure_visual() -> void:
	if _sprite != null:
		return
	_sprite = Sprite3D.new()
	_sprite.name = "GatherableSprite"
	_sprite.position.y = 0.22
	_sprite.shaded = false
	_sprite.double_sided = true
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	add_child(_sprite)


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
