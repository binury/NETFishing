extends SceneTree

const WorldWeatherServiceType = preload(
	"res://world/world_weather_service.gd"
)
const NetworkWorldWeatherServiceType = preload(
	"res://network/network_world_weather_service.gd"
)
const WorldTimeServiceType = preload("res://world/world_time_service.gd")
const WorldTimeVisualControllerType = preload(
	"res://world/world_time_visual_controller.gd"
)
const FishingContextType = preload("res://fishing/fishing_context.gd")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const FishAvailabilityType = preload("res://fish/fish_availability.gd")
const FishableWaterRegionType = preload(
	"res://world/fishable_water_region.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_weather_scheduler()
	_validate_authoritative_weather_override()
	_validate_weather_persistence()
	_validate_legacy_forecast_save_migration()
	_validate_snapshot_bounds()
	_validate_fishing_weather_seams()
	_validate_fishing_spot_context()
	_validate_weather_presentation()
	print("World weather validation: PASS")
	quit()


func _validate_weather_scheduler() -> void:
	var weather := WorldWeatherServiceType.new()
	root.add_child(weather)
	weather.begin_authoritative_session(20260802)
	assert(weather.get_weather() == WorldWeatherServiceType.Weather.SUNNY)
	assert(_duration_is_valid(weather))
	weather.advance_weather(weather.get_seconds_remaining() + 0.01)
	assert(weather.get_weather() == WorldWeatherServiceType.Weather.CLOUDY)
	assert(_duration_is_valid(weather))
	weather.advance_weather(weather.get_seconds_remaining() + 0.01)
	assert(weather.get_weather() in [
		WorldWeatherServiceType.Weather.SUNNY,
		WorldWeatherServiceType.Weather.RAINY,
		WorldWeatherServiceType.Weather.FOGGY,
	])
	assert(_duration_is_valid(weather))
	weather.apply_authoritative_snapshot(
		WorldWeatherServiceType.Weather.RAINY, 120.0
	)
	assert(weather.is_raining())
	assert(not weather.is_foggy())
	weather.apply_authoritative_snapshot(
		WorldWeatherServiceType.Weather.FOGGY, 120.0
	)
	assert(weather.is_foggy())
	assert(not weather.is_raining())
	weather.queue_free()


func _duration_is_valid(weather: WorldWeatherServiceType) -> bool:
	var seconds: float = weather.get_seconds_remaining()
	return is_equal_approx(
		seconds, WorldWeatherServiceType.WEATHER_PERIOD_SECONDS
	)


func _validate_authoritative_weather_override() -> void:
	var weather := WorldWeatherServiceType.new()
	root.add_child(weather)
	assert(not weather.set_authoritative_weather(
		WorldWeatherServiceType.Weather.FOGGY
	))
	weather.begin_authoritative_session(20260812)
	assert(weather.set_authoritative_weather(
		WorldWeatherServiceType.Weather.FOGGY
	))
	assert(weather.is_foggy())
	assert(_duration_is_valid(weather))
	weather.end_session()
	assert(not weather.set_authoritative_weather(
		WorldWeatherServiceType.Weather.RAINY
	))

	var clock := WorldTimeServiceType.new()
	root.add_child(clock)
	clock.begin_test_session(WorldTimeServiceType.DAY_START_HOUR)
	var schedule: Array[Dictionary] = []
	for index: int in WorldWeatherServiceType.DAILY_PLAN_SEGMENT_COUNT:
		schedule.append({
			"start_hour": fposmod(
				WorldTimeServiceType.DAY_START_HOUR
				+ float(index)
				* WorldWeatherServiceType.DAILY_PLAN_SEGMENT_HOURS,
				WorldTimeServiceType.HOURS_PER_DAY,
			),
			"weather": int(WorldWeatherServiceType.Weather.SUNNY),
		})
	assert(weather.configure_daily_plan("command-test", schedule, clock))
	weather.begin_authoritative_session(20260812)
	assert(weather.set_authoritative_weather(
		WorldWeatherServiceType.Weather.RAINY
	))
	weather.advance_weather(1.0)
	assert(weather.is_raining())
	clock.synchronize_time(
		WorldTimeServiceType.DAY_START_HOUR
		+ WorldWeatherServiceType.DAILY_PLAN_SEGMENT_HOURS
	)
	weather.advance_weather(0.01)
	assert(weather.get_weather() == WorldWeatherServiceType.Weather.SUNNY)
	weather.queue_free()
	clock.queue_free()


func _validate_weather_persistence() -> void:
	var weather := WorldWeatherServiceType.new()
	root.add_child(weather)
	weather.set_persistence_tracking_enabled(true)
	weather.begin_authoritative_session(20260802)
	weather.apply_authoritative_snapshot(
		WorldWeatherServiceType.Weather.RAINY,
		200.0,
	)
	weather.advance_weather(12.5)
	assert(weather.has_persistent_state())
	assert(
		weather.get_persistent_weather()
		== WorldWeatherServiceType.Weather.RAINY
	)
	assert(is_equal_approx(
		weather.get_persistent_seconds_remaining(),
		187.5,
	))
	weather.set_persistence_tracking_enabled(false)
	weather.begin_remote_session()
	weather.apply_authoritative_snapshot(
		WorldWeatherServiceType.Weather.FOGGY,
		45.0,
	)
	assert(weather.is_foggy())
	assert(
		weather.get_persistent_weather()
		== WorldWeatherServiceType.Weather.RAINY
	)
	assert(is_equal_approx(
		weather.get_persistent_seconds_remaining(),
		187.5,
	))
	weather.set_persistence_tracking_enabled(true)
	weather.begin_authoritative_session(20260803)
	assert(weather.get_weather() == WorldWeatherServiceType.DEFAULT_WEATHER)
	assert(is_equal_approx(
		weather.get_seconds_remaining(),
		WorldWeatherServiceType.WEATHER_PERIOD_SECONDS,
	))
	assert(not weather.restore_persistent_state(
		WorldWeatherServiceType.Weather.RAINY,
		WorldWeatherServiceType.MAX_PERSISTED_SECONDS + 1.0,
	))
	weather.queue_free()


func _validate_snapshot_bounds() -> void:
	assert(NetworkWorldWeatherServiceType.validate_snapshot({
		"session_id": "session",
		"weather": int(WorldWeatherServiceType.Weather.FOGGY),
		"seconds_remaining": 300.0,
		"sequence": 2,
	}))
	assert(not NetworkWorldWeatherServiceType.validate_snapshot({
		"session_id": "session",
		"weather": 99,
		"seconds_remaining": 300.0,
		"sequence": 2,
	}))
	assert(not NetworkWorldWeatherServiceType.validate_snapshot({
		"session_id": "session",
		"weather": int(WorldWeatherServiceType.Weather.RAINY),
		"seconds_remaining": 3601.0,
		"sequence": 2,
	}))


func _validate_legacy_forecast_save_migration() -> void:
	var legacy_schedule: Array[Dictionary] = []
	for index: int in JobCatalog.LEGACY_WEATHER_SEGMENT_COUNT:
		legacy_schedule.append({
			"start_hour": fposmod(
				WorldTimeService.DAY_START_HOUR
					+ float(index) * JobCatalog.LEGACY_WEATHER_SEGMENT_HOURS,
				WorldTimeService.HOURS_PER_DAY,
			),
			"weather": int(WorldWeatherService.Weather.SUNNY),
		})
	var legacy_job: Dictionary = {
		"id": "legacy-catch",
		"title": "legacy catch",
		"description": "catch one fish",
		"kind": int(JobCatalog.Kind.CATCH_TOTAL),
		"target": 1,
		"fish_coin": 1,
		"experience": 1,
	}
	var save_data: Dictionary = PlayerJobService.default_save_data()
	save_data["host_board"] = {
		"plan_id": "legacy-plan",
		"cycle": 4,
		"schedule_anchor_index": 0,
		"jobs": [legacy_job],
		"weather_schedule": legacy_schedule,
	}
	save_data["active_plan_id"] = "legacy-plan"
	assert(PlayerJobService.validate_save_data(save_data))
	var jobs := PlayerJobService.new()
	assert(jobs.restore_from_save_data(save_data))
	var migrated: Dictionary = jobs.to_save_data()
	assert((migrated.get("host_board", {}) as Dictionary).is_empty())
	assert(str(migrated.get("active_plan_id", "")).is_empty())
	jobs.free()


func _validate_fishing_weather_seams() -> void:
	var clear_context := FishingContextType.new()
	var rain_context := FishingContextType.new()
	rain_context.is_raining = true
	var fog_context := FishingContextType.new()
	fog_context.is_foggy = true
	fog_context.is_night = true
	var rain_only := FishAvailabilityType.new()
	rain_only.require_rain = true
	assert(not rain_only.is_available(clear_context))
	assert(rain_only.is_available(rain_context))
	var fog_only := FishAvailabilityType.new()
	fog_only.allow_day = false
	fog_only.require_fog = true
	assert(not fog_only.is_available(clear_context))
	assert(fog_only.is_available(fog_context))
	var no_fog := FishAvailabilityType.new()
	no_fog.forbid_fog = true
	assert(no_fog.is_available(clear_context))
	assert(not no_fog.is_available(fog_context))


func _validate_fishing_spot_context() -> void:
	var weather := WorldWeatherServiceType.new()
	weather.begin_remote_session()
	weather.apply_authoritative_snapshot(
		WorldWeatherServiceType.Weather.FOGGY, 200.0
	)
	var fishing_spot := FishingSpotType.new()
	fishing_spot.set("_world_weather", weather)
	var region := FishableWaterRegionType.new()
	region.location_tags = [&"starter_pond"]
	var context: FishingContext = fishing_spot.build_network_context(region)
	assert(context.is_foggy)
	assert(not context.is_raining)
	weather.apply_authoritative_snapshot(
		WorldWeatherServiceType.Weather.RAINY, 200.0
	)
	context = fishing_spot.build_network_context(region)
	assert(context.is_raining)
	assert(not context.is_foggy)
	region.free()
	fishing_spot.free()
	weather.free()


func _validate_weather_presentation() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	var sky := Sky.new()
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload(
		"res://world/environment/netfishing_sky.gdshader"
	)
	sky.sky_material = sky_material
	environment.sky = sky
	environment.adjustment_enabled = true
	environment.fog_enabled = true
	world_environment.environment = environment
	world_root.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	world_root.add_child(sun)
	var clock := WorldTimeServiceType.new()
	world_root.add_child(clock)
	clock.begin_test_session(14.0)
	var weather := WorldWeatherServiceType.new()
	world_root.add_child(weather)
	weather.begin_remote_session()
	var rain_target := Node3D.new()
	world_root.add_child(rain_target)
	var rain_camera := Camera3D.new()
	world_root.add_child(rain_camera)
	rain_target.global_position = Vector3(-18.0, 2.0, 14.0)
	rain_camera.global_position = Vector3(24.0, 9.0, -18.0)
	var visuals := WorldTimeVisualControllerType.new()
	world_root.add_child(visuals)
	visuals.setup(
		clock,
		world_environment,
		sun,
		weather,
		rain_target,
		func() -> Camera3D: return rain_camera,
	)
	var runtime_environment: Environment = world_environment.environment
	var runtime_sky_material := (
		runtime_environment.sky.sky_material as ShaderMaterial
	)
	clock.set_authoritative_time(0.0)
	visuals.apply_time_immediately(0.0)
	assert(float(
		runtime_sky_material.get_shader_parameter("star_visibility")
	) > 0.99)
	visuals.apply_weather_immediately(
		WorldWeatherServiceType.Weather.CLOUDY
	)
	assert(is_equal_approx(float(
		runtime_sky_material.get_shader_parameter("star_visibility")
	), 0.18))
	visuals.apply_weather_immediately(
		WorldWeatherServiceType.Weather.RAINY
	)
	assert(is_equal_approx(float(
		runtime_sky_material.get_shader_parameter("star_visibility")
	), 0.03))
	visuals.apply_weather_immediately(
		WorldWeatherServiceType.Weather.FOGGY
	)
	assert(is_zero_approx(float(
		runtime_sky_material.get_shader_parameter("star_visibility")
	)))
	visuals.apply_weather_immediately(
		WorldWeatherServiceType.Weather.SUNNY
	)
	clock.set_authoritative_time(14.0)
	visuals.apply_time_immediately(14.0)
	var clear_background_energy: float = (
		runtime_environment.background_energy_multiplier
	)
	var clear_ambient_energy: float = runtime_environment.ambient_light_energy
	var clear_fog_light_energy: float = runtime_environment.fog_light_energy
	var clear_brightness: float = runtime_environment.adjustment_brightness
	var clear_saturation: float = runtime_environment.adjustment_saturation
	var clear_sun_energy: float = sun.light_energy
	var clear_water_brightness: float = float(
		WorldTimeVisualControllerType.SALT_WATER_MATERIAL.get_shader_parameter(
			"environment_brightness"
		)
	)
	assert(not runtime_environment.fog_enabled)
	assert(is_zero_approx(float(
		WorldTimeVisualControllerType.SALT_WATER_MATERIAL.get_shader_parameter(
			"weather_fog_amount"
		)
	)))
	assert(is_equal_approx(runtime_environment.fog_sky_affect, 0.35))
	assert(is_zero_approx(float(
		runtime_sky_material.get_shader_parameter("cloud_opacity")
	)))
	var storm_clouds := visuals.get_node("LocalStormClouds") as Node3D
	assert(storm_clouds != null)
	assert(storm_clouds.call("get_patch_count") == 81)
	var cloud_field := storm_clouds.get_node("CloudField") as MultiMeshInstance3D
	assert(cloud_field != null)
	assert(cloud_field.multimesh != null)
	assert(cloud_field.multimesh.instance_count == 81)
	assert(cloud_field.multimesh.mesh is ArrayMesh)
	var cloud_shader: Shader = preload(
		"res://world/environment/local_storm_cloud.gdshader"
	)
	assert("cull_disabled" in cloud_shader.code)
	assert(LocalStormCloudLayer.WRAP_RADIUS >= 315.0)
	assert(is_equal_approx(LocalStormCloudLayer.MAXIMUM_OPACITY, 1.0))
	assert(
		LocalStormCloudLayer.DISTANCE_FADE_END
		< LocalStormCloudLayer.WRAP_RADIUS
	)
	assert(is_zero_approx(float(storm_clouds.call("get_storm_amount"))))
	visuals.apply_weather_immediately(
		WorldWeatherServiceType.Weather.FOGGY
	)
	assert(runtime_environment.fog_enabled)
	assert(float(
		WorldTimeVisualControllerType.SALT_WATER_MATERIAL.get_shader_parameter(
			"weather_fog_amount"
		)
	) > 0.99)
	assert(is_zero_approx(float(
		WorldTimeVisualControllerType.SALT_WATER_MATERIAL.get_shader_parameter(
			"weather_fog_near_amount"
		)
	)))
	var water_fog_color := (
		WorldTimeVisualControllerType.SALT_WATER_MATERIAL.get_shader_parameter(
			"weather_fog_color"
		) as Color
	)
	var rendered_fog_color := (
		runtime_environment.fog_light_color.srgb_to_linear()
	)
	rendered_fog_color.r *= runtime_environment.fog_light_energy
	rendered_fog_color.g *= runtime_environment.fog_light_energy
	rendered_fog_color.b *= runtime_environment.fog_light_energy
	rendered_fog_color.a = 1.0
	rendered_fog_color = rendered_fog_color.linear_to_srgb()
	assert(water_fog_color.is_equal_approx(rendered_fog_color))
	assert(is_equal_approx(float(
		WorldTimeVisualControllerType.SALT_WATER_MATERIAL.get_shader_parameter(
			"surface_highlight_night_floor"
		)
	), WorldTimeVisualControllerType.DEFAULT_SURFACE_HIGHLIGHT_FLOOR))
	assert(runtime_environment.fog_depth_begin <= 4.01)
	assert(is_equal_approx(runtime_environment.fog_depth_end, 18.0))
	assert(is_equal_approx(runtime_environment.fog_sky_affect, 1.0))
	assert(is_zero_approx(runtime_environment.fog_aerial_perspective))
	assert(is_zero_approx(float(
		runtime_sky_material.get_shader_parameter("cloud_opacity")
	)))
	assert(is_equal_approx(
		runtime_environment.background_energy_multiplier,
		clear_background_energy
		* WorldTimeVisualControllerType.FOG_DAYLIGHT_SCENE_BRIGHTNESS,
	))
	assert(is_equal_approx(
		runtime_environment.ambient_light_energy,
		clear_ambient_energy
		* WorldTimeVisualControllerType.FOG_DAYLIGHT_SCENE_BRIGHTNESS,
	))
	assert(is_equal_approx(
		runtime_environment.fog_light_energy,
		clear_fog_light_energy
		* WorldTimeVisualControllerType.FOG_DAYLIGHT_FOG_LIGHT_BRIGHTNESS,
	))
	assert(is_equal_approx(
		runtime_environment.adjustment_brightness,
		clear_brightness
		* WorldTimeVisualControllerType.FOG_DAYLIGHT_POST_BRIGHTNESS,
	))
	assert(is_equal_approx(sun.light_energy, clear_sun_energy * 0.30))
	assert(is_equal_approx(
		float(
			WorldTimeVisualControllerType.SALT_WATER_MATERIAL.get_shader_parameter(
				"environment_brightness"
			)
		),
		clear_water_brightness
		* WorldTimeVisualControllerType.FOG_DAYLIGHT_WATER_BRIGHTNESS,
	))
	assert(is_equal_approx(
		runtime_environment.adjustment_saturation,
		clear_saturation,
	))
	visuals.apply_weather_immediately(
		WorldWeatherServiceType.Weather.RAINY
	)
	assert(runtime_environment.fog_enabled)
	assert(float(
		WorldTimeVisualControllerType.SALT_WATER_MATERIAL.get_shader_parameter(
			"weather_fog_amount"
		)
	) > 0.99)
	assert(is_zero_approx(float(
		WorldTimeVisualControllerType.SALT_WATER_MATERIAL.get_shader_parameter(
			"weather_fog_near_amount"
		)
	)))
	var rainy_water_fog_color := (
		WorldTimeVisualControllerType.SALT_WATER_MATERIAL.get_shader_parameter(
			"weather_fog_color"
		) as Color
	)
	assert(
		rainy_water_fog_color.is_equal_approx(
			WorldTimeVisualControllerType.RAIN_WATER_FOG_COLOR
		)
	)
	assert(is_equal_approx(float(
		WorldTimeVisualControllerType.SALT_WATER_MATERIAL.get_shader_parameter(
			"surface_highlight_night_floor"
		)
	), WorldTimeVisualControllerType.DEFAULT_SURFACE_HIGHLIGHT_FLOOR))
	assert(is_equal_approx(runtime_environment.fog_sky_affect, 0.68))
	assert(
		float(runtime_sky_material.get_shader_parameter("cloud_coverage"))
		> 0.98
	)
	assert(
		float(runtime_sky_material.get_shader_parameter("cloud_opacity"))
		> 0.99
	)
	assert(float(storm_clouds.call("get_storm_amount")) > 0.87)
	assert(storm_clouds.visible)
	assert(is_equal_approx(
		runtime_environment.adjustment_brightness,
		clear_brightness
		* 0.92
		* WorldTimeVisualControllerType.RAIN_DAYLIGHT_POST_BRIGHTNESS,
	))
	var rain := visuals.get_node("LocalRain") as GPUParticles3D
	assert(rain != null)
	assert(rain.global_position.is_equal_approx(
		rain_camera.global_position
		+ WorldTimeVisualControllerType.RAIN_EMITTER_OFFSET
	))
	rain_camera.global_position = Vector3(-31.0, 15.0, 42.0)
	visuals.call("_update_rain_position")
	assert(rain.global_position.is_equal_approx(
		rain_camera.global_position
		+ WorldTimeVisualControllerType.RAIN_EMITTER_OFFSET
	))
	assert(rain.emitting)
	assert(rain.amount_ratio > 0.99)
	assert(rain.amount == WorldTimeVisualControllerType.RAIN_PARTICLE_AMOUNT)
	assert(rain.visibility_aabb == (
		WorldTimeVisualControllerType.RAIN_VISIBILITY_AABB
	))
	var rain_material := rain.process_material as ParticleProcessMaterial
	assert(rain_material != null)
	assert(rain_material.emission_box_extents.is_equal_approx(
		WorldTimeVisualControllerType.RAIN_EMISSION_EXTENTS
	))
	assert(is_equal_approx(
		rain_material.initial_velocity_min,
		WorldTimeVisualControllerType.RAIN_VELOCITY_MIN,
	))
	assert(is_equal_approx(
		rain_material.initial_velocity_max,
		WorldTimeVisualControllerType.RAIN_VELOCITY_MAX,
	))
	var rain_mesh := rain.draw_pass_1 as BoxMesh
	assert(rain_mesh != null)
	assert(rain_mesh.size.is_equal_approx(
		WorldTimeVisualControllerType.RAIN_DROP_SIZE
	))
	visuals.call(
		"_on_weather_changed",
		WorldWeatherServiceType.Weather.SUNNY,
		60.0,
	)
	visuals.call(
		"_process",
		WorldTimeVisualControllerType.WEATHER_TRANSITION_SECONDS * 0.5,
	)
	var halfway_water_fog: float = float(
		WorldTimeVisualControllerType.SALT_WATER_MATERIAL.get_shader_parameter(
			"weather_fog_amount"
		)
	)
	assert(halfway_water_fog > 0.49 and halfway_water_fog < 0.51)
	assert(is_equal_approx(
		float(
			WorldTimeVisualControllerType.FRESH_WATER_MATERIAL.get_shader_parameter(
				"weather_fog_amount"
			)
		),
		halfway_water_fog,
	))
	assert(runtime_environment.fog_enabled)
	visuals.call(
		"_process",
		WorldTimeVisualControllerType.WEATHER_TRANSITION_SECONDS * 0.5,
	)
	assert(is_zero_approx(float(
		WorldTimeVisualControllerType.SALT_WATER_MATERIAL.get_shader_parameter(
			"weather_fog_amount"
		)
	)))
	assert(not runtime_environment.fog_enabled)
	visuals.apply_weather_immediately(
		WorldWeatherServiceType.Weather.CLOUDY
	)
	assert(not runtime_environment.fog_enabled)
	assert(is_zero_approx(float(
		WorldTimeVisualControllerType.SALT_WATER_MATERIAL.get_shader_parameter(
			"weather_fog_amount"
		)
	)))
	visuals.apply_weather_immediately(
		WorldWeatherServiceType.Weather.SUNNY
	)
	assert(not runtime_environment.fog_enabled)
	assert(not rain.emitting)
	world_root.queue_free()
