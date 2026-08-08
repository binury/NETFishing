class_name ControllerFocusPresentation
extends Node

const CONTROLLER_MOTION_THRESHOLD: float = 0.35
const INVERSION_DISABLED_META: StringName = &"controller_focus_inversion_disabled"

var _controller_active: bool = false
var _focused_item: CanvasItem
var _original_material: Material
var _inversion_material: ShaderMaterial


func _ready() -> void:
	var inversion_shader := Shader.new()
	inversion_shader.code = """
shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 source = texture(TEXTURE, UV) * COLOR;
	COLOR = vec4(vec3(1.0) - source.rgb, source.a);
}
"""
	_inversion_material = ShaderMaterial.new()
	_inversion_material.shader = inversion_shader
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	set_process_input(true)
	set_process(true)


func _exit_tree() -> void:
	_restore_focused_item()


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			_set_controller_active(true)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= (
			CONTROLLER_MOTION_THRESHOLD
		):
			_set_controller_active(true)
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			_set_controller_active(false)
	elif event is InputEventKey:
		if (event as InputEventKey).pressed:
			_set_controller_active(false)


func _process(_delta: float) -> void:
	if not is_instance_valid(_focused_item):
		_focused_item = null
		_original_material = null
		return
	var focus_owner: Control = get_viewport().gui_get_focus_owner()
	if (
		focus_owner != _focused_item
		or not focus_owner.is_visible_in_tree()
		or focus_owner.focus_mode == Control.FOCUS_NONE
		or bool(focus_owner.get_meta(INVERSION_DISABLED_META, false))
	):
		_apply_to_focus(focus_owner)


func _set_controller_active(active: bool) -> void:
	if _controller_active == active:
		return
	_controller_active = active
	_apply_to_focus(get_viewport().gui_get_focus_owner())


func _on_focus_changed(control: Control) -> void:
	_apply_to_focus(control)


func _apply_to_focus(control: Control) -> void:
	_restore_focused_item()
	if (
		not _controller_active
		or control == null
		or not control.is_visible_in_tree()
		or control.focus_mode == Control.FOCUS_NONE
		or bool(control.get_meta(INVERSION_DISABLED_META, false))
	):
		return
	_focused_item = control
	_original_material = _focused_item.material
	_focused_item.material = _inversion_material


func _restore_focused_item() -> void:
	if is_instance_valid(_focused_item):
		_focused_item.material = _original_material
	_focused_item = null
	_original_material = null
