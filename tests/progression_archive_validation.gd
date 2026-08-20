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
	var data_root := main.get("_data_root") as PlayerDataRoot
	assert(save_manager != null and player != null and data_root != null)
	assert(save_manager.initialize_new_game(864209))
	save_manager.set_autosave_enabled(true)
	assert(player.wallet.restore_balance(4321))
	assert(player.bag.add_item(&"coffee"))
	assert(save_manager.save_now())

	var save_path: String = str(save_manager.get("_save_path"))
	assert(save_path.ends_with("player/player_save.nfsave"))
	assert(FileAccess.file_exists(save_path))
	assert(not FileAccess.file_exists(save_path.get_base_dir().path_join(
		"player_save.json"
	)))
	_assert_opaque(save_path)
	var decoded: Dictionary = ProgressionSaveCodec.read_local_save(save_path)
	assert(bool(decoded.get("ok", false)))
	assert(int((decoded["data"] as Dictionary)["save_version"]) == 10)

	var archive_path: String = data_root.progression_backup_directory().path_join(
		"progression-test.nfsave"
	)
	var exported: Dictionary = save_manager.export_progression_archive(
		archive_path
	)
	assert(bool(exported.get("ok", false)))
	assert(FileAccess.file_exists(archive_path))
	_assert_opaque(archive_path)
	var inspected: Dictionary = save_manager.inspect_progression_archive(
		archive_path
	)
	assert(bool(inspected.get("ok", false)))
	assert(int(inspected.get("wallet_balance", -1)) == 4321)
	assert(int(inspected.get("world_seed", -1)) == 864209)

	assert(player.wallet.restore_balance(7))
	assert(save_manager.save_now())
	var imported: Dictionary = save_manager.import_progression_archive(
		archive_path
	)
	assert(bool(imported.get("ok", false)))
	assert(save_manager.load_player_data())
	assert(player.wallet.get_balance() == 4321)
	assert(save_manager.get_world_seed() == 864209)

	var legacy_data: Dictionary = (
		ProgressionSaveCodec.read_local_save(save_path)["data"]
	)
	assert(save_manager.delete_progression_save())
	var legacy_path: String = save_path.get_base_dir().path_join(
		"player_save.json"
	)
	var legacy_file := FileAccess.open(legacy_path, FileAccess.WRITE)
	assert(legacy_file != null)
	legacy_file.store_string(JSON.stringify(legacy_data, "\t"))
	legacy_file.close()
	assert(save_manager.load_player_data())
	assert(FileAccess.file_exists(save_path))
	assert(not FileAccess.file_exists(legacy_path))
	_assert_opaque(save_path)

	var settings_panels: Array[Node] = main.find_children(
		"*", "SettingsPanel", true, false
	)
	assert(settings_panels.size() == 2)
	for settings_panel: SettingsPanel in settings_panels:
		var export_button := settings_panel.get_node(
			"%ExportProgression"
		) as Button
		var import_button := settings_panel.get_node(
			"%ImportProgression"
		) as Button
		assert(export_button != null and import_button != null)
		assert(not export_button.disabled and not import_button.disabled)
		assert(
			export_button.get_node(export_button.focus_neighbor_right)
			== import_button
		)
		assert(
			import_button.get_node(import_button.focus_neighbor_left)
			== export_button
		)

	var migrated_root: String = data_root.root_path.get_base_dir().path_join(
		"progression-migrated-data"
	)
	var data_migration: Dictionary = PortableDataMigration.migrate_active_to(
		data_root, migrated_root
	)
	assert(bool(data_migration.get("ok", false)))
	var migrated_save: String = migrated_root.path_join(
		"player/player_save.nfsave"
	)
	assert(FileAccess.file_exists(migrated_save))
	assert(bool(
		ProgressionSaveCodec.read_local_save(migrated_save).get("ok", false)
	))

	main.queue_free()
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	print("Progression archive validation: PASS")
	quit()


func _assert_opaque(path: String) -> void:
	var bytes: PackedByteArray = PortableFileGuard.read_bytes(path)
	assert(not bytes.is_empty())
	var encoded_hex: String = bytes.hex_encode()
	assert("save_version".to_utf8_buffer().hex_encode() not in encoded_hex)
	assert("wallet".to_utf8_buffer().hex_encode() not in encoded_hex)
