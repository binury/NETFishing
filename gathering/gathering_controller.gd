class_name GatheringController
extends Node3D

const FishingShopStockType = preload("res://economy/fishing_shop_stock.gd")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const NetworkWorldSpawnServiceType = preload(
	"res://network/network_world_spawn_service.gd"
)

signal status_changed(message: String)

@export_range(0.5, 5.0, 0.05) var marker_distance: float = 1.7
@export_range(0.025, 2.0, 0.025) var marker_radius: float = 0.175
@export_range(0.0, 1.0, 0.01) var marker_surface_offset: float = 0.045
@export_range(0.0, 2.0, 0.05) var forward_probe_extra_distance: float = 0.6
@export_flags_3d_physics var terrain_collision_mask: int = 1
@export_range(0.5, 20.0, 0.5) var ray_height: float = 5.0
@export_range(0.5, 20.0, 0.5) var ray_depth: float = 8.0

var _player: Player
var _bag: PlayerBag
var _hotbar: PlayerHotbar
var _fishing_spot: FishingSpotType
var _service: NetworkWorldSpawnServiceType
var _marker: MeshInstance3D
var _marker_invalid_material: StandardMaterial3D
var _marker_valid_material: StandardMaterial3D
var _marker_position: Vector3
var _marker_has_surface: bool = false
var _target_entity_id: String = ""
var _charging: bool = false
var _charge_elapsed: float = 0.0
var _charge_duration: float = 2.0
var _request_id: String = ""
var _gameplay_input_enabled: bool = false


func _ready() -> void:
	_build_marker()
	set_process_unhandled_input(true)


func setup(
	player: Player,
	bag: PlayerBag,
	hotbar: PlayerHotbar,
	fishing_spot: FishingSpotType,
	service: NetworkWorldSpawnServiceType,
) -> void:
	_player = player
	_bag = bag
	_hotbar = hotbar
	_fishing_spot = fishing_spot
	_service = service
	_service.local_interaction_finished.connect(
		_on_interaction_finished
	)


func set_gameplay_input_enabled(enabled: bool) -> void:
	_gameplay_input_enabled = enabled
	if not enabled:
		_cancel_charge()


func is_net_selected() -> bool:
	return (
		_bag != null
		and _hotbar != null
		and _hotbar.get_selected_item_id()
		== FishingShopStockType.CRAB_NET_ID
		and _bag.owns_item(FishingShopStockType.CRAB_NET_ID)
	)


func _process(delta: float) -> void:
	var input_available: bool = (
		_gameplay_input_enabled
		and is_net_selected()
		and _player != null
		and _player.is_local_control_enabled()
		and _fishing_spot != null
		and _fishing_spot.can_change_hotbar_selection()
	)
	if not input_available:
		if _charging:
			_cancel_charge()
		_set_marker_visible(false)
		return
	if not _charging:
		_set_marker_visible(false)
		return
	_charge_elapsed += delta
	_update_marker_target()
	_update_target_entity()
	var target_entry: GatherableData = _service.get_entry_for_entity(
		_target_entity_id
	)
	if target_entry != null:
		_charge_duration = target_entry.charge_duration
	var fully_charged: bool = _charge_elapsed >= _charge_duration
	var valid_target: bool = (
		fully_charged
		and not _target_entity_id.is_empty()
		and _player.is_sneaking()
	)
	_marker.material_override = (
		_marker_valid_material if valid_target else _marker_invalid_material
	)
	_set_marker_visible(_marker_has_surface)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action("fish_primary"):
		return
	if event.is_pressed():
		if (
			_gameplay_input_enabled
			and _player != null
			and _player.release_net_strike_hold()
		):
			get_viewport().set_input_as_handled()
			return
		if (
			_charging
			or not _gameplay_input_enabled
			or not is_net_selected()
			or _fishing_spot == null
			or not _fishing_spot.can_change_hotbar_selection()
		):
			return
		_request_id = _service.begin_local_interaction()
		if _request_id.is_empty():
			return
		_charging = true
		_charge_elapsed = 0.0
		_charge_duration = maxf(
			_service.get_charge_duration_for_tool(
				FishingShopStockType.CRAB_NET_ID
			),
			0.1,
		)
		_update_marker_target()
		_update_target_entity()
		_player.begin_net_draw_visual()
		get_viewport().set_input_as_handled()
		return
	if not _charging:
		return
	var fully_charged: bool = _charge_elapsed >= _charge_duration
	var valid_capture: bool = (
		fully_charged
		and _marker_has_surface
		and not _target_entity_id.is_empty()
		and _player.is_sneaking()
	)
	_player.play_net_strike_visual()
	if valid_capture:
		_service.finish_local_interaction(
			_request_id,
			_target_entity_id,
			_marker_position,
		)
	else:
		_service.cancel_local_interaction(_request_id)
		_player.resolve_net_strike_visual(false)
	_reset_charge_state()
	get_viewport().set_input_as_handled()


func _update_marker_target() -> void:
	_marker_has_surface = false
	if _player == null or get_world_3d() == null:
		return
	var facing: Vector3 = _player.get_facing_direction()
	facing.y = 0.0
	if facing.is_zero_approx():
		facing = -_player.global_basis.z
		facing.y = 0.0
	if facing.is_zero_approx():
		return
	facing = facing.normalized()
	var probe_origin: Vector3 = _player.get_body_center_position()
	var probe_direction: Vector3 = _get_surface_probe_direction(facing)
	var forward_hit: Dictionary = _cast_marker_ray(
		probe_origin,
		probe_origin
		+ probe_direction
		* (marker_distance + forward_probe_extra_distance),
	)
	if _apply_marker_surface(forward_hit, facing):
		return
	var query_center: Vector3 = _player.global_position + facing * marker_distance
	var ground_hit: Dictionary = _cast_marker_ray(
		query_center + Vector3.UP * ray_height,
		query_center - Vector3.UP * ray_depth,
	)
	_apply_marker_surface(ground_hit, facing)


func _get_surface_probe_direction(facing: Vector3) -> Vector3:
	var vertical_aim: float = 0.0
	var camera := _player.get_active_gameplay_camera()
	if camera != null:
		vertical_aim = clampf((-camera.global_basis.z).y, -0.75, 0.75)
	return Vector3(facing.x, vertical_aim, facing.z).normalized()


func _cast_marker_ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(
		from,
		to,
		terrain_collision_mask,
		[_player.get_rid()],
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return get_world_3d().direct_space_state.intersect_ray(query)


func _apply_marker_surface(hit: Dictionary, facing: Vector3) -> bool:
	if hit.is_empty():
		return false
	var position: Variant = hit.get("position")
	var normal_value: Variant = hit.get("normal")
	if (
		typeof(position) != TYPE_VECTOR3
		or typeof(normal_value) != TYPE_VECTOR3
	):
		return false
	var surface_normal := normal_value as Vector3
	if not surface_normal.is_finite() or surface_normal.is_zero_approx():
		return false
	surface_normal = surface_normal.normalized()
	_marker_position = (
		(position as Vector3) + surface_normal * marker_surface_offset
	)
	_marker.global_position = _marker_position
	_marker.global_basis = marker_basis_for_surface(surface_normal, facing)
	_marker_has_surface = true
	return true


static func marker_basis_for_surface(
	surface_normal: Vector3,
	facing: Vector3,
) -> Basis:
	var normal := surface_normal.normalized()
	var reference := Vector3.UP
	if absf(normal.dot(Vector3.UP)) > 0.95:
		reference = facing.normalized()
		if reference.is_zero_approx() or absf(normal.dot(reference)) > 0.95:
			reference = Vector3.FORWARD
	var x_axis := reference.cross(normal).normalized()
	if x_axis.is_zero_approx():
		x_axis = Vector3.RIGHT
	var z_axis := x_axis.cross(normal).normalized()
	return Basis(x_axis, normal, z_axis).orthonormalized()


func _update_target_entity() -> void:
	_target_entity_id = (
		_service.find_capture_target(
			_marker_position,
			FishingShopStockType.CRAB_NET_ID,
		)
		if _marker_has_surface and _service != null
		else ""
	)


func _cancel_charge() -> void:
	if _charging and not _request_id.is_empty() and _service != null:
		_service.cancel_local_interaction(_request_id)
	if _charging and _player != null:
		_player.cancel_net_action_visual()
	_reset_charge_state()


func _reset_charge_state() -> void:
	_charging = false
	_charge_elapsed = 0.0
	_request_id = ""
	_target_entity_id = ""
	_marker_has_surface = false
	_set_marker_visible(false)


func _on_interaction_finished(accepted: bool, message: String) -> void:
	if _player != null:
		_player.resolve_net_strike_visual(accepted)
	_reset_charge_state()
	if not accepted or not message.is_empty():
		status_changed.emit(message)


func _build_marker() -> void:
	_marker_invalid_material = StandardMaterial3D.new()
	_marker_invalid_material.albedo_color = Color(0.86, 0.24, 0.19, 0.9)
	_marker_invalid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_valid_material = StandardMaterial3D.new()
	_marker_valid_material.albedo_color = Color(0.25, 0.9, 0.36, 0.95)
	_marker_valid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := TorusMesh.new()
	ring.inner_radius = marker_radius * 0.78
	ring.outer_radius = marker_radius
	ring.rings = 16
	ring.ring_segments = 24
	_marker = MeshInstance3D.new()
	_marker.name = "GatheringTargetMarker"
	_marker.mesh = ring
	_marker.material_override = _marker_invalid_material
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)


func _set_marker_visible(value: bool) -> void:
	if _marker != null:
		_marker.visible = value
