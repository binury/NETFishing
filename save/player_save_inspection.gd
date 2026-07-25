class_name PlayerSaveInspection
extends RefCounted

enum Status {
	MISSING,
	VALID_SUPPORTED,
	MALFORMED,
	UNSUPPORTED_VERSION,
	IO_ERROR,
}

var status: Status = Status.MISSING
var detected_version: int = -1
var catch_count: int = 0
var wallet_balance: int = 0
var discovered_species_count: int = 0
var has_primary_file: bool = false
var message: String = ""


func can_continue() -> bool:
	return status == Status.VALID_SUPPORTED


func can_delete() -> bool:
	return has_primary_file
