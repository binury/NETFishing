class_name BubbleTransitionFlurry
extends Control

const BUBBLE_TEXTURES: Array[Texture2D] = [
	preload("res://ui/assets/title/bubbles/bubble1.png"),
	preload("res://ui/assets/title/bubbles/bubble2.png"),
	preload("res://ui/assets/title/bubbles/bubble3.png"),
]
const BUBBLE_COUNT_MIN: int = 4
const BUBBLE_COUNT_MAX: int = 5
const BUBBLE_SCALE_MIN: float = 0.65
const BUBBLE_SCALE_MAX: float = 1.15
const BUBBLE_OPACITY_MIN: float = 0.55
const BUBBLE_OPACITY_MAX: float = 0.90
const BUBBLE_DRIFT_MIN: float = 10.0
const BUBBLE_DRIFT_MAX: float = 45.0
const BUBBLE_WOBBLE_MIN: float = 3.0
const BUBBLE_WOBBLE_MAX: float = 9.0
const BUBBLE_TRAVEL_DURATION_MIN: float = 7.0
const BUBBLE_TRAVEL_DURATION_MAX: float = 14.0
const BUBBLE_EDGE_MARGIN: float = 16.0
const BURST_X_MIN: float = 0.36
const BURST_X_MAX: float = 0.64
const BURST_Y_MIN: float = 0.60
const BURST_Y_MAX: float = 0.78
const MAX_ACTIVE_BUBBLES: int = 30

var _rng := RandomNumberGenerator.new()
var _generation: int = 0
var _bubbles: Array[TextureRect] = []
var _tweens: Dictionary[int, Tween] = {}


func _ready() -> void:
	_rng.randomize()


func emit_flurry() -> void:
	if not visible or BUBBLE_TEXTURES.is_empty():
		return
	var bubble_count: int = _rng.randi_range(
		BUBBLE_COUNT_MIN,
		BUBBLE_COUNT_MAX
	)
	for _bubble_index: int in bubble_count:
		if not _spawn_bubble(
			_rng.randf_range(BURST_X_MIN, BURST_X_MAX),
			_rng.randf_range(BURST_Y_MIN, BURST_Y_MAX)
		):
			break


func clear_flurries() -> void:
	_generation += 1
	for tween: Tween in _tweens.values():
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	for bubble: TextureRect in _bubbles:
		if is_instance_valid(bubble):
			bubble.queue_free()
	_bubbles.clear()


func get_active_bubble_count() -> int:
	return _bubbles.size()


func _spawn_bubble(normalized_x: float, start_y_ratio: float) -> bool:
	if _bubbles.size() >= MAX_ACTIVE_BUBBLES:
		return false
	var layer_size: Vector2 = size
	if layer_size.x <= 1.0 or layer_size.y <= 1.0:
		return false
	var texture: Texture2D = BUBBLE_TEXTURES[
		_rng.randi_range(0, BUBBLE_TEXTURES.size() - 1)
	]
	var presentation_size: Vector2 = texture.get_size() * _rng.randf_range(
		BUBBLE_SCALE_MIN,
		BUBBLE_SCALE_MAX
	)
	var bubble := TextureRect.new()
	bubble.name = "TransitionBubble"
	bubble.texture = texture
	bubble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bubble.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bubble.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.size = presentation_size
	bubble.modulate.a = _rng.randf_range(
		BUBBLE_OPACITY_MIN,
		BUBBLE_OPACITY_MAX
	)
	add_child(bubble)
	_bubbles.append(bubble)

	var drift_direction: float = (
		1.0 if _rng.randi_range(0, 1) == 1 else -1.0
	)
	var horizontal_drift: float = _rng.randf_range(
		BUBBLE_DRIFT_MIN,
		BUBBLE_DRIFT_MAX
	) * drift_direction
	var wobble_amplitude: float = _rng.randf_range(
		BUBBLE_WOBBLE_MIN,
		BUBBLE_WOBBLE_MAX
	)
	var wobble_cycles: float = _rng.randf_range(0.8, 1.6)
	var wobble_phase: float = _rng.randf_range(0.0, TAU)
	var full_start_y: float = (
		layer_size.y + presentation_size.y + BUBBLE_EDGE_MARGIN
	)
	var start_y: float = (
		start_y_ratio * layer_size.y - presentation_size.y * 0.5
	)
	var end_y: float = -presentation_size.y - BUBBLE_EDGE_MARGIN
	var full_distance: float = maxf(full_start_y - end_y, 1.0)
	var remaining_distance: float = maxf(start_y - end_y, 1.0)
	var travel_duration: float = _rng.randf_range(
		BUBBLE_TRAVEL_DURATION_MIN,
		BUBBLE_TRAVEL_DURATION_MAX
	) * remaining_distance / full_distance
	var generation: int = _generation
	_update_bubble(
		0.0,
		bubble,
		normalized_x,
		start_y_ratio,
		horizontal_drift,
		wobble_amplitude,
		wobble_cycles,
		wobble_phase,
		generation
	)
	var tween: Tween = create_tween()
	_tweens[bubble.get_instance_id()] = tween
	tween.tween_method(
		_update_bubble.bind(
			bubble,
			normalized_x,
			start_y_ratio,
			horizontal_drift,
			wobble_amplitude,
			wobble_cycles,
			wobble_phase,
			generation
		),
		0.0,
		1.0,
		travel_duration
	)
	tween.finished.connect(
		_finish_bubble.bind(bubble, generation),
		CONNECT_ONE_SHOT
	)
	return true


func _update_bubble(
	progress: float,
	bubble: TextureRect,
	normalized_x: float,
	start_y_ratio: float,
	horizontal_drift: float,
	wobble_amplitude: float,
	wobble_cycles: float,
	wobble_phase: float,
	generation: int,
) -> void:
	if generation != _generation or not is_instance_valid(bubble):
		return
	var start_y: float = start_y_ratio * size.y - bubble.size.y * 0.5
	var end_y: float = -bubble.size.y - BUBBLE_EDGE_MARGIN
	var wobble: float = sin(
		wobble_phase + progress * TAU * wobble_cycles
	) * wobble_amplitude
	bubble.position = Vector2(
		normalized_x * size.x
		+ horizontal_drift * progress
		+ wobble
		- bubble.size.x * 0.5,
		lerpf(start_y, end_y, progress)
	)


func _finish_bubble(bubble: TextureRect, generation: int) -> void:
	if generation != _generation or not is_instance_valid(bubble):
		return
	_tweens.erase(bubble.get_instance_id())
	_bubbles.erase(bubble)
	bubble.queue_free()


func _exit_tree() -> void:
	clear_flurries()
