class_name BubbleConfirmationPage
extends Control

signal confirmed
signal cancelled

enum InitialFocus {
	CONFIRM,
	CANCEL,
}

@export var cluster_path: NodePath = ^"BubbleCluster"
@export var message_path: NodePath = ^"BubbleCluster/MessageBubble"
@export var message_label_path: NodePath = (
	^"BubbleCluster/MessageBubble/MessageLabel"
)
@export var confirm_path: NodePath = ^"BubbleCluster/ConfirmButton"
@export var confirm_label_path: NodePath = (
	^"BubbleCluster/ConfirmButton/ConfirmLabel"
)
@export var cancel_path: NodePath = ^"BubbleCluster/CancelButton"
@export var cancel_label_path: NodePath = (
	^"BubbleCluster/CancelButton/CancelLabel"
)
@export var maximum_layout_size: Vector2 = Vector2(720.0, 520.0)
@export var compact_maximum_layout_size: Vector2 = Vector2(544.0, 400.0)
@export var compact_width_threshold: float = 680.0
@export var compact_height_threshold: float = 500.0
@export_range(0.0, 128.0, 1.0) var transition_safe_margin: float = 24.0

var _cluster: BubbleCluster
var _message: BubbleButton
var _message_label: Label
var _confirm_button: BubbleButton
var _confirm_label: Label
var _cancel_button: BubbleButton
var _cancel_label: Label
var _bubbles: Array[BubbleButton] = []
var _initial_focus: InitialFocus = InitialFocus.CONFIRM
var _resting_cluster_position: Vector2 = Vector2.ZERO
var _transition: Tween
var _transition_generation: int = 0
var _is_transitioning: bool = false


func _ready() -> void:
	_cluster = get_node(cluster_path) as BubbleCluster
	_message = get_node(message_path) as BubbleButton
	_message_label = get_node(message_label_path) as Label
	_confirm_button = get_node(confirm_path) as BubbleButton
	_confirm_label = get_node(confirm_label_path) as Label
	_cancel_button = get_node(cancel_path) as BubbleButton
	_cancel_label = get_node(cancel_label_path) as Label
	_bubbles = [_message, _confirm_button, _cancel_button]
	_cluster.configure(_bubbles)
	_message.focus_mode = Control.FOCUS_NONE
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_button.pressed.connect(confirmed.emit)
	_cancel_button.pressed.connect(cancelled.emit)
	_configure_focus()
	resized.connect(_update_layout)
	call_deferred("_update_layout")
	hide_page()


func configure(
	message_text: String,
	confirm_text: String,
	cancel_text: String = "cancel",
	initial_focus: InitialFocus = InitialFocus.CONFIRM,
) -> void:
	_message_label.text = message_text
	_confirm_label.text = confirm_text
	_cancel_label.text = cancel_text
	_initial_focus = initial_focus


func transition_in(duration: float, completed: Callable) -> void:
	_transition_generation += 1
	_cancel_transition()
	show()
	_is_transitioning = true
	_set_interactive(false)
	set_process(true)
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
		_finish_transition_in.bind(generation, completed),
		CONNECT_ONE_SHOT
	)


func transition_out(duration: float, completed: Callable) -> void:
	if not visible or _is_transitioning:
		return
	_transition_generation += 1
	_cancel_transition()
	_is_transitioning = true
	_set_interactive(false)
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


func hide_page() -> void:
	_transition_generation += 1
	_cancel_transition()
	_is_transitioning = false
	_set_interactive(false)
	set_process(false)
	hide()
	if _cluster != null:
		_cluster.position = _resting_cluster_position


func lock_interaction() -> void:
	_set_interactive(false)


func is_transitioning() -> bool:
	return _is_transitioning


func focus_initial() -> void:
	var target: BubbleButton = (
		_cancel_button
		if _initial_focus == InitialFocus.CANCEL
		else _confirm_button
	)
	if target.visible and target.focus_mode != Control.FOCUS_NONE:
		target.grab_focus()


func _process(delta: float) -> void:
	if visible:
		_cluster.advance_motion(delta)


func _update_layout() -> void:
	if not is_node_ready() or _cluster == null:
		return
	var compact: bool = (
		size.x < compact_width_threshold
		or size.y < compact_height_threshold
	)
	var layout_maximum: Vector2 = (
		compact_maximum_layout_size
		if compact
		else maximum_layout_size
	)
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


func _configure_focus() -> void:
	var confirm_to_cancel: NodePath = _confirm_button.get_path_to(
		_cancel_button
	)
	var cancel_to_confirm: NodePath = _cancel_button.get_path_to(
		_confirm_button
	)
	_confirm_button.focus_neighbor_left = confirm_to_cancel
	_confirm_button.focus_neighbor_right = confirm_to_cancel
	_confirm_button.focus_neighbor_top = confirm_to_cancel
	_confirm_button.focus_neighbor_bottom = confirm_to_cancel
	_cancel_button.focus_neighbor_left = cancel_to_confirm
	_cancel_button.focus_neighbor_right = cancel_to_confirm
	_cancel_button.focus_neighbor_top = cancel_to_confirm
	_cancel_button.focus_neighbor_bottom = cancel_to_confirm


func _set_interactive(interactive: bool) -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if interactive
		else Control.MOUSE_FILTER_IGNORE
	)
	for bubble: BubbleButton in [_confirm_button, _cancel_button]:
		if not interactive and bubble.has_focus():
			bubble.release_focus()
		bubble.focus_mode = (
			Control.FOCUS_ALL if interactive else Control.FOCUS_NONE
		)
		bubble.mouse_filter = (
			Control.MOUSE_FILTER_STOP
			if interactive
			else Control.MOUSE_FILTER_IGNORE
		)


func _finish_transition_in(
	generation: int,
	completed: Callable,
) -> void:
	if generation != _transition_generation or not visible:
		return
	_transition = null
	_is_transitioning = false
	_cluster.position = _resting_cluster_position
	_set_interactive(true)
	focus_initial()
	completed.call()


func _finish_transition_out(
	generation: int,
	completed: Callable,
) -> void:
	if generation != _transition_generation or not visible:
		return
	_transition = null
	_is_transitioning = false
	hide()
	_cluster.position = _resting_cluster_position
	set_process(false)
	completed.call()


func _cancel_transition() -> void:
	if _transition != null:
		_transition.kill()
		_transition = null
