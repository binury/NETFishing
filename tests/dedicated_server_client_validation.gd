extends SceneTree

const MainScene = preload("res://main/main.tscn")
const TEST_ENDPOINT: String = "127.0.0.1:7777"
const EXPECTED_SERVER_NAME: String = "Dedicated-Client-Test"


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
	main.call("_on_title_join_game_requested", TEST_ENDPOINT)
	var session := main.get_node("%NetworkSession") as NetworkSession
	var joined: bool = false
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if session.state == NetworkSession.State.VERIFYING_SERVER_IDENTITY:
			main.call("_confirm_server_trust")
		if session.is_joined_client() and bool(main.get("_gameplay_started")):
			joined = true
			break
	assert(joined)
	assert(session.get_local_peer_id() > 1)
	assert(session.get_player_count() == 1)
	var metadata: Dictionary = session.get_last_server_metadata()
	assert(str(metadata.get("server_display_name", "")) == EXPECTED_SERVER_NAME)
	var spawn_service := main.get_node(
		"%PlayerSpawnService"
	) as PlayerSpawnService
	assert(spawn_service.get_avatar(1) == null)
	assert(spawn_service.get_avatar(session.get_local_peer_id()) != null)
	print("DEDICATED_SERVER_CLIENT_VALIDATION_OK")
	session.disconnect_session("Dedicated client validation complete.")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	quit()
