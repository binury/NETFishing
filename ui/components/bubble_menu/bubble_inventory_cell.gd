class_name BubbleInventoryCell
extends Button

@export var profile: BubbleMenuProfile

@onready var _icon: TextureRect = %Icon
@onready var _primary_label: Label = %PrimaryLabel
@onready var _secondary_label: Label = %SecondaryLabel
@onready var _favorite_marker: Label = %FavoriteMarker
@onready var _selected_marker: Label = %SelectedMarker

var _selected: bool = false
var _focused_item: bool = false
var _compact: bool = false
var _icon_texture: Texture2D
var _primary_text: String = ""
var _secondary_text: String = ""
var _favorite: bool = false


func _ready() -> void:
	focus_entered.connect(_refresh_style)
	focus_exited.connect(_refresh_style)
	_apply_compact_layout()
	_apply_content()
	_refresh_style()


func configure(
	icon_texture: Texture2D,
	primary_text: String,
	secondary_text: String,
) -> void:
	_icon_texture = icon_texture
	_primary_text = primary_text
	_secondary_text = secondary_text
	if is_node_ready():
		_apply_content()


func set_item_state(
	selected: bool,
	focused_item: bool,
	favorite: bool,
) -> void:
	_selected = selected
	_focused_item = focused_item
	_favorite = favorite
	if is_node_ready():
		_apply_content()
		_refresh_style()


func set_compact(compact: bool) -> void:
	_compact = compact
	if not is_node_ready():
		custom_minimum_size = (
			Vector2(104.0, 98.0)
			if compact
			else Vector2(144.0, 136.0)
		)
		return
	_apply_compact_layout()


func _apply_compact_layout() -> void:
	custom_minimum_size = (
		Vector2(104.0, 98.0)
		if _compact
		else Vector2(144.0, 136.0)
	)
	_icon.custom_minimum_size = (
		Vector2(72.0, 44.0)
		if _compact
		else Vector2(104.0, 68.0)
	)
	_primary_label.add_theme_font_size_override(
		"font_size",
		15 if _compact else 18,
	)
	_secondary_label.add_theme_font_size_override(
		"font_size",
		13 if _compact else 15,
	)


func _apply_content() -> void:
	_icon.texture = _icon_texture
	_primary_label.text = _primary_text
	_secondary_label.text = _secondary_text
	_selected_marker.visible = _selected
	_favorite_marker.visible = _favorite


func _has_point(point: Vector2) -> bool:
	var radius: Vector2 = size * 0.5
	if radius.x <= 0.0 or radius.y <= 0.0:
		return false
	var normalized: Vector2 = (point - radius) / radius
	return normalized.length_squared() <= 1.0


func _refresh_style() -> void:
	if profile == null:
		return
	var normal_style: StyleBoxFlat = profile.make_normal_style()
	var border_width: int = (
		profile.emphasized_border_width
		if _selected or _focused_item or has_focus()
		else profile.normal_border_width
	)
	normal_style.border_width_left = border_width
	normal_style.border_width_top = border_width
	normal_style.border_width_right = border_width
	normal_style.border_width_bottom = border_width
	if _selected:
		normal_style.bg_color = profile.pressed_fill
	if _focused_item:
		normal_style.border_color = profile.text_color
	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", profile.make_hover_style())
	add_theme_stylebox_override("focus", normal_style)
	add_theme_stylebox_override("pressed", profile.make_pressed_style())
	add_theme_stylebox_override("disabled", profile.make_disabled_style())
	add_theme_color_override("font_color", profile.text_color)
