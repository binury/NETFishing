class_name SettingsBubblePage
extends Control

@export var page_id: StringName
@export var cluster_path: NodePath = ^"BubbleCluster"
@export var bubble_paths: Array[NodePath] = []
@export var focus_paths: Array[NodePath] = []
@export var initial_focus_path: NodePath
@export var back_focus_path: NodePath
@export var maximum_layout_size: Vector2 = Vector2(720.0, 520.0)
@export var compact_maximum_layout_size: Vector2 = Vector2.ZERO
@export var compact_width_threshold: float = 680.0
@export var compact_height_threshold: float = 500.0
@export_range(0.1, 2.0, 0.01) var outgoing_rise_duration: float = 1.70
@export_range(0.1, 2.0, 0.01) var incoming_rise_duration: float = 1.85
@export_range(0.0, 128.0, 1.0) var transition_safe_margin: float = 24.0

var _cluster: BubbleCluster
var _bubbles: Array[BubbleButton] = []
var _focus_bubbles: Array[BubbleButton] = []
var _transition: Tween
var _transition_generation: int = 0
var _resting_cluster_position: Vector2 = Vector2.ZERO
var _is_transitioning: bool = false


func _ready() -> void:
	_cluster = get_node(cluster_path) as BubbleCluster
	for path: NodePath in bubble_paths:
		var bubble := get_node(path) as BubbleButton
		if bubble != null:
			_bubbles.append(bubble)
	for path: NodePath in focus_paths:
		var bubble := get_node(path) as BubbleButton
		if bubble != null:
			_focus_bubbles.append(bubble)
	_cluster.configure(_bubbles)
	_configure_focus_order()
	resized.connect(_update_layout)
	call_deferred("_update_layout")
	set_process(false)


func show_page(should_focus: bool = true) -> void:
	_transition_generation += 1
	_cancel_transition()
	show()
	_is_transitioning = false
	_cluster.position = _resting_cluster_position
	set_process(true)
	_set_interactive(true)
	if should_focus:
		focus_initial()


func transition_out(
	completed: Callable,
	duration_override: float = -1.0,
) -> void:
	_transition_generation += 1
	_cancel_transition()
	_is_transitioning = true
	_set_interactive(false)
	set_process(true)
	var duration: float = (
		duration_override
		if duration_override > 0.0
		else outgoing_rise_duration
	)
	var generation: int = _transition_generation
	_transition = create_tween()
	_transition.tween_property(
		_cluster,
		"position:y",
		-_cluster.size.y - transition_safe_margin,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.finished.connect(
		_finish_transition_out.bind(generation, completed),
		CONNECT_ONE_SHOT
	)


func transition_in(
	should_focus: bool,
	completed: Callable,
	duration_override: float = -1.0,
) -> void:
	_transition_generation += 1
	_cancel_transition()
	show()
	_is_transitioning = true
	_set_interactive(false)
	set_process(true)
	var duration: float = (
		duration_override
		if duration_override > 0.0
		else incoming_rise_duration
	)
	_cluster.position = Vector2(
		_resting_cluster_position.x,
		size.y + transition_safe_margin
	)
	var generation: int = _transition_generation
	_transition = create_tween()
	_transition.tween_property(
		_cluster,
		"position",
		_resting_cluster_position,
		duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_transition.finished.connect(
		_finish_transition_in.bind(generation, should_focus, completed),
		CONNECT_ONE_SHOT
	)


func hide_page() -> void:
	_transition_generation += 1
	_cancel_transition()
	_is_transitioning = false
	_set_interactive(false)
	set_process(false)
	hide()
	if _cluster != null:
		_cluster.position = _resting_cluster_position


func focus_initial() -> void:
	var initial := get_node_or_null(initial_focus_path) as Control
	if initial != null and initial.visible and initial.focus_mode != Control.FOCUS_NONE:
		initial.grab_focus()


func focus_back() -> void:
	var back := get_node_or_null(back_focus_path) as Control
	if back != null and back.visible and back.focus_mode != Control.FOCUS_NONE:
		back.grab_focus()


func get_page_id() -> StringName:
	return page_id


func _process(delta: float) -> void:
	if visible:
		_cluster.advance_motion(delta)


func _update_layout() -> void:
	if not is_node_ready() or _cluster == null:
		return
	var compact: bool = false
	var layout_maximum: Vector2 = maximum_layout_size
	if compact and compact_maximum_layout_size != Vector2.ZERO:
		layout_maximum = compact_maximum_layout_size
	var field_size := Vector2(
		minf(size.x, layout_maximum.x),
		minf(size.y, layout_maximum.y)
	)
	field_size.x = maxf(1.0, field_size.x)
	field_size.y = maxf(1.0, field_size.y)
	_resting_cluster_position = (size - field_size) * 0.5
	if not _is_transitioning:
		_cluster.position = _resting_cluster_position
	_cluster.size = field_size
	_cluster.apply_layout(field_size, compact)


func _configure_focus_order() -> void:
	for bubble: BubbleButton in _bubbles:
		bubble.focus_mode = Control.FOCUS_NONE
	for index: int in _focus_bubbles.size():
		var bubble: BubbleButton = _focus_bubbles[index]
		if index > 0:
			bubble.focus_neighbor_top = bubble.get_path_to(
				_focus_bubbles[index - 1]
			)
			bubble.focus_neighbor_left = bubble.focus_neighbor_top
		if index + 1 < _focus_bubbles.size():
			bubble.focus_neighbor_bottom = bubble.get_path_to(
				_focus_bubbles[index + 1]
			)
			bubble.focus_neighbor_right = bubble.focus_neighbor_bottom


func _set_interactive(interactive: bool) -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if interactive
		else Control.MOUSE_FILTER_IGNORE
	)
	for bubble: BubbleButton in _focus_bubbles:
		bubble.focus_mode = (
			Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
		)
		bubble.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if interactive
			else Control.MOUSE_FILTER_IGNORE
		)


func _finish_transition_out(generation: int, completed: Callable) -> void:
	if generation != _transition_generation or not visible:
		return
	_transition = null
	_is_transitioning = false
	hide()
	_cluster.position = _resting_cluster_position
	completed.call()


func _finish_transition_in(
	generation: int,
	should_focus: bool,
	completed: Callable,
) -> void:
	if generation != _transition_generation or not visible:
		return
	_transition = null
	_is_transitioning = false
	_cluster.position = _resting_cluster_position
	set_process(true)
	_set_interactive(true)
	if should_focus:
		focus_initial()
	completed.call()


func _cancel_transition() -> void:
	if _transition != null:
		_transition.kill()
		_transition = null
