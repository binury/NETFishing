class_name PeerRegistry
extends RefCounted

class PeerRecord:
	extends RefCounted

	var peer_id: int = 0
	var profile_id: String = ""
	var display_name: String = ""
	var protocol_version: int = 0
	var joined_at_unix: int = 0
	var appearance_snapshot: Dictionary = (
		CharacterCustomizationCatalog.default_snapshot()
	)
	var identity_fingerprint: String = ""
	var identity_public_key: String = ""
	var identity_authenticated: bool = false
	var profile_authorization: Dictionary = {}


var _records: Dictionary[int, PeerRecord] = {}


func add_peer(
	peer_id: int,
	profile_id: String,
	display_name: String,
	protocol_version: int,
	identity_fingerprint: String = "",
	identity_public_key: String = "",
) -> bool:
	if (
		peer_id <= 0
		or profile_id.is_empty()
		or (
			not identity_fingerprint.is_empty()
			and has_fingerprint(identity_fingerprint)
		)
	):
		return false
	var record := PeerRecord.new()
	record.peer_id = peer_id
	record.profile_id = profile_id
	record.display_name = display_name
	record.protocol_version = protocol_version
	record.joined_at_unix = int(Time.get_unix_time_from_system())
	record.identity_fingerprint = identity_fingerprint
	record.identity_public_key = identity_public_key
	record.identity_authenticated = NetworkIdentityCrypto.valid_fingerprint(
		identity_fingerprint
	)
	_records[peer_id] = record
	return true


func remove_peer(peer_id: int) -> PeerRecord:
	var record: PeerRecord = _records.get(peer_id)
	_records.erase(peer_id)
	return record


func get_peer(peer_id: int) -> PeerRecord:
	return _records.get(peer_id)


func update_display_name(peer_id: int, display_name: String) -> bool:
	var record: PeerRecord = _records.get(peer_id)
	if record == null or display_name.is_empty():
		return false
	record.display_name = display_name
	return true


func update_appearance(peer_id: int, snapshot: Dictionary) -> bool:
	var record: PeerRecord = _records.get(peer_id)
	if record == null or not CharacterCustomizationCatalog.validate_snapshot(snapshot):
		return false
	record.appearance_snapshot = snapshot.duplicate(true)
	return true


func has_peer(peer_id: int) -> bool:
	return _records.has(peer_id)


func has_profile(profile_id: String) -> bool:
	for record: PeerRecord in _records.values():
		if record.profile_id == profile_id:
			return true
	return false


func has_fingerprint(fingerprint: String) -> bool:
	for record: PeerRecord in _records.values():
		if record.identity_fingerprint == fingerprint:
			return true
	return false


func get_peer_ids() -> Array[int]:
	var result: Array[int] = []
	for peer_id: int in _records:
		result.append(peer_id)
	result.sort()
	return result


func size() -> int:
	return _records.size()


func clear() -> void:
	_records.clear()
