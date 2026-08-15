class_name PlayerItemEffects
extends Node

const ItemDataType = preload("res://items/item_data.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")

signal effects_changed

const COFFEE_ID: StringName = &"coffee"
const ENERGY_DRINK_ID: StringName = &"energy_drink"
const SNACK_ID: StringName = &"snack"
const FISH_FINDER_ID: StringName = &"fish_finder"
const BATTERIES_ID: StringName = &"batteries"
const EFFECT_IDS: Array[StringName] = [
	COFFEE_ID,
	ENERGY_DRINK_ID,
	SNACK_ID,
	FISH_FINDER_ID,
]
const FISH_FINDER_DEAD_MESSAGE: String = "hmm... batteries are dead..."
const COFFEE_DURATION: float = 90.0
const ENERGY_DRINK_DURATION: float = 90.0
const SNACK_DURATION: float = 60.0
const FISH_FINDER_DURATION: float = 120.0
const COFFEE_MOVEMENT_MULTIPLIER: float = 1.10
const ENERGY_REEL_MULTIPLIER: float = 1.15
const SNACK_BARRIER_BONUS: int = 1
const FISH_FINDER_BITE_MULTIPLIER: float = 0.80

var _remaining: Dictionary[StringName, float] = {
	COFFEE_ID: 0.0,
	ENERGY_DRINK_ID: 0.0,
	SNACK_ID: 0.0,
	FISH_FINDER_ID: 0.0,
}


func _process(delta: float) -> void:
	var changed: bool = false
	for item_id: StringName in _remaining:
		var previous: float = _remaining[item_id]
		if previous <= 0.0:
			continue
		var next: float = maxf(previous - delta, 0.0)
		_remaining[item_id] = next
		if next == 0.0:
			changed = true
	if changed:
		effects_changed.emit()


func use_consumable(
	item: ItemDataType,
	bag: PlayerBagType,
) -> bool:
	return use_item(item, bag)


func use_item(
	item: ItemDataType,
	bag: PlayerBagType,
) -> bool:
	var is_fish_finder: bool = (
		item != null
		and item.item_id == FISH_FINDER_ID
		and item.category == ItemDataType.Category.TOOL
		and item.equippable
	)
	if (
		item == null
		or bag == null
		or (
			item.category != ItemDataType.Category.CONSUMABLE
			and not is_fish_finder
		)
		or not item.usable
		or not _remaining.has(item.item_id)
		or not bag.owns_item(item.item_id)
	):
		return false
	var consumed_item_id: StringName = (
		BATTERIES_ID if is_fish_finder else item.item_id
	)
	if not bag.remove_item(consumed_item_id, 1):
		return false
	_remaining[item.item_id] = _get_duration(item.item_id)
	effects_changed.emit()
	return true


func activate_authoritative(item_id: StringName, duration: float) -> bool:
	if not _remaining.has(item_id) or not is_finite(duration) or duration <= 0.0:
		return false
	_remaining[item_id] = duration
	effects_changed.emit()
	return true


func restore_remaining(snapshot: Dictionary[StringName, float]) -> void:
	for item_id: StringName in _remaining:
		_remaining[item_id] = maxf(snapshot.get(item_id, 0.0), 0.0)
	effects_changed.emit()


func get_remaining_snapshot() -> Dictionary[StringName, float]:
	return _remaining.duplicate()


func get_registered_effect_ids() -> Array[StringName]:
	return EFFECT_IDS.duplicate()


func get_effect_duration(item_id: StringName) -> float:
	return _get_duration(item_id)


func reset_all() -> void:
	var changed: bool = false
	for item_id: StringName in _remaining:
		changed = changed or _remaining[item_id] > 0.0
		_remaining[item_id] = 0.0
	if changed:
		effects_changed.emit()


func get_remaining(item_id: StringName) -> float:
	return maxf(_remaining.get(item_id, 0.0), 0.0)


func is_active(item_id: StringName) -> bool:
	return get_remaining(item_id) > 0.0


func get_movement_multiplier() -> float:
	return COFFEE_MOVEMENT_MULTIPLIER if is_active(COFFEE_ID) else 1.0


func get_reel_multiplier() -> float:
	return ENERGY_REEL_MULTIPLIER if is_active(ENERGY_DRINK_ID) else 1.0


func get_barrier_bonus() -> int:
	return SNACK_BARRIER_BONUS if is_active(SNACK_ID) else 0


func get_bite_time_multiplier() -> float:
	return (
		FISH_FINDER_BITE_MULTIPLIER
		if is_active(FISH_FINDER_ID)
		else 1.0
	)


func get_rarity_weight_multiplier(rarity: int) -> float:
	if not is_active(FISH_FINDER_ID):
		return 1.0
	match rarity:
		0:
			return 1.0
		1:
			return 1.10
		2:
			return 1.15
		3:
			return 1.20
		_:
			return 1.25


func get_feedback(item_id: StringName) -> String:
	match item_id:
		COFFEE_ID:
			return "coffee active: movement speed increased."
		ENERGY_DRINK_ID:
			return "energy drink active: reeling speed increased."
		SNACK_ID:
			return "snack active: barrier damage increased."
		FISH_FINDER_ID:
			return "fish finder active: bites and uncommon catches improved."
		_:
			return ""


func _get_duration(item_id: StringName) -> float:
	match item_id:
		COFFEE_ID:
			return COFFEE_DURATION
		ENERGY_DRINK_ID:
			return ENERGY_DRINK_DURATION
		SNACK_ID:
			return SNACK_DURATION
		FISH_FINDER_ID:
			return FISH_FINDER_DURATION
		_:
			return 0.0
