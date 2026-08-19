extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")


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

	var save_manager := main.get("_save_manager") as PlayerSaveManager
	var player := main.get("_player") as Player
	assert(save_manager != null and player != null)
	const TEST_WORLD_SEED := 918273
	assert(save_manager.initialize_new_game(TEST_WORLD_SEED))
	save_manager.set_autosave_enabled(true)
	assert(player.bag.add_item(&"art_kit"))
	assert(player.bag.add_item(&"coffee"))
	assert(player.bag.move_item_to_storage_slot(&"basic_fishing_rod", 14))
	assert(player.bag.move_item_to_storage_slot(&"coffee", 12))
	assert(save_manager.save_now())

	var save_file := FileAccess.open(
		str(save_manager.get("_save_path")),
		FileAccess.READ,
	)
	assert(save_file != null)
	var parsed: Variant = JSON.parse_string(save_file.get_as_text())
	save_file.close()
	assert(typeof(parsed) == TYPE_DICTIONARY)
	var records: Array = (parsed as Dictionary)["bag"]["items"]
	assert(int((parsed as Dictionary)["world"]["seed"]) == TEST_WORLD_SEED)
	assert(_saved_slot(records, &"basic_fishing_rod") == 14)
	assert(_saved_slot(records, &"coffee") == 12)

	assert(player.bag.move_item_to_storage_slot(&"basic_fishing_rod", 0))
	assert(player.bag.move_item_to_storage_slot(&"coffee", 0))
	assert(save_manager.load_player_data())
	assert(save_manager.get_world_seed() == TEST_WORLD_SEED)
	assert(player.bag.get_storage_slot(&"basic_fishing_rod") == 14)
	assert(player.bag.get_storage_slot(&"coffee") == 12)

	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	print("Inventory storage persistence validation: PASS")
	quit()


func _saved_slot(records: Array, item_id: StringName) -> int:
	for value: Variant in records:
		if (
			typeof(value) == TYPE_DICTIONARY
			and str((value as Dictionary).get("item_id", ""))
			== String(item_id)
		):
			return int((value as Dictionary).get("storage_slot", -1))
	return -1
