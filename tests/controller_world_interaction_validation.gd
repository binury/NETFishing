extends SceneTree

const MainScene = preload("res://main/main.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main := MainScene.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame
	if not bool(main.get("_application_initialized")):
		main.call("_activate_selected_data_path", "", true)
	for _frame: int in 8:
		await process_frame
	_expect(
		bool(main.get("_application_initialized")),
		"application initialization failed",
	)
	_expect(
		bool(main.call("_prepare_private_host")),
		"private host preparation failed",
	)
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	_expect(
		save_manager != null and save_manager.initialize_new_game(),
		"new-game initialization failed",
	)
	main.call("_enter_gameplay")
	for _frame: int in 8:
		await process_frame

	var player := main.get("_player") as Player
	var interaction := main.get("_shop_interaction") as FishingShopInteraction
	var game_ui := main.get("_game_ui") as GameUI
	var chat_service := main.get_node(
		"%NetworkChatService"
	) as NetworkChatService
	_expect(player != null, "local player is unavailable")
	_expect(interaction != null, "shop interaction is unavailable")
	_expect(game_ui != null, "game UI is unavailable")
	_expect(chat_service != null, "network chat service is unavailable")
	if (
		player != null
		and interaction != null
		and game_ui != null
		and chat_service != null
	):
		player.global_position = interaction.global_position
		for _frame: int in 6:
			await physics_frame
		_expect(
			interaction.is_local_player_in_range(),
			"local player did not enter the shop interaction range",
		)
		var character_calls: Array[String] = []
		var capture_call := func(
			_peer_id: int,
			call_id: String,
			_pitch_scale: float,
		) -> void:
			character_calls.append(call_id)
		chat_service.character_call_received.connect(capture_call)
		var press := InputEventJoypadButton.new()
		press.device = 0
		press.button_index = JOY_BUTTON_Y
		press.pressed = true
		_expect(
			press.is_action_pressed("interact"),
			"Y does not resolve to interact",
		)
		_expect(
			press.is_action_pressed("character_call"),
			"Y does not resolve to character call",
		)
		game_ui.call("_input", press)
		main.call("_unhandled_input", press)
		await process_frame
		_expect(
			game_ui.get_fishing_shop().visible,
			"Y did not open the shop while the player was in range",
		)
		_expect(
			character_calls.is_empty(),
			"Y played a character call instead of opening the shop",
		)
		player.global_position = interaction.global_position + Vector3(20.0, 0.0, 0.0)
		for _frame: int in 6:
			await physics_frame
		for _frame: int in 60:
			if not game_ui.get_fishing_shop().visible:
				break
			await process_frame
		_expect(
			not interaction.is_local_player_in_range(),
			"local player did not leave the shop interaction range",
		)
		_expect(
			not game_ui.get_fishing_shop().visible,
			"shop did not close after leaving its interaction range",
		)
		game_ui.call("_input", press)
		await process_frame
		_expect(
			character_calls.size() == 1,
			"Y did not play a character call away from an interaction",
		)
		chat_service.character_call_received.disconnect(capture_call)

	var session := main.get_node("%NetworkSession") as NetworkSession
	if session != null:
		session.disconnect_session("Controller interaction validation complete.")
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	if _failures.is_empty():
		print("Controller world interaction validation: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
