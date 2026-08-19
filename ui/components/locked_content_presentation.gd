class_name LockedContentPresentation
extends RefCounted

const UtilityPageStyleType = preload("res://ui/utility_page_style.gd")
const ICON: Texture2D = preload("res://ui/icons/pictograms/lock_light.png")

const LARGE_ICON_SIZE: float = 24.0
const COMPACT_ICON_SIZE: float = 18.0
const LARGE_PRESENTATION_THRESHOLD: float = 70.0
const ICON_ALPHA: float = 0.18
const BACKGROUND_ALPHA: float = 0.38


static func icon_size_for(presentation_size: Vector2) -> Vector2:
	var edge: float = (
		LARGE_ICON_SIZE
		if minf(presentation_size.x, presentation_size.y)
		>= LARGE_PRESENTATION_THRESHOLD
		else COMPACT_ICON_SIZE
	)
	return Vector2(edge, edge)


static func icon_modulate(alpha: float = ICON_ALPHA) -> Color:
	return Color(UtilityPageStyleType.OCEAN_DISABLED, alpha)


static func disabled_background_color() -> Color:
	return Color(UtilityPageStyleType.OCEAN_FIELD, BACKGROUND_ALPHA)


static func make_icon_texture(
	icon_size: int = int(COMPACT_ICON_SIZE),
	canvas_size: int = icon_size,
) -> Texture2D:
	var source_image: Image = ICON.get_image()
	if source_image == null or source_image.is_empty():
		return ICON
	var image := source_image.duplicate() as Image
	if image.is_compressed() and image.decompress() != OK:
		return ICON
	image.convert(Image.FORMAT_RGBA8)
	image.resize(
		icon_size,
		icon_size,
		Image.INTERPOLATE_NEAREST,
	)
	if canvas_size > icon_size:
		var canvas := Image.create(
			canvas_size,
			canvas_size,
			false,
			Image.FORMAT_RGBA8,
		)
		canvas.fill(Color.TRANSPARENT)
		var inset := Vector2i.ONE * ((canvas_size - icon_size) / 2)
		canvas.blend_rect(
			image,
			Rect2i(Vector2i.ZERO, Vector2i(icon_size, icon_size)),
			inset,
		)
		image = canvas
	var texture := ImageTexture.create_from_image(image)
	texture.set_meta(&"locked_content_icon", true)
	texture.set_meta(&"locked_content_icon_size", icon_size)
	texture.set_meta(&"locked_content_canvas_size", canvas_size)
	return texture
