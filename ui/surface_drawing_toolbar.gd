class_name SurfaceDrawingToolbar
extends PanelContainer

const UtilityPageStyleType = preload("res://ui/utility_page_style.gd")

@onready var _mode_button: Button = %ModeButton
@onready var _brush_option: OptionButton = %BrushOption
@onready var _grid_option: OptionButton = %GridOption
@onready var _color_list: VBoxContainer = %ColorList

var _service: NetworkSurfaceDrawingService
var _unlocks: PlayerArtUnlocks
var _color_buttons: Dictionary[StringName, Button] = {}


func _ready() -> void:
	UtilityPageStyleType.apply_page(self)
	var panel: StyleBoxFlat = UtilityPageStyleType.panel_style()
	panel.content_margin_left = 10.0
	panel.content_margin_top = 10.0
	panel.content_margin_right = 10.0
	panel.content_margin_bottom = 10.0
	add_theme_stylebox_override("panel", panel)
	UtilityPageStyleType.apply_ocean_button(_mode_button)
	UtilityPageStyleType.apply_ocean_button(_brush_option)
	UtilityPageStyleType.apply_ocean_button(_grid_option)
	_mode_button.custom_minimum_size = Vector2(48, 48)
	_make_mode_button_round()
	_mode_button.pressed.connect(_toggle_mode)
	_brush_option.item_selected.connect(_select_brush)
	_grid_option.item_selected.connect(_select_grid)
	_build_options()
	hide()


func _make_mode_button_round() -> void:
	for style_name: StringName in [
		&"normal", &"hover", &"pressed", &"focus", &"disabled",
	]:
		var existing: StyleBox = _mode_button.get_theme_stylebox(style_name)
		var style := existing.duplicate() as StyleBoxFlat
		if style == null:
			continue
		style.set_corner_radius_all(24)
		_mode_button.add_theme_stylebox_override(style_name, style)


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


func owns_pointer_event(event: InputEvent) -> bool:
	if not visible:
		return false
	if _brush_option.get_popup().visible or _grid_option.get_popup().visible:
		return true
	if event is InputEventMouse:
		return get_global_rect().has_point((event as InputEventMouse).position)
	return false


func _build_options() -> void:
	_brush_option.clear()
	for brush_size: int in PlayerArtUnlocks.BRUSH_SIZES:
		_brush_option.add_item("%d×" % brush_size, brush_size)
	_grid_option.clear()
	for grid_size: int in PlayerArtUnlocks.GRID_SIZES:
		_grid_option.add_item("%d×" % grid_size, grid_size)
	for child: Node in _color_list.get_children():
		child.queue_free()
	_color_buttons.clear()
	for color_id: StringName in SurfaceDrawingPalette.get_color_ids():
		var button := Button.new()
		button.custom_minimum_size = Vector2(34, 34)
		button.focus_mode = Control.FOCUS_ALL
		button.tooltip_text = SurfaceDrawingPalette.get_display_name(color_id)
		button.pressed.connect(_select_color.bind(color_id))
		_color_list.add_child(button)
		_color_buttons[color_id] = button
		_apply_color_button_style(button, color_id, false)


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
			_service != null and _service.get_color_id() == color_id,
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


func _on_unlocks_changed(_unlock_mask: int) -> void:
	_refresh_unlocks()


func _on_service_state_changed(
	is_active: bool,
	mode_name: String,
	_color_name: String,
	_color_value: Color,
	brush_size: int,
	grid_size: int,
	_status: String,
) -> void:
	visible = is_active
	if not is_active:
		return
	_mode_button.text = "▦" if mode_name == "place grid" else "●"
	_mode_button.tooltip_text = (
		"Switch to marker mode"
		if mode_name == "place grid"
		else "Switch to grid mode"
	)
	_select_option_by_id(_brush_option, brush_size)
	_select_option_by_id(_grid_option, grid_size)
	_refresh_unlocks()


func _select_option_by_id(option: OptionButton, item_id: int) -> void:
	for index: int in range(option.item_count):
		if option.get_item_id(index) == item_id:
			option.select(index)
			return
