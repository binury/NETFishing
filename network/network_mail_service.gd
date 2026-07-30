class_name NetworkMailService
extends Node

signal mailbox_changed
signal unread_count_changed(count: int)
signal operation_finished(success: bool, message: String)
signal peers_changed

const MAX_LEDGER: int = 256

var _session: NetworkSession
var _reservations: PlayerAssetReservationService
var _wallet: PlayerWallet
var _inventory: FishInventory
var _bag: PlayerBag
var _collection_log: CollectionLog
var _cooler_capacity: PlayerCoolerCapacity
var _item_catalog: ItemCatalog
var _fish_catalog: FishPool
var _save_manager: PlayerSaveManager

var _letters: Dictionary[String, Dictionary] = {}
var _local_letters: Dictionary[String, Dictionary] = {}
var _send_ledger: Dictionary[int, Dictionary] = {}
var _action_ledger: Dictionary[String, bool] = {}
var _sequence := 0
var _pending_local_send: Dictionary = {}
var _pending_transfers: Dictionary[String, Dictionary] = {}
var _local_removal_snapshots: Dictionary[String, Dictionary] = {}
var _received_awards: Dictionary[String, bool] = {}
var _relationship_policy: NetworkPlayerListService


func setup(
	session: NetworkSession,
	reservations: PlayerAssetReservationService,
	wallet: PlayerWallet,
	inventory: FishInventory,
	bag: PlayerBag,
	collection_log: CollectionLog,
	cooler_capacity: PlayerCoolerCapacity,
	item_catalog: ItemCatalog,
	fish_catalog: FishPool,
	save_manager: PlayerSaveManager,
) -> void:
	_session = session
	_reservations = reservations
	_wallet = wallet
	_inventory = inventory
	_bag = bag
	_collection_log = collection_log
	_cooler_capacity = cooler_capacity
	_item_catalog = item_catalog
	_fish_catalog = fish_catalog
	_save_manager = save_manager
	_session.peer_authenticated.connect(func(_id: int, _name: String) -> void:
		peers_changed.emit()
	)
	_session.peer_removed.connect(_on_peer_removed)
	_session.peer_display_name_changed.connect(
		func(_id: int, _name: String) -> void: peers_changed.emit()
	)
	_session.state_changed.connect(_on_session_state_changed)


func set_relationship_policy(policy: NetworkPlayerListService) -> void:
	_relationship_policy = policy


func refresh_relationship_filters() -> void:
	_emit_mailbox()
	peers_changed.emit()


func get_local_letters() -> Array[Dictionary]:
	var values: Array[Dictionary] = []
	for letter: Dictionary in _local_letters.values():
		if (
			int(letter["recipient_peer_id"]) == _session.get_local_peer_id()
			and not _letter_is_locally_blocked(letter)
		):
			values.append(letter.duplicate(true))
	values.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_unread := int(a["state"]) == NetworkMailProtocol.State.SENT_UNREAD
		var b_unread := int(b["state"]) == NetworkMailProtocol.State.SENT_UNREAD
		return a_unread != b_unread if a_unread != b_unread else (
			int(a["sequence"]) > int(b["sequence"])
		)
	)
	return values


func get_letter(mail_id: String) -> Dictionary:
	return _local_letters.get(mail_id, {}).duplicate(true)


func get_unread_count() -> int:
	var count := 0
	for letter: Dictionary in _local_letters.values():
		if (
			int(letter["recipient_peer_id"]) == _session.get_local_peer_id()
			and int(letter["state"]) == NetworkMailProtocol.State.SENT_UNREAD
			and not _letter_is_locally_blocked(letter)
		):
			count += 1
	return count


func is_local_recipient(letter: Dictionary) -> bool:
	return (
		int(letter.get("recipient_peer_id", 0))
		== _session.get_local_peer_id()
	)


func get_local_display_name() -> String:
	var record := _session.get_peer_record(_session.get_local_peer_id())
	return record.display_name if record != null else "Player"


func get_recipient_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	var local_id := _session.get_local_peer_id()
	for peer_id: int in _session.get_authenticated_peer_ids():
		if peer_id == local_id:
			continue
		var record := _session.get_peer_record(peer_id)
		if record != null and (
			_relationship_policy == null
			or not _relationship_policy.is_locally_blocked(
				record.identity_fingerprint
			)
		):
			choices.append({
				"peer_id": peer_id,
				"name": record.display_name,
				"fingerprint": record.identity_fingerprint,
			})
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0
	)
	var counts: Dictionary[String, int] = {}
	for choice: Dictionary in choices:
		var normalized := str(choice["name"]).to_lower()
		counts[normalized] = int(counts.get(normalized, 0)) + 1
	for choice: Dictionary in choices:
		var display_name: String = choice["name"]
		if int(counts.get(display_name.to_lower(), 0)) > 1:
			choice["label"] = "%s · %s" % [
				display_name,
				NetworkIdentityCrypto.compact_suffix(choice["fingerprint"]),
			]
		else:
			choice["label"] = display_name
	return choices


func send_letter(
	recipient_peer_id: int,
	greeting_id: String,
	body: String,
	salutation_id: String,
	attachment: Dictionary,
) -> bool:
	if (
		not _pending_local_send.is_empty()
		or not _session.is_gameplay_session_active()
		or recipient_peer_id == _session.get_local_peer_id()
		or not _session.is_authenticated_peer(recipient_peer_id)
		or (
			_relationship_policy != null
			and _relationship_policy.is_locally_blocked(
				_session.get_peer_record(recipient_peer_id).identity_fingerprint
			)
		)
		or (
			not _session.is_host()
			and not _session.supports_server_capability(
				NetworkMailProtocol.CAPABILITY
			)
		)
	):
		operation_finished.emit(false, "That player is no longer connected.")
		return false
	var request_id := _new_id("mail_request")
	var reservation_id := ""
	if int(attachment.get("type", 0)) != 0:
		reservation_id = _new_id("reservation")
		if not _reservations.reserve(reservation_id, attachment):
			operation_finished.emit(false, "That gift is not available.")
			return false
	var request := {
		"request_id": request_id,
		"session_id": _session.get_session_id(),
		"recipient_peer_id": recipient_peer_id,
		"greeting_id": greeting_id,
		"body": NetworkMailProtocol.sanitize_body(body),
		"salutation_id": salutation_id,
		"reservation_id": reservation_id,
		"attachment": attachment.duplicate(true),
		"sender_fingerprint": _session.get_local_identity_fingerprint(),
		"recipient_fingerprint": (
			_session.get_peer_record(recipient_peer_id).identity_fingerprint
		),
	}
	request["sender_signature"] = _session.sign_local_action(
		"mail_send", NetworkMailProtocol.mail_signature_fields(request)
	)
	if not NetworkMailProtocol.validate_send_request(request):
		if not reservation_id.is_empty():
			_reservations.release(reservation_id)
		operation_finished.emit(false, "Letter could not be sent.")
		return false
	_pending_local_send = request.duplicate(true)
	if _session.is_host():
		_handle_send(_session.get_local_peer_id(), request)
	else:
		submit_mail.rpc_id(1, request)
	return true


@rpc("any_peer", "call_remote", "reliable", NetworkMailProtocol.RELIABLE_CHANNEL)
func submit_mail(data: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender):
		_handle_send(sender, data)


func _handle_send(sender: int, data: Dictionary) -> void:
	var request_id := str(data.get("request_id", ""))
	var ledger: Dictionary = _send_ledger.get(sender, {})
	if ledger.has(request_id):
		_deliver_send_result(sender, ledger[request_id])
		return
	var error := ""
	if (
		not NetworkMailProtocol.validate_send_request(data)
		or str(data.get("session_id", "")) != _session.get_session_id()
	):
		error = "Letter could not be sent."
	var recipient := int(data.get("recipient_peer_id", 0))
	if error.is_empty() and (
		recipient == sender or not _session.is_authenticated_peer(recipient)
	):
		error = "That player is no longer connected."
	var sender_record := _session.get_peer_record(sender)
	var recipient_record := _session.get_peer_record(recipient)
	if error.is_empty() and (
		sender_record == null
		or recipient_record == null
		or sender_record.identity_fingerprint
			!= str(data.get("sender_fingerprint", ""))
		or recipient_record.identity_fingerprint
			!= str(data.get("recipient_fingerprint", ""))
		or not _session.verify_peer_action(
			sender,
			"mail_send",
			NetworkMailProtocol.mail_signature_fields(data),
			data.get("sender_signature", PackedByteArray()),
		)
	):
		error = "Letter identity could not be verified."
	if (
		error.is_empty()
		and _relationship_policy != null
		and _relationship_policy.pair_is_blocked(
			sender_record.identity_fingerprint,
			recipient_record.identity_fingerprint,
		)
	):
		error = "That player is unavailable."
	if error.is_empty() and _letters.size() >= NetworkMailProtocol.MAX_SESSION_LETTERS:
		error = "The session mailbox is full."
	var recipient_count := 0
	for letter: Dictionary in _letters.values():
		if int(letter["recipient_peer_id"]) == recipient:
			recipient_count += 1
	if (
		error.is_empty()
		and recipient_count >= NetworkMailProtocol.MAX_RECIPIENT_LETTERS
	):
		error = "That inbox is full."
	var attachment: Dictionary = data.get("attachment", {})
	if error.is_empty() and not _validate_attachment_structure(attachment):
		error = "That gift is not valid."
	var result := {
		"request_id": request_id if not request_id.is_empty() else "invalid",
		"accepted": error.is_empty(),
		"message": "Letter sent." if error.is_empty() else error,
		"reservation_id": str(data.get("reservation_id", "")),
	}
	if error.is_empty():
		_sequence += 1
		var letter := {
			"mail_id": _new_id("mail"),
			"session_id": _session.get_session_id(),
			"sequence": _sequence,
			"sender_peer_id": sender,
			"sender_display_name": sender_record.display_name,
			"recipient_peer_id": recipient,
			"recipient_display_name": recipient_record.display_name,
			"greeting_id": str(data["greeting_id"]),
			"body": NetworkMailProtocol.sanitize_body(data["body"]),
			"salutation_id": str(data["salutation_id"]),
			"reservation_id": str(data["reservation_id"]),
			"attachment": attachment.duplicate(true),
			"state": NetworkMailProtocol.State.SENT_UNREAD,
			"request_id": request_id,
			"sender_fingerprint": data["sender_fingerprint"],
			"recipient_fingerprint": data["recipient_fingerprint"],
			"sender_signature": data["sender_signature"],
			"sender_public_key": sender_record.identity_public_key,
		}
		_letters[letter["mail_id"]] = letter
		result["mail"] = letter
		_deliver_private_letter(sender, letter)
		_deliver_private_letter(recipient, letter)
	ledger[result["request_id"]] = result.duplicate(true)
	_bound(ledger)
	_send_ledger[sender] = ledger
	_deliver_send_result(sender, result)


func _deliver_private_letter(peer_id: int, letter: Dictionary) -> void:
	if peer_id == _session.get_local_peer_id():
		_receive_letter(letter)
	elif _session.is_authenticated_peer(peer_id):
		receive_private_letter.rpc_id(peer_id, letter)


@rpc("authority", "call_remote", "reliable", NetworkMailProtocol.RELIABLE_CHANNEL)
func receive_private_letter(letter: Dictionary) -> void:
	_receive_letter(letter)


func _receive_letter(letter: Dictionary) -> void:
	if (
		not NetworkMailProtocol.validate_mail(letter)
		or str(letter["session_id"]) != _session.get_session_id()
		or _session.get_local_peer_id() not in [
			int(letter["sender_peer_id"]), int(letter["recipient_peer_id"]),
		]
	):
		return
	var sender_public := NetworkIdentityCrypto.normalize_public_pem(
		str(letter.get("sender_public_key", ""))
	)
	if (
		not _session.matches_authenticated_session_identity(
			str(letter["sender_fingerprint"]), sender_public
		)
		or not NetworkIdentityCrypto.verify_fields(
			NetworkIdentityCrypto.load_public_key(sender_public),
			"mail_send",
			NetworkMailProtocol.mail_signature_fields(letter),
			letter["sender_signature"],
		)
	):
		return
	_local_letters[letter["mail_id"]] = letter.duplicate(true)
	_emit_mailbox()


func cancel_unaccepted_between(first: String, second: String) -> void:
	if not _session.is_host():
		return
	for letter: Dictionary in _letters.values():
		if not (
			str(letter.get("sender_fingerprint", "")) in [first, second]
			and str(letter.get("recipient_fingerprint", "")) in [first, second]
		):
			continue
		if int(letter.get("state", -1)) not in [
			NetworkMailProtocol.State.SENT_UNREAD,
			NetworkMailProtocol.State.READ,
		]:
			continue
		letter["state"] = NetworkMailProtocol.State.CANCELLED
		_request_release(
			int(letter["sender_peer_id"]), str(letter.get("reservation_id", ""))
		)
		_update_participants(letter)


func _deliver_send_result(peer_id: int, result: Dictionary) -> void:
	if peer_id == _session.get_local_peer_id():
		_receive_send_result(result)
	else:
		receive_send_result.rpc_id(peer_id, result)


@rpc("authority", "call_remote", "reliable", NetworkMailProtocol.RELIABLE_CHANNEL)
func receive_send_result(result: Dictionary) -> void:
	_receive_send_result(result)


func _receive_send_result(result: Dictionary) -> void:
	if (
		_pending_local_send.is_empty()
		or str(result.get("request_id", ""))
		!= str(_pending_local_send.get("request_id", ""))
	):
		return
	if not bool(result.get("accepted", false)):
		var reservation_id := str(_pending_local_send.get("reservation_id", ""))
		if not reservation_id.is_empty():
			_reservations.release(reservation_id)
	_pending_local_send.clear()
	operation_finished.emit(
		bool(result.get("accepted", false)),
		str(result.get("message", "Letter could not be sent."))
	)


func mark_read(mail_id: String) -> void:
	var request := _action_request(mail_id)
	if request.is_empty():
		return
	if _session.is_host():
		_handle_read(_session.get_local_peer_id(), request)
	else:
		submit_read.rpc_id(1, request)


@rpc("any_peer", "call_remote", "reliable", NetworkMailProtocol.RELIABLE_CHANNEL)
func submit_read(data: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender):
		_handle_read(sender, data)


func _handle_read(peer_id: int, data: Dictionary) -> void:
	var action_id := str(data.get("request_id", ""))
	if _action_ledger.has(action_id):
		return
	var letter: Dictionary = _letters.get(str(data.get("mail_id", "")), {})
	if (
		letter.is_empty()
		or int(letter["recipient_peer_id"]) != peer_id
		or str(data.get("session_id", "")) != _session.get_session_id()
	):
		return
	_action_ledger[action_id] = true
	if int(letter["state"]) == NetworkMailProtocol.State.SENT_UNREAD:
		letter["state"] = NetworkMailProtocol.State.READ
		_update_participants(letter)


func accept_gift(mail_id: String) -> void:
	var request := _action_request(mail_id)
	if request.is_empty():
		return
	var letter: Dictionary = _local_letters.get(mail_id, {})
	request["recipient_signature"] = _session.sign_local_action(
		"mail_accept",
		NetworkMailProtocol.acceptance_signature_fields(
			request,
			str(letter.get("sender_fingerprint", "")),
			str(letter.get("recipient_fingerprint", "")),
		),
	)
	if _session.is_host():
		_handle_accept(_session.get_local_peer_id(), request)
	else:
		submit_accept.rpc_id(1, request)


@rpc("any_peer", "call_remote", "reliable", NetworkMailProtocol.RELIABLE_CHANNEL)
func submit_accept(data: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender):
		_handle_accept(sender, data)


func _handle_accept(peer_id: int, data: Dictionary) -> void:
	var action_id := str(data.get("request_id", ""))
	var letter: Dictionary = _letters.get(str(data.get("mail_id", "")), {})
	if _action_ledger.has(action_id):
		return
	if (
		letter.is_empty()
		or int(letter["recipient_peer_id"]) != peer_id
		or int(letter["state"]) not in [
			NetworkMailProtocol.State.SENT_UNREAD,
			NetworkMailProtocol.State.READ,
		]
		or int(letter["attachment"].get("type", 0)) == 0
		or not _session.is_authenticated_peer(int(letter["sender_peer_id"]))
	):
		return
	var recipient_record := _session.get_peer_record(peer_id)
	if (
		recipient_record == null
		or recipient_record.identity_fingerprint
			!= str(letter.get("recipient_fingerprint", ""))
		or not _session.verify_peer_action(
			peer_id,
			"mail_accept",
			NetworkMailProtocol.acceptance_signature_fields(
				data,
				str(letter.get("sender_fingerprint", "")),
				str(letter.get("recipient_fingerprint", "")),
			),
			data.get("recipient_signature", PackedByteArray()),
		)
	):
		return
	_action_ledger[action_id] = true
	var transfer_id := _new_id("mail_transfer")
	letter["state"] = NetworkMailProtocol.State.ACCEPTANCE_PENDING
	letter["transfer_id"] = transfer_id
	_pending_transfers[transfer_id] = {
		"letter": letter,
		"recipient_prepared": false,
		"sender_removed": false,
	}
	_update_participants(letter)
	_request_prepare(int(letter["recipient_peer_id"]), transfer_id, letter)


func _request_prepare(peer_id: int, transfer_id: String, letter: Dictionary) -> void:
	if peer_id == _session.get_local_peer_id():
		_prepare_recipient(transfer_id, letter)
	else:
		prepare_recipient.rpc_id(peer_id, transfer_id, letter)


@rpc("authority", "call_remote", "reliable", NetworkMailProtocol.RELIABLE_CHANNEL)
func prepare_recipient(transfer_id: String, letter: Dictionary) -> void:
	_prepare_recipient(transfer_id, letter)


func _prepare_recipient(transfer_id: String, letter: Dictionary) -> void:
	var recipient_ready: bool = _can_receive(letter["attachment"])
	_send_phase_ack("recipient_prepared", transfer_id, recipient_ready)


func _request_sender_commit(peer_id: int, transfer_id: String, letter: Dictionary) -> void:
	if peer_id == _session.get_local_peer_id():
		_commit_sender(transfer_id, letter)
	else:
		commit_sender.rpc_id(peer_id, transfer_id, letter)


@rpc("authority", "call_remote", "reliable", NetworkMailProtocol.RELIABLE_CHANNEL)
func commit_sender(transfer_id: String, letter: Dictionary) -> void:
	_commit_sender(transfer_id, letter)


func _commit_sender(transfer_id: String, letter: Dictionary) -> void:
	var reservation_id: String = letter["reservation_id"]
	var snapshot := _capture_assets()
	var applied := (
		_reservations.has_reservation(reservation_id)
		and _reservations.commit_removal(reservation_id)
		and _save_manager.save_if_dirty()
	)
	if not applied:
		_restore_assets(snapshot)
		_save_manager.save_if_dirty()
	else:
		_local_removal_snapshots[transfer_id] = snapshot
	_send_phase_ack("sender_removed", transfer_id, applied)


func _request_recipient_award(
	peer_id: int, transfer_id: String, letter: Dictionary
) -> void:
	if peer_id == _session.get_local_peer_id():
		_award_recipient(transfer_id, letter)
	else:
		award_recipient.rpc_id(peer_id, transfer_id, letter)


@rpc("authority", "call_remote", "reliable", NetworkMailProtocol.RELIABLE_CHANNEL)
func award_recipient(transfer_id: String, letter: Dictionary) -> void:
	_award_recipient(transfer_id, letter)


func _award_recipient(transfer_id: String, letter: Dictionary) -> void:
	if _received_awards.has(transfer_id):
		_send_phase_ack("recipient_awarded", transfer_id, true)
		return
	var snapshot := _capture_assets()
	var applied := _apply_award(letter["attachment"])
	if applied:
		applied = _save_manager.save_if_dirty()
	if not applied:
		_restore_assets(snapshot)
		_save_manager.save_if_dirty()
	else:
		_received_awards[transfer_id] = true
		_bound(_received_awards)
	_send_phase_ack("recipient_awarded", transfer_id, applied)


func _send_phase_ack(phase: String, transfer_id: String, applied: bool) -> void:
	var letter := _find_local_transfer_letter(transfer_id)
	var fields := _gift_phase_fields(phase, transfer_id, applied, letter)
	var fingerprint := _session.get_local_identity_fingerprint()
	var signature := _session.sign_local_action(
		"gift_%s" % phase, fields
	)
	if _session.is_host():
		_handle_phase_ack(
			_session.get_local_peer_id(),
			phase,
			transfer_id,
			applied,
			fingerprint,
			signature,
		)
	else:
		acknowledge_transfer_phase.rpc_id(
			1, phase, transfer_id, applied, fingerprint, signature
		)


@rpc("any_peer", "call_remote", "reliable", NetworkMailProtocol.RELIABLE_CHANNEL)
func acknowledge_transfer_phase(
	phase: String,
	transfer_id: String,
	applied: bool,
	fingerprint: String,
	signature: PackedByteArray,
) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender):
		_handle_phase_ack(
			sender, phase, transfer_id, applied, fingerprint, signature
		)


func _handle_phase_ack(
	peer_id: int,
	phase: String,
	transfer_id: String,
	applied: bool,
	fingerprint: String,
	signature: PackedByteArray,
) -> void:
	var transfer: Dictionary = _pending_transfers.get(transfer_id, {})
	if transfer.is_empty():
		return
	var letter: Dictionary = transfer["letter"]
	var record := _session.get_peer_record(peer_id)
	if (
		record == null
		or record.identity_fingerprint != fingerprint
		or not _session.verify_peer_action(
			peer_id,
			"gift_%s" % phase,
			_gift_phase_fields(phase, transfer_id, applied, letter),
			signature,
		)
	):
		return
	if phase == "recipient_prepared":
		if peer_id != int(letter["recipient_peer_id"]):
			return
		if not applied:
			_finish_transfer(transfer_id, false, "Gift could not be transferred.")
			return
		transfer["recipient_prepared"] = true
		_request_sender_commit(int(letter["sender_peer_id"]), transfer_id, letter)
	elif phase == "sender_removed":
		if peer_id != int(letter["sender_peer_id"]):
			return
		if not applied:
			_finish_transfer(transfer_id, false, "Gift returned to sender.")
			return
		transfer["sender_removed"] = true
		_request_recipient_award(
			int(letter["recipient_peer_id"]), transfer_id, letter
		)
	elif phase == "recipient_awarded":
		if peer_id != int(letter["recipient_peer_id"]):
			return
		if applied:
			_finish_transfer(transfer_id, true, "Gift accepted.")
		else:
			_request_sender_rollback(
				int(letter["sender_peer_id"]), transfer_id
			)
			_finish_transfer(transfer_id, false, "Gift could not be transferred.")


func _find_local_transfer_letter(transfer_id: String) -> Dictionary:
	for value: Dictionary in _local_letters.values():
		if str(value.get("transfer_id", "")) == transfer_id:
			return value
	return {}


func _gift_phase_fields(
	phase: String,
	transfer_id: String,
	applied: bool,
	letter: Dictionary,
) -> Array:
	return [
		_session.get_session_id(),
		transfer_id,
		str(letter.get("mail_id", "")),
		str(letter.get("sender_fingerprint", "")),
		str(letter.get("recipient_fingerprint", "")),
		phase,
		applied,
	]


func _request_sender_rollback(peer_id: int, transfer_id: String) -> void:
	if peer_id == _session.get_local_peer_id():
		_rollback_sender(transfer_id)
	else:
		rollback_sender.rpc_id(peer_id, transfer_id)


@rpc("authority", "call_remote", "reliable", NetworkMailProtocol.RELIABLE_CHANNEL)
func rollback_sender(transfer_id: String) -> void:
	_rollback_sender(transfer_id)


func _rollback_sender(transfer_id: String) -> void:
	var snapshot: Dictionary = _local_removal_snapshots.get(transfer_id, {})
	if not snapshot.is_empty():
		_restore_assets(snapshot)
		_save_manager.save_if_dirty()
		_local_removal_snapshots.erase(transfer_id)


func _finish_transfer(transfer_id: String, accepted: bool, message: String) -> void:
	var transfer: Dictionary = _pending_transfers.get(transfer_id, {})
	if transfer.is_empty():
		return
	var letter: Dictionary = transfer["letter"]
	letter["state"] = (
		NetworkMailProtocol.State.ACCEPTED
		if accepted else NetworkMailProtocol.State.ATTACHMENT_RECALLED
	)
	_pending_transfers.erase(transfer_id)
	_update_participants(letter)
	operation_finished.emit(accepted, message)


func decline_gift(mail_id: String) -> void:
	var request := _action_request(mail_id)
	if request.is_empty():
		return
	if _session.is_host():
		_handle_decline(_session.get_local_peer_id(), request)
	else:
		submit_decline.rpc_id(1, request)


@rpc("any_peer", "call_remote", "reliable", NetworkMailProtocol.RELIABLE_CHANNEL)
func submit_decline(data: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if _session.is_host() and _session.is_authenticated_peer(sender):
		_handle_decline(sender, data)


func _handle_decline(peer_id: int, data: Dictionary) -> void:
	var action_id := str(data.get("request_id", ""))
	var letter: Dictionary = _letters.get(str(data.get("mail_id", "")), {})
	if _action_ledger.has(action_id):
		return
	if (
		letter.is_empty()
		or int(letter["recipient_peer_id"]) != peer_id
		or int(letter["state"]) not in [
			NetworkMailProtocol.State.SENT_UNREAD,
			NetworkMailProtocol.State.READ,
		]
	):
		return
	_action_ledger[action_id] = true
	letter["state"] = NetworkMailProtocol.State.DECLINED
	_request_release(int(letter["sender_peer_id"]), letter["reservation_id"])
	_update_participants(letter)


func _request_release(peer_id: int, reservation_id: String) -> void:
	if reservation_id.is_empty():
		return
	if peer_id == _session.get_local_peer_id():
		_reservations.release(reservation_id)
	else:
		release_reservation.rpc_id(peer_id, reservation_id)


@rpc("authority", "call_remote", "reliable", NetworkMailProtocol.RELIABLE_CHANNEL)
func release_reservation(reservation_id: String) -> void:
	_reservations.release(reservation_id)


func _update_participants(letter: Dictionary) -> void:
	_letters[letter["mail_id"]] = letter
	_deliver_private_letter(int(letter["sender_peer_id"]), letter)
	_deliver_private_letter(int(letter["recipient_peer_id"]), letter)


func _action_request(mail_id: String) -> Dictionary:
	if mail_id.is_empty() or not _local_letters.has(mail_id):
		return {}
	return {
		"request_id": _new_id("mail_action"),
		"mail_id": mail_id,
		"session_id": _session.get_session_id(),
	}


func _validate_attachment_structure(attachment: Dictionary) -> bool:
	if typeof(attachment.get("type")) != TYPE_INT:
		return false
	match int(attachment["type"]):
		PlayerAssetReservationService.AttachmentType.NONE:
			return attachment.size() == 1
		PlayerAssetReservationService.AttachmentType.FISH_COIN:
			return (
				attachment.size() == 2
				and
				typeof(attachment.get("amount")) == TYPE_INT
				and int(attachment["amount"]) >= 1
				and int(attachment["amount"]) <= 1000000000
			)
		PlayerAssetReservationService.AttachmentType.FISH:
			if not (
				attachment.size() == 3
				and
				typeof(attachment.get("catch_id")) == TYPE_STRING
				and typeof(attachment.get("catch")) == TYPE_DICTIONARY
			):
				return false
			var fish_catch := _decode_catch(attachment)
			return (
				fish_catch != null
				and str(fish_catch.catch_id) == str(attachment["catch_id"])
				and not bool(
					Dictionary(attachment["catch"]).get("is_favorited", false)
				)
			)
		PlayerAssetReservationService.AttachmentType.CONSUMABLE:
			var item := _item_catalog.get_item_by_id(
				StringName(str(attachment.get("item_id", "")))
			)
			return (
				attachment.size() == 3
				and
				item != null
				and item.category == ItemData.Category.CONSUMABLE
				and typeof(attachment.get("quantity")) == TYPE_INT
				and int(attachment["quantity"]) >= 1
				and int(attachment["quantity"]) <= item.max_stack
			)
	return false


func _can_receive(attachment: Dictionary) -> bool:
	match int(attachment.get("type", 0)):
		PlayerAssetReservationService.AttachmentType.FISH_COIN:
			return _wallet.can_credit(int(attachment["amount"]))
		PlayerAssetReservationService.AttachmentType.FISH:
			return (
				_inventory.get_all_catches().size() < _cooler_capacity.get_capacity()
				and not _inventory.contains_catch_id(
					StringName(str(attachment["catch_id"]))
				)
				and _decode_catch(attachment) != null
			)
		PlayerAssetReservationService.AttachmentType.CONSUMABLE:
			return _bag.can_add_item(
				StringName(str(attachment["item_id"])),
				int(attachment["quantity"])
			)
	return false


func _apply_award(attachment: Dictionary) -> bool:
	if not _can_receive(attachment):
		return false
	match int(attachment["type"]):
		PlayerAssetReservationService.AttachmentType.FISH_COIN:
			return _wallet.credit(int(attachment["amount"]))
		PlayerAssetReservationService.AttachmentType.FISH:
			var fish_catch := _decode_catch(attachment)
			_inventory.add_catch(fish_catch)
			_collection_log.mark_discovered(fish_catch.fish_id)
			return _inventory.contains_catch_id(fish_catch.catch_id)
		PlayerAssetReservationService.AttachmentType.CONSUMABLE:
			return _bag.add_item(
				StringName(str(attachment["item_id"])),
				int(attachment["quantity"])
			)
	return false


func _decode_catch(attachment: Dictionary) -> FishCatch:
	var data: Dictionary = attachment.get("catch", {})
	var fish := _fish_catalog.get_fish_by_id(
		StringName(str(data.get("fish_id", "")))
	)
	return FishCatch.from_network_dict(data, fish)


func _capture_assets() -> Dictionary:
	return {
		"wallet": _wallet.get_balance(),
		"bag": _bag.get_all_items(),
		"catches": _inventory.get_all_catches(),
		"next_sequence": _inventory.get_next_catch_sequence(),
		"discovered": _collection_log.get_discovered_ids(),
	}


func _restore_assets(snapshot: Dictionary) -> void:
	_wallet.restore_balance(int(snapshot["wallet"]))
	_bag.replace_all_items(snapshot["bag"])
	_inventory.replace_all_catches(
		snapshot["catches"], int(snapshot["next_sequence"])
	)
	_collection_log.replace_discovered_ids(snapshot["discovered"])


func _emit_mailbox() -> void:
	mailbox_changed.emit()
	unread_count_changed.emit(get_unread_count())


func _letter_is_locally_blocked(letter: Dictionary) -> bool:
	if _relationship_policy == null:
		return false
	var local_id := _session.get_local_peer_id()
	var other_fingerprint := (
		str(letter.get("sender_fingerprint", ""))
		if int(letter.get("sender_peer_id", 0)) != local_id
		else str(letter.get("recipient_fingerprint", ""))
	)
	return _relationship_policy.is_locally_blocked(other_fingerprint)


func _on_peer_removed(peer_id: int) -> void:
	if not _session.is_host():
		_clear_local_mail_for_peer(peer_id)
		return
	for letter: Dictionary in _letters.values():
		if int(letter["recipient_peer_id"]) == peer_id:
			if int(letter["state"]) in [
				NetworkMailProtocol.State.SENT_UNREAD,
				NetworkMailProtocol.State.READ,
			]:
				letter["state"] = NetworkMailProtocol.State.CANCELLED
				_request_release(
					int(letter["sender_peer_id"]), letter["reservation_id"]
				)
				_deliver_private_letter(
					int(letter["sender_peer_id"]), letter
				)
		elif (
			int(letter["sender_peer_id"]) == peer_id
			and int(letter["state"]) in [
				NetworkMailProtocol.State.SENT_UNREAD,
				NetworkMailProtocol.State.READ,
			]
		):
			letter["state"] = NetworkMailProtocol.State.ATTACHMENT_RECALLED
			_update_participants(letter)
	_send_ledger.erase(peer_id)
	_clear_local_mail_for_peer(peer_id)
	peers_changed.emit()


func _clear_local_mail_for_peer(peer_id: int) -> void:
	for mail_id: String in _local_letters.keys():
		var letter: Dictionary = _local_letters[mail_id]
		if int(letter["recipient_peer_id"]) == peer_id:
			_local_letters.erase(mail_id)
	_emit_mailbox()


func _on_session_state_changed(state: NetworkSession.State) -> void:
	if state in [
		NetworkSession.State.INACTIVE,
		NetworkSession.State.DISCONNECTING,
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		_reservations.release_all()
		_letters.clear()
		_local_letters.clear()
		_send_ledger.clear()
		_action_ledger.clear()
		_pending_local_send.clear()
		_pending_transfers.clear()
		_local_removal_snapshots.clear()
		_received_awards.clear()
		_sequence = 0
		_emit_mailbox()


func _bound(values: Dictionary) -> void:
	while values.size() > MAX_LEDGER:
		values.erase(values.keys().front())


func _new_id(prefix: String) -> String:
	return "%s:%s" % [
		prefix, Crypto.new().generate_random_bytes(16).hex_encode(),
	]
