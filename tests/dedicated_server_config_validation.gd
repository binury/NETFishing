extends SceneTree

const ConfigType = preload("res://server/dedicated_server_config.gd")


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
	file.set_value("server", "public", true)
	file.set_value("server", "data_directory", "/tmp/configured-server")
	file.set_value("discovery", "url", "https://discovery.netfishing.org/")
	assert(file.save(path) == OK)

	var configured := ConfigType.new()
	assert(bool(configured.call("_load_file", path)))
	configured.call("_validate")
	assert(configured.is_valid())
	assert(str(configured.get("server_name")) == "Configured Room")
	assert(str(configured.get("bind_address")) == "127.0.0.1")
	assert(int(configured.get("port")) == 17777)
	assert(int(configured.get("max_players")) == 12)
	assert(bool(configured.get("public_listing")))
	assert(str(configured.get("discovery_url")) == "https://discovery.netfishing.org")
	assert(DirAccess.remove_absolute(path) == OK)

	var invalid := ConfigType.new()
	invalid.set("public_listing", true)
	invalid.set("data_directory", "/tmp/invalid-server")
	invalid.call("_validate")
	assert(not invalid.is_valid())

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
			"required_game_version": "0.6.8-alpha",
		},
	}
	var outdated_message: String = str(
		discovery.call("_request_failure", outdated_discovery_error)
	)
	assert("out of date" in outdated_message)
	assert("0.6.8-alpha" in outdated_message)
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
			"required_game_version": "0.6.6-alpha",
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
