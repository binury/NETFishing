class_name UIPixelationPresenter
extends SubViewportContainer

const MIN_UI_VIEWPORT_SIZE: Vector2i = Vector2i(256, 180)
const UIReferencePresentationType = preload(
	"res://ui/ui_reference_presentation.gd"
)

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
	var display_size := Vector2(root_size)
	var reference_scale: float = (
		UIReferencePresentationType.get_scale(display_size)
	)
	var previous_effective_size: int = _effective_pixel_size
	_effective_pixel_size = _resolve_effective_pixel_size(reference_scale)
	var render_height: int = _get_render_height(
		_effective_pixel_size,
		reference_scale,
	)
	var render_scale: float = (
		float(render_height)
		/ UIReferencePresentationType.REFERENCE_SIZE.y
	)
	var viewport_size := Vector2i(
		roundi(
			UIReferencePresentationType.REFERENCE_SIZE.x
			* render_scale
		),
		render_height,
	)
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = UIReferencePresentationType.get_offset(display_size)
	size = Vector2(viewport_size)
	scale = Vector2.ONE * (reference_scale / render_scale)
	stretch_shrink = 1
	_ui_root.position = Vector2.ZERO
	_ui_root.scale = Vector2.ONE * render_scale
	_ui_root.size = UIReferencePresentationType.REFERENCE_SIZE
	if (
		previous_effective_size != _effective_pixel_size
		or _requested_pixel_size != _effective_pixel_size
	):
		effective_pixel_size_changed.emit(
			_requested_pixel_size,
			_effective_pixel_size
		)


func _get_render_height(pixel_size: int, reference_scale: float) -> int:
	var displayed_canvas_height: int = maxi(
		1,
		roundi(
			UIReferencePresentationType.REFERENCE_SIZE.y
			* reference_scale
		),
	)
	if pixel_size == PlayerSettings.MIN_UI_PIXEL_SIZE:
		return displayed_canvas_height
	var target_height: int = PlayerSettings.get_ui_render_height(
		pixel_size,
		roundi(UIReferencePresentationType.REFERENCE_SIZE.y),
	)
	return mini(displayed_canvas_height, target_height)


func _resolve_effective_pixel_size(reference_scale: float) -> int:
	for candidate: int in range(_requested_pixel_size, 0, -1):
		var candidate_height: int = _get_render_height(
			candidate,
			reference_scale,
		)
		var candidate_size := Vector2i(
			roundi(
				UIReferencePresentationType.REFERENCE_SIZE.x
				* float(candidate_height)
				/ UIReferencePresentationType.REFERENCE_SIZE.y
			),
			candidate_height,
		)
		if (
			candidate_size.x >= MIN_UI_VIEWPORT_SIZE.x
			and candidate_size.y >= MIN_UI_VIEWPORT_SIZE.y
		):
			return candidate
	return PlayerSettings.MIN_UI_PIXEL_SIZE
