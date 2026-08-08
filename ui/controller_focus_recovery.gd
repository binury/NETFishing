class_name ControllerFocusRecovery
extends Node

const CONTROLLER_AXIS_THRESHOLD: float = 0.35
const SEMANTIC_MATCH_BONUS: float = 1000000.0

var _controller_active: bool = false
var _last_focus_center: Vector2 = Vector2.ZERO
var _last_focus_key: String = ""
var _scope_chain: Array[WeakRef] = []
var _recovery_generation: int = 0


func _ready() -> void:
	set_process_input(true)
	set_process(true)
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)


func _exit_tree() -> void:
	var viewport := get_viewport()
	if viewport.gui_focus_changed.is_connected(_on_gui_focus_changed):
		viewport.gui_focus_changed.disconnect(_on_gui_focus_changed)


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		if button_event.pressed:
			_controller_active = true
			if button_event.button_index == JOY_BUTTON_LEFT_SHOULDER:
				_recovery_generation += 1
				_scope_chain.clear()
		return
	if event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= (
			CONTROLLER_AXIS_THRESHOLD
		):
			_controller_active = true
		return
	if event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			_controller_active = false
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		_controller_active = false


func _process(_delta: float) -> void:
	if (
		_controller_active
		and not _scope_chain.is_empty()
		and get_viewport().gui_get_focus_owner() == null
	):
		_recover_focus(_recovery_generation)


func _on_gui_focus_changed(control: Control) -> void:
	_recovery_generation += 1
	if control != null:
		if _controller_active and control is BaseButton:
			_remember_focus(control)
		return
	if not _controller_active or _scope_chain.is_empty():
		return
	var generation: int = _recovery_generation
	_recover_focus.call_deferred(generation)


func _remember_focus(control: Control) -> void:
	_last_focus_center = control.get_global_rect().get_center()
	_last_focus_key = _semantic_key(control)
	_scope_chain.clear()
	var recovery_root: Node = get_parent()
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		if ancestor is Control:
			_scope_chain.append(weakref(ancestor))
		if ancestor == recovery_root:
			break
		ancestor = ancestor.get_parent()


func _recover_focus(generation: int) -> void:
	if generation != _recovery_generation:
		return
	if not _controller_active or get_viewport().gui_get_focus_owner() != null:
		return
	for scope_reference: WeakRef in _scope_chain:
		var scope := scope_reference.get_ref() as Control
		if (
			scope == null
			or not is_instance_valid(scope)
			or not scope.is_inside_tree()
			or not scope.is_visible_in_tree()
		):
			continue
		var replacement := _best_replacement_in(scope)
		if replacement != null:
			replacement.grab_focus()
			return


func _best_replacement_in(scope: Control) -> Control:
	var best: Control = null
	var best_score: float = INF
	for node: Node in scope.find_children("*", "Control", true, false):
		var candidate := node as Control
		if not _is_focusable(candidate):
			continue
		var distance: float = candidate.get_global_rect().get_center().distance_squared_to(
			_last_focus_center
		)
		if not _last_focus_key.is_empty() and _semantic_key(candidate) == _last_focus_key:
			distance -= SEMANTIC_MATCH_BONUS
		if distance < best_score:
			best = candidate
			best_score = distance
	return best


func _is_focusable(control: Control) -> bool:
	if (
		control == null
		or not control.is_inside_tree()
		or not control.is_visible_in_tree()
		or control.focus_mode == Control.FOCUS_NONE
	):
		return false
	var button := control as BaseButton
	return button == null or not button.disabled


func _semantic_key(control: Control) -> String:
	if control.has_meta(&"controller_focus_key"):
		return str(control.get_meta(&"controller_focus_key"))
	var button := control as Button
	var label: String = button.text if button != null else ""
	var tooltip: String = control.tooltip_text
	tooltip = tooltip.trim_suffix(" (show variants)")
	tooltip = tooltip.trim_suffix(" (hide variants)")
	return "%s|%s|%s" % [control.get_class(), label, tooltip]
