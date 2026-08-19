class_name WorldTimeService
extends Node

const CalendarSeasonType = preload("res://world/calendar_season.gd")

signal time_changed(time_hours: float, phase: Phase)
signal phase_changed(phase: Phase)
signal calendar_date_changed(date_id: String)
signal authoritative_time_set(time_hours: float)
signal natural_time_advanced(hours: float)

enum Phase {
	DAWN,
	DAY,
	DUSK,
	NIGHT,
}

const HOURS_PER_DAY: float = 24.0
const REAL_SECONDS_PER_CYCLE: float = 24.0 * 60.0 * 60.0
const HOURS_PER_REAL_SECOND: float = HOURS_PER_DAY / REAL_SECONDS_PER_CYCLE
const SYSTEM_CLOCK_SAMPLE_INTERVAL_SECONDS: float = 0.25
const DAY_START_HOUR: float = 8.0
const NIGHT_START_HOUR: float = 20.0
const TRANSITION_HALF_HOURS: float = 0.5
const DAWN_START_HOUR: float = DAY_START_HOUR - TRANSITION_HALF_HOURS
const DAWN_END_HOUR: float = DAY_START_HOUR + TRANSITION_HALF_HOURS
const DUSK_START_HOUR: float = NIGHT_START_HOUR - TRANSITION_HALF_HOURS
const DUSK_END_HOUR: float = NIGHT_START_HOUR + TRANSITION_HALF_HOURS
const DEFAULT_START_HOUR: float = DAY_START_HOUR
const MONTH_NAMES: Array[String] = [
	"january",
	"february",
	"march",
	"april",
	"may",
	"june",
	"july",
	"august",
	"september",
	"october",
	"november",
	"december",
]
const WEEKDAY_NAMES: Array[String] = [
	"sunday",
	"monday",
	"tuesday",
	"wednesday",
	"thursday",
	"friday",
	"saturday",
]
const WEEKDAY_MONTH_OFFSETS: Array[int] = [
	0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4,
]

var _time_hours: float = DEFAULT_START_HOUR
var _persistent_time_hours: float = DEFAULT_START_HOUR
var _running: bool = false
var _system_clock_authority: bool = false
var _editor_time_override: bool = false
var _phase: Phase = Phase.DAWN
var _last_emitted_clock_minute: int = floori(DEFAULT_START_HOUR * 60.0)
var _system_clock_sample_elapsed: float = 0.0
var _last_system_unix_seconds: float = -1.0
var _calendar_date_id: String = ""
var _local_datetime: Dictionary = {}


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	if not _running:
		return
	if _system_clock_authority and not _editor_time_override:
		_system_clock_sample_elapsed += delta
		if _system_clock_sample_elapsed >= SYSTEM_CLOCK_SAMPLE_INTERVAL_SECONDS:
			_system_clock_sample_elapsed = 0.0
			_sample_system_clock(false)
		return
	advance_time(delta)


func begin_authoritative_session() -> void:
	_running = true
	_system_clock_authority = true
	_editor_time_override = false
	_system_clock_sample_elapsed = 0.0
	_last_system_unix_seconds = -1.0
	set_process(true)
	_sample_system_clock(true)


func begin_remote_session() -> void:
	_running = true
	_system_clock_authority = false
	_editor_time_override = false
	_system_clock_sample_elapsed = 0.0
	_last_system_unix_seconds = -1.0
	_set_calendar_date_id("")
	_local_datetime = {}
	set_process(true)


func begin_test_session(
	start_hour: float = DEFAULT_START_HOUR,
	date_id: String = "",
) -> void:
	_running = true
	_system_clock_authority = false
	_editor_time_override = false
	_system_clock_sample_elapsed = 0.0
	_last_system_unix_seconds = -1.0
	set_process(false)
	if is_valid_calendar_date_id(date_id):
		_set_remote_datetime(start_hour, date_id)
	else:
		_set_calendar_date_id("")
		_local_datetime = {}
	_set_time_hours(start_hour, true)


func end_session() -> void:
	_running = false
	_system_clock_authority = false
	_editor_time_override = false
	_system_clock_sample_elapsed = 0.0
	_last_system_unix_seconds = -1.0
	_set_calendar_date_id("")
	_local_datetime = {}
	set_process(false)
	_set_time_hours(DEFAULT_START_HOUR, true)


func advance_time(real_seconds: float) -> void:
	if not _running or real_seconds <= 0.0:
		return
	var advanced_hours: float = real_seconds * HOURS_PER_REAL_SECOND
	_set_time_hours(_time_hours + advanced_hours, false)
	natural_time_advanced.emit(advanced_hours)


func synchronize_time(authoritative_time_hours: float) -> void:
	if not is_finite(authoritative_time_hours):
		return
	_set_time_hours(authoritative_time_hours, true)


func synchronize_calendar_time(
	authoritative_time_hours: float,
	date_id: String,
) -> bool:
	if (
		not is_finite(authoritative_time_hours)
		or not is_valid_calendar_date_id(date_id)
	):
		return false
	_set_remote_datetime(authoritative_time_hours, date_id)
	_set_time_hours(authoritative_time_hours, true)
	return true


func set_authoritative_time(time_hours: float) -> bool:
	# This hook intentionally exists only in the Godot editor/test runtime.
	# Exported clients and dedicated servers always follow their authoritative
	# machine clock and cannot expose mutable time commands to players.
	if (
		not OS.has_feature("editor")
		or not is_finite(time_hours)
		or time_hours < 0.0
		or time_hours >= HOURS_PER_DAY
	):
		return false
	_editor_time_override = true
	_set_time_hours(time_hours, true)
	authoritative_time_set.emit(_time_hours)
	return true


func clear_editor_time_override() -> void:
	if not _editor_time_override:
		return
	_editor_time_override = false
	_last_system_unix_seconds = -1.0
	if _system_clock_authority:
		_sample_system_clock(true)


func is_using_system_clock() -> bool:
	return _system_clock_authority and not _editor_time_override


func set_persistence_tracking_enabled(_enabled: bool) -> void:
	# Kept as a compatibility seam for schema-4 saves. Real-time sessions never
	# use saved time as an authority.
	pass


func restore_persistent_time_hours(time_hours: float) -> bool:
	if (
		not is_finite(time_hours)
		or time_hours < 0.0
		or time_hours >= HOURS_PER_DAY
	):
		return false
	_persistent_time_hours = time_hours
	return true


func get_persistent_time_hours() -> float:
	return _time_hours if _running else _persistent_time_hours


func get_time_hours() -> float:
	return _time_hours


func get_calendar_date_id() -> String:
	return _calendar_date_id


func get_calendar_cycle_id(rollover_hour: float) -> String:
	if _local_datetime.is_empty():
		return ""
	return calendar_cycle_id_from_datetime(_local_datetime, rollover_hour)


func get_phase() -> Phase:
	return _phase


func is_night_period() -> bool:
	return _time_hours < DAY_START_HOUR or _time_hours >= NIGHT_START_HOUR


func is_transition() -> bool:
	return _phase in [Phase.DAWN, Phase.DUSK]


func get_clock_text() -> String:
	return format_clock_time(_time_hours)


func get_calendar_text() -> String:
	return format_calendar_date(_calendar_date_id)


func get_season() -> int:
	return CalendarSeasonType.from_date_id(_calendar_date_id)


func get_season_text() -> String:
	var season: int = get_season()
	return (
		CalendarSeasonType.NAMES[season]
		if season != CalendarSeasonType.UNKNOWN
		else ""
	)


static func time_hours_from_datetime(datetime: Dictionary) -> float:
	var hour: int = clampi(int(datetime.get("hour", 0)), 0, 23)
	var minute: int = clampi(int(datetime.get("minute", 0)), 0, 59)
	var second: int = clampi(int(datetime.get("second", 0)), 0, 59)
	return (
		float(hour)
		+ float(minute) / 60.0
		+ float(second) / (60.0 * 60.0)
	)


static func date_id_from_datetime(datetime: Dictionary) -> String:
	return "%04d-%02d-%02d" % [
		int(datetime.get("year", 0)),
		int(datetime.get("month", 0)),
		int(datetime.get("day", 0)),
	]


static func is_valid_calendar_date_id(date_id: String) -> bool:
	if (
		date_id.length() != 10
		or date_id[4] != "-"
		or date_id[7] != "-"
	):
		return false
	var year_text: String = date_id.substr(0, 4)
	var month_text: String = date_id.substr(5, 2)
	var day_text: String = date_id.substr(8, 2)
	if (
		not year_text.is_valid_int()
		or not month_text.is_valid_int()
		or not day_text.is_valid_int()
	):
		return false
	var year: int = int(year_text)
	var month: int = int(month_text)
	var day: int = int(day_text)
	if year < 1 or month < 1 or month > 12:
		return false
	return day >= 1 and day <= _days_in_month(year, month)


static func format_calendar_date(date_id: String) -> String:
	if not is_valid_calendar_date_id(date_id):
		return ""
	var year: int = int(date_id.substr(0, 4))
	var month: int = int(date_id.substr(5, 2))
	var day: int = int(date_id.substr(8, 2))
	var weekday: int = _weekday_for_date(year, month, day)
	return "%s, %s %d" % [
		WEEKDAY_NAMES[weekday],
		MONTH_NAMES[month - 1],
		day,
	]


static func calendar_cycle_id_from_datetime(
	datetime: Dictionary,
	rollover_hour: float,
) -> String:
	var cycle_datetime: Dictionary = datetime.duplicate(true)
	if time_hours_from_datetime(datetime) < rollover_hour:
		var previous_day_unix: int = (
			Time.get_unix_time_from_datetime_dict(datetime) - 24 * 60 * 60
		)
		cycle_datetime = Time.get_datetime_dict_from_unix_time(
			previous_day_unix
		)
	return date_id_from_datetime(cycle_datetime)


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


func _sample_system_clock(force_emit: bool) -> void:
	var datetime: Dictionary = Time.get_datetime_dict_from_system(false)
	var unix_seconds: float = Time.get_unix_time_from_system()
	var previous_unix_seconds: float = _last_system_unix_seconds
	_last_system_unix_seconds = unix_seconds
	_local_datetime = datetime.duplicate(true)
	_set_time_hours(time_hours_from_datetime(datetime), force_emit)
	_set_calendar_date_id(date_id_from_datetime(datetime))
	if previous_unix_seconds < 0.0:
		return
	var advanced_seconds: float = unix_seconds - previous_unix_seconds
	if advanced_seconds > 0.0:
		natural_time_advanced.emit(advanced_seconds / 3600.0)


func _set_remote_datetime(time_hours: float, date_id: String) -> void:
	var normalized: float = _normalized_hour(time_hours)
	var total_seconds: int = floori(normalized * 60.0 * 60.0)
	_local_datetime = {
		"year": int(date_id.substr(0, 4)),
		"month": int(date_id.substr(5, 2)),
		"day": int(date_id.substr(8, 2)),
		"hour": total_seconds / 3600,
		"minute": (total_seconds / 60) % 60,
		"second": total_seconds % 60,
	}
	_set_calendar_date_id(date_id)


func _set_calendar_date_id(date_id: String) -> void:
	if date_id == _calendar_date_id:
		return
	_calendar_date_id = date_id
	calendar_date_changed.emit(_calendar_date_id)


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
	if phase_was_changed:
		phase_changed.emit(_phase)
	if force_emit or clock_minute_changed or phase_was_changed:
		_last_emitted_clock_minute = clock_minute
		time_changed.emit(_time_hours, _phase)


static func _normalized_hour(time_hours: float) -> float:
	return fposmod(time_hours, HOURS_PER_DAY)


static func _days_in_month(year: int, month: int) -> int:
	match month:
		2:
			return 29 if _is_leap_year(year) else 28
		4, 6, 9, 11:
			return 30
		_:
			return 31


static func _is_leap_year(year: int) -> bool:
	return year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)


static func _weekday_for_date(year: int, month: int, day: int) -> int:
	var adjusted_year: int = year - 1 if month < 3 else year
	return posmod(
		adjusted_year
		+ adjusted_year / 4
		- adjusted_year / 100
		+ adjusted_year / 400
		+ WEEKDAY_MONTH_OFFSETS[month - 1]
		+ day,
		7,
	)
