class_name ProfilePreview
extends SubViewportContainer

@export_range(0.1, 2.0, 0.05) var drag_sensitivity: float = 0.012
@export_range(0.1, 4.0, 0.1) var keyboard_speed: float = 1.8

@onready var _preview_root: Node3D = %PreviewRoot

var _dragging: bool = false
var _visuals: Node3D


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	gui_input.connect(_on_gui_input)
	_visuals = PlayerVisualPresenter.instantiate_visuals()
	_preview_root.add_child(_visuals)
	var rod := _visuals.find_child("FishingRod", true, false) as Node3D
	if rod != null:
		rod.visible = false
	var catch_display := _visuals.find_child("CatchDisplay", true, false) as Node3D
	if catch_display != null:
		catch_display.visible = false


func apply_appearance_profile(profile: Dictionary) -> void:
	if _visuals != null:
		PlayerVisualPresenter.apply_appearance(_visuals, profile)


func reset_view() -> void:
	_preview_root.rotation.y = 0.0


func _process(delta: float) -> void:
	if not has_focus():
		return
	var axis := Input.get_axis("ui_left", "ui_right")
	var right_stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(right_stick) > 0.2:
		axis = right_stick
	if absf(axis) > 0.1:
		_rotate(axis * keyboard_speed * delta)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			grab_focus()
			accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_rotate(event.relative.x * drag_sensitivity)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_dragging = false


func _rotate(amount: float) -> void:
	_preview_root.rotation.y = fposmod(_preview_root.rotation.y + amount, TAU)
