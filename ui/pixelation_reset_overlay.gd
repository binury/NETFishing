class_name PixelationResetOverlay
extends CanvasLayer

signal reset_requested
signal return_to_settings_requested

@onready var _reset_button: Button = %ResetPixelationButton


func _ready() -> void:
	_reset_button.pressed.connect(reset_requested.emit)
	_reset_button.gui_input.connect(_on_reset_button_gui_input)


func set_settings_open(is_open: bool) -> void:
	visible = is_open
	if not is_open and _reset_button.has_focus():
		_reset_button.release_focus()


func focus_reset_button() -> void:
	if visible:
		_reset_button.grab_focus()


func _on_reset_button_gui_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("ui_up")
		or event.is_action_pressed("ui_focus_prev")
	):
		return_to_settings_requested.emit()
		get_viewport().set_input_as_handled()
