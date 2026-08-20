class_name ProgressionSaveCodec
extends RefCounted

const MAGIC := "NETFISHING_PROGRESSION_CONTAINER"
const FORMAT_VERSION := 1
const LOCAL_KIND := "local_save"
const ARCHIVE_KIND := "portable_archive"
const MAX_CONTAINER_BYTES := 16 * 1024 * 1024

# This key keeps routine progression files opaque to casual editing. Since the
# client is open source, it is intentionally not treated as a security secret.
const CONTAINER_PASSPHRASE := (
	"NETfishing progression container v1 / not an identity credential"
)


static func encode_local_save(
	save_data: Dictionary,
	scratch_path: String,
) -> PackedByteArray:
	return _encode_container(LOCAL_KIND, save_data, scratch_path)


static func encode_archive(
	save_data: Dictionary,
	scratch_path: String,
) -> PackedByteArray:
	return _encode_container(ARCHIVE_KIND, save_data, scratch_path)


static func read_local_save(
	path: String,
	allow_legacy_plaintext: bool = false,
) -> Dictionary:
	if allow_legacy_plaintext and not _looks_encrypted(path):
		var legacy: Dictionary = _read_plaintext_dictionary(path)
		if bool(legacy.get("ok", false)):
			legacy["legacy_plaintext"] = true
		return legacy
	return _read_container(path, LOCAL_KIND)


static func read_archive(path: String) -> Dictionary:
	if not _looks_encrypted(path):
		return {"ok": false, "message": "progression archive is not recognized."}
	return _read_container(path, ARCHIVE_KIND)


static func _encode_container(
	kind: String,
	save_data: Dictionary,
	scratch_path: String,
) -> PackedByteArray:
	if save_data.is_empty() or scratch_path.is_empty():
		return PackedByteArray()
	var payload_json: String = JSON.stringify(save_data)
	if payload_json.is_empty():
		return PackedByteArray()
	var payload_bytes: PackedByteArray = payload_json.to_utf8_buffer()
	var envelope: Dictionary = {
		"magic": MAGIC,
		"format_version": FORMAT_VERSION,
		"kind": kind,
		"game_version": str(
			ProjectSettings.get_setting("application/config/version", "")
		),
		"created_at_unix": int(Time.get_unix_time_from_system()),
		"payload_sha256": PortableFileGuard.hash_bytes(payload_bytes),
		"payload_json": payload_json,
	}
	if DirAccess.make_dir_recursive_absolute(
		scratch_path.get_base_dir()
	) != OK:
		return PackedByteArray()
	_remove_if_present(scratch_path)
	var file: FileAccess = FileAccess.open_encrypted_with_pass(
		scratch_path,
		FileAccess.WRITE,
		CONTAINER_PASSPHRASE,
	)
	if file == null:
		return PackedByteArray()
	file.store_string(JSON.stringify(envelope))
	file.flush()
	var write_ok: bool = file.get_error() == OK
	file.close()
	if not write_ok:
		_remove_if_present(scratch_path)
		return PackedByteArray()
	var encoded: PackedByteArray = PortableFileGuard.read_bytes(
		scratch_path,
		MAX_CONTAINER_BYTES,
	)
	_remove_if_present(scratch_path)
	return encoded


static func _read_container(path: String, expected_kind: String) -> Dictionary:
	if (
		path.is_empty()
		or not FileAccess.file_exists(path)
		or FileAccess.get_size(path) > MAX_CONTAINER_BYTES
	):
		return {"ok": false, "message": "progression file is unavailable."}
	var file: FileAccess = FileAccess.open_encrypted_with_pass(
		path,
		FileAccess.READ,
		CONTAINER_PASSPHRASE,
	)
	if file == null:
		return {"ok": false, "message": "progression file could not be opened."}
	var envelope_text: String = file.get_as_text()
	file.close()
	var envelope_json := JSON.new()
	if (
		envelope_json.parse(envelope_text) != OK
		or typeof(envelope_json.data) != TYPE_DICTIONARY
	):
		return {"ok": false, "message": "progression container is malformed."}
	var envelope: Dictionary = envelope_json.data
	if (
		envelope.get("magic") != MAGIC
		or int(envelope.get("format_version", -1)) != FORMAT_VERSION
		or str(envelope.get("kind", "")) != expected_kind
	):
		return {"ok": false, "message": "progression container is unsupported."}
	var payload_json: String = str(envelope.get("payload_json", ""))
	var payload_bytes: PackedByteArray = payload_json.to_utf8_buffer()
	if (
		payload_json.is_empty()
		or str(envelope.get("payload_sha256", ""))
		!= PortableFileGuard.hash_bytes(payload_bytes)
	):
		return {"ok": false, "message": "progression container failed validation."}
	var payload_parser := JSON.new()
	if (
		payload_parser.parse(payload_json) != OK
		or typeof(payload_parser.data) != TYPE_DICTIONARY
	):
		return {"ok": false, "message": "progression payload is malformed."}
	return {
		"ok": true,
		"data": payload_parser.data,
		"game_version": str(envelope.get("game_version", "")),
		"created_at_unix": int(envelope.get("created_at_unix", 0)),
		"legacy_plaintext": false,
	}


static func _read_plaintext_dictionary(path: String) -> Dictionary:
	var bytes: PackedByteArray = PortableFileGuard.read_bytes(
		path,
		MAX_CONTAINER_BYTES,
	)
	if bytes.is_empty():
		return {"ok": false}
	var text: String = bytes.get_string_from_utf8()
	if not text.strip_edges().begins_with("{"):
		return {"ok": false}
	var parser := JSON.new()
	if parser.parse(text) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		return {"ok": false}
	return {"ok": true, "data": parser.data}


static func _looks_encrypted(path: String) -> bool:
	if not FileAccess.file_exists(path) or FileAccess.get_size(path) < 4:
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var header: PackedByteArray = file.get_buffer(4)
	file.close()
	return header == PackedByteArray([0x47, 0x44, 0x45, 0x43])


static func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
