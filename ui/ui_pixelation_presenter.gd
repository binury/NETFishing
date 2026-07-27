class_name UIPixelationPresenter
extends SubViewportContainer

const MIN_UI_VIEWPORT_SIZE: Vector2i = Vector2i(320, 180)

signal effective_pixel_size_changed(
	requested_pixel_size: int,
	effective_pixel_size: int,
)

@onready var _ui_viewport: SubViewport = $UIViewport
@onready var _ui_root: Control = $UIViewport/GameUI/UIRoot

var _requested_pixel_size: int = PlayerSettings.DEFAULT_UI_PIXEL_SIZE
var _effective_pixel_size: int = PlayerSettings.DEFAULT_UI_PIXEL_SIZE
var _gameplay_active: bool = false
var _interactive_ui_open: bool = false


func _ready() -> void:
	var root_viewport: Viewport = get_viewport()
	root_viewport.size_changed.connect(_resize_presentation)
	_resize_presentation()


func set_pixel_size(pixel_size: int) -> void:
	_requested_pixel_size = clampi(
		pixel_size,
		PlayerSettings.MIN_UI_PIXEL_SIZE,
		PlayerSettings.MAX_UI_PIXEL_SIZE
	)
	_resize_presentation()


func get_requested_pixel_size() -> int:
	return _requested_pixel_size


func get_effective_pixel_size() -> int:
	return _effective_pixel_size


func get_ui_viewport_size() -> Vector2i:
	return _ui_viewport.size


func set_gameplay_active(active: bool) -> void:
	_gameplay_active = active
	_refresh_mouse_filter()


func set_interactive_ui_open(is_open: bool) -> void:
	_interactive_ui_open = is_open
	_refresh_mouse_filter()


func _refresh_mouse_filter() -> void:
	mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if not _gameplay_active or _interactive_ui_open
		else Control.MOUSE_FILTER_IGNORE
	)


func _resize_presentation() -> void:
	if not is_node_ready():
		return
	var root_size: Vector2i = get_window().size
	if root_size.x <= 0 or root_size.y <= 0:
		return
	var previous_effective_size: int = _effective_pixel_size
	_effective_pixel_size = _resolve_effective_pixel_size(root_size)
	var render_scale: float = PlayerSettings.get_ui_render_scale(
		_effective_pixel_size
	)
	var viewport_size := Vector2i(
		ceili(float(root_size.x) * render_scale),
		ceili(float(root_size.y) * render_scale)
	)
	var presentation_size: Vector2 = Vector2(viewport_size) / render_scale
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = (Vector2(root_size) - presentation_size) * 0.5
	size = Vector2(viewport_size)
	scale = Vector2.ONE / render_scale
	stretch_shrink = 1
	_ui_root.position = Vector2.ZERO
	_ui_root.scale = Vector2.ONE * render_scale
	_ui_root.size = Vector2(root_size)
	if (
		previous_effective_size != _effective_pixel_size
		or _requested_pixel_size != _effective_pixel_size
	):
		effective_pixel_size_changed.emit(
			_requested_pixel_size,
			_effective_pixel_size
		)


func _resolve_effective_pixel_size(root_size: Vector2i) -> int:
	for candidate: int in range(_requested_pixel_size, 0, -1):
		var render_scale: float = PlayerSettings.get_ui_render_scale(candidate)
		var candidate_size := Vector2i(
			ceili(float(root_size.x) * render_scale),
			ceili(float(root_size.y) * render_scale)
		)
		if (
			candidate_size.x >= MIN_UI_VIEWPORT_SIZE.x
			and candidate_size.y >= MIN_UI_VIEWPORT_SIZE.y
		):
			return candidate
	return PlayerSettings.MIN_UI_PIXEL_SIZE
