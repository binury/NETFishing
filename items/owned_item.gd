class_name OwnedItem
extends Resource

@export var item_id: StringName
@export var quantity: int = 1


func is_valid() -> bool:
	return not item_id.is_empty() and quantity > 0


func duplicate_record():
	return duplicate(true)


func to_save_dict() -> Dictionary:
	return {
		"item_id": String(item_id),
		"quantity": quantity,
	}
