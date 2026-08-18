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
const WEATHER_PERIOD_SECONDS: float = 60.0 * 60.0
const SUNNY_DURATION_RANGE := Vector2(
	WEATHER_PERIOD_SECONDS, WEATHER_PERIOD_SECONDS
)
const CLOUDY_DURATION_RANGE := Vector2(
	WEATHER_PERIOD_SECONDS, WEATHER_PERIOD_SECONDS
)
const RAINY_DURATION_RANGE := Vector2(
	WEATHER_PERIOD_SECONDS, WEATHER_PERIOD_SECONDS
)
const FOGGY_DURATION_RANGE := Vector2(
	WEATHER_PERIOD_SECONDS, WEATHER_PERIOD_SECONDS
)
const MAX_PERSISTED_SECONDS: float = WEATHER_PERIOD_SECONDS
const DAILY_PLAN_SEGMENT_HOURS: float = 1.0
const DAILY_PLAN_SEGMENT_COUNT: int = 24

var _weather: Weather = DEFAULT_WEATHER
var _seconds_remaining: float = SUNNY_DURATION_RANGE.x
var _persistent_weather: Weather = DEFAULT_WEATHER
var _persistent_seconds_remaining: float = SUNNY_DURATION_RANGE.x
var _has_persistent_state: bool = false
var _persistence_tracking_enabled: bool = false
var _running_authority: bool = false
var _rng := RandomNumberGenerator.new()
var _daily_plan_id: String = ""
var _daily_schedule: Array[Dictionary] = []
var _world_time: WorldTimeService
var _manual_override_weather: Weather = DEFAULT_WEATHER
var _manual_override_segment_index: int = -1


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	advance_weather(delta)


func begin_authoritative_session(seed_value: int) -> void:
	_rng.seed = seed_value
	_running_authority = true
	set_process(true)
	_clear_manual_override()
	if _daily_schedule.is_empty() or _world_time == null:
		_set_weather(
			DEFAULT_WEATHER,
			_roll_duration(DEFAULT_WEATHER),
			true,
		)
	else:
		_update_scheduled_weather(true)


func begin_remote_session() -> void:
	_running_authority = false
	set_process(false)
	_clear_manual_override()
	_set_weather(DEFAULT_WEATHER, SUNNY_DURATION_RANGE.x, true)


func end_session() -> void:
	_running_authority = false
	set_process(false)
	_clear_manual_override()
	_set_weather(DEFAULT_WEATHER, SUNNY_DURATION_RANGE.x, true)


func advance_weather(real_seconds: float) -> void:
	if not _running_authority or real_seconds <= 0.0:
		return
	if not _daily_schedule.is_empty() and _world_time != null:
		_update_scheduled_weather(false)
		return
	_seconds_remaining -= real_seconds
	while _seconds_remaining <= 0.0:
		var overrun: float = -_seconds_remaining
		var next_weather: Weather = _choose_next_weather()
		_set_weather(next_weather, _roll_duration(next_weather), true)
		_seconds_remaining -= overrun
	if _persistence_tracking_enabled:
		_store_persistent_state()


func apply_authoritative_snapshot(
	weather: Weather,
	seconds_remaining: float,
) -> void:
	if not is_valid_weather(int(weather)) or not is_finite(seconds_remaining):
		return
	_set_weather(weather, maxf(seconds_remaining, 0.0), false)


func set_authoritative_weather(weather: Weather) -> bool:
	# Manual weather is an editor/test hook, not a player or operator command.
	if (
		not OS.has_feature("editor")
		or not _running_authority
		or not is_valid_weather(int(weather))
	):
		return false
	var duration: float = _roll_duration(weather)
	if not _daily_schedule.is_empty() and _world_time != null:
		_manual_override_weather = weather
		_manual_override_segment_index = _current_daily_segment_index()
		duration = _current_daily_segment_seconds_remaining(
			_manual_override_segment_index
		)
	else:
		_clear_manual_override()
	_set_weather(weather, duration, true)
	return true


func set_persistence_tracking_enabled(enabled: bool) -> void:
	if _persistence_tracking_enabled == enabled:
		return
	if _persistence_tracking_enabled:
		_store_persistent_state()
	_persistence_tracking_enabled = enabled


func restore_persistent_state(
	weather: Weather,
	seconds_remaining: float,
) -> bool:
	if not is_valid_persistent_state(weather, seconds_remaining):
		return false
	_persistent_weather = weather
	_persistent_seconds_remaining = seconds_remaining
	_has_persistent_state = true
	if _persistence_tracking_enabled:
		_set_weather(
			_persistent_weather,
			_persistent_seconds_remaining,
			true,
		)
	return true


func reset_persistent_state() -> void:
	_has_persistent_state = false
	_persistent_weather = DEFAULT_WEATHER
	_persistent_seconds_remaining = SUNNY_DURATION_RANGE.x
	if _persistence_tracking_enabled and _running_authority:
		_set_weather(
			DEFAULT_WEATHER,
			_roll_duration(DEFAULT_WEATHER),
			true,
		)


func has_persistent_state() -> bool:
	return _has_persistent_state


func get_persistent_weather() -> Weather:
	return _persistent_weather


func get_persistent_seconds_remaining() -> float:
	return _persistent_seconds_remaining


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


func configure_daily_plan(
	plan_id: String,
	schedule: Array,
	world_time: WorldTimeService,
) -> bool:
	if (
		plan_id.is_empty()
		or not is_valid_daily_plan_schedule(schedule)
		or world_time == null
	):
		return false
	_daily_plan_id = plan_id
	_daily_schedule.clear()
	_clear_manual_override()
	for value: Variant in schedule:
		_daily_schedule.append((value as Dictionary).duplicate(true))
	_world_time = world_time
	if _running_authority:
		_update_scheduled_weather(true)
	return true


func clear_daily_plan() -> void:
	_daily_plan_id = ""
	_daily_schedule.clear()
	_world_time = null
	_clear_manual_override()


func get_daily_plan_id() -> String:
	return _daily_plan_id


static func is_valid_weather(value: int) -> bool:
	return value >= Weather.SUNNY and value <= Weather.FOGGY


static func is_valid_persistent_state(
	weather: Weather,
	seconds_remaining: float,
) -> bool:
	return (
		is_valid_weather(int(weather))
		and is_finite(seconds_remaining)
		and seconds_remaining >= 0.0
		and seconds_remaining <= MAX_PERSISTED_SECONDS
	)


static func is_valid_daily_plan_schedule(value: Variant) -> bool:
	if typeof(value) != TYPE_ARRAY:
		return false
	var schedule: Array = value
	if schedule.size() != DAILY_PLAN_SEGMENT_COUNT:
		return false
	for entry_value: Variant in schedule:
		if typeof(entry_value) != TYPE_DICTIONARY:
			return false
		var entry: Dictionary = entry_value
		if (
			typeof(entry.get("start_hour")) not in [TYPE_FLOAT, TYPE_INT]
			or not is_finite(float(entry.get("start_hour", -1.0)))
			or float(entry.get("start_hour", -1.0)) < 0.0
			or float(entry.get("start_hour", -1.0)) >= 24.0
			or not _is_bounded_integer(
				entry.get("weather"), Weather.SUNNY, Weather.FOGGY
			)
			or not is_valid_weather(int(entry.get("weather", -1)))
		):
			return false
	return true


static func _is_bounded_integer(
	value: Variant,
	minimum: int,
	maximum: int,
) -> bool:
	if typeof(value) == TYPE_INT:
		return int(value) >= minimum and int(value) <= maximum
	if typeof(value) != TYPE_FLOAT:
		return false
	var number: float = float(value)
	return (
		is_finite(number)
		and number >= float(minimum)
		and number <= float(maximum)
		and is_equal_approx(number, round(number))
	)


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
	if _persistence_tracking_enabled:
		_store_persistent_state()
	if force_emit or changed:
		weather_changed.emit(_weather, _seconds_remaining)


func _store_persistent_state() -> void:
	_persistent_weather = _weather
	_persistent_seconds_remaining = _seconds_remaining
	_has_persistent_state = true


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


func _update_scheduled_weather(force_emit: bool) -> void:
	if _daily_schedule.is_empty() or _world_time == null:
		return
	var segment_index: int = _current_daily_segment_index()
	var entry: Dictionary = _daily_schedule[segment_index]
	var weather: Weather = int(entry.get("weather", DEFAULT_WEATHER)) as Weather
	if _manual_override_segment_index == segment_index:
		weather = _manual_override_weather
	elif _manual_override_segment_index >= 0:
		_clear_manual_override()
	var seconds_remaining: float = _current_daily_segment_seconds_remaining(
		segment_index
	)
	_set_weather(weather, seconds_remaining, force_emit)


func _current_daily_segment_index() -> int:
	var elapsed_hours: float = fposmod(
		_world_time.get_time_hours() - WorldTimeService.DAY_START_HOUR,
		WorldTimeService.HOURS_PER_DAY,
	)
	return clampi(
		floori(elapsed_hours / DAILY_PLAN_SEGMENT_HOURS),
		0,
		_daily_schedule.size() - 1,
	)


func _current_daily_segment_seconds_remaining(segment_index: int) -> float:
	var elapsed_hours: float = fposmod(
		_world_time.get_time_hours() - WorldTimeService.DAY_START_HOUR,
		WorldTimeService.HOURS_PER_DAY,
	)
	var next_boundary: float = (
		float(segment_index + 1) * DAILY_PLAN_SEGMENT_HOURS
	)
	var hours_remaining: float = maxf(next_boundary - elapsed_hours, 0.0)
	return hours_remaining / WorldTimeService.HOURS_PER_REAL_SECOND


func _clear_manual_override() -> void:
	_manual_override_weather = DEFAULT_WEATHER
	_manual_override_segment_index = -1
