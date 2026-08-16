class_name OwnedItem
extends Resource

const MAX_STORAGE_SLOT_INDEX: int = 254

@export var item_id: StringName
@export var quantity: int = 1
@export var storage_slot: int = -1


func is_valid() -> bool:
	return (
		not item_id.is_empty()
		and quantity > 0
		and storage_slot >= -1
		and storage_slot <= MAX_STORAGE_SLOT_INDEX
	)


func duplicate_record():
	return duplicate(true)


func to_save_dict() -> Dictionary:
	return {
		"item_id": String(item_id),
		"quantity": quantity,
		"storage_slot": storage_slot,
	}
