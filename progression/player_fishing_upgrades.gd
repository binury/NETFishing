class_name PlayerFishingUpgrades
extends Node

const PlayerWalletType = preload("res://economy/player_wallet.gd")

signal upgrades_changed(reel_speed_level: int, barrier_power_level: int)

const MAX_REEL_SPEED_LEVEL: int = 5
const MAX_BARRIER_POWER_LEVEL: int = 7
const REEL_SPEED_COSTS: Array[int] = [50, 125, 300, 650, 1250]
const BARRIER_POWER_COSTS: Array[int] = [
	100,
	275,
	700,
	1500,
	3000,
	6000,
	12000,
]

var _reel_speed_level: int = 0
var _barrier_power_level: int = 0


func get_reel_speed_level() -> int:
	return _reel_speed_level


func get_barrier_power_level() -> int:
	return _barrier_power_level


func get_reel_speed_multiplier() -> float:
	return 1.0 + float(_reel_speed_level) * 0.10


func get_barrier_damage() -> int:
	return get_barrier_damage_for_level(_barrier_power_level)


static func get_barrier_damage_for_level(level: int) -> int:
	return 1 << clampi(level, 0, MAX_BARRIER_POWER_LEVEL)


func get_next_reel_speed_cost() -> int:
	if _reel_speed_level >= MAX_REEL_SPEED_LEVEL:
		return -1
	return REEL_SPEED_COSTS[_reel_speed_level]


func get_next_barrier_power_cost() -> int:
	if _barrier_power_level >= MAX_BARRIER_POWER_LEVEL:
		return -1
	return BARRIER_POWER_COSTS[_barrier_power_level]


func can_purchase_reel_speed(wallet: PlayerWalletType) -> bool:
	var cost: int = get_next_reel_speed_cost()
	return wallet != null and cost >= 0 and wallet.can_afford(cost)


func can_purchase_barrier_power(wallet: PlayerWalletType) -> bool:
	var cost: int = get_next_barrier_power_cost()
	return wallet != null and cost >= 0 and wallet.can_afford(cost)


func purchase_reel_speed(wallet: PlayerWalletType) -> bool:
	return _purchase_level(true, wallet)


func purchase_barrier_power(wallet: PlayerWalletType) -> bool:
	return _purchase_level(false, wallet)


func reset_to_defaults() -> void:
	restore_levels(0, 0)


func restore_levels(
	reel_speed_level: int,
	barrier_power_level: int,
) -> bool:
	var validated_reel: int = clampi(
		reel_speed_level,
		0,
		MAX_REEL_SPEED_LEVEL
	)
	var validated_barrier: int = clampi(
		barrier_power_level,
		0,
		MAX_BARRIER_POWER_LEVEL
	)
	var changed: bool = (
		_reel_speed_level != validated_reel
		or _barrier_power_level != validated_barrier
	)
	_reel_speed_level = validated_reel
	_barrier_power_level = validated_barrier
	if changed:
		upgrades_changed.emit(
			_reel_speed_level,
			_barrier_power_level
		)
	return true


func restore_from_save(data: Dictionary) -> void:
	var reel_value: Variant = data.get("reel_speed_level", 0)
	var barrier_value: Variant = data.get("barrier_power_level", 0)
	restore_levels(
		int(reel_value) if reel_value is int or reel_value is float else 0,
		int(barrier_value)
		if barrier_value is int or barrier_value is float
		else 0
	)


func to_save_data() -> Dictionary:
	return {
		"reel_speed_level": _reel_speed_level,
		"barrier_power_level": _barrier_power_level,
	}


func _purchase_level(
	is_reel_speed: bool,
	wallet: PlayerWalletType,
) -> bool:
	if wallet == null:
		return false
	var current_level: int = (
		_reel_speed_level if is_reel_speed else _barrier_power_level
	)
	var maximum_level: int = (
		MAX_REEL_SPEED_LEVEL
		if is_reel_speed
		else MAX_BARRIER_POWER_LEVEL
	)
	if current_level < 0 or current_level >= maximum_level:
		return false
	var costs: Array[int] = (
		REEL_SPEED_COSTS if is_reel_speed else BARRIER_POWER_COSTS
	)
	var cost: int = costs[current_level]
	if cost < 0 or not wallet.can_afford(cost):
		return false
	if not wallet.debit(cost):
		return false
	if is_reel_speed:
		_reel_speed_level = current_level + 1
	else:
		_barrier_power_level = current_level + 1
	upgrades_changed.emit(
		_reel_speed_level,
		_barrier_power_level
	)
	return true
