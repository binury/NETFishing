class_name PortableDataMigration
extends RefCounted

const LEGACY_FILES := {
	"player_save.json": "player/player_save.json",
	"network_profile.json": "player/network_profile.json",
	"player_appearance.json": "player/player_appearance.json",
	"saved_servers.json": "social/saved_servers.json",
	"known_players.json": "social/known_players.json",
	"player_relationships.json": "social/player_relationships.json",
	"server_trust.json": "social/server_trust.json",
	"host_bans.json": "social/host_bans.json",
}


static func legacy_files_present() -> bool:
	for filename: String in LEGACY_FILES:
		if FileAccess.file_exists("user://".path_join(filename)):
			return true
	return false


static func migrate_legacy_to(
	data_root: PlayerDataRoot,
	destination: String,
) -> Dictionary:
	var normalized := destination.simplify_path().trim_suffix("/")
	if DirAccess.dir_exists_absolute(normalized):
		var existing_manifest := normalized.path_join(
			PlayerDataRoot.MANIFEST_FILENAME
		)
		if FileAccess.file_exists(existing_manifest):
			return {
				"ok": false,
				"requires_existing_root_decision": true,
				"message": "The selected folder already contains NETFISHING data.",
			}
		if not _directory_empty(normalized):
			return {
				"ok": false,
				"message": "Choose an empty folder or create a NETFISHING subfolder.",
			}
	var staging := "%s.migration-%s" % [
		normalized, Crypto.new().generate_random_bytes(8).hex_encode()
	]
	if DirAccess.make_dir_recursive_absolute(staging) != OK:
		return {"ok": false, "message": "Migration staging could not be created."}
	var created := data_root.create_unbound_root(staging)
	if not bool(created.get("ok", false)):
		_remove_tree(staging)
		return {"ok": false, "message": str(created.get("message", ""))}
	var copied: Array[String] = []
	for source_name: String in LEGACY_FILES:
		var source := ProjectSettings.globalize_path(
			"user://".path_join(source_name)
		)
		if not FileAccess.file_exists(source):
			continue
		var target := staging.path_join(LEGACY_FILES[source_name])
		var result := _copy_verified_json(source, target)
		if not bool(result.get("ok", false)):
			_remove_tree(staging)
			return {
				"ok": false,
				"message": "Migration failed while validating %s." % source_name,
			}
		copied.append(source_name)
	if DirAccess.dir_exists_absolute(normalized):
		DirAccess.remove_absolute(normalized)
	if DirAccess.rename_absolute(staging, normalized) != OK:
		_remove_tree(staging)
		return {"ok": false, "message": "Migration could not activate its destination."}
	var manifest := _read_json(normalized.path_join(PlayerDataRoot.MANIFEST_FILENAME))
	var migrated_root_id := str(manifest.get("root_id", ""))
	if migrated_root_id.is_empty() or not data_root.use_existing_root(normalized):
		return {"ok": false, "message": "Migration completed but could not switch roots."}
	var recovery := ProjectSettings.globalize_path("user://migration-recovery").path_join(
		Time.get_datetime_string_from_system().replace(":", "-")
	)
	DirAccess.make_dir_recursive_absolute(recovery)
	for source_name: String in copied:
		_copy_bytes(
			ProjectSettings.globalize_path("user://".path_join(source_name)),
			recovery.path_join(source_name),
		)
	return {
		"ok": true,
		"message": "Player data moved successfully.",
		"recovery_path": recovery,
	}


static func migrate_active_to(
	data_root: PlayerDataRoot,
	destination: String,
) -> Dictionary:
	var normalized := destination.simplify_path().trim_suffix("/")
	if normalized == data_root.root_path:
		return {"ok": true, "message": "This data folder is already active."}
	if DirAccess.dir_exists_absolute(normalized) and not _directory_empty(normalized):
		if FileAccess.file_exists(normalized.path_join(PlayerDataRoot.MANIFEST_FILENAME)):
			return {
				"ok": false,
				"requires_existing_root_decision": true,
				"message": (
					"The selected folder already contains NETFISHING data. "
					+ "Choose it through the existing-data recovery flow."
				),
			}
		return {"ok": false, "message": "Choose an empty folder or a NETFISHING subfolder."}
	var staging := "%s.migration-%s" % [
		normalized, Crypto.new().generate_random_bytes(8).hex_encode()
	]
	if DirAccess.make_dir_recursive_absolute(staging) != OK:
		return {"ok": false, "message": "Migration staging could not be created."}
	var created := data_root.create_unbound_root(staging)
	if not bool(created.get("ok", false)):
		_remove_tree(staging)
		return {"ok": false, "message": str(created.get("message", ""))}
	for relative: String in [
		"player/player_save.json",
		"player/network_profile.json",
		"player/player_appearance.json",
		"social/saved_servers.json",
		"social/known_players.json",
		"social/player_relationships.json",
		"social/server_trust.json",
		"social/host_bans.json",
	]:
		var source := data_root.root_path.path_join(relative)
		if not FileAccess.file_exists(source):
			continue
		if not bool(_copy_verified_json(source, staging.path_join(relative)).get("ok", false)):
			_remove_tree(staging)
			return {"ok": false, "message": "Migration validation failed for %s." % relative}
	if DirAccess.dir_exists_absolute(normalized):
		DirAccess.remove_absolute(normalized)
	if DirAccess.rename_absolute(staging, normalized) != OK:
		_remove_tree(staging)
		return {"ok": false, "message": "Migration could not activate its destination."}
	var old_root := data_root.root_path
	if not data_root.use_existing_root(normalized):
		return {"ok": false, "message": "Migration copied data but did not change the pointer."}
	return {
		"ok": true,
		"message": "Data folder changed. Previous data was preserved.",
		"previous_root": old_root,
	}


static func adopt_legacy_app_data(data_root: PlayerDataRoot) -> Dictionary:
	var source_root := ProjectSettings.globalize_path("user://").trim_suffix("/")
	var root := ProjectSettings.globalize_path(PlayerDataRoot.APP_DATA_PORTABLE_PATH)
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		return {"ok": false, "message": "The app-data folder could not be created."}
	var created := data_root.create_app_data_layout_for_migration(root)
	if not bool(created.get("ok", false)):
		return created
	for source_name: String in LEGACY_FILES:
		var source := source_root.path_join(source_name)
		if not FileAccess.file_exists(source):
			continue
		var target := root.path_join(LEGACY_FILES[source_name])
		if not bool(_copy_verified_json(source, target).get("ok", false)):
			return {
				"ok": false,
				"message": "Could not validate %s in app-data mode." % source_name,
			}
	if not data_root.use_existing_root(root):
		return {"ok": false, "message": data_root.error_message}
	return {
		"ok": true,
		"message": "Existing player data remains in app data.",
		"recovery_path": source_root,
	}


static func replace_existing_with_legacy(
	data_root: PlayerDataRoot,
	destination: String,
) -> Dictionary:
	var normalized := destination.simplify_path().trim_suffix("/")
	var manifest := normalized.path_join(PlayerDataRoot.MANIFEST_FILENAME)
	if not FileAccess.file_exists(manifest):
		return {"ok": false, "message": "The selected folder is not a NETFISHING data root."}
	var recovery := ProjectSettings.globalize_path("user://migration-recovery").path_join(
		"replaced-root-" + Time.get_datetime_string_from_system().replace(":", "-")
	)
	if not _copy_tree(normalized, recovery):
		return {"ok": false, "message": "The selected data could not be backed up."}
	_remove_tree(normalized)
	var result := migrate_legacy_to(data_root, normalized)
	if bool(result.get("ok", false)):
		result["replaced_root_backup"] = recovery
	return result


static func replace_existing_with_active(
	data_root: PlayerDataRoot,
	destination: String,
) -> Dictionary:
	var normalized := destination.simplify_path().trim_suffix("/")
	if not FileAccess.file_exists(normalized.path_join(PlayerDataRoot.MANIFEST_FILENAME)):
		return {"ok": false, "message": "The selected folder is not a NETFISHING data root."}
	var recovery := ProjectSettings.globalize_path("user://migration-recovery").path_join(
		"replaced-root-" + Time.get_datetime_string_from_system().replace(":", "-")
	)
	if not _copy_tree(normalized, recovery):
		return {"ok": false, "message": "The selected data could not be backed up."}
	_remove_tree(normalized)
	var result := migrate_active_to(data_root, normalized)
	if bool(result.get("ok", false)):
		result["replaced_root_backup"] = recovery
	return result


static func _copy_verified_json(source: String, destination: String) -> Dictionary:
	var bytes := PortableFileGuard.read_bytes(source)
	if bytes.is_empty() and FileAccess.get_open_error() != OK:
		return {"ok": false}
	var json := JSON.new()
	if (
		json.parse(bytes.get_string_from_utf8()) != OK
		or typeof(json.data) != TYPE_DICTIONARY
		or not _valid_owned_data(source.get_file(), json.data)
	):
		return {"ok": false}
	if DirAccess.make_dir_recursive_absolute(destination.get_base_dir()) != OK:
		return {"ok": false}
	if not _write_bytes(destination, bytes):
		return {"ok": false}
	var copied := PortableFileGuard.read_bytes(destination)
	return {
		"ok": (
			PortableFileGuard.hash_bytes(copied)
			== PortableFileGuard.hash_bytes(bytes)
		)
	}


static func _valid_owned_data(filename: String, data: Dictionary) -> bool:
	if filename == "player_save.json":
		var version := int(data.get("save_version", -1))
		return version >= 1 and version <= PlayerSaveManager.SAVE_VERSION
	return (
		filename not in LEGACY_FILES
		or int(data.get("format_version", -1)) == 1
	)


static func _copy_bytes(source: String, destination: String) -> bool:
	return _write_bytes(destination, PortableFileGuard.read_bytes(source))


static func _copy_tree(source: String, destination: String) -> bool:
	if DirAccess.make_dir_recursive_absolute(destination) != OK:
		return false
	var access := DirAccess.open(source)
	if access == null:
		return false
	access.list_dir_begin()
	var name := access.get_next()
	while not name.is_empty():
		var from := source.path_join(name)
		var to := destination.path_join(name)
		if access.current_is_dir():
			if not _copy_tree(from, to):
				access.list_dir_end()
				return false
		elif not _copy_bytes(from, to):
			access.list_dir_end()
			return false
		name = access.get_next()
	access.list_dir_end()
	return true


static func _write_bytes(path: String, bytes: PackedByteArray) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	return ok


static func _read_json(path: String) -> Dictionary:
	var bytes := PortableFileGuard.read_bytes(path)
	var json := JSON.new()
	return (
		json.data
		if json.parse(bytes.get_string_from_utf8()) == OK
		and typeof(json.data) == TYPE_DICTIONARY
		else {}
	)


static func _directory_empty(path: String) -> bool:
	var access := DirAccess.open(path)
	if access == null:
		return true
	access.list_dir_begin()
	var name := access.get_next()
	access.list_dir_end()
	return name.is_empty()


static func _remove_tree(path: String) -> void:
	var access := DirAccess.open(path)
	if access == null:
		return
	access.list_dir_begin()
	var name := access.get_next()
	while not name.is_empty():
		var child := path.path_join(name)
		if access.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = access.get_next()
	access.list_dir_end()
	DirAccess.remove_absolute(path)
