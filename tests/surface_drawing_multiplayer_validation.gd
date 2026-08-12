extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const TEST_PORT: int = 18133
const WAIT_MSEC: int = 20000


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
	push_error("Surface drawing multiplayer validation needs host or client mode.")
	quit(1)


func _run_host() -> void:
	var main: Node = await _create_initialized_main()
	var session := main.get_node("%NetworkSession") as NetworkSession
	assert(session.start_private_host(TEST_PORT))
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(save_manager.initialize_new_game())
	main.call("_enter_gameplay")
	await physics_frame
	await physics_frame
	var player := main.get("_player") as Player
	assert(player.bag.add_item(&"art_kit", 1))
	assert(player.art_unlocks.restore_mask(PlayerArtUnlocks.ALL_UNLOCK_MASK))

	var service := main.get_node(
		"%NetworkSurfaceDrawingService"
	) as NetworkSurfaceDrawingService
	var surface: Dictionary = _surface_below_local_player(main)
	assert(not surface.is_empty())
	assert(service.request_canvas_at_surface(
		surface["position"], surface["normal"], Vector3.RIGHT
	))
	var canvas_id: String = service.get_canvas_ids()[0]
	assert(service.request_cell_edits(canvas_id, [{
		"x": 7,
		"y": 7,
		"color_id": "coral",
	}]))
	assert(session.set_host_open(true))

	var remote_peer_id: int = await _wait_for_remote_peer(session)
	assert(remote_peer_id > 1)
	var remote_record: PeerRegistry.PeerRecord = session.get_peer_record(
		remote_peer_id
	)
	assert(remote_record != null)
	assert(session.peer_supports_capability(
		remote_peer_id, SurfaceDrawingProtocol.CAPABILITY
	))

	var overwrite_deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < overwrite_deadline:
		await process_frame
		var state: Dictionary = service.get_canvas_state(canvas_id)
		if int(state.get("revision", 0)) < 2:
			continue
		var cell: Dictionary = _find_cell(state, 7, 7)
		if (
			str(cell.get("color_id", "")) == "blue"
			and str(cell.get("author_fingerprint", ""))
				== remote_record.identity_fingerprint
		):
			break
	var overwritten_state: Dictionary = service.get_canvas_state(canvas_id)
	assert(int(overwritten_state["revision"]) >= 2)
	var overwritten_cell: Dictionary = _find_cell(overwritten_state, 7, 7)
	assert(str(overwritten_cell["color_id"]) == "blue")
	assert(
		str(overwritten_cell["author_fingerprint"])
		== remote_record.identity_fingerprint
	)

	assert(service.request_cell_edits(canvas_id, [{
		"x": 8,
		"y": 7,
		"color_id": "sunny",
	}]))
	var undo_deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < undo_deadline:
		await process_frame
		var state: Dictionary = service.get_canvas_state(canvas_id)
		if str(_find_cell(state, 7, 7).get("color_id", "")) == "coral":
			break
	assert(
		str(_find_cell(service.get_canvas_state(canvas_id), 7, 7)["color_id"])
		== "coral"
	)
	var guide_deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < guide_deadline:
		await process_frame
		if not bool(service.get_canvas_state(canvas_id).get("guide_visible", true)):
			break
	assert(not bool(service.get_canvas_state(canvas_id)["guide_visible"]))
	# Keep the shared hidden state observable before publishing the restore.
	await create_timer(1.0).timeout
	assert(service.request_guide_visibility(canvas_id, true))
	await create_timer(1.0).timeout
	assert(service.request_guide_visibility(canvas_id, false, true))
	await create_timer(1.0).timeout
	assert(service.clear_session_artwork())
	await create_timer(1.0).timeout
	print("Surface drawing multiplayer host validation: PASS")
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
	var join_deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < join_deadline:
		await process_frame
		if session.state == NetworkSession.State.VERIFYING_SERVER_IDENTITY:
			main.call("_confirm_server_trust")
		if session.is_joined_client() and bool(main.get("_gameplay_started")):
			break
	assert(session.is_joined_client())
	assert(session.supports_server_capability(
		SurfaceDrawingProtocol.CAPABILITY
	))
	var player := main.get("_player") as Player
	assert(player.bag.add_item(&"art_kit", 1))
	assert(player.art_unlocks.restore_mask(PlayerArtUnlocks.ALL_UNLOCK_MASK))

	var service := main.get_node(
		"%NetworkSurfaceDrawingService"
	) as NetworkSurfaceDrawingService
	var snapshot_deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while (
		Time.get_ticks_msec() < snapshot_deadline
		and service.get_canvas_ids().is_empty()
	):
		await process_frame
	assert(service.get_canvas_ids().size() == 1)
	var canvas_id: String = service.get_canvas_ids()[0]
	var snapshot: Dictionary = service.get_canvas_state(canvas_id)
	assert(str(_find_cell(snapshot, 7, 7).get("color_id", "")) == "coral")
	assert(service.request_cell_edits(canvas_id, [{
		"x": 7,
		"y": 7,
		"color_id": "blue",
	}]))

	var shared_edit_deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < shared_edit_deadline:
		await process_frame
		var state: Dictionary = service.get_canvas_state(canvas_id)
		if str(_find_cell(state, 8, 7).get("color_id", "")) == "sunny":
			break
	var final_state: Dictionary = service.get_canvas_state(canvas_id)
	assert(str(_find_cell(final_state, 7, 7)["color_id"]) == "blue")
	assert(str(_find_cell(final_state, 8, 7)["color_id"]) == "sunny")
	assert(service.request_undo_last_stroke())
	var undo_deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < undo_deadline:
		await process_frame
		var state: Dictionary = service.get_canvas_state(canvas_id)
		if str(_find_cell(state, 7, 7).get("color_id", "")) == "coral":
			break
	assert(
		str(_find_cell(service.get_canvas_state(canvas_id), 7, 7)["color_id"])
		== "coral"
	)
	assert(service.request_guide_visibility(canvas_id, false))
	var guide_hidden_deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < guide_hidden_deadline:
		await process_frame
		if not bool(service.get_canvas_state(canvas_id).get("guide_visible", true)):
			break
	assert(not bool(service.get_canvas_state(canvas_id)["guide_visible"]))
	var guide_restored_deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < guide_restored_deadline:
		await process_frame
		if bool(service.get_canvas_state(canvas_id).get("guide_visible", false)):
			break
	assert(bool(service.get_canvas_state(canvas_id)["guide_visible"]))
	var finalized_deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < finalized_deadline:
		await process_frame
		if bool(service.get_canvas_state(canvas_id).get("finalized", false)):
			break
	assert(bool(service.get_canvas_state(canvas_id)["finalized"]))
	var reset_deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < reset_deadline:
		await process_frame
		if service.get_canvas_ids().is_empty():
			break
	assert(service.get_canvas_ids().is_empty())
	print("Surface drawing multiplayer client validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	quit()


func _surface_below_local_player(main: Node) -> Dictionary:
	var player := main.get("_player") as Player
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP * 3.0,
		player.global_position + Vector3.DOWN * 6.0,
		1,
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [player.get_rid()]
	return player.get_world_3d().direct_space_state.intersect_ray(query)


func _wait_for_remote_peer(session: NetworkSession) -> int:
	var deadline: int = Time.get_ticks_msec() + WAIT_MSEC
	while Time.get_ticks_msec() < deadline:
		await process_frame
		for peer_id: int in session.get_authenticated_peer_ids():
			if peer_id != session.get_local_peer_id():
				return peer_id
	return 0


func _find_cell(state: Dictionary, x: int, y: int) -> Dictionary:
	for value: Variant in state.get("cells", []):
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var cell: Dictionary = value
		if int(cell.get("x", -1)) == x and int(cell.get("y", -1)) == y:
			return cell
	return {}


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
