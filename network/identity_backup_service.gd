class_name IdentityBackupService
extends Node

signal operation_finished(success: bool, message: String)

const MAGIC := "NETFISHING_IDENTITY_BACKUP"
const FORMAT_VERSION := 1
const MAX_BACKUP_BYTES := 256 * 1024
const MIN_PASSPHRASE_LENGTH := 12
const MAX_PASSPHRASE_LENGTH := 256

var _data_root: PlayerDataRoot
var _player_identity: PlayerIdentityStore
var _host_identity: HostIdentityStore


func setup(
	data_root: PlayerDataRoot,
	player_identity: PlayerIdentityStore,
	host_identity: HostIdentityStore,
) -> void:
	_data_root = data_root
	_player_identity = player_identity
	_host_identity = host_identity


func default_export_path(identity_type: String) -> String:
	var store := _store(identity_type)
	if store == null:
		return ""
	if not store.is_ready() and not store.load_or_create():
		return ""
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	return _data_root.identity_backup_directory().path_join(
		"%s-%s-%s.nfidentity" % [
			identity_type,
			NetworkIdentityCrypto.compact_suffix(store.fingerprint),
			timestamp,
		]
	)


func export_backup(
	identity_type: String,
	path: String,
	passphrase: String,
	confirmation: String,
) -> bool:
	if not _valid_passphrase(passphrase) or passphrase != confirmation:
		return _finish(false, "Passphrases must match and contain at least 12 characters.")
	if FileAccess.file_exists(path):
		return _finish(false, "Choose a new backup filename.")
	var store := _store(identity_type)
	if store == null or (not store.is_ready() and not store.load_or_create()):
		return _finish(false, "The active identity is unavailable.")
	var material := store.export_identity_material()
	var proof := store.sign("identity_backup_self_test", [
		identity_type, material["fingerprint"],
	])
	var envelope := {
		"magic": MAGIC,
		"format_version": FORMAT_VERSION,
		"identity_type": identity_type,
		"algorithm": NetworkIdentityCrypto.ALGORITHM,
		"private_pem": material["private_pem"],
		"public_pem": material["public_pem"],
		"fingerprint": material["fingerprint"],
		"created_at_unix": int(Time.get_unix_time_from_system()),
		"source_device_id": _data_root.device_id,
		"self_signature": Marshalls.raw_to_base64(proof),
	}
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.WRITE, passphrase)
	if file == null:
		return _finish(false, "Could not write this identity backup.")
	file.store_string(JSON.stringify(envelope))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok:
		return _finish(false, "Could not write this identity backup.")
	var verified := inspect_backup(path, passphrase, identity_type)
	if not bool(verified.get("ok", false)):
		DirAccess.remove_absolute(path)
		return _finish(false, "Could not verify this identity backup.")
	return _finish(true, "Encrypted identity backup created.")


func inspect_backup(
	path: String,
	passphrase: String,
	expected_type: String,
) -> Dictionary:
	if (
		not _valid_passphrase(passphrase)
		or not FileAccess.file_exists(path)
		or FileAccess.get_size(path) > MAX_BACKUP_BYTES
	):
		return {"ok": false}
	var file := FileAccess.open_encrypted_with_pass(path, FileAccess.READ, passphrase)
	if file == null:
		return {"ok": false}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false}
	var data: Dictionary = json.data
	if (
		data.get("magic") != MAGIC
		or data.get("format_version") != FORMAT_VERSION
		or data.get("identity_type") != expected_type
		or data.get("algorithm") != NetworkIdentityCrypto.ALGORITHM
	):
		return {"ok": false}
	var private_pem := str(data.get("private_pem", ""))
	var public_pem := NetworkIdentityCrypto.normalize_public_pem(
		str(data.get("public_pem", ""))
	)
	var fingerprint := str(data.get("fingerprint", ""))
	if (
		private_pem.length() > 128 * 1024
		or public_pem.length() > 32 * 1024
		or NetworkIdentityCrypto.fingerprint_public_pem(public_pem) != fingerprint
	):
		return {"ok": false}
	var key := CryptoKey.new()
	if key.load_from_string(private_pem) != OK:
		return {"ok": false}
	var signature := Marshalls.base64_to_raw(str(data.get("self_signature", "")))
	if not NetworkIdentityCrypto.verify_fields(
		NetworkIdentityCrypto.load_public_key(public_pem),
		"identity_backup_self_test",
		[expected_type, fingerprint],
		signature,
	):
		return {"ok": false}
	var fresh := NetworkIdentityCrypto.sign_fields(
		key, "identity_import_self_test", [fingerprint]
	)
	if not NetworkIdentityCrypto.verify_fields(
		NetworkIdentityCrypto.load_public_key(public_pem),
		"identity_import_self_test",
		[fingerprint],
		fresh,
	):
		return {"ok": false}
	return {
		"ok": true,
		"identity_type": expected_type,
		"fingerprint": fingerprint,
		"private_pem": private_pem,
		"public_pem": public_pem,
	}


func import_backup(
	identity_type: String,
	path: String,
	passphrase: String,
	confirmed_replacement: bool,
) -> Dictionary:
	var inspected := inspect_backup(path, passphrase, identity_type)
	if not bool(inspected.get("ok", false)):
		_finish(false, "Could not open this identity backup.")
		return {"ok": false}
	var store := _store(identity_type)
	var incoming := str(inspected["fingerprint"])
	if store.fingerprint == incoming:
		_finish(true, "This identity is already active.")
		return {"ok": true, "same": true}
	if not confirmed_replacement:
		return {
			"ok": false,
			"requires_confirmation": true,
			"current_fingerprint": store.fingerprint,
			"incoming_fingerprint": incoming,
		}
	var result := store.install_identity_material(
		str(inspected["private_pem"]),
		str(inspected["public_pem"]),
		incoming,
	)
	_finish(
		bool(result.get("ok", false)),
		"Identity imported. Restart NETFISHING before multiplayer."
		if bool(result.get("ok", false))
		else "Could not install this identity backup.",
	)
	return result


func _store(identity_type: String) -> LocalSigningIdentityStore:
	if identity_type == "player":
		return _player_identity
	if identity_type == "host":
		return _host_identity
	return null


func _valid_passphrase(value: String) -> bool:
	return value.length() >= MIN_PASSPHRASE_LENGTH and value.length() <= MAX_PASSPHRASE_LENGTH


func _finish(success: bool, message: String) -> bool:
	operation_finished.emit(success, message)
	return success
