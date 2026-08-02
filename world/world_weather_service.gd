class_name WorldWeatherService
extends Node

signal weather_changed(weather: Weather, seconds_remaining: float)

enum Weather {
	SUNNY,
	CLOUDY,
	RAINY,
	FOGGY,
}

const DEFAULT_WEATHER: Weather = Weather.SUNNY
const SUNNY_DURATION_RANGE := Vector2(480.0, 900.0)
const CLOUDY_DURATION_RANGE := Vector2(300.0, 720.0)
const RAINY_DURATION_RANGE := Vector2(300.0, 600.0)
const FOGGY_DURATION_RANGE := Vector2(300.0, 600.0)

var _weather: Weather = DEFAULT_WEATHER
var _seconds_remaining: float = SUNNY_DURATION_RANGE.x
var _running_authority: bool = false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	advance_weather(delta)


func begin_authoritative_session(seed_value: int) -> void:
	_rng.seed = seed_value
	_running_authority = true
	set_process(true)
	_set_weather(DEFAULT_WEATHER, _roll_duration(DEFAULT_WEATHER), true)


func begin_remote_session() -> void:
	_running_authority = false
	set_process(false)
	_set_weather(DEFAULT_WEATHER, SUNNY_DURATION_RANGE.x, true)


func end_session() -> void:
	_running_authority = false
	set_process(false)
	_set_weather(DEFAULT_WEATHER, SUNNY_DURATION_RANGE.x, true)


func advance_weather(real_seconds: float) -> void:
	if not _running_authority or real_seconds <= 0.0:
		return
	_seconds_remaining -= real_seconds
	while _seconds_remaining <= 0.0:
		var overrun: float = -_seconds_remaining
		var next_weather: Weather = _choose_next_weather()
		_set_weather(next_weather, _roll_duration(next_weather), true)
		_seconds_remaining -= overrun


func apply_authoritative_snapshot(
	weather: Weather,
	seconds_remaining: float,
) -> void:
	if not is_valid_weather(int(weather)) or not is_finite(seconds_remaining):
		return
	_set_weather(weather, maxf(seconds_remaining, 0.0), false)


func get_weather() -> Weather:
	return _weather


func get_seconds_remaining() -> float:
	return _seconds_remaining


func is_raining() -> bool:
	return _weather == Weather.RAINY


func is_foggy() -> bool:
	return _weather == Weather.FOGGY


func get_weather_name() -> String:
	return weather_name(_weather)


static func is_valid_weather(value: int) -> bool:
	return value >= Weather.SUNNY and value <= Weather.FOGGY


static func weather_name(weather: Weather) -> String:
	match weather:
		Weather.SUNNY:
			return "sunny"
		Weather.CLOUDY:
			return "cloudy"
		Weather.RAINY:
			return "rainy"
		Weather.FOGGY:
			return "foggy"
	return "unknown"


func _set_weather(
	weather: Weather,
	seconds_remaining: float,
	force_emit: bool,
) -> void:
	var changed: bool = weather != _weather
	_weather = weather
	_seconds_remaining = maxf(seconds_remaining, 0.0)
	if force_emit or changed:
		weather_changed.emit(_weather, _seconds_remaining)


func _choose_next_weather() -> Weather:
	match _weather:
		Weather.SUNNY:
			return Weather.CLOUDY
		Weather.RAINY, Weather.FOGGY:
			return Weather.CLOUDY
		Weather.CLOUDY:
			var roll: float = _rng.randf()
			if roll < 0.45:
				return Weather.SUNNY
			if roll < 0.80:
				return Weather.RAINY
			return Weather.FOGGY
	return Weather.SUNNY


func _roll_duration(weather: Weather) -> float:
	var duration_range: Vector2 = _duration_range(weather)
	return _rng.randf_range(duration_range.x, duration_range.y)


func _duration_range(weather: Weather) -> Vector2:
	match weather:
		Weather.SUNNY:
			return SUNNY_DURATION_RANGE
		Weather.CLOUDY:
			return CLOUDY_DURATION_RANGE
		Weather.RAINY:
			return RAINY_DURATION_RANGE
		Weather.FOGGY:
			return FOGGY_DURATION_RANGE
	return SUNNY_DURATION_RANGE
