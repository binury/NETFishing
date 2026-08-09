extends SceneTree

const MainScene = preload("res://main/main.tscn")
const FishCatchType = preload("res://fish/fish_catch.gd")
const TEST_PORT: int = 17978


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
	push_error("Fish showcase multiplayer validation needs host or client mode.")
	quit(1)


func _run_host() -> void:
	var main: Node = await _create_initialized_main()
	var session := main.get_node("%NetworkSession") as NetworkSession
	assert(session.start_private_host(TEST_PORT))
	var save_manager := main.get("_save_manager") as PlayerSaveManager
	assert(save_manager.initialize_new_game())
	main.call("_enter_gameplay")
	var player := main.get("_player") as Player
	var service := main.get_node(
		"%NetworkFishShowcaseService"
	) as NetworkFishShowcaseService
	var fish_catch: FishCatch = _add_bluegill(main, player)
	assert(player.hotbar.assign_fish(1, fish_catch.catch_id))
	assert(player.hotbar.select_slot(1))
	assert(service.toggle_selected_fish())
	assert(service.is_local_showcase_visible())
	assert(session.set_host_open(true))

	var remote_peer_id: int = 0
	var join_deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < join_deadline and remote_peer_id == 0:
		await process_frame
		for peer_id: int in session.get_authenticated_peer_ids():
			if peer_id != session.get_local_peer_id():
				remote_peer_id = peer_id
				break
	assert(remote_peer_id > 1)
	var spawn_service := main.get_node(
		"%PlayerSpawnService"
	) as PlayerSpawnService
	var remote_avatar: Player = spawn_service.get_avatar(remote_peer_id)
	assert(remote_avatar != null)
	var remote_display := remote_avatar.get("_held_fish_display") as Node3D
	var visible_deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < visible_deadline and not remote_display.visible:
		await process_frame
	assert(remote_display.visible)
	var hidden_deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < hidden_deadline and remote_display.visible:
		await process_frame
	assert(not remote_display.visible)
	service.toggle_selected_fish()
	print("Fish showcase multiplayer host validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	await process_frame
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
	assert(
		session.supports_server_capability(
			NetworkFishShowcaseProtocol.CAPABILITY
		)
	)
	var spawn_service := main.get_node(
		"%PlayerSpawnService"
	) as PlayerSpawnService
	var host_avatar: Player = spawn_service.get_avatar(1)
	assert(host_avatar != null)
	var host_display := host_avatar.get("_held_fish_display") as Node3D
	var snapshot_deadline: int = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < snapshot_deadline and not host_display.visible:
		await process_frame
	assert(host_display.visible)

	var player := main.get("_player") as Player
	var animation_player := player.get_node(
		"Visuals/CharacterRig/AnimationPlayer"
	) as AnimationPlayer
	for animation_name: StringName in [
		&"pocket_idle_idle",
		&"pocket_idle_show",
		&"pocket_show_show",
		&"pocket_show_idle",
	]:
		assert(animation_player.has_animation(animation_name))
	var service := main.get_node(
		"%NetworkFishShowcaseService"
	) as NetworkFishShowcaseService
	var fish_catch: FishCatch = _add_bluegill(main, player)
	assert(player.hotbar.assign_fish(1, fish_catch.catch_id))
	assert(player.hotbar.select_slot(1))
	assert(service.toggle_selected_fish())
	assert((player.get("_held_fish_display") as Node3D).visible)
	await create_timer(2.0).timeout
	assert(service.toggle_selected_fish())
	var held_display := player.get("_held_fish_display") as Node3D
	assert(held_display.visible)
	assert(animation_player.current_animation == &"pocket_show_idle")
	var pocket_deadline: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < pocket_deadline and held_display.visible:
		await process_frame
	assert(not held_display.visible)
	print("Fish showcase multiplayer client validation: PASS")
	session.disconnect_session("")
	main.queue_free()
	await process_frame
	quit()


func _add_bluegill(main: Node, player: Player) -> FishCatch:
	var catalog := main.get("fish_catalog") as FishPool
	var fish: FishData = catalog.get_fish_by_id(&"bluegill")
	var fish_catch := FishCatchType.new()
	fish_catch.fish = fish
	fish_catch.fish_id = fish.id
	fish_catch.weight_lb = fish.get_minimum_weight()
	fish_catch.display_scale = fish.get_display_scale_for_weight(
		fish_catch.weight_lb
	)
	fish_catch.sale_value = fish.get_sale_value_for_weight(
		fish_catch.weight_lb
	)
	fish_catch.ensure_identity()
	player.inventory.add_catch(fish_catch)
	return fish_catch


func _create_initialized_main() -> Node:
	root.size = Vector2i(1280, 720)
	var main := MainScene.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame
	if not bool(main.get("_application_initialized")):
		main.call("_activate_selected_data_path", "", true)
	for _frame: int in 8:
		await process_frame
	assert(bool(main.get("_application_initialized")))
	return main
