class_name RainAmbience
extends AudioStreamPlayer

const RAIN_STREAM_PATH: String = (
	"res://audio/ambience/rain_loop_ontario.ogg"
)
const SILENT_VOLUME_DB: float = -60.0

@export_range(-40.0, 0.0, 0.5) var rain_volume_db: float = -8.0
@export_range(0.0, 10.0, 0.1) var fade_seconds: float = 2.5

var _weather_service: WorldWeatherService
var _fade_tween: Tween
var _is_active: bool = false


func _ready() -> void:
	bus = &"SFX"
	var rain_stream := load(RAIN_STREAM_PATH) as AudioStreamOggVorbis
	var runtime_stream := (
		rain_stream.duplicate() as AudioStreamOggVorbis
		if rain_stream != null
		else null
	)
	if runtime_stream != null:
		runtime_stream.loop = true
		stream = runtime_stream
	volume_db = SILENT_VOLUME_DB


func configure(weather_service: WorldWeatherService) -> void:
	if (
		_weather_service != null
		and _weather_service.weather_changed.is_connected(
			_on_weather_changed
		)
	):
		_weather_service.weather_changed.disconnect(_on_weather_changed)
	_weather_service = weather_service
	if (
		_weather_service != null
		and not _weather_service.weather_changed.is_connected(
			_on_weather_changed
		)
	):
		_weather_service.weather_changed.connect(_on_weather_changed)


func set_active(active: bool) -> void:
	if _is_active == active:
		return
	_is_active = active
	if not active:
		_silence_immediately()
		return
	_transition_to_rain(
		_weather_service != null and _weather_service.is_raining()
	)


func _on_weather_changed(
	weather: WorldWeatherService.Weather,
	_seconds_remaining: float,
) -> void:
	_transition_to_rain(weather == WorldWeatherService.Weather.RAINY)


func _transition_to_rain(is_raining: bool) -> void:
	if not _is_active:
		return
	_stop_fade()
	if is_raining:
		if stream == null:
			return
		if not playing:
			volume_db = SILENT_VOLUME_DB
			play()
		_fade_volume_to(rain_volume_db, false)
		return
	if playing:
		_fade_volume_to(SILENT_VOLUME_DB, true)


func _fade_volume_to(target_volume_db: float, stop_after_fade: bool) -> void:
	if fade_seconds <= 0.0:
		volume_db = target_volume_db
		if stop_after_fade:
			_finish_fade_out()
		return
	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_SINE)
	_fade_tween.set_ease(Tween.EASE_IN_OUT)
	_fade_tween.tween_property(
		self,
		"volume_db",
		target_volume_db,
		fade_seconds,
	)
	if stop_after_fade:
		_fade_tween.tween_callback(_finish_fade_out)


func _finish_fade_out() -> void:
	if _weather_service != null and _weather_service.is_raining():
		return
	stop()
	volume_db = SILENT_VOLUME_DB
	_fade_tween = null


func _silence_immediately() -> void:
	_stop_fade()
	stop()
	volume_db = SILENT_VOLUME_DB


func _stop_fade() -> void:
	if _fade_tween == null:
		return
	_fade_tween.kill()
	_fade_tween = null
