class_name ControllerFocusRecovery
extends Node

const CONTROLLER_AXIS_THRESHOLD: float = 0.35
const SEMANTIC_MATCH_BONUS: float = 1000000.0
const KEYBOARD_NAVIGATION_ACTIONS: Array[StringName] = [
	&"ui_accept",
	&"ui_cancel",
	&"ui_up",
	&"ui_down",
	&"ui_left",
	&"ui_right",
	&"ui_focus_next",
	&"ui_focus_prev",
	&"ui_page_up",
	&"ui_page_down",
	&"ui_home",
	&"ui_end",
]

var _controller_active: bool = false
var _focus_navigation_active: bool = false
var _last_focus_center: Vector2 = Vector2.ZERO
var _last_focus_key: String = ""
var _scope_chain: Array[WeakRef] = []
var _pending_focus: WeakRef
var _pointer_button_down: bool = false
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
			_pointer_button_down = false
			_controller_active = true
			_focus_navigation_active = true
			if button_event.button_index == JOY_BUTTON_LEFT_SHOULDER:
				_recovery_generation += 1
				_scope_chain.clear()
				_pending_focus = null
				return
			_request_pending_focus()
		return
	if event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= (
			CONTROLLER_AXIS_THRESHOLD
		):
			_pointer_button_down = false
			_controller_active = true
			_focus_navigation_active = true
			_request_pending_focus()
		return
	if event is InputEventMouseMotion:
		_pointer_button_down = (
			(event as InputEventMouseMotion).button_mask != 0
		)
		_leave_focus_navigation(not _pointer_button_down)
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index in [
			MOUSE_BUTTON_LEFT,
			MOUSE_BUTTON_RIGHT,
			MOUSE_BUTTON_MIDDLE,
		]:
			_pointer_button_down = mouse_button.pressed
			_leave_focus_navigation(false)
			if not mouse_button.pressed:
				_release_current_pointer_focus.call_deferred()
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		_pointer_button_down = false
		_controller_active = false
		if _is_keyboard_navigation_event(event):
			_focus_navigation_active = true
			_request_pending_focus()
		else:
			_leave_focus_navigation()


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
		if _focus_navigation_active:
			_pending_focus = null
			if _controller_active and control is BaseButton:
				_remember_focus(control)
			return
		if _keeps_pointer_focus(control):
			return
		if _is_focusable(control):
			_pending_focus = weakref(control)
		_release_focus_if_inactive.call_deferred(control)
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
		):
			continue
		if not scope.is_visible_in_tree():
			_scope_chain.clear()
			return
		var replacement := _best_replacement_in(scope)
		if replacement != null:
			replacement.grab_focus()
		else:
			_scope_chain.clear()
		return
	_scope_chain.clear()


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
		or control.focus_mode not in [Control.FOCUS_CLICK, Control.FOCUS_ALL]
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


func _leave_focus_navigation(release_focus: bool = true) -> void:
	_controller_active = false
	_focus_navigation_active = false
	_recovery_generation += 1
	_scope_chain.clear()
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner == null or _keeps_pointer_focus(focus_owner):
		return
	if _is_focusable(focus_owner):
		_pending_focus = weakref(focus_owner)
	if release_focus:
		_release_focus_if_inactive.call_deferred(focus_owner)


func _release_focus_if_inactive(control: Control) -> void:
	if (
		_focus_navigation_active
		or _pointer_button_down
		or control == null
		or not is_instance_valid(control)
		or get_viewport().gui_get_focus_owner() != control
		or _keeps_pointer_focus(control)
	):
		return
	get_viewport().gui_release_focus()


func _release_current_pointer_focus() -> void:
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if focus_owner != null:
		_release_focus_if_inactive(focus_owner)


func _request_pending_focus() -> void:
	if (
		not _focus_navigation_active
		or _pending_focus == null
		or get_viewport().gui_get_focus_owner() != null
	):
		return
	_restore_pending_focus.call_deferred(_recovery_generation)


func _restore_pending_focus(generation: int) -> void:
	if (
		generation != _recovery_generation
		or not _focus_navigation_active
		or _pending_focus == null
		or get_viewport().gui_get_focus_owner() != null
	):
		return
	var target := _pending_focus.get_ref() as Control
	if not _is_focusable(target):
		_pending_focus = null
		return
	_pending_focus = null
	target.grab_focus()


func _is_keyboard_navigation_event(event: InputEvent) -> bool:
	if event.is_action_pressed(&"open_backpack"):
		return false
	if (
		event.is_action_pressed(&"ui_cancel")
		and get_viewport().gui_get_focus_owner() == null
	):
		return false
	for action: StringName in KEYBOARD_NAVIGATION_ACTIONS:
		if event.is_action_pressed(action):
			return true
	return false


func _keeps_pointer_focus(control: Control) -> bool:
	return control is LineEdit or control is TextEdit
