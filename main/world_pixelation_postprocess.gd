class_name WorldPixelationPostprocess
extends CanvasLayer

@onready var _screen_grid: ColorRect = %ScreenGrid

var _pixel_size: int = PlayerSettings.DEFAULT_WORLD_PIXEL_SIZE
var _gameplay_active: bool = false


func _ready() -> void:
	get_viewport().size_changed.connect(_refresh_grid)
	_refresh_grid()


func set_pixel_size(pixel_size: int) -> void:
	_pixel_size = clampi(
		pixel_size,
		PlayerSettings.MIN_WORLD_PIXEL_SIZE,
		PlayerSettings.MAX_WORLD_PIXEL_SIZE
	)
	_refresh_grid()


func set_gameplay_active(active: bool) -> void:
	_gameplay_active = active
	_refresh_grid()


func get_grid_size() -> Vector2i:
	return PlayerSettings.get_world_grid_size(
		_pixel_size,
		get_window().size
	)


func _refresh_grid() -> void:
	if not is_node_ready():
		return
	var effect_enabled: bool = (
		_gameplay_active
		and _pixel_size != PlayerSettings.MIN_WORLD_PIXEL_SIZE
	)
	_screen_grid.visible = effect_enabled
	if not effect_enabled:
		return
	var shader_material := _screen_grid.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(
			"logical_grid_size",
			Vector2(get_grid_size())
		)
