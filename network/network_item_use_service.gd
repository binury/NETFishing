class_name NetworkItemUseService
extends Node

const FishingRodDataType = preload("res://items/fishing_rod_data.gd")

const ArtShopStockType = preload("res://economy/art_shop_stock.gd")
const FishingShopStockType = preload("res://economy/fishing_shop_stock.gd")

const MAX_LEDGER_ENTRIES: int = 64

signal local_item_use_pending(request_id: String)
signal local_item_use_finished(accepted: bool, message: String)
signal equipped_state_changed(peer_id: int, item_id: StringName, category: int)

var _session: NetworkSession
var _spawn_service: PlayerSpawnService
var _catalog: ItemCatalog
var _local_bag: PlayerBag
var _local_effects: PlayerItemEffects
var _save_manager: PlayerSaveManager
var _requests: Dictionary[int, Dictionary] = {}
var _pending_by_peer: Dictionary[int, String] = {}
var _result_owners: Dictionary[String, int] = {}
var _received_results: Dictionary[String, bool] = {}
var _pending_local: Dictionary = {}
var _equipped_states: Dictionary[int, Dictionary] = {}
var _local_equipped_revision: int = 0
var _reservations: PlayerAssetReservationService


func setup(
	session: NetworkSession,
	spawn_service: PlayerSpawnService,
	catalog: ItemCatalog,
	local_bag: PlayerBag,
	local_effects: PlayerItemEffects,
	save_manager: PlayerSaveManager,
	reservations: PlayerAssetReservationService,
) -> void:
	_session = session
	_spawn_service = spawn_service
	_catalog = catalog
	_local_bag = local_bag
	_local_effects = local_effects
	_save_manager = save_manager
	_reservations = reservations
	_session.peer_removed.connect(_on_peer_removed)
	_session.state_changed.connect(_on_session_state_changed)
	_session.peer_authenticated.connect(_on_peer_authenticated)


func request_use(item_id: StringName) -> String:
	if not _pending_local.is_empty():
		local_item_use_finished.emit(false, "An item use is already pending.")
		return ""
	var consumed_item_id: StringName = _consumed_item_id(item_id)
	if item_id == PlayerItemEffects.FISH_FINDER_ID and (
		_local_bag == null
		or not _local_bag.owns_item(item_id)
		or _local_bag.get_quantity(consumed_item_id) < 1
	):
		local_item_use_finished.emit(
			false, PlayerItemEffects.FISH_FINDER_DEAD_MESSAGE
		)
		return ""
	if (
		_reservations != null
		and _reservations.get_available_item_quantity(consumed_item_id) < 1
	):
		local_item_use_finished.emit(false, "Reserved in a letter.")
		return ""
	if (
		_session == null
		or not _session.is_gameplay_session_active()
		or (
			not _session.is_host()
			and not _session.supports_server_capability(
				NetworkItemProtocol.ITEM_USE_CAPABILITY
			)
		)
	):
		local_item_use_finished.emit(false, "Item use is unavailable.")
		return ""
	var request_id := _new_id("item")
	var data := {
		"request_id": request_id,
		"session_id": _session.get_session_id(),
		"item_id": str(item_id),
		"quantity": _local_bag.get_quantity(consumed_item_id),
	}
	_pending_local = data.duplicate(true)
	local_item_use_pending.emit(request_id)
	if _session.is_host():
		_handle_use_request(_session.get_local_peer_id(), data)
	else:
		submit_item_use.rpc_id(1, data)
	return request_id


@rpc("any_peer", "call_remote", "reliable", NetworkItemProtocol.RELIABLE_CHANNEL)
func submit_item_use(data: Dictionary) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender_id):
		_handle_use_request(sender_id, data)


func _handle_use_request(peer_id: int, data: Dictionary) -> void:
	var request_id := str(data.get("request_id", ""))
	var ledger: Dictionary = _requests.get(peer_id, {})
	if ledger.has(request_id):
		_send_result(peer_id, ledger[request_id])
		return
	var error := NetworkItemProtocol.validate_use_request(data)
	if (
		error.is_empty()
		and str(data["session_id"]) != _session.get_session_id()
	):
		error = "Item use could not be completed."
	if error.is_empty() and _pending_by_peer.has(peer_id):
		error = "An item use is already pending."
	var item_id := StringName(str(data.get("item_id", "")))
	var item: ItemData = _catalog.get_item_by_id(item_id)
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	var duration: float = 0.0
	var is_fish_finder: bool = (
		item_id == PlayerItemEffects.FISH_FINDER_ID
		and item != null
		and item.category == ItemData.Category.TOOL
		and item.usable
		and item.equippable
	)
	if error.is_empty() and (
		item == null
		or not item.is_available()
		or (
			item.category != ItemData.Category.CONSUMABLE
			and not is_fish_finder
		)
		or not item.usable
	):
		error = "That item cannot be used now."
	if error.is_empty() and int(data["quantity"]) < 1:
		error = (
			PlayerItemEffects.FISH_FINDER_DEAD_MESSAGE
			if is_fish_finder
			else "You do not have that item."
		)
	if error.is_empty() and (
		avatar == null
		or avatar.is_water_recovery_active()
	):
		error = "That item cannot be used now."
	if error.is_empty():
		duration = avatar.item_effects.get_effect_duration(item_id)
		if duration <= 0.0:
			error = "That item cannot be used now."
	var result := {
		"result_id": _new_id("item_result"),
		"request_id": request_id if not request_id.is_empty() else "invalid",
		"session_id": _session.get_session_id(),
		"target_peer_id": peer_id,
		"accepted": error.is_empty(),
		"item_id": str(item_id) if not item_id.is_empty() else "invalid",
		"quantity": 1 if error.is_empty() else 0,
		"duration": duration if error.is_empty() else 0.0,
		"message": "Used %s." % item.display_name if error.is_empty() else error,
	}
	ledger[request_id] = result.duplicate(true)
	_bound(ledger)
	_requests[peer_id] = ledger
	_result_owners[result["result_id"]] = peer_id
	_pending_by_peer[peer_id] = request_id
	_send_result(peer_id, result)


func _send_result(peer_id: int, result: Dictionary) -> void:
	if peer_id == _session.get_local_peer_id():
		_apply_result(result)
	else:
		receive_item_use_result.rpc_id(peer_id, result)


@rpc("authority", "call_remote", "reliable", NetworkItemProtocol.RELIABLE_CHANNEL)
func receive_item_use_result(data: Dictionary) -> void:
	_apply_result(data)


func _apply_result(data: Dictionary) -> void:
	if (
		not NetworkItemProtocol.validate_use_result(data)
		or str(data["session_id"]) != _session.get_session_id()
		or int(data["target_peer_id"]) != _session.get_local_peer_id()
	):
		return
	var result_id: String = data["result_id"]
	if _received_results.has(result_id):
		_acknowledge(data, true, "")
		return
	if (
		_pending_local.is_empty()
		or str(data["request_id"]) != str(_pending_local.get("request_id", ""))
	):
		return
	if not bool(data["accepted"]):
		_received_results[result_id] = true
		_pending_local.clear()
		local_item_use_finished.emit(false, str(data["message"]))
		_acknowledge(data, false, str(data["message"]))
		return
	var item_id := StringName(str(data["item_id"]))
	var consumed_item_id: StringName = _consumed_item_id(item_id)
	if (
		_reservations != null
		and _reservations.get_available_item_quantity(consumed_item_id) < 1
	):
		_pending_local.clear()
		local_item_use_finished.emit(false, "Reserved in a letter.")
		_acknowledge(data, false, "Reserved in a letter.")
		return
	var bag_snapshot := _local_bag.get_all_items()
	if (
		_local_bag.get_quantity(consumed_item_id) < 1
		or not _local_bag.remove_item(consumed_item_id, 1)
		or not _save_manager.save_if_dirty()
	):
		_local_bag.replace_all_items(bag_snapshot)
		_save_manager.save_if_dirty()
		_pending_local.clear()
		local_item_use_finished.emit(false, "Item use could not be completed.")
		_acknowledge(data, false, "Item use could not be completed.")
		return
	_received_results[result_id] = true
	_bound(_received_results)
	_pending_local.clear()
	local_item_use_finished.emit(true, str(data["message"]))
	_acknowledge(data, true, "")


func _acknowledge(data: Dictionary, applied: bool, message: String) -> void:
	if _session.is_host():
		_handle_ack(
			_session.get_local_peer_id(),
			str(data["result_id"]),
			str(data["request_id"]),
			applied,
			message
		)
	else:
		acknowledge_item_use.rpc_id(
			1, str(data["result_id"]), str(data["request_id"]), applied,
			message.left(NetworkItemProtocol.MAX_MESSAGE_LENGTH)
		)


@rpc("any_peer", "call_remote", "reliable", NetworkItemProtocol.RELIABLE_CHANNEL)
func acknowledge_item_use(
	result_id: String,
	request_id: String,
	applied: bool,
	message: String,
) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender_id):
		_handle_ack(sender_id, result_id, request_id, applied, message)


func _handle_ack(
	peer_id: int,
	result_id: String,
	request_id: String,
	applied: bool,
	_message: String,
) -> void:
	if (
		_result_owners.get(result_id, 0) != peer_id
		or _pending_by_peer.get(peer_id, "") != request_id
	):
		return
	_pending_by_peer.erase(peer_id)
	if not applied:
		return
	var result: Dictionary = _requests.get(peer_id, {}).get(request_id, {})
	var avatar := _spawn_service.get_avatar(peer_id)
	if avatar == null or result.is_empty():
		return
	var item_id := StringName(str(result["item_id"]))
	avatar.item_effects.activate_authoritative(item_id, float(result["duration"]))
	_broadcast_effect(peer_id, item_id, float(result["duration"]))


func get_effects_for_peer(peer_id: int) -> PlayerItemEffects:
	var avatar := _spawn_service.get_avatar(peer_id)
	return avatar.item_effects if avatar != null else null


func get_equipped_item_id(peer_id: int) -> StringName:
	var state: Dictionary = _equipped_states.get(peer_id, {})
	if state.is_empty() or not bool(state.get("owns_item", false)):
		return StringName()
	return StringName(str(state.get("item_id", "")))


func submit_local_equipped(item_id: StringName, owns_item: bool) -> void:
	if _session == null or not _session.is_gameplay_session_active():
		return
	_local_equipped_revision += 1
	var item: ItemData = _catalog.get_item_by_id(item_id)
	var can_equip: bool = (
		item != null and item.is_available() and owns_item
	)
	var data := {
		"session_id": _session.get_session_id(),
		"owner_peer_id": _session.get_local_peer_id(),
		"item_id": str(item_id) if can_equip else "",
		"category": int(item.category) if can_equip else -1,
		"revision": _local_equipped_revision,
		"owns_item": can_equip,
	}
	if _session.is_host():
		_handle_equipped_state(_session.get_local_peer_id(), data)
	elif _session.supports_server_capability(
		NetworkItemProtocol.EQUIPMENT_CAPABILITY
	):
		submit_equipped_state.rpc_id(1, data)


@rpc("any_peer", "call_remote", "reliable", NetworkItemProtocol.RELIABLE_CHANNEL)
func submit_equipped_state(data: Dictionary) -> void:
	var sender_id := multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender_id):
		_handle_equipped_state(sender_id, data)


func _handle_equipped_state(peer_id: int, data: Dictionary) -> void:
	if (
		not NetworkItemProtocol.validate_equipped_state(data)
		or str(data["session_id"]) != _session.get_session_id()
		or int(data["owner_peer_id"]) != peer_id
	):
		return
	var previous: Dictionary = _equipped_states.get(peer_id, {})
	if int(data["revision"]) <= int(previous.get("revision", -1)):
		return
	var item_id := StringName(str(data["item_id"]))
	var item: ItemData = _catalog.get_item_by_id(item_id)
	if not item_id.is_empty() and (
		item == null
		or not item.is_available()
		or not bool(data["owns_item"])
		or int(item.category) != int(data["category"])
	):
		return
	_equipped_states[peer_id] = data.duplicate(true)
	_apply_equipped(data)
	receive_equipped_state.rpc(data)


@rpc("authority", "call_remote", "reliable", NetworkItemProtocol.RELIABLE_CHANNEL)
func receive_equipped_state(data: Dictionary) -> void:
	if NetworkItemProtocol.validate_equipped_state(data):
		_equipped_states[int(data["owner_peer_id"])] = data.duplicate(true)
		_apply_equipped(data)


func _apply_equipped(data: Dictionary) -> void:
	var peer_id: int = data["owner_peer_id"]
	var avatar := _spawn_service.get_avatar(peer_id)
	if avatar != null:
		var item_id := StringName(str(data["item_id"]))
		var item: ItemData = _catalog.get_item_by_id(item_id)
		avatar.set_active_fishing_rod(
			(
				item as FishingRodDataType
				if (
					item != null
					and item.is_available()
					and int(data["category"]) == ItemData.Category.ROD
					and bool(data["owns_item"])
				)
				else null
			),
			true,
		)
		avatar.set_active_art_kit(
			item.icon if item != null else null,
			item_id == ArtShopStockType.ART_KIT_ITEM_ID and bool(data["owns_item"]),
		)
		avatar.set_active_catching_net(
			item_id == FishingShopStockType.CRAB_NET_ID
			and bool(data["owns_item"]),
		)
	equipped_state_changed.emit(
		peer_id, StringName(str(data["item_id"])), int(data["category"])
	)


func _broadcast_effect(peer_id: int, item_id: StringName, duration: float) -> void:
	var data := {
		"session_id": _session.get_session_id(),
		"owner_peer_id": peer_id,
		"item_id": str(item_id),
		"remaining": duration,
	}
	_apply_effect_snapshot(data)
	receive_effect_snapshot.rpc(data)


@rpc("authority", "call_remote", "reliable", NetworkItemProtocol.RELIABLE_CHANNEL)
func receive_effect_snapshot(data: Dictionary) -> void:
	_apply_effect_snapshot(data)


func _apply_effect_snapshot(data: Dictionary) -> void:
	if (
		typeof(data.get("owner_peer_id")) != TYPE_INT
		or typeof(data.get("item_id")) != TYPE_STRING
		or typeof(data.get("remaining")) not in [TYPE_FLOAT, TYPE_INT]
		or str(data.get("session_id", "")) != _session.get_session_id()
	):
		return
	var avatar := _spawn_service.get_avatar(int(data["owner_peer_id"]))
	if avatar != null:
		avatar.item_effects.activate_authoritative(
			StringName(data["item_id"]), float(data["remaining"])
		)


func _on_peer_authenticated(peer_id: int, _display_name: String) -> void:
	if not _session.is_host():
		return
	for state: Dictionary in _equipped_states.values():
		receive_equipped_state.rpc_id(peer_id, state)


func _on_peer_removed(peer_id: int) -> void:
	_requests.erase(peer_id)
	_pending_by_peer.erase(peer_id)
	_equipped_states.erase(peer_id)


func _on_session_state_changed(state: NetworkSession.State) -> void:
	if state in [
		NetworkSession.State.INACTIVE,
		NetworkSession.State.DISCONNECTING,
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		var pending := not _pending_local.is_empty()
		_requests.clear()
		_pending_by_peer.clear()
		_result_owners.clear()
		_received_results.clear()
		_equipped_states.clear()
		_pending_local.clear()
		if pending:
			local_item_use_finished.emit(false, "Connection lost.")


func _bound(values: Dictionary) -> void:
	while values.size() > MAX_LEDGER_ENTRIES:
		values.erase(values.keys().front())


func _new_id(prefix: String) -> String:
	return "%s:%s" % [
		prefix, Crypto.new().generate_random_bytes(16).hex_encode(),
	]


func _consumed_item_id(item_id: StringName) -> StringName:
	return (
		PlayerItemEffects.BATTERIES_ID
		if item_id == PlayerItemEffects.FISH_FINDER_ID
		else item_id
	)
