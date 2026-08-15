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
	main.queue_free()
	for _frame: int in 4:
		await process_frame
	OS.unset_environment(
		RuntimePerformanceProfileType.PROFILE_ENVIRONMENT_VARIABLE
	)
	print("Light performance profile validation: PASS")
	quit()


func _validate_profile_resolution() -> void:
	var normal := RuntimePerformanceProfileType.from_name(&"normal")
	var light := RuntimePerformanceProfileType.from_name(&"light")
	var legacy := RuntimePerformanceProfileType.from_name(&"", true)
	assert(not normal.is_light())
	assert(is_equal_approx(normal.get_world_render_scale(), 1.0))
	assert(light.is_light())
	assert(is_equal_approx(light.get_world_render_scale(), 0.5))
	assert(legacy.is_light())


func _validate_main_profile(main: Node) -> void:
	var profile: RuntimePerformanceProfile = main.get("_performance_profile")
	assert(profile != null and profile.is_light())
	assert(is_equal_approx(root.scaling_3d_scale, 0.5))
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


func _validate_minimal_weather(main: Node) -> void:
	var visuals: WorldTimeVisualController = main.get_node(
		"%WorldTimeVisualController"
	)
	var rain := visuals.get_node("LocalRain") as GPUParticles3D
	assert(rain.amount == WorldTimeVisualController.LIGHT_RAIN_PARTICLE_AMOUNT)
	assert(rain.fixed_fps == WorldTimeVisualController.LIGHT_RAIN_FIXED_FPS)
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
