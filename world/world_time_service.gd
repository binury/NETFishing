class_name WorldTimeService
extends Node

signal time_changed(time_hours: float, phase: Phase)
signal phase_changed(phase: Phase)

enum Phase {
	DAWN,
	DAY,
	DUSK,
	NIGHT,
}

const HOURS_PER_DAY: float = 24.0
const REAL_SECONDS_PER_CYCLE: float = 60.0 * 60.0
const HOURS_PER_REAL_SECOND: float = HOURS_PER_DAY / REAL_SECONDS_PER_CYCLE
const DAY_START_HOUR: float = 8.0
const NIGHT_START_HOUR: float = 20.0
const TRANSITION_HALF_HOURS: float = 0.5
const DAWN_START_HOUR: float = DAY_START_HOUR - TRANSITION_HALF_HOURS
const DAWN_END_HOUR: float = DAY_START_HOUR + TRANSITION_HALF_HOURS
const DUSK_START_HOUR: float = NIGHT_START_HOUR - TRANSITION_HALF_HOURS
const DUSK_END_HOUR: float = NIGHT_START_HOUR + TRANSITION_HALF_HOURS
const DEFAULT_START_HOUR: float = DAY_START_HOUR

var _time_hours: float = DEFAULT_START_HOUR
var _persistent_time_hours: float = DEFAULT_START_HOUR
var _persistence_tracking_enabled: bool = false
var _running: bool = false
var _phase: Phase = Phase.DAWN
var _last_emitted_clock_minute: int = floori(DEFAULT_START_HOUR * 60.0)


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	advance_time(delta)


func begin_session(start_hour: float = DEFAULT_START_HOUR) -> void:
	_running = true
	set_process(true)
	_set_time_hours(start_hour, true)


func end_session() -> void:
	_running = false
	set_process(false)
	_set_time_hours(DEFAULT_START_HOUR, true)


func advance_time(real_seconds: float) -> void:
	if not _running or real_seconds <= 0.0:
		return
	_set_time_hours(
		_time_hours + real_seconds * HOURS_PER_REAL_SECOND,
		false,
	)


func synchronize_time(authoritative_time_hours: float) -> void:
	if not is_finite(authoritative_time_hours):
		return
	_set_time_hours(authoritative_time_hours, true)


func set_persistence_tracking_enabled(enabled: bool) -> void:
	if _persistence_tracking_enabled == enabled:
		return
	if _persistence_tracking_enabled:
		_persistent_time_hours = _time_hours
	_persistence_tracking_enabled = enabled


func restore_persistent_time_hours(time_hours: float) -> bool:
	if (
		not is_finite(time_hours)
		or time_hours < 0.0
		or time_hours >= HOURS_PER_DAY
	):
		return false
	_persistent_time_hours = time_hours
	if _persistence_tracking_enabled:
		_set_time_hours(_persistent_time_hours, true)
	return true


func get_persistent_time_hours() -> float:
	return _persistent_time_hours


func get_time_hours() -> float:
	return _time_hours


func get_phase() -> Phase:
	return _phase


func is_night_period() -> bool:
	return _time_hours < DAY_START_HOUR or _time_hours >= NIGHT_START_HOUR


func is_transition() -> bool:
	return _phase in [Phase.DAWN, Phase.DUSK]


func get_clock_text() -> String:
	return format_clock_time(_time_hours)


static func phase_for_hour(time_hours: float) -> Phase:
	var hour: float = _normalized_hour(time_hours)
	if hour >= DAWN_START_HOUR and hour < DAWN_END_HOUR:
		return Phase.DAWN
	if hour >= DAWN_END_HOUR and hour < DUSK_START_HOUR:
		return Phase.DAY
	if hour >= DUSK_START_HOUR and hour < DUSK_END_HOUR:
		return Phase.DUSK
	return Phase.NIGHT


static func format_clock_time(time_hours: float) -> String:
	var hour: float = _normalized_hour(time_hours)
	var total_minutes: int = floori(hour * 60.0)
	var hour_24: int = floori(float(total_minutes) / 60.0)
	var minute: int = total_minutes % 60
	var hour_12: int = hour_24 % 12
	if hour_12 == 0:
		hour_12 = 12
	return "%d:%02d %s" % [
		hour_12,
		minute,
		"am" if hour_24 < 12 else "pm",
	]


func _set_time_hours(time_hours: float, force_emit: bool) -> void:
	var normalized: float = _normalized_hour(time_hours)
	var next_phase: Phase = phase_for_hour(normalized)
	var phase_was_changed: bool = next_phase != _phase
	var clock_minute: int = floori(normalized * 60.0)
	var clock_minute_changed: bool = (
		clock_minute != _last_emitted_clock_minute
	)
	_time_hours = normalized
	_phase = next_phase
	if _persistence_tracking_enabled:
		_persistent_time_hours = normalized
	if phase_was_changed:
		phase_changed.emit(_phase)
	if force_emit or clock_minute_changed or phase_was_changed:
		_last_emitted_clock_minute = clock_minute
		time_changed.emit(_time_hours, _phase)


static func _normalized_hour(time_hours: float) -> float:
	return fposmod(time_hours, HOURS_PER_DAY)
