class_name DedicatedServerConfig
extends RefCounted

const DEFAULT_NAME: String = "NETfishing Dedicated Server"
const DEFAULT_BIND_ADDRESS: String = "*"
const DEFAULT_PORT: int = 7777
const DEFAULT_MAX_PLAYERS: int = 8
const DEFAULT_WORLD_SEED: int = 13001
const MAX_WORLD_SEED: int = 2147483646
const MAX_OPERATORS: int = 64

var server_name: String = DEFAULT_NAME
var bind_address: String = DEFAULT_BIND_ADDRESS
var port: int = DEFAULT_PORT
var max_players: int = DEFAULT_MAX_PLAYERS
var world_seed: int = DEFAULT_WORLD_SEED
var public_listing: bool = false
var discovery_url: String = ""
var data_directory: String = ""
var operator_fingerprints: PackedStringArray = PackedStringArray()
var error_message: String = ""


static func from_runtime() -> DedicatedServerConfig:
	var result := DedicatedServerConfig.new()
	result.data_directory = ProjectSettings.globalize_path(
		"user://dedicated-server-data"
	)
	result.discovery_url = str(ProjectSettings.get_setting(
		"network/discovery/base_url", ""
	)).strip_edges()
	var config_path: String = OS.get_environment(
		"NETFISHING_SERVER_CONFIG"
	).strip_edges()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--config="):
			config_path = argument.trim_prefix("--config=").strip_edges()
	if not config_path.is_empty() and not result._load_file(config_path):
		return result
	result._apply_environment()
	result._apply_arguments(OS.get_cmdline_user_args())
	result._validate()
	return result


func is_valid() -> bool:
	return error_message.is_empty()


func _load_file(path: String) -> bool:
	var file := ConfigFile.new()
	var error: Error = file.load(path)
	if error != OK:
		error_message = "Could not load server configuration: %s" % path
		return false
	server_name = str(file.get_value("server", "name", server_name))
	bind_address = str(file.get_value(
		"server", "bind_address", bind_address
	))
	port = int(file.get_value("server", "port", port))
	max_players = int(file.get_value(
		"server", "max_players", max_players
	))
	world_seed = int(file.get_value("world", "seed", world_seed))
	public_listing = bool(file.get_value(
		"server", "public", public_listing
	))
	data_directory = str(file.get_value(
		"server", "data_directory", data_directory
	))
	discovery_url = str(file.get_value(
		"discovery", "url", discovery_url
	))
	operator_fingerprints = _parse_fingerprint_list(file.get_value(
		"moderation", "operators", operator_fingerprints
	))
	return true


func _apply_environment() -> void:
	server_name = _environment_string(
		"NETFISHING_SERVER_NAME", server_name
	)
	bind_address = _environment_string(
		"NETFISHING_SERVER_BIND", bind_address
	)
	port = _environment_int("NETFISHING_SERVER_PORT", port)
	max_players = _environment_int(
		"NETFISHING_SERVER_MAX_PLAYERS", max_players
	)
	world_seed = _environment_int(
		"NETFISHING_WORLD_SEED", world_seed
	)
	public_listing = _environment_bool(
		"NETFISHING_SERVER_PUBLIC", public_listing
	)
	discovery_url = _environment_string(
		"NETFISHING_DISCOVERY_URL", discovery_url
	)
	data_directory = _environment_string(
		"NETFISHING_DATA_DIR", data_directory
	)
	if OS.has_environment("NETFISHING_SERVER_OPERATORS"):
		operator_fingerprints = _parse_fingerprint_list(
			OS.get_environment("NETFISHING_SERVER_OPERATORS")
		)


func _apply_arguments(arguments: PackedStringArray) -> void:
	for argument: String in arguments:
		if argument.begins_with("--name="):
			server_name = argument.trim_prefix("--name=")
		elif argument.begins_with("--bind="):
			bind_address = argument.trim_prefix("--bind=")
		elif argument.begins_with("--port="):
			port = _parse_int(argument.trim_prefix("--port="), port)
		elif argument.begins_with("--max-players="):
			max_players = _parse_int(
				argument.trim_prefix("--max-players="), max_players
			)
		elif argument.begins_with("--world-seed="):
			world_seed = _parse_int(
				argument.trim_prefix("--world-seed="), world_seed
			)
		elif argument.begins_with("--data-dir="):
			data_directory = argument.trim_prefix("--data-dir=")
		elif argument.begins_with("--discovery-url="):
			discovery_url = argument.trim_prefix("--discovery-url=")
		elif argument.begins_with("--operators="):
			operator_fingerprints = _parse_fingerprint_list(
				argument.trim_prefix("--operators=")
			)
		elif argument == "--public":
			public_listing = true
		elif argument == "--private":
			public_listing = false


func _validate() -> void:
	server_name = server_name.strip_edges().left(48)
	bind_address = bind_address.strip_edges()
	discovery_url = discovery_url.strip_edges().trim_suffix("/")
	data_directory = data_directory.strip_edges()
	operator_fingerprints = _normalized_fingerprints(operator_fingerprints)
	if server_name.is_empty():
		error_message = "Server name cannot be empty."
	elif not _safe_text(server_name):
		error_message = "Server name contains unsupported characters."
	elif bind_address.is_empty():
		error_message = "Bind address cannot be empty."
	elif port < 1 or port > 65535:
		error_message = "Server port must be between 1 and 65535."
	elif max_players < 1 or max_players > 128:
		error_message = "Maximum players must be between 1 and 128."
	elif world_seed <= 0 or world_seed > MAX_WORLD_SEED:
		error_message = "World seed must be between 1 and %d." % MAX_WORLD_SEED
	elif not data_directory.is_empty() and not data_directory.is_absolute_path():
		error_message = "Server data directory must be an absolute path."
	elif public_listing and not (
		discovery_url.begins_with("https://")
		or discovery_url.begins_with("http://")
	):
		error_message = "A public server requires a discovery URL."
	elif operator_fingerprints.size() > MAX_OPERATORS:
		error_message = "A server may configure at most %d operators." % (
			MAX_OPERATORS
		)
	else:
		for fingerprint: String in operator_fingerprints:
			if not NetworkIdentityCrypto.valid_fingerprint(fingerprint):
				error_message = (
					"Server operator fingerprints must be 64 lowercase hex characters."
				)
				break


static func _safe_text(value: String) -> bool:
	for index: int in value.length():
		var codepoint: int = value.unicode_at(index)
		if codepoint < 32 or codepoint == 127:
			return false
	return true


static func _environment_string(name: String, fallback: String) -> String:
	return OS.get_environment(name) if OS.has_environment(name) else fallback


static func _environment_int(name: String, fallback: int) -> int:
	return (
		_parse_int(OS.get_environment(name), fallback)
		if OS.has_environment(name) else fallback
	)


static func _environment_bool(name: String, fallback: bool) -> bool:
	if not OS.has_environment(name):
		return fallback
	var value: String = OS.get_environment(name).strip_edges().to_lower()
	return value in ["1", "true", "yes", "on"]


static func _parse_int(value: String, fallback: int) -> int:
	return int(value) if value.strip_edges().is_valid_int() else fallback


static func _parse_fingerprint_list(value: Variant) -> PackedStringArray:
	var values: PackedStringArray = PackedStringArray()
	if typeof(value) == TYPE_STRING:
		var text: String = str(value)
		for separator: String in [";", "\n", "\r", "\t", " "]:
			text = text.replace(separator, ",")
		values = text.split(",", false)
	elif typeof(value) in [TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY]:
		for entry: Variant in value:
			if typeof(entry) in [TYPE_STRING, TYPE_STRING_NAME]:
				values.append(str(entry))
	return _normalized_fingerprints(values)


static func _normalized_fingerprints(
	values: PackedStringArray,
) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for value: String in values:
		var fingerprint: String = value.strip_edges().to_lower()
		if not fingerprint.is_empty() and fingerprint not in result:
			result.append(fingerprint)
	result.sort()
	return result
