class_name FileDialogController
extends Node

const FileDialogControllerNavigationType = preload(
	"res://ui/file_dialog_controller_navigation.gd"
)

var _text_entry_request: Callable
var _text_entry_is_open: Callable
var _tracked_dialogs: Dictionary[int, WeakRef] = {}


func setup_text_entry(
	request: Callable,
	is_open: Callable = Callable(),
) -> void:
	_text_entry_request = request
	_text_entry_is_open = is_open


func track_dialog(dialog: FileDialog) -> void:
	if dialog != null:
		_tracked_dialogs[dialog.get_instance_id()] = weakref(dialog)


func _process(_delta: float) -> void:
	if _text_entry_is_active():
		return
	for instance_id: int in _tracked_dialogs.keys():
		var reference: WeakRef = _tracked_dialogs[instance_id]
		var dialog := reference.get_ref() as FileDialog
		if dialog == null or not is_instance_valid(dialog):
			_tracked_dialogs.erase(instance_id)
			continue
		if not dialog.visible:
			continue
		FileDialogControllerNavigationType.configure(dialog)
		_connect_text_controls(dialog)


func _input(event: InputEvent) -> void:
	if _text_entry_is_active():
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	var scope: Window = _active_scope()
	if scope == null:
		return
	var focused: Control = scope.gui_get_focus_owner()
	if focused == null:
		return
	var direction: Vector2 = _controller_direction(event)
	var item_list := focused as ItemList
	if (
		item_list != null
		and direction != Vector2.ZERO
		and FileDialogControllerNavigationType.move_from_item_list(
			item_list, direction
		)
	):
		get_viewport().set_input_as_handled()
		return
	var button_event := event as InputEventJoypadButton
	if (
		button_event != null
		and button_event.pressed
		and event.is_action_pressed(&"ui_accept")
		and (focused is LineEdit or focused is TextEdit)
		and _text_entry_request.is_valid()
		and bool(_text_entry_request.call(focused))
	):
		get_viewport().set_input_as_handled()


func _active_scope() -> Window:
	for reference_value: WeakRef in _tracked_dialogs.values():
		var dialog := reference_value.get_ref() as FileDialog
		if dialog == null or not is_instance_valid(dialog) or not dialog.visible:
			continue
		return FileDialogControllerNavigationType.active_scope(dialog)
	return null


func _controller_direction(event: InputEvent) -> Vector2:
	if event.is_action_pressed(&"ui_up"):
		return Vector2.UP
	if event.is_action_pressed(&"ui_down"):
		return Vector2.DOWN
	if event.is_action_pressed(&"ui_left"):
		return Vector2.LEFT
	if event.is_action_pressed(&"ui_right"):
		return Vector2.RIGHT
	return Vector2.ZERO


func _connect_text_controls(dialog: FileDialog) -> void:
	var scope: Window = FileDialogControllerNavigationType.active_scope(dialog)
	for control: Control in (
		FileDialogControllerNavigationType.interactive_controls(scope)
	):
		if not (control is LineEdit or control is TextEdit):
			continue
		var callback := _on_text_gui_input.bind(control)
		if not control.gui_input.is_connected(callback):
			control.gui_input.connect(callback)


func _on_text_gui_input(event: InputEvent, control: Control) -> void:
	var button_event := event as InputEventJoypadButton
	if (
		button_event == null
		or not button_event.pressed
		or (
			button_event.button_index != JOY_BUTTON_A
			and not event.is_action_pressed(&"ui_accept")
		)
		or not _text_entry_request.is_valid()
	):
		return
	if bool(_text_entry_request.call(control)):
		control.accept_event()


func _text_entry_is_active() -> bool:
	return (
		_text_entry_is_open.is_valid()
		and bool(_text_entry_is_open.call())
	)
