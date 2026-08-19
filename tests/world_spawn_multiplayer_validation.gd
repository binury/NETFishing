extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const TEST_PORT: int = 18170
const EXPECTED_POPULATION: int = 8
const EXPECTED_BY_TYPE: Dictionary = {
	&"crab_brown": 2,
	&"clam_manila": 3,
	&"beetle_stag_common": 3,
}
const WINTER_POPULATION: int = 5
const WINTER_BY_TYPE: Dictionary = {
	&"crab_brown": 2,
	&"clam_manila": 3,
}
const SUMMER_DATE_ID: String = "2026-08-18"
const WINTER_DATE_ID: String = "2026-12-18"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("host"):
		await _run_host()
		return
	if arguments.has("client"):
		await _run_client()
		return
	push_error("World spawn multiplayer validation needs host or client mode.")
	quit(1)


func _run_host() -> void:
	var main: Node = await _create_initialized_main()
	var session := main.get_node("%NetworkSession") as NetworkSession
	var service: Node = main.get_node("%NetworkWorldSpawnService")
	var world_time := main.get_node("%WorldTimeService") as WorldTimeService
	assert(session.start_dedicated_host(TEST_PORT, 8, "127.0.0.1"))
	assert(world_time.synchronize_calendar_time(12.0, SUMMER_DATE_ID))
	assert(world_time.set_authoritative_time(12.0))
	assert(session.set_host_open(true))
	await _wait_for_population(service, EXPECTED_POPULATION)
	_freeze_timed_entries(service)
	_validate_population(service, true)

	var remote_peer_id: int = 0
	var join_deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < join_deadline and remote_peer_id == 0:
		await process_frame
		for peer_id: int in session.get_authenticated_peer_ids():
			if peer_id != session.get_local_peer_id():
				remote_peer_id = peer_id
				break
	assert(remote_peer_id > 1)
	assert(session.peer_supports_capability(
		remote_peer_id,
		NetworkProtocol.WORLD_SPAWN_CAPABILITY,
	))
	await create_timer(0.75).timeout
	assert(world_time.synchronize_calendar_time(12.0, WINTER_DATE_ID))
	await _wait_for_population(service, WINTER_POPULATION)
	_validate_population(service, true, WINTER_BY_TYPE)
	await create_timer(0.75).timeout
	assert(world_time.synchronize_calendar_time(12.0, SUMMER_DATE_ID))
	await _wait_for_population(service, EXPECTED_POPULATION)
	_validate_population(service, true)

	var disconnect_deadline: int = Time.get_ticks_msec() + 12000
	while (
		Time.get_ticks_msec() < disconnect_deadline
		and session.is_authenticated_peer(remote_peer_id)
	):
		await process_frame
	assert(not session.is_authenticated_peer(remote_peer_id))
	_validate_population(service, true)
	_validate_respawn_budget(service)
	print("World spawn multiplayer host validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()


func _run_client() -> void:
	var main: Node = await _create_initialized_main()
	main.call(
		"_on_title_join_game_requested",
		"127.0.0.1:%d" % TEST_PORT,
	)
	var session := main.get_node("%NetworkSession") as NetworkSession
	var service: Node = main.get_node("%NetworkWorldSpawnService")
	var world_time := main.get_node("%WorldTimeService") as WorldTimeService
	var join_deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < join_deadline:
		await process_frame
		if session.state == NetworkSession.State.VERIFYING_SERVER_IDENTITY:
			main.call("_confirm_server_trust")
		if session.is_joined_client() and bool(main.get("_gameplay_started")):
			break
	assert(session.is_joined_client())
	assert(session.supports_server_capability(
		NetworkProtocol.WORLD_SPAWN_CAPABILITY
	))
	await _wait_for_population(service, EXPECTED_POPULATION)
	_validate_population(service, false)
	await _wait_for_population(service, WINTER_POPULATION)
	_validate_population(service, false, WINTER_BY_TYPE)
	assert(world_time.get_calendar_date_id() == WINTER_DATE_ID)
	await _wait_for_population(service, EXPECTED_POPULATION)
	_validate_population(service, false)
	assert(world_time.get_calendar_date_id() == SUMMER_DATE_ID)
	print("World spawn multiplayer client validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()


func _wait_for_population(service: Node, expected_population: int) -> void:
	var deadline: int = Time.get_ticks_msec() + 12000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if (service.get("_entities") as Dictionary).size() == expected_population:
			return
	assert(false, "Timed out waiting for the world spawn population.")


func _validate_population(
	service: Node,
	expect_authoritative_state: bool,
	expected_by_type: Dictionary = EXPECTED_BY_TYPE,
) -> void:
	var entities: Dictionary = service.get("_entities")
	var presentations: Dictionary = service.get("_presentations")
	var expected_population: int = 0
	for amount: int in expected_by_type.values():
		expected_population += amount
	assert(entities.size() == expected_population)
	assert(presentations.size() == expected_population)
	var counts: Dictionary = {}
	for state: Dictionary in entities.values():
		var type_id := state.get("type_id") as StringName
		counts[type_id] = int(counts.get(type_id, 0)) + 1
		var position: Variant = state.get("position")
		assert(typeof(position) == TYPE_VECTOR3)
		assert((position as Vector3).is_finite())
		var entry := state.get("data") as GatherableData
		assert(entry != null)
		assert(
			(position as Vector3).y
			>= entry.minimum_surface_y - 0.001
		)
		if expect_authoritative_state:
			var quality: int = int(state.get("quality", -1))
			assert(FishQuality.is_valid(quality))
			if entry.is_stationary_spawn():
				assert(entry.get_movement_speed_for_quality(quality) <= 0.0)
				assert(not entry.can_be_scared())
			else:
				assert(entry.get_movement_speed_for_quality(quality) > 0.0)
				assert(entry.get_scare_radius_for_quality(quality) > 0.0)
	assert(counts == expected_by_type)


func _freeze_timed_entries(service: Node) -> void:
	for state: Dictionary in (service.get("_entities") as Dictionary).values():
		var entry := state.get("data") as GatherableData
		if entry != null and entry.active_lifetime_seconds > 0.0:
			state["expires_at"] = INF


func _validate_respawn_budget(service: Node) -> void:
	var entities: Dictionary = service.get("_entities")
	var crab_ids: Array[String] = []
	for entity_id: String in entities:
		var state: Dictionary = entities[entity_id]
		if state.get("type_id") == &"crab_brown":
			crab_ids.append(entity_id)
	assert(crab_ids.size() == 2)
	for entity_id: String in crab_ids:
		service.call(
			"_despawn_entity",
			entity_id,
			&"captured",
			false,
			true,
		)
	assert((service.get("_entities") as Dictionary).size() == 6)

	var now: float = Time.get_ticks_msec() / 1000.0
	var respawns: Array = service.get("_respawns")
	assert(respawns.size() == crab_ids.size())
	for index: int in respawns.size():
		var respawn: Dictionary = respawns[index]
		var delay: float = float(respawn.get("due", 0.0)) - now
		assert(delay >= 479.0 and delay <= 721.0)
		respawn["due"] = now - 1.0
		respawns[index] = respawn

	service.call("_update_respawns")
	assert((service.get("_entities") as Dictionary).size() == 7)
	assert((service.get("_respawns") as Array).size() == 1)
	var next_by_type: Dictionary = service.get("_next_respawn_by_type")
	var next_allowed: float = float(next_by_type.get(&"crab_brown", 0.0))
	assert(next_allowed - now >= 179.0)

	service.call("_update_respawns")
	assert((service.get("_entities") as Dictionary).size() == 7)
	assert((service.get("_respawns") as Array).size() == 1)
	next_by_type[&"crab_brown"] = now - 1.0
	service.call("_update_respawns")
	assert((service.get("_entities") as Dictionary).size() == 8)
	assert((service.get("_respawns") as Array).is_empty())
	_validate_population(service, true)


func _create_initialized_main() -> Node:
	root.size = Vector2i(1280, 720)
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame
	if not bool(main.get("_application_initialized")):
		main.call("_activate_selected_data_path", "", true)
	for _frame: int in 8:
		await process_frame
	assert(bool(main.get("_application_initialized")))
	return main
