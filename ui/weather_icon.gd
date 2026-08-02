class_name WeatherIcon
extends Control

const BUBBLE_COLOR := Color(0.025, 0.13, 0.19, 0.94)
const ICON_COLOR := Color(0.78, 0.91, 0.95)
const SUN_COLOR := Color(0.98, 0.82, 0.34)
const MOON_COLOR := Color(0.78, 0.88, 1.0)
const RAIN_COLOR := Color(0.28, 0.73, 0.82)

var _weather: WorldWeatherService.Weather = WorldWeatherService.Weather.SUNNY
var _is_nighttime: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	focus_mode = Control.FOCUS_NONE
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


func set_nighttime(is_nighttime: bool) -> void:
	if _is_nighttime == is_nighttime:
		return
	_is_nighttime = is_nighttime
	queue_redraw()


func is_nighttime() -> bool:
	return _is_nighttime


func get_weather() -> WorldWeatherService.Weather:
	return _weather


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5
	draw_circle(center, radius, BUBBLE_COLOR)
	match _weather:
		WorldWeatherService.Weather.SUNNY:
			if _is_nighttime:
				_draw_moon(center)
			else:
				_draw_sun(center)
		WorldWeatherService.Weather.CLOUDY:
			_draw_cloud(center + Vector2(0.0, 1.0))
		WorldWeatherService.Weather.RAINY:
			_draw_cloud(center + Vector2(0.0, -2.0))
			for x_offset: float in PackedFloat32Array([-6.0, 0.0, 6.0]):
				draw_line(
					center + Vector2(x_offset + 1.0, 5.0),
					center + Vector2(x_offset - 1.0, 9.0),
					RAIN_COLOR,
					2.0,
					true,
				)
		WorldWeatherService.Weather.FOGGY:
			for y_offset: float in PackedFloat32Array([-6.0, 0.0, 6.0]):
				draw_line(
					center + Vector2(-9.0, y_offset),
					center + Vector2(9.0, y_offset),
					ICON_COLOR,
					2.0,
					true,
				)


func _draw_sun(center: Vector2) -> void:
	draw_circle(center, 5.0, SUN_COLOR)
	for index: int in 8:
		var angle: float = TAU * float(index) / 8.0
		var direction := Vector2(cos(angle), sin(angle))
		draw_line(
			center + direction * 8.0,
			center + direction * 11.0,
			SUN_COLOR,
			2.0,
			true,
		)


func _draw_moon(center: Vector2) -> void:
	draw_circle(center, 8.0, MOON_COLOR)
	draw_circle(center + Vector2(4.0, -2.0), 7.0, BUBBLE_COLOR)


func _update_tooltip() -> void:
	tooltip_text = (
		"clear"
		if _weather == WorldWeatherService.Weather.SUNNY
		else WorldWeatherService.weather_name(_weather)
	)


func _draw_cloud(center: Vector2) -> void:
	draw_circle(center + Vector2(-5.0, 0.0), 5.0, ICON_COLOR)
	draw_circle(center + Vector2(0.0, -3.0), 6.0, ICON_COLOR)
	draw_circle(center + Vector2(6.0, 0.0), 5.0, ICON_COLOR)
	draw_rect(Rect2(center + Vector2(-9.0, 0.0), Vector2(18.0, 5.0)), ICON_COLOR)
