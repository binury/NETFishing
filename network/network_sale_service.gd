class_name NetworkSaleService
extends Node

const FishCatchType = preload("res://fish/fish_catch.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const FishBuyerProfileType = preload("res://economy/fish_buyer_profile.gd")
const FishSaleServiceType = preload("res://economy/fish_sale_service.gd")
const FishSaleResultType = preload("res://economy/fish_sale_result.gd")

const MAX_LEDGER_ENTRIES_PER_PEER: int = 64
const PELICAN_INTERACTION_RANGE: float = 7.5

signal local_sale_pending(request_id: String)
signal local_sale_finished(
	request_id: String,
	accepted: bool,
	message: String,
	catch_ids: Array[StringName],
	payout: int,
)

var _session: NetworkSession
var _spawn_service: PlayerSpawnService
var _network_fishing: NetworkFishingService
var _inventory: FishInventory
var _wallet: PlayerWallet
var _sale_service: FishSaleServiceType
var _save_manager: PlayerSaveManager
var _fish_catalog: FishPoolType
var _buyer: FishBuyerProfileType
var _pelican_landmark: Node3D
var _request_ledgers: Dictionary[int, Dictionary] = {}
var _pending_by_peer: Dictionary[int, String] = {}
var _result_owners: Dictionary[String, int] = {}
var _acknowledged_results: Dictionary[String, bool] = {}
var _applied_results: Dictionary[String, bool] = {}
var _received_results: Dictionary[String, bool] = {}
var _pending_local_request_id: String = ""
var _pending_local_catch_ids: Array[StringName] = []
var _reservations: PlayerAssetReservationService


func setup(
	session: NetworkSession,
	spawn_service: PlayerSpawnService,
	network_fishing: NetworkFishingService,
	inventory: FishInventory,
	wallet: PlayerWallet,
	sale_service: FishSaleServiceType,
	save_manager: PlayerSaveManager,
	fish_catalog: FishPoolType,
	buyer: FishBuyerProfileType,
	pelican_landmark: Node3D,
	reservations: PlayerAssetReservationService,
) -> void:
	_session = session
	_spawn_service = spawn_service
	_network_fishing = network_fishing
	_inventory = inventory
	_wallet = wallet
	_sale_service = sale_service
	_save_manager = save_manager
	_fish_catalog = fish_catalog
	_buyer = buyer
	_pelican_landmark = pelican_landmark
	_reservations = reservations
	if not _session.peer_removed.is_connected(_on_peer_removed):
		_session.peer_removed.connect(_on_peer_removed)
	if not _session.state_changed.is_connected(_on_session_state_changed):
		_session.state_changed.connect(_on_session_state_changed)


func can_request_sale() -> bool:
	return (
		_session != null
		and _session.is_gameplay_session_active()
		and (
			_session.is_host()
			or _session.supports_server_capability(
				NetworkSaleProtocol.CAPABILITY
			)
		)
	)


func is_local_sale_pending() -> bool:
	return not _pending_local_request_id.is_empty()


func request_local_sale(catch_ids: Array[StringName]) -> String:
	for catch_id: StringName in catch_ids:
		if _reservations != null and _reservations.is_fish_reserved(catch_id):
			local_sale_finished.emit(
				"", false, "Reserved in a letter.", [], 0
			)
			return ""
	if is_local_sale_pending():
		local_sale_finished.emit(
			"", false, "Selling…", [], 0
		)
		return ""
	if not can_request_sale():
		local_sale_finished.emit(
			"",
			false,
			"Selling is not supported by this server.",
			[],
			0
		)
		return ""
	if catch_ids.is_empty() or _inventory == null:
		local_sale_finished.emit(
			"", false, "Sale could not be completed.", [], 0
		)
		return ""
	var evidence: Array[Dictionary] = []
	for catch_id: StringName in catch_ids:
		var fish_catch: FishCatch = _inventory.get_catch_by_id(catch_id)
		if fish_catch == null:
			local_sale_finished.emit(
				"", false, "That catch is no longer available.", [], 0
			)
			return ""
		evidence.append(fish_catch.to_network_dict())
	var request_id: String = _new_id("sale")
	var request: Dictionary = {
		"request_id": request_id,
		"session_id": _session.get_session_id(),
		"buyer_id": str(_buyer.id) if _buyer != null else "",
		"catches": evidence,
	}
	_pending_local_request_id = request_id
	_pending_local_catch_ids = catch_ids.duplicate()
	local_sale_pending.emit(request_id)
	if _session.is_host():
		_handle_sale_request(_session.get_local_peer_id(), request)
	else:
		submit_sale_request.rpc_id(1, request)
	return request_id


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	NetworkSaleProtocol.RELIABLE_CHANNEL
)
func submit_sale_request(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		_session == null
		or not _session.is_host()
		or not _session.is_authenticated_peer(sender_id)
	):
		return
	_handle_sale_request(sender_id, data)


func _handle_sale_request(peer_id: int, data: Dictionary) -> void:
	var validation_error: String = NetworkSaleProtocol.validate_request(data)
	var request_id: String = str(data.get("request_id", ""))
	var ledger: Dictionary = _request_ledgers.get(peer_id, {})
	if not request_id.is_empty() and ledger.has(request_id):
		_send_result(peer_id, ledger[request_id])
		return
	if not validation_error.is_empty():
		_record_and_send(peer_id, _rejected_result(
			request_id, validation_error
		))
		return
	if str(data["session_id"]) != _session.get_session_id():
		_record_and_send(peer_id, _rejected_result(
			request_id, "Sale could not be completed."
		))
		return
	if (
		_pending_by_peer.has(peer_id)
		and _pending_by_peer[peer_id] != request_id
	):
		_record_and_send(peer_id, _rejected_result(
			request_id, "A sale is already pending."
		))
		return
	if not _is_buyer_available_for_peer(peer_id):
		var avatar: Player = _spawn_service.get_avatar(peer_id)
		var message: String = (
			"The buyer is unavailable."
			if avatar == null or _pelican_landmark == null
			else "Move closer to the buyer."
		)
		_record_and_send(peer_id, _rejected_result(request_id, message))
		return
	if _buyer == null or not _buyer.is_valid():
		_record_and_send(peer_id, _rejected_result(
			request_id, "The buyer is unavailable."
		))
		return
	if StringName(str(data["buyer_id"])) != _buyer.id:
		_record_and_send(peer_id, _rejected_result(
			request_id, "The buyer is unavailable."
		))
		return
	var result: Dictionary = _build_authoritative_result(
		peer_id, request_id, data["catches"]
	)
	_pending_by_peer[peer_id] = request_id
	_record_and_send(peer_id, result)


func _build_authoritative_result(
	peer_id: int,
	request_id: String,
	evidence_values: Array,
) -> Dictionary:
	if _fish_catalog == null or _buyer == null:
		return _rejected_result(
			request_id, "The buyer is unavailable."
		)
	var catch_ids: Array[String] = []
	var base_value: int = 0
	var payout: int = 0
	for value: Variant in evidence_values:
		var evidence: Dictionary = value
		var fish_id := StringName(str(evidence.get("fish_id", "")))
		var fish: FishDataType = _fish_catalog.get_fish_by_id(fish_id)
		var decoded: FishCatch = FishCatchType.from_network_dict(
			evidence, fish
		)
		if decoded == null:
			return _rejected_result(
				request_id, "Sale could not be completed."
			)
		if (
			not str(decoded.catch_id).begins_with("%s:" % fish_id)
			or decoded.weight_lb < fish.get_minimum_weight()
			or decoded.weight_lb > fish.get_maximum_weight()
			or decoded.sale_value < fish.sell_value_min
			or decoded.sale_value > fish.sell_value_max
		):
			return _rejected_result(
				request_id, "Sale could not be completed."
			)
		if bool(evidence.get("is_favorited", false)):
			return _rejected_result(
				request_id, "Favorite catches cannot be sold."
			)
		var offer: int = _buyer.get_offer(decoded.sale_value)
		if (
			offer < 0
			or base_value > 9223372036854775807 - decoded.sale_value
			or payout > 9223372036854775807 - offer
		):
			return _rejected_result(
				request_id, "Sale could not be completed."
			)
		base_value += decoded.sale_value
		payout += offer
		catch_ids.append(str(decoded.catch_id))
	return {
		"result_id": _new_id("sale_result"),
		"request_id": request_id,
		"session_id": _session.get_session_id(),
		"target_peer_id": peer_id,
		"accepted": true,
		"catch_ids": catch_ids,
		"payout": payout,
		"base_value": base_value,
		"message": "Sale complete.",
	}


func _rejected_result(request_id: String, message: String) -> Dictionary:
	var safe_request_id: String = (
		request_id
		if (
			not request_id.is_empty()
			and request_id.length() <= NetworkSaleProtocol.MAX_ID_LENGTH
		)
		else "invalid"
	)
	return {
		"result_id": _new_id("sale_result"),
		"request_id": safe_request_id,
		"session_id": _session.get_session_id() if _session != null else "",
		"target_peer_id": 0,
		"accepted": false,
		"catch_ids": [],
		"payout": 0,
		"base_value": 0,
		"message": message.left(NetworkSaleProtocol.MAX_MESSAGE_LENGTH),
	}


func _record_and_send(peer_id: int, result: Dictionary) -> void:
	result["target_peer_id"] = peer_id
	var request_id: String = str(result["request_id"])
	var ledger: Dictionary = _request_ledgers.get(peer_id, {})
	ledger[request_id] = result.duplicate(true)
	while ledger.size() > MAX_LEDGER_ENTRIES_PER_PEER:
		ledger.erase(ledger.keys().front())
	_request_ledgers[peer_id] = ledger
	_result_owners[str(result["result_id"])] = peer_id
	_bound_dictionary(_result_owners)
	_send_result(peer_id, result)


func _send_result(peer_id: int, result: Dictionary) -> void:
	if peer_id == _session.get_local_peer_id():
		_apply_sale_result(result)
	else:
		receive_sale_result.rpc_id(peer_id, result)


@rpc(
	"authority",
	"call_remote",
	"reliable",
	NetworkSaleProtocol.RELIABLE_CHANNEL
)
func receive_sale_result(data: Dictionary) -> void:
	_apply_sale_result(data)


func _apply_sale_result(data: Dictionary) -> void:
	if (
		not NetworkSaleProtocol.validate_result(data)
		or _session == null
		or str(data["session_id"]) != _session.get_session_id()
		or int(data["target_peer_id"]) != _session.get_local_peer_id()
	):
		return
	var result_id: String = data["result_id"]
	if _received_results.has(result_id):
		_acknowledge_result(
			data, _applied_results.has(result_id), ""
		)
		return
	if str(data["request_id"]) != _pending_local_request_id:
		return
	if not bool(data["accepted"]):
		_received_results[result_id] = true
		_bound_dictionary(_received_results)
		_finish_local_sale(
			data["request_id"], false, str(data["message"]), [], 0
		)
		_acknowledge_result(data, false, str(data["message"]))
		return
	var catch_ids: Array[StringName] = []
	for value: Variant in data["catch_ids"]:
		if typeof(value) not in [TYPE_STRING, TYPE_STRING_NAME]:
			_fail_local_apply(data, "Sale could not be completed.")
			return
		catch_ids.append(StringName(str(value)))
	if catch_ids != _pending_local_catch_ids:
		_fail_local_apply(data, "Sale could not be completed.")
		return
	for catch_id: StringName in catch_ids:
		if _reservations != null and _reservations.is_fish_reserved(catch_id):
			_fail_local_apply(data, "Reserved in a letter.")
			return
	var preview: FishSaleResultType = _sale_service.preview_batch(
		catch_ids, _buyer
	)
	if not preview.is_success():
		var message: String = (
			"Favorite catches cannot be sold."
			if preview.status == FishSaleResultType.Status.FAVORITED
			else "That catch is no longer available."
		)
		_fail_local_apply(data, message)
		return
	if (
		preview.payout != int(data["payout"])
		or preview.base_value != int(data["base_value"])
	):
		_fail_local_apply(data, "Sale could not be completed.")
		return
	var inventory_snapshot: Array[FishCatch] = _inventory.get_all_catches()
	var sequence_snapshot: int = _inventory.get_next_catch_sequence()
	var wallet_snapshot: int = _wallet.get_balance()
	var local_result: FishSaleResultType = _sale_service.sell_batch(
		catch_ids, _buyer
	)
	if not local_result.is_success() or not _save_manager.save_if_dirty():
		_inventory.replace_all_catches(
			inventory_snapshot, sequence_snapshot
		)
		_wallet.restore_balance(wallet_snapshot)
		_save_manager.save_if_dirty()
		_fail_local_apply(data, "Sale could not be completed.")
		return
	_applied_results[result_id] = true
	_bound_dictionary(_applied_results)
	_received_results[result_id] = true
	_bound_dictionary(_received_results)
	_finish_local_sale(
		data["request_id"],
		true,
		"Sale complete.",
		catch_ids,
		int(data["payout"])
	)
	_acknowledge_result(data, true, "")


func _fail_local_apply(data: Dictionary, message: String) -> void:
	_finish_local_sale(data["request_id"], false, message, [], 0)
	_acknowledge_result(data, false, message)


func _finish_local_sale(
	request_id: String,
	accepted: bool,
	message: String,
	catch_ids: Array[StringName],
	payout: int,
) -> void:
	_pending_local_request_id = ""
	_pending_local_catch_ids.clear()
	local_sale_finished.emit(
		request_id, accepted, message, catch_ids, payout
	)


func _acknowledge_result(
	data: Dictionary,
	applied: bool,
	message: String,
) -> void:
	if _session.is_host():
		_handle_acknowledgement(
			_session.get_local_peer_id(),
			str(data["result_id"]),
			str(data["request_id"]),
			applied,
			message
		)
	else:
		acknowledge_sale_result.rpc_id(
			1,
			str(data["result_id"]),
			str(data["request_id"]),
			applied,
			message.left(NetworkSaleProtocol.MAX_MESSAGE_LENGTH)
		)


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	NetworkSaleProtocol.RELIABLE_CHANNEL
)
func acknowledge_sale_result(
	result_id: String,
	request_id: String,
	applied: bool,
	message: String,
) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		_session == null
		or not _session.is_host()
		or not _session.is_authenticated_peer(sender_id)
	):
		return
	_handle_acknowledgement(
		sender_id, result_id, request_id, applied, message
	)


func _handle_acknowledgement(
	peer_id: int,
	result_id: String,
	request_id: String,
	_applied: bool,
	_message: String,
) -> void:
	if (
		result_id.is_empty()
		or result_id.length() > NetworkSaleProtocol.MAX_ID_LENGTH
		or request_id.is_empty()
		or request_id.length() > NetworkSaleProtocol.MAX_ID_LENGTH
		or _message.length() > NetworkSaleProtocol.MAX_MESSAGE_LENGTH
		or _result_owners.get(result_id, 0) != peer_id
	):
		return
	_acknowledged_results[result_id] = true
	_bound_dictionary(_acknowledged_results)
	if _pending_by_peer.get(peer_id, "") == request_id:
		_pending_by_peer.erase(peer_id)


func _is_buyer_available_for_peer(peer_id: int) -> bool:
	if (
		_session == null
		or not _session.is_host()
		or not _session.is_gameplay_session_active()
		or _spawn_service == null
		or _pelican_landmark == null
		or not is_instance_valid(_pelican_landmark)
	):
		return false
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	if (
		avatar == null
		or avatar.is_water_recovery_active()
		or (
			_network_fishing != null
			and _network_fishing.has_peer_attempt(peer_id)
		)
	):
		return false
	return (
		avatar.global_position.distance_to(
			_pelican_landmark.global_position
		) <= PELICAN_INTERACTION_RANGE
	)


func _on_peer_removed(peer_id: int) -> void:
	_request_ledgers.erase(peer_id)
	_pending_by_peer.erase(peer_id)
	for result_id: String in _result_owners.keys():
		if _result_owners[result_id] == peer_id:
			_result_owners.erase(result_id)
			_acknowledged_results.erase(result_id)


func _on_session_state_changed(state: NetworkSession.State) -> void:
	if state in [
		NetworkSession.State.INACTIVE,
		NetworkSession.State.DISCONNECTING,
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		var had_pending: bool = is_local_sale_pending()
		_clear_session_state()
		if had_pending:
			local_sale_finished.emit(
				"", false, "Connection lost.", [], 0
			)


func _clear_session_state() -> void:
	_request_ledgers.clear()
	_pending_by_peer.clear()
	_result_owners.clear()
	_acknowledged_results.clear()
	_applied_results.clear()
	_received_results.clear()
	_pending_local_request_id = ""
	_pending_local_catch_ids.clear()


func _bound_dictionary(values: Dictionary) -> void:
	while values.size() > MAX_LEDGER_ENTRIES_PER_PEER:
		values.erase(values.keys().front())


func _new_id(prefix: String) -> String:
	return "%s:%s" % [
		prefix,
		Crypto.new().generate_random_bytes(16).hex_encode(),
	]
