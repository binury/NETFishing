class_name NetworkFishingService
extends Node

const FishCatchType = preload("res://fish/fish_catch.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const FishSelectorType = preload("res://fish/fish_selector.gd")
const FishingContextType = preload("res://fishing/fishing_context.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")
const FishExperienceType = preload("res://fish/fish_experience.gd")
const PlayerExperienceType = preload(
	"res://progression/player_experience.gd"
)
const RemotePresentationType = preload(
	"res://fishing/remote_fishing_presentation.gd"
)
const ItemDataType = preload("res://items/item_data.gd")

const MAX_LEDGER_ENTRIES_PER_PEER: int = 64
const CAST_ORIGIN_TOLERANCE: float = 2.5
const CAPACITY_RESPONSE_TIMEOUT: float = 5.0
const MIN_CAST_INTERVAL: float = 0.25

signal local_cast_accepted(attempt_id: String, target: Vector3)
signal local_cast_rejected(message: String)
signal local_bite_started(attempt_id: String)
signal local_bite_pending(attempt_id: String)
signal local_snapshot_received(snapshot: Dictionary)
signal local_catch_received(fish_catch: FishCatch)
signal local_attempt_ended(outcome: StringName, message: String)

var _session: NetworkSession
var _spawn_service: PlayerSpawnService
var _fishing_spot: FishingSpot
var _local_inventory: FishInventory
var _local_bag: PlayerBag
var _local_collection: CollectionLog
var _local_capacity: PlayerCoolerCapacity
var _local_experience: PlayerExperienceType
var _save_manager: PlayerSaveManager
var _item_catalog: ItemCatalog
var _fish_catalog: FishPoolType
var _item_use: NetworkItemUseService
var _attempts: Dictionary[int, NetworkFishingAttempt] = {}
var _request_ledgers: Dictionary[int, Dictionary] = {}
var _result_ledgers: Dictionary[String, bool] = {}
var _result_acknowledgements: Dictionary[String, String] = {}
var _last_cast_time: Dictionary[int, float] = {}
var _last_input_time: Dictionary[int, float] = {}
var _remote_presentations: Dictionary[int, RemoteFishingPresentation] = {}
var _pending_local_bait_by_request: Dictionary[String, StringName] = {}
var _snapshot_accumulator: float = 0.0
var _local_input_sequence: int = 0


func setup(
	session: NetworkSession,
	spawn_service: PlayerSpawnService,
	fishing_spot: FishingSpot,
	local_inventory: FishInventory,
	local_bag: PlayerBag,
	local_collection: CollectionLog,
	local_capacity: PlayerCoolerCapacity,
	local_experience: PlayerExperienceType,
	save_manager: PlayerSaveManager,
	item_catalog: ItemCatalog,
	fish_catalog: FishPoolType,
	item_use: NetworkItemUseService,
) -> void:
	_session = session
	_spawn_service = spawn_service
	_fishing_spot = fishing_spot
	_local_inventory = local_inventory
	_local_bag = local_bag
	_local_collection = local_collection
	_local_capacity = local_capacity
	_local_experience = local_experience
	_save_manager = save_manager
	_item_catalog = item_catalog
	_fish_catalog = fish_catalog
	_item_use = item_use
	if not _session.peer_removed.is_connected(_on_peer_removed):
		_session.peer_removed.connect(_on_peer_removed)
	if not _session.state_changed.is_connected(_on_session_state_changed):
		_session.state_changed.connect(_on_session_state_changed)
	if not _spawn_service.avatar_removed.is_connected(_on_avatar_removed):
		_spawn_service.avatar_removed.connect(_on_avatar_removed)


func request_local_cast(
	origin: Vector3,
	target: Vector3,
	charge: float,
	evidence: Dictionary,
) -> String:
	if (
		_session == null
		or not _session.is_gameplay_session_active()
		or not origin.is_finite()
		or not target.is_finite()
	):
		local_cast_rejected.emit("Fishing attempt ended.")
		return ""
	var bait_id := StringName(str(evidence.get("bait_id", "")))
	if not bait_id.is_empty() and (
		_local_bag == null or not _local_bag.owns_item(bait_id)
	):
		local_cast_rejected.emit("No bait available.")
		return ""
	var lure_id := StringName(str(evidence.get("lure_id", "")))
	if not lure_id.is_empty() and (
		_local_bag == null or not _local_bag.owns_item(lure_id)
	):
		local_cast_rejected.emit("Lure is unavailable.")
		return ""
	var request_id: String = _new_id("cast")
	var data: Dictionary = {
		"request_id": request_id,
		"session_id": _session.get_session_id(),
		"origin": NetworkFishingProtocol.vector3_to_array(origin),
		"target": NetworkFishingProtocol.vector3_to_array(target),
		"charge": charge,
		"rod_id": str(evidence.get("rod_id", "")),
		"reel_speed": float(evidence.get("reel_speed", 0.0)),
		"barrier_damage": int(evidence.get("barrier_damage", 0)),
		"bite_multiplier": float(evidence.get("bite_multiplier", 1.0)),
		"rarity_multipliers": evidence.get("rarity_multipliers", []),
		"discovered_fish_ids": evidence.get("discovered_fish_ids", []),
		"capacity_available": bool(evidence.get("capacity_available", false)),
		"bait_id": str(bait_id),
		"lure_id": str(lure_id),
	}
	if _session.is_host():
		_handle_cast_request(_session.get_local_peer_id(), data)
	else:
		if not bait_id.is_empty():
			_pending_local_bait_by_request[request_id] = bait_id
		submit_cast_request.rpc_id(1, data)
	return request_id


func submit_local_input(held: bool, pressed: bool) -> void:
	var peer_id: int = _session.get_local_peer_id()
	var attempt: NetworkFishingAttempt = _attempts.get(peer_id)
	if attempt == null:
		return
	_local_input_sequence += 1
	var data: Dictionary = {
		"attempt_id": attempt.attempt_id,
		"sequence": _local_input_sequence,
		"held": held,
		"pressed": pressed,
	}
	if _session.is_host():
		_handle_fishing_input(peer_id, data)
	else:
		submit_fishing_input.rpc_id(1, data)


func cancel_local_attempt(reason: String = "Fishing attempt ended.") -> void:
	if _session == null or not _session.is_gameplay_session_active():
		return
	var peer_id: int = _session.get_local_peer_id()
	var attempt: NetworkFishingAttempt = _attempts.get(peer_id)
	if attempt == null:
		return
	if _session.is_host():
		_cancel_attempt(peer_id, reason)
	else:
		submit_cancel_request.rpc_id(1, attempt.attempt_id)


func cancel_peer_attempt(peer_id: int, reason: String) -> void:
	if _session != null and _session.is_host() and _attempts.has(peer_id):
		_cancel_attempt(peer_id, reason)


func has_local_attempt() -> bool:
	return (
		_session != null
		and _attempts.has(_session.get_local_peer_id())
	)


func has_peer_attempt(peer_id: int) -> bool:
	return _attempts.has(peer_id)


func _process(delta: float) -> void:
	if _session == null or not _session.is_host():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	for peer_id: int in _attempts.keys():
		var attempt: NetworkFishingAttempt = _attempts.get(peer_id)
		if attempt == null:
			continue
		match attempt.phase:
			NetworkFishingAttempt.Phase.WAITING_FOR_BITE:
				if attempt.bite_confirmation_pending:
					continue
				_update_waiting_attempt(attempt, delta)
				if not _attempts.has(peer_id):
					continue
				attempt.bite_time_remaining -= delta
				if attempt.bite_time_remaining <= 0.0:
					if &"deferred_fight" in attempt.lure_effects:
						_set_bite_pending(attempt)
					else:
						_start_bite(attempt)
			NetworkFishingAttempt.Phase.PENDING_CAPACITY:
				if now >= attempt.capacity_deadline:
					_cancel_attempt(peer_id, "Fishing attempt ended.")
	_snapshot_accumulator += delta
	if _snapshot_accumulator >= NetworkFishingProtocol.SNAPSHOT_RATE:
		_snapshot_accumulator = fmod(
			_snapshot_accumulator,
			NetworkFishingProtocol.SNAPSHOT_RATE
		)
		_broadcast_snapshots()


@rpc("any_peer", "call_remote", "reliable", 0)
func submit_cast_request(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not _session.is_host() or not _session.is_authenticated_peer(sender_id):
		return
	_handle_cast_request(sender_id, data)


func _handle_cast_request(peer_id: int, data: Dictionary) -> void:
	var validation_error: String = NetworkFishingProtocol.validate_cast_request(
		data
	)
	if not validation_error.is_empty():
		_send_cast_rejected(peer_id, str(data.get("request_id", "")),
			validation_error)
		return
	var request_id: String = data["request_id"]
	var ledger: Dictionary = _request_ledgers.get(peer_id, {})
	if ledger.has(request_id):
		_resend_request_response(peer_id, ledger[request_id])
		return
	if str(data["session_id"]) != _session.get_session_id():
		_record_and_reject(peer_id, request_id, "Fishing attempt ended.")
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last_cast_time.get(peer_id, -INF)) < MIN_CAST_INTERVAL:
		_record_and_reject(peer_id, request_id, "Already fishing.")
		return
	_last_cast_time[peer_id] = now
	if _attempts.has(peer_id):
		_record_and_reject(peer_id, request_id, "Already fishing.")
		return
	if not bool(data["capacity_available"]):
		_record_and_reject(peer_id, request_id, "Cooler is full.")
		return
	var rod: ItemData = _item_catalog.get_item_by_id(
		StringName(str(data["rod_id"]))
	)
	if rod == null or rod.category != ItemData.Category.ROD:
		_record_and_reject(peer_id, request_id, "Select a fishing rod to cast.")
		return
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	if avatar == null or avatar.is_water_recovery_active():
		_record_and_reject(peer_id, request_id, "Fishing attempt ended.")
		return
	var origin: Vector3 = NetworkFishingProtocol.array_to_vector3(data["origin"])
	var target: Vector3 = NetworkFishingProtocol.array_to_vector3(data["target"])
	var authoritative_origin: Vector3 = avatar.get_cast_origin_position()
	if origin.distance_to(authoritative_origin) > CAST_ORIGIN_TOLERANCE:
		_record_and_reject(peer_id, request_id, "Cannot fish here.")
		return
	var cast_offset: Vector3 = target - authoritative_origin
	cast_offset.y = 0.0
	var expected_distance: float = lerpf(
		_fishing_spot.minimum_cast_distance,
		_fishing_spot.maximum_cast_distance,
		float(data["charge"])
	)
	var facing: Vector3 = avatar.get_facing_direction()
	facing.y = 0.0
	if (
		cast_offset.length() < _fishing_spot.minimum_cast_distance - 0.25
		or cast_offset.length() > _fishing_spot.maximum_cast_distance + 0.5
		or absf(cast_offset.length() - expected_distance) > 1.25
		or (
			not facing.is_zero_approx()
			and facing.normalized().dot(cast_offset.normalized()) < 0.2
		)
	):
		_record_and_reject(peer_id, request_id, "Cannot fish here.")
		return
	var surface: FishingSurfaceSample = _fishing_spot.resolve_fishing_surface(
		target,
		authoritative_origin.y,
	)
	var region: FishableWaterRegion = surface.water_region
	var authoritative_target: Vector3 = surface.position
	if (
		not surface.is_fishable()
		or region == null
		or region.fish_pool == null
		or not _fishing_spot.is_cast_path_clear(
			authoritative_origin,
			authoritative_target
		)
	):
		_record_and_reject(peer_id, request_id, "Cannot fish here.")
		return
	var effects: PlayerItemEffects = (
		_item_use.get_effects_for_peer(peer_id)
		if _item_use != null else null
	)
	var selected_fish: FishDataType = _select_authoritative_fish(
		region, data, effects
	)
	if selected_fish == null or not selected_fish.is_allowed_in_water(
		region.water_type
	):
		_record_and_reject(peer_id, request_id, "Nothing is biting here.")
		return
	var bait_id: StringName = StringName(str(data.get("bait_id", "")))
	var avatar_bag: PlayerBag = avatar.bag
	var owns_authoritative_bag: bool = (
		peer_id == _session.get_local_peer_id()
	)
	var bait: ItemDataType = (
		_item_catalog.get_item_by_id(bait_id)
		if not bait_id.is_empty() and _item_catalog != null
		else null
	)
	var lure_id: StringName = StringName(str(data.get("lure_id", "")))
	var lure: ItemDataType = (
		_item_catalog.get_item_by_id(lure_id)
		if not lure_id.is_empty() and _item_catalog != null
		else null
	)
	if (
		not lure_id.is_empty()
		and (
			lure == null
			or not lure.is_lure()
			or (
				owns_authoritative_bag
				and (
					avatar_bag == null
					or not avatar_bag.owns_item(lure_id)
				)
			)
		)
	):
		_record_and_reject(peer_id, request_id, "Lure is unavailable.")
		return
	if not bait_id.is_empty() and (
		bait == null
		or not bait.is_bait()
		or (
			owns_authoritative_bag
			and (
				avatar_bag == null
				or not avatar_bag.remove_item(bait_id, 1)
			)
		)
	):
		_record_and_reject(peer_id, request_id, "No bait available.")
		return
	var attempt := NetworkFishingAttempt.new()
	attempt.owner_peer_id = peer_id
	attempt.request_id = request_id
	attempt.attempt_id = _new_id("attempt")
	attempt.session_id = _session.get_session_id()
	attempt.phase = NetworkFishingAttempt.Phase.WAITING_FOR_BITE
	attempt.origin = authoritative_origin
	attempt.target = authoritative_target
	attempt.bobber_position = authoritative_target
	attempt.fish_id = selected_fish.id
	attempt.bait_tags = _bait_tags_for_request(data)
	attempt.lure_effects.clear()
	if lure != null:
		for effect_id: StringName in lure.lure_effects:
			attempt.lure_effects.append(effect_id)
	attempt.reel_speed = float(data["reel_speed"]) * (
		effects.get_reel_multiplier() if effects != null else 1.0
	)
	attempt.barrier_damage = int(data["barrier_damage"]) + (
		effects.get_barrier_bonus() if effects != null else 0
	)
	attempt.bite_time_remaining = _fishing_spot.roll_bite_wait_time() * float(
		effects.get_bite_time_multiplier() if effects != null else 1.0
	)
	attempt.controller = CatchController.new()
	add_child(attempt.controller)
	attempt.controller.encounter_updated.connect(
		_on_encounter_updated.bind(peer_id)
	)
	attempt.controller.caught.connect(_on_attempt_caught.bind(peer_id))
	attempt.controller.escaped.connect(_on_attempt_escaped.bind(peer_id))
	attempt.set_meta("snapshot", _make_waiting_snapshot(attempt))
	_attempts[peer_id] = attempt
	avatar.set_movement_enabled(false)
	var response: Dictionary = _make_cast_accepted(attempt)
	_record_request_response(peer_id, request_id, response)
	_broadcast_cast_accepted(response)


func _update_waiting_attempt(
	attempt: NetworkFishingAttempt,
	delta: float,
) -> void:
	if not attempt.input_held:
		return
	var flat_offset: Vector3 = attempt.target - attempt.origin
	flat_offset.y = 0.0
	var withdrawable_distance: float = (
		flat_offset.length() - _fishing_spot.withdrawal_cancel_distance
	)
	if withdrawable_distance <= 0.0:
		_cancel_attempt(attempt.owner_peer_id, "", &"withdrawal")
		return
	attempt.withdrawal_progress = minf(
		attempt.withdrawal_progress
		+ _fishing_spot.withdrawal_rate * delta / withdrawable_distance,
		1.0
	)
	var endpoint: Vector3 = attempt.origin + (
		flat_offset.normalized()
		* _fishing_spot.withdrawal_cancel_distance
	)
	endpoint.y = attempt.target.y
	var desired: Vector3 = attempt.target.lerp(
		endpoint,
		attempt.withdrawal_progress
	)
	var withdrawal_surface: FishingSurfaceSample = (
		_fishing_spot.resolve_safe_withdrawal_surface(
			attempt.bobber_position,
			desired,
			endpoint - attempt.bobber_position,
		)
	)
	if not withdrawal_surface.is_fishable():
		_cancel_attempt(attempt.owner_peer_id, "", &"withdrawal")
		return
	attempt.bobber_position = withdrawal_surface.position
	attempt.set_meta("snapshot", _make_waiting_snapshot(attempt))
	if is_equal_approx(attempt.withdrawal_progress, 1.0):
		_cancel_attempt(attempt.owner_peer_id, "", &"withdrawal")


func _make_waiting_snapshot(
	attempt: NetworkFishingAttempt,
) -> Dictionary:
	return {
		"attempt_id": attempt.attempt_id,
		"owner_peer_id": attempt.owner_peer_id,
		"phase": int(attempt.phase),
		"progress": 0.0,
		"chase_progress": 0.0,
		"barrier_positions": [],
		"barrier_health": [],
		"barrier_max_health": [],
		"active_barrier_index": -1,
		"visible": false,
		"acknowledged_input_sequence": attempt.last_input_sequence,
		"bobber_position": NetworkFishingProtocol.vector3_to_array(
			attempt.bobber_position
		),
	}


func _select_authoritative_fish(
	region: FishableWaterRegion,
	data: Dictionary,
	effects: PlayerItemEffects,
) -> FishDataType:
	var evidence_log := CollectionLogType.new()
	for value: Variant in data["discovered_fish_ids"]:
		var fish_id := StringName(str(value))
		if _fish_catalog.get_fish_by_id(fish_id) == null:
			return null
		evidence_log.mark_discovered(fish_id)
	var selector := FishSelectorType.new()
	selector.undiscovered_weight_multiplier = (
		_fishing_spot.undiscovered_weight_multiplier
	)
	for rarity: int in range(FishDataType.Rarity.size()):
		selector.rarity_weight_multipliers.append(
			effects.get_rarity_weight_multiplier(rarity)
			if effects != null else 1.0
		)
	selector.begin_roll()
	var context: FishingContextType = _fishing_spot.build_network_context(region)
	context.active_bait_tags = _bait_tags_for_request(data)
	var selected_fish := selector.select_fish(
		region.fish_pool, context, evidence_log
	)
	evidence_log.free()
	return selected_fish


func _bait_tags_for_request(data: Dictionary) -> Array[StringName]:
	var bait_id: StringName = StringName(str(data.get("bait_id", "")))
	if bait_id.is_empty() or _item_catalog == null:
		return []
	var bait: ItemDataType = _item_catalog.get_item_by_id(bait_id)
	return bait.bait_tags.duplicate() if bait != null and bait.is_bait() else []


func _set_bite_pending(attempt: NetworkFishingAttempt) -> void:
	if (
		attempt.phase != NetworkFishingAttempt.Phase.WAITING_FOR_BITE
		or attempt.bite_confirmation_pending
	):
		return
	attempt.bite_confirmation_pending = true
	attempt.bite_time_remaining = 0.0
	attempt.input_held = false
	var data: Dictionary = {
		"attempt_id": attempt.attempt_id,
		"owner_peer_id": attempt.owner_peer_id,
	}
	_apply_bite_pending(data)
	receive_bite_pending.rpc(data)


func _start_bite(attempt: NetworkFishingAttempt) -> void:
	if attempt.phase != NetworkFishingAttempt.Phase.WAITING_FOR_BITE:
		return
	var fish: FishDataType = _fish_catalog.get_fish_by_id(attempt.fish_id)
	if fish == null or fish.catch_profile == null:
		_cancel_attempt(attempt.owner_peer_id, "Fishing attempt ended.")
		return
	attempt.bite_confirmation_pending = false
	attempt.phase = NetworkFishingAttempt.Phase.FIGHTING
	attempt.encounter_seed = _new_seed()
	var selector := FishSelectorType.new()
	selector.use_deterministic_test_seed = true
	selector.deterministic_test_seed = attempt.encounter_seed ^ 0x5F3759DF
	selector.begin_roll()
	var fish_catch: FishCatch = selector.create_catch(fish, attempt.bait_tags)
	if fish_catch == null or not fish_catch.is_valid():
		_cancel_attempt(attempt.owner_peer_id, "Fishing attempt ended.")
		return
	attempt.catch_payload = fish_catch.to_network_dict()
	attempt.controller.start_authoritative_encounter(
		fish.catch_profile,
		attempt.reel_speed,
		attempt.barrier_damage,
		attempt.encounter_seed,
		fish_catch.quality,
	)
	var data: Dictionary = {
		"attempt_id": attempt.attempt_id,
		"owner_peer_id": attempt.owner_peer_id,
	}
	_apply_bite_started(data)
	receive_bite_started.rpc(data)


@rpc("any_peer", "call_remote", "unreliable_ordered", 3)
func submit_fishing_input(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not _session.is_host() or not _session.is_authenticated_peer(sender_id):
		return
	_handle_fishing_input(sender_id, data)


func _handle_fishing_input(peer_id: int, data: Dictionary) -> void:
	if not NetworkFishingProtocol.validate_input(data):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last_input_time.get(peer_id, -INF)) < 1.0 / 120.0:
		return
	_last_input_time[peer_id] = now
	var attempt: NetworkFishingAttempt = _attempts.get(peer_id)
	if (
		attempt == null
		or attempt.attempt_id != str(data["attempt_id"])
		or int(data["sequence"]) <= attempt.last_input_sequence
	):
		return
	attempt.last_input_sequence = int(data["sequence"])
	attempt.input_held = bool(data["held"])
	if (
		attempt.phase == NetworkFishingAttempt.Phase.WAITING_FOR_BITE
		and attempt.bite_confirmation_pending
	):
		if bool(data["pressed"]):
			attempt.input_held = false
			_start_bite(attempt)
		return
	if attempt.phase != NetworkFishingAttempt.Phase.FIGHTING:
		return
	attempt.controller.set_reel_input(attempt.input_held)
	if bool(data["pressed"]):
		attempt.controller.handle_primary_pressed()


@rpc("any_peer", "call_remote", "reliable", 0)
func submit_cancel_request(attempt_id: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	var attempt: NetworkFishingAttempt = _attempts.get(sender_id)
	if (
		not _session.is_host()
		or not _session.is_authenticated_peer(sender_id)
		or attempt == null
		or attempt.attempt_id != attempt_id
	):
		return
	_cancel_attempt(sender_id, "")


func _on_encounter_updated(
	progress: float,
	chase_progress: float,
	barrier_positions: PackedFloat32Array,
	barrier_health: PackedInt32Array,
	barrier_max_health: PackedInt32Array,
	active_barrier_index: int,
	visible: bool,
	peer_id: int,
) -> void:
	var attempt: NetworkFishingAttempt = _attempts.get(peer_id)
	if attempt == null or attempt.phase != NetworkFishingAttempt.Phase.FIGHTING:
		return
	attempt.set_meta("snapshot", {
		"attempt_id": attempt.attempt_id,
		"owner_peer_id": peer_id,
		"phase": int(attempt.phase),
		"progress": progress,
		"chase_progress": chase_progress,
		"barrier_positions": Array(barrier_positions),
		"barrier_health": Array(barrier_health),
		"barrier_max_health": Array(barrier_max_health),
		"active_barrier_index": active_barrier_index,
		"visible": visible,
		"acknowledged_input_sequence": attempt.last_input_sequence,
		"bobber_position": NetworkFishingProtocol.vector3_to_array(
			attempt.bobber_position
		),
	})


func _broadcast_snapshots() -> void:
	var snapshots: Array[Dictionary] = []
	for attempt: NetworkFishingAttempt in _attempts.values():
		var snapshot: Dictionary = attempt.get_meta("snapshot", {})
		if not snapshot.is_empty():
			snapshots.append(snapshot)
	if snapshots.is_empty():
		return
	_apply_snapshots(snapshots)
	receive_fishing_snapshots.rpc(snapshots)


@rpc("authority", "call_remote", "unreliable_ordered", 4)
func receive_fishing_snapshots(snapshots: Array) -> void:
	_apply_snapshots(snapshots)


func _apply_snapshots(snapshots: Array) -> void:
	var local_peer_id: int = _session.get_local_peer_id()
	for value: Variant in snapshots:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var snapshot: Dictionary = value
		if not _valid_snapshot(snapshot):
			continue
		var owner_peer_id: int = int(snapshot["owner_peer_id"])
		if owner_peer_id == local_peer_id:
			local_snapshot_received.emit(snapshot)
		else:
			var presentation := _get_remote_presentation(owner_peer_id)
			if presentation != null:
				presentation.update_bobber(
					NetworkFishingProtocol.array_to_vector3(
						snapshot["bobber_position"]
					)
				)


func _valid_snapshot(data: Dictionary) -> bool:
	if not (
		typeof(data.get("attempt_id")) == TYPE_STRING
		and typeof(data.get("owner_peer_id")) == TYPE_INT
		and typeof(data.get("phase")) == TYPE_INT
		and typeof(data.get("progress")) in [TYPE_FLOAT, TYPE_INT]
		and typeof(data.get("chase_progress")) in [TYPE_FLOAT, TYPE_INT]
		and typeof(data.get("barrier_positions")) == TYPE_ARRAY
		and typeof(data.get("barrier_health")) == TYPE_ARRAY
		and typeof(data.get("barrier_max_health")) == TYPE_ARRAY
		and typeof(data.get("active_barrier_index")) == TYPE_INT
		and typeof(data.get("visible")) == TYPE_BOOL
		and typeof(data.get("bobber_position")) == TYPE_ARRAY
		and NetworkFishingProtocol.array_to_vector3(
			data["bobber_position"]
		).is_finite()
	):
		return false
	var positions: Array = data["barrier_positions"]
	var health: Array = data["barrier_health"]
	var maximum_health: Array = data["barrier_max_health"]
	if (
		positions.size() > 32
		or health.size() != positions.size()
		or maximum_health.size() != positions.size()
	):
		return false
	var progress: float = float(data["progress"])
	var chase: float = float(data["chase_progress"])
	if (
		not is_finite(progress)
		or not is_finite(chase)
		or progress < -0.01
		or progress > 1.01
		or chase < -10.0
		or chase > 1.01
	):
		return false
	for index: int in range(positions.size()):
		if (
			typeof(positions[index]) not in [TYPE_FLOAT, TYPE_INT]
			or not is_finite(float(positions[index]))
			or typeof(health[index]) != TYPE_INT
			or typeof(maximum_health[index]) != TYPE_INT
			or int(health[index]) < 0
			or int(maximum_health[index]) < 0
			or int(health[index]) > int(maximum_health[index])
		):
			return false
	return true


func _on_attempt_caught(peer_id: int) -> void:
	var attempt: NetworkFishingAttempt = _attempts.get(peer_id)
	if attempt == null or attempt.phase != NetworkFishingAttempt.Phase.FIGHTING:
		return
	var fish: FishDataType = _fish_catalog.get_fish_by_id(attempt.fish_id)
	if fish == null:
		_cancel_attempt(peer_id, "Fishing attempt ended.")
		return
	var fish_catch: FishCatch = FishCatchType.from_network_dict(
		attempt.catch_payload,
		fish,
	)
	if fish_catch == null or not fish_catch.is_valid():
		_cancel_attempt(peer_id, "Fishing attempt ended.")
		return
	attempt.phase = NetworkFishingAttempt.Phase.PENDING_CAPACITY
	attempt.result_id = _new_id("result")
	attempt.catch_payload = fish_catch.to_network_dict()
	attempt.capacity_nonce = _new_id("capacity")
	attempt.capacity_deadline = (
		Time.get_ticks_msec() / 1000.0 + CAPACITY_RESPONSE_TIMEOUT
	)
	var probe: Dictionary = {
		"attempt_id": attempt.attempt_id,
		"capacity_nonce": attempt.capacity_nonce,
		"catch_id": str(fish_catch.catch_id),
	}
	if peer_id == _session.get_local_peer_id():
		_handle_local_capacity_probe(probe)
	else:
		receive_capacity_probe.rpc_id(peer_id, probe)


@rpc("authority", "call_remote", "reliable", 0)
func receive_capacity_probe(data: Dictionary) -> void:
	_handle_local_capacity_probe(data)


func _handle_local_capacity_probe(data: Dictionary) -> void:
	if (
		typeof(data.get("attempt_id")) != TYPE_STRING
		or typeof(data.get("capacity_nonce")) != TYPE_STRING
		or typeof(data.get("catch_id")) != TYPE_STRING
	):
		return
	var can_accept: bool = (
		_local_inventory != null
		and _local_capacity != null
		and (
			_local_inventory.contains_catch_id(StringName(data["catch_id"]))
			or _local_inventory.get_all_catches().size()
			< _local_capacity.get_capacity()
		)
	)
	if _session.is_host():
		_handle_capacity_response(
			_session.get_local_peer_id(),
			str(data["attempt_id"]),
			str(data["capacity_nonce"]),
			can_accept
		)
	else:
		submit_capacity_response.rpc_id(
			1,
			str(data["attempt_id"]),
			str(data["capacity_nonce"]),
			can_accept
		)


@rpc("any_peer", "call_remote", "reliable", 0)
func submit_capacity_response(
	attempt_id: String,
	capacity_nonce: String,
	can_accept: bool,
) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if not _session.is_host() or not _session.is_authenticated_peer(sender_id):
		return
	_handle_capacity_response(
		sender_id, attempt_id, capacity_nonce, can_accept
	)


func _handle_capacity_response(
	peer_id: int,
	attempt_id: String,
	capacity_nonce: String,
	can_accept: bool,
) -> void:
	var attempt: NetworkFishingAttempt = _attempts.get(peer_id)
	if (
		attempt == null
		or attempt.phase != NetworkFishingAttempt.Phase.PENDING_CAPACITY
		or attempt.attempt_id != attempt_id
		or attempt.capacity_nonce != capacity_nonce
	):
		return
	if not can_accept:
		_cancel_attempt(peer_id, "Cooler is full.")
		return
	_finalize_catch(attempt)


func _finalize_catch(attempt: NetworkFishingAttempt) -> void:
	attempt.phase = NetworkFishingAttempt.Phase.CAUGHT
	var outcome: Dictionary = {
		"result_id": attempt.result_id,
		"request_id": attempt.request_id,
		"attempt_id": attempt.attempt_id,
		"owner_peer_id": attempt.owner_peer_id,
		"session_id": attempt.session_id,
		"outcome": int(NetworkFishingProtocol.Outcome.CATCH),
		"catch": attempt.catch_payload.duplicate(true),
	}
	if attempt.owner_peer_id == _session.get_local_peer_id():
		_apply_target_outcome(outcome)
	else:
		receive_target_outcome.rpc_id(attempt.owner_peer_id, outcome)
	_broadcast_public_outcome(
		attempt,
		&"catch",
		"",
		attempt.catch_payload,
	)
	_dispose_attempt(attempt.owner_peer_id)


@rpc("authority", "call_remote", "reliable", 0)
func receive_target_outcome(data: Dictionary) -> void:
	_apply_target_outcome(data)


func _apply_target_outcome(data: Dictionary) -> void:
	if not _validate_target_outcome(data):
		return
	var result_id: String = data["result_id"]
	var catch_data: Dictionary = data["catch"]
	var catch_id := StringName(str(catch_data.get("catch_id", "")))
	if _result_ledgers.has(result_id):
		_acknowledge_result(result_id, catch_id)
		return
	var fish_id := StringName(str(catch_data.get("fish_id", "")))
	var fish: FishDataType = _fish_catalog.get_fish_by_id(fish_id)
	var fish_catch: FishCatch = FishCatchType.from_network_dict(
		catch_data, fish
	)
	if fish_catch == null:
		return
	var already_owned: bool = _local_inventory.contains_catch_id(catch_id)
	if (
		not already_owned
		and _local_inventory.get_all_catches().size()
		>= _local_capacity.get_capacity()
	):
		return
	if not already_owned:
		var experience_award: int = (
			FishExperienceType.calculate_for_collection(
				fish_catch,
				_local_collection,
			)
		)
		_local_inventory.add_catch(fish_catch)
		_local_collection.mark_quality_discovered(
			fish_id,
			fish_catch.quality,
		)
		_local_experience.award_experience(experience_award)
	if not _save_manager.save_if_dirty():
		return
	_result_ledgers[result_id] = true
	_bound_result_ledger()
	if not _session.is_host():
		_attempts.erase(_session.get_local_peer_id())
	local_catch_received.emit(fish_catch)
	_acknowledge_result(result_id, catch_id)


func _validate_target_outcome(data: Dictionary) -> bool:
	return (
		typeof(data.get("result_id")) == TYPE_STRING
		and typeof(data.get("request_id")) == TYPE_STRING
		and typeof(data.get("attempt_id")) == TYPE_STRING
		and typeof(data.get("owner_peer_id")) == TYPE_INT
		and int(data["owner_peer_id"]) == _session.get_local_peer_id()
		and typeof(data.get("session_id")) == TYPE_STRING
		and str(data["session_id"]) == _session.get_session_id()
		and int(data.get("outcome", -1))
		== NetworkFishingProtocol.Outcome.CATCH
		and typeof(data.get("catch")) == TYPE_DICTIONARY
	)


func _acknowledge_result(result_id: String, catch_id: StringName) -> void:
	if _session.is_host():
		return
	acknowledge_fishing_result.rpc_id(1, result_id, str(catch_id))


@rpc("any_peer", "call_remote", "reliable", 0)
func acknowledge_fishing_result(result_id: String, catch_id: String) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		not _session.is_host()
		or not _session.is_authenticated_peer(sender_id)
		or result_id.is_empty()
		or catch_id.is_empty()
	):
		return
	_result_acknowledgements[result_id] = catch_id
	while _result_acknowledgements.size() > MAX_LEDGER_ENTRIES_PER_PEER:
		_result_acknowledgements.erase(
			_result_acknowledgements.keys().front()
		)


func _on_attempt_escaped(peer_id: int) -> void:
	var attempt: NetworkFishingAttempt = _attempts.get(peer_id)
	if attempt == null:
		return
	attempt.phase = NetworkFishingAttempt.Phase.ESCAPED
	_broadcast_public_outcome(attempt, &"escape", "The fish got away!")
	_dispose_attempt(peer_id)


func _cancel_attempt(
	peer_id: int,
	message: String,
	outcome: StringName = &"cancelled",
) -> void:
	var attempt: NetworkFishingAttempt = _attempts.get(peer_id)
	if attempt == null:
		return
	attempt.phase = NetworkFishingAttempt.Phase.CANCELLED
	_broadcast_public_outcome(attempt, outcome, message)
	_dispose_attempt(peer_id)


func _broadcast_public_outcome(
	attempt: NetworkFishingAttempt,
	outcome: StringName,
	message: String,
	catch_payload: Dictionary = {},
) -> void:
	var data: Dictionary = {
		"attempt_id": attempt.attempt_id,
		"owner_peer_id": attempt.owner_peer_id,
		"outcome": str(outcome),
		"message": message.left(128),
	}
	if outcome == &"catch" and not catch_payload.is_empty():
		data["catch"] = catch_payload.duplicate(true)
	_apply_public_outcome(data)
	receive_public_outcome.rpc(data)


@rpc("authority", "call_remote", "reliable", 0)
func receive_public_outcome(data: Dictionary) -> void:
	_apply_public_outcome(data)


func _apply_public_outcome(data: Dictionary) -> void:
	if (
		typeof(data.get("owner_peer_id")) != TYPE_INT
		or typeof(data.get("outcome")) != TYPE_STRING
		or typeof(data.get("message")) != TYPE_STRING
	):
		return
	var peer_id: int = data["owner_peer_id"]
	if peer_id == _session.get_local_peer_id():
		if str(data["outcome"]) != "catch":
			if not _session.is_host():
				_attempts.erase(peer_id)
			local_attempt_ended.emit(
				StringName(str(data["outcome"])),
				str(data["message"])
			)
	else:
		var outcome := StringName(str(data["outcome"]))
		if outcome in [&"catch", &"escape", &"withdrawal"]:
			_return_remote_presentation(peer_id, outcome, data)
		else:
			_cleanup_remote_presentation(peer_id)


func _make_cast_accepted(attempt: NetworkFishingAttempt) -> Dictionary:
	return {
		"accepted": true,
		"request_id": attempt.request_id,
		"attempt_id": attempt.attempt_id,
		"owner_peer_id": attempt.owner_peer_id,
		"origin": NetworkFishingProtocol.vector3_to_array(attempt.origin),
		"target": NetworkFishingProtocol.vector3_to_array(attempt.target),
	}


func _broadcast_cast_accepted(data: Dictionary) -> void:
	_apply_cast_accepted(data)
	receive_cast_accepted.rpc(data)


@rpc("authority", "call_remote", "reliable", 0)
func receive_cast_accepted(data: Dictionary) -> void:
	_apply_cast_accepted(data)


func _apply_cast_accepted(data: Dictionary) -> void:
	if (
		typeof(data.get("attempt_id")) != TYPE_STRING
		or typeof(data.get("owner_peer_id")) != TYPE_INT
		or typeof(data.get("origin")) != TYPE_ARRAY
		or typeof(data.get("target")) != TYPE_ARRAY
	):
		return
	var peer_id: int = data["owner_peer_id"]
	var origin: Vector3 = NetworkFishingProtocol.array_to_vector3(
		data.get("origin", [])
	)
	var target: Vector3 = NetworkFishingProtocol.array_to_vector3(data["target"])
	if not origin.is_finite() or not target.is_finite():
		return
	if peer_id == _session.get_local_peer_id():
		var attempt := NetworkFishingAttempt.new()
		attempt.owner_peer_id = peer_id
		attempt.request_id = str(data.get("request_id", ""))
		attempt.attempt_id = str(data["attempt_id"])
		attempt.session_id = _session.get_session_id()
		attempt.phase = NetworkFishingAttempt.Phase.WAITING_FOR_BITE
		attempt.target = target
		# On the host this replaces the same authoritative value with itself.
		if not _session.is_host():
			_attempts[peer_id] = attempt
			var pending_bait_id: StringName = (
				_pending_local_bait_by_request.get(
					attempt.request_id,
					StringName(),
				)
			)
			_pending_local_bait_by_request.erase(attempt.request_id)
			if not pending_bait_id.is_empty() and (
				_local_bag == null
				or not _local_bag.remove_item(pending_bait_id, 1)
			):
				cancel_local_attempt("No bait available.")
				local_cast_rejected.emit("No bait available.")
				return
		local_cast_accepted.emit(attempt.attempt_id, target)
	else:
		var presentation := _get_remote_presentation(peer_id)
		if presentation != null:
			presentation.show_cast(origin, target)


@rpc("authority", "call_remote", "reliable", 0)
func receive_bite_pending(data: Dictionary) -> void:
	_apply_bite_pending(data)


func _apply_bite_pending(data: Dictionary) -> void:
	if (
		typeof(data.get("attempt_id")) != TYPE_STRING
		or typeof(data.get("owner_peer_id")) != TYPE_INT
	):
		return
	if int(data["owner_peer_id"]) == _session.get_local_peer_id():
		local_bite_pending.emit(str(data["attempt_id"]))


@rpc("authority", "call_remote", "reliable", 0)
func receive_bite_started(data: Dictionary) -> void:
	_apply_bite_started(data)


func _apply_bite_started(data: Dictionary) -> void:
	if (
		typeof(data.get("attempt_id")) != TYPE_STRING
		or typeof(data.get("owner_peer_id")) != TYPE_INT
	):
		return
	var peer_id: int = data["owner_peer_id"]
	if peer_id == _session.get_local_peer_id():
		local_bite_started.emit(str(data["attempt_id"]))
	else:
		var presentation := _get_remote_presentation(peer_id)
		if presentation != null:
			presentation.show_bite()


func _record_and_reject(
	peer_id: int,
	request_id: String,
	message: String,
) -> void:
	var response: Dictionary = {
		"accepted": false,
		"request_id": request_id,
		"message": message.left(128),
	}
	_record_request_response(peer_id, request_id, response)
	_send_cast_rejected(peer_id, request_id, message)


func _send_cast_rejected(
	peer_id: int,
	request_id: String,
	message: String,
) -> void:
	if peer_id == _session.get_local_peer_id():
		local_cast_rejected.emit(message)
	else:
		receive_cast_rejected.rpc_id(peer_id, request_id, message.left(128))


@rpc("authority", "call_remote", "reliable", 0)
func receive_cast_rejected(request_id: String, message: String) -> void:
	_pending_local_bait_by_request.erase(request_id)
	local_cast_rejected.emit(message)


func _record_request_response(
	peer_id: int,
	request_id: String,
	response: Dictionary,
) -> void:
	var ledger: Dictionary = _request_ledgers.get(peer_id, {})
	ledger[request_id] = response.duplicate(true)
	while ledger.size() > MAX_LEDGER_ENTRIES_PER_PEER:
		ledger.erase(ledger.keys().front())
	_request_ledgers[peer_id] = ledger


func _resend_request_response(peer_id: int, response: Dictionary) -> void:
	if bool(response.get("accepted", false)):
		if peer_id == _session.get_local_peer_id():
			_apply_cast_accepted(response)
		else:
			receive_cast_accepted.rpc_id(peer_id, response)
	else:
		_send_cast_rejected(
			peer_id,
			str(response.get("request_id", "")),
			str(response.get("message", "Fishing attempt ended."))
		)


func _get_remote_presentation(
	peer_id: int,
) -> RemoteFishingPresentation:
	var existing: RemoteFishingPresentation = _remote_presentations.get(peer_id)
	if existing != null and is_instance_valid(existing):
		return existing
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	if avatar == null:
		return null
	var presentation := RemotePresentationType.new()
	presentation.name = "RemoteFishing_%d" % peer_id
	add_child(presentation)
	presentation.setup(avatar)
	_remote_presentations[peer_id] = presentation
	return presentation


func _cleanup_remote_presentation(peer_id: int) -> void:
	var presentation: RemoteFishingPresentation = _remote_presentations.get(peer_id)
	_remote_presentations.erase(peer_id)
	if presentation != null and is_instance_valid(presentation):
		presentation.cleanup()
		presentation.queue_free()


func _return_remote_presentation(
	peer_id: int,
	outcome: StringName,
	data: Dictionary,
) -> void:
	var presentation: RemoteFishingPresentation = _remote_presentations.get(
		peer_id
	)
	_remote_presentations.erase(peer_id)
	if presentation == null or not is_instance_valid(presentation):
		return
	presentation.return_completed.connect(
		presentation.queue_free,
		CONNECT_ONE_SHOT,
	)
	var showcase_catch: FishCatch = null
	if outcome == &"catch" and typeof(data.get("catch")) == TYPE_DICTIONARY:
		var catch_data: Dictionary = data["catch"]
		var fish_id := StringName(str(catch_data.get("fish_id", "")))
		var fish: FishDataType = _fish_catalog.get_fish_by_id(fish_id)
		showcase_catch = FishCatchType.from_network_dict(catch_data, fish)
	presentation.play_return(showcase_catch)


func _dispose_attempt(peer_id: int) -> void:
	var attempt: NetworkFishingAttempt = _attempts.get(peer_id)
	_attempts.erase(peer_id)
	if attempt != null and attempt.controller != null:
		attempt.controller.reset()
		attempt.controller.queue_free()
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	var local_return_is_active: bool = (
		peer_id == _session.get_local_peer_id()
		and _fishing_spot != null
		and _fishing_spot.is_returning()
	)
	if avatar != null and not local_return_is_active:
		avatar.set_movement_enabled(true)


func _on_peer_removed(peer_id: int) -> void:
	if _session.is_host() and _attempts.has(peer_id):
		_cancel_attempt(peer_id, "Fishing attempt ended.")
	else:
		_attempts.erase(peer_id)
	_cleanup_remote_presentation(peer_id)
	_request_ledgers.erase(peer_id)
	_last_cast_time.erase(peer_id)
	_last_input_time.erase(peer_id)


func _on_avatar_removed(peer_id: int) -> void:
	_cleanup_remote_presentation(peer_id)


func _on_session_state_changed(state: NetworkSession.State) -> void:
	if state in [
		NetworkSession.State.INACTIVE,
		NetworkSession.State.DISCONNECTING,
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		_clear_all()


func _clear_all() -> void:
	for peer_id: int in _attempts.keys():
		var attempt: NetworkFishingAttempt = _attempts[peer_id]
		if attempt != null and attempt.controller != null:
			attempt.controller.queue_free()
	_attempts.clear()
	for peer_id: int in _remote_presentations.keys():
		_cleanup_remote_presentation(peer_id)
	_request_ledgers.clear()
	_result_ledgers.clear()
	_result_acknowledgements.clear()
	_last_cast_time.clear()
	_last_input_time.clear()
	_snapshot_accumulator = 0.0
	_local_input_sequence = 0


func _bound_result_ledger() -> void:
	while _result_ledgers.size() > MAX_LEDGER_ENTRIES_PER_PEER:
		_result_ledgers.erase(_result_ledgers.keys().front())


func _new_id(prefix: String) -> String:
	return "%s:%s" % [
		prefix,
		Crypto.new().generate_random_bytes(16).hex_encode(),
	]


func _new_seed() -> int:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(8)
	var seed_value: int = 0
	for byte: int in bytes:
		seed_value = (seed_value << 8) ^ byte
	return seed_value
