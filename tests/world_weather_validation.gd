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
	match weather.get_weather():
		WorldWeatherServiceType.Weather.SUNNY:
			return seconds >= 480.0 and seconds <= 900.0
		WorldWeatherServiceType.Weather.CLOUDY:
			return seconds >= 300.0 and seconds <= 720.0
		WorldWeatherServiceType.Weather.RAINY, WorldWeatherServiceType.Weather.FOGGY:
			return seconds >= 300.0 and seconds <= 600.0
	return false


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
		"seconds_remaining": 1801.0,
		"sequence": 2,
	}))


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
	clock.begin_session(14.0)
	var weather := WorldWeatherServiceType.new()
	world_root.add_child(weather)
	weather.begin_remote_session()
	var rain_target := Node3D.new()
	world_root.add_child(rain_target)
	var visuals := WorldTimeVisualControllerType.new()
	world_root.add_child(visuals)
	visuals.setup(
		clock, world_environment, sun, weather, rain_target
	)
	visuals.apply_weather_immediately(
		WorldWeatherServiceType.Weather.FOGGY
	)
	var runtime_environment: Environment = world_environment.environment
	assert(runtime_environment.fog_depth_begin <= 4.01)
	assert(runtime_environment.fog_depth_end <= 42.01)
	assert(runtime_environment.fog_sky_affect >= 0.93)
	assert(runtime_environment.fog_aerial_perspective >= 0.91)
	assert(runtime_environment.adjustment_saturation < 0.70)
	visuals.apply_weather_immediately(
		WorldWeatherServiceType.Weather.RAINY
	)
	var rain := visuals.get_node("LocalRain") as GPUParticles3D
	assert(rain != null)
	assert(rain.emitting)
	assert(rain.amount_ratio > 0.99)
	visuals.apply_weather_immediately(
		WorldWeatherServiceType.Weather.SUNNY
	)
	assert(not rain.emitting)
	world_root.queue_free()
