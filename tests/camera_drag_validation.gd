extends SceneTree

const PlayerScene: PackedScene = preload("res://player/player.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var player := PlayerScene.instantiate() as Player
	root.add_child(player)
	await process_frame
	player.local_control_enabled = true
	player.set_camera_input_enabled(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.button_mask = MOUSE_BUTTON_MASK_RIGHT
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	assert(bool(player.get("_camera_dragging")))
	if DisplayServer.get_name() != "headless":
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

	var yaw := player.get_node("%CameraYaw") as Node3D
	var previous_yaw: float = yaw.rotation.y
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	motion.relative = Vector2(18.0, -4.0)
	motion.screen_relative = motion.relative
	Input.parse_input_event(motion)
	await process_frame
	assert(not is_equal_approx(yaw.rotation.y, previous_yaw))
	assert(bool(player.get("_camera_dragging")))
	if DisplayServer.get_name() != "headless":
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame
	assert(not bool(player.get("_camera_dragging")))
	if DisplayServer.get_name() != "headless":
		assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)

	Input.parse_input_event(press)
	await process_frame
	assert(bool(player.get("_camera_dragging")))
	player.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not bool(player.get("_camera_dragging")))

	player.queue_free()
	await process_frame
	print("Camera drag validation: PASS")
	quit()
