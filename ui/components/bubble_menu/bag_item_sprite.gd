class_name BagItemSprite
extends ItemDragSource

signal drag_started
signal drag_finished

@onready var _visual_root: Control = %VisualRoot
@onready var _item_texture: TextureRect = %ItemTexture
@onready var _quantity_badge: PanelContainer = %QuantityBadge
@onready var _quantity_label: Label = %QuantityLabel
@onready var _compatibility_marker: Label = %CompatibilityMarker

var _motion_phase: float = 0.0
var _depth_scale: float = 1.0
var _selected: bool = false
var _hovered: bool = false
var _dragging: bool = false


func _ready() -> void:
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_refresh_style)
	focus_exited.connect(_refresh_style)
	resized.connect(_update_visual_pivot)
	_update_visual_pivot()
	_apply_quantity_style()
	_refresh_style()


func configure_item(
	new_item_id: StringName,
	new_item_name: String,
	new_icon: Texture2D,
	quantity: int,
	hotbar_compatible: bool,
	phase: float,
	depth_scale: float,
) -> void:
	setup(new_item_id, new_item_name, new_icon)
	_item_texture.texture = new_icon
	_quantity_label.text = "×%d" % quantity
	_quantity_badge.visible = quantity > 1
	_compatibility_marker.visible = not hotbar_compatible
	_motion_phase = phase
	_depth_scale = depth_scale


func set_selected(selected: bool) -> void:
	_selected = selected
	_refresh_style()


func advance_presentation(elapsed: float, motion_enabled: bool) -> void:
	if not motion_enabled or _dragging:
		return
	var bob: float = sin(elapsed * TAU / 7.4 + _motion_phase) * 0.9
	var tilt: float = sin(
		elapsed * TAU / 10.2 + _motion_phase * 1.29
	) * 0.014
	_visual_root.position = Vector2(0.0, bob)
	_visual_root.rotation = tilt
	var emphasis: float = 1.04 if _hovered or has_focus() else 1.0
	_visual_root.scale = Vector2.ONE * _depth_scale * emphasis


func _get_drag_data(at_position: Vector2) -> Variant:
	var payload: Variant = super(at_position)
	if payload != null:
		_dragging = true
		drag_started.emit()
	return payload


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _dragging:
		_dragging = false
		drag_finished.emit()


func _has_point(point: Vector2) -> bool:
	var radius: Vector2 = size * Vector2(0.46, 0.42)
	if radius.x <= 0.0 or radius.y <= 0.0:
		return false
	var normalized: Vector2 = (point - size * 0.5) / radius
	return normalized.length_squared() <= 1.0


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_refresh_style()


func _update_visual_pivot() -> void:
	_visual_root.pivot_offset = size * 0.5


func _refresh_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.9, 0.75, 0.12) if _selected else Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	var width: int = 0
	if _selected:
		style.border_color = Color(0.28, 0.19, 0.1, 1.0)
		width = 4
	if has_focus():
		style.border_color = Color(0.035, 0.145, 0.22, 1.0)
		width = 4
	elif _hovered:
		style.border_color = Color(0.48, 0.35, 0.2, 0.9)
		width = 2
	style.set_border_width_all(width)
	style.set_corner_radius_all(64)
	for state: StringName in [
		&"normal",
		&"hover",
		&"focus",
		&"pressed",
	]:
		add_theme_stylebox_override(state, style)


func _apply_quantity_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.94, 0.86, 0.64, 1.0)
	style.border_color = Color(0.31, 0.22, 0.12, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	_quantity_badge.add_theme_stylebox_override("panel", style)
