extends SceneTree

const WorldTimeServiceType = preload("res://world/world_time_service.gd")
const WorldTimeVisualControllerType = preload(
	"res://world/world_time_visual_controller.gd"
)
const NetworkWorldTimeServiceType = preload(
	"res://network/network_world_time_service.gd"
)
const FishingContextType = preload("res://fishing/fishing_context.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishPoolType = preload("res://fish/fish_pool.gd")
const FishingSpotType = preload("res://fishing/fishing_spot.gd")
const FishableWaterRegionType = preload(
	"res://world/fishable_water_region.gd"
)
const WeatherIconType = preload("res://ui/weather_icon.gd")

const Catalog: FishPoolType = preload("res://fish/pools/fish_catalog.tres")
const SaltWaterMaterial: ShaderMaterial = preload(
	"res://world/materials/stylized_water.tres"
)
const FreshWaterMaterial: ShaderMaterial = preload(
	"res://world/materials/stylized_water_fresh.tres"
)
func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_clock_boundaries_and_duration()
	_validate_persistent_host_clock()
	_validate_fishing_availability()
	_validate_fishing_spot_context()
	_validate_network_snapshot_bounds()
	_validate_environment_presentation()
	_validate_weather_clock_icon()
	print("World time validation: PASS")
	quit()


func _validate_clock_boundaries_and_duration() -> void:
	assert(WorldTimeServiceType.REAL_SECONDS_PER_CYCLE == 3600.0)
	assert(
		WorldTimeServiceType.phase_for_hour(7.49)
		== WorldTimeServiceType.Phase.NIGHT
	)
	assert(
		WorldTimeServiceType.phase_for_hour(7.5)
		== WorldTimeServiceType.Phase.DAWN
	)
	assert(
		WorldTimeServiceType.phase_for_hour(8.49)
		== WorldTimeServiceType.Phase.DAWN
	)
	assert(
		WorldTimeServiceType.phase_for_hour(8.5)
		== WorldTimeServiceType.Phase.DAY
	)
	assert(
		WorldTimeServiceType.phase_for_hour(19.5)
		== WorldTimeServiceType.Phase.DUSK
	)
	assert(
		WorldTimeServiceType.phase_for_hour(20.5)
		== WorldTimeServiceType.Phase.NIGHT
	)
	assert(WorldTimeServiceType.format_clock_time(0.0) == "12:00 am")
	assert(WorldTimeServiceType.format_clock_time(8.0) == "8:00 am")
	assert(WorldTimeServiceType.format_clock_time(20.5) == "8:30 pm")

	var clock := WorldTimeServiceType.new()
	root.add_child(clock)
	clock.begin_session(8.0)
	clock.advance_time(1800.0)
	assert(is_equal_approx(clock.get_time_hours(), 20.0))
	assert(clock.is_night_period())
	assert(clock.is_transition())
	clock.advance_time(1800.0)
	assert(is_equal_approx(clock.get_time_hours(), 8.0))
	assert(not clock.is_night_period())
	assert(clock.is_transition())

	# Small high-refresh deltas must still advance the displayed minute. Using
	# is_equal_approx() per frame used to suppress every clock notification.
	var emitted_times: Array[float] = []
	clock.time_changed.connect(
		func(time_hours: float, _phase: WorldTimeService.Phase) -> void:
			emitted_times.append(time_hours)
	)
	clock.begin_session(12.0 + 31.0 / 60.0)
	emitted_times.clear()
	for _frame: int in 1201:
		clock.advance_time(1.0 / 240.0)
	assert(clock.get_clock_text() == "12:33 pm")
	assert(emitted_times.size() >= 2)
	clock.queue_free()


func _validate_persistent_host_clock() -> void:
	var clock := WorldTimeServiceType.new()
	root.add_child(clock)
	assert(clock.restore_persistent_time_hours(18.75))
	clock.set_persistence_tracking_enabled(true)
	clock.begin_session(clock.get_persistent_time_hours())
	assert(is_equal_approx(clock.get_time_hours(), 18.75))
	clock.synchronize_time(19.25)
	assert(is_equal_approx(clock.get_persistent_time_hours(), 19.25))
	clock.set_persistence_tracking_enabled(false)
	clock.synchronize_time(6.5)
	assert(is_equal_approx(clock.get_time_hours(), 6.5))
	assert(is_equal_approx(clock.get_persistent_time_hours(), 19.25))
	assert(not clock.restore_persistent_time_hours(-1.0))
	assert(not clock.restore_persistent_time_hours(24.0))
	clock.queue_free()


func _validate_fishing_availability() -> void:
	var day_context := FishingContextType.new()
	day_context.location_tags = [&"starter_pond"]
	day_context.is_night = false
	var night_context := FishingContextType.new()
	night_context.location_tags = [&"starter_pond"]
	night_context.is_night = true
	var transition_context := FishingContextType.new()
	transition_context.location_tags = [&"starter_pond"]
	transition_context.is_night = true
	transition_context.is_day_night_transition = true

	for fish_id: StringName in [&"bluegill", &"sunfish"]:
		var day_fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(day_fish.availability.is_available(day_context))
		assert(not day_fish.availability.is_available(night_context))
		assert(day_fish.availability.is_available(transition_context))
	for fish_id: StringName in [
		&"catfish_blue",
		&"catfish_channel",
		&"catfish_flathead",
		&"catfish_white",
	]:
		var night_fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(not night_fish.availability.is_available(day_context))
		assert(night_fish.availability.is_available(night_context))
		assert(night_fish.availability.is_available(transition_context))
	for fish_id: StringName in [
		&"bass",
		&"carp",
		&"tuna_albacore",
		&"tuna_bigeye",
		&"tuna_bluefin",
		&"tuna_skipjack",
		&"tuna_yellowfin",
		&"goby_round",
		&"salmon_atlantic",
		&"salmon_chum",
		&"salmon_coho",
		&"salmon_pink",
		&"salmon_sockeye",
	]:
		var all_time_fish: FishDataType = Catalog.get_fish_by_id(fish_id)
		assert(all_time_fish.availability.is_available(day_context))
		assert(all_time_fish.availability.is_available(night_context))
		assert(all_time_fish.availability.is_available(transition_context))


func _validate_fishing_spot_context() -> void:
	var clock := WorldTimeServiceType.new()
	clock.begin_session(20.25)
	var fishing_spot := FishingSpotType.new()
	fishing_spot.set("_world_time", clock)
	var region := FishableWaterRegionType.new()
	region.location_tags = [&"starter_pond"]
	region.water_type = WaterType.Type.FRESH_WATER
	var dusk_context: FishingContext = fishing_spot.build_network_context(region)
	assert(dusk_context.is_night)
	assert(dusk_context.is_day_night_transition)
	clock.synchronize_time(14.0)
	var day_context: FishingContext = fishing_spot.build_network_context(region)
	assert(not day_context.is_night)
	assert(not day_context.is_day_night_transition)
	region.free()
	fishing_spot.free()
	clock.free()


func _validate_network_snapshot_bounds() -> void:
	assert(NetworkWorldTimeServiceType.validate_snapshot({
		"session_id": "session",
		"time_hours": 8.25,
		"sequence": 1,
	}))
	assert(not NetworkWorldTimeServiceType.validate_snapshot({
		"session_id": "session",
		"time_hours": 24.0,
		"sequence": 1,
	}))
	assert(not NetworkWorldTimeServiceType.validate_snapshot({
		"session_id": "",
		"time_hours": 8.0,
		"sequence": 1,
	}))


func _validate_environment_presentation() -> void:
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
	var visuals := WorldTimeVisualControllerType.new()
	world_root.add_child(visuals)
	visuals.setup(clock, world_environment, sun)
	visuals.apply_time_immediately(12.0)
	var runtime_environment: Environment = world_environment.environment
	var runtime_sky_material := (
		runtime_environment.sky.sky_material as ShaderMaterial
	)
	var day_horizon_value: Variant = runtime_sky_material.get_shader_parameter(
		"sky_horizon_color"
	)
	assert(day_horizon_value is Color)
	var day_horizon: Color = day_horizon_value as Color
	var day_sun_visibility: float = float(
		runtime_sky_material.get_shader_parameter("sun_visibility")
	)
	var day_sun_direction: Vector3 = (
		runtime_sky_material.get_shader_parameter("sun_direction") as Vector3
	)
	assert(day_sun_visibility > 0.99)
	assert(day_sun_direction.y > 0.85)
	assert(
		float(runtime_sky_material.get_shader_parameter("moon_visibility"))
		< 0.01
	)
	var day_ambient_energy: float = runtime_environment.ambient_light_energy
	assert(not runtime_environment.fog_enabled)
	assert(is_equal_approx(runtime_environment.fog_sky_affect, 0.35))
	var water_shader: Shader = preload(
		"res://world/materials/stylized_water.gdshader"
	)
	var sky_shader: Shader = preload(
		"res://world/environment/netfishing_sky.gdshader"
	)
	assert("uniform float fog_horizon_occlusion" in sky_shader.code)
	assert("fog_horizon_color.rgb" in sky_shader.code)
	assert("fog_disabled" in water_shader.code)
	assert("surface_view_position = view_vertex.xyz" in water_shader.code)
	assert("surface_view_distance = length(surface_view_position)" in water_shader.code)
	assert(
		"max(weather_fog_end, weather_fog_begin + 1.0),\n"
		+ "\t\tsurface_view_distance"
		in water_shader.code
	)
	assert("weather_fog_near_amount" in water_shader.code)
	assert("float weather_fog_alpha = mix(" in water_shader.code)
	assert("ALPHA = clamp(water_alpha, 0.1, weather_fog_alpha)" in water_shader.code)
	assert(is_zero_approx(float(
		SaltWaterMaterial.get_shader_parameter("weather_fog_amount")
	)))
	assert(is_equal_approx(float(
		SaltWaterMaterial.get_shader_parameter("surface_highlight_night_floor")
	), WorldTimeVisualController.DEFAULT_SURFACE_HIGHLIGHT_FLOOR))
	var day_water_brightness := float(
		SaltWaterMaterial.get_shader_parameter("environment_brightness")
	)
	assert(day_water_brightness > 0.99)
	assert(is_equal_approx(
		float(FreshWaterMaterial.get_shader_parameter("environment_brightness")),
		day_water_brightness,
	))
	visuals.apply_time_immediately(0.0)
	var night_horizon: Color = runtime_sky_material.get_shader_parameter(
		"sky_horizon_color"
	) as Color
	assert(night_horizon != day_horizon)
	assert(
		float(runtime_sky_material.get_shader_parameter("sun_visibility"))
		< 0.01
	)
	var night_moon_visibility: float = float(
		runtime_sky_material.get_shader_parameter("moon_visibility")
	)
	var night_moon_direction: Vector3 = (
		runtime_sky_material.get_shader_parameter("moon_direction") as Vector3
	)
	var night_sun_direction: Vector3 = (
		runtime_sky_material.get_shader_parameter("sun_direction") as Vector3
	)
	assert(night_moon_visibility > 0.99)
	assert(night_moon_direction.y > 0.85)
	assert(night_moon_direction.is_equal_approx(-night_sun_direction))
	assert(runtime_environment.ambient_light_energy < day_ambient_energy)
	assert(is_zero_approx(float(
		runtime_sky_material.get_shader_parameter("fog_horizon_occlusion")
	)))
	var night_water_brightness := float(
		SaltWaterMaterial.get_shader_parameter("environment_brightness")
	)
	assert(night_water_brightness < day_water_brightness * 0.4)
	assert(is_equal_approx(
		float(FreshWaterMaterial.get_shader_parameter("environment_brightness")),
		night_water_brightness,
	))
	var night_water_tint := (
		SaltWaterMaterial.get_shader_parameter("environment_tint") as Color
	)
	assert(night_water_tint.get_luminance() < 0.5)
	var night_background_energy := runtime_environment.background_energy_multiplier
	var night_ambient_energy := runtime_environment.ambient_light_energy
	var night_fog_light_energy := runtime_environment.fog_light_energy
	var night_adjustment_brightness := runtime_environment.adjustment_brightness
	var night_adjustment_saturation := runtime_environment.adjustment_saturation
	visuals.apply_weather_immediately(WorldWeatherService.Weather.FOGGY)
	visuals.apply_time_immediately(0.0)
	assert(runtime_environment.fog_enabled)
	assert(float(
		SaltWaterMaterial.get_shader_parameter("weather_fog_amount")
	) > 0.99)
	assert(is_equal_approx(float(
		SaltWaterMaterial.get_shader_parameter("weather_fog_near_amount")
	), WorldTimeVisualController.FOGGY_NIGHT_WATER_NEAR_FOG_AMOUNT))
	assert(is_equal_approx(float(
		SaltWaterMaterial.get_shader_parameter("surface_highlight_night_floor")
	), WorldTimeVisualController.FOGGY_NIGHT_SURFACE_HIGHLIGHT_FLOOR))
	assert(is_equal_approx(float(
		runtime_sky_material.get_shader_parameter("fog_horizon_occlusion")
	), 1.0))
	assert((
		runtime_sky_material.get_shader_parameter("fog_horizon_color") as Color
	).is_equal_approx(WorldTimeVisualController.NIGHT_FOG))
	var night_rendered_fog_color := (
		runtime_environment.fog_light_color.srgb_to_linear()
	)
	night_rendered_fog_color.r *= runtime_environment.fog_light_energy
	night_rendered_fog_color.g *= runtime_environment.fog_light_energy
	night_rendered_fog_color.b *= runtime_environment.fog_light_energy
	night_rendered_fog_color.a = 1.0
	night_rendered_fog_color = night_rendered_fog_color.linear_to_srgb()
	var night_water_fog_color := (
		SaltWaterMaterial.get_shader_parameter("weather_fog_color") as Color
	)
	var corrected_night_fog_color := night_rendered_fog_color
	corrected_night_fog_color.r *= (
		WorldTimeVisualController.FOGGY_DARK_WATER_FOG_CORRECTION.r
	)
	corrected_night_fog_color.g *= (
		WorldTimeVisualController.FOGGY_DARK_WATER_FOG_CORRECTION.g
	)
	corrected_night_fog_color.b *= (
		WorldTimeVisualController.FOGGY_DARK_WATER_FOG_CORRECTION.b
	)
	assert(night_water_fog_color.is_equal_approx(corrected_night_fog_color))
	var foggy_sky_horizon := (
		runtime_sky_material.get_shader_parameter("sky_horizon_color") as Color
	)
	assert(foggy_sky_horizon.is_equal_approx(night_horizon))
	assert(is_equal_approx(runtime_environment.fog_sky_affect, 1.0))
	assert(is_zero_approx(runtime_environment.fog_aerial_perspective))
	assert(is_equal_approx(runtime_environment.fog_depth_begin, 3.0))
	assert(is_equal_approx(runtime_environment.fog_depth_end, 18.0))
	assert(is_equal_approx(
		float(SaltWaterMaterial.get_shader_parameter("environment_brightness")),
		night_water_brightness,
	))
	assert(is_equal_approx(
		runtime_environment.background_energy_multiplier,
		night_background_energy,
	))
	assert(is_equal_approx(
		runtime_environment.ambient_light_energy,
		night_ambient_energy,
	))
	assert(is_equal_approx(
		runtime_environment.fog_light_energy,
		night_fog_light_energy,
	))
	assert(is_equal_approx(
		runtime_environment.adjustment_brightness,
		night_adjustment_brightness,
	))
	assert(is_equal_approx(
		runtime_environment.adjustment_saturation,
		night_adjustment_saturation,
	))
	visuals.apply_time_immediately(8.0)
	assert(is_equal_approx(float(
		SaltWaterMaterial.get_shader_parameter("weather_fog_near_amount")
	), WorldTimeVisualController.FOGGY_NIGHT_WATER_NEAR_FOG_AMOUNT))
	assert(is_equal_approx(float(
		runtime_sky_material.get_shader_parameter("fog_horizon_occlusion")
	), 1.0))
	visuals.apply_time_immediately(20.0)
	assert(is_zero_approx(float(
		SaltWaterMaterial.get_shader_parameter("weather_fog_near_amount")
	)))
	assert(is_zero_approx(float(
		runtime_sky_material.get_shader_parameter("fog_horizon_occlusion")
	)))
	visuals.apply_weather_immediately(WorldWeatherService.Weather.SUNNY)
	visuals.apply_time_immediately(20.0)
	assert(not runtime_environment.fog_enabled)
	assert(is_zero_approx(float(
		SaltWaterMaterial.get_shader_parameter("weather_fog_amount")
	)))
	assert(is_zero_approx(float(
		SaltWaterMaterial.get_shader_parameter("weather_fog_near_amount")
	)))
	assert(is_equal_approx(float(
		SaltWaterMaterial.get_shader_parameter("surface_highlight_night_floor")
	), WorldTimeVisualController.DEFAULT_SURFACE_HIGHLIGHT_FLOOR))
	assert(is_zero_approx(float(
		runtime_sky_material.get_shader_parameter("fog_horizon_occlusion")
	)))
	var dusk_horizon: Color = runtime_sky_material.get_shader_parameter(
		"sky_horizon_color"
	) as Color
	assert(dusk_horizon.r > day_horizon.r)
	world_root.queue_free()


func _validate_weather_clock_icon() -> void:
	var weather_icon := WeatherIconType.new()
	root.add_child(weather_icon)
	assert(weather_icon.tooltip_text == "clear")
	assert(not weather_icon.is_nighttime())
	weather_icon.set_nighttime(true)
	assert(weather_icon.is_nighttime())
	weather_icon.set_weather(WorldWeatherService.Weather.CLOUDY)
	assert(weather_icon.tooltip_text == "cloudy")
	weather_icon.queue_free()
