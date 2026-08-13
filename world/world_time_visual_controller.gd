class_name WorldTimeVisualController
extends Node

const UPDATE_INTERVAL_SECONDS: float = 0.1
const SUN_YAW_DEGREES: float = -32.0
const WEATHER_TRANSITION_SECONDS: float = 10.0
const RAIN_EMITTER_OFFSET := Vector3(0.0, 7.0, 0.0)
const RAIN_PARTICLE_AMOUNT: int = 560
const RAIN_VELOCITY_MIN: float = 16.0
const RAIN_VELOCITY_MAX: float = 20.0
const RAIN_DROP_SIZE := Vector3(0.014, 0.34, 0.014)
const FOG_DAYLIGHT_SCENE_BRIGHTNESS: float = 0.42
const FOG_DAYLIGHT_FOG_LIGHT_BRIGHTNESS: float = 0.42
const FOG_DAYLIGHT_WATER_BRIGHTNESS: float = 0.42
const FOG_DAYLIGHT_POST_BRIGHTNESS: float = 0.50
const RAIN_DAYLIGHT_POST_BRIGHTNESS: float = 0.52
const RAIN_WATER_FOG_COLOR := Color(0.025, 0.038, 0.045)
const SALT_WATER_MATERIAL: ShaderMaterial = preload(
	"res://world/materials/stylized_water.tres"
)
const FRESH_WATER_MATERIAL: ShaderMaterial = preload(
	"res://world/materials/stylized_water_fresh.tres"
)
const LocalStormCloudLayerType = preload(
	"res://world/environment/local_storm_cloud_layer.gd"
)

const DAY_SKY_TOP := Color(0.204, 0.498, 0.643)
const DAY_SKY_HORIZON := Color(0.663, 0.843, 0.847)
const DAY_GROUND_BOTTOM := Color(0.157, 0.361, 0.439)
const DAY_GROUND_HORIZON := Color(0.549, 0.749, 0.765)
const DAY_AMBIENT := Color(0.82, 0.90, 0.92)
const DAY_FOG := Color(0.549, 0.749, 0.765)
const DAY_SUN := Color(0.88, 0.94, 0.96)
const DAY_SUN_DISC := Color(1.0, 0.86, 0.46)

const NIGHT_SKY_TOP := Color(0.026, 0.050, 0.105)
const NIGHT_SKY_HORIZON := Color(0.10, 0.17, 0.28)
const NIGHT_GROUND_BOTTOM := Color(0.020, 0.040, 0.080)
const NIGHT_GROUND_HORIZON := Color(0.075, 0.135, 0.22)
const NIGHT_AMBIENT := Color(0.28, 0.35, 0.48)
const NIGHT_FOG := Color(0.13, 0.21, 0.32)
const NIGHT_SUN := Color(0.35, 0.44, 0.62)
const NIGHT_WATER_TINT := Color(0.34, 0.48, 0.58)

const WARM_SKY_TOP := Color(0.31, 0.30, 0.42)
const WARM_SKY_HORIZON := Color(0.96, 0.48, 0.22)
const WARM_GROUND_BOTTOM := Color(0.20, 0.14, 0.16)
const WARM_GROUND_HORIZON := Color(0.82, 0.34, 0.18)
const WARM_AMBIENT := Color(0.92, 0.58, 0.40)
const WARM_FOG := Color(0.74, 0.39, 0.27)
const WARM_SUN := Color(1.0, 0.58, 0.30)
const WARM_WATER_TINT := Color(0.78, 0.62, 0.58)
const WARM_SUN_DISC := Color(1.0, 0.45, 0.16)
const MOON_DISC := Color(0.78, 0.88, 1.0)
const DAY_CLOUD_LIGHT := Color(0.70, 0.76, 0.77)
const DAY_CLOUD_SHADOW := Color(0.31, 0.38, 0.40)
const NIGHT_CLOUD_LIGHT := Color(0.18, 0.22, 0.30)
const NIGHT_CLOUD_SHADOW := Color(0.06, 0.09, 0.14)
const WARM_CLOUD_LIGHT := Color(0.76, 0.55, 0.45)
const WARM_CLOUD_SHADOW := Color(0.31, 0.23, 0.24)
const STORM_CLOUD_SHADOW := Color(0.08, 0.12, 0.14)
const DAY_LOWER_CLOUD := Color(0.22, 0.25, 0.26)
const NIGHT_LOWER_CLOUD := Color(0.08, 0.10, 0.14)
const WARM_LOWER_CLOUD := Color(0.22, 0.16, 0.16)

var _time_service: WorldTimeService
var _weather_service: WorldWeatherService
var _world_environment: WorldEnvironment
var _sun: DirectionalLight3D
var _rain_target: Node3D
var _rain_camera_provider: Callable
var _environment: Environment
var _sky_material: ShaderMaterial
var _rain: GPUParticles3D
var _storm_clouds: LocalStormCloudLayer
var _elapsed: float = 0.0
var _weather_from: WorldWeatherService.Weather = (
	WorldWeatherService.Weather.SUNNY
)
var _weather_to: WorldWeatherService.Weather = (
	WorldWeatherService.Weather.SUNNY
)
var _weather_transition: float = 1.0


func setup(
	time_service: WorldTimeService,
	world_environment: WorldEnvironment,
	sun: DirectionalLight3D,
	weather_service: WorldWeatherService = null,
	rain_target: Node3D = null,
	rain_camera_provider: Callable = Callable(),
) -> void:
	_time_service = time_service
	_weather_service = weather_service
	_world_environment = world_environment
	_sun = sun
	_rain_target = rain_target
	_rain_camera_provider = rain_camera_provider
	if not _prepare_runtime_environment():
		set_process(false)
		return
	_prepare_rain()
	_prepare_storm_clouds()
	if _weather_service != null:
		_weather_from = _weather_service.get_weather()
		_weather_to = _weather_from
		_weather_transition = 1.0
		if not _weather_service.weather_changed.is_connected(
			_on_weather_changed
		):
			_weather_service.weather_changed.connect(_on_weather_changed)
	set_process(true)
	_apply_time(_time_service.get_time_hours())


func _process(delta: float) -> void:
	if _time_service == null:
		return
	_update_rain_position()
	if _weather_transition < 1.0:
		_weather_transition = minf(
			_weather_transition + delta / WEATHER_TRANSITION_SECONDS,
			1.0,
		)
	_elapsed += delta
	if _elapsed < UPDATE_INTERVAL_SECONDS:
		return
	_elapsed = 0.0
	_apply_time(_time_service.get_time_hours())


func apply_time_immediately(time_hours: float) -> void:
	_apply_time(time_hours)


func apply_weather_immediately(
	weather: WorldWeatherService.Weather,
) -> void:
	_weather_from = weather
	_weather_to = weather
	_weather_transition = 1.0
	if _time_service != null:
		_apply_time(_time_service.get_time_hours())


func _prepare_runtime_environment() -> bool:
	if (
		_time_service == null
		or _world_environment == null
		or _world_environment.environment == null
		or _sun == null
	):
		push_error("World time visuals require an environment and sun.")
		return false
	_environment = _world_environment.environment.duplicate(true) as Environment
	if _environment == null or _environment.sky == null:
		push_error("World time visuals could not duplicate the world environment.")
		return false
	var runtime_sky: Sky = _environment.sky.duplicate(true) as Sky
	if runtime_sky == null or runtime_sky.sky_material == null:
		push_error("World time visuals require a sky material.")
		return false
	_sky_material = (
		runtime_sky.sky_material.duplicate(true) as ShaderMaterial
	)
	if _sky_material == null:
		push_error("World time visuals require the NETfishing sky material.")
		return false
	runtime_sky.sky_material = _sky_material
	_environment.sky = runtime_sky
	_world_environment.environment = _environment
	return true


func _prepare_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "LocalRain"
	_rain.amount = RAIN_PARTICLE_AMOUNT
	_rain.amount_ratio = 0.0
	_rain.lifetime = 1.25
	_rain.fixed_fps = 30
	_rain.local_coords = false
	_rain.visibility_aabb = AABB(
		Vector3(-7.0, -9.0, -7.0), Vector3(14.0, 12.0, 14.0)
	)
	var process_material := ParticleProcessMaterial.new()
	process_material.emission_shape = (
		ParticleProcessMaterial.EMISSION_SHAPE_BOX
	)
	process_material.emission_box_extents = Vector3(6.5, 1.0, 6.5)
	process_material.direction = Vector3.DOWN
	process_material.spread = 5.0
	process_material.initial_velocity_min = RAIN_VELOCITY_MIN
	process_material.initial_velocity_max = RAIN_VELOCITY_MAX
	process_material.gravity = Vector3(0.0, -2.0, 0.0)
	_rain.process_material = process_material
	var drop_mesh := BoxMesh.new()
	drop_mesh.size = RAIN_DROP_SIZE
	var drop_material := StandardMaterial3D.new()
	drop_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_material.albedo_color = Color(0.48, 0.78, 0.90, 0.72)
	drop_mesh.material = drop_material
	_rain.draw_pass_1 = drop_mesh
	add_child(_rain)
	_update_rain_position()


func _prepare_storm_clouds() -> void:
	_storm_clouds = LocalStormCloudLayerType.new()
	_storm_clouds.name = "LocalStormClouds"
	add_child(_storm_clouds)
	_storm_clouds.setup(_rain_target)


func _apply_time(time_hours: float) -> void:
	if _environment == null or _sky_material == null or _sun == null:
		return
	var hour: float = fposmod(time_hours, WorldTimeService.HOURS_PER_DAY)
	var daylight: float = _daylight_amount(hour)
	var warmth: float = _transition_warmth(hour)
	var sky_top: Color = _blended_color(
		NIGHT_SKY_TOP, DAY_SKY_TOP, WARM_SKY_TOP, daylight, warmth
	)
	var sky_horizon: Color = _blended_color(
		NIGHT_SKY_HORIZON,
		DAY_SKY_HORIZON,
		WARM_SKY_HORIZON,
		daylight,
		warmth,
	)
	var ground_bottom: Color = _blended_color(
		NIGHT_GROUND_BOTTOM,
		DAY_GROUND_BOTTOM,
		WARM_GROUND_BOTTOM,
		daylight,
		warmth,
	)
	var ground_horizon: Color = _blended_color(
		NIGHT_GROUND_HORIZON,
		DAY_GROUND_HORIZON,
		WARM_GROUND_HORIZON,
		daylight,
		warmth,
	)
	var ambient: Color = _blended_color(
		NIGHT_AMBIENT, DAY_AMBIENT, WARM_AMBIENT, daylight, warmth
	)
	var fog_color: Color = _blended_color(
		NIGHT_FOG, DAY_FOG, WARM_FOG, daylight, warmth
	)
	var foggy_fog_amount: float = _weather_value(0.0, 0.0, 0.0, 1.0)
	var rain_fog_amount: float = _weather_value(0.0, 0.0, 1.0, 0.0)
	var fog_daylight_amount: float = daylight * foggy_fog_amount
	var rain_daylight_amount: float = daylight * rain_fog_amount
	var weather_fog_amount: float = minf(
		rain_fog_amount + foggy_fog_amount,
		1.0,
	)
	_environment.fog_enabled = weather_fog_amount > 0.001
	var fog_scene_brightness: float = lerpf(
		1.0,
		FOG_DAYLIGHT_SCENE_BRIGHTNESS,
		fog_daylight_amount,
	)
	_sky_material.set_shader_parameter(
		"sky_top_color", sky_top
	)
	_sky_material.set_shader_parameter(
		"sky_horizon_color",
		sky_horizon,
	)
	_sky_material.set_shader_parameter(
		"ground_bottom_color",
		ground_bottom,
	)
	_sky_material.set_shader_parameter(
		"ground_horizon_color",
		ground_horizon,
	)
	_apply_sky_clouds(daylight, warmth)
	_environment.background_energy_multiplier = (
		lerpf(0.52, 0.85, daylight)
		* _weather_value(1.0, 0.82, 0.66, 1.0)
		* fog_scene_brightness
	)
	_environment.ambient_light_color = ambient
	_environment.ambient_light_energy = (
		lerpf(0.66, 1.08, daylight)
		* _weather_value(1.0, 0.88, 0.76, 1.0)
		* fog_scene_brightness
	)
	_environment.fog_light_color = fog_color
	var fog_light_energy := (
		lerpf(0.56, 0.82, daylight)
		* _weather_value(1.0, 0.92, 0.82, 1.0)
		* lerpf(
			1.0,
			FOG_DAYLIGHT_FOG_LIGHT_BRIGHTNESS,
			fog_daylight_amount,
		)
	)
	_environment.fog_light_energy = fog_light_energy
	_environment.fog_aerial_perspective = _weather_value(
		0.35, 0.48, 0.62, 0.0
	)
	_environment.fog_sky_affect = _weather_value(
		0.35, 0.48, 0.68, 1.0
	)
	_environment.fog_depth_curve = _weather_value(
		1.6, 1.5, 1.4, 1.18
	)
	_environment.fog_depth_begin = _weather_value(
		42.0, 32.0, 20.0, 3.0
	)
	_environment.fog_depth_end = _weather_value(
		170.0, 140.0, 95.0, 18.0
	)
	_apply_water_environment(
		daylight,
		warmth,
		rain_fog_amount,
		foggy_fog_amount,
		_fog_render_color(fog_color, fog_light_energy),
	)
	_environment.adjustment_brightness = (
		lerpf(0.93, 0.98, daylight)
		* _weather_value(1.0, 0.97, 0.92, 1.0)
		* lerpf(
			1.0,
			FOG_DAYLIGHT_POST_BRIGHTNESS,
			fog_daylight_amount,
		)
		* lerpf(
			1.0,
			RAIN_DAYLIGHT_POST_BRIGHTNESS,
			rain_daylight_amount,
		)
	)
	_environment.adjustment_saturation = (
		lerpf(0.82, 0.91, daylight)
		* _weather_value(1.0, 0.88, 0.78, 1.0)
	)
	_sun.rotation_degrees = Vector3(
		-360.0 * fposmod(hour - WorldTimeService.DAY_START_HOUR, 24.0) / 24.0,
		SUN_YAW_DEGREES,
		0.0,
	)
	_sky_material.set_shader_parameter(
		"sun_direction", _sun.global_transform.basis.z.normalized()
	)
	_sky_material.set_shader_parameter(
		"sun_color", DAY_SUN_DISC.lerp(WARM_SUN_DISC, warmth)
	)
	_sky_material.set_shader_parameter(
		"sun_visibility",
		daylight * _weather_value(1.0, 0.65, 0.28, 1.0),
	)
	_sky_material.set_shader_parameter(
		"moon_direction", -_sun.global_transform.basis.z.normalized()
	)
	_sky_material.set_shader_parameter("moon_color", MOON_DISC)
	_sky_material.set_shader_parameter(
		"moon_visibility",
		(1.0 - daylight) * _weather_value(1.0, 0.72, 0.36, 1.0),
	)
	_sun.light_color = _blended_color(
		NIGHT_SUN, DAY_SUN, WARM_SUN, daylight, warmth
	)
	_sun.light_energy = (
		lerpf(0.0, 0.10, daylight)
		* _weather_value(1.0, 0.55, 0.25, 0.30)
	)
	_update_rain_amount()


func _apply_water_environment(
	daylight: float,
	warmth: float,
	rain_fog_amount: float,
	foggy_fog_amount: float,
	fog_render_color: Color,
) -> void:
	var water_tint := _blended_color(
		NIGHT_WATER_TINT,
		Color.WHITE,
		WARM_WATER_TINT,
		daylight,
		warmth,
	)
	var water_brightness := (
		lerpf(0.34, 1.0, daylight)
		* _weather_value(1.0, 0.90, 0.78, 1.0)
		* lerpf(
			1.0,
			FOG_DAYLIGHT_WATER_BRIGHTNESS,
			daylight * _weather_value(0.0, 0.0, 0.0, 1.0),
		)
	)
	var weather_fog_amount: float = minf(
		rain_fog_amount + foggy_fog_amount,
		1.0,
	)
	var foggy_color_weight: float = (
		foggy_fog_amount / weather_fog_amount
		if weather_fog_amount > 0.001
		else 0.0
	)
	var water_fog_color := RAIN_WATER_FOG_COLOR.lerp(
		fog_render_color,
		foggy_color_weight,
	)
	for material: ShaderMaterial in [
		SALT_WATER_MATERIAL,
		FRESH_WATER_MATERIAL,
	]:
		material.set_shader_parameter("environment_tint", water_tint)
		material.set_shader_parameter(
			"environment_brightness",
			water_brightness,
		)
		material.set_shader_parameter("weather_fog_color", water_fog_color)
		material.set_shader_parameter(
			"weather_fog_amount",
			weather_fog_amount,
		)
		material.set_shader_parameter(
			"weather_fog_begin",
			_weather_value(42.0, 32.0, 20.0, 3.0),
		)
		material.set_shader_parameter(
			"weather_fog_end",
			_weather_value(170.0, 140.0, 95.0, 18.0),
		)
		material.set_shader_parameter(
			"weather_fog_curve",
			_weather_value(1.6, 1.5, 1.4, 1.18),
		)


func _fog_render_color(fog_color: Color, fog_light_energy: float) -> Color:
	var linear_fog_color := fog_color.srgb_to_linear()
	linear_fog_color.r *= fog_light_energy
	linear_fog_color.g *= fog_light_energy
	linear_fog_color.b *= fog_light_energy
	linear_fog_color.a = 1.0
	return linear_fog_color.linear_to_srgb()


func _apply_sky_clouds(daylight: float, warmth: float) -> void:
	var cloud_light := _blended_color(
		NIGHT_CLOUD_LIGHT,
		DAY_CLOUD_LIGHT,
		WARM_CLOUD_LIGHT,
		daylight,
		warmth,
	)
	var cloud_shadow := _blended_color(
		NIGHT_CLOUD_SHADOW,
		DAY_CLOUD_SHADOW,
		WARM_CLOUD_SHADOW,
		daylight,
		warmth,
	)
	var storm_amount: float = _weather_value(0.0, 0.18, 0.55, 0.0)
	cloud_light = cloud_light.lerp(cloud_shadow, storm_amount * 0.35)
	cloud_shadow = cloud_shadow.lerp(
		STORM_CLOUD_SHADOW,
		storm_amount * 0.10,
	)
	var lower_cloud_color := _blended_color(
		NIGHT_LOWER_CLOUD,
		DAY_LOWER_CLOUD,
		WARM_LOWER_CLOUD,
		daylight,
		warmth,
	)
	_sky_material.set_shader_parameter(
		"cloud_coverage",
		_weather_value(0.0, 0.58, 0.985, 0.0),
	)
	_sky_material.set_shader_parameter(
		"cloud_opacity",
		_weather_value(0.0, 0.76, 1.0, 0.0),
	)
	_sky_material.set_shader_parameter("cloud_light_color", cloud_light)
	_sky_material.set_shader_parameter("cloud_shadow_color", cloud_shadow)
	if _storm_clouds != null:
		_storm_clouds.set_storm_amount(
			_weather_value(0.0, 0.0, 1.0, 0.0),
			lower_cloud_color,
		)


func _on_weather_changed(
	weather: WorldWeatherService.Weather,
	_seconds_remaining: float,
) -> void:
	if weather == _weather_to:
		return
	_weather_from = _weather_to
	_weather_to = weather
	_weather_transition = 0.0


func _weather_value(
	sunny: float,
	cloudy: float,
	rainy: float,
	foggy: float,
) -> float:
	return lerpf(
		_weather_state_value(_weather_from, sunny, cloudy, rainy, foggy),
		_weather_state_value(_weather_to, sunny, cloudy, rainy, foggy),
		_weather_transition,
	)


func _weather_state_value(
	weather: WorldWeatherService.Weather,
	sunny: float,
	cloudy: float,
	rainy: float,
	foggy: float,
) -> float:
	match weather:
		WorldWeatherService.Weather.CLOUDY:
			return cloudy
		WorldWeatherService.Weather.RAINY:
			return rainy
		WorldWeatherService.Weather.FOGGY:
			return foggy
	return sunny


func _update_rain_amount() -> void:
	if _rain == null:
		return
	var rain_amount: float = _weather_value(0.0, 0.0, 1.0, 0.0)
	_rain.amount_ratio = rain_amount
	_rain.emitting = rain_amount > 0.01


func _update_rain_position() -> void:
	if _rain == null or _rain_target == null:
		return
	var anchor_position: Vector3 = _rain_target.global_position
	if _rain_camera_provider.is_valid():
		var camera_candidate: Variant = _rain_camera_provider.call()
		if camera_candidate is Camera3D:
			var active_camera := camera_candidate as Camera3D
			if is_instance_valid(active_camera):
				anchor_position = active_camera.global_position
	_rain.global_position = anchor_position + RAIN_EMITTER_OFFSET


func _daylight_amount(hour: float) -> float:
	if hour >= WorldTimeService.DAWN_START_HOUR and hour < WorldTimeService.DAWN_END_HOUR:
		return smoothstep(
			WorldTimeService.DAWN_START_HOUR,
			WorldTimeService.DAWN_END_HOUR,
			hour,
		)
	if hour >= WorldTimeService.DAWN_END_HOUR and hour < WorldTimeService.DUSK_START_HOUR:
		return 1.0
	if hour >= WorldTimeService.DUSK_START_HOUR and hour < WorldTimeService.DUSK_END_HOUR:
		return 1.0 - smoothstep(
			WorldTimeService.DUSK_START_HOUR,
			WorldTimeService.DUSK_END_HOUR,
			hour,
		)
	return 0.0


func _transition_warmth(hour: float) -> float:
	if hour >= WorldTimeService.DAWN_START_HOUR and hour < WorldTimeService.DAWN_END_HOUR:
		return 1.0 - absf(hour - WorldTimeService.DAY_START_HOUR) / WorldTimeService.TRANSITION_HALF_HOURS
	if hour >= WorldTimeService.DUSK_START_HOUR and hour < WorldTimeService.DUSK_END_HOUR:
		return 1.0 - absf(hour - WorldTimeService.NIGHT_START_HOUR) / WorldTimeService.TRANSITION_HALF_HOURS
	return 0.0


func _blended_color(
	night_color: Color,
	day_color: Color,
	warm_color: Color,
	daylight: float,
	warmth: float,
) -> Color:
	return night_color.lerp(day_color, daylight).lerp(warm_color, warmth)
