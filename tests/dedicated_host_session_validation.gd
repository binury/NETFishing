extends SceneTree

const TEST_PORT: int = 35777


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var harness := Node.new()
	root.add_child(harness)
	var players := Node3D.new()
	harness.add_child(players)
	var spawn_service := PlayerSpawnService.new()
	harness.add_child(spawn_service)
	spawn_service.setup(players, null, Transform3D.IDENTITY)
	var host_identity := HostIdentityStore.new()
	harness.add_child(host_identity)
	var known_players := KnownPlayerStore.new()
	harness.add_child(known_players)
	var host_bans := HostBanStore.new()
	harness.add_child(host_bans)
	var session := NetworkSession.new()
	harness.add_child(session)
	await process_frame
	session.setup(
		null,
		null,
		spawn_service,
		null,
		host_identity,
		known_players,
		null,
		host_bans,
		true,
	)
	assert(session.start_dedicated_host(TEST_PORT, 5, "127.0.0.1"))
	assert(session.is_dedicated_host())
	assert(session.get_local_peer_id() == 0)
	assert(session.get_player_count() == 0)
	assert(session.get_session_max_players() == 5)
	assert(session.get_host_port() == TEST_PORT)
	assert(session.set_host_open(true))
	assert(session.is_open_host())
	session.disconnect_session("Dedicated host validation complete.")
	assert(not session.is_session_active())
	assert(not session.is_dedicated_host())
	harness.queue_free()
	print("DEDICATED_HOST_SESSION_VALIDATION_OK")
	quit(0)
