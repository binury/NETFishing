extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const ItemCatalogResource: ItemCatalog = preload(
	"res://items/catalog/item_catalog.tres"
)


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
	assert(player.bag.add_item(&"worms"))
	assert(player.bag.add_item(&"the_standby"))
	assert(player.equip_bait(ItemCatalogResource.get_item_by_id(&"worms")))
	assert(player.equip_lure(ItemCatalogResource.get_item_by_id(&"the_standby")))
	assert(player.bag.move_item_to_storage_slot(&"basic_fishing_rod", 14))
	assert(player.bag.move_item_to_storage_slot(&"coffee", 12))
	assert(save_manager.save_now())

	var decoded: Dictionary = ProgressionSaveCodec.read_local_save(
		str(save_manager.get("_save_path"))
	)
	assert(bool(decoded.get("ok", false)))
	var parsed: Dictionary = decoded["data"]
	var records: Array = parsed["bag"]["items"]
	assert(int(parsed["world"]["seed"]) == TEST_WORLD_SEED)
	assert(_saved_slot(records, &"basic_fishing_rod") == 14)
	assert(_saved_slot(records, &"coffee") == 12)

	assert(player.bag.move_item_to_storage_slot(&"basic_fishing_rod", 0))
	assert(player.bag.move_item_to_storage_slot(&"coffee", 0))
	player.unequip_bait()
	player.unequip_lure()
	assert(save_manager.load_player_data())
	assert(save_manager.get_world_seed() == TEST_WORLD_SEED)
	assert(player.bag.get_storage_slot(&"basic_fishing_rod") == 14)
	assert(player.bag.get_storage_slot(&"coffee") == 12)
	assert(player.active_bait_id == &"worms")
	assert(player.active_lure_id == &"the_standby")

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
