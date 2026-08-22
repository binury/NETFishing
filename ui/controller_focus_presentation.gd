class_name ControllerFocusPresentation
extends Node

const CONTROLLER_MOTION_THRESHOLD: float = 0.35
const FOCUS_ARROW_TEXTURE: Texture2D = preload(
	"res://ui/icons/pictograms/arrow_cursor.png"
)
const FOCUS_ARROW_SIZE: Vector2 = Vector2(64.0, 64.0)
const FOCUS_ARROW_ROTATION_DEGREES: float = 60.0
const FOCUS_ARROW_TIP_UV: Vector2 = Vector2(0.96875, 0.4453125)
const FOCUS_ARROW_TARGET_OVERLAP: Vector2 = Vector2(16.0, 16.0)
const FOCUS_ARROW_BUBBLE_OVERLAP: float = 10.0
const FOCUS_ARROW_SHADOW_OFFSET: Vector2 = Vector2(-6.0, -3.0)
const FOCUS_ARROW_SHADOW_COLOR: Color = Color(0.0, 0.035, 0.055, 0.56)
const FOCUS_ARROW_CANVAS_LAYER: int = 120

const FOCUS_STYLE_REPLACEMENTS: Dictionary[StringName, StringName] = {
	&"focus": &"normal",
	&"selected": &"",
	&"selected_focus": &"",
	&"cursor": &"",
	&"cursor_unfocused": &"",
}
const FOCUS_COLOR_REPLACEMENTS: Dictionary[StringName, StringName] = {
	&"font_focus_color": &"font_color",
	&"icon_focus_color": &"icon_normal_color",
	&"font_selected_color": &"font_color",
	&"font_hovered_selected_color": &"font_hovered_color",
}
const HOVER_STYLE_REPLACEMENTS: Dictionary[StringName, StringName] = {
	&"hover": &"normal",
	&"hover_pressed": &"pressed",
	&"hovered": &"",
	&"hovered_selected": &"",
}
const HOVER_COLOR_REPLACEMENTS: Dictionary[StringName, StringName] = {
	&"font_hover_color": &"font_color",
	&"icon_hover_color": &"icon_normal_color",
	&"font_hover_pressed_color": &"font_pressed_color",
	&"icon_hover_pressed_color": &"icon_pressed_color",
	&"font_hovered_color": &"font_color",
	&"font_hovered_selected_color": &"font_color",
}

var _controller_active: bool = false
var _virtual_pointer_active: bool = false
var _navigation_focus_active: bool = false
var _neutral_focus_seed: Control
var _releasing_neutral_focus: bool = false
var _focus_clear_generation: int = 0
var _directional_input_generation: int = 0
var _directional_input_in_flight: bool = false
var _focused_control: Control
var _focused_popup: PopupMenu
var _popup_scroll_offset: float = 0.0
var _suppressed_control: Control
var _original_style_overrides: Dictionary[StringName, Dictionary] = {}
var _original_color_overrides: Dictionary[StringName, Dictionary] = {}
var _suppressed_hover_control: Control
var _original_hover_style_overrides: Dictionary[StringName, Dictionary] = {}
var _original_hover_color_overrides: Dictionary[StringName, Dictionary] = {}
var _original_popup_hover_style: Dictionary = {}
var _original_popup_hover_color: Dictionary = {}
var _focus_layer: CanvasLayer
var _focus_arrow_shadow: TextureRect
var _focus_arrow: TextureRect


func _ready() -> void:
	_build_focus_arrow()
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	set_process_input(true)
	set_process(true)
	var existing_focus: Control = _active_focus_owner()
	if existing_focus != null:
		_capture_neutral_focus_seed(existing_focus)


func _exit_tree() -> void:
	_clear_focus_presentation()
	_restore_native_hover_highlight()


func _input(event: InputEvent) -> void:
	if _virtual_pointer_active and (
		event is InputEventJoypadButton or event is InputEventJoypadMotion
	):
		return
	var directional_navigation: bool = _is_directional_navigation(event)
	if directional_navigation:
		_directional_input_generation += 1
		_directional_input_in_flight = true
		_clear_directional_input_in_flight.call_deferred(
			_directional_input_generation
		)
	if event is InputEventJoypadButton:
		if (event as InputEventJoypadButton).pressed:
			_set_controller_active(true)
	elif event is InputEventJoypadMotion:
		if absf((event as InputEventJoypadMotion).axis_value) >= (
			CONTROLLER_MOTION_THRESHOLD
		):
			_set_controller_active(true)
	elif event is InputEventMouseMotion:
		_set_controller_active(false)
		_neutralize_current_navigation_focus()
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			_set_controller_active(false)
			_neutralize_current_navigation_focus()
	elif event is InputEventKey:
		if (event as InputEventKey).pressed:
			_set_controller_active(false)
	if directional_navigation and _restore_neutral_focus_seed():
		get_viewport().set_input_as_handled()


func set_virtual_pointer_active(active: bool) -> void:
	if _virtual_pointer_active == active:
		return
	_virtual_pointer_active = active
	if active:
		_set_controller_active(false)
		_clear_focus_presentation()
		_restore_native_hover_highlight()


func _process(_delta: float) -> void:
	if _virtual_pointer_active:
		_set_controller_active(false)
		return
	_update_hover_suppression()
	if _controller_active:
		var focused_popup: PopupMenu = _active_focused_popup(get_viewport())
		if focused_popup != null:
			if focused_popup != _focused_popup or _focused_control != null:
				_apply_to_popup(focused_popup)
			else:
				_update_arrow_geometry()
			return
	var focus_owner: Control = _active_focus_owner()
	if (
		focus_owner != _focused_control
		or not _focus_is_presentable(focus_owner)
	):
		_apply_to_focus(focus_owner)
	elif _controller_active:
		_update_arrow_geometry()


func _build_focus_arrow() -> void:
	_focus_layer = CanvasLayer.new()
	_focus_layer.name = "ControllerFocusArrowLayer"
	_focus_layer.layer = FOCUS_ARROW_CANVAS_LAYER
	add_child(_focus_layer)
	_focus_arrow_shadow = _make_focus_cursor_texture(
		"ControllerFocusArrowShadow"
	)
	_focus_arrow_shadow.self_modulate = FOCUS_ARROW_SHADOW_COLOR
	_focus_layer.add_child(_focus_arrow_shadow)
	_focus_arrow = _make_focus_cursor_texture("ControllerFocusArrow")
	_focus_layer.add_child(_focus_arrow)


func _make_focus_cursor_texture(node_name: String) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.name = node_name
	texture_rect.texture = FOCUS_ARROW_TEXTURE
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.size = FOCUS_ARROW_SIZE
	texture_rect.pivot_offset = FOCUS_ARROW_SIZE * 0.5
	texture_rect.rotation_degrees = FOCUS_ARROW_ROTATION_DEGREES
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.focus_mode = Control.FOCUS_NONE
	texture_rect.visible = false
	return texture_rect


func _set_focus_cursor_visible(is_visible: bool) -> void:
	if _focus_arrow_shadow != null:
		_focus_arrow_shadow.visible = is_visible
	if _focus_arrow != null:
		_focus_arrow.visible = is_visible


func _set_controller_active(active: bool) -> void:
	if _controller_active == active:
		return
	_controller_active = active
	_update_hover_suppression()
	if _controller_active:
		var focused_popup: PopupMenu = _active_focused_popup(get_viewport())
		if focused_popup != null:
			_apply_to_popup(focused_popup)
			return
	var focus_owner: Control = _active_focus_owner()
	_apply_to_focus(focus_owner)
	if _controller_active:
		_queue_focus_visibility_update(focus_owner)


func _on_focus_changed(control: Control) -> void:
	if _releasing_neutral_focus and control == null:
		return
	if control == null:
		_focus_clear_generation += 1
		_clear_focus_presentation()
		_reset_navigation_session_after_focus_clear.call_deferred(
			_focus_clear_generation
		)
		return
	# A normal transfer between controls briefly reports a null owner. Cancel
	# that deferred reset so active directional navigation remains continuous.
	_focus_clear_generation += 1
	if _directional_input_in_flight and _is_navigation_focus(control):
		_navigation_focus_active = true
		_neutral_focus_seed = null
	elif not _navigation_focus_active and _is_navigation_focus(control):
		_capture_neutral_focus_seed(control)
		return
	if _controller_active:
		var focused_popup: PopupMenu = _active_focused_popup(get_viewport())
		if focused_popup != null:
			_apply_to_popup(focused_popup)
			return
	_apply_to_focus(control)
	if _controller_active:
		_queue_focus_visibility_update(control)


func _reset_navigation_session_after_focus_clear(generation: int) -> void:
	if generation != _focus_clear_generation or _active_focus_owner() != null:
		return
	_navigation_focus_active = false
	_neutral_focus_seed = null


func _clear_directional_input_in_flight(generation: int) -> void:
	if generation == _directional_input_generation:
		_directional_input_in_flight = false


func _is_directional_navigation(event: InputEvent) -> bool:
	if event is InputEventKey and (event as InputEventKey).echo:
		return false
	# Tab is both Godot's default ui_focus_next key and NETfishing's default
	# player-menu binding. The global focus presenter must leave that gameplay
	# action alone; otherwise a remembered neutral focus seed consumes the key
	# before PlayerMenu can open or close.
	if event is InputEventKey and event.is_action_pressed(&"open_backpack"):
		return false
	return (
		event.is_action_pressed(&"ui_left")
		or event.is_action_pressed(&"ui_right")
		or event.is_action_pressed(&"ui_up")
		or event.is_action_pressed(&"ui_down")
		or event.is_action_pressed(&"ui_focus_next")
		or event.is_action_pressed(&"ui_focus_prev")
	)


func _is_navigation_focus(control: Control) -> bool:
	# Text entry is an explicit interaction rather than menu navigation. It must
	# retain direct focus for typing, including Chat and dialog fields.
	return not (control is LineEdit or control is TextEdit)


func _capture_neutral_focus_seed(control: Control) -> void:
	if not _focus_is_presentable(control) or not _is_navigation_focus(control):
		return
	_navigation_focus_active = false
	_neutral_focus_seed = control
	_clear_focus_presentation()
	_releasing_neutral_focus = true
	control.release_focus()
	_releasing_neutral_focus = false


func _neutralize_current_navigation_focus() -> void:
	var focus_owner: Control = _active_focus_owner()
	if focus_owner != null and _is_navigation_focus(focus_owner):
		_capture_neutral_focus_seed(focus_owner)
	else:
		_navigation_focus_active = false
		_clear_focus_presentation()


func _restore_neutral_focus_seed() -> bool:
	if not _focus_is_presentable(_neutral_focus_seed):
		_neutral_focus_seed = null
		return false
	var target: Control = _neutral_focus_seed
	_neutral_focus_seed = null
	_navigation_focus_active = true
	target.grab_focus()
	return true


func _queue_focus_visibility_update(control: Control) -> void:
	if control == null:
		return
	_ensure_focus_visible.call_deferred(control)


func _ensure_focus_visible(control: Control) -> void:
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	var ancestor: Node = control.get_parent()
	while ancestor != null:
		var scroll := ancestor as ScrollContainer
		if scroll != null and scroll.is_visible_in_tree():
			scroll.ensure_control_visible(control)
		ancestor = ancestor.get_parent()


func _apply_to_focus(control: Control) -> void:
	_clear_focus_presentation()
	if not _controller_active or not _focus_is_presentable(control):
		return
	_focused_control = control
	_focus_layer.custom_viewport = control.get_viewport()
	_suppress_native_focus_highlight(control)
	_set_focus_cursor_visible(true)
	_update_arrow_geometry()


func _apply_to_popup(popup: PopupMenu) -> void:
	_clear_focus_presentation()
	if (
		not _controller_active
		or popup == null
		or not is_instance_valid(popup)
		or not popup.visible
		or popup.get_focused_item() < 0
	):
		return
	_focused_popup = popup
	_popup_scroll_offset = 0.0
	_focus_layer.custom_viewport = popup
	_suppress_popup_focus_highlight(popup)
	_set_focus_cursor_visible(true)
	_update_arrow_geometry()


func _focus_is_presentable(control: Control) -> bool:
	return (
		control != null
		and is_instance_valid(control)
		and control.is_visible_in_tree()
		and control.focus_mode != Control.FOCUS_NONE
	)


func _update_arrow_geometry() -> void:
	if (
		_focus_arrow == null
		or not _controller_active
		or (
			_focused_popup == null
			and not _focus_is_presentable(_focused_control)
		)
		or (
			_focused_popup != null
			and (
				not is_instance_valid(_focused_popup)
				or not _focused_popup.visible
				or _focused_popup.get_focused_item() < 0
			)
		)
	):
		_set_focus_cursor_visible(false)
		return
	var presentation_scale: Vector2 = _presentation_canvas_scale()
	var arrow_size: Vector2 = FOCUS_ARROW_SIZE * presentation_scale
	_focus_arrow.size = arrow_size
	_focus_arrow.pivot_offset = arrow_size * 0.5
	_focus_arrow_shadow.size = arrow_size
	_focus_arrow_shadow.pivot_offset = arrow_size * 0.5
	var desired_tip: Vector2 = (
		_popup_focus_target_rect(_focused_popup).position
		+ FOCUS_ARROW_TARGET_OVERLAP * presentation_scale
		if _focused_popup != null
		else _focus_target_position(
			_focused_control,
			presentation_scale,
		)
	)
	var tip_from_pivot: Vector2 = (
		(FOCUS_ARROW_TIP_UV - Vector2.ONE * 0.5) * arrow_size
	).rotated(deg_to_rad(FOCUS_ARROW_ROTATION_DEGREES))
	var arrow_position: Vector2 = (
		desired_tip - arrow_size * 0.5 - tip_from_pivot
	)
	_focus_arrow.position = arrow_position
	_focus_arrow_shadow.position = (
		arrow_position
		+ FOCUS_ARROW_SHADOW_OFFSET * presentation_scale
	)
	_set_focus_cursor_visible(true)


func _focus_target_position(
	control: Control,
	presentation_scale: Vector2,
) -> Vector2:
	if control is BubbleButton or control is CoolerFishSprite:
		return _bubble_focus_target_position(control)
	return (
		_focus_target_rect(control).position
		+ FOCUS_ARROW_TARGET_OVERLAP * presentation_scale
	)


func _bubble_focus_target_position(control: Control) -> Vector2:
	var direction := Vector2.RIGHT.rotated(
		deg_to_rad(FOCUS_ARROW_ROTATION_DEGREES)
	)
	var radius: Vector2 = control.size * 0.5
	var safe_radius := Vector2(
		maxf(radius.x, 0.001),
		maxf(radius.y, 0.001),
	)
	var boundary_distance: float = 1.0 / sqrt(
		pow(direction.x / safe_radius.x, 2.0)
		+ pow(direction.y / safe_radius.y, 2.0)
	)
	var local_tip: Vector2 = (
		radius
		- direction * boundary_distance
		+ direction * FOCUS_ARROW_BUBBLE_OVERLAP
	)
	return _rect_in_presentation_viewport(
		control,
		Rect2(local_tip, Vector2.ZERO),
	).position


func _presentation_canvas_scale() -> Vector2:
	var target: Control = _focused_control
	var target_scale := Vector2.ONE
	if target != null and is_instance_valid(target):
		target_scale = (
			target.get_global_transform_with_canvas().get_scale().abs()
		)
	else:
		# PopupMenu is a Window rather than a Control. Its cursor retains the
		# canonical host scale used before cross-viewport focus support.
		var host := get_parent() as Control
		if host != null:
			target_scale = (
				host.get_global_transform_with_canvas().get_scale().abs()
			)
	return Vector2(
		maxf(target_scale.x, 0.001),
		maxf(target_scale.y, 0.001),
	)


func _focus_target_rect(control: Control) -> Rect2:
	var item_list := control as ItemList
	if item_list != null:
		var selected_items: PackedInt32Array = item_list.get_selected_items()
		if not selected_items.is_empty():
			return _rect_in_presentation_viewport(
				item_list,
				item_list.get_item_rect(selected_items[0]),
			)
	var tree := control as Tree
	if tree != null:
		var selected_item: TreeItem = tree.get_selected()
		if selected_item != null:
			return _rect_in_presentation_viewport(
				tree,
				tree.get_item_area_rect(
					selected_item,
					tree.get_selected_column(),
				),
			)
	return _rect_in_presentation_viewport(
		control,
		Rect2(Vector2.ZERO, control.size),
	)


func _rect_in_presentation_viewport(
	control: Control,
	local_rect: Rect2,
) -> Rect2:
	var canvas_transform: Transform2D = control.get_global_transform_with_canvas()
	var corners: Array[Vector2] = [
		canvas_transform * local_rect.position,
		canvas_transform * Vector2(local_rect.end.x, local_rect.position.y),
		canvas_transform * local_rect.end,
		canvas_transform * Vector2(local_rect.position.x, local_rect.end.y),
	]
	var result := Rect2(corners.front(), Vector2.ZERO)
	for corner: Vector2 in corners:
		result = result.expand(corner)
	return _offset_rect_to_presentation_viewport(
		result,
		control.get_viewport(),
	)


func _popup_focus_target_rect(popup: PopupMenu) -> Rect2:
	var focused_index: int = popup.get_focused_item()
	var panel_style: StyleBox = popup.get_theme_stylebox(&"panel")
	var panel_left: float = panel_style.get_content_margin(SIDE_LEFT)
	var panel_top: float = panel_style.get_content_margin(SIDE_TOP)
	var panel_right: float = panel_style.get_content_margin(SIDE_RIGHT)
	var panel_bottom: float = panel_style.get_content_margin(SIDE_BOTTOM)
	var item_heights: Array[float] = []
	var focused_top: float = 0.0
	for index: int in popup.get_item_count():
		var item_height: float = _popup_item_height(popup, index)
		item_heights.append(item_height)
		if index < focused_index:
			focused_top += item_height
	var focused_height: float = item_heights[focused_index]
	var visible_height: float = maxf(
		1.0,
		float(popup.size.y) - panel_top - panel_bottom,
	)
	if focused_top < _popup_scroll_offset:
		_popup_scroll_offset = focused_top
	elif focused_top + focused_height > _popup_scroll_offset + visible_height:
		_popup_scroll_offset = (
			focused_top + focused_height - visible_height
		)
	var local_rect := Rect2(
		Vector2(
			panel_left,
			panel_top + focused_top - _popup_scroll_offset,
		),
		Vector2(
			maxf(1.0, float(popup.size.x) - panel_left - panel_right),
			focused_height,
		),
	)
	if _focus_layer.custom_viewport == popup:
		return local_rect
	local_rect.position += Vector2(popup.position)
	var parent_node: Node = popup.get_parent()
	if parent_node == null:
		return local_rect
	return _offset_rect_to_presentation_viewport(
		local_rect,
		parent_node.get_viewport(),
	)


func _popup_item_height(popup: PopupMenu, index: int) -> float:
	var vertical_separation: float = float(
		popup.get_theme_constant(&"v_separation")
	)
	if popup.is_item_separator(index) and popup.get_item_text(index).is_empty():
		return maxf(
			1.0,
			popup.get_theme_stylebox(&"separator").get_minimum_size().y,
		) + vertical_separation
	var font: Font = popup.get_theme_font(&"font")
	var font_height: float = font.get_height(
		popup.get_theme_font_size(&"font_size")
	)
	var icon: Texture2D = popup.get_item_icon(index)
	var icon_height: float = icon.get_height() if icon != null else 0.0
	return maxf(font_height, icon_height) + vertical_separation


func _offset_rect_to_presentation_viewport(
	rect: Rect2,
	starting_viewport: Viewport,
) -> Rect2:
	var result: Rect2 = rect
	var current_viewport: Viewport = starting_viewport
	var presentation_viewport: Viewport = (
		_focus_layer.custom_viewport
		if _focus_layer != null
		else get_viewport()
	)
	while current_viewport != presentation_viewport:
		var embedded_window := current_viewport as Window
		if embedded_window == null or not embedded_window.is_embedded():
			break
		result.position += Vector2(embedded_window.position)
		var parent_node: Node = embedded_window.get_parent()
		if parent_node == null:
			break
		current_viewport = parent_node.get_viewport()
	return result


func _active_focus_owner() -> Control:
	return _focus_owner_in_viewport(get_viewport())


func _active_focused_popup(viewport: Viewport) -> PopupMenu:
	var embedded_windows: Array[Window] = viewport.get_embedded_subwindows()
	for index: int in range(embedded_windows.size() - 1, -1, -1):
		var window: Window = embedded_windows[index]
		if not window.visible:
			continue
		var nested_popup: PopupMenu = _active_focused_popup(window)
		if nested_popup != null:
			return nested_popup
		var popup := window as PopupMenu
		if popup != null and popup.get_focused_item() >= 0:
			return popup
	return null


func _focus_owner_in_viewport(viewport: Viewport) -> Control:
	var embedded_windows: Array[Window] = viewport.get_embedded_subwindows()
	for index: int in range(embedded_windows.size() - 1, -1, -1):
		var window: Window = embedded_windows[index]
		if not window.visible:
			continue
		var nested_owner: Control = _focus_owner_in_viewport(window)
		if nested_owner != null:
			return nested_owner
	return viewport.gui_get_focus_owner()


func _suppress_native_focus_highlight(control: Control) -> void:
	_suppressed_control = control
	_original_style_overrides.clear()
	_original_color_overrides.clear()
	for focus_name: StringName in FOCUS_STYLE_REPLACEMENTS:
		var replacement_name: StringName = FOCUS_STYLE_REPLACEMENTS[focus_name]
		_original_style_overrides[focus_name] = {
			"had_override": control.has_theme_stylebox_override(focus_name),
			"value": control.get_theme_stylebox(focus_name),
		}
		var replacement: StyleBox = (
			StyleBoxEmpty.new()
			if replacement_name.is_empty()
			else control.get_theme_stylebox(replacement_name)
			if control.has_theme_stylebox_override(replacement_name)
			else StyleBoxEmpty.new()
		)
		control.add_theme_stylebox_override(focus_name, replacement)
	for focus_name: StringName in FOCUS_COLOR_REPLACEMENTS:
		var replacement_name: StringName = FOCUS_COLOR_REPLACEMENTS[focus_name]
		if not control.has_theme_color(replacement_name):
			continue
		_original_color_overrides[focus_name] = {
			"had_override": control.has_theme_color_override(focus_name),
			"value": control.get_theme_color(focus_name),
		}
		control.add_theme_color_override(
			focus_name,
			control.get_theme_color(replacement_name),
		)


func _update_hover_suppression() -> void:
	if not _controller_active:
		_restore_native_hover_highlight()
		return
	var hovered: Control = _hover_presentation_control(
		_hovered_control_in_viewport(get_viewport())
	)
	if hovered == _suppressed_hover_control:
		return
	_restore_native_hover_highlight()
	if hovered != null:
		_suppress_native_hover_highlight(hovered)
func _hovered_control_in_viewport(viewport: Viewport) -> Control:
	var embedded_windows: Array[Window] = viewport.get_embedded_subwindows()
	for index: int in range(embedded_windows.size() - 1, -1, -1):
		var window: Window = embedded_windows[index]
		if not window.visible:
			continue
		var nested_hovered: Control = _hovered_control_in_viewport(window)
		if nested_hovered != null:
			return nested_hovered
	return viewport.gui_get_hovered_control()


func _hover_presentation_control(control: Control) -> Control:
	var candidate: Control = control
	while candidate != null:
		if (
			candidate is BaseButton
			or candidate is ItemList
			or candidate is Tree
			or candidate.focus_mode != Control.FOCUS_NONE
		):
			return candidate
		candidate = candidate.get_parent() as Control
	return null


func _suppress_native_hover_highlight(control: Control) -> void:
	_suppressed_hover_control = control
	_original_hover_style_overrides.clear()
	_original_hover_color_overrides.clear()
	if control.has_method(&"set_controller_focus_presentation_active"):
		control.call(&"set_controller_focus_presentation_active", true)
	for hover_name: StringName in HOVER_STYLE_REPLACEMENTS:
		var replacement_name: StringName = HOVER_STYLE_REPLACEMENTS[hover_name]
		_original_hover_style_overrides[hover_name] = {
			"had_override": control.has_theme_stylebox_override(hover_name),
			"value": control.get_theme_stylebox(hover_name),
		}
		var replacement: StyleBox = (
			StyleBoxEmpty.new()
			if replacement_name.is_empty()
			else control.get_theme_stylebox(replacement_name)
		)
		control.add_theme_stylebox_override(hover_name, replacement)
	for hover_name: StringName in HOVER_COLOR_REPLACEMENTS:
		var replacement_name: StringName = HOVER_COLOR_REPLACEMENTS[hover_name]
		if not control.has_theme_color(replacement_name):
			continue
		_original_hover_color_overrides[hover_name] = {
			"had_override": control.has_theme_color_override(hover_name),
			"value": control.get_theme_color(hover_name),
		}
		control.add_theme_color_override(
			hover_name,
			control.get_theme_color(replacement_name),
		)


func _restore_native_hover_highlight() -> void:
	if not is_instance_valid(_suppressed_hover_control):
		_suppressed_hover_control = null
		_original_hover_style_overrides.clear()
		_original_hover_color_overrides.clear()
		return
	for hover_name: StringName in _original_hover_style_overrides:
		var state: Dictionary = _original_hover_style_overrides[hover_name]
		if bool(state.get("had_override", false)):
			_suppressed_hover_control.add_theme_stylebox_override(
				hover_name,
				state.get("value") as StyleBox,
			)
		else:
			_suppressed_hover_control.remove_theme_stylebox_override(hover_name)
	for hover_name: StringName in _original_hover_color_overrides:
		var state: Dictionary = _original_hover_color_overrides[hover_name]
		if bool(state.get("had_override", false)):
			_suppressed_hover_control.add_theme_color_override(
				hover_name,
				state.get("value") as Color,
			)
		else:
			_suppressed_hover_control.remove_theme_color_override(hover_name)
	if _suppressed_hover_control.has_method(
		&"set_controller_focus_presentation_active"
	):
		_suppressed_hover_control.call(
			&"set_controller_focus_presentation_active", false
		)
	_suppressed_hover_control = null
	_original_hover_style_overrides.clear()
	_original_hover_color_overrides.clear()


func _suppress_popup_focus_highlight(popup: PopupMenu) -> void:
	_original_popup_hover_style = {
		"had_override": popup.has_theme_stylebox_override(&"hover"),
		"value": popup.get_theme_stylebox(&"hover"),
	}
	_original_popup_hover_color = {
		"had_override": popup.has_theme_color_override(&"font_hover_color"),
		"value": popup.get_theme_color(&"font_hover_color"),
	}
	popup.add_theme_stylebox_override(&"hover", StyleBoxEmpty.new())
	popup.add_theme_color_override(
		&"font_hover_color",
		popup.get_theme_color(&"font_color"),
	)


func _restore_native_focus_highlight() -> void:
	if not is_instance_valid(_suppressed_control):
		_suppressed_control = null
		_original_style_overrides.clear()
		_original_color_overrides.clear()
		return
	for focus_name: StringName in _original_style_overrides:
		var state: Dictionary = _original_style_overrides[focus_name]
		if bool(state.get("had_override", false)):
			_suppressed_control.add_theme_stylebox_override(
				focus_name,
				state.get("value") as StyleBox,
			)
		else:
			_suppressed_control.remove_theme_stylebox_override(focus_name)
	for focus_name: StringName in _original_color_overrides:
		var state: Dictionary = _original_color_overrides[focus_name]
		if bool(state.get("had_override", false)):
			_suppressed_control.add_theme_color_override(
				focus_name,
				state.get("value") as Color,
			)
		else:
			_suppressed_control.remove_theme_color_override(focus_name)
	_suppressed_control = null
	_original_style_overrides.clear()
	_original_color_overrides.clear()


func _restore_popup_focus_highlight() -> void:
	if not is_instance_valid(_focused_popup):
		_original_popup_hover_style.clear()
		_original_popup_hover_color.clear()
		return
	if bool(_original_popup_hover_style.get("had_override", false)):
		_focused_popup.add_theme_stylebox_override(
			&"hover",
			_original_popup_hover_style.get("value") as StyleBox,
		)
	else:
		_focused_popup.remove_theme_stylebox_override(&"hover")
	if bool(_original_popup_hover_color.get("had_override", false)):
		_focused_popup.add_theme_color_override(
			&"font_hover_color",
			_original_popup_hover_color.get("value") as Color,
		)
	else:
		_focused_popup.remove_theme_color_override(&"font_hover_color")
	_original_popup_hover_style.clear()
	_original_popup_hover_color.clear()


func _clear_focus_presentation() -> void:
	_restore_native_focus_highlight()
	_restore_popup_focus_highlight()
	_focused_control = null
	_focused_popup = null
	_popup_scroll_offset = 0.0
	if _focus_layer != null:
		_focus_layer.custom_viewport = get_viewport()
	_set_focus_cursor_visible(false)
