class_name NetworkWorldSpawnService
extends Node

const FishCatchType = preload("res://fish/fish_catch.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishExperienceType = preload("res://fish/fish_experience.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const FishQualityType = preload("res://fish/fish_quality.gd")
const FishSelectorType = preload("res://fish/fish_selector.gd")
const GatherableCatalogType = preload("res://gathering/gatherable_catalog.gd")
const GatherableDataType = preload("res://gathering/gatherable_data.gd")
const WorldGatherableType = preload("res://gathering/world_gatherable.gd")
const TestWorldType = preload("res://world/test_world.gd")
const CalendarSeasonType = preload("res://world/calendar_season.gd")

signal local_capture_received(fish_catch: FishCatch)
signal local_interaction_finished(accepted: bool, message: String)

const SNAPSHOT_INTERVAL_SECONDS: float = 0.2
const CAPACITY_RESPONSE_TIMEOUT_SECONDS: float = 3.0
const MAX_REQUEST_ID_LENGTH: int = 128
const MAX_LEDGER_ENTRIES: int = 96

var _session: NetworkSession
var _spawn_service: PlayerSpawnService
var _world: TestWorldType
var _world_root: Node3D
var _world_time: WorldTimeService
var _catalog: GatherableCatalogType
var _fish_catalog: FishPoolType
var _local_inventory: FishInventory
var _local_collection: CollectionLog
var _local_capacity: PlayerCoolerCapacity
var _local_experience: PlayerExperience
var _save_manager: PlayerSaveManager
var _item_use: NetworkItemUseService

var _entities: Dictionary = {}
var _presentations: Dictionary = {}
var _entity_revisions: Dictionary = {}
var _surface_triangles: Dictionary = {}
var _surface_areas: Dictionary = {}
var _surface_total_areas: Dictionary = {}
var _spawn_anchor_positions: Dictionary = {}
var _respawns: Array[Dictionary] = []
var _next_respawn_by_type: Dictionary[StringName, float] = {}
var _charge_requests: Dictionary = {}
var _pending_captures: Dictionary = {}
var _received_results: Dictionary = {}
var _showcase_deadlines: Dictionary = {}
var _envelope_sequence: int = 0
var _snapshot_elapsed: float = 0.0
var _population_session_id: String = ""
var _rng := RandomNumberGenerator.new()


func setup(
	session: NetworkSession,
	spawn_service: PlayerSpawnService,
	world: TestWorldType,
	world_root: Node3D,
	catalog: GatherableCatalogType,
	fish_catalog: FishPoolType,
	local_inventory: FishInventory,
	local_collection: CollectionLog,
	local_capacity: PlayerCoolerCapacity,
	local_experience: PlayerExperience,
	save_manager: PlayerSaveManager,
	item_use: NetworkItemUseService,
	world_time: WorldTimeService = null,
) -> void:
	_session = session
	_spawn_service = spawn_service
	_world = world
	_world_root = world_root
	_catalog = catalog
	_fish_catalog = fish_catalog
	_local_inventory = local_inventory
	_local_collection = local_collection
	_local_capacity = local_capacity
	_local_experience = local_experience
	_save_manager = save_manager
	_item_use = item_use
	_world_time = world_time
	_rng.randomize()
	_session.peer_authenticated.connect(_on_peer_authenticated)
	_session.peer_removed.connect(_on_peer_removed)
	_session.state_changed.connect(_on_session_state_changed)
	if (
		_world_time != null
		and not _world_time.calendar_date_changed.is_connected(
			_on_calendar_date_changed
		)
	):
		_world_time.calendar_date_changed.connect(_on_calendar_date_changed)
	set_physics_process(true)
	_begin_population_if_ready.call_deferred()


func begin_local_interaction() -> String:
	if (
		_session == null
		or not _session.is_gameplay_session_active()
		or (
			not _session.is_host()
			and not _session.supports_server_capability(
				NetworkWorldSpawnProtocol.CAPABILITY
			)
		)
	):
		local_interaction_finished.emit(false, "Catching is unavailable.")
		return ""
	var request_id: String = _new_id("gather")
	var data: Dictionary = {
		"session_id": _session.get_session_id(),
		"request_id": request_id,
	}
	if _session.is_host():
		_handle_interaction_begin(_session.get_local_peer_id(), data)
	else:
		submit_interaction_begin.rpc_id(1, data)
	return request_id


func finish_local_interaction(
	request_id: String,
	entity_id: String,
	target_position: Vector3,
) -> void:
	if request_id.is_empty() or not target_position.is_finite():
		return
	var data: Dictionary = {
		"session_id": _session.get_session_id(),
		"request_id": request_id,
		"entity_id": entity_id,
		"target_position": NetworkWorldSpawnProtocol.vector3_to_array(
			target_position
		),
	}
	if _session.is_host():
		_handle_interaction_finish(_session.get_local_peer_id(), data)
	else:
		submit_interaction_finish.rpc_id(1, data)


func cancel_local_interaction(request_id: String) -> void:
	if request_id.is_empty() or _session == null:
		return
	if _session.is_host():
		_handle_interaction_cancel(_session.get_local_peer_id(), request_id)
	else:
		submit_interaction_cancel.rpc_id(1, request_id)


func find_entity_near(
	position: Vector3,
	radius: float,
) -> String:
	var best_id: String = ""
	var best_distance_squared: float = radius * radius
	for entity_id: String in _entities:
		var state: Dictionary = _entities[entity_id]
		if bool(state.get("locked", false)):
			continue
		var entity_position: Vector3 = state.get("position", Vector3.ZERO)
		var distance_squared: float = entity_position.distance_squared_to(
			position
		)
		if distance_squared <= best_distance_squared:
			best_distance_squared = distance_squared
			best_id = entity_id
	return best_id


func find_capture_target(
	position: Vector3,
	tool_id: StringName,
) -> String:
	if tool_id.is_empty():
		return ""
	var best_id: String = ""
	var best_distance_squared: float = INF
	for entity_id: String in _entities:
		var state: Dictionary = _entities[entity_id]
		if bool(state.get("locked", false)):
			continue
		var entry := state.get("data") as GatherableDataType
		if entry == null or entry.required_tool_id != tool_id:
			continue
		var entity_position: Vector3 = state.get("position", Vector3.ZERO)
		var distance_squared: float = entity_position.distance_squared_to(
			position
		)
		if (
			distance_squared <= entry.capture_radius * entry.capture_radius
			and distance_squared <= best_distance_squared
		):
			best_distance_squared = distance_squared
			best_id = entity_id
	return best_id


func get_charge_duration_for_tool(tool_id: StringName) -> float:
	var duration: float = 0.0
	if _catalog == null or tool_id.is_empty():
		return duration
	for entry: GatherableDataType in _catalog.get_available_entries(
		_current_season()
	):
		if entry.required_tool_id == tool_id:
			duration = maxf(duration, entry.charge_duration)
	return duration


func get_entry_for_entity(entity_id: String) -> GatherableDataType:
	var state: Dictionary = _entities.get(entity_id, {})
	return state.get("data") as GatherableDataType


func _physics_process(delta: float) -> void:
	if (
		_session == null
		or not _session.is_host()
		or not _session.is_gameplay_session_active()
	):
		return
	_begin_population_if_ready()
	_update_pending_capture_timeouts()
	_update_respawns()
	_update_showcase_deadlines()
	_update_host_entities(delta)
	_snapshot_elapsed += delta
	if _snapshot_elapsed >= SNAPSHOT_INTERVAL_SECONDS:
		_snapshot_elapsed = fmod(
			_snapshot_elapsed,
			SNAPSHOT_INTERVAL_SECONDS,
		)
		_broadcast_entity_snapshots()


func _begin_population_if_ready() -> void:
	if (
		_session == null
		or not _session.is_host()
		or not _session.is_gameplay_session_active()
		or _catalog == null
		or _world == null
		or _world_root == null
	):
		return
	var session_id: String = _session.get_session_id()
	if session_id.is_empty() or session_id == _population_session_id:
		return
	_clear_world()
	_population_session_id = session_id
	for entry: GatherableDataType in _catalog.get_available_entries(
		_current_season()
	):
		_cache_spawn_surface(entry)
		for _spawn_index: int in entry.population:
			_spawn_entity(entry)


func _cache_spawn_surface(entry: GatherableDataType) -> void:
	if (
		entry == null
		or _surface_triangles.has(entry.type_id)
		or _spawn_anchor_positions.has(entry.type_id)
	):
		return
	if not entry.spawn_anchor_set_id.is_empty():
		var anchor_positions: PackedVector3Array = (
			_world.get_gatherable_spawn_positions(entry.spawn_anchor_set_id)
		)
		_spawn_anchor_positions[entry.type_id] = anchor_positions
		if anchor_positions.is_empty():
			push_warning(
				"No gatherable spawn anchors were found for %s." % entry.type_id
			)
		return
	var triangles: Array[PackedVector3Array]
	if not entry.diggable_area_id.is_empty():
		triangles = _world.get_diggable_area_triangles(entry.diggable_area_id)
	else:
		triangles = _world.get_spawn_surface_triangles(
			entry.surface_materials,
			entry.minimum_surface_y,
		)
	var areas := PackedFloat32Array()
	var total_area: float = 0.0
	for triangle: PackedVector3Array in triangles:
		var area: float = (
			(triangle[1] - triangle[0]).cross(
				triangle[2] - triangle[0]
			).length() * 0.5
		)
		total_area += area
		areas.append(total_area)
	_surface_triangles[entry.type_id] = triangles
	_surface_areas[entry.type_id] = areas
	_surface_total_areas[entry.type_id] = total_area
	if triangles.is_empty():
		push_warning(
			"No valid spawn surface was found for %s." % entry.type_id
		)


func _spawn_entity(entry: GatherableDataType) -> void:
	var position: Vector3 = _sample_surface_position(entry)
	if not position.is_finite():
		return
	var target: Vector3 = (
		position
		if entry.is_stationary_spawn()
		else _sample_surface_position(entry, position, entry.roam_radius)
	)
	var quality: int = FishQualityType.roll(_rng)
	var entity_id: String = _new_id("world")
	var state: Dictionary = {
		"entity_id": entity_id,
		"type_id": entry.type_id,
		"data": entry,
		"position": position,
		"target": target,
		"yaw": _rng.randf_range(-PI, PI),
		"quality": quality,
		"revision": 1,
		"locked": false,
		"expires_at": (
			_now() + entry.active_lifetime_seconds
			if entry.active_lifetime_seconds > 0.0
			else INF
		),
	}
	if not (state["target"] as Vector3).is_finite():
		state["target"] = position
	_entities[entity_id] = state
	var envelope: Dictionary = _make_envelope(
		&"spawn",
		{"entity": _state_to_network(state)},
	)
	_apply_envelope(envelope)
	receive_world_envelope.rpc(envelope)


func _update_host_entities(delta: float) -> void:
	for entity_id: String in _entities.keys():
		var state: Dictionary = _entities.get(entity_id, {})
		if state.is_empty() or bool(state.get("locked", false)):
			continue
		var entry := state.get("data") as GatherableDataType
		if entry == null:
			continue
		if _now() >= float(state.get("expires_at", INF)):
			_despawn_entity(entity_id, &"expired", false, true)
			continue
		if entry.is_stationary_spawn():
			continue
		var quality: int = _get_state_quality(state)
		var position: Vector3 = state["position"]
		var target: Vector3 = state["target"]
		var horizontal_delta := Vector3(
			target.x - position.x,
			0.0,
			target.z - position.z,
		)
		if horizontal_delta.length_squared() <= 0.04:
			target = _sample_surface_position(
				entry,
				position,
				entry.roam_radius,
			)
			if not target.is_finite():
				target = position
			state["target"] = target
			horizontal_delta = Vector3(
				target.x - position.x,
				0.0,
				target.z - position.z,
			)
		if not horizontal_delta.is_zero_approx():
			var step: float = minf(
				entry.get_movement_speed_for_quality(quality) * delta,
				horizontal_delta.length(),
			)
			var direction: Vector3 = horizontal_delta.normalized()
			position.x += direction.x * step
			position.z += direction.z * step
			position.y = lerpf(
				position.y,
				target.y,
				minf(step / maxf(horizontal_delta.length(), 0.001), 1.0),
			)
			state["yaw"] = atan2(-direction.x, -direction.z)
		state["position"] = position
		_entities[entity_id] = state
		if entry.can_be_scared() and _should_scare(entry, position, quality):
			_despawn_entity(entity_id, &"scared", true, true)


func _should_scare(
	entry: GatherableDataType,
	position: Vector3,
	quality: int,
) -> bool:
	var scare_radius: float = entry.get_scare_radius_for_quality(quality)
	var radius_squared: float = scare_radius * scare_radius
	for peer_id: int in _spawn_service.get_peer_ids():
		var avatar: Player = _spawn_service.get_avatar(peer_id)
		if (
			avatar == null
			or not avatar.is_moving_horizontally()
			or avatar.is_sneaking()
		):
			continue
		var delta := Vector2(
			avatar.global_position.x - position.x,
			avatar.global_position.z - position.z,
		)
		if delta.length_squared() <= radius_squared:
			return true
	return false


func _sample_surface_position(
	entry: GatherableDataType,
	origin: Vector3 = Vector3(INF, INF, INF),
	maximum_distance: float = INF,
) -> Vector3:
	_cache_spawn_surface(entry)
	if not entry.spawn_anchor_set_id.is_empty():
		return _sample_anchor_position(entry, origin, maximum_distance)
	var triangles: Array = _surface_triangles.get(entry.type_id, [])
	var cumulative_areas: PackedFloat32Array = _surface_areas.get(
		entry.type_id,
		PackedFloat32Array(),
	)
	var total_area: float = float(
		_surface_total_areas.get(entry.type_id, 0.0)
	)
	if triangles.is_empty() or total_area <= 0.0:
		return Vector3(INF, INF, INF)
	var attempts: int = 48 if is_finite(maximum_distance) else 1
	var fallback: Vector3 = Vector3(INF, INF, INF)
	for _attempt: int in attempts:
		var roll: float = _rng.randf() * total_area
		var triangle_index: int = cumulative_areas.bsearch(roll)
		triangle_index = clampi(triangle_index, 0, triangles.size() - 1)
		var triangle: PackedVector3Array = triangles[triangle_index]
		var root: float = sqrt(_rng.randf())
		var barycentric_b: float = root * (1.0 - _rng.randf())
		var barycentric_c: float = root - barycentric_b
		var point: Vector3 = (
			triangle[0] * (1.0 - root)
			+ triangle[1] * barycentric_b
			+ triangle[2] * barycentric_c
		)
		fallback = point
		if (
			not is_finite(maximum_distance)
			or Vector2(point.x - origin.x, point.z - origin.z).length()
			<= maximum_distance
		):
			return point
	if origin.is_finite() and is_finite(maximum_distance):
		return origin
	return fallback


func _sample_anchor_position(
	entry: GatherableDataType,
	origin: Vector3,
	maximum_distance: float,
) -> Vector3:
	var anchors: PackedVector3Array = _spawn_anchor_positions.get(
		entry.type_id,
		PackedVector3Array(),
	)
	var candidates := PackedVector3Array()
	for anchor: Vector3 in anchors:
		if not anchor.is_finite() or _anchor_is_occupied(entry.type_id, anchor):
			continue
		if (
			origin.is_finite()
			and is_finite(maximum_distance)
			and anchor.distance_to(origin) > maximum_distance
		):
			continue
		candidates.append(anchor)
	if candidates.is_empty():
		return Vector3(INF, INF, INF)
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _anchor_is_occupied(type_id: StringName, anchor: Vector3) -> bool:
	for state: Dictionary in _entities.values():
		if StringName(state.get("type_id", StringName())) != type_id:
			continue
		var position: Variant = state.get("position")
		if (
			typeof(position) == TYPE_VECTOR3
			and (position as Vector3).distance_squared_to(anchor) <= 0.0001
		):
			return true
	return false


func _broadcast_entity_snapshots() -> void:
	if _entities.is_empty():
		return
	var snapshots: Array[Dictionary] = []
	for entity_id: String in _entities:
		var state: Dictionary = _entities[entity_id]
		state["revision"] = int(state["revision"]) + 1
		_entities[entity_id] = state
		snapshots.append(_state_to_network(state))
	while not snapshots.is_empty():
		var chunk: Array[Dictionary] = []
		var chunk_size: int = mini(
			NetworkWorldSpawnProtocol.SNAPSHOT_ENTITIES_PER_ENVELOPE,
			snapshots.size(),
		)
		for _index: int in chunk_size:
			chunk.append(snapshots.pop_front())
		var envelope: Dictionary = _make_envelope(
			&"snapshot",
			{"entities": chunk},
		)
		_apply_envelope(envelope)
		receive_world_snapshot_envelope.rpc(envelope)


func _despawn_entity(
	entity_id: String,
	reason: StringName,
	with_dust: bool,
	schedule_respawn: bool,
) -> void:
	var state: Dictionary = _entities.get(entity_id, {})
	if state.is_empty():
		return
	var entry := state.get("data") as GatherableDataType
	_entities.erase(entity_id)
	var envelope: Dictionary = _make_envelope(
		&"despawn",
		{
			"entity_id": entity_id,
			"reason": str(reason),
			"with_dust": with_dust,
		},
	)
	_apply_envelope(envelope)
	receive_world_envelope.rpc(envelope)
	if schedule_respawn and entry != null:
		_respawns.append({
			"type_id": entry.type_id,
			"due": _now() + entry.get_respawn_delay(reason, _rng),
		})


func _update_respawns() -> void:
	var now: float = _now()
	var remaining: Array[Dictionary] = []
	for respawn: Dictionary in _respawns:
		var type_id := StringName(str(respawn.get("type_id", "")))
		var next_allowed: float = float(
			_next_respawn_by_type.get(type_id, 0.0)
		)
		if now < maxf(float(respawn.get("due", INF)), next_allowed):
			remaining.append(respawn)
			continue
		var entry: GatherableDataType = _catalog.get_entry(
			type_id
		)
		if entry != null and entry.is_available(_current_season()):
			_spawn_entity(entry)
			_next_respawn_by_type[type_id] = (
				now + entry.minimum_respawn_spacing_seconds
			)
	_respawns = remaining


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	NetworkWorldSpawnProtocol.RELIABLE_CHANNEL,
)
func submit_interaction_begin(data: Dictionary) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(peer_id):
		_handle_interaction_begin(peer_id, data)


func _handle_interaction_begin(peer_id: int, data: Dictionary) -> void:
	var request_id: String = str(data.get("request_id", ""))
	if (
		str(data.get("session_id", "")) != _session.get_session_id()
		or request_id.is_empty()
		or request_id.length() > MAX_REQUEST_ID_LENGTH
		or _pending_captures.has(peer_id)
	):
		_send_interaction_result(
			peer_id, request_id, false, "Cannot use that gathering tool now."
		)
		return
	_charge_requests[peer_id] = {
		"request_id": request_id,
		"started": _now(),
	}


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	NetworkWorldSpawnProtocol.RELIABLE_CHANNEL,
)
func submit_interaction_finish(data: Dictionary) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(peer_id):
		_handle_interaction_finish(peer_id, data)


func _handle_interaction_finish(peer_id: int, data: Dictionary) -> void:
	var request_id: String = str(data.get("request_id", ""))
	var entity_id: String = str(data.get("entity_id", ""))
	var charge: Dictionary = _charge_requests.get(peer_id, {})
	_charge_requests.erase(peer_id)
	var target_position: Vector3 = NetworkWorldSpawnProtocol.array_to_vector3(
		data.get("target_position", [])
	)
	var state: Dictionary = _entities.get(entity_id, {})
	var entry := state.get("data") as GatherableDataType
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	var error: String = ""
	if (
		str(data.get("session_id", "")) != _session.get_session_id()
		or request_id.is_empty()
		or request_id.length() > MAX_REQUEST_ID_LENGTH
		or str(charge.get("request_id", "")) != request_id
		or not target_position.is_finite()
	):
		error = "The catch attempt was invalid."
	elif state.is_empty() or entry == null or bool(state.get("locked", false)):
		error = "That gathering spot is no longer there."
	elif _now() - float(charge.get("started", _now())) + 0.05 < entry.charge_duration:
		error = "Finish readying the tool first."
	elif _item_use.get_equipped_item_id(peer_id) != entry.required_tool_id:
		error = "Equip the correct gathering tool."
	elif avatar == null:
		error = "The player is unavailable."
	elif entry.requires_sneaking and not avatar.is_sneaking():
		error = "Sneak closer before using the tool."
	else:
		var entity_position: Vector3 = state["position"]
		var target_distance: float = entity_position.distance_to(target_position)
		var player_distance: float = Vector2(
			avatar.global_position.x - entity_position.x,
			avatar.global_position.z - entity_position.z,
		).length()
		if target_distance > entry.capture_radius:
			error = "The gathering tool missed."
		elif player_distance > entry.interaction_range:
			error = "Move closer before using the tool."
	if not error.is_empty():
		_send_interaction_result(peer_id, request_id, false, error)
		return
	var fish_catch: FishCatch = _create_catch_for_state(entry, state)
	if fish_catch == null or not fish_catch.is_valid():
		_send_interaction_result(peer_id, request_id, false, "The catch could not be recorded.")
		return
	state["locked"] = true
	_entities[entity_id] = state
	var capacity_nonce: String = _new_id("capacity")
	_pending_captures[peer_id] = {
		"request_id": request_id,
		"entity_id": entity_id,
		"catch": fish_catch.to_network_dict(),
		"result_id": _new_id("gather_result"),
		"capacity_nonce": capacity_nonce,
		"deadline": _now() + CAPACITY_RESPONSE_TIMEOUT_SECONDS,
	}
	var probe: Dictionary = {
		"session_id": _session.get_session_id(),
		"request_id": request_id,
		"capacity_nonce": capacity_nonce,
		"catch_id": str(fish_catch.catch_id),
	}
	if peer_id == _session.get_local_peer_id():
		_handle_local_capacity_probe(probe)
	else:
		receive_capacity_probe.rpc_id(peer_id, probe)


func _create_catch_for_state(
	entry: GatherableDataType,
	state: Dictionary,
) -> FishCatch:
	var selector := FishSelectorType.new()
	selector.begin_roll()
	var fish_catch: FishCatch = selector.create_catch(entry.catch_data)
	if fish_catch == null:
		return null
	var quality: int = _get_state_quality(state)
	fish_catch.quality = quality
	fish_catch.sale_value = FishQualityType.apply_sale_value(
		entry.catch_data.get_sale_value_for_weight(fish_catch.weight_lb),
		quality,
	)
	return fish_catch


func _get_state_quality(state: Dictionary) -> int:
	var quality: int = int(
		state.get("quality", FishQualityType.Tier.BORING)
	)
	return (
		quality
		if FishQualityType.is_valid(quality)
		else FishQualityType.Tier.BORING
	)


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	NetworkWorldSpawnProtocol.RELIABLE_CHANNEL,
)
func submit_interaction_cancel(request_id: String) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(peer_id):
		_handle_interaction_cancel(peer_id, request_id)


func _handle_interaction_cancel(peer_id: int, request_id: String) -> void:
	var charge: Dictionary = _charge_requests.get(peer_id, {})
	if str(charge.get("request_id", "")) == request_id:
		_charge_requests.erase(peer_id)


@rpc(
	"authority",
	"call_remote",
	"reliable",
	NetworkWorldSpawnProtocol.RELIABLE_CHANNEL,
)
func receive_capacity_probe(data: Dictionary) -> void:
	_handle_local_capacity_probe(data)


func _handle_local_capacity_probe(data: Dictionary) -> void:
	if str(data.get("session_id", "")) != _session.get_session_id():
		return
	var catch_id := StringName(str(data.get("catch_id", "")))
	var can_accept: bool = (
		_local_inventory != null
		and _local_inventory.can_accept_catch(catch_id)
	)
	if _session.is_host():
		_handle_capacity_response(
			_session.get_local_peer_id(),
			str(data.get("request_id", "")),
			str(data.get("capacity_nonce", "")),
			can_accept,
		)
	else:
		submit_capacity_response.rpc_id(
			1,
			str(data.get("request_id", "")),
			str(data.get("capacity_nonce", "")),
			can_accept,
		)


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	NetworkWorldSpawnProtocol.RELIABLE_CHANNEL,
)
func submit_capacity_response(
	request_id: String,
	capacity_nonce: String,
	can_accept: bool,
) -> void:
	var peer_id: int = multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(peer_id):
		_handle_capacity_response(
			peer_id,
			request_id,
			capacity_nonce,
			can_accept,
		)


func _handle_capacity_response(
	peer_id: int,
	request_id: String,
	capacity_nonce: String,
	can_accept: bool,
) -> void:
	var pending: Dictionary = _pending_captures.get(peer_id, {})
	if (
		pending.is_empty()
		or str(pending.get("request_id", "")) != request_id
		or str(pending.get("capacity_nonce", "")) != capacity_nonce
	):
		return
	if not can_accept:
		_reject_pending_capture(peer_id, "Inventory is full.")
		return
	_pending_captures.erase(peer_id)
	var entity_id: String = str(pending["entity_id"])
	_despawn_entity(entity_id, &"captured", false, true)
	var outcome: Dictionary = {
		"session_id": _session.get_session_id(),
		"result_id": str(pending["result_id"]),
		"request_id": request_id,
		"target_peer_id": peer_id,
		"catch": (pending["catch"] as Dictionary).duplicate(true),
	}
	if peer_id == _session.get_local_peer_id():
		_apply_capture_result(outcome)
	else:
		receive_capture_result.rpc_id(peer_id, outcome)
	_broadcast_showcase(peer_id, outcome["catch"], true)
	_showcase_deadlines[peer_id] = _now() + 4.5


func _reject_pending_capture(peer_id: int, message: String) -> void:
	var pending: Dictionary = _pending_captures.get(peer_id, {})
	_pending_captures.erase(peer_id)
	if pending.is_empty():
		return
	var entity_id: String = str(pending.get("entity_id", ""))
	var state: Dictionary = _entities.get(entity_id, {})
	if not state.is_empty():
		state["locked"] = false
		_entities[entity_id] = state
	_send_interaction_result(
		peer_id,
		str(pending.get("request_id", "")),
		false,
		message,
	)


func _update_pending_capture_timeouts() -> void:
	var now: float = _now()
	for peer_id: int in _pending_captures.keys():
		var pending: Dictionary = _pending_captures[peer_id]
		if now >= float(pending.get("deadline", INF)):
			_reject_pending_capture(peer_id, "The catch attempt timed out.")


@rpc(
	"authority",
	"call_remote",
	"reliable",
	NetworkWorldSpawnProtocol.RELIABLE_CHANNEL,
)
func receive_capture_result(data: Dictionary) -> void:
	_apply_capture_result(data)


func _apply_capture_result(data: Dictionary) -> void:
	if (
		str(data.get("session_id", "")) != _session.get_session_id()
		or int(data.get("target_peer_id", 0)) != _session.get_local_peer_id()
		or typeof(data.get("catch")) != TYPE_DICTIONARY
	):
		return
	var result_id: String = str(data.get("result_id", ""))
	var request_id: String = str(data.get("request_id", ""))
	if result_id.is_empty() or request_id.is_empty():
		return
	if _received_results.has(result_id):
		local_interaction_finished.emit(true, "Caught.")
		return
	var catch_data: Dictionary = data["catch"]
	var fish: FishDataType = _fish_catalog.get_fish_by_id(
		StringName(str(catch_data.get("fish_id", "")))
	)
	var fish_catch: FishCatch = FishCatchType.from_network_dict(
		catch_data,
		fish,
	)
	if fish_catch == null or not fish_catch.is_valid():
		return
	var already_owned: bool = _local_inventory.contains_catch_id(
		fish_catch.catch_id
	)
	if (
		not already_owned
		and not _local_inventory.can_accept_catch(fish_catch.catch_id)
	):
		return
	if not already_owned:
		var experience: int = FishExperienceType.calculate_for_collection(
			fish_catch,
			_local_collection,
		)
		_local_inventory.add_catch(fish_catch)
		_local_collection.mark_quality_discovered(
			fish_catch.fish_id,
			fish_catch.quality,
		)
		_local_experience.award_experience(experience)
	if not _save_manager.save_if_dirty():
		return
	_received_results[result_id] = true
	_bound(_received_results)
	local_interaction_finished.emit(true, "Caught %s." % fish.display_name)
	local_capture_received.emit(fish_catch)


func _send_interaction_result(
	peer_id: int,
	request_id: String,
	accepted: bool,
	message: String,
) -> void:
	var result: Dictionary = {
		"session_id": _session.get_session_id(),
		"request_id": request_id if not request_id.is_empty() else "invalid",
		"target_peer_id": peer_id,
		"accepted": accepted,
		"message": message.left(160),
	}
	if peer_id == _session.get_local_peer_id():
		_apply_interaction_result(result)
	else:
		receive_interaction_result.rpc_id(peer_id, result)


@rpc(
	"authority",
	"call_remote",
	"reliable",
	NetworkWorldSpawnProtocol.RELIABLE_CHANNEL,
)
func receive_interaction_result(data: Dictionary) -> void:
	_apply_interaction_result(data)


func _apply_interaction_result(data: Dictionary) -> void:
	if (
		str(data.get("session_id", "")) != _session.get_session_id()
		or int(data.get("target_peer_id", 0)) != _session.get_local_peer_id()
		or typeof(data.get("accepted")) != TYPE_BOOL
	):
		return
	local_interaction_finished.emit(
		bool(data["accepted"]),
		str(data.get("message", "")),
	)


func _broadcast_showcase(
	peer_id: int,
	catch_data: Dictionary,
	visible: bool,
) -> void:
	var envelope: Dictionary = _make_envelope(
		&"showcase",
		{
			"owner_peer_id": peer_id,
			"visible": visible,
			"catch": catch_data.duplicate(true) if visible else {},
		},
	)
	_apply_envelope(envelope)
	receive_world_envelope.rpc(envelope)


func _update_showcase_deadlines() -> void:
	var now: float = _now()
	for peer_id: int in _showcase_deadlines.keys():
		if now < float(_showcase_deadlines[peer_id]):
			continue
		_showcase_deadlines.erase(peer_id)
		_broadcast_showcase(peer_id, {}, false)


func _make_envelope(
	event_id: StringName,
	payload: Dictionary,
) -> Dictionary:
	_envelope_sequence += 1
	return NetworkWorldSpawnProtocol.make_envelope(
		_session.get_session_id(),
		_envelope_sequence,
		event_id,
		payload,
	)


@rpc(
	"authority",
	"call_remote",
	"reliable",
	NetworkWorldSpawnProtocol.RELIABLE_CHANNEL,
)
func receive_world_envelope(envelope: Dictionary) -> void:
	_apply_envelope(envelope)


@rpc(
	"authority",
	"call_remote",
	"unreliable_ordered",
	NetworkWorldSpawnProtocol.SNAPSHOT_CHANNEL,
)
func receive_world_snapshot_envelope(envelope: Dictionary) -> void:
	_apply_envelope(envelope)


func _apply_envelope(envelope: Dictionary) -> void:
	if (
		not NetworkWorldSpawnProtocol.validate_envelope(envelope)
		or str(envelope["session_id"]) != _session.get_session_id()
	):
		return
	var event_id := StringName(str(envelope["event_id"]))
	var payload: Dictionary = envelope["payload"]
	match event_id:
		&"spawn":
			_apply_entity_state(payload.get("entity", {}), true)
		&"snapshot":
			_apply_entity_states(payload.get("entities", []), false, false)
		&"population":
			_apply_entity_states(payload.get("entities", []), true, true)
		&"despawn":
			_apply_despawn(payload)
		&"showcase":
			_apply_showcase(payload)


func _apply_entity_states(
	values: Variant,
	immediate: bool,
	reconcile: bool,
) -> void:
	if (
		typeof(values) != TYPE_ARRAY
		or values.size() > NetworkWorldSpawnProtocol.MAX_ENTITIES_PER_SNAPSHOT
	):
		return
	var included: Dictionary = {}
	for value: Variant in values:
		if not NetworkWorldSpawnProtocol.validate_entity_state(value):
			continue
		var state: Dictionary = value
		included[str(state["entity_id"])] = true
		_apply_entity_state(state, immediate)
	if not reconcile:
		return
	for entity_id: String in _presentations.keys():
		if not included.has(entity_id):
			_remove_presentation(entity_id, false)


func _apply_entity_state(value: Variant, immediate: bool) -> void:
	if not NetworkWorldSpawnProtocol.validate_entity_state(value):
		return
	var state: Dictionary = value
	var entity_id: String = str(state["entity_id"])
	var revision: int = int(state["revision"])
	if revision < int(_entity_revisions.get(entity_id, -1)):
		return
	var entry: GatherableDataType = _catalog.get_entry(
		StringName(str(state["type_id"]))
	)
	if entry == null:
		return
	var position: Vector3 = NetworkWorldSpawnProtocol.array_to_vector3(
		state["position"]
	)
	var presentation := _presentations.get(entity_id) as WorldGatherableType
	if presentation == null or not is_instance_valid(presentation):
		presentation = WorldGatherableType.new()
		presentation.name = "WorldGatherable_%s" % entity_id.right(12)
		_world_root.add_child(presentation)
		presentation.configure(
			entity_id,
			entry,
			position,
			float(state["yaw"]),
		)
		_presentations[entity_id] = presentation
	else:
		presentation.apply_network_state(
			position,
			float(state["yaw"]),
			immediate,
		)
	_entity_revisions[entity_id] = revision
	if not _session.is_host():
		_entities[entity_id] = {
			"entity_id": entity_id,
			"type_id": entry.type_id,
			"data": entry,
			"position": position,
			"yaw": float(state["yaw"]),
			"revision": revision,
			"locked": false,
		}


func _apply_despawn(payload: Dictionary) -> void:
	var entity_id: String = str(payload.get("entity_id", ""))
	if entity_id.is_empty():
		return
	if not _session.is_host():
		_entities.erase(entity_id)
	_remove_presentation(entity_id, bool(payload.get("with_dust", false)))


func _remove_presentation(entity_id: String, with_dust: bool) -> void:
	var presentation := _presentations.get(entity_id) as WorldGatherableType
	_presentations.erase(entity_id)
	_entity_revisions.erase(entity_id)
	if presentation != null and is_instance_valid(presentation):
		presentation.play_despawn(with_dust)


func _apply_showcase(payload: Dictionary) -> void:
	if (
		typeof(payload.get("owner_peer_id")) != TYPE_INT
		or typeof(payload.get("visible")) != TYPE_BOOL
	):
		return
	var peer_id: int = int(payload["owner_peer_id"])
	if peer_id == _session.get_local_peer_id():
		return
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	if avatar == null:
		return
	if not bool(payload["visible"]):
		avatar.end_catch_showcase()
		return
	if typeof(payload.get("catch")) != TYPE_DICTIONARY:
		return
	var catch_data: Dictionary = payload["catch"]
	var fish: FishDataType = _fish_catalog.get_fish_by_id(
		StringName(str(catch_data.get("fish_id", "")))
	)
	var fish_catch: FishCatch = FishCatchType.from_network_dict(
		catch_data,
		fish,
	)
	if fish_catch != null:
		avatar.begin_remote_catch_showcase(fish_catch)


func _state_to_network(state: Dictionary) -> Dictionary:
	return {
		"entity_id": str(state["entity_id"]),
		"type_id": str(state["type_id"]),
		"position": NetworkWorldSpawnProtocol.vector3_to_array(
			state["position"]
		),
		"yaw": float(state["yaw"]),
		"revision": int(state["revision"]),
	}


func _on_peer_authenticated(peer_id: int, _display_name: String) -> void:
	if not _session.is_host():
		return
	var states: Array[Dictionary] = []
	for state: Dictionary in _entities.values():
		states.append(_state_to_network(state))
	var envelope: Dictionary = _make_envelope(
		&"population",
		{"entities": states},
	)
	receive_world_envelope.rpc_id(peer_id, envelope)


func _on_peer_removed(peer_id: int) -> void:
	_charge_requests.erase(peer_id)
	if _pending_captures.has(peer_id):
		_unlock_pending_capture(peer_id)
	_showcase_deadlines.erase(peer_id)


func _unlock_pending_capture(peer_id: int) -> void:
	var pending: Dictionary = _pending_captures.get(peer_id, {})
	_pending_captures.erase(peer_id)
	if pending.is_empty():
		return
	var entity_id: String = str(pending.get("entity_id", ""))
	var state: Dictionary = _entities.get(entity_id, {})
	if state.is_empty():
		return
	state["locked"] = false
	_entities[entity_id] = state


func _on_session_state_changed(_state: NetworkSession.State) -> void:
	if _session.is_gameplay_session_active():
		_begin_population_if_ready.call_deferred()
		return
	_clear_world()
	_population_session_id = ""


func _on_calendar_date_changed(_date_id: String) -> void:
	if (
		_session == null
		or not _session.is_host()
		or not _session.is_gameplay_session_active()
		or _population_session_id.is_empty()
	):
		return
	_reconcile_seasonal_population()


func _reconcile_seasonal_population() -> void:
	if _catalog == null:
		return
	var season: int = _current_season()
	for entity_id: String in _entities.keys():
		var state: Dictionary = _entities.get(entity_id, {})
		var entry := state.get("data") as GatherableDataType
		if entry != null and not entry.is_available(season):
			_despawn_entity(entity_id, &"season_changed", false, false)
	var retained_respawns: Array[Dictionary] = []
	for respawn: Dictionary in _respawns:
		var entry: GatherableDataType = _catalog.get_entry(
			StringName(str(respawn.get("type_id", "")))
		)
		if entry != null and entry.is_available(season):
			retained_respawns.append(respawn)
	_respawns = retained_respawns
	for entry: GatherableDataType in _catalog.get_available_entries(season):
		_cache_spawn_surface(entry)
		var current_population: int = _population_for_type(entry.type_id)
		while current_population < entry.population:
			_spawn_entity(entry)
			current_population += 1


func _population_for_type(type_id: StringName) -> int:
	var count: int = 0
	for state: Dictionary in _entities.values():
		if StringName(str(state.get("type_id", ""))) == type_id:
			count += 1
	for respawn: Dictionary in _respawns:
		if StringName(str(respawn.get("type_id", ""))) == type_id:
			count += 1
	return count


func _current_season() -> int:
	return (
		_world_time.get_season()
		if _world_time != null
		else CalendarSeasonType.UNKNOWN
	)


func _clear_world() -> void:
	for presentation: WorldGatherableType in _presentations.values():
		if presentation != null and is_instance_valid(presentation):
			presentation.queue_free()
	_entities.clear()
	_presentations.clear()
	_entity_revisions.clear()
	_surface_triangles.clear()
	_surface_areas.clear()
	_surface_total_areas.clear()
	_spawn_anchor_positions.clear()
	_respawns.clear()
	_next_respawn_by_type.clear()
	_charge_requests.clear()
	_pending_captures.clear()
	_showcase_deadlines.clear()
	_snapshot_elapsed = 0.0


func _bound(values: Dictionary) -> void:
	while values.size() > MAX_LEDGER_ENTRIES:
		values.erase(values.keys().front())


func _new_id(prefix: String) -> String:
	return "%s:%s" % [
		prefix,
		Crypto.new().generate_random_bytes(16).hex_encode(),
	]


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
