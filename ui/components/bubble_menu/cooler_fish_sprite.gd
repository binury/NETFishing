class_name CoolerFishSprite
extends Button

@onready var _visual_root: Control = %VisualRoot
@onready var _fish_shadow: TextureRect = %FishShadow
@onready var _fish_texture: TextureRect = %FishTexture
@onready var _favorite_marker: Label = %FavoriteMarker

var catch_id: StringName
var _display_name: String = ""
var _neutral_position := Vector2.ZERO
var _target_position := Vector2.ZERO
var _motion_phase: float = 0.0
var _depth_scale: float = 1.0
var _batch_selected: bool = false
var _focused_catch: bool = false
var _hovered: bool = false
var _rarity_color := Color.WHITE


func _ready() -> void:
	resized.connect(_update_visual_pivot)
	focus_entered.connect(_refresh_style)
	focus_exited.connect(_refresh_style)
	mouse_entered.connect(func() -> void:
		_hovered = true
		_refresh_style()
	)
	mouse_exited.connect(func() -> void:
		_hovered = false
		_refresh_style()
	)
	_update_visual_pivot()
	_refresh_style()


func configure(
	identity: StringName,
	display_name: String,
	texture: Texture2D,
	phase: float,
	depth_scale: float,
	rarity_color: Color,
) -> void:
	catch_id = identity
	_display_name = display_name
	_fish_texture.texture = texture
	_fish_shadow.texture = texture
	_motion_phase = phase
	_depth_scale = depth_scale
	_rarity_color = rarity_color
	_refresh_style()
	tooltip_text = "%s · drag to a hotbar slot" % _display_name


func _get_drag_data(_at_position: Vector2) -> Variant:
	if catch_id.is_empty() or disabled or _fish_texture.texture == null:
		return null
	var preview := VBoxContainer.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_theme_constant_override("separation", 2)
	var texture := TextureRect.new()
	texture.custom_minimum_size = Vector2(72.0, 52.0)
	texture.texture = _fish_texture.texture
	texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(texture)
	var label := Label.new()
	label.text = _display_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 12)
	preview.add_child(label)
	set_drag_preview(preview)
	return {
		"kind": "cooler_fish",
		"catch_id": String(catch_id),
	}


func set_target_position(target: Vector2, immediate: bool = false) -> void:
	_target_position = target
	if immediate:
		_neutral_position = target
	position = _neutral_position


func set_item_state(
	batch_selected: bool,
	focused_catch: bool,
	favorite: bool,
) -> void:
	_batch_selected = batch_selected
	_focused_catch = focused_catch
	_favorite_marker.visible = favorite
	_refresh_style()


func advance_presentation(delta: float, elapsed: float) -> void:
	var response: float = 1.0 - exp(-9.0 * delta)
	_neutral_position = _neutral_position.lerp(_target_position, response)
	position = _neutral_position
	var bob: float = sin(elapsed * TAU / 7.2 + _motion_phase) * 1.1
	var tilt: float = sin(elapsed * TAU / 9.0 + _motion_phase * 1.31) * 0.018
	var interaction_lift: float = 0.0
	if _batch_selected:
		interaction_lift += 3.0
	if _focused_catch or has_focus():
		interaction_lift += 1.5
	elif _hovered:
		interaction_lift += 0.8
	_visual_root.position = Vector2(0.0, bob - interaction_lift)
	_visual_root.rotation = tilt
	var emphasis: float = 1.0
	if _batch_selected:
		emphasis += 0.085
	if _focused_catch or has_focus():
		emphasis += 0.035
	elif _hovered:
		emphasis += 0.045
	_visual_root.scale = Vector2.ONE * _depth_scale * emphasis


func _has_point(point: Vector2) -> bool:
	var radius: float = minf(size.x, size.y) * 0.48
	if radius <= 0.0:
		return false
	return (point - size * 0.5).length_squared() <= radius * radius


func _update_visual_pivot() -> void:
	_visual_root.pivot_offset = size * 0.5


func _refresh_style() -> void:
	var idle := StyleBoxEmpty.new()
	var normal := _make_rarity_style(_rarity_color, 2, 0.25)
	var hover := _make_rarity_style(_rarity_color.lightened(0.08), 4, 0.34)
	var selected_fill: Color = (
		_rarity_color.lightened(0.12)
		if _batch_selected
		else _rarity_color
	)
	var selected := _make_rarity_style(
		selected_fill,
		6 if _batch_selected else 4,
		0.46 if _batch_selected else 0.34,
	)
	var circle_visible: bool = (
		_batch_selected
		or _hovered
		or has_focus()
	)
	var base_style: StyleBox = idle
	if circle_visible:
		base_style = (
			selected
			if _batch_selected or _focused_catch
			else normal
		)
	add_theme_stylebox_override(
		"normal",
		base_style,
	)
	add_theme_stylebox_override("hover", selected if _batch_selected else hover)
	add_theme_stylebox_override("focus", selected)
	add_theme_stylebox_override("pressed", selected)


func _make_rarity_style(
	fill: Color,
	shadow_size: int,
	shadow_alpha: float,
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(0)
	style.set_corner_radius_all(128)
	style.shadow_color = Color(0.01, 0.045, 0.06, shadow_alpha)
	style.shadow_size = shadow_size
	style.shadow_offset = Vector2(0.0, 2.0)
	return style
