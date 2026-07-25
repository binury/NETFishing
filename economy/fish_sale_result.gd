class_name FishSaleResult
extends RefCounted

enum Status {
	SUCCESS,
	NOT_FOUND,
	FAVORITED,
	INVALID_VALUE,
	INVALID_BUYER,
	INVALID_OFFER,
	TRANSACTION_FAILED,
}

var success: bool = false
var status: Status = Status.TRANSACTION_FAILED
var catch_id: StringName
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
			return "Fish no longer exists."
		Status.FAVORITED:
			return "Favorited fish cannot be sold."
		Status.INVALID_VALUE:
			return "Invalid sale value."
		Status.INVALID_BUYER:
			return "Buyer is unavailable."
		Status.INVALID_OFFER:
			return "Invalid buyer offer."
		_:
			return "Transaction failed."
