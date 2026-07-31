class_name PlayerGroundShadow
extends Node3D

@export_range(0.0, 0.1, 0.001) var surface_offset: float = 0.018
@export_range(0.0, 0.5, 0.01) var full_opacity_height: float = 0.12
@export_range(0.5, 4.0, 0.05) var fade_end_height: float = 2.0
@export_range(1.0, 20.0, 0.5) var fade_speed: float = 10.0
@export_range(0.25, 1.0, 0.01) var airborne_scale: float = 0.72

@onready var _player := get_parent() as Player
@onready var _ground_probe: RayCast3D = %GroundProbe
@onready var _placement: Node3D = %GroundShadowPlacement
@onready var _visual: MeshInstance3D = %GroundShadowVisual

var _opacity: float = 0.0
var _visual_scale: float = 1.0


func _ready() -> void:
	_visual.visible = false


func _physics_process(delta: float) -> void:
	_ground_probe.force_raycast_update()
	var target_opacity := 0.0
	var target_scale := airborne_scale
	var can_place := (
		_player != null
		and _player.is_remote_presentation_visible()
		and not _player.is_water_recovery_active()
		and _ground_probe.is_colliding()
		and not (_ground_probe.get_collider() is PlayerWaterTrigger)
	)
	if can_place:
		var hit_position: Vector3 = _ground_probe.get_collision_point()
		var hit_normal: Vector3 = _ground_probe.get_collision_normal().normalized()
		var height := maxf(global_position.y - hit_position.y, 0.0)
		var height_fade := 1.0 - smoothstep(
			full_opacity_height,
			fade_end_height,
			height,
		)
		target_opacity = height_fade
		target_scale = lerpf(airborne_scale, 1.0, height_fade)
		_place_on_surface(hit_position, hit_normal)
	_opacity = move_toward(_opacity, target_opacity, fade_speed * delta)
	_visual_scale = move_toward(
		_visual_scale,
		target_scale,
		fade_speed * 0.35 * delta,
	)
	_placement.scale = Vector3.ONE * _visual_scale
	_visual.visible = _opacity > 0.001
	_visual.transparency = 1.0 - _opacity


func _place_on_surface(position: Vector3, normal: Vector3) -> void:
	var tangent := Vector3.RIGHT - normal * Vector3.RIGHT.dot(normal)
	if tangent.length_squared() < 0.001:
		tangent = Vector3.FORWARD - normal * Vector3.FORWARD.dot(normal)
	tangent = tangent.normalized()
	var bitangent := tangent.cross(normal).normalized()
	_placement.global_transform = Transform3D(
		Basis(tangent, normal, bitangent),
		position + normal * surface_offset,
	)
