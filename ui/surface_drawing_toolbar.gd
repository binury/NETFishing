class_name SurfaceDrawingToolbar
extends Control

const UtilityPageStyleType = preload("res://ui/utility_page_style.gd")
const ControllerVirtualCursorType = preload(
	"res://ui/controller_virtual_cursor.gd"
)
const MARKER_MODE_ICON: Texture2D = preload(
	"res://items/icons/art/art_kit_marker.png"
)
const MARKER_MODE_SHADER: Shader = preload(
	"res://ui/art_kit_marker_icon.gdshader"
)
const GRID_MODE_ICON: Texture2D = preload(
	"res://items/icons/art/art_kit_grid_light.png"
)
const BRUSH_SIZE_ICONS: Dictionary[int, Texture2D] = {
	1: preload("res://items/icons/art/art_kit_marker_tip_fine.png"),
	2: preload("res://items/icons/art/art_kit_marker_tip_thin.png"),
	3: preload("res://items/icons/art/art_kit_marker_tip_mid.png"),
	4: preload("res://items/icons/art/art_kit_marker_tip_thick.png"),
}
const GRID_SIZE_ICONS: Dictionary[int, Texture2D] = {
	16: preload("res://items/icons/art/art_kit_grid_small_light.png"),
	32: preload("res://items/icons/art/art_kit_grid_medium_light.png"),
	64: preload("res://items/icons/art/art_kit_grid_large_light.png"),
	128: preload("res://items/icons/art/art_kit_grid_xl_light.png"),
}
const TOOLBAR_WIDTH: float = 510.0
const TOOLBAR_HEIGHT: float = 373.0
const COLOR_RAIL_WIDTH: float = 46.0

@onready var _mode_button: Button = %ModeButton
@onready var _brush_option: OptionButton = %BrushOption
@onready var _grid_option: OptionButton = %GridOption
@onready var _color_list: VBoxContainer = %ColorList
@onready var _top_panel: PanelContainer = %TopPanel
@onready var _color_panel: PanelContainer = %ColorPanel
@onready var _eraser_button: Button = %EraserButton
@onready var _undo_button: Button = %UndoButton
@onready var _hide_guide_button: Button = %HideGuideButton
@onready var _restore_guide_button: Button = %RestoreGuideButton
@onready var _finalize_guide_button: Button = %FinalizeGuideButton

var _service: NetworkSurfaceDrawingService
var _unlocks: PlayerArtUnlocks
var _color_buttons: Dictionary[StringName, Button] = {}
var _dock_right: bool = true
var _marker_mode_material: ShaderMaterial
var _brush_popup_cursor: ControllerVirtualCursorType
var _grid_popup_cursor: ControllerVirtualCursorType
var _applied_marker_icon_color: Color = Color(-1.0, -1.0, -1.0, -1.0)


func _ready() -> void:
	UtilityPageStyleType.apply_page(self)
	_apply_toolbar_panel(_top_panel)
	_apply_toolbar_panel(_color_panel)
	UtilityPageStyleType.apply_ocean_button(_mode_button)
	UtilityPageStyleType.apply_ocean_button(_brush_option)
	UtilityPageStyleType.apply_ocean_button(_grid_option)
	for size_option: OptionButton in [_brush_option, _grid_option]:
		size_option.expand_icon = true
		size_option.add_theme_constant_override("icon_max_width", 40)
		size_option.get_popup().add_theme_constant_override(
			"icon_max_width", 40
		)
	for button: Button in _action_buttons():
		UtilityPageStyleType.apply_ocean_button(button)
		button.custom_minimum_size = Vector2(48, 44)
		_make_button_round(button, 22)
	_mode_button.custom_minimum_size = Vector2(48, 48)
	_make_button_round(_mode_button, 24)
	_enlarge_action_icon(_mode_button)
	_marker_mode_material = ShaderMaterial.new()
	_marker_mode_material.shader = MARKER_MODE_SHADER
	_marker_mode_material.set_shader_parameter(
		"marker_color",
		SurfaceDrawingPalette.get_color(SurfaceDrawingPalette.DEFAULT_COLOR_ID),
	)
	_mode_button.material = _marker_mode_material
	for button: Button in _action_buttons():
		_enlarge_action_icon(button)
	_mode_button.pressed.connect(_toggle_mode)
	_eraser_button.pressed.connect(_toggle_eraser)
	_undo_button.pressed.connect(_undo_last_stroke)
	_hide_guide_button.pressed.connect(
		_arm_guide_action.bind(NetworkSurfaceDrawingService.GuideAction.HIDE)
	)
	_restore_guide_button.pressed.connect(
		_arm_guide_action.bind(NetworkSurfaceDrawingService.GuideAction.RESTORE)
	)
	_finalize_guide_button.pressed.connect(
		_arm_guide_action.bind(NetworkSurfaceDrawingService.GuideAction.FINALIZE)
	)
	_brush_option.item_selected.connect(_select_brush)
	_grid_option.item_selected.connect(_select_grid)
	_configure_pointer_only_controls()
	_brush_popup_cursor = _add_popup_cursor(_brush_option.get_popup())
	_grid_popup_cursor = _add_popup_cursor(_grid_option.get_popup())
	_build_options()
	_apply_marker_color_to_brush_icons(
		SurfaceDrawingPalette.get_color(SurfaceDrawingPalette.DEFAULT_COLOR_ID)
	)
	_apply_dock_side()
	hide()


func _apply_toolbar_panel(panel: PanelContainer) -> void:
	var style: StyleBoxFlat = UtilityPageStyleType.panel_style()
	style.content_margin_left = 6.0
	style.content_margin_top = 6.0
	style.content_margin_right = 6.0
	style.content_margin_bottom = 6.0
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)


func _action_buttons() -> Array[Button]:
	return [
		_eraser_button,
		_undo_button,
		_hide_guide_button,
		_restore_guide_button,
		_finalize_guide_button,
	]


func _make_button_round(button: Button, radius: int) -> void:
	for style_name: StringName in [
		&"normal", &"hover", &"pressed", &"focus", &"disabled",
	]:
		var existing: StyleBox = button.get_theme_stylebox(style_name)
		var style := existing.duplicate() as StyleBoxFlat
		if style == null:
			continue
		style.set_corner_radius_all(radius)
		button.add_theme_stylebox_override(style_name, style)


func _enlarge_action_icon(button: Button) -> void:
	# The shared ocean button uses generous text padding, leaving only a
	# 20-pixel icon area in these compact bubbles. Keep the 48x44 control and
	# hitbox intact while giving icon-only actions a full 40x40 presentation.
	button.add_theme_constant_override("icon_max_width", 40)
	for style_name: StringName in [
		&"normal", &"hover", &"pressed", &"focus", &"disabled",
	]:
		var existing: StyleBox = button.get_theme_stylebox(style_name)
		var style := existing.duplicate() as StyleBoxFlat
		if style == null:
			continue
		style.content_margin_left = 4.0
		style.content_margin_right = 4.0
		style.content_margin_top = 2.0
		style.content_margin_bottom = 2.0
		button.add_theme_stylebox_override(style_name, style)


func setup(
	service: NetworkSurfaceDrawingService,
	unlocks: PlayerArtUnlocks,
) -> void:
	_service = service
	_unlocks = unlocks
	if _service != null and not _service.hud_state_changed.is_connected(
		_on_service_state_changed
	):
		_service.hud_state_changed.connect(_on_service_state_changed)
	if _unlocks != null and not _unlocks.unlocks_changed.is_connected(
		_on_unlocks_changed
	):
		_unlocks.unlocks_changed.connect(_on_unlocks_changed)
	_refresh_unlocks()


func set_dock_right(should_dock_right: bool) -> void:
	_dock_right = should_dock_right
	if is_node_ready():
		_apply_dock_side()


func is_docked_right() -> bool:
	return _dock_right


func _apply_dock_side() -> void:
	anchor_left = 1.0 if _dock_right else 0.0
	anchor_right = anchor_left
	offset_left = -TOOLBAR_WIDTH if _dock_right else 0.0
	offset_right = 0.0 if _dock_right else TOOLBAR_WIDTH
	offset_top = 0.0
	offset_bottom = TOOLBAR_HEIGHT
	_top_panel.offset_left = 0.0
	_top_panel.offset_right = TOOLBAR_WIDTH
	_color_panel.offset_left = (
		TOOLBAR_WIDTH - COLOR_RAIL_WIDTH if _dock_right else 0.0
	)
	_color_panel.offset_right = (
		TOOLBAR_WIDTH if _dock_right else COLOR_RAIL_WIDTH
	)


func owns_pointer_event(event: InputEvent) -> bool:
	if not visible:
		return false
	if _brush_option.get_popup().visible or _grid_option.get_popup().visible:
		return true
	if event is InputEventMouse:
		var pointer_position: Vector2 = (event as InputEventMouse).position
		return (
			_top_panel.get_global_rect().has_point(pointer_position)
			or _color_panel.get_global_rect().has_point(pointer_position)
		)
	return false


func update_virtual_pointer_overlay(is_pointer_visible: bool) -> bool:
	var active_popup: PopupMenu
	var active_cursor: ControllerVirtualCursorType
	if _brush_option.get_popup().visible:
		active_popup = _brush_option.get_popup()
		active_cursor = _brush_popup_cursor
	elif _grid_option.get_popup().visible:
		active_popup = _grid_option.get_popup()
		active_cursor = _grid_popup_cursor
	for popup_cursor: ControllerVirtualCursorType in [
		_brush_popup_cursor, _grid_popup_cursor,
	]:
		if popup_cursor != null:
			popup_cursor.visible = (
				is_pointer_visible and popup_cursor == active_cursor
			)
	if not is_pointer_visible or active_popup == null or active_cursor == null:
		return false
	active_cursor.set_pointer_position(active_popup.get_mouse_position())
	return true


func hide_virtual_pointer_overlay() -> void:
	update_virtual_pointer_overlay(false)


func _configure_pointer_only_controls() -> void:
	for control: Control in [
		_mode_button,
		_brush_option,
		_grid_option,
		_eraser_button,
		_undo_button,
		_hide_guide_button,
		_restore_guide_button,
		_finalize_guide_button,
	]:
		control.focus_mode = Control.FOCUS_NONE
		control.focus_neighbor_left = NodePath()
		control.focus_neighbor_top = NodePath()
		control.focus_neighbor_right = NodePath()
		control.focus_neighbor_bottom = NodePath()
		control.focus_next = NodePath()
		control.focus_previous = NodePath()
	for popup: PopupMenu in [
		_brush_option.get_popup(), _grid_option.get_popup(),
	]:
		popup.unfocusable = true


func _add_popup_cursor(popup: PopupMenu) -> ControllerVirtualCursorType:
	var cursor := ControllerVirtualCursorType.new()
	cursor.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	cursor.z_as_relative = false
	popup.add_child(cursor)
	return cursor


func _build_options() -> void:
	_brush_option.clear()
	for brush_size: int in PlayerArtUnlocks.BRUSH_SIZES:
		_brush_option.add_icon_item(
			BRUSH_SIZE_ICONS[brush_size],
			"",
			brush_size,
		)
		_brush_option.set_item_tooltip(
			_brush_option.item_count - 1,
			"%d× marker size" % brush_size,
		)
	_grid_option.clear()
	for grid_size: int in PlayerArtUnlocks.GRID_SIZES:
		_grid_option.add_icon_item(
			GRID_SIZE_ICONS[grid_size],
			"",
			grid_size,
		)
		_grid_option.set_item_tooltip(
			_grid_option.item_count - 1,
			"%d×%d grid" % [grid_size, grid_size],
		)
	for child: Node in _color_list.get_children():
		child.queue_free()
	_color_buttons.clear()
	for color_id: StringName in SurfaceDrawingPalette.get_color_ids():
		var button := Button.new()
		button.custom_minimum_size = Vector2(34, 34)
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = SurfaceDrawingPalette.get_display_name(color_id)
		button.pressed.connect(_select_color.bind(color_id))
		_color_list.add_child(button)
		_color_buttons[color_id] = button
		_apply_color_button_style(button, color_id, false)


func _apply_marker_color_to_brush_icons(marker_color: Color) -> void:
	if _applied_marker_icon_color.is_equal_approx(marker_color):
		return
	_applied_marker_icon_color = marker_color
	for index: int in range(_brush_option.item_count):
		var brush_size: int = _brush_option.get_item_id(index)
		_brush_option.set_item_icon(
			index,
			_channel_masked_icon(BRUSH_SIZE_ICONS[brush_size], marker_color),
		)


func _channel_masked_icon(source: Texture2D, marker_color: Color) -> Texture2D:
	var source_image: Image = source.get_image()
	if source_image == null or source_image.is_empty():
		return source
	var image := source_image.duplicate() as Image
	if image.is_compressed():
		if image.decompress() != OK:
			return source
	image.convert(Image.FORMAT_RGBA8)
	for y: int in image.get_height():
		for x: int in image.get_width():
			var source_color: Color = image.get_pixel(x, y)
			var red_dominance: float = (
				source_color.r - maxf(source_color.g, source_color.b)
			)
			var marker_mask: float = smoothstep(0.04, 0.18, red_dominance)
			image.set_pixel(
				x,
				y,
				Color(
					lerpf(
						source_color.r,
						marker_color.r * source_color.r,
						marker_mask,
					),
					lerpf(
						source_color.g,
						marker_color.g * source_color.r,
						marker_mask,
					),
					lerpf(
						source_color.b,
						marker_color.b * source_color.r,
						marker_mask,
					),
					source_color.a * marker_color.a,
				),
			)
	var texture := ImageTexture.create_from_image(image)
	texture.set_meta(&"channel_mask_source", source.resource_path)
	return texture


func _refresh_unlocks() -> void:
	if not is_node_ready() or _unlocks == null:
		return
	var brush_popup: PopupMenu = _brush_option.get_popup()
	for index: int in range(_brush_option.item_count):
		var brush_size: int = _brush_option.get_item_id(index)
		brush_popup.set_item_disabled(
			index, not _unlocks.is_brush_size_unlocked(brush_size)
		)
	var grid_popup: PopupMenu = _grid_option.get_popup()
	for index: int in range(_grid_option.item_count):
		var grid_size: int = _grid_option.get_item_id(index)
		grid_popup.set_item_disabled(
			index, not _unlocks.is_grid_size_unlocked(grid_size)
		)
	for color_id: StringName in _color_buttons:
		var button: Button = _color_buttons[color_id]
		button.disabled = not _unlocks.is_color_unlocked(color_id)
		_apply_color_button_style(
			button,
			color_id,
			(
				_service != null
				and not _service.is_eraser_mode()
				and _service.get_color_id() == color_id
			),
		)


func _apply_color_button_style(
	button: Button,
	color_id: StringName,
	selected: bool,
) -> void:
	var color: Color = (
		SurfaceDrawingPalette.get_color(color_id)
		if not button.disabled
		else UtilityPageStyleType.OCEAN_DISABLED
	)
	for style_name: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color.lightened(0.12) if style_name == &"hover" else color
		style.set_border_width_all(3 if selected else 0)
		style.border_color = UtilityPageStyleType.OCEAN_TEXT_PRIMARY
		style.set_corner_radius_all(17)
		button.add_theme_stylebox_override(style_name, style)
	var disabled_style := StyleBoxFlat.new()
	disabled_style.bg_color = UtilityPageStyleType.OCEAN_DISABLED
	disabled_style.set_corner_radius_all(17)
	button.add_theme_stylebox_override("disabled", disabled_style)


func _toggle_mode() -> void:
	if _service != null:
		_service.set_placement_mode(not _service.is_placement_mode())


func _select_brush(index: int) -> void:
	if _service != null:
		_service.set_brush_size(_brush_option.get_item_id(index))


func _select_grid(index: int) -> void:
	if _service != null:
		_service.set_grid_size(_grid_option.get_item_id(index))


func _select_color(color_id: StringName) -> void:
	if _service != null:
		_service.set_color_id(color_id)


func _toggle_eraser() -> void:
	if _service != null:
		_service.set_eraser_mode(not _service.is_eraser_mode())


func _undo_last_stroke() -> void:
	if _service != null:
		_service.request_undo_last_stroke()


func _arm_guide_action(action: int) -> void:
	if _service != null:
		_service.arm_guide_action(action)


func _on_unlocks_changed(_unlock_mask: int) -> void:
	_refresh_unlocks()


func _on_service_state_changed(
	is_active: bool,
	mode_name: String,
	_color_name: String,
	color_value: Color,
	brush_size: int,
	grid_size: int,
	_status: String,
) -> void:
	visible = is_active
	if not is_active:
		hide_virtual_pointer_overlay()
		return
	_mode_button.icon = (
		GRID_MODE_ICON if mode_name == "place grid" else MARKER_MODE_ICON
	)
	_marker_mode_material.set_shader_parameter("marker_color", color_value)
	_apply_marker_color_to_brush_icons(color_value)
	_mode_button.accessibility_name = (
		"switch to marker mode"
		if mode_name == "place grid"
		else "switch to grid mode"
	)
	_mode_button.tooltip_text = (
		"Switch to marker mode"
		if mode_name == "place grid"
		else "Switch to grid mode"
	)
	_select_option_by_id(_brush_option, brush_size)
	_select_option_by_id(_grid_option, grid_size)
	_refresh_action_state()
	_refresh_unlocks()


func _refresh_action_state() -> void:
	if _service == null:
		return
	_eraser_button.button_pressed = _service.is_eraser_mode()
	var guide_action: int = _service.get_armed_guide_action()
	_hide_guide_button.button_pressed = (
		guide_action == NetworkSurfaceDrawingService.GuideAction.HIDE
	)
	_restore_guide_button.button_pressed = (
		guide_action == NetworkSurfaceDrawingService.GuideAction.RESTORE
	)
	_finalize_guide_button.button_pressed = (
		guide_action == NetworkSurfaceDrawingService.GuideAction.FINALIZE
	)


func _select_option_by_id(option: OptionButton, item_id: int) -> void:
	for index: int in range(option.item_count):
		if option.get_item_id(index) == item_id:
			option.select(index)
			return
