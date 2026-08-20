extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const RuntimePerformanceProfileType = preload(
	"res://main/runtime_performance_profile.gd"
)
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_profile_resolution()
	OS.set_environment(
		RuntimePerformanceProfileType.PROFILE_ENVIRONMENT_VARIABLE,
		"light",
	)
	root.size = Vector2i(640, 480)
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	for _frame: int in 4:
		await process_frame
	if not bool(main.get("_application_initialized")):
		main.call("_activate_selected_data_path", "", true)
	for _frame: int in 8:
		await process_frame
	assert(bool(main.get("_application_initialized")))
	_validate_main_profile(main)
	_validate_minimal_weather(main)
	_stop_audio_players(main)
	main.queue_free()
	for _frame: int in 8:
		await process_frame
	OS.unset_environment(
		RuntimePerformanceProfileType.PROFILE_ENVIRONMENT_VARIABLE
	)
	var normal_main: Node = MainScene.instantiate()
	root.add_child(normal_main)
	for _frame: int in 4:
		await process_frame
	if not bool(normal_main.get("_application_initialized")):
		normal_main.call("_activate_selected_data_path", "", true)
	for _frame: int in 8:
		await process_frame
	assert(bool(normal_main.get("_application_initialized")))
	_validate_normal_profile(normal_main)
	_validate_new_game_music_transition(normal_main)
	_stop_audio_players(normal_main)
	normal_main.queue_free()
	for _frame: int in 8:
		await process_frame
	print("Light performance profile validation: PASS")
	quit()


func _validate_profile_resolution() -> void:
	var normal := RuntimePerformanceProfileType.from_name(&"normal")
	var light := RuntimePerformanceProfileType.from_name(&"light")
	var legacy := RuntimePerformanceProfileType.from_name(&"", true)
	assert(not normal.is_light())
	assert(is_equal_approx(normal.get_world_render_scale(), 1.0))
	assert(light.is_light())
	assert(is_equal_approx(light.get_world_render_scale(), 0.375))
	assert(legacy.is_light())


func _validate_main_profile(main: Node) -> void:
	var profile: RuntimePerformanceProfile = main.get("_performance_profile")
	assert(profile != null and profile.is_light())
	assert(is_equal_approx(root.scaling_3d_scale, 0.375))
	var pixelation: Node = main.get_node("%WorldPixelationPostprocess")
	assert(bool(pixelation.call("is_light_performance_profile")))
	pixelation.call("set_gameplay_active", true)
	var screen_grid := pixelation.get_node("ScreenGrid") as ColorRect
	assert(screen_grid != null and not screen_grid.visible)

	var pond := _first_fresh_water_visual(main)
	var ocean := main.get_node(
		"TestWorld/Regions/GeneratedWorldRegion/WaterBodies/OceanWater/VisualWater"
	) as MeshInstance3D
	assert(not pond.visible)
	assert(ocean.material_override is StandardMaterial3D)
	assert(not ocean.material_override is ShaderMaterial)
	_validate_ocean_fishing_coverage(main, ocean)
	var region := main.get_node(
		"TestWorld/Regions/GeneratedWorldRegion"
	) as GeneratedWorldRegion
	assert(region != null)
	assert(region.get_node("Decorations").get_child_count() > 0)

	var title_background := main.get_node("%TitleBackground") as ColorRect
	var title_material := title_background.material as ShaderMaterial
	assert(title_material != null)
	assert(not bool(title_material.get_shader_parameter(
		"animation_enabled"
	)))
	for backdrop_name: StringName in [
		&"PlayerMenuBackdrop",
		&"ShopBackdrop",
	]:
		var backdrop := main.get_node("%%%s" % backdrop_name) as ColorRect
		var backdrop_material := backdrop.material as ShaderMaterial
		assert(backdrop_material != null)
		assert(not bool(backdrop_material.get_shader_parameter(
			"animation_enabled"
		)))
		assert(
			backdrop_material.get_shader_parameter(
				"scroll_velocity_pixels"
			) == Vector2.ZERO
		)
	var game_ui := main.get_node("%GameUI") as GameUI
	var title_screen := game_ui.get_title_screen()
	assert(title_screen != null)
	assert(not title_screen.is_decorative_presentation_active())
	var player_menu := game_ui.get("_player_menu") as PlayerMenu
	assert(player_menu != null)
	assert(not player_menu.is_cooler_water_effect_enabled())
	assert((main.get_node("%TitleMusic") as AudioStreamPlayer).stream != null)
	assert((main.get_node("%NewGameMusic") as AudioStreamPlayer).stream != null)
	assert((main.get_node("%DuskMusic") as AudioStreamPlayer).stream != null)
	assert(
		(main.get_node("%WavesAudio") as AudioStreamPlayer).stream == null
	)
	assert(
		(main.get_node("RainAmbience") as AudioStreamPlayer).stream == null
	)


func _validate_normal_profile(main: Node) -> void:
	var profile: RuntimePerformanceProfile = main.get("_performance_profile")
	assert(profile != null and not profile.is_light())
	assert(is_equal_approx(root.scaling_3d_scale, 1.0))
	var pixelation: Node = main.get_node("%WorldPixelationPostprocess")
	assert(not bool(pixelation.call("is_light_performance_profile")))
	var pond := _first_fresh_water_visual(main)
	var ocean := main.get_node(
		"TestWorld/Regions/GeneratedWorldRegion/WaterBodies/OceanWater/VisualWater"
	) as MeshInstance3D
	assert(not pond.visible)
	assert(ocean.material_override is ShaderMaterial)
	_validate_ocean_fishing_coverage(main, ocean)
	var region := main.get_node(
		"TestWorld/Regions/GeneratedWorldRegion"
	) as GeneratedWorldRegion
	assert(region != null)
	assert(region.get_node("Decorations").get_child_count() > 0)
	var game_ui := main.get_node("%GameUI") as GameUI
	var title_screen := game_ui.get_title_screen()
	assert(title_screen != null)
	assert(title_screen.is_decorative_presentation_active())
	assert(title_screen.is_decorative_bubble_scheduler_active())
	var player_menu := game_ui.get("_player_menu") as PlayerMenu
	assert(player_menu != null)
	assert(player_menu.is_cooler_water_effect_enabled())

	var title_background := main.get_node("%TitleBackground") as ColorRect
	var title_material := title_background.material as ShaderMaterial
	assert(title_material != null)
	assert(bool(title_material.get_shader_parameter("animation_enabled")))
	for backdrop_name: StringName in [
		&"PlayerMenuBackdrop",
		&"ShopBackdrop",
	]:
		var backdrop := main.get_node("%%%s" % backdrop_name) as ColorRect
		var backdrop_material := backdrop.material as ShaderMaterial
		assert(backdrop_material != null)
		assert(bool(backdrop_material.get_shader_parameter(
			"animation_enabled"
		)))
		assert(
			backdrop_material.get_shader_parameter(
				"scroll_velocity_pixels"
			) != Vector2.ZERO
		)
	var visuals: WorldTimeVisualController = main.get_node(
		"%WorldTimeVisualController"
	)
	var rain := visuals.get_node("LocalRain") as GPUParticles3D
	assert(rain.amount == WorldTimeVisualController.RAIN_PARTICLE_AMOUNT)
	assert(rain.fixed_fps == 30)
	var clouds := visuals.get_node(
		"LocalStormClouds"
	) as LocalStormCloudLayer
	assert(clouds.get_patch_count() == 81)
	assert(clouds.get_node_or_null("CloudField") is MultiMeshInstance3D)
	assert(clouds.get_node_or_null("CloudCeiling") == null)
	assert((main.get_node("%TitleMusic") as AudioStreamPlayer).stream != null)
	assert((main.get_node("%NewGameMusic") as AudioStreamPlayer).stream != null)
	assert((main.get_node("%DuskMusic") as AudioStreamPlayer).stream != null)
	assert(
		(main.get_node("%WavesAudio") as AudioStreamPlayer).stream != null
	)
	assert(
		(main.get_node("RainAmbience") as AudioStreamPlayer).stream != null
	)


func _validate_new_game_music_transition(main: Node) -> void:
	var title_music := main.get_node("%TitleMusic") as AudioStreamPlayer
	var new_game_music := main.get_node("%NewGameMusic") as AudioStreamPlayer
	assert(title_music.playing)
	main.call("_start_new_game_music")
	assert(not title_music.playing)
	assert(new_game_music.playing)
	main.call("_show_title_music", true)
	assert(not new_game_music.playing)
	assert(title_music.playing)


func _first_fresh_water_visual(main: Node) -> MeshInstance3D:
	var root := main.get_node(
		"TestWorld/Regions/GeneratedWorldRegion/WaterBodies/FreshWaterBodies"
	) as Node3D
	assert(root != null and root.get_child_count() > 0)
	return root.get_child(0).get_node("VisualWater") as MeshInstance3D


func _validate_ocean_fishing_coverage(
	main: Node,
	ocean: MeshInstance3D,
) -> void:
	var ocean_mesh := ocean.mesh as PlaneMesh
	assert(ocean_mesh != null)
	var shape_node := main.get_node(
		"TestWorld/Regions/GeneratedWorldRegion/WaterBodies/OceanWater/"
		+ "FishingRegion/Shape"
	) as CollisionShape3D
	assert(shape_node != null)
	var fishing_shape := shape_node.shape as BoxShape3D
	assert(fishing_shape != null)
	assert(fishing_shape.size.is_equal_approx(Vector3(
		ocean_mesh.size.x,
		4.0,
		ocean_mesh.size.y,
	)))


func _stop_audio_players(root_node: Node) -> void:
	if root_node is AudioStreamPlayer:
		(root_node as AudioStreamPlayer).stop()
	elif root_node is AudioStreamPlayer2D:
		(root_node as AudioStreamPlayer2D).stop()
	elif root_node is AudioStreamPlayer3D:
		(root_node as AudioStreamPlayer3D).stop()
	for child: Node in root_node.get_children():
		_stop_audio_players(child)


func _validate_minimal_weather(main: Node) -> void:
	var visuals: WorldTimeVisualController = main.get_node(
		"%WorldTimeVisualController"
	)
	var rain := visuals.get_node("LocalRain") as GPUParticles3D
	assert(rain.amount == WorldTimeVisualController.LIGHT_RAIN_PARTICLE_AMOUNT)
	assert(rain.fixed_fps == WorldTimeVisualController.LIGHT_RAIN_FIXED_FPS)
	assert(rain.amount == 48)
	assert(rain.fixed_fps == 8)
	var clouds := visuals.get_node("LocalStormClouds") as LocalStormCloudLayer
	assert(clouds.get_patch_count() == 1)
	var ceiling := clouds.get_node("CloudCeiling") as MeshInstance3D
	assert(ceiling != null and ceiling.mesh is PlaneMesh)
	assert(ceiling.material_override == null)
	assert((ceiling.mesh as PlaneMesh).material is StandardMaterial3D)

	visuals.apply_weather_immediately(WorldWeatherService.Weather.RAINY)
	assert(rain.emitting and rain.amount_ratio > 0.99)
	assert(clouds.visible and clouds.get_storm_amount() > 0.87)
	var cloud_material := (
		(ceiling.mesh as PlaneMesh).material as StandardMaterial3D
	)
	assert(cloud_material.albedo_color.a < 0.65)
	var test_world := main.get_node("TestWorld") as TestWorld
	var runtime_environment := (
		test_world.get_world_environment().environment as Environment
	)
	var sky_material := (
		runtime_environment.sky.sky_material as ShaderMaterial
	)
	assert(is_zero_approx(float(
		sky_material.get_shader_parameter("cloud_coverage")
	)))
	assert(is_zero_approx(float(
		sky_material.get_shader_parameter("cloud_opacity")
	)))
