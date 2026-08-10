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
	assert(bool(discovery.call("_valid_public_room", {
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
	})))
	discovery.free()
	print("DEDICATED_SERVER_CONFIG_VALIDATION_OK")
	quit()
