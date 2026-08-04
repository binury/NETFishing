class_name PlayerDataRoot
extends Node

signal status_changed(message: String)
signal conflict_detected(message: String, conflict_path: String)

const BOOTSTRAP_PATH := "user://data_root_bootstrap.json"
const BOOTSTRAP_TEMP_PATH := "user://data_root_bootstrap.json.tmp"
const BOOTSTRAP_VERSION := 1
const MANIFEST_VERSION := 1
const LAYOUT_VERSION := 1
const MANIFEST_FILENAME := "netfishing_data.json"
const README_FILENAME := "README.txt"
const ENVIRONMENT_VARIABLE := "NETFISHING_DATA_DIR"
const APPLICATION_ID := "netfishing"
const APP_DATA_PORTABLE_PATH := "user://portable-data"
const PATH_ALLOWED: StringName = &"allowed"
const PATH_SOURCE_PROJECT: StringName = &"source_project"
const PATH_INSTALLATION: StringName = &"installation"

enum Mode {
	UNRESOLVED,
	SELECTED_FOLDER,
	APP_DATA,
	ENVIRONMENT_OVERRIDE,
	COMMAND_LINE_OVERRIDE,
}

var mode := Mode.UNRESOLVED
var root_path := ""
var root_id := ""
var device_id := ""
var error_message := ""
var requires_selection := false
var override_active := false


func resolve() -> bool:
	_load_bootstrap_identity()
	var command_line: String = _command_line_override()
	if not command_line.is_empty():
		override_active = true
		mode = Mode.COMMAND_LINE_OVERRIDE
		return _activate_existing(command_line, "", false)
	if OS.has_environment(ENVIRONMENT_VARIABLE):
		override_active = true
		mode = Mode.ENVIRONMENT_OVERRIDE
		var environment_path: String = OS.get_environment(ENVIRONMENT_VARIABLE)
		if not environment_path.is_absolute_path():
			return _fail("NETFISHING_DATA_DIR must be an absolute path.")
		return _activate_existing(environment_path, "", false)
	var bootstrap: Dictionary = _read_json(BOOTSTRAP_PATH, 64 * 1024)
	if bootstrap.is_empty() and FileAccess.file_exists(BOOTSTRAP_PATH + ".backup"):
		bootstrap = _read_json(BOOTSTRAP_PATH + ".backup", 64 * 1024)
	if not bootstrap.is_empty():
		if bootstrap.get("format_version") != BOOTSTRAP_VERSION:
			return _fail("The data-folder pointer uses an unsupported version.")
		var selected: String = str(bootstrap.get("selected_absolute_path", ""))
		var expected: String = str(bootstrap.get("expected_root_id", ""))
		if selected.is_empty():
			return _fail("The data-folder pointer is incomplete.")
		mode = (
			Mode.APP_DATA
			if selected == ProjectSettings.globalize_path(APP_DATA_PORTABLE_PATH)
			else Mode.SELECTED_FOLDER
		)
		return _activate_existing(selected, expected, false)
	requires_selection = true
	error_message = ""
	return false


func default_visible_path() -> String:
	var documents: String = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	if documents.is_empty():
		return ""
	var candidate: String = _normalize(documents.path_join("NETFISHING"))
	if not candidate.is_absolute_path():
		return ""
	var classification: StringName = classify_candidate_path(
		candidate,
		ProjectSettings.globalize_path("res://"),
		OS.get_executable_path().get_base_dir(),
	)
	return candidate if classification == PATH_ALLOWED else ""


func select_new_root(path: String, app_data: bool = false) -> bool:
	if override_active:
		return _fail("The data folder is controlled by a process override.")
	if device_id.length() != 32:
		device_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var normalized: String = _normalize(path)
	if app_data:
		normalized = ProjectSettings.globalize_path(APP_DATA_PORTABLE_PATH)
	if not _validate_candidate(normalized, true):
		return false
	var manifest_path: String = normalized.path_join(MANIFEST_FILENAME)
	if FileAccess.file_exists(manifest_path):
		var manifest: Dictionary = _read_json(manifest_path)
		if not _valid_manifest(manifest):
			return _fail("The selected folder has a malformed NETfishing manifest.")
		root_id = str(manifest["root_id"])
	else:
		if not _directory_is_empty(normalized) and not app_data:
			return _fail(
				"Choose an empty folder or an existing NETfishing data folder."
			)
		root_id = Crypto.new().generate_random_bytes(16).hex_encode()
		if not _create_layout(normalized, root_id):
			return _fail("The NETfishing data folder could not be created.")
	if not _write_bootstrap(normalized, root_id):
		return _fail("The data-folder pointer could not be saved.")
	root_path = normalized
	mode = Mode.APP_DATA if app_data else Mode.SELECTED_FOLDER
	requires_selection = false
	error_message = ""
	status_changed.emit("Data folder ready.")
	return true


func create_unbound_root(path: String) -> Dictionary:
	var normalized: String = _normalize(path)
	if not _validate_candidate(normalized, true):
		return {"ok": false, "message": error_message}
	if not _directory_is_empty(normalized):
		return {"ok": false, "message": "The destination staging folder is not empty."}
	var id: String = Crypto.new().generate_random_bytes(16).hex_encode()
	if not _create_layout(normalized, id):
		return {"ok": false, "message": "The portable layout could not be created."}
	return {"ok": true, "root_id": id}


func create_app_data_layout_for_migration(path: String) -> Dictionary:
	var normalized: String = _normalize(path)
	if not _validate_candidate(normalized, false):
		return {"ok": false, "message": error_message}
	var manifest_path: String = normalized.path_join(MANIFEST_FILENAME)
	if FileAccess.file_exists(manifest_path):
		var manifest: Dictionary = _read_json(manifest_path)
		return (
			{"ok": true, "root_id": str(manifest.get("root_id", ""))}
			if _valid_manifest(manifest)
			else {"ok": false, "message": "The app-data manifest is malformed."}
		)
	var id: String = Crypto.new().generate_random_bytes(16).hex_encode()
	if not _create_layout(normalized, id):
		return {"ok": false, "message": "The app-data layout could not be created."}
	return {"ok": true, "root_id": id}


func use_existing_root(path: String) -> bool:
	if override_active:
		return _fail("The data folder is controlled by a process override.")
	if device_id.length() != 32:
		device_id = Crypto.new().generate_random_bytes(16).hex_encode()
	var normalized: String = _normalize(path)
	if not _activate_existing(normalized, "", true):
		return false
	if not _write_bootstrap(root_path, root_id):
		root_path = ""
		root_id = ""
		return _fail("The data-folder pointer could not be saved.")
	mode = (
		Mode.APP_DATA
		if normalized == ProjectSettings.globalize_path(APP_DATA_PORTABLE_PATH)
		else Mode.SELECTED_FOLDER
	)
	return true


func path_for(store_owner: StringName) -> String:
	var relative: String = {
		&"player_save": "player/player_save.json",
		&"network_profile": "player/network_profile.json",
		&"player_appearance": "player/player_appearance.json",
		&"saved_servers": "social/saved_servers.json",
		&"known_players": "social/known_players.json",
		&"player_relationships": "social/player_relationships.json",
		&"server_trust": "social/server_trust.json",
		&"host_bans": "social/host_bans.json",
	}.get(store_owner, "")
	return root_path.path_join(relative) if not relative.is_empty() else ""


func conflict_directory() -> String:
	return root_path.path_join("backups/conflicts")


func identity_backup_directory() -> String:
	return root_path.path_join("identity-backups")


func migration_backup_directory() -> String:
	return root_path.path_join("backups/migrations")


func storage_mode_text() -> String:
	return {
		Mode.SELECTED_FOLDER: "Selected folder",
		Mode.APP_DATA: "App data",
		Mode.ENVIRONMENT_OVERRIDE: "Environment override",
		Mode.COMMAND_LINE_OVERRIDE: "Command-line override",
	}.get(mode, "Unavailable")


func open_folder() -> bool:
	return not root_path.is_empty() and OS.shell_open(root_path) == OK


func report_conflict(message: String, conflict_path: String) -> void:
	error_message = message
	conflict_detected.emit(message, conflict_path)
	status_changed.emit(message)


func _activate_existing(path: String, expected_id: String, permit_creation: bool) -> bool:
	var normalized: String = _normalize(path)
	if not _validate_candidate(normalized, permit_creation):
		return false
	var manifest_path: String = normalized.path_join(MANIFEST_FILENAME)
	if not FileAccess.file_exists(manifest_path):
		return _fail("The selected folder is not a NETfishing data folder.")
	var manifest: Dictionary = _read_json(manifest_path)
	if not _valid_manifest(manifest):
		return _fail("The NETfishing data-folder manifest is malformed.")
	var found_id: String = str(manifest["root_id"])
	if not expected_id.is_empty() and expected_id != found_id:
		return _fail("The selected data folder does not match this device pointer.")
	if not _test_writable(normalized):
		return _fail("The NETfishing data folder is unavailable or unwritable.")
	root_path = normalized
	root_id = found_id
	requires_selection = false
	error_message = ""
	if PortableFileGuard.has_syncthing_conflict(root_path.path_join("player")):
		status_changed.emit("Syncthing conflict copies were found. Review the data folder.")
	return true


func _validate_candidate(path: String, create: bool) -> bool:
	var normalized: String = _normalize(path)
	if normalized.is_empty() or not normalized.is_absolute_path():
		return _fail("Choose an absolute filesystem folder.")
	var app_data_path: String = _normalize(
		ProjectSettings.globalize_path(APP_DATA_PORTABLE_PATH)
	)
	var exported_app_data: bool = (
		normalized == app_data_path
		and not OS.has_feature("editor")
	)
	var classification: StringName = classify_candidate_path(
		normalized,
		ProjectSettings.globalize_path("res://"),
		OS.get_executable_path().get_base_dir(),
	)
	if classification == PATH_SOURCE_PROJECT and not exported_app_data:
		return _fail("The project folder cannot be used as the player data folder.")
	if classification == PATH_INSTALLATION and not exported_app_data:
		return _fail(
			"The application installation folder cannot be used as the player data folder."
		)
	if not DirAccess.dir_exists_absolute(normalized):
		if not create or DirAccess.make_dir_recursive_absolute(normalized) != OK:
			return _fail("The selected data folder is unavailable.")
	return _test_writable(normalized)


static func classify_candidate_path(
	candidate_path: String,
	project_reference: String,
	installation_reference: String,
	case_insensitive: bool = OS.get_name() == "Windows",
) -> StringName:
	var candidate: String = _normalize_comparison_path(
		candidate_path, case_insensitive
	)
	if candidate.is_empty() or not candidate.is_absolute_path():
		return PATH_ALLOWED
	var project: String = _normalize_reference_path(
		project_reference, case_insensitive
	)
	if not project.is_empty() and _is_same_or_child_path(candidate, project):
		return PATH_SOURCE_PROJECT
	var installation: String = _normalize_reference_path(
		installation_reference, case_insensitive
	)
	if (
		not installation.is_empty()
		and _is_same_or_child_path(candidate, installation)
	):
		return PATH_INSTALLATION
	return PATH_ALLOWED


static func _normalize_reference_path(path: String, case_insensitive: bool) -> String:
	var normalized: String = _normalize_comparison_path(path, case_insensitive)
	if normalized.is_empty() or not normalized.is_absolute_path():
		return ""
	if normalized == "/" or _is_windows_drive_root(normalized):
		return ""
	return normalized


static func _normalize_comparison_path(path: String, case_insensitive: bool) -> String:
	var normalized: String = path.strip_edges().replace("\\", "/").simplify_path()
	while normalized.length() > 1 and normalized.ends_with("/"):
		if _is_windows_drive_root(normalized):
			break
		normalized = normalized.left(-1)
	return normalized.to_lower() if case_insensitive else normalized


static func _is_windows_drive_root(path: String) -> bool:
	return path.length() == 3 and path[1] == ":" and path[2] == "/"


static func _is_same_or_child_path(candidate: String, reference: String) -> bool:
	return candidate == reference or candidate.begins_with(reference + "/")


func _test_writable(path: String) -> bool:
	var probe: String = path.path_join(
		".netfishing-write-%s.tmp" % device_id.left(12)
	)
	var file: FileAccess = FileAccess.open(probe, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string("probe")
	file.close()
	return DirAccess.remove_absolute(probe) == OK


func _create_layout(path: String, id: String) -> bool:
	for relative: String in [
		"player", "social", "backups/saves", "backups/migrations",
		"backups/conflicts", "identity-backups",
	]:
		if DirAccess.make_dir_recursive_absolute(path.path_join(relative)) != OK:
			return false
	var now: int = int(Time.get_unix_time_from_system())
	var manifest: Dictionary = {
		"format_version": MANIFEST_VERSION,
		"layout_version": LAYOUT_VERSION,
		"application": APPLICATION_ID,
		"root_id": id,
		"created_at_unix": now,
		"last_opened_at_unix": now,
	}
	if not _write_text_atomic(
		path.path_join(MANIFEST_FILENAME), JSON.stringify(manifest, "\t")
	):
		return false
	var readme: String = (
		"NETfishing player data\n\n"
		+ "This folder is safe to synchronize with tools such as Syncthing.\n"
		+ "Active private identity keys remain device-local.\n"
		+ "Encrypted identity backups require their passphrase.\n"
		+ "Chat and Session Mail are not stored here.\n"
		+ "Do not play the same profile on two devices at the same time.\n"
		+ "Conflicting edits are preserved under backups/conflicts; they are not merged.\n"
	)
	return _write_text_atomic(path.path_join(README_FILENAME), readme)


func _write_bootstrap(path: String, id: String) -> bool:
	var now: int = int(Time.get_unix_time_from_system())
	var data: Dictionary = {
		"format_version": BOOTSTRAP_VERSION,
		"selected_absolute_path": path,
		"expected_root_id": id,
		"device_id": device_id,
		"selected_at_unix": now,
		"last_successfully_opened_at_unix": now,
	}
	return _write_text_atomic(
		ProjectSettings.globalize_path(BOOTSTRAP_PATH),
		JSON.stringify(data, "\t"),
	)


func _load_bootstrap_identity() -> void:
	var data: Dictionary = _read_json(BOOTSTRAP_PATH, 64 * 1024)
	if data.is_empty():
		data = _read_json(BOOTSTRAP_PATH + ".backup", 64 * 1024)
	device_id = str(data.get("device_id", ""))
	if device_id.length() != 32:
		device_id = Crypto.new().generate_random_bytes(16).hex_encode()


func _command_line_override() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in args.size():
		var value: String = args[index]
		if value.begins_with("--data-dir="):
			return value.trim_prefix("--data-dir=")
		if value == "--data-dir" and index + 1 < args.size():
			return args[index + 1]
	return ""


func _valid_manifest(data: Dictionary) -> bool:
	return (
		data.get("format_version") == MANIFEST_VERSION
		and data.get("layout_version") == LAYOUT_VERSION
		and data.get("application") == APPLICATION_ID
		and typeof(data.get("root_id")) == TYPE_STRING
		and str(data["root_id"]).length() == 32
	)


func _directory_is_empty(path: String) -> bool:
	var access: DirAccess = DirAccess.open(path)
	if access == null:
		return true
	access.list_dir_begin()
	var entry_name: String = access.get_next()
	while entry_name in [".", ".."]:
		entry_name = access.get_next()
	access.list_dir_end()
	return entry_name.is_empty()


func _normalize(path: String) -> String:
	var normalized: String = path.replace("\\", "/").simplify_path()
	while normalized.length() > 1 and normalized.ends_with("/"):
		if _is_windows_drive_root(normalized):
			break
		normalized = normalized.left(-1)
	return normalized


func _read_json(path: String, maximum := 1024 * 1024) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > maximum:
		return {}
	var json: JSON = JSON.new()
	var error: Error = json.parse(file.get_as_text())
	file.close()
	return json.data if error == OK and typeof(json.data) == TYPE_DICTIONARY else {}


func _write_text_atomic(path: String, text: String) -> bool:
	var absolute: String = (
		ProjectSettings.globalize_path(path)
		if path.begins_with("user://")
		else path
	)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return false
	var temporary: String = absolute + ".tmp"
	var file: FileAccess = FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	var ok: bool = file.get_error() == OK
	file.close()
	if not ok:
		return false
	var backup: String = absolute + ".backup"
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	var had_primary: bool = FileAccess.file_exists(absolute)
	if had_primary and DirAccess.rename_absolute(absolute, backup) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		if had_primary:
			DirAccess.rename_absolute(backup, absolute)
		return false
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	return true


func _fail(message: String) -> bool:
	error_message = message
	status_changed.emit(message)
	return false
