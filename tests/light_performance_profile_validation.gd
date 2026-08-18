extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")
const RuntimePerformanceProfileType = preload(
	"res://main/runtime_performance_profile.gd"
)
const FOLIAGE_WIND_SHADER: Shader = preload(
	"res://world/materials/foliage_wind.gdshader"
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

	var pond := main.get_node(
		"TestWorld/Regions/StarterIslandRegion/WaterBodies/Pond/VisualWater"
	) as MeshInstance3D
	var ocean := main.get_node(
		"TestWorld/Regions/StarterIslandRegion/WaterBodies/Ocean/VisualWater"
	) as MeshInstance3D
	assert(pond.material_override is StandardMaterial3D)
	assert(ocean.material_override is StandardMaterial3D)
	assert(not pond.material_override is ShaderMaterial)
	assert(not ocean.material_override is ShaderMaterial)
	assert(not ocean.is_processing())
	_validate_ocean_fishing_coverage(main, ocean)
	var island := main.get_node(
		"TestWorld/Regions/StarterIslandRegion"
	) as StarterIslandRegion
	assert(island != null and not island.is_foliage_wind_enabled())
	assert(_count_foliage_wind_overrides(
		island.get_node("Terrain/Visual")
	) == 0)

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
	assert((main.get_node("%TitleMusic") as AudioStreamPlayer).stream == null)
	assert((main.get_node("%DuskMusic") as AudioStreamPlayer).stream == null)
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
	var pond := main.get_node(
		"TestWorld/Regions/StarterIslandRegion/WaterBodies/Pond/VisualWater"
	) as MeshInstance3D
	var ocean := main.get_node(
		"TestWorld/Regions/StarterIslandRegion/WaterBodies/Ocean/VisualWater"
	) as MeshInstance3D
	assert(pond.material_override is ShaderMaterial)
	assert(ocean.material_override is ShaderMaterial)
	assert(not ocean.is_processing())
	_validate_ocean_fishing_coverage(main, ocean)
	var island := main.get_node(
		"TestWorld/Regions/StarterIslandRegion"
	) as StarterIslandRegion
	assert(island != null and island.is_foliage_wind_enabled())
	assert(_count_foliage_wind_overrides(
		island.get_node("Terrain/Visual")
	) > 0)
	var game_ui := main.get_node("%GameUI") as GameUI
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
	assert((main.get_node("%TitleMusic") as AudioStreamPlayer).stream != null)
	assert((main.get_node("%DuskMusic") as AudioStreamPlayer).stream != null)
	assert(
		(main.get_node("%WavesAudio") as AudioStreamPlayer).stream != null
	)
	assert(
		(main.get_node("RainAmbience") as AudioStreamPlayer).stream != null
	)


func _validate_ocean_fishing_coverage(
	main: Node,
	ocean: MeshInstance3D,
) -> void:
	var ocean_mesh := ocean.mesh as PlaneMesh
	assert(ocean_mesh != null)
	var shape_node := main.get_node(
		"TestWorld/Regions/StarterIslandRegion/WaterBodies/Ocean/"
		+ "FishingRegions/OceanFishingRegion/Shape"
	) as CollisionShape3D
	assert(shape_node != null)
	var fishing_shape := shape_node.shape as BoxShape3D
	assert(fishing_shape != null)
	assert(fishing_shape.size.is_equal_approx(Vector3(
		ocean_mesh.size.x,
		2.0,
		ocean_mesh.size.y,
	)))


func _count_foliage_wind_overrides(root_node: Node) -> int:
	var count: int = 0
	var mesh_instance := root_node as MeshInstance3D
	if mesh_instance != null and mesh_instance.mesh != null:
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_surface_override_material(
				surface_index
			) as ShaderMaterial
			if material != null and material.shader == FOLIAGE_WIND_SHADER:
				count += 1
	for child: Node in root_node.get_children():
		count += _count_foliage_wind_overrides(child)
	return count


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
