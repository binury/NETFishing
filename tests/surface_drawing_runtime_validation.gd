extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const TEST_PORT: int = 18132


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
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
	assert(service != null)
	assert(session.supports_server_capability(SurfaceDrawingProtocol.CAPABILITY))
	_validate_marker_controls(service, player)
	var query := PhysicsRayQueryParameters3D.create(
		player.global_position + Vector3.UP * 3.0,
		player.global_position + Vector3.DOWN * 6.0,
		1,
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty())
	assert(service.request_canvas_at_surface(
		hit["position"], hit["normal"], Vector3.RIGHT
	))
	assert(service.get_canvas_ids().size() == 1)
	var canvas_id: String = service.get_canvas_ids()[0]
	assert(service.request_cell_edits(canvas_id, [{
		"x": 8,
		"y": 8,
		"color_id": "ocean_teal",
	}]))
	var state: Dictionary = service.get_canvas_state(canvas_id)
	assert(int(state["revision"]) == 1)
	assert((state["cells"] as Array).size() == 1)
	assert(state["cells"][0]["color_id"] == "ocean_teal")
	assert(
		state["cells"][0]["author_fingerprint"]
		== session.get_local_identity_fingerprint()
	)
	assert(service.request_guide_visibility(canvas_id, false))
	state = service.get_canvas_state(canvas_id)
	assert(not bool(state["guide_visible"]))
	var canvas_nodes: Dictionary = service.get("_canvas_nodes")
	var canvas := canvas_nodes[canvas_id] as SurfaceDrawingCanvas
	assert(not canvas.is_guide_visible())
	assert(service.request_guide_visibility(canvas_id, true))
	assert(bool(service.get_canvas_state(canvas_id)["guide_visible"]))
	assert(service.request_guide_visibility(canvas_id, false, true))
	assert(bool(service.get_canvas_state(canvas_id)["finalized"]))
	assert(canvas.is_finalized())
	assert(service.request_canvas_at_surface(
		hit["position"], hit["normal"], Vector3.RIGHT
	))
	assert(service.get_canvas_ids().size() == 2)
	var replacement_canvas_id: String = ""
	for candidate_id: String in service.get_canvas_ids():
		if candidate_id != canvas_id:
			replacement_canvas_id = candidate_id
	assert(not replacement_canvas_id.is_empty())
	assert(service.request_cell_edits(replacement_canvas_id, [{
		"x": 8,
		"y": 8,
		"color_id": "blue",
	}]))
	assert((service.get_canvas_state(canvas_id)["cells"] as Array).is_empty())
	assert(
		str(service.get_canvas_state(replacement_canvas_id)["cells"][0]["color_id"])
		== "blue"
	)
	assert(service.request_undo_last_stroke())
	assert((service.get_canvas_state(replacement_canvas_id)["cells"] as Array).is_empty())
	assert(
		str(service.get_canvas_state(canvas_id)["cells"][0]["color_id"])
		== "ocean_teal"
	)
	var player_list := main.get_node(
		"%NetworkPlayerListService"
	) as NetworkPlayerListService
	assert(player_list.get_session_artwork_counts() == Vector2i(2, 1))
	assert(player_list.reset_session_artwork())
	assert(service.get_canvas_ids().is_empty())

	print("Surface drawing runtime validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	await process_frame
	quit()


func _validate_marker_controls(
	service: NetworkSurfaceDrawingService,
	player: Player,
) -> void:
	var prior_mouse_mode: Input.MouseMode = Input.mouse_mode
	service.activate()
	assert(service.is_active())
	assert(service.is_placement_mode())
	if DisplayServer.get_name() != "headless":
		assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)

	var placement_key := InputEventKey.new()
	placement_key.physical_keycode = KEY_R
	placement_key.pressed = true
	assert(service.handle_input(placement_key, true))
	assert(not service.is_placement_mode())

	var pointer_before: Vector2 = service.get_pointer_screen_position()
	var pointer_motion := InputEventMouseMotion.new()
	pointer_motion.position = pointer_before + Vector2(30.0, -12.0)
	assert(service.handle_input(pointer_motion, true))
	assert(service.get_pointer_screen_position() != pointer_before)
	var zoom_event := InputEventMouseButton.new()
	zoom_event.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom_event.shift_pressed = true
	zoom_event.pressed = true
	assert(not service.handle_input(zoom_event, true))
	var prior_zoom: float = float(player.get("_target_zoom"))
	player.call("_unhandled_input", zoom_event)
	assert(float(player.get("_target_zoom")) < prior_zoom)

	var camera_press := InputEventMouseButton.new()
	camera_press.button_index = MOUSE_BUTTON_RIGHT
	camera_press.pressed = true
	assert(not service.handle_input(camera_press, true))
	var pointer_before_camera: Vector2 = service.get_pointer_screen_position()
	assert(not service.handle_input(pointer_motion, true))
	assert(service.get_pointer_screen_position() == pointer_before_camera)
	var camera_release := InputEventMouseButton.new()
	camera_release.button_index = MOUSE_BUTTON_RIGHT
	camera_release.pressed = false
	assert(not service.handle_input(camera_release, true))

	assert(service.handle_input(placement_key, true))
	assert(service.is_placement_mode())
	service.deactivate()
	assert(Input.mouse_mode == prior_mouse_mode)
