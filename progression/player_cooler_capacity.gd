class_name PlayerCoolerCapacity
extends Node

const PlayerWalletType = preload("res://economy/player_wallet.gd")

signal capacity_changed(level: int, capacity: int)

const CAPACITIES: Array[int] = [12, 18, 24, 32, 40]
const EXPANSION_COSTS: Array[int] = [75, 175, 400, 850]
const MAX_LEVEL: int = 4

var _capacity_level: int = 0


func get_level() -> int:
	return _capacity_level


func get_capacity() -> int:
	return CAPACITIES[_capacity_level]


func get_next_capacity() -> int:
	if _capacity_level >= MAX_LEVEL:
		return -1
	return CAPACITIES[_capacity_level + 1]


func get_next_cost() -> int:
	if _capacity_level >= MAX_LEVEL:
		return -1
	return EXPANSION_COSTS[_capacity_level]


func can_purchase(wallet: PlayerWalletType) -> bool:
	var cost: int = get_next_cost()
	return wallet != null and cost >= 0 and wallet.can_afford(cost)


func purchase(wallet: PlayerWalletType) -> bool:
	if not can_purchase(wallet):
		return false
	var cost: int = get_next_cost()
	if not wallet.debit(cost):
		return false
	_capacity_level += 1
	capacity_changed.emit(_capacity_level, get_capacity())
	return true


func restore_level(level: int) -> bool:
	var validated: int = clampi(level, 0, MAX_LEVEL)
	var changed: bool = _capacity_level != validated
	_capacity_level = validated
	if changed:
		capacity_changed.emit(_capacity_level, get_capacity())
	return true


func reset_to_defaults() -> void:
	restore_level(0)


func to_save_data() -> Dictionary:
	return {"capacity_level": _capacity_level}
