class_name PlayerWallet
extends Node

signal balance_changed(new_balance: int, delta: int)

@export var current_balance: int = 0


func _ready() -> void:
	current_balance = maxi(current_balance, 0)


func get_balance() -> int:
	return current_balance


func restore_balance(balance: int) -> bool:
	if balance < 0:
		return false
	var previous_balance: int = current_balance
	current_balance = balance
	balance_changed.emit(
		current_balance,
		current_balance - previous_balance
	)
	return true


func can_afford(amount: int) -> bool:
	return amount >= 0 and current_balance >= amount


func can_credit(amount: int) -> bool:
	return (
		amount >= 0
		and current_balance <= 9223372036854775807 - amount
	)


func credit(amount: int) -> bool:
	if not can_credit(amount):
		return false
	if amount == 0:
		return true
	current_balance += amount
	balance_changed.emit(current_balance, amount)
	return true


func debit(amount: int) -> bool:
	if not can_afford(amount):
		return false
	if amount == 0:
		return true
	current_balance -= amount
	balance_changed.emit(current_balance, -amount)
	return true
