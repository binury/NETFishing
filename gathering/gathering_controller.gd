class_name GatheringController
extends Node3D

const FishingShopStockType = preload("res://economy/fishing_shop_stock.gd")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const NetworkWorldSpawnServiceType = preload(
	"res://network/network_world_spawn_service.gd"
)

signal status_changed(message: String)

@export_range(0.5, 5.0, 0.05) var marker_distance: float = 1.7
@export_range(0.1, 2.0, 0.05) var marker_radius: float = 0.7
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
		get_viewport().set_input_as_handled()
		return
	if not _charging:
		return
	var fully_charged: bool = _charge_elapsed >= _charge_duration
	if (
		fully_charged
		and _marker_has_surface
		and not _target_entity_id.is_empty()
		and _player.is_sneaking()
	):
		_service.finish_local_interaction(
			_request_id,
			_target_entity_id,
			_marker_position,
		)
	else:
		_service.cancel_local_interaction(_request_id)
		status_changed.emit(
			"Sneak close, pull the net all the way back, and line up the marker."
		)
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
	var query_center: Vector3 = _player.global_position + facing * marker_distance
	var query := PhysicsRayQueryParameters3D.create(
		query_center + Vector3.UP * ray_height,
		query_center - Vector3.UP * ray_depth,
		terrain_collision_mask,
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var position: Variant = hit.get("position")
	if typeof(position) != TYPE_VECTOR3:
		return
	_marker_position = (position as Vector3) + Vector3.UP * 0.045
	_marker.global_position = _marker_position
	_marker_has_surface = true


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
	_reset_charge_state()


func _reset_charge_state() -> void:
	_charging = false
	_charge_elapsed = 0.0
	_request_id = ""
	_target_entity_id = ""
	_marker_has_surface = false
	_set_marker_visible(false)


func _on_interaction_finished(accepted: bool, message: String) -> void:
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
