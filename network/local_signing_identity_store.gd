class_name LocalSigningIdentityStore
extends Node

const FORMAT_VERSION: int = 1

var fingerprint: String = ""
var public_pem: String = ""
var error_message: String = ""
var _private_key: CryptoKey
var _prefix: String = ""
var _allow_generation: bool = true
var _storage_directory: String = ""


func configure(
	prefix: String,
	allow_generation: bool = true,
	storage_directory: String = "",
) -> void:
	_prefix = prefix
	_allow_generation = allow_generation
	_storage_directory = storage_directory.strip_edges()


func load_or_create() -> bool:
	if _prefix.is_empty():
		error_message = "Identity storage is not configured."
		return false
	var key_path := _path(".key")
	var public_path := _path(".pub")
	var metadata_path := _path(".json")
	var any_exists := (
		FileAccess.file_exists(key_path)
		or FileAccess.file_exists(public_path)
		or FileAccess.file_exists(metadata_path)
	)
	if any_exists:
		return _load_existing()
	if not _allow_generation:
		return false
	return _generate_new()


func is_ready() -> bool:
	return _private_key != null and NetworkIdentityCrypto.valid_fingerprint(fingerprint)


func sign(domain: String, fields: Array) -> PackedByteArray:
	return NetworkIdentityCrypto.sign_fields(_private_key, domain, fields)


func verify(domain: String, fields: Array, signature: PackedByteArray) -> bool:
	return NetworkIdentityCrypto.verify_fields(
		NetworkIdentityCrypto.load_public_key(public_pem),
		domain,
		fields,
		signature,
	)


func export_identity_material() -> Dictionary:
	if not is_ready():
		return {}
	return {
		"private_pem": _private_key.save_to_string(),
		"public_pem": public_pem,
		"fingerprint": fingerprint,
	}


func install_identity_material(
	private_pem: String,
	public_value: String,
	expected_fingerprint: String,
) -> Dictionary:
	var normalized_public := NetworkIdentityCrypto.normalize_public_pem(public_value)
	var derived := NetworkIdentityCrypto.fingerprint_public_pem(normalized_public)
	var key := CryptoKey.new()
	if (
		derived != expected_fingerprint
		or key.load_from_string(private_pem) != OK
	):
		return {"ok": false}
	var probe := NetworkIdentityCrypto.sign_fields(
		key, "identity_import_self_test", [derived]
	)
	if not NetworkIdentityCrypto.verify_fields(
		NetworkIdentityCrypto.load_public_key(normalized_public),
		"identity_import_self_test",
		[derived],
		probe,
	):
		return {"ok": false}
	if derived == fingerprint:
		return {"ok": true, "same": true, "archive_path": ""}
	var had_active_identity := is_ready()
	var archive := _archive_current_identity() if had_active_identity else ""
	if had_active_identity and archive.is_empty():
		return {"ok": false}
	var metadata := {
		"format_version": FORMAT_VERSION,
		"algorithm": NetworkIdentityCrypto.ALGORITHM,
		"fingerprint": derived,
		"created_at_unix": int(Time.get_unix_time_from_system()),
	}
	if (
		not _write_atomic(_path(".key"), private_pem)
		or not _write_atomic(_path(".pub"), normalized_public)
		or not _write_atomic(_path(".json"), JSON.stringify(metadata, "\t"))
	):
		if not archive.is_empty():
			_restore_archive(archive)
		_load_existing()
		return {"ok": false}
	FileAccess.set_unix_permissions(_path(".key"), 384)
	if not _load_existing() or fingerprint != derived:
		if not archive.is_empty():
			_restore_archive(archive)
		_load_existing()
		return {"ok": false}
	return {"ok": true, "same": false, "archive_path": archive}


func _generate_new() -> bool:
	var key := Crypto.new().generate_rsa(3072)
	if key == null:
		error_message = "A signing identity could not be generated."
		return false
	var private_text := key.save_to_string()
	var public_text := NetworkIdentityCrypto.normalize_public_pem(
		key.save_to_string(true)
	)
	var derived := NetworkIdentityCrypto.fingerprint_public_pem(public_text)
	var probe := NetworkIdentityCrypto.sign_fields(key, "identity_self_test", [derived])
	var public_key := NetworkIdentityCrypto.load_public_key(public_text)
	if (
		not NetworkIdentityCrypto.valid_fingerprint(derived)
		or not NetworkIdentityCrypto.verify_fields(
			public_key, "identity_self_test", [derived], probe
		)
	):
		error_message = "The generated signing identity failed verification."
		return false
	var metadata := {
		"format_version": FORMAT_VERSION,
		"algorithm": NetworkIdentityCrypto.ALGORITHM,
		"fingerprint": derived,
		"created_at_unix": int(Time.get_unix_time_from_system()),
	}
	if (
		not _write_atomic(_path(".key"), private_text)
		or not _write_atomic(_path(".pub"), public_text)
		or not _write_atomic(_path(".json"), JSON.stringify(metadata, "\t"))
	):
		error_message = "The signing identity could not be stored."
		return false
	FileAccess.set_unix_permissions(_path(".key"), 384)
	return _load_existing()


func _load_existing() -> bool:
	var required := [_path(".key"), _path(".pub"), _path(".json")]
	for path: String in required:
		if not FileAccess.file_exists(path):
			error_message = "Identity recovery is required. An identity file is missing."
			return false
	var private_file := FileAccess.open(_path(".key"), FileAccess.READ)
	var public_file := FileAccess.open(_path(".pub"), FileAccess.READ)
	var metadata_file := FileAccess.open(_path(".json"), FileAccess.READ)
	if private_file == null or public_file == null or metadata_file == null:
		error_message = "Identity recovery is required. Identity files could not be read."
		return false
	var private_text := private_file.get_as_text()
	var loaded_public := NetworkIdentityCrypto.normalize_public_pem(public_file.get_as_text())
	var metadata_text := metadata_file.get_as_text()
	var json := JSON.new()
	if json.parse(metadata_text) != OK or typeof(json.data) != TYPE_DICTIONARY:
		error_message = "Identity recovery is required. Identity metadata is damaged."
		return false
	var metadata: Dictionary = json.data
	var derived := NetworkIdentityCrypto.fingerprint_public_pem(loaded_public)
	if (
		metadata.get("format_version") != FORMAT_VERSION
		or metadata.get("algorithm") != NetworkIdentityCrypto.ALGORITHM
		or metadata.get("fingerprint") != derived
	):
		error_message = "Identity recovery is required. Identity files do not match."
		return false
	var key := CryptoKey.new()
	if key.load_from_string(private_text) != OK:
		error_message = "Identity recovery is required. The private key is damaged."
		return false
	var probe := NetworkIdentityCrypto.sign_fields(key, "identity_self_test", [derived])
	if not NetworkIdentityCrypto.verify_fields(
		NetworkIdentityCrypto.load_public_key(loaded_public),
		"identity_self_test",
		[derived],
		probe,
	):
		error_message = "Identity recovery is required. The key pair does not match."
		return false
	_private_key = key
	public_pem = loaded_public
	fingerprint = derived
	error_message = ""
	return true


func _write_atomic(path: String, content: String) -> bool:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return false
	if FileAccess.file_exists(path):
		var backup := path + ".backup"
		_remove_if_present(backup)
		if not _rename(path, backup):
			return false
		if not _rename(temporary, path):
			_rename(backup, path)
			return false
		_remove_if_present(backup)
		return true
	return _rename(temporary, path)


func _path(extension: String) -> String:
	var filename: String = "%s%s" % [_prefix, extension]
	return (
		_storage_directory.path_join(filename)
		if not _storage_directory.is_empty()
		else "user://%s" % filename
	)


func identity_type() -> String:
	return "player" if _prefix == "player_identity" else "host"


func _archive_current_identity() -> String:
	var timestamp := Time.get_datetime_string_from_system().replace(":", "-")
	var archive := ProjectSettings.globalize_path(
		"user://identity-recovery/%s-%s" % [_prefix, timestamp]
	)
	if DirAccess.make_dir_recursive_absolute(archive) != OK:
		return ""
	for extension: String in [".key", ".pub", ".json"]:
		var source := _path(extension)
		var bytes := PortableFileGuard.read_bytes(source, 1024 * 1024)
		if bytes.is_empty():
			return ""
		var file := FileAccess.open(archive.path_join(_prefix + extension), FileAccess.WRITE)
		if file == null:
			return ""
		file.store_buffer(bytes)
		file.close()
	FileAccess.set_unix_permissions(
		archive.path_join(_prefix + ".key"), 384
	)
	return archive


func _restore_archive(archive: String) -> void:
	for extension: String in [".key", ".pub", ".json"]:
		var source := archive.path_join(_prefix + extension)
		var bytes := PortableFileGuard.read_bytes(source, 1024 * 1024)
		if bytes.is_empty():
			continue
		var file := FileAccess.open(_path(extension), FileAccess.WRITE)
		if file != null:
			file.store_buffer(bytes)
			file.close()
	FileAccess.set_unix_permissions(_path(".key"), 384)


func _rename(from_path: String, to_path: String) -> bool:
	return DirAccess.rename_absolute(
		ProjectSettings.globalize_path(from_path),
		ProjectSettings.globalize_path(to_path),
	) == OK


func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
