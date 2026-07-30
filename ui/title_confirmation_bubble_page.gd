class_name TitleConfirmationBubblePage
extends Control

signal confirmed
signal cancelled

@export var cluster_path: NodePath = ^"BubbleCluster"
@export var prompt_path: NodePath = ^"BubbleCluster/PromptBubble"
@export var prompt_label_path: NodePath = ^"BubbleCluster/PromptBubble/PromptLabel"
@export var confirm_path: NodePath = ^"BubbleCluster/ConfirmButton"
@export var confirm_label_path: NodePath = (
	^"BubbleCluster/ConfirmButton/ConfirmLabel"
)
@export var cancel_path: NodePath = ^"BubbleCluster/CancelButton"
@export var multiline_confirm_neutral_size: Vector2 = Vector2(116.0, 116.0)
@export var multiline_confirm_compact_minimum_size: Vector2 = (
	Vector2(90.0, 90.0)
)
@export var compact_height_threshold: float = 250.0
@export_range(0.0, 128.0, 1.0) var transition_safe_margin: float = 24.0

var _cluster: BubbleCluster
var _prompt: BubbleButton
var _prompt_label: Label
var _confirm_button: BubbleButton
var _confirm_label: Label
var _cancel_button: BubbleButton
var _default_confirm_neutral_size: Vector2
var _default_confirm_compact_minimum_size: Vector2
var _bubbles: Array[BubbleButton] = []
var _resting_cluster_position: Vector2 = Vector2.ZERO
var _transition: Tween
var _transition_generation: int = 0
var _is_transitioning: bool = false


func _ready() -> void:
	_cluster = get_node(cluster_path) as BubbleCluster
	_prompt = get_node(prompt_path) as BubbleButton
	_prompt_label = get_node(prompt_label_path) as Label
	_confirm_button = get_node(confirm_path) as BubbleButton
	_confirm_label = get_node(confirm_label_path) as Label
	_cancel_button = get_node(cancel_path) as BubbleButton
	_default_confirm_neutral_size = _confirm_button.neutral_size
	_default_confirm_compact_minimum_size = (
		_confirm_button.compact_minimum_size
	)
	_bubbles = [_prompt, _confirm_button, _cancel_button]
	_cluster.configure(_bubbles)
	_prompt.focus_mode = Control.FOCUS_NONE
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_button.pressed.connect(confirmed.emit)
	_cancel_button.pressed.connect(cancelled.emit)
	_configure_focus()
	hide_page()


func configure(
	prompt_text: String,
	confirm_text: String,
	use_multiline_action_layout: bool = false,
) -> void:
	_prompt_label.text = prompt_text
	if use_multiline_action_layout:
		_confirm_button.text = ""
		_confirm_label.text = confirm_text
		_confirm_label.show()
		_confirm_button.label_control_path = ^"ConfirmLabel"
	else:
		_confirm_label.text = ""
		_confirm_label.hide()
		_confirm_button.label_control_path = NodePath()
		_confirm_button.text = confirm_text
	_confirm_button.apply_profile()
	_confirm_button.neutral_size = (
		multiline_confirm_neutral_size
		if use_multiline_action_layout
		else _default_confirm_neutral_size
	)
	_confirm_button.compact_minimum_size = (
		multiline_confirm_compact_minimum_size
		if use_multiline_action_layout
		else _default_confirm_compact_minimum_size
	)


func set_stage_rect(stage_rect: Rect2) -> void:
	if not is_node_ready():
		return
	var field_size := Vector2(
		maxf(1.0, stage_rect.size.x),
		maxf(1.0, stage_rect.size.y)
	)
	_resting_cluster_position = stage_rect.position
	_cluster.size = field_size
	_cluster.apply_layout(
		field_size,
		false
	)
	if not _is_transitioning:
		_cluster.position = _resting_cluster_position


func transition_in(
	_duration: float,
	completed: Callable,
) -> void:
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
	var duration := UIMotion.bubble_duration(
		_cluster.position.y - _resting_cluster_position.y
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


func transition_out(
	_duration: float,
	completed: Callable,
) -> void:
	if not visible or _is_transitioning:
		return
	_transition_generation += 1
	_cancel_transition()
	_is_transitioning = true
	_set_interactive(false)
	var target_y: float = -_cluster.size.y - transition_safe_margin
	var duration := UIMotion.bubble_duration(
		target_y - _cluster.position.y
	)
	var generation: int = _transition_generation
	_transition = create_tween()
	_transition.tween_property(
		_cluster,
		"position:y",
		target_y,
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


func focus_confirm() -> void:
	if (
		_confirm_button.visible
		and _confirm_button.focus_mode != Control.FOCUS_NONE
	):
		_confirm_button.grab_focus()


func _process(delta: float) -> void:
	if visible:
		_cluster.advance_motion(delta)


func _configure_focus() -> void:
	_confirm_button.focus_neighbor_left = _confirm_button.get_path_to(
		_cancel_button
	)
	_confirm_button.focus_neighbor_right = _confirm_button.focus_neighbor_left
	_confirm_button.focus_neighbor_top = _confirm_button.focus_neighbor_left
	_confirm_button.focus_neighbor_bottom = _confirm_button.focus_neighbor_left
	_cancel_button.focus_neighbor_left = _cancel_button.get_path_to(
		_confirm_button
	)
	_cancel_button.focus_neighbor_right = _cancel_button.focus_neighbor_left
	_cancel_button.focus_neighbor_top = _cancel_button.focus_neighbor_left
	_cancel_button.focus_neighbor_bottom = _cancel_button.focus_neighbor_left


func _set_interactive(interactive: bool) -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_PASS
		if interactive
		else Control.MOUSE_FILTER_IGNORE
	)
	for bubble: BubbleButton in [_confirm_button, _cancel_button]:
		if bubble == null:
			continue
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
	_set_interactive(true)
	focus_confirm()
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
