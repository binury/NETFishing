class_name FishSaleResult
extends RefCounted

enum Status {
	SUCCESS,
	NOT_FOUND,
	FAVORITED,
	INVALID_VALUE,
	INVALID_BUYER,
	INVALID_OFFER,
	INVALID_SELECTION,
	RESERVED,
	TRANSACTION_FAILED,
}

var success: bool = false
var status: Status = Status.TRANSACTION_FAILED
var catch_id: StringName
var catch_ids: Array[StringName] = []
var fish_count: int = 0
var fish_name: String = ""
var buyer_id: StringName
var buyer_display_name: String = ""
var buyer_animal_name: String = ""
var base_value: int = 0
var payout: int = 0
var sale_message: String = ""


func is_success() -> bool:
	return success and status == Status.SUCCESS


func get_message() -> String:
	match status:
		Status.SUCCESS:
			return sale_message
		Status.NOT_FOUND:
			return "fish no longer exists."
		Status.FAVORITED:
			return "favorited fish cannot be sold."
		Status.INVALID_VALUE:
			return "invalid sale value."
		Status.INVALID_BUYER:
			return "buyer is unavailable."
		Status.INVALID_OFFER:
			return "invalid buyer offer."
		Status.INVALID_SELECTION:
			return "the fish selection is invalid."
		Status.RESERVED:
			return "reserved fish cannot be sold."
		_:
			return "transaction failed."
