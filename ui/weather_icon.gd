class_name WeatherIcon
extends Control

const CLEAR_DAY_TEXTURE: Texture2D = preload(
	"res://ui/icons/weather/weather_clear_day.png"
)
const CLEAR_NIGHT_TEXTURE: Texture2D = preload(
	"res://ui/icons/weather/weather_clear_night_full.png"
)
const CLOUDY_TEXTURE: Texture2D = preload(
	"res://ui/icons/weather/weather_cloudy.png"
)
const FOG_TEXTURE: Texture2D = preload(
	"res://ui/icons/weather/weather_fog.png"
)
const RAIN_TEXTURE: Texture2D = preload(
	"res://ui/icons/weather/weather_rain.png"
)

var _weather: WorldWeatherService.Weather = WorldWeatherService.Weather.SUNNY
var _is_nighttime: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	custom_minimum_size = Vector2(34.0, 34.0)
	_update_tooltip()
	queue_redraw()


func set_weather(weather: WorldWeatherService.Weather) -> void:
	if _weather == weather:
		_update_tooltip()
		return
	_weather = weather
	_update_tooltip()
	queue_redraw()


func set_nighttime(nighttime: bool) -> void:
	if _is_nighttime == nighttime:
		return
	_is_nighttime = nighttime
	queue_redraw()


func is_nighttime() -> bool:
	return _is_nighttime


func get_weather() -> WorldWeatherService.Weather:
	return _weather


func _draw() -> void:
	var icon_size := Vector2.ONE * minf(size.x, size.y)
	var icon_rect := Rect2((size - icon_size) * 0.5, icon_size)
	draw_texture_rect(_get_weather_texture(), icon_rect, false)


func _get_weather_texture() -> Texture2D:
	match _weather:
		WorldWeatherService.Weather.SUNNY:
			return CLEAR_NIGHT_TEXTURE if _is_nighttime else CLEAR_DAY_TEXTURE
		WorldWeatherService.Weather.CLOUDY:
			return CLOUDY_TEXTURE
		WorldWeatherService.Weather.RAINY:
			return RAIN_TEXTURE
		WorldWeatherService.Weather.FOGGY:
			return FOG_TEXTURE
	return CLEAR_DAY_TEXTURE


func _update_tooltip() -> void:
	tooltip_text = (
		"clear"
		if _weather == WorldWeatherService.Weather.SUNNY
		else WorldWeatherService.weather_name(_weather)
	)
