extends SceneTree

const ConfigType = preload("res://server/dedicated_server_config.gd")
const OPERATOR_A: String = (
	"0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
)
const OPERATOR_B: String = (
	"fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var defaults := ConfigType.new()
	defaults.set("data_directory", "/tmp/netfishing-server")
	defaults.call("_validate")
	assert(defaults.is_valid())
	assert(not bool(defaults.get("public_listing")))

	var path: String = ProjectSettings.globalize_path(
		"user://dedicated-server-validation.cfg"
	)
	var file := ConfigFile.new()
	file.set_value("server", "name", "Configured Room")
	file.set_value("server", "bind_address", "127.0.0.1")
	file.set_value("server", "port", 17777)
	file.set_value("server", "max_players", 12)
	file.set_value("world", "seed", 928374)
	file.set_value("server", "public", true)
	file.set_value("server", "data_directory", "/tmp/configured-server")
	file.set_value("discovery", "url", "https://discovery.netfishing.org/")
	file.set_value(
		"moderation", "operators", PackedStringArray([OPERATOR_B, OPERATOR_A])
	)
	assert(file.save(path) == OK)

	var configured := ConfigType.new()
	assert(bool(configured.call("_load_file", path)))
	configured.call("_validate")
	assert(configured.is_valid())
	assert(str(configured.get("server_name")) == "Configured Room")
	assert(str(configured.get("bind_address")) == "127.0.0.1")
	assert(int(configured.get("port")) == 17777)
	assert(int(configured.get("max_players")) == 12)
	assert(int(configured.get("world_seed")) == 928374)
	assert(bool(configured.get("public_listing")))
	assert(str(configured.get("discovery_url")) == "https://discovery.netfishing.org")
	assert(
		configured.get("operator_fingerprints")
		== PackedStringArray([OPERATOR_A, OPERATOR_B])
	)
	assert(DirAccess.remove_absolute(path) == OK)

	var parsed := ConfigType.new()
	parsed.set(
		"operator_fingerprints",
		ConfigType._parse_fingerprint_list(
			"%s, %s;%s" % [OPERATOR_B.to_upper(), OPERATOR_A, OPERATOR_A]
		),
	)
	parsed.set("data_directory", "/tmp/parsed-server")
	parsed.call("_validate")
	assert(parsed.is_valid())
	assert(
		parsed.get("operator_fingerprints")
		== PackedStringArray([OPERATOR_A, OPERATOR_B])
	)

	var invalid_operator := ConfigType.new()
	invalid_operator.set(
		"operator_fingerprints", PackedStringArray(["not-a-fingerprint"])
	)
	invalid_operator.set("data_directory", "/tmp/invalid-operator-server")
	invalid_operator.call("_validate")
	assert(not invalid_operator.is_valid())

	var invalid := ConfigType.new()
	invalid.set("public_listing", true)
	invalid.set("data_directory", "/tmp/invalid-server")
	invalid.call("_validate")
	assert(not invalid.is_valid())

	var invalid_seed := ConfigType.new()
	invalid_seed.set("world_seed", 0)
	invalid_seed.set("data_directory", "/tmp/invalid-seed-server")
	invalid_seed.call("_validate")
	assert(not invalid_seed.is_valid())

	var discovery := DiscoveryClient.new()
	assert(
		str(discovery.call("_default_room_name", "River"))
		== "River's Server"
	)
	assert(
		DiscoveryClient.UPNP_RENEW_INTERVAL_SECONDS
		< float(DiscoveryClient.UPNP_MAPPING_DURATION_SECONDS)
	)
	assert(
		DiscoveryClient.UPNP_RETRY_INTERVAL_SECONDS
		< DiscoveryClient.UPNP_RENEW_INTERVAL_SECONDS
	)
	var discovery_settings_path: String = ProjectSettings.globalize_path(
		DiscoveryClient.SETTINGS_PATH
	)
	assert(not FileAccess.file_exists(discovery_settings_path))
	assert(discovery.set_room_name("Client Room"))
	var client_settings: PackedByteArray = FileAccess.get_file_as_bytes(
		discovery_settings_path
	)
	assert(not client_settings.is_empty())
	var dedicated_discovery := DiscoveryClient.new()
	dedicated_discovery.call("_load_settings")
	assert(
		dedicated_discovery.configure_dedicated_runtime("Headless Room")
	)
	assert(dedicated_discovery.get_room_name() == "Headless Room")
	assert(
		FileAccess.get_file_as_bytes(discovery_settings_path)
		== client_settings
	)
	dedicated_discovery.free()
	assert(DirAccess.remove_absolute(discovery_settings_path) == OK)
	assert(
		discovery.get_host_state()
		== DiscoveryClient.HostState.CLOSED
	)
	assert(
		discovery.get_public_join_state()
		== DiscoveryClient.PublicJoinState.IDLE
	)
	discovery.set("_lease_room_id", "local-room")
	assert(discovery.is_own_room({"room_id": "local-room"}))
	assert(not discovery.is_own_room({"room_id": "another-room"}))
	discovery.set("_lease_room_id", "")
	assert(not discovery.is_own_room({"room_id": "local-room"}))
	var listed_room := {
		"room_id": "empty-dedicated-room",
		"room_name": "Empty Dedicated Room",
		"address": "203.0.113.10",
		"port": 7777,
		"current_players": 0,
		"max_players": 8,
		"game_version": str(ProjectSettings.get_setting(
			"application/config/version", "unknown"
		)),
		"protocol_version": NetworkProtocol.PROTOCOL_VERSION,
	}
	assert(bool(discovery.call("_valid_public_room", listed_room)))
	var incompatible_room: Dictionary = listed_room.duplicate(true)
	incompatible_room["game_version"] = "0.0.0-alpha"
	assert(not bool(discovery.call("_valid_public_room", incompatible_room)))
	assert(
		NetworkProtocol.game_version_rejection(
			"0.6.4-alpha", "0.6.5-alpha"
		) == NetworkProtocol.RejectionCode.CLIENT_OUTDATED
	)
	assert(
		NetworkProtocol.game_version_rejection(
			"0.6.6-alpha", "0.6.5-alpha"
		) == NetworkProtocol.RejectionCode.SERVER_OUTDATED
	)
	assert(
		NetworkProtocol.game_version_rejection(
			"0.6.5-alpha", "0.6.5-alpha"
		) == NetworkProtocol.RejectionCode.NONE
	)
	assert(
		NetworkProtocol.game_version_rejection(
			"0.6.5-beta", "0.6.5-alpha"
		) == NetworkProtocol.RejectionCode.SERVER_OUTDATED
	)
	var outdated_discovery_error := {
		"error": {
			"code": "game_version_mismatch",
			"message": "generic mismatch",
			"required_game_version": "99.0.0-alpha",
		},
	}
	var outdated_message: String = str(
		discovery.call("_request_failure", outdated_discovery_error)
	)
	assert("out of date" in outdated_message)
	assert("99.0.0-alpha" in outdated_message)
	assert("will not be listed" in outdated_message)
	discovery.set(
		"_host_request_kind",
		DiscoveryClient.HostRequestKind.CREATE,
	)
	discovery.set("_host_request_in_flight", true)
	discovery.call(
		"_on_host_request_completed",
		HTTPRequest.RESULT_SUCCESS,
		HTTPClient.RESPONSE_CONFLICT,
		PackedStringArray(),
		JSON.stringify(outdated_discovery_error).to_utf8_buffer(),
	)
	assert(discovery.get_host_state() == DiscoveryClient.HostState.ERROR)
	assert(discovery.host_status_is_error())
	assert(discovery.get_host_status_message() == outdated_message)
	var newer_discovery_error := {
		"error": {
			"code": "game_version_mismatch",
			"message": "generic mismatch",
			"required_game_version": "0.0.0-alpha",
		},
	}
	var newer_message: String = str(
		discovery.call("_request_failure", newer_discovery_error)
	)
	assert("discovery is updated" in newer_message)
	assert("will not be listed" in newer_message)
	discovery.free()
	print("DEDICATED_SERVER_CONFIG_VALIDATION_OK")
	quit()
