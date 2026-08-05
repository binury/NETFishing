class_name NetworkSurfaceDrawingService
extends Node

const BrushHighlightShader: Shader = preload(
	"res://drawing/surface_drawing_highlight.gdshader"
)
const ArtShopStockType = preload("res://economy/art_shop_stock.gd")

signal hud_state_changed(
	is_active: bool,
	mode_name: String,
	color_name: String,
	color_value: Color,
	brush_size: int,
	grid_size: int,
	status: String,
)
signal session_artwork_changed(canvas_count: int, painted_cell_count: int)

const SOLID_SURFACE_MASK: int = 1
const MAX_DRAW_DISTANCE: float = 16.0
const SURFACE_VALIDATION_DEPTH: float = 0.5
const MIN_SURFACE_NORMAL_DOT: float = 0.35
const EDIT_INTERVAL_MSEC: int = 45
const REQUEST_WINDOW_MSEC: int = 1000
const MAX_REQUESTS_PER_WINDOW: int = 32
const MAX_RECENT_REQUEST_IDS: int = 64
const GRID_PREVIEW_SURFACE_OFFSET: float = 0.03
const POINTER_EDGE_MARGIN: float = 2.0
const INVALID_POINTER_SCREEN_POSITION := Vector2(-1.0, -1.0)

enum GuideAction {
	NONE,
	HIDE,
	RESTORE,
	FINALIZE,
}

var _session: NetworkSession
var _spawn_service: PlayerSpawnService
var _relationships: PlayerRelationshipStore
var _local_player: Player
var _bag: PlayerBag
var _art_unlocks: PlayerArtUnlocks
var _drawing_root: Node3D
var _canvas_states: Dictionary[String, Dictionary] = {}
var _canvas_nodes: Dictionary[String, SurfaceDrawingCanvas] = {}
var _selected_canvas_id: String = ""
var _brush_preview: MultiMeshInstance3D
var _brush_preview_multimesh: MultiMesh
var _brush_preview_material: ShaderMaterial
var _placement_preview: MeshInstance3D
var _placement_preview_material: StandardMaterial3D
var _active: bool = false
var _placing_grid: bool = false
var _brush_size: int = 1
var _grid_size: int = SurfaceDrawingProtocol.DEFAULT_GRID_SIZE
var _color_ids: Array[StringName] = []
var _color_index: int = 0
var _painting: bool = false
var _erasing: bool = false
var _eraser_mode: bool = false
var _armed_guide_action: int = GuideAction.NONE
var _armed_return_placement_mode: bool = false
var _armed_return_eraser_mode: bool = false
var _camera_look_active: bool = false
var _prior_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _last_edited_cell := Vector3i(-1, -1, -1)
var _active_stroke_id: String = ""
var _last_local_stroke_id: String = ""
var _last_edit_msec: int = 0
var _aim_hit: Dictionary = {}
var _pointer_screen_position: Vector2 = Vector2.ZERO
var _request_sequence: int = 0
var _canvas_sequence: int = 0
var _peer_request_times: Dictionary[int, PackedInt64Array] = {}
var _peer_request_ids: Dictionary[int, PackedStringArray] = {}
var _stroke_history_by_peer: Dictionary[int, Dictionary] = {}
var _cell_last_stroke: Dictionary[String, String] = {}
var _peer_art_entitlements: Dictionary[int, Dictionary] = {}


func setup(
	session: NetworkSession,
	spawn_service: PlayerSpawnService,
	relationships: PlayerRelationshipStore,
	local_player: Player,
	drawing_root: Node3D,
	bag: PlayerBag,
	art_unlocks: PlayerArtUnlocks,
) -> void:
	_session = session
	_spawn_service = spawn_service
	_relationships = relationships
	_local_player = local_player
	_drawing_root = drawing_root
	_bag = bag
	_art_unlocks = art_unlocks
	_refresh_local_unlocks()
	if _session != null:
		_session.state_changed.connect(_on_session_state_changed)
		_session.peer_removed.connect(_on_peer_removed)
	if _relationships != null:
		_relationships.relationship_changed.connect(
			_on_relationship_changed
		)
	if _bag != null and not _bag.contents_changed.is_connected(
		_on_local_art_entitlement_changed
	):
		_bag.contents_changed.connect(_on_local_art_entitlement_changed)
	if _art_unlocks != null and not _art_unlocks.unlocks_changed.is_connected(
		_on_local_art_unlocks_changed
	):
		_art_unlocks.unlocks_changed.connect(_on_local_art_unlocks_changed)
	_create_brush_preview()
	_create_placement_preview()
	set_process(true)
	_emit_hud_state("")


func handle_input(
	event: InputEvent,
	can_open: bool,
	pointer_screen_position: Vector2 = INVALID_POINTER_SCREEN_POSITION,
) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if (
			key_event.pressed
			and not key_event.echo
			and key_event.physical_keycode == KEY_P
		):
			if _active:
				deactivate()
				return true
			if can_open and can_activate():
				activate(pointer_screen_position)
				return true
			return false
	if not _active:
		return false
	if not can_open:
		deactivate()
		return false
	if event.is_action_pressed("ui_cancel"):
		if _armed_guide_action != GuideAction.NONE:
			_cancel_armed_guide_action()
			return true
		if _placing_grid:
			_set_placement_mode(false)
			return true
		deactivate()
		return true
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if not key_event.pressed or key_event.echo:
			return false
		if key_event.ctrl_pressed and key_event.physical_keycode == KEY_Z:
			request_undo_last_stroke()
			return true
		match key_event.physical_keycode:
			KEY_Q:
				if not _placing_grid:
					_cycle_color(-1)
				return true
			KEY_E:
				if not _placing_grid:
					_cycle_color(1)
				return true
			KEY_R:
				_set_placement_mode(not _placing_grid)
				return true
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		_set_pointer_from_input(
			mouse_event.position,
			pointer_screen_position,
		)
		_update_aim()
		if (
			mouse_event.shift_pressed
			and mouse_event.button_index in [
				MOUSE_BUTTON_WHEEL_UP,
				MOUSE_BUTTON_WHEEL_DOWN,
			]
		):
			return false
		match mouse_event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mouse_event.pressed and not _placing_grid:
					_set_brush_size(_brush_size + 1)
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				if mouse_event.pressed and not _placing_grid:
					_set_brush_size(_brush_size - 1)
				return true
			MOUSE_BUTTON_LEFT:
				if _placing_grid:
					if mouse_event.pressed:
						if _armed_guide_action != GuideAction.NONE:
							_execute_armed_guide_action()
						elif mouse_event.shift_pressed and mouse_event.ctrl_pressed:
							_finalize_selected_guide()
						elif mouse_event.shift_pressed:
							_remove_selected_guide()
						else:
							_request_canvas_at_aim()
					return true
				if mouse_event.pressed:
					_begin_stroke()
				_erasing = (
					mouse_event.pressed
					and (mouse_event.shift_pressed or _eraser_mode)
				)
				_painting = mouse_event.pressed and not _erasing
				if _painting or _erasing:
					_submit_current_brush(_erasing, true)
				else:
					_finish_stroke()
				return true
			MOUSE_BUTTON_RIGHT:
				_camera_look_active = mouse_event.pressed
				_reset_stroke()
				return false
	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion
		if _camera_look_active:
			return false
		_set_pointer_from_input(
			motion_event.position,
			pointer_screen_position,
		)
		_update_aim()
		return true
	return false


func activate(
	pointer_screen_position: Vector2 = INVALID_POINTER_SCREEN_POSITION,
) -> void:
	if _active or not can_activate():
		return
	_active = true
	_placing_grid = true
	_eraser_mode = false
	_clear_armed_guide_action(false)
	_refresh_local_unlocks()
	_rebuild_placement_preview()
	_reset_stroke()
	var initial_pointer_position: Vector2 = pointer_screen_position
	if not _is_valid_pointer_screen_position(initial_pointer_position):
		initial_pointer_position = get_viewport().get_mouse_position()
	_pointer_screen_position = _clamped_pointer_position(
		initial_pointer_position
	)
	_prior_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_aim()
	_refresh_stencil_visibility()
	_emit_hud_state(
		"click to place a shared grid"
	)


func deactivate() -> void:
	if not _active:
		return
	_active = false
	_placing_grid = false
	_eraser_mode = false
	_clear_armed_guide_action(false)
	_camera_look_active = false
	_reset_stroke()
	_selected_canvas_id = ""
	_aim_hit.clear()
	_hide_previews()
	_refresh_stencil_visibility()
	Input.mouse_mode = _prior_mouse_mode
	_emit_hud_state("")


func is_active() -> bool:
	return _active


func is_placement_mode() -> bool:
	return _placing_grid


func can_activate() -> bool:
	return _drawing_available() and _owns_art_kit()


func set_placement_mode(enabled: bool) -> void:
	_set_placement_mode(enabled)


func set_color_id(color_id: StringName) -> bool:
	var color_index: int = _color_ids.find(color_id)
	if color_index < 0:
		return false
	_clear_armed_guide_action(true)
	_eraser_mode = false
	_color_index = color_index
	_reset_stroke()
	_emit_hud_state("")
	return true


func set_eraser_mode(enabled: bool) -> void:
	if not _active:
		return
	_clear_armed_guide_action(true)
	_eraser_mode = enabled
	if _eraser_mode and _placing_grid:
		_placing_grid = false
	_reset_stroke()
	_selected_canvas_id = ""
	_update_aim()
	_refresh_stencil_visibility()
	_emit_hud_state("eraser selected" if _eraser_mode else "marker selected")


func is_eraser_mode() -> bool:
	return _eraser_mode


func arm_guide_action(action: int) -> bool:
	if (
		not _active
		or action not in [GuideAction.HIDE, GuideAction.RESTORE, GuideAction.FINALIZE]
	):
		return false
	if _armed_guide_action == action:
		_cancel_armed_guide_action()
		return false
	if _armed_guide_action == GuideAction.NONE:
		_armed_return_placement_mode = _placing_grid
		_armed_return_eraser_mode = _eraser_mode
	_armed_guide_action = action
	_placing_grid = true
	_eraser_mode = false
	_reset_stroke()
	_selected_canvas_id = ""
	_update_aim()
	_refresh_stencil_visibility()
	_emit_hud_state("click a grid to %s it" % _guide_action_verb(action))
	return true


func get_armed_guide_action() -> int:
	return _armed_guide_action


func cancel_armed_guide_action() -> void:
	_cancel_armed_guide_action()


func set_brush_size(value: int) -> bool:
	if _art_unlocks == null or not _art_unlocks.is_brush_size_unlocked(value):
		return false
	_set_brush_size(value)
	return true


func set_grid_size(value: int) -> bool:
	if _art_unlocks == null or not _art_unlocks.is_grid_size_unlocked(value):
		return false
	if _grid_size == value:
		return true
	_grid_size = value
	_rebuild_placement_preview()
	_update_previews()
	_emit_hud_state("")
	return true


func get_brush_size() -> int:
	return _brush_size


func get_grid_size() -> int:
	return _grid_size


func get_color_id() -> StringName:
	return _current_color_id()


func get_pointer_screen_position() -> Vector2:
	return _pointer_screen_position


func set_unlocked_color_ids(unlocked_ids: Array[StringName]) -> void:
	_color_ids = SurfaceDrawingPalette.filter_unlocked_ids(unlocked_ids)
	_color_index = clampi(_color_index, 0, _color_ids.size() - 1)
	_emit_hud_state("")


func _refresh_local_unlocks() -> void:
	if _art_unlocks == null:
		_color_ids = [SurfaceDrawingPalette.DEFAULT_COLOR_ID]
		return
	var previous_color: StringName = _current_color_id()
	_color_ids = _art_unlocks.get_unlocked_color_ids()
	var previous_index: int = _color_ids.find(previous_color)
	_color_index = previous_index if previous_index >= 0 else 0
	if not _art_unlocks.is_brush_size_unlocked(_brush_size):
		_brush_size = PlayerArtUnlocks.BASE_BRUSH_SIZE
	if not _art_unlocks.is_grid_size_unlocked(_grid_size):
		_grid_size = PlayerArtUnlocks.BASE_GRID_SIZE


func _owns_art_kit() -> bool:
	return _bag != null and _bag.owns_item(ArtShopStockType.ART_KIT_ITEM_ID)


func _local_entitlement() -> Dictionary:
	return {
		"has_kit": _owns_art_kit(),
		"unlock_mask": (
			_art_unlocks.get_unlock_mask() if _art_unlocks != null else 0
		),
	}


func _publish_local_entitlement() -> void:
	if _session == null or not _session.is_gameplay_session_active():
		return
	var entitlement: Dictionary = _local_entitlement()
	if _session.is_host():
		_peer_art_entitlements[_session.get_local_peer_id()] = entitlement
	else:
		submit_art_entitlement.rpc_id(
			1,
			_session.get_session_id(),
			bool(entitlement["has_kit"]),
			int(entitlement["unlock_mask"]),
		)


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	SurfaceDrawingProtocol.RELIABLE_CHANNEL,
)
func submit_art_entitlement(
	session_id: String,
	has_kit: bool,
	unlock_mask: int,
) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		_session == null
		or not _session.is_host()
		or not _session.is_authenticated_peer(sender_id)
		or session_id != _session.get_session_id()
		or unlock_mask < 0
		or (unlock_mask & ~PlayerArtUnlocks.ALL_UNLOCK_MASK) != 0
	):
		return
	_peer_art_entitlements[sender_id] = {
		"has_kit": has_kit,
		"unlock_mask": unlock_mask,
	}


func _peer_entitlement(peer_id: int) -> Dictionary:
	if _session != null and peer_id == _session.get_local_peer_id():
		return _local_entitlement()
	return Dictionary(_peer_art_entitlements.get(peer_id, {}))


func _peer_owns_art_kit(peer_id: int) -> bool:
	return bool(_peer_entitlement(peer_id).get("has_kit", false))


func _peer_can_place_grid(peer_id: int, grid_size: int) -> bool:
	var entitlement: Dictionary = _peer_entitlement(peer_id)
	return (
		bool(entitlement.get("has_kit", false))
		and _mask_unlocks_grid(
			int(entitlement.get("unlock_mask", 0)), grid_size
		)
	)


func _peer_can_edit(peer_id: int, request: Dictionary) -> bool:
	var entitlement: Dictionary = _peer_entitlement(peer_id)
	if not bool(entitlement.get("has_kit", false)):
		return false
	var unlock_mask: int = int(entitlement.get("unlock_mask", 0))
	if not _mask_unlocks_brush(unlock_mask, int(request["brush_size"])):
		return false
	for value: Variant in request["edits"]:
		var edit: Dictionary = value
		var color_id := StringName(str(edit.get("color_id", "")))
		if not color_id.is_empty() and not _mask_unlocks_color(
			unlock_mask, color_id
		):
			return false
	return true


func _mask_unlocks_color(unlock_mask: int, color_id: StringName) -> bool:
	if color_id == SurfaceDrawingPalette.DEFAULT_COLOR_ID:
		return true
	for product_id: StringName in PlayerArtUnlocks.COLOR_PRODUCTS:
		if (
			PlayerArtUnlocks.color_id_for_product(product_id) == color_id
			and _mask_owns_product(unlock_mask, product_id)
		):
			return true
	return false


func _mask_unlocks_brush(unlock_mask: int, brush_size: int) -> bool:
	if brush_size == PlayerArtUnlocks.BASE_BRUSH_SIZE:
		return true
	for product_id: StringName in PlayerArtUnlocks.BRUSH_PRODUCTS:
		if (
			PlayerArtUnlocks.brush_size_for_product(product_id) == brush_size
			and _mask_owns_product(unlock_mask, product_id)
		):
			return true
	return false


func _mask_unlocks_grid(unlock_mask: int, grid_size: int) -> bool:
	if grid_size == PlayerArtUnlocks.BASE_GRID_SIZE:
		return true
	for product_id: StringName in PlayerArtUnlocks.GRID_PRODUCTS:
		if (
			PlayerArtUnlocks.grid_size_for_product(product_id) == grid_size
			and _mask_owns_product(unlock_mask, product_id)
		):
			return true
	return false


func _mask_owns_product(unlock_mask: int, product_id: StringName) -> bool:
	var bit: int = PlayerArtUnlocks.get_product_bit(product_id)
	return bit >= 0 and (unlock_mask & (1 << bit)) != 0


func request_canvas_at_surface(
	origin: Vector3,
	normal: Vector3,
	tangent: Vector3,
) -> bool:
	if (
		not _drawing_available()
		or not _owns_art_kit()
		or _art_unlocks == null
		or not _art_unlocks.is_grid_size_unlocked(_grid_size)
		or normal.is_zero_approx()
		or tangent.is_zero_approx()
	):
		return false
	var data: Dictionary = {
		"request_id": _new_request_id("canvas"),
		"session_id": _session.get_session_id(),
		"origin": SurfaceDrawingProtocol.vector_to_array(origin),
		"normal": SurfaceDrawingProtocol.vector_to_array(normal.normalized()),
		"tangent": SurfaceDrawingProtocol.vector_to_array(tangent.normalized()),
		"width": _grid_size,
		"height": _grid_size,
		"cell_size": SurfaceDrawingProtocol.CELL_SIZE,
	}
	if _session.is_host():
		_handle_canvas_request(_session.get_local_peer_id(), data)
	else:
		submit_canvas_request.rpc_id(1, data)
	return true


func request_cell_edits(
	canvas_id: String,
	edits: Array[Dictionary],
	stroke_id: String = "",
) -> bool:
	if (
		not _drawing_available()
		or not _owns_art_kit()
		or canvas_id.is_empty()
		or edits.is_empty()
	):
		return false
	var resolved_stroke_id: String = stroke_id
	if resolved_stroke_id.is_empty():
		resolved_stroke_id = _new_request_id("stroke")
	_last_local_stroke_id = resolved_stroke_id
	var data: Dictionary = {
		"request_id": _new_request_id("edit"),
		"session_id": _session.get_session_id(),
		"canvas_id": canvas_id,
		"stroke_id": resolved_stroke_id,
		"brush_size": _brush_size,
		"edits": edits,
	}
	if not SurfaceDrawingProtocol.validate_edit_request(data):
		return false
	if _session.is_host():
		_handle_edit_request(_session.get_local_peer_id(), data)
	else:
		submit_edit_request.rpc_id(1, data)
	return true


func request_guide_visibility(
	canvas_id: String,
	should_be_visible: bool,
	should_finalize: bool = false,
) -> bool:
	if not _drawing_available() or not _owns_art_kit() or canvas_id.is_empty():
		return false
	var data: Dictionary = {
		"request_id": _new_request_id("guide"),
		"session_id": _session.get_session_id(),
		"canvas_id": canvas_id,
		"guide_visible": should_be_visible and not should_finalize,
		"finalized": should_finalize,
	}
	if not SurfaceDrawingProtocol.validate_guide_request(data):
		return false
	if _session.is_host():
		_handle_guide_request(_session.get_local_peer_id(), data)
	else:
		submit_guide_request.rpc_id(1, data)
	return true


func request_undo_last_stroke() -> bool:
	if (
		not _drawing_available()
		or not _owns_art_kit()
		or _last_local_stroke_id.is_empty()
	):
		_emit_hud_state("nothing to undo")
		return false
	var data: Dictionary = {
		"request_id": _new_request_id("undo"),
		"session_id": _session.get_session_id(),
		"stroke_id": _last_local_stroke_id,
	}
	if not SurfaceDrawingProtocol.validate_undo_request(data):
		return false
	_last_local_stroke_id = ""
	if _session.is_host():
		_handle_undo_request(_session.get_local_peer_id(), data)
	else:
		submit_undo_request.rpc_id(1, data)
		_emit_hud_state("undoing last stroke...")
	return true


func get_canvas_count() -> int:
	return _canvas_states.size()


func get_painted_cell_count() -> int:
	var count: int = 0
	for state: Dictionary in _canvas_states.values():
		count += (state.get("cells", []) as Array).size()
	return count


func clear_session_artwork() -> bool:
	if not _drawing_available() or not _session.is_host():
		return false
	_clear_session_artwork_state()
	for peer_id: int in _session.get_authenticated_peer_ids():
		if (
			peer_id != _session.get_local_peer_id()
			and _session.peer_supports_capability(
				peer_id, SurfaceDrawingProtocol.CAPABILITY
			)
		):
			receive_session_artwork_reset.rpc_id(
				peer_id, _session.get_session_id()
			)
	return true


func get_canvas_ids() -> Array[String]:
	var result: Array[String] = []
	for canvas_id: String in _canvas_states:
		result.append(canvas_id)
	result.sort()
	return result


func get_canvas_state(canvas_id: String) -> Dictionary:
	return Dictionary(_canvas_states.get(canvas_id, {})).duplicate(true)


func _process(_delta: float) -> void:
	if not _active:
		return
	_update_aim()
	if _placing_grid:
		return
	if _painting:
		_submit_current_brush(false)
	elif _erasing:
		_submit_current_brush(true)


func _drawing_available() -> bool:
	return (
		_session != null
		and _session.is_gameplay_session_active()
		and (
			_session.is_host()
			or _session.supports_server_capability(
				SurfaceDrawingProtocol.CAPABILITY
			)
		)
	)


func _update_aim() -> void:
	_aim_hit = _raycast_from_pointer()
	var previous_canvas_id: String = _selected_canvas_id
	var found_canvas_id: String = ""
	var nearest_plane_distance: float = INF
	if not _aim_hit.is_empty():
		var hit_position: Vector3 = _aim_hit["position"]
		for canvas_id: String in _canvas_nodes:
			var canvas: SurfaceDrawingCanvas = _canvas_nodes[canvas_id]
			if canvas.is_finalized():
				continue
			var plane_distance: float = canvas.get_surface_plane_distance(
				hit_position
			)
			if (
				canvas.contains_world_point(
					hit_position,
					SurfaceDrawingCanvas.SURFACE_SAMPLE_DEPTH + 0.05,
				)
				and plane_distance < nearest_plane_distance
			):
				found_canvas_id = canvas_id
				nearest_plane_distance = plane_distance
	_selected_canvas_id = found_canvas_id
	if previous_canvas_id != _selected_canvas_id:
		_reset_stroke()
	_update_previews()


func _raycast_from_pointer() -> Dictionary:
	if _local_player == null or not is_instance_valid(_local_player):
		return {}
	var camera: Camera3D = _local_player.get_gameplay_camera()
	if camera == null or not camera.current:
		return {}
	var from: Vector3 = camera.project_ray_origin(_pointer_screen_position)
	var direction: Vector3 = camera.project_ray_normal(
		_pointer_screen_position
	).normalized()
	var to: Vector3 = from + direction * MAX_DRAW_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(
		from,
		to,
		SOLID_SURFACE_MASK,
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [_local_player.get_rid()]
	var hit: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not _is_static_surface(hit.get("collider")):
		return {}
	return hit


func _update_previews() -> void:
	if _placing_grid:
		_update_placement_preview()
		_hide_brush_preview()
		return
	if _placement_preview != null:
		_placement_preview.hide()
	_update_brush_preview()


func _update_placement_preview() -> void:
	if _placement_preview == null or _aim_hit.is_empty():
		if _placement_preview != null:
			_placement_preview.hide()
		return
	var placement: Dictionary = _resolved_placement()
	var normal: Vector3 = placement["normal"]
	var hit_position: Vector3 = placement["origin"]
	var tangent: Vector3 = placement["tangent"]
	var bitangent: Vector3 = normal.cross(tangent).normalized()
	_placement_preview.global_transform = Transform3D(
		Basis(tangent, bitangent, normal),
		hit_position + normal * GRID_PREVIEW_SURFACE_OFFSET,
	)
	if _placement_preview_material != null:
		_placement_preview_material.albedo_color = (
			Color(0.34, 1.0, 0.72, 0.88)
			if bool(placement["snapped"])
			else Color(0.46, 0.91, 0.95, 0.72)
		)
	_placement_preview.show()


func _update_brush_preview() -> void:
	if (
		_brush_preview == null
		or _brush_preview_multimesh == null
		or _aim_hit.is_empty()
		or _selected_canvas_id.is_empty()
	):
		_hide_brush_preview()
		return
	var canvas: SurfaceDrawingCanvas = _canvas_nodes.get(
		_selected_canvas_id
	)
	if canvas == null:
		_hide_brush_preview()
		return
	var center: Vector2i = canvas.cell_at_world_point(_aim_hit["position"])
	var cells: Array[Vector2i] = _brush_cells(canvas, center)
	if cells.is_empty():
		_hide_brush_preview()
		return
	var root_inverse: Transform3D = _drawing_root.global_transform.affine_inverse()
	for index: int in range(cells.size()):
		var cell: Vector2i = cells[index]
		var world_transform: Transform3D = canvas.get_cell_surface_transform(
			cell.x, cell.y, 0.94
		)
		_brush_preview_multimesh.set_instance_transform(
			index, root_inverse * world_transform
		)
	_brush_preview_multimesh.visible_instance_count = cells.size()
	_brush_preview.show()


func _hide_brush_preview() -> void:
	if _brush_preview_multimesh != null:
		_brush_preview_multimesh.visible_instance_count = 0
	if _brush_preview != null:
		_brush_preview.hide()


func _hide_previews() -> void:
	_hide_brush_preview()
	if _placement_preview != null:
		_placement_preview.hide()


func _resolved_placement() -> Dictionary:
	var normal: Vector3 = _normalized_or(
		_aim_hit.get("normal", Vector3.UP), Vector3.UP
	)
	var states: Array[Dictionary] = []
	for state: Dictionary in _canvas_states.values():
		states.append(state)
	return SurfaceDrawingPlacement.resolve(
		_aim_hit.get("position", Vector3.ZERO),
		normal,
		_surface_tangent(normal),
		states,
		_grid_size,
	)


func _request_canvas_at_aim() -> void:
	if _aim_hit.is_empty():
		_emit_hud_state("aim at a solid surface before placing a grid")
		return
	var placement: Dictionary = _resolved_placement()
	var normal: Vector3 = placement["normal"]
	var origin: Vector3 = placement["origin"]
	if not _selected_canvas_id.is_empty():
		var existing_state: Dictionary = _canvas_states.get(
			_selected_canvas_id, {}
		)
		if not existing_state.is_empty():
			if not bool(existing_state.get("guide_visible", true)):
				if request_guide_visibility(_selected_canvas_id, true):
					if not _session.is_host():
						_emit_hud_state("restoring grid guide...")
			else:
				_emit_hud_state("a shared grid already covers this area")
			return
	if _overlaps_existing_canvas(origin, normal, _grid_size):
		_emit_hud_state("a shared grid already covers this area")
		return
	if request_canvas_at_surface(origin, normal, placement["tangent"]):
		_emit_hud_state(
			"placing snapped shared grid..."
			if bool(placement["snapped"])
			else "placing shared grid..."
		)


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	SurfaceDrawingProtocol.RELIABLE_CHANNEL,
)
func submit_canvas_request(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender_id):
		_handle_canvas_request(sender_id, data)


func _handle_canvas_request(peer_id: int, data: Dictionary) -> void:
	var requested_size: int = int(data.get("width", 0))
	if (
		not _session.is_host()
		or not SurfaceDrawingProtocol.validate_canvas_request(data)
		or str(data["session_id"]) != _session.get_session_id()
		or not _accept_request(peer_id, str(data["request_id"]))
		or not _peer_can_place_grid(peer_id, requested_size)
		or _canvas_states.size() >= SurfaceDrawingProtocol.MAX_CANVASES
		or _active_canvas_count() >= SurfaceDrawingProtocol.MAX_ACTIVE_CANVASES
		or _allocated_grid_cells() + requested_size * requested_size
			> SurfaceDrawingProtocol.MAX_SESSION_GRID_CELLS
	):
		return
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	var requested_origin: Vector3 = SurfaceDrawingProtocol.array_to_vector(
		data["origin"]
	)
	if (
		avatar == null
		or avatar.global_position.distance_to(requested_origin)
			> MAX_DRAW_DISTANCE + 2.0
	):
		return
	var requested_normal: Vector3 = SurfaceDrawingProtocol.array_to_vector(
		data["normal"]
	).normalized()
	var surface_hit: Dictionary = _validate_surface(
		requested_origin, requested_normal
	)
	if surface_hit.is_empty():
		return
	var normal: Vector3 = _normalized_or(
		surface_hit.get("normal", requested_normal), requested_normal
	)
	if _overlaps_existing_canvas(
		surface_hit["position"], normal, requested_size
	):
		return
	var tangent: Vector3 = SurfaceDrawingProtocol.array_to_vector(
		data["tangent"]
	)
	tangent = (tangent - normal * tangent.dot(normal)).normalized()
	if tangent.is_zero_approx():
		tangent = _surface_tangent(normal)
	_canvas_sequence += 1
	var canvas_id: String = "%s-%d" % [
		_session.get_session_id().left(16), _canvas_sequence,
	]
	var record: PeerRegistry.PeerRecord = _session.get_peer_record(peer_id)
	if record == null or not record.identity_authenticated:
		return
	var state: Dictionary = {
		"session_id": _session.get_session_id(),
		"canvas_id": canvas_id,
		"origin": SurfaceDrawingProtocol.vector_to_array(
			surface_hit["position"]
		),
		"normal": SurfaceDrawingProtocol.vector_to_array(normal),
		"tangent": SurfaceDrawingProtocol.vector_to_array(tangent),
		"width": requested_size,
		"height": requested_size,
		"cell_size": SurfaceDrawingProtocol.CELL_SIZE,
		"revision": 0,
		"guide_visible": true,
		"finalized": false,
		"layer": _canvas_sequence,
		"creator_fingerprint": record.identity_fingerprint,
		"cells": [],
	}
	_apply_canvas_state(state)
	_broadcast_canvas_state(state)
	_emit_hud_state("shared grid placed • everyone can draw here")


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	SurfaceDrawingProtocol.RELIABLE_CHANNEL,
)
func submit_guide_request(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender_id):
		_handle_guide_request(sender_id, data)


func _handle_guide_request(peer_id: int, data: Dictionary) -> void:
	if (
		not _session.is_host()
		or not SurfaceDrawingProtocol.validate_guide_request(data)
		or str(data["session_id"]) != _session.get_session_id()
		or not _accept_request(peer_id, str(data["request_id"]))
		or not _peer_owns_art_kit(peer_id)
	):
		return
	var canvas_id: String = str(data["canvas_id"])
	var state: Dictionary = _canvas_states.get(canvas_id, {})
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	if state.is_empty() or avatar == null:
		return
	var origin: Vector3 = SurfaceDrawingProtocol.array_to_vector(state["origin"])
	if avatar.global_position.distance_to(origin) > MAX_DRAW_DISTANCE + 2.0:
		return
	var was_finalized: bool = bool(state.get("finalized", false))
	var finalized: bool = bool(data["finalized"])
	if was_finalized:
		return
	var guide_visible: bool = bool(data["guide_visible"]) and not finalized
	if (
		bool(state.get("guide_visible", true)) == guide_visible
		and was_finalized == finalized
	):
		return
	state["revision"] = int(state["revision"]) + 1
	state["guide_visible"] = guide_visible
	state["finalized"] = finalized
	_canvas_states[canvas_id] = state
	var update: Dictionary = {
		"session_id": _session.get_session_id(),
		"canvas_id": canvas_id,
		"revision": int(state["revision"]),
		"guide_visible": guide_visible,
		"finalized": finalized,
	}
	var canvas: SurfaceDrawingCanvas = _canvas_nodes.get(canvas_id)
	if canvas != null:
		canvas.apply_guide_update(update)
	_broadcast_guide_update(update)
	_emit_hud_state(
		"grid finalized • artwork remains editable through new grids"
		if finalized
		else "grid guide restored" if guide_visible else "grid guide hidden"
	)
	_emit_artwork_changed()


func _submit_current_brush(erasing: bool, force: bool = false) -> void:
	if _selected_canvas_id.is_empty() or _aim_hit.is_empty():
		return
	var canvas: SurfaceDrawingCanvas = _canvas_nodes.get(
		_selected_canvas_id
	)
	if canvas == null:
		return
	var center: Vector2i = canvas.cell_at_world_point(_aim_hit["position"])
	if center.x < 0:
		return
	var stroke_key := Vector3i(
		_selected_canvas_id.hash(), center.x, center.y
	)
	var now: int = Time.get_ticks_msec()
	if (
		not force
		and (
			stroke_key == _last_edited_cell
			or now - _last_edit_msec < EDIT_INTERVAL_MSEC
		)
		):
		return
	var edits: Array[Dictionary] = []
	for cell: Vector2i in _brush_cells(canvas, center):
		edits.append({
			"x": cell.x,
			"y": cell.y,
			"color_id": "" if erasing else str(_current_color_id()),
		})
	if edits.is_empty():
		return
	_last_edited_cell = stroke_key
	_last_edit_msec = now
	if _active_stroke_id.is_empty():
		_begin_stroke()
	request_cell_edits(_selected_canvas_id, edits, _active_stroke_id)


func _brush_cells(
	canvas: SurfaceDrawingCanvas,
	center: Vector2i,
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if canvas == null or center.x < 0 or center.y < 0:
		return result
	var start_offset: int = -floori(float(_brush_size - 1) * 0.5)
	for y_offset: int in range(start_offset, start_offset + _brush_size):
		for x_offset: int in range(start_offset, start_offset + _brush_size):
			var cell := Vector2i(center.x + x_offset, center.y + y_offset)
			if (
				cell.x < 0
				or cell.x >= canvas.grid_width
				or cell.y < 0
				or cell.y >= canvas.grid_height
			):
				continue
			result.append(cell)
	return result


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	SurfaceDrawingProtocol.RELIABLE_CHANNEL,
)
func submit_edit_request(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender_id):
		_handle_edit_request(sender_id, data)


func _handle_edit_request(peer_id: int, data: Dictionary) -> void:
	if (
		not _session.is_host()
		or not SurfaceDrawingProtocol.validate_edit_request(data)
		or str(data["session_id"]) != _session.get_session_id()
		or not _accept_request(peer_id, str(data["request_id"]))
		or not _peer_can_edit(peer_id, data)
	):
		return
	var canvas_id: String = str(data["canvas_id"])
	var state: Dictionary = _canvas_states.get(canvas_id, {})
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	var record: PeerRegistry.PeerRecord = _session.get_peer_record(peer_id)
	if (
		state.is_empty()
		or bool(state.get("finalized", false))
		or avatar == null
		or record == null
	):
		return
	var stroke_id: String = str(data["stroke_id"])
	var grid_width: int = int(state["width"])
	var grid_height: int = int(state["height"])
	var mutations: Dictionary[String, Dictionary] = {}
	for edit_value: Variant in data["edits"]:
		var edit: Dictionary = edit_value
		var x: int = int(edit["x"])
		var y: int = int(edit["y"])
		if x >= grid_width or y >= grid_height:
			continue
		var cell_position: Vector3 = _state_cell_position(
			state, x, y
		)
		if (
			avatar.global_position.distance_to(cell_position)
				> MAX_DRAW_DISTANCE + 2.0
			or _validate_surface(
				cell_position,
				SurfaceDrawingProtocol.array_to_vector(state["normal"]),
			).is_empty()
		):
			continue
		var color_id := StringName(str(edit["color_id"]))
		var authoritative: Dictionary = {
			"x": x,
			"y": y,
			"color_id": str(color_id),
			"author_fingerprint": (
				record.identity_fingerprint if not color_id.is_empty() else ""
			),
		}
		_queue_cell_mutation(
			mutations,
			canvas_id,
			authoritative,
			peer_id,
			stroke_id,
		)
		_queue_overlapping_finished_mutations(
			mutations,
			canvas_id,
			cell_position,
			peer_id,
			stroke_id,
		)
	if mutations.is_empty():
		return
	_publish_cell_mutations(mutations)


func _queue_cell_mutation(
	mutations: Dictionary[String, Dictionary],
	canvas_id: String,
	edit: Dictionary,
	peer_id: int,
	stroke_id: String,
) -> void:
	var state: Dictionary = _canvas_states.get(canvas_id, {})
	if state.is_empty():
		return
	var x: int = int(edit["x"])
	var y: int = int(edit["y"])
	var cell_key: int = _cell_key_for_state(state, x, y)
	var canvas_mutations: Dictionary = mutations.get(
		canvas_id, {}
	)
	var current: Dictionary = (
		_cell_value_from_edit(canvas_mutations[cell_key])
		if canvas_mutations.has(cell_key)
		else _state_cell(state, x, y)
	)
	var next: Dictionary = _cell_value_from_edit(edit)
	if _same_cell_value(current, next):
		return
	_record_stroke_change(
		peer_id, stroke_id, canvas_id, x, y, current, next
	)
	canvas_mutations[cell_key] = edit.duplicate(true)
	mutations[canvas_id] = canvas_mutations
	_cell_last_stroke[_mutation_key(canvas_id, x, y)] = stroke_id


func _queue_overlapping_finished_mutations(
	mutations: Dictionary[String, Dictionary],
	target_canvas_id: String,
	world_position: Vector3,
	peer_id: int,
	stroke_id: String,
) -> void:
	var target_state: Dictionary = _canvas_states.get(target_canvas_id, {})
	if target_state.is_empty():
		return
	var target_normal: Vector3 = SurfaceDrawingProtocol.array_to_vector(
		target_state["normal"]
	).normalized()
	for canvas_id: String in _canvas_states:
		if canvas_id == target_canvas_id:
			continue
		var state: Dictionary = _canvas_states[canvas_id]
		if not bool(state.get("finalized", false)):
			continue
		var normal: Vector3 = SurfaceDrawingProtocol.array_to_vector(
			state["normal"]
		).normalized()
		if normal.dot(target_normal) < 0.9:
			continue
		var canvas: SurfaceDrawingCanvas = _canvas_nodes.get(canvas_id)
		if (
			canvas == null
			or not canvas.contains_world_point(
				world_position,
				SurfaceDrawingCanvas.SURFACE_SAMPLE_DEPTH + 0.05,
			)
		):
			continue
		var center_cell: Vector2i = canvas.cell_at_world_point(world_position)
		if center_cell.x < 0:
			continue
		for y_offset: int in range(-1, 2):
			for x_offset: int in range(-1, 2):
				var cell := Vector2i(
					center_cell.x + x_offset,
					center_cell.y + y_offset,
				)
				if (
					cell.x < 0
					or cell.x >= canvas.grid_width
					or cell.y < 0
					or cell.y >= canvas.grid_height
				):
					continue
				var relative: Vector3 = (
					canvas.get_cell_world_position(cell.x, cell.y)
					- world_position
				)
				if (
					absf(relative.dot(canvas.get_surface_tangent()))
						>= SurfaceDrawingProtocol.CELL_SIZE
					or absf(relative.dot(canvas.get_surface_bitangent()))
						>= SurfaceDrawingProtocol.CELL_SIZE
					or _state_cell(state, cell.x, cell.y).is_empty()
				):
					continue
				_queue_cell_mutation(
					mutations,
					canvas_id,
					{
						"x": cell.x,
						"y": cell.y,
						"color_id": "",
						"author_fingerprint": "",
					},
					peer_id,
					stroke_id,
				)


func _record_stroke_change(
	peer_id: int,
	stroke_id: String,
	canvas_id: String,
	x: int,
	y: int,
	before: Dictionary,
	after: Dictionary,
) -> void:
	var history: Dictionary = _stroke_history_by_peer.get(peer_id, {})
	if str(history.get("stroke_id", "")) != stroke_id:
		history = {"stroke_id": stroke_id, "changes": {}}
	var changes: Dictionary = history["changes"]
	var key: String = _mutation_key(canvas_id, x, y)
	var change: Dictionary = changes.get(key, {})
	if change.is_empty():
		change = {
			"canvas_id": canvas_id,
			"x": x,
			"y": y,
			"before": before.duplicate(true),
			"before_stroke": str(_cell_last_stroke.get(key, "")),
		}
	change["after"] = after.duplicate(true)
	changes[key] = change
	history["changes"] = changes
	_stroke_history_by_peer[peer_id] = history


func _publish_cell_mutations(
	mutations: Dictionary[String, Dictionary],
) -> void:
	var canvas_ids: Array[String] = mutations.keys()
	canvas_ids.sort()
	for canvas_id: String in canvas_ids:
		var state: Dictionary = _canvas_states.get(canvas_id, {})
		if state.is_empty():
			continue
		var cells: Dictionary[int, Dictionary] = _cells_by_key(
			state["cells"], int(state["width"])
		)
		var canvas_mutations: Dictionary = mutations[canvas_id]
		var cell_keys: Array[int] = []
		for cell_key_value: Variant in canvas_mutations.keys():
			cell_keys.append(int(cell_key_value))
		cell_keys.sort()
		var edits: Array[Dictionary] = []
		for cell_key: int in cell_keys:
			var edit: Dictionary = canvas_mutations[cell_key]
			if str(edit["color_id"]).is_empty():
				cells.erase(cell_key)
			else:
				cells[cell_key] = edit.duplicate(true)
			edits.append(edit.duplicate(true))
		if edits.is_empty():
			continue
		state["revision"] = int(state["revision"]) + 1
		state["cells"] = _sorted_cells(cells)
		_canvas_states[canvas_id] = state
		var update: Dictionary = {
			"session_id": _session.get_session_id(),
			"canvas_id": canvas_id,
			"revision": int(state["revision"]),
			"edits": edits,
		}
		var local_canvas: SurfaceDrawingCanvas = _canvas_nodes.get(canvas_id)
		if local_canvas != null:
			local_canvas.apply_update(update)
		_broadcast_canvas_update(update)
	_emit_artwork_changed()


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	SurfaceDrawingProtocol.RELIABLE_CHANNEL,
)
func submit_undo_request(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender_id):
		_handle_undo_request(sender_id, data)


func _handle_undo_request(peer_id: int, data: Dictionary) -> void:
	if (
		not _session.is_host()
		or not SurfaceDrawingProtocol.validate_undo_request(data)
		or str(data["session_id"]) != _session.get_session_id()
		or not _accept_request(peer_id, str(data["request_id"]))
		or not _peer_owns_art_kit(peer_id)
	):
		return
	var stroke_id: String = str(data["stroke_id"])
	var history: Dictionary = _stroke_history_by_peer.get(peer_id, {})
	var mutations: Dictionary[String, Dictionary] = {}
	var restored_count: int = 0
	if str(history.get("stroke_id", "")) == stroke_id:
		var changes: Dictionary = history.get("changes", {})
		for mutation_key: String in changes:
			if str(_cell_last_stroke.get(mutation_key, "")) != stroke_id:
				continue
			var change: Dictionary = changes[mutation_key]
			var canvas_id: String = str(change["canvas_id"])
			var state: Dictionary = _canvas_states.get(canvas_id, {})
			if state.is_empty():
				continue
			var x: int = int(change["x"])
			var y: int = int(change["y"])
			var current: Dictionary = _state_cell(state, x, y)
			if not _same_cell_value(current, change.get("after", {})):
				continue
			var before: Dictionary = change.get("before", {})
			var restored: Dictionary = _authoritative_edit_from_value(
				x, y, before
			)
			var canvas_mutations: Dictionary = mutations.get(
				canvas_id, {}
			)
			canvas_mutations[_cell_key_for_state(state, x, y)] = restored
			mutations[canvas_id] = canvas_mutations
			var previous_stroke: String = str(
				change.get("before_stroke", "")
			)
			if previous_stroke.is_empty():
				_cell_last_stroke.erase(mutation_key)
			else:
				_cell_last_stroke[mutation_key] = previous_stroke
			restored_count += 1
	_stroke_history_by_peer.erase(peer_id)
	if not mutations.is_empty():
		_publish_cell_mutations(mutations)
	_send_undo_result(peer_id, restored_count)


func _send_undo_result(peer_id: int, restored_count: int) -> void:
	if peer_id == _session.get_local_peer_id():
		_receive_undo_result(restored_count)
	else:
		receive_undo_result.rpc_id(peer_id, restored_count)


@rpc(
	"authority",
	"call_remote",
	"reliable",
	SurfaceDrawingProtocol.RELIABLE_CHANNEL,
)
func receive_undo_result(restored_count: int) -> void:
	_receive_undo_result(restored_count)


func _receive_undo_result(restored_count: int) -> void:
	_emit_hud_state(
		"last stroke undone"
		if restored_count > 0
		else "last stroke changed elsewhere and could not be undone"
	)


@rpc(
	"authority",
	"call_remote",
	"reliable",
	SurfaceDrawingProtocol.RELIABLE_CHANNEL,
)
func receive_canvas_state(data: Dictionary) -> void:
	_apply_canvas_state(data)


@rpc(
	"authority",
	"call_remote",
	"reliable",
	SurfaceDrawingProtocol.RELIABLE_CHANNEL,
)
func receive_canvas_update(data: Dictionary) -> void:
	_apply_canvas_update(data)


@rpc(
	"authority",
	"call_remote",
	"reliable",
	SurfaceDrawingProtocol.RELIABLE_CHANNEL,
)
func receive_guide_update(data: Dictionary) -> void:
	_apply_guide_update(data)


@rpc(
	"authority",
	"call_remote",
	"reliable",
	SurfaceDrawingProtocol.RELIABLE_CHANNEL,
)
func receive_session_artwork_reset(session_id: String) -> void:
	if session_id == _session.get_session_id():
		_clear_session_artwork_state()


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	SurfaceDrawingProtocol.RELIABLE_CHANNEL,
)
func request_canvas_snapshot(request_id: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		not _session.is_host()
		or not _session.is_authenticated_peer(sender_id)
		or request_id.is_empty()
		or request_id.length() > SurfaceDrawingProtocol.MAX_REQUEST_ID_LENGTH
		or not _accept_request(sender_id, request_id)
		or not _session.peer_supports_capability(
			sender_id, SurfaceDrawingProtocol.CAPABILITY
		)
	):
		return
	for state: Dictionary in _canvas_states.values():
		receive_canvas_state.rpc_id(sender_id, state)


func _apply_canvas_state(data: Dictionary) -> void:
	if (
		not SurfaceDrawingProtocol.validate_canvas_state(data)
		or str(data["session_id"]) != _session.get_session_id()
	):
		return
	var canvas_id: String = str(data["canvas_id"])
	var previous_state: Dictionary = _canvas_states.get(canvas_id, {})
	if (
		not previous_state.is_empty()
		and int(data["revision"]) <= int(previous_state["revision"])
	):
		return
	_canvas_states[canvas_id] = data.duplicate(true)
	var previous_canvas: SurfaceDrawingCanvas = _canvas_nodes.get(canvas_id)
	if previous_canvas != null:
		previous_canvas.queue_free()
	var canvas := SurfaceDrawingCanvas.new()
	canvas.name = "Drawing_%s" % canvas_id
	_drawing_root.add_child(canvas)
	if not canvas.setup(data, _relationships, SOLID_SURFACE_MASK):
		canvas.queue_free()
		return
	_canvas_nodes[canvas_id] = canvas
	_refresh_stencil_visibility()
	_emit_artwork_changed()
	if (
		_active
		and str(data.get("creator_fingerprint", ""))
			== _session.get_local_identity_fingerprint()
	):
		_emit_hud_state("shared grid placed • move and click to place another")


func _apply_canvas_update(data: Dictionary) -> void:
	if (
		not SurfaceDrawingProtocol.validate_canvas_update(data)
		or str(data["session_id"]) != _session.get_session_id()
	):
		return
	var canvas_id: String = str(data["canvas_id"])
	var state: Dictionary = _canvas_states.get(canvas_id, {})
	var canvas: SurfaceDrawingCanvas = _canvas_nodes.get(canvas_id)
	if state.is_empty() or canvas == null or int(data["revision"]) <= int(state["revision"]):
		return
	var cells: Dictionary[int, Dictionary] = _cells_by_key(
		state["cells"], int(state["width"])
	)
	var grid_width: int = int(state["width"])
	var grid_height: int = int(state["height"])
	for edit_value: Variant in data["edits"]:
		var edit: Dictionary = edit_value
		var x: int = int(edit["x"])
		var y: int = int(edit["y"])
		if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
			return
		var key: int = y * grid_width + x
		if str(edit["color_id"]).is_empty():
			cells.erase(key)
		else:
			cells[key] = edit.duplicate(true)
	state["revision"] = int(data["revision"])
	state["cells"] = _sorted_cells(cells)
	_canvas_states[canvas_id] = state
	canvas.apply_update(data)
	_emit_artwork_changed()


func _apply_guide_update(data: Dictionary) -> void:
	if (
		not SurfaceDrawingProtocol.validate_guide_update(data)
		or str(data["session_id"]) != _session.get_session_id()
	):
		return
	var canvas_id: String = str(data["canvas_id"])
	var state: Dictionary = _canvas_states.get(canvas_id, {})
	var canvas: SurfaceDrawingCanvas = _canvas_nodes.get(canvas_id)
	if (
		state.is_empty()
		or canvas == null
		or int(data["revision"]) <= int(state["revision"])
	):
		return
	state["revision"] = int(data["revision"])
	state["finalized"] = bool(data["finalized"])
	state["guide_visible"] = (
		bool(data["guide_visible"]) and not bool(data["finalized"])
	)
	_canvas_states[canvas_id] = state
	canvas.apply_guide_update(data)
	if _active:
		_emit_hud_state(
			"grid finalized • new grids may overlap its artwork"
			if bool(data["finalized"])
			else "grid guide restored"
			if bool(data["guide_visible"])
			else "grid guide hidden • pixels now meet edge-to-edge"
		)
	_emit_artwork_changed()


func _broadcast_canvas_state(data: Dictionary) -> void:
	for peer_id: int in _session.get_authenticated_peer_ids():
		if peer_id == _session.get_local_peer_id():
			continue
		if _session.peer_supports_capability(
			peer_id, SurfaceDrawingProtocol.CAPABILITY
		):
			receive_canvas_state.rpc_id(peer_id, data)


func _broadcast_canvas_update(data: Dictionary) -> void:
	for peer_id: int in _session.get_authenticated_peer_ids():
		if peer_id == _session.get_local_peer_id():
			continue
		if _session.peer_supports_capability(
			peer_id, SurfaceDrawingProtocol.CAPABILITY
		):
			receive_canvas_update.rpc_id(peer_id, data)


func _broadcast_guide_update(data: Dictionary) -> void:
	for peer_id: int in _session.get_authenticated_peer_ids():
		if peer_id == _session.get_local_peer_id():
			continue
		if _session.peer_supports_capability(
			peer_id, SurfaceDrawingProtocol.CAPABILITY
		):
			receive_guide_update.rpc_id(peer_id, data)


func _validate_surface(origin: Vector3, normal: Vector3) -> Dictionary:
	if _drawing_root == null or normal.is_zero_approx():
		return {}
	var world: World3D = _drawing_root.get_world_3d()
	if world == null:
		return {}
	var direction: Vector3 = normal.normalized()
	var query := PhysicsRayQueryParameters3D.create(
		origin + direction * SURFACE_VALIDATION_DEPTH,
		origin - direction * SURFACE_VALIDATION_DEPTH,
		SOLID_SURFACE_MASK,
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty() or not _is_static_surface(hit.get("collider")):
		return {}
	var hit_normal: Vector3 = _normalized_or(
		hit.get("normal", direction), direction
	)
	if absf(hit_normal.dot(direction)) < MIN_SURFACE_NORMAL_DOT:
		return {}
	return hit


func _is_static_surface(value: Variant) -> bool:
	return value is StaticBody3D


func _surface_tangent(normal: Vector3) -> Vector3:
	var camera: Camera3D = (
		_local_player.get_gameplay_camera() if _local_player != null else null
	)
	var candidate: Vector3 = (
		camera.global_basis.x if camera != null else Vector3.RIGHT
	)
	candidate = (candidate - normal * candidate.dot(normal)).normalized()
	if candidate.is_zero_approx():
		candidate = Vector3.UP.cross(normal).normalized()
	if candidate.is_zero_approx():
		candidate = Vector3.RIGHT
	return candidate


func _state_cell_position(state: Dictionary, x: int, y: int) -> Vector3:
	var origin: Vector3 = SurfaceDrawingProtocol.array_to_vector(state["origin"])
	var normal: Vector3 = SurfaceDrawingProtocol.array_to_vector(
		state["normal"]
	).normalized()
	var tangent: Vector3 = SurfaceDrawingProtocol.array_to_vector(
		state["tangent"]
	).normalized()
	var bitangent: Vector3 = normal.cross(tangent).normalized()
	var size: float = float(state["cell_size"])
	return (
		origin
		+ tangent * (float(x) + 0.5 - float(state["width"]) * 0.5) * size
		+ bitangent * (float(y) + 0.5 - float(state["height"]) * 0.5) * size
	)


func _overlaps_existing_canvas(
	origin: Vector3,
	normal: Vector3,
	requested_size: int,
) -> bool:
	for state: Dictionary in _canvas_states.values():
		if bool(state.get("finalized", false)):
			continue
		var existing_origin: Vector3 = SurfaceDrawingProtocol.array_to_vector(
			state["origin"]
		)
		var existing_normal: Vector3 = SurfaceDrawingProtocol.array_to_vector(
			state["normal"]
		).normalized()
		if absf(normal.dot(existing_normal)) < 0.85:
			continue
		var relative: Vector3 = origin - existing_origin
		if absf(relative.dot(existing_normal)) > SURFACE_VALIDATION_DEPTH:
			continue
		var tangent: Vector3 = SurfaceDrawingProtocol.array_to_vector(
			state["tangent"]
		).normalized()
		var bitangent: Vector3 = existing_normal.cross(tangent).normalized()
		var width: float = (
			(float(state["width"]) + float(requested_size))
			* float(state["cell_size"])
			* 0.5
		)
		var height: float = (
			(float(state["height"]) + float(requested_size))
			* float(state["cell_size"])
			* 0.5
		)
		var clearance: float = float(state["cell_size"]) * 0.5
		if (
			absf(relative.dot(tangent)) < width - clearance
			and absf(relative.dot(bitangent)) < height - clearance
		):
			return true
	return false


func _active_canvas_count() -> int:
	var count: int = 0
	for state: Dictionary in _canvas_states.values():
		if not bool(state.get("finalized", false)):
			count += 1
	return count


func _allocated_grid_cells() -> int:
	var count: int = 0
	for state: Dictionary in _canvas_states.values():
		count += int(state.get("width", 0)) * int(state.get("height", 0))
	return count


func _create_brush_preview() -> void:
	if _drawing_root == null:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_brush_preview_material = ShaderMaterial.new()
	_brush_preview_material.shader = BrushHighlightShader
	quad.material = _brush_preview_material
	_brush_preview_multimesh = MultiMesh.new()
	_brush_preview_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_brush_preview_multimesh.mesh = quad
	_brush_preview_multimesh.instance_count = (
		SurfaceDrawingProtocol.MAX_EDITS_PER_REQUEST
	)
	_brush_preview_multimesh.visible_instance_count = 0
	_brush_preview = MultiMeshInstance3D.new()
	_brush_preview.name = "MarkerBrushPreview"
	_brush_preview.multimesh = _brush_preview_multimesh
	_brush_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_brush_preview.hide()
	_drawing_root.add_child(_brush_preview)


func _create_placement_preview() -> void:
	_rebuild_placement_preview()


func _rebuild_placement_preview() -> void:
	if _drawing_root == null:
		return
	if _placement_preview != null:
		_placement_preview.queue_free()
		_placement_preview = null
	var mesh := ImmediateMesh.new()
	_placement_preview_material = StandardMaterial3D.new()
	_placement_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_placement_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_placement_preview_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_placement_preview_material.albedo_color = Color(0.46, 0.91, 0.95, 0.72)
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _placement_preview_material)
	var half_width: float = (
		float(_grid_size)
		* SurfaceDrawingProtocol.CELL_SIZE
		* 0.5
	)
	var half_height: float = (
		float(_grid_size)
		* SurfaceDrawingProtocol.CELL_SIZE
		* 0.5
	)
	for x: int in range(_grid_size + 1):
		var horizontal: float = (
			-half_width + float(x) * SurfaceDrawingProtocol.CELL_SIZE
		)
		mesh.surface_add_vertex(Vector3(horizontal, -half_height, 0.0))
		mesh.surface_add_vertex(Vector3(horizontal, half_height, 0.0))
	for y: int in range(_grid_size + 1):
		var vertical: float = (
			-half_height + float(y) * SurfaceDrawingProtocol.CELL_SIZE
		)
		mesh.surface_add_vertex(Vector3(-half_width, vertical, 0.0))
		mesh.surface_add_vertex(Vector3(half_width, vertical, 0.0))
	mesh.surface_end()
	_placement_preview = MeshInstance3D.new()
	_placement_preview.name = "MarkerGridPlacementPreview"
	_placement_preview.mesh = mesh
	_placement_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_placement_preview.hide()
	_drawing_root.add_child(_placement_preview)


func _set_placement_mode(enabled: bool) -> void:
	if not _active:
		return
	_clear_armed_guide_action(true)
	if _placing_grid == enabled:
		_emit_hud_state("")
		return
	_placing_grid = enabled
	_reset_stroke()
	_selected_canvas_id = ""
	_update_aim()
	_refresh_stencil_visibility()
	_emit_hud_state(
		(
			"click place/restore • shift hide • ctrl shift finish • shift scroll zoom"
			if _placing_grid
			else "click draw • shift click erase • ctrl z undo • shift scroll zoom"
		)
	)


func _execute_armed_guide_action() -> void:
	var action: int = _armed_guide_action
	match action:
		GuideAction.HIDE:
			_remove_selected_guide()
		GuideAction.RESTORE:
			_restore_selected_guide()
		GuideAction.FINALIZE:
			_finalize_selected_guide()
	_clear_armed_guide_action(true)
	_emit_hud_state("")


func _cancel_armed_guide_action() -> void:
	if _armed_guide_action == GuideAction.NONE:
		return
	_clear_armed_guide_action(true)
	_emit_hud_state("")


func _clear_armed_guide_action(restore_tool: bool) -> void:
	if _armed_guide_action == GuideAction.NONE:
		return
	_armed_guide_action = GuideAction.NONE
	if restore_tool:
		_placing_grid = _armed_return_placement_mode
		_eraser_mode = _armed_return_eraser_mode
	_armed_return_placement_mode = false
	_armed_return_eraser_mode = false
	_reset_stroke()
	_update_aim()
	_refresh_stencil_visibility()


func _guide_action_verb(action: int) -> String:
	match action:
		GuideAction.HIDE:
			return "hide"
		GuideAction.RESTORE:
			return "restore"
		GuideAction.FINALIZE:
			return "finish"
	return "use"


func _remove_selected_guide() -> void:
	if _selected_canvas_id.is_empty():
		_emit_hud_state("aim at a placed grid before removing its guide")
		return
	var state: Dictionary = _canvas_states.get(_selected_canvas_id, {})
	if state.is_empty():
		return
	if not bool(state.get("guide_visible", true)):
		_emit_hud_state("this grid guide is hidden • click to restore")
		return
	if request_guide_visibility(_selected_canvas_id, false):
		if not _session.is_host():
			_emit_hud_state("hiding grid guide...")


func _restore_selected_guide() -> void:
	if _selected_canvas_id.is_empty():
		_emit_hud_state("aim at a hidden grid before restoring its guide")
		return
	var state: Dictionary = _canvas_states.get(_selected_canvas_id, {})
	if state.is_empty() or bool(state.get("finalized", false)):
		return
	if bool(state.get("guide_visible", true)):
		_emit_hud_state("this grid guide is already visible")
		return
	if request_guide_visibility(_selected_canvas_id, true):
		if not _session.is_host():
			_emit_hud_state("restoring grid guide...")


func _finalize_selected_guide() -> void:
	if _selected_canvas_id.is_empty():
		_emit_hud_state("aim at an active grid before finishing it")
		return
	var state: Dictionary = _canvas_states.get(_selected_canvas_id, {})
	if state.is_empty() or bool(state.get("finalized", false)):
		return
	if request_guide_visibility(_selected_canvas_id, false, true):
		if not _session.is_host():
			_emit_hud_state("finishing grid • artwork remains shared...")


func _clamped_pointer_position(value: Vector2) -> Vector2:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	return Vector2(
		clampf(value.x, POINTER_EDGE_MARGIN, viewport_size.x - POINTER_EDGE_MARGIN),
		clampf(value.y, POINTER_EDGE_MARGIN, viewport_size.y - POINTER_EDGE_MARGIN),
	)


func _set_pointer_from_input(
	event_position: Vector2,
	pointer_screen_position: Vector2,
) -> void:
	# GameUI receives input through a scaled SubViewport, so event_position is
	# expressed in that UI viewport's render coordinates. Camera3D ray methods
	# require coordinates in the camera's root viewport instead. GameUI supplies
	# that authoritative window position; direct callers may still use an event
	# position when they share this service's viewport.
	var resolved_position: Vector2 = pointer_screen_position
	if not _is_valid_pointer_screen_position(resolved_position):
		resolved_position = event_position
	_pointer_screen_position = _clamped_pointer_position(resolved_position)


func _is_valid_pointer_screen_position(value: Vector2) -> bool:
	return value.x >= 0.0 and value.y >= 0.0


func _cycle_color(direction: int) -> void:
	if _color_ids.is_empty():
		return
	_clear_armed_guide_action(true)
	_eraser_mode = false
	_color_index = posmod(_color_index + direction, _color_ids.size())
	_reset_stroke()
	_emit_hud_state("")


func _set_brush_size(value: int) -> void:
	var requested: int = clampi(value, 1, 4)
	if _art_unlocks != null and not _art_unlocks.is_brush_size_unlocked(
		requested
	):
		return
	_brush_size = requested
	_reset_stroke()
	_emit_hud_state("")


func _current_color_id() -> StringName:
	return (
		_color_ids[_color_index]
		if not _color_ids.is_empty()
		else SurfaceDrawingPalette.DEFAULT_COLOR_ID
	)


func _current_color() -> Color:
	return SurfaceDrawingPalette.get_color(_current_color_id())


func _emit_hud_state(status: String) -> void:
	hud_state_changed.emit(
		_active,
		"place grid" if _placing_grid else "marker",
		SurfaceDrawingPalette.get_display_name(_current_color_id()),
		_current_color(),
		_brush_size,
		_grid_size,
		status,
	)


func _refresh_stencil_visibility() -> void:
	for canvas_id: String in _canvas_nodes:
		_canvas_nodes[canvas_id].set_stencil_visible(_active)


func _begin_stroke() -> void:
	_active_stroke_id = _new_request_id("stroke")
	_last_edited_cell = Vector3i(-1, -1, -1)


func _finish_stroke() -> void:
	_painting = false
	_erasing = false
	_active_stroke_id = ""
	_last_edited_cell = Vector3i(-1, -1, -1)


func _reset_stroke() -> void:
	_finish_stroke()


func _new_request_id(prefix: String) -> String:
	_request_sequence += 1
	return "%s-%d-%d" % [prefix, Time.get_ticks_msec(), _request_sequence]


func _cells_by_key(
	values: Array,
	grid_width: int,
) -> Dictionary[int, Dictionary]:
	var result: Dictionary[int, Dictionary] = {}
	for value: Variant in values:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var cell: Dictionary = value
		var key: int = (
			int(cell.get("y", -1)) * grid_width
			+ int(cell.get("x", -1))
		)
		result[key] = cell.duplicate(true)
	return result


func _state_cell(state: Dictionary, x: int, y: int) -> Dictionary:
	var cells: Dictionary[int, Dictionary] = _cells_by_key(
		state.get("cells", []), int(state["width"])
	)
	return Dictionary(
		cells.get(_cell_key_for_state(state, x, y), {})
	).duplicate(true)


func _cell_value_from_edit(edit: Dictionary) -> Dictionary:
	if edit.is_empty() or str(edit.get("color_id", "")).is_empty():
		return {}
	return {
		"color_id": str(edit["color_id"]),
		"author_fingerprint": str(edit.get("author_fingerprint", "")),
	}


func _authoritative_edit_from_value(
	x: int,
	y: int,
	value: Dictionary,
) -> Dictionary:
	return {
		"x": x,
		"y": y,
		"color_id": str(value.get("color_id", "")),
		"author_fingerprint": str(value.get("author_fingerprint", "")),
	}


func _same_cell_value(first: Dictionary, second: Dictionary) -> bool:
	return (
		str(first.get("color_id", "")) == str(second.get("color_id", ""))
		and str(first.get("author_fingerprint", ""))
			== str(second.get("author_fingerprint", ""))
	)


func _cell_key_for_state(state: Dictionary, x: int, y: int) -> int:
	return y * int(state["width"]) + x


func _mutation_key(canvas_id: String, x: int, y: int) -> String:
	return "%s:%d:%d" % [canvas_id, x, y]


func _sorted_cells(values: Dictionary[int, Dictionary]) -> Array[Dictionary]:
	var keys: Array[int] = values.keys()
	keys.sort()
	var result: Array[Dictionary] = []
	for key: int in keys:
		result.append(values[key].duplicate(true))
	return result


func _normalized_or(value: Variant, fallback: Vector3) -> Vector3:
	var vector: Vector3 = value if typeof(value) == TYPE_VECTOR3 else fallback
	return fallback if vector.is_zero_approx() else vector.normalized()


func _accept_request(peer_id: int, request_id: String) -> bool:
	var recent_ids: PackedStringArray = _peer_request_ids.get(
		peer_id, PackedStringArray()
	)
	if request_id in recent_ids:
		return false
	var now: int = Time.get_ticks_msec()
	var request_times: PackedInt64Array = _peer_request_times.get(
		peer_id, PackedInt64Array()
	)
	while (
		not request_times.is_empty()
		and now - request_times[0] >= REQUEST_WINDOW_MSEC
	):
		request_times.remove_at(0)
	if request_times.size() >= MAX_REQUESTS_PER_WINDOW:
		_peer_request_times[peer_id] = request_times
		return false
	request_times.append(now)
	recent_ids.append(request_id)
	while recent_ids.size() > MAX_RECENT_REQUEST_IDS:
		recent_ids.remove_at(0)
	_peer_request_times[peer_id] = request_times
	_peer_request_ids[peer_id] = recent_ids
	return true


func _on_peer_removed(peer_id: int) -> void:
	_peer_request_times.erase(peer_id)
	_peer_request_ids.erase(peer_id)
	_stroke_history_by_peer.erase(peer_id)
	_peer_art_entitlements.erase(peer_id)


func _on_local_art_entitlement_changed() -> void:
	if _active and not _owns_art_kit():
		deactivate()
	_publish_local_entitlement()


func _on_local_art_unlocks_changed(_unlock_mask: int) -> void:
	_refresh_local_unlocks()
	_rebuild_placement_preview()
	_publish_local_entitlement()
	_emit_hud_state("")


func _on_relationship_changed(_fingerprint: String) -> void:
	for canvas: SurfaceDrawingCanvas in _canvas_nodes.values():
		canvas.refresh_relationship_visibility()


func _on_session_state_changed(state: NetworkSession.State) -> void:
	if state == NetworkSession.State.JOINED_CLIENT:
		_publish_local_entitlement()
		request_canvas_snapshot.rpc_id(1, _new_request_id("snapshot"))
		return
	if state in [
		NetworkSession.State.PRIVATE_HOST,
		NetworkSession.State.OPEN_HOST,
	]:
		_publish_local_entitlement()
		return
	if state not in [
		NetworkSession.State.INACTIVE,
		NetworkSession.State.DISCONNECTING,
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		return
	deactivate()
	_clear_session_artwork_state()
	_canvas_sequence = 0
	_peer_request_times.clear()
	_peer_request_ids.clear()
	_peer_art_entitlements.clear()


func _clear_session_artwork_state() -> void:
	_canvas_states.clear()
	for canvas: SurfaceDrawingCanvas in _canvas_nodes.values():
		canvas.queue_free()
	_canvas_nodes.clear()
	_canvas_sequence = 0
	_selected_canvas_id = ""
	_stroke_history_by_peer.clear()
	_cell_last_stroke.clear()
	_last_local_stroke_id = ""
	_hide_previews()
	_emit_artwork_changed()


func _emit_artwork_changed() -> void:
	session_artwork_changed.emit(
		get_canvas_count(), get_painted_cell_count()
	)
