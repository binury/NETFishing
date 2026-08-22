extends SceneTree

const TestWorldScene: PackedScene = preload("res://world/test_world.tscn")
const SetupPageScene: PackedScene = preload(
	"res://ui/new_game_setup_page.tscn"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	_validate_layout_values()
	await _validate_setup_page()
	await _validate_world_switching()
	_validate_network_metadata()
	print("World layout validation: PASS")
	quit()


func _validate_layout_values() -> void:
	assert(WorldLayout.is_valid(WorldLayout.GENERATED))
	assert(WorldLayout.is_valid(String(WorldLayout.STARTER_ISLAND)))
	assert(not WorldLayout.is_valid(&"unknown"))
	assert(WorldLayout.normalized("unknown") == WorldLayout.GENERATED)
	assert(WorldLayout.display_name(WorldLayout.STARTER_ISLAND) == "starter island")


func _validate_setup_page() -> void:
	assert(NewGameSetupPage.parse_seed_text(" 24680 ") == 24680)
	assert(NewGameSetupPage.parse_seed_text("0") == 0)
	assert(NewGameSetupPage.parse_seed_text("2147483647") == 0)
	assert(NewGameSetupPage.parse_seed_text("") == 0)
	var text_seed: int = NewGameSetupPage.parse_seed_text("voyager island")
	assert(text_seed > 0 and text_seed <= PlayerSaveManager.MAX_WORLD_SEED)
	assert(NewGameSetupPage.parse_seed_text(" voyager island ") == text_seed)
	assert(NewGameSetupPage.parse_seed_text("voyager island") == text_seed)
	assert(NewGameSetupPage.parse_seed_text("Voyager Island") != text_seed)
	var page := SetupPageScene.instantiate() as NewGameSetupPage
	root.add_child(page)
	await process_frame
	page.open_page(true)
	await process_frame
	assert(page.visible)
	var paper := page.get_node("%Paper") as PanelContainer
	assert(paper.get_combined_minimum_size().x <= paper.size.x)
	assert(paper.get_combined_minimum_size().y <= paper.size.y)
	assert(page.get_selected_world_layout() == WorldLayout.GENERATED)
	assert(page.get_selected_world_seed() > 0)
	assert((page.get_node("%OverwriteWarning") as Label).visible)
	var generated_button := page.get_node("%GeneratedButton") as Button
	var starter_button := page.get_node("%StarterButton") as Button
	var random_button := page.get_node("%RandomSeedButton") as Button
	var custom_button := page.get_node("%CustomSeedButton") as Button
	var seed_edit := page.get_node("%SeedEdit") as LineEdit
	var start_button := page.get_node("%StartButton") as Button
	var back_button := page.get_node("%BackButton") as Button
	assert(generated_button.get_node(generated_button.focus_neighbor_right) == starter_button)
	assert(generated_button.get_node(generated_button.focus_neighbor_bottom) == random_button)
	assert(random_button.get_node(random_button.focus_neighbor_right) == custom_button)
	assert(start_button.get_node(start_button.focus_neighbor_right) == back_button)
	page.call("_choose_custom_seed")
	assert(seed_edit.editable)
	assert(custom_button.get_node(custom_button.focus_neighbor_bottom) == seed_edit)
	assert(seed_edit.get_node(seed_edit.focus_neighbor_bottom) == start_button)
	page.call("_set_world_layout", WorldLayout.STARTER_ISLAND)
	assert(not (page.get_node("%SeedSection") as Control).visible)
	var request: Dictionary = {}
	page.start_requested.connect(func(layout: StringName, seed: int) -> void:
		request["layout"] = layout
		request["seed"] = seed
	)
	page.call("_request_start")
	assert(request.get("layout") == WorldLayout.STARTER_ISLAND)
	assert(int(request.get("seed", 0)) > 0)
	page.queue_free()
	await process_frame


func _validate_world_switching() -> void:
	var world := TestWorldScene.instantiate() as TestWorld
	root.add_child(world)
	await process_frame
	assert(world.get_world_layout() == WorldLayout.GENERATED)
	assert(world.get_fishing_shop() != null)
	assert(world.get_player_storage() != null)
	_validate_world_boundary_clearance(world)
	assert(world.activate_world(WorldLayout.STARTER_ISLAND, 13579))
	assert(world.get_world_layout() == WorldLayout.STARTER_ISLAND)
	assert(world.get_generation_seed() == 13579)
	assert(world.get_node_or_null("Regions/StarterIslandRegion") != null)
	assert(world.get_node_or_null("Regions/GeneratedWorldRegion") == null)
	assert(world.get_fishing_shop() != null)
	assert(world.get_player_storage() != null)
	assert(not world.get_fishable_water_regions().is_empty())
	assert(world.activate_world(WorldLayout.GENERATED, 24680))
	assert(world.get_world_layout() == WorldLayout.GENERATED)
	assert(world.get_generation_seed() == 24680)
	assert(world.get_node_or_null("Regions/GeneratedWorldRegion") != null)
	assert(world.get_node_or_null("Regions/StarterIslandRegion") == null)
	world.queue_free()
	await process_frame


func _validate_world_boundary_clearance(world: TestWorld) -> void:
	var active_region := world.get("_active_region") as WorldRegion
	assert(active_region != null)
	var half := active_region.get_playable_half_extents()
	var north := world.get_node("WorldBounds/North") as StaticBody3D
	var south := world.get_node("WorldBounds/South") as StaticBody3D
	var west := world.get_node("WorldBounds/West") as StaticBody3D
	var east := world.get_node("WorldBounds/East") as StaticBody3D
	var fishing_defaults := FishingSpot.new()
	assert(
		TestWorld.WORLD_BOUNDARY_SHORELINE_CLEARANCE
		> fishing_defaults.maximum_cast_distance + 1.0
	)
	fishing_defaults.free()
	assert(north.position.z - half.y >= 18.0)
	assert(-south.position.z - half.y >= 18.0)
	assert(-west.position.x - half.x >= 18.0)
	assert(east.position.x - half.x >= 18.0)


func _validate_network_metadata() -> void:
	var hello: Dictionary = NetworkProtocol.make_server_hello(
		true,
		NetworkProtocol.RejectionCode.NONE,
		"session",
		2,
		1,
		16,
		"room",
		97531,
		WorldLayout.STARTER_ISLAND,
	)
	assert(str(hello.get("world_layout", "")) == String(
		WorldLayout.STARTER_ISLAND
	))
	assert(int(hello.get("world_seed", 0)) == 97531)
	assert(
		NetworkProtocol.WORLD_LAYOUT_CAPABILITY
		in PackedStringArray(hello.get("capability_flags", []))
	)
