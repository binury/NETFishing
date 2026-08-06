class_name NetworkFishShowcaseService
extends Node

const FishPoolType = preload("res://fish/fish_pool.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishCatchType = preload("res://fish/fish_catch.gd")
const FishQualityType = preload("res://fish/fish_quality.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const PlayerHotbarType = preload("res://inventory/player_hotbar.gd")

var _session: NetworkSession
var _spawn_service: PlayerSpawnService
var _fish_catalog: FishPoolType
var _local_inventory: FishInventoryType
var _local_hotbar: PlayerHotbarType
var _states: Dictionary[int, Dictionary] = {}
var _local_revision: int = 0
var _local_visible: bool = false
var _local_catch_id: StringName


func setup(
	session: NetworkSession,
	spawn_service: PlayerSpawnService,
	fish_catalog: FishPoolType,
	local_inventory: FishInventoryType,
	local_hotbar: PlayerHotbarType,
) -> void:
	_session = session
	_spawn_service = spawn_service
	_fish_catalog = fish_catalog
	_local_inventory = local_inventory
	_local_hotbar = local_hotbar
	_session.peer_authenticated.connect(_on_peer_authenticated)
	_session.peer_removed.connect(_on_peer_removed)
	_session.state_changed.connect(_on_session_state_changed)
	_spawn_service.avatar_spawned.connect(_on_avatar_spawned)
	_local_inventory.catches_changed.connect(_on_local_inventory_changed)
	_local_hotbar.selected_assignment_changed.connect(
		_on_selected_assignment_changed
	)


func toggle_selected_fish() -> bool:
	if _local_hotbar == null or _local_inventory == null:
		return false
	var catch_id: StringName = _local_hotbar.get_selected_fish_catch_id()
	var fish_catch: FishCatchType = _local_inventory.get_catch_by_id(catch_id)
	if fish_catch == null or not fish_catch.is_valid():
		return false
	if _local_visible and _local_catch_id == catch_id:
		_submit_local_state(null, false)
	else:
		_submit_local_state(fish_catch, true)
	return true


func is_local_showcase_visible() -> bool:
	return _local_visible


func get_local_showcase_catch_id() -> StringName:
	return _local_catch_id


func _submit_local_state(fish_catch: FishCatchType, should_show: bool) -> void:
	_local_revision += 1
	var local_peer_id: int = (
		_session.get_local_peer_id() if _session != null else 1
	)
	var data: Dictionary = {
		"session_id": (
			_session.get_session_id()
			if _session != null and not _session.get_session_id().is_empty()
			else "local"
		),
		"owner_peer_id": local_peer_id,
		"visible": should_show and fish_catch != null,
		"fish_id": String(fish_catch.fish_id) if fish_catch != null else "",
		"weight_lb": fish_catch.weight_lb if fish_catch != null else 0.0,
		"display_scale": (
			fish_catch.display_scale if fish_catch != null else 0.0
		),
		"quality": (
			fish_catch.quality
			if fish_catch != null
			else FishQualityType.Tier.BORING
		),
		"revision": _local_revision,
	}
	_local_visible = bool(data["visible"])
	_local_catch_id = (
		fish_catch.catch_id if _local_visible else StringName()
	)
	_apply_state(data)
	if _session == null or not _session.is_gameplay_session_active():
		return
	data["session_id"] = _session.get_session_id()
	if _session.is_host():
		_handle_showcase_state(local_peer_id, data)
	elif _session.supports_server_capability(
		NetworkFishShowcaseProtocol.CAPABILITY
	):
		submit_showcase_state.rpc_id(1, data)


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	NetworkFishShowcaseProtocol.RELIABLE_CHANNEL,
)
func submit_showcase_state(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender_id):
		_handle_showcase_state(sender_id, data)


func _handle_showcase_state(peer_id: int, data: Dictionary) -> void:
	if (
		not _session.is_host()
		or not NetworkFishShowcaseProtocol.validate_state(data)
		or str(data["session_id"]) != _session.get_session_id()
		or int(data["owner_peer_id"]) != peer_id
		or (
			peer_id != _session.get_local_peer_id()
			and not _session.is_authenticated_peer(peer_id)
		)
	):
		return
	var previous: Dictionary = _states.get(peer_id, {})
	if int(data["revision"]) <= int(previous.get("revision", -1)):
		return
	if not _state_matches_catalog(data):
		return
	var sanitized: Dictionary = data.duplicate(true)
	_states[peer_id] = sanitized
	_apply_state(sanitized)
	receive_showcase_state.rpc(sanitized)


@rpc(
	"authority",
	"call_remote",
	"reliable",
	NetworkFishShowcaseProtocol.RELIABLE_CHANNEL,
)
func receive_showcase_state(data: Dictionary) -> void:
	if (
		not NetworkFishShowcaseProtocol.validate_state(data)
		or str(data["session_id"]) != _session.get_session_id()
		or not _state_matches_catalog(data)
	):
		return
	var peer_id: int = int(data["owner_peer_id"])
	var previous: Dictionary = _states.get(peer_id, {})
	if int(data["revision"]) <= int(previous.get("revision", -1)):
		return
	_states[peer_id] = data.duplicate(true)
	_apply_state(data)


func _state_matches_catalog(data: Dictionary) -> bool:
	if not bool(data["visible"]):
		return true
	var fish_id: StringName = StringName(str(data["fish_id"]))
	var fish: FishDataType = _fish_catalog.get_fish_by_id(fish_id)
	if fish == null or not fish.is_selectable():
		return false
	var weight_lb: float = float(data["weight_lb"])
	return (
		weight_lb >= fish.get_minimum_weight()
		and weight_lb <= fish.get_maximum_weight()
	)


func _apply_state(data: Dictionary) -> void:
	var peer_id: int = int(data["owner_peer_id"])
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	if avatar == null:
		return
	if not bool(data["visible"]):
		avatar.set_held_fish(null, 1.0, false)
		return
	var fish: FishDataType = _fish_catalog.get_fish_by_id(
		StringName(str(data["fish_id"]))
	)
	avatar.set_held_fish(
		fish,
		fish.get_display_scale_for_weight(float(data["weight_lb"])),
		true,
	)


func _on_selected_assignment_changed(
	_slot_index: int,
	kind: int,
	identity: StringName,
) -> void:
	if (
		_local_visible
		and (
			kind != PlayerHotbarType.AssignmentKind.FISH
			or identity != _local_catch_id
		)
	):
		_submit_local_state(null, false)


func _on_local_inventory_changed() -> void:
	if (
		_local_visible
		and not _local_inventory.contains_catch_id(_local_catch_id)
	):
		_submit_local_state(null, false)


func _on_peer_authenticated(peer_id: int, _display_name: String) -> void:
	if not _session.is_host():
		return
	for state: Dictionary in _states.values():
		if bool(state.get("visible", false)):
			receive_showcase_state.rpc_id(peer_id, state)


func _on_avatar_spawned(peer_id: int, _avatar: Player) -> void:
	var state: Dictionary = _states.get(peer_id, {})
	if not state.is_empty():
		_apply_state(state)


func _on_peer_removed(peer_id: int) -> void:
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	if avatar != null:
		avatar.set_held_fish(null, 1.0, false)
	_states.erase(peer_id)


func _on_session_state_changed(state: NetworkSession.State) -> void:
	if state not in [
		NetworkSession.State.INACTIVE,
		NetworkSession.State.DISCONNECTING,
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		return
	for peer_id: int in _states:
		var avatar: Player = _spawn_service.get_avatar(peer_id)
		if avatar != null:
			avatar.set_held_fish(null, 1.0, false)
	_states.clear()
	_local_visible = false
	_local_catch_id = StringName()
	var local_avatar: Player = _spawn_service.get_avatar(
		_session.get_local_peer_id()
	)
	if local_avatar != null:
		local_avatar.set_held_fish(null, 1.0, false)
