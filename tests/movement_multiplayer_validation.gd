extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const PlayerScene: PackedScene = preload("res://player/player.tscn")
const TEST_PORT: int = 18141


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _validate_latency_smoothing()
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.has("unit"):
		print("Movement latency smoothing validation: PASS")
		quit()
		return
	if arguments.has("host"):
		await _run_host()
		return
	if arguments.has("client"):
		await _run_client()
		return
	push_error("Movement multiplayer validation needs host or client mode.")
	quit(1)


func _validate_latency_smoothing() -> void:
	var avatar := PlayerScene.instantiate() as Player
	root.add_child(avatar)
	await process_frame
	avatar.set_process(false)
	avatar.set_physics_process(false)
	_validate_compact_snapshot_encoding()
	_validate_transit_estimation()
	_validate_remote_snapshot_smoothing(avatar)
	_validate_reliable_jump_intent(avatar)
	_validate_stale_input_expiry(avatar)
	avatar.queue_free()
	await process_frame


func _validate_compact_snapshot_encoding() -> void:
	var moving_snapshot: Dictionary = _network_snapshot(
		Vector3.ZERO,
		Vector3(4.5, 0.0, 0.0),
		1,
	)
	assert(NetworkSession.MOVEMENT_SNAPSHOT_BATCH_SIZE == 8)
	var encoded_snapshots: Array = []
	for _peer: int in NetworkSession.MOVEMENT_SNAPSHOT_BATCH_SIZE:
		encoded_snapshots.append(
			NetworkSession._encode_movement_snapshot(moving_snapshot)
		)
	assert(var_to_bytes(encoded_snapshots).size() < 1200)
	assert(
		NetworkSession._decode_movement_snapshot(
			encoded_snapshots[0]
		) == moving_snapshot
	)


func _validate_transit_estimation() -> void:
	assert(is_equal_approx(
		Player.resolve_local_prediction_transit_seconds(
			10,
			16,
			1.0 / 30.0,
			0.075,
		),
		0.075,
	))
	# Six outstanding 30 Hz inputs span about 200 ms round trip. The fallback
	# must use only the approximately 100 ms one-way half of that gap.
	assert(is_equal_approx(
		Player.resolve_local_prediction_transit_seconds(
			10,
			16,
			1.0 / 30.0,
			-1.0,
		),
		0.1,
	))
	assert(is_equal_approx(
		Player.resolve_local_prediction_transit_seconds(
			1,
			100,
			1.0 / 30.0,
			-1.0,
		),
		Player.LOCAL_PREDICTION_EXTRAPOLATION_LIMIT_SECONDS,
	))


func _validate_remote_snapshot_smoothing(avatar: Player) -> void:
	avatar.configure_network_remote(false)
	var moving_snapshot: Dictionary = _network_snapshot(
		Vector3.ZERO,
		Vector3(4.5, 0.0, 0.0),
		1,
	)
	avatar.push_network_snapshot(moving_snapshot, 0.1)
	assert(is_equal_approx(avatar.global_position.x, 0.45))
	assert(is_equal_approx(
		float(avatar.get("_network_target_position").x),
		0.45,
	))
	avatar.call("_update_network_interpolation", 0.12)
	var before_delayed_snapshot: Vector3 = avatar.global_position
	var delayed_snapshot: Dictionary = _network_snapshot(
		Vector3(0.54, 0.0, 0.0),
		Vector3(4.5, 0.0, 0.0),
		2,
	)
	avatar.push_network_snapshot(delayed_snapshot, 0.1)
	# Snapshot receipt updates the target without teleporting a presented
	# remote avatar, even after a jittered packet interval.
	assert(avatar.global_position == before_delayed_snapshot)
	assert(float(avatar.get("_network_snapshot_jitter")) > 0.0)
	avatar.call("_update_network_interpolation", 1.0 / 60.0)
	assert(
		avatar.global_position.distance_to(before_delayed_snapshot) < 0.12
	)
	# Simulate a burst of dropped snapshots. Extrapolation must stop at the
	# tight limit instead of allowing the remote avatar to run indefinitely.
	for _step: int in 20:
		avatar.call("_update_network_interpolation", 1.0 / 30.0)
	assert(is_equal_approx(
		float(avatar.get("_network_snapshot_age")),
		Player.NETWORK_EXTRAPOLATION_LIMIT_SECONDS,
	))
	var maximum_extrapolated_x: float = (
		0.54
		+ 4.5 * (0.1 + Player.NETWORK_EXTRAPOLATION_LIMIT_SECONDS)
	)
	assert(avatar.global_position.x <= maximum_extrapolated_x + 0.1)

	avatar.set_local_control(true)
	avatar.global_position = Vector3(0.8, 0.0, 0.0)
	avatar.apply_local_prediction_correction(
		moving_snapshot,
		10,
		1.0 / 30.0,
		0.1,
	)
	assert(avatar.global_position.x < 0.8)
	assert(avatar.global_position.x > 0.7)


func _validate_reliable_jump_intent(avatar: Player) -> void:
	avatar.set_local_control(true)
	avatar.call("_queue_local_network_jump_intent")
	var first: Dictionary = avatar.capture_network_input(20)
	var repeated: Dictionary = avatar.capture_network_input(21)
	assert(bool(first["jump"]))
	assert(bool(repeated["jump"]))
	assert(int(avatar.get("_local_network_jump_intent_sequence")) == 20)
	avatar.apply_local_prediction_correction(
		_network_snapshot(avatar.global_position, Vector3.ZERO, 20),
		21,
		1.0 / 30.0,
		0.0,
	)
	assert(not bool(avatar.capture_network_input(22)["jump"]))

	avatar.configure_network_remote(true)
	var first_host_jump: Dictionary = _movement_input(30, false, false)
	first_host_jump["jump"] = true
	avatar.apply_authoritative_network_input(first_host_jump)
	assert(bool(avatar.get("_network_jump_pending")))
	avatar.set("_network_jump_pending", false)
	var repeated_host_jump: Dictionary = _movement_input(31, false, false)
	repeated_host_jump["jump"] = true
	avatar.apply_authoritative_network_input(repeated_host_jump)
	assert(not bool(avatar.get("_network_jump_pending")))
	avatar.apply_authoritative_network_input(
		_movement_input(32, false, false)
	)
	var next_host_jump: Dictionary = _movement_input(33, false, false)
	next_host_jump["jump"] = true
	avatar.apply_authoritative_network_input(next_host_jump)
	assert(bool(avatar.get("_network_jump_pending")))
	avatar.reset_network_movement_state()
	assert(not bool(avatar.get("_network_jump_pending")))
	assert(not bool(avatar.get("_local_network_jump_intent_pending")))
	assert(int(avatar.get("_last_network_input_sequence")) == 0)


func _validate_stale_input_expiry(avatar: Player) -> void:
	avatar.configure_network_remote(true)
	avatar.apply_authoritative_network_input(_movement_input(40, true))
	assert((avatar.get("_network_axis") as Vector2).length_squared() > 0.0)
	avatar.call(
		"_update_network_input_freshness",
		Player.NETWORK_INPUT_STALE_TIMEOUT_SECONDS + 0.01,
	)
	assert((avatar.get("_network_axis") as Vector2) == Vector2.ZERO)
	assert(not bool(avatar.get("_network_sprint")))
	assert(bool(avatar.get("_network_input_stale")))
	avatar.apply_authoritative_network_input(_movement_input(41, false))
	assert(not bool(avatar.get("_network_input_stale")))
	assert((avatar.get("_network_axis") as Vector2).length_squared() > 0.0)


func _network_snapshot(
	position: Vector3,
	velocity: Vector3,
	acknowledged_input: int,
) -> Dictionary:
	return {
		"peer_id": 2,
		"acknowledged_input": acknowledged_input,
		"position": [position.x, position.y, position.z],
		"velocity": [velocity.x, velocity.y, velocity.z],
		"visual_yaw": 0.0,
		"animation_state": NetworkPlayerAnimationProtocol.make_state(
			NetworkPlayerAnimationProtocol.LOCOMOTION_RUNNING,
			true,
		),
		"sitting": false,
		"casting": false,
	}


func _run_host() -> void:
	var main: Node = await _create_initialized_main()
	var session := main.get_node("%NetworkSession") as NetworkSession
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(session.start_private_host(TEST_PORT))
	assert(save_manager.initialize_new_game())
	main.call("_enter_gameplay")
	for _frame: int in 4:
		await physics_frame
	assert(session.set_host_open(true))
	var remote_peer_id: int = await _wait_for_remote_peer(session)
	assert(remote_peer_id > 1)
	var player := main.get("_player") as Player
	player.configure_network_remote(true)
	player.apply_authoritative_network_input(_movement_input(1, true))
	await create_timer(2.5).timeout
	player.apply_authoritative_network_input(_movement_input(2, false))
	await create_timer(2.5).timeout
	player.apply_authoritative_network_input(
		_movement_input(3, false, true, true)
	)
	await create_timer(2.0).timeout
	player.apply_authoritative_network_input(
		_movement_input(4, false, false, true)
	)
	await create_timer(2.0).timeout
	player.apply_authoritative_network_input(
		_movement_input(5, false, false, true, &"draw", 1)
	)
	await create_timer(1.0).timeout
	player.apply_authoritative_network_input(
		_movement_input(6, false, false, true, &"strike", 2)
	)
	await create_timer(0.5).timeout
	player.apply_authoritative_network_input(
		_movement_input(7, false, false, false, &"", 3)
	)
	var disconnect_deadline: int = Time.get_ticks_msec() + 8000
	while (
		Time.get_ticks_msec() < disconnect_deadline
		and session.is_authenticated_peer(remote_peer_id)
	):
		await process_frame
	assert(not session.is_authenticated_peer(remote_peer_id))
	print("Movement multiplayer host validation: PASS")
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
	var join_deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < join_deadline:
		await process_frame
		if session.state == NetworkSession.State.VERIFYING_SERVER_IDENTITY:
			main.call("_confirm_server_trust")
		if session.is_joined_client() and bool(main.get("_gameplay_started")):
			break
	assert(session.is_joined_client())
	var spawn_service := main.get_node(
		"%PlayerSpawnService"
	) as PlayerSpawnService
	var host_avatar: Player = spawn_service.get_avatar(1)
	assert(host_avatar != null)
	var animation_player := host_avatar.get_node(
		"Visuals/CharacterRig/AnimationPlayer"
	) as AnimationPlayer
	var sprint_dust := host_avatar.get_node("%SprintDust") as SprintDustTrail
	var saw_running: bool = false
	var saw_walking: bool = false
	var saw_sneaking: bool = false
	var saw_idle_sneak: bool = false
	var saw_net_draw: bool = false
	var saw_net_strike: bool = false
	var saw_animation_advance: bool = false
	var saw_dust: bool = false
	var previous_animation: StringName = &""
	var previous_animation_position: float = -1.0
	var observation_deadline: int = Time.get_ticks_msec() + 14000
	while Time.get_ticks_msec() < observation_deadline:
		await process_frame
		var current_animation: StringName = animation_player.current_animation
		saw_running = saw_running or current_animation.begins_with("running")
		saw_walking = saw_walking or current_animation.begins_with("walking")
		saw_sneaking = saw_sneaking or current_animation == &"sneaking"
		saw_idle_sneak = saw_idle_sneak or current_animation == &"idle_sneak"
		saw_net_draw = saw_net_draw or current_animation == &"draw"
		saw_net_strike = saw_net_strike or current_animation == &"strike"
		var current_position: float = (
			animation_player.current_animation_position
		)
		if (
			current_animation == previous_animation
			and previous_animation_position >= 0.0
			and absf(current_position - previous_animation_position) > 0.001
		):
			saw_animation_advance = true
		previous_animation = current_animation
		previous_animation_position = current_position
		saw_dust = saw_dust or sprint_dust.get_active_puff_count() > 0
		if (
			saw_running
			and saw_walking
			and saw_sneaking
			and saw_idle_sneak
			and saw_net_draw
			and saw_net_strike
			and saw_animation_advance
			and saw_dust
		):
			break
	assert(saw_running)
	assert(saw_walking)
	assert(saw_sneaking)
	assert(saw_idle_sneak)
	assert(saw_net_draw)
	assert(saw_net_strike)
	assert(saw_animation_advance)
	assert(saw_dust)
	print("Movement multiplayer client validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()


func _movement_input(
	sequence: int,
	sprinting: bool,
	moving: bool = true,
	sneaking: bool = false,
	action_id: StringName = &"",
	action_sequence: int = 0,
) -> Dictionary:
	return {
		"sequence": sequence,
		"axis": [0.0, -1.0] if moving else [0.0, 0.0],
		"camera_yaw": 0.0,
		"jump": false,
		"sprint": sprinting,
		"sneak": sneaking,
		"slow_walk": false,
		"sitting": false,
		"casting": false,
		"animation_action": NetworkPlayerAnimationProtocol.make_action_state(
			action_id,
			action_sequence,
		),
	}


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


func _wait_for_remote_peer(session: NetworkSession) -> int:
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		for peer_id: int in session.get_authenticated_peer_ids():
			if peer_id != session.get_local_peer_id():
				return peer_id
	return 0
