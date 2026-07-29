class_name ConnectionEndpoint
extends RefCounted

var host: String = ""
var port: int = 7777
var normalized_display: String = ""
var original_display: String = ""
var error_message: String = ""


func is_valid() -> bool:
	return error_message.is_empty() and not host.is_empty() and port in range(1, 65536)
