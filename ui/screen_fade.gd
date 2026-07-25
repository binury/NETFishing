class_name ScreenFade
extends ColorRect

signal transition_completed(generation: int, faded_to_black: bool)

@export_range(0.01, 3.0, 0.01) var fade_out_duration: float = 0.4
@export_range(0.01, 3.0, 0.01) var fade_in_duration: float = 0.45

var _fade_tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	visible = false


func fade_to_black(generation: int) -> void:
	_start_fade(1.0, fade_out_duration, generation, true)


func fade_from_black(generation: int) -> void:
	visible = true
	modulate.a = 1.0
	_start_fade(0.0, fade_in_duration, generation, false)


func reset_immediately() -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null
	modulate.a = 0.0
	visible = false


func _start_fade(
	target_alpha: float,
	duration: float,
	generation: int,
	faded_to_black: bool,
) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	visible = true
	_fade_tween = create_tween()
	_fade_tween.set_trans(Tween.TRANS_QUAD)
	_fade_tween.set_ease(
		Tween.EASE_IN if faded_to_black else Tween.EASE_OUT
	)
	_fade_tween.tween_property(
		self,
		"modulate:a",
		target_alpha,
		maxf(duration, 0.01)
	)
	_fade_tween.finished.connect(
		_on_fade_finished.bind(generation, faded_to_black),
		CONNECT_ONE_SHOT
	)


func _on_fade_finished(generation: int, faded_to_black: bool) -> void:
	_fade_tween = null
	if not faded_to_black:
		visible = false
	transition_completed.emit(generation, faded_to_black)
