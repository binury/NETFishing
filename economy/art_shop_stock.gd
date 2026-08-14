class_name ArtShopStock
extends RefCounted

const ART_KIT_ITEM_ID: StringName = &"art_kit"
const ART_KIT_PRICE: int = 50
const UPGRADE_PRICE: int = 50

const MARKER_PRODUCTS: Array[StringName] = [
	&"marker_ocean_teal",
	&"marker_coral",
	&"marker_sunny",
	&"marker_leaf",
	&"marker_blue",
	&"marker_violet",
	&"marker_charcoal",
]
const BRUSH_PRODUCTS: Array[StringName] = [
	&"brush_2x",
	&"brush_3x",
	&"brush_4x",
]
const GRID_PRODUCTS: Array[StringName] = [
	&"grid_32x",
	&"grid_64x",
	&"grid_128x",
]


static func get_price(product_id: StringName) -> int:
	if product_id == ART_KIT_ITEM_ID:
		return ART_KIT_PRICE
	return UPGRADE_PRICE if PlayerArtUnlocks.is_product_id(product_id) else -1


static func get_display_name(product_id: StringName) -> String:
	if product_id == ART_KIT_ITEM_ID:
		return "Art Kit"
	var color_id: StringName = PlayerArtUnlocks.color_id_for_product(product_id)
	if not color_id.is_empty():
		return "%s marker" % SurfaceDrawingPalette.get_display_name(color_id)
	var brush_size: int = PlayerArtUnlocks.brush_size_for_product(product_id)
	if brush_size > 0:
		return "%d× brush" % brush_size
	var grid_size: int = PlayerArtUnlocks.grid_size_for_product(product_id)
	if grid_size > 0:
		return "%d×%d grid" % [grid_size, grid_size]
	return "Unknown art supply"


static func get_description(product_id: StringName) -> String:
	if product_id == ART_KIT_ITEM_ID:
		return "Select the Art Kit in the Hotbar to paint."
	var color_id: StringName = PlayerArtUnlocks.color_id_for_product(product_id)
	if not color_id.is_empty():
		return "Unlocks this marker color in the Paint UI."
	var brush_size: int = PlayerArtUnlocks.brush_size_for_product(product_id)
	if brush_size > 0:
		return "Unlocks the %d× brush in the Paint UI." % brush_size
	var grid_size: int = PlayerArtUnlocks.grid_size_for_product(product_id)
	if grid_size > 0:
		return "Unlocks the %d×%d grid in the Paint UI." % [
			grid_size, grid_size,
		]
	return ""
