class_name PortableFileGuard
extends RefCounted

const MAX_PORTABLE_FILE_BYTES := 16 * 1024 * 1024


static func hash_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_PORTABLE_FILE_BYTES:
		return ""
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return hash_bytes(bytes)


static func hash_bytes(bytes: PackedByteArray) -> String:
	var context: HashingContext = HashingContext.new()
	var start_error: Error = context.start(HashingContext.HASH_SHA256)
	if start_error != OK:
		return ""
	var update_error: Error = context.update(bytes)
	if update_error != OK:
		return ""
	return context.finish().hex_encode()


static func read_bytes(path: String, maximum_bytes: int = MAX_PORTABLE_FILE_BYTES) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > maximum_bytes:
		return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return bytes


static func write_guarded(
	path: String,
	bytes: PackedByteArray,
	expected_hash: String,
	conflict_directory: String,
	device_id: String,
) -> Dictionary:
	var current_exists: bool = FileAccess.file_exists(path)
	var current_hash: String = hash_file(path) if current_exists else ""
	if current_hash != expected_hash:
		var conflict_path: String = _write_conflict_copy(
			path, bytes, conflict_directory, device_id
		)
		return {
			"ok": false,
			"conflict": true,
			"hash": expected_hash,
			"conflict_path": conflict_path,
			"message": (
				"This file changed on another device.\n"
				+ "Your current data was preserved as a conflict copy."
			),
		}
	if not _ensure_parent(path):
		return {"ok": false, "conflict": false, "hash": expected_hash}
	var temporary: String = path + ".tmp"
	var backup: String = path + ".backup"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "conflict": false, "hash": expected_hash}
	file.store_buffer(bytes)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		_remove(temporary)
		return {"ok": false, "conflict": false, "hash": expected_hash}
	_remove(backup)
	if current_exists and not _rename(path, backup):
		_remove(temporary)
		return {"ok": false, "conflict": false, "hash": expected_hash}
	if not _rename(temporary, path):
		if current_exists:
			_rename(backup, path)
		return {"ok": false, "conflict": false, "hash": expected_hash}
	_remove(backup)
	return {
		"ok": true,
		"conflict": false,
		"hash": hash_bytes(bytes),
		"conflict_path": "",
	}


static func has_syncthing_conflict(directory: String) -> bool:
	var access: DirAccess = DirAccess.open(directory)
	if access == null:
		return false
	access.list_dir_begin()
	var name: String = access.get_next()
	while not name.is_empty():
		var lower: String = name.to_lower()
		if "sync-conflict" in lower or ".syncthing." in lower:
			access.list_dir_end()
			return true
		name = access.get_next()
	access.list_dir_end()
	return false


static func _write_conflict_copy(
	canonical_path: String,
	bytes: PackedByteArray,
	conflict_directory: String,
	device_id: String,
) -> String:
	if DirAccess.make_dir_recursive_absolute(conflict_directory) != OK:
		return ""
	var filename: String = canonical_path.get_file()
	var safe_device: String = device_id.left(16)
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var destination: String = conflict_directory.path_join(
		"%s.local-%s-%s" % [filename, safe_device, timestamp]
	)
	var file: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_buffer(bytes)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	return destination if ok else ""


static func _ensure_parent(path: String) -> bool:
	var parent: String = path.get_base_dir()
	return (
		DirAccess.dir_exists_absolute(parent)
		or DirAccess.make_dir_recursive_absolute(parent) == OK
	)


static func _rename(from_path: String, to_path: String) -> bool:
	return DirAccess.rename_absolute(from_path, to_path) == OK


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
