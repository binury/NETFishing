class_name PlayerArtUnlocks
extends Node

const PlayerWalletType = preload("res://economy/player_wallet.gd")

signal unlocks_changed(unlock_mask: int)

const BASE_BRUSH_SIZE: int = 1
const BASE_GRID_SIZE: int = 16
const BRUSH_SIZES: Array[int] = [1, 2, 3, 4]
const GRID_SIZES: Array[int] = [16, 32, 64, 128]

# Stable product IDs are both the save and shop transaction boundary.
const PRODUCT_BITS: Dictionary[StringName, int] = {
	&"marker_ocean_teal": 0,
	&"marker_coral": 1,
	&"marker_sunny": 2,
	&"marker_leaf": 3,
	&"marker_blue": 4,
	&"marker_violet": 5,
	&"marker_charcoal": 6,
	&"brush_2x": 7,
	&"brush_3x": 8,
	&"brush_4x": 9,
	&"grid_32x": 10,
	&"grid_64x": 11,
	&"grid_128x": 12,
}
const COLOR_PRODUCTS: Dictionary[StringName, StringName] = {
	&"marker_ocean_teal": &"ocean_teal",
	&"marker_coral": &"coral",
	&"marker_sunny": &"sunny",
	&"marker_leaf": &"leaf",
	&"marker_blue": &"blue",
	&"marker_violet": &"violet",
	&"marker_charcoal": &"charcoal",
}
const BRUSH_PRODUCTS: Dictionary[StringName, int] = {
	&"brush_2x": 2,
	&"brush_3x": 3,
	&"brush_4x": 4,
}
const GRID_PRODUCTS: Dictionary[StringName, int] = {
	&"grid_32x": 32,
	&"grid_64x": 64,
	&"grid_128x": 128,
}
const ALL_UNLOCK_MASK: int = (1 << 13) - 1

var _unlock_mask: int = 0


func get_unlock_mask() -> int:
	return _unlock_mask


func owns_product(product_id: StringName) -> bool:
	var bit: int = get_product_bit(product_id)
	return bit >= 0 and (_unlock_mask & (1 << bit)) != 0


func unlock_product(product_id: StringName) -> bool:
	var bit: int = get_product_bit(product_id)
	if bit < 0 or owns_product(product_id):
		return false
	_unlock_mask |= 1 << bit
	unlocks_changed.emit(_unlock_mask)
	return true


func purchase_product(
	product_id: StringName,
	wallet: PlayerWalletType,
	cost: int,
) -> bool:
	if (
		wallet == null
		or cost < 0
		or owns_product(product_id)
		or get_product_bit(product_id) < 0
		or not wallet.can_afford(cost)
	):
		return false
	if not wallet.debit(cost):
		return false
	if unlock_product(product_id):
		return true
	if not wallet.credit(cost):
		push_error("Art upgrade purchase rollback failed.")
	return false


func restore_mask(value: int) -> bool:
	if value < 0 or (value & ~ALL_UNLOCK_MASK) != 0:
		return false
	var changed: bool = _unlock_mask != value
	_unlock_mask = value
	if changed:
		unlocks_changed.emit(_unlock_mask)
	return true


func reset_to_defaults() -> void:
	restore_mask(0)


func to_save_data() -> Dictionary:
	return {"unlock_mask": _unlock_mask}


func get_unlocked_color_ids() -> Array[StringName]:
	var result: Array[StringName] = [SurfaceDrawingPalette.DEFAULT_COLOR_ID]
	for product_id: StringName in COLOR_PRODUCTS:
		if owns_product(product_id):
			result.append(StringName(str(COLOR_PRODUCTS[product_id])))
	return result


func get_unlocked_brush_sizes() -> Array[int]:
	var result: Array[int] = [BASE_BRUSH_SIZE]
	for product_id: StringName in BRUSH_PRODUCTS:
		if owns_product(product_id):
			result.append(int(BRUSH_PRODUCTS[product_id]))
	result.sort()
	return result


func get_unlocked_grid_sizes() -> Array[int]:
	var result: Array[int] = [BASE_GRID_SIZE]
	for product_id: StringName in GRID_PRODUCTS:
		if owns_product(product_id):
			result.append(int(GRID_PRODUCTS[product_id]))
	result.sort()
	return result


func is_color_unlocked(color_id: StringName) -> bool:
	return color_id in get_unlocked_color_ids()


func is_brush_size_unlocked(brush_size: int) -> bool:
	return brush_size in get_unlocked_brush_sizes()


func is_grid_size_unlocked(grid_size: int) -> bool:
	return grid_size in get_unlocked_grid_sizes()


static func get_product_bit(product_id: StringName) -> int:
	return int(PRODUCT_BITS.get(product_id, -1))


static func is_product_id(product_id: StringName) -> bool:
	return PRODUCT_BITS.has(product_id)


static func resulting_mask(current_mask: int, product_id: StringName) -> int:
	var bit: int = get_product_bit(product_id)
	if bit < 0:
		return current_mask
	return current_mask | (1 << bit)


static func color_id_for_product(product_id: StringName) -> StringName:
	return StringName(str(COLOR_PRODUCTS.get(product_id, "")))


static func brush_size_for_product(product_id: StringName) -> int:
	return int(BRUSH_PRODUCTS.get(product_id, -1))


static func grid_size_for_product(product_id: StringName) -> int:
	return int(GRID_PRODUCTS.get(product_id, -1))
