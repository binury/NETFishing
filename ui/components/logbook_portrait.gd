class_name LogbookPortrait
extends TextureRect

const ENTRY_FRAME_SIZE := Vector2(86.0, 40.0)
const DETAIL_FRAME_SIZE := Vector2(240.0, 132.0)

static var _normalized_textures: Dictionary[String, Texture2D] = {}

var source_texture: Texture2D


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func configure(
	portrait_texture: Texture2D,
	frame_size: Vector2,
	portrait_material: Material = null,
) -> void:
	source_texture = portrait_texture
	custom_minimum_size = frame_size
	material = portrait_material
	texture = _normalize_visible_bounds(portrait_texture)


func configure_fitted(
	portrait_texture: Texture2D,
	maximum_size: Vector2,
	portrait_material: Material = null,
) -> void:
	source_texture = portrait_texture
	material = portrait_material
	texture = _normalize_visible_bounds(portrait_texture)
	if texture == null:
		custom_minimum_size = Vector2.ZERO
		return
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		custom_minimum_size = Vector2.ZERO
		return
	var fit_scale: float = minf(
		maximum_size.x / texture_size.x,
		maximum_size.y / texture_size.y,
	)
	custom_minimum_size = texture_size * fit_scale


static func _normalize_visible_bounds(
	portrait_texture: Texture2D,
) -> Texture2D:
	if portrait_texture == null:
		return null
	var cache_key: String = portrait_texture.resource_path
	if cache_key.is_empty():
		cache_key = "instance_%d" % portrait_texture.get_instance_id()
	var cached: Texture2D = _normalized_textures.get(cache_key) as Texture2D
	if cached != null:
		return cached
	var image: Image = portrait_texture.get_image()
	if image == null or image.is_empty():
		_normalized_textures[cache_key] = portrait_texture
		return portrait_texture
	var full_rect := Rect2i(Vector2i.ZERO, image.get_size())
	var visible_rect: Rect2i = image.get_used_rect()
	if visible_rect.size == Vector2i.ZERO or visible_rect == full_rect:
		_normalized_textures[cache_key] = portrait_texture
		return portrait_texture
	var normalized := AtlasTexture.new()
	normalized.atlas = portrait_texture
	normalized.region = Rect2(visible_rect)
	_normalized_textures[cache_key] = normalized
	return normalized
