extends SceneTree

const EDGE_PADDING: String = " \t\n ​⠀"


func _initialize() -> void:
	call_deferred("_validate_protocol")


func _validate_protocol() -> void:
	_validate_type_and_empty_handling()
	_validate_message_cleanup()
	_validate_protocol_limits()
	print("Network chat protocol validation: PASS")
	quit()


func _validate_type_and_empty_handling() -> void:
	assert(NetworkChatProtocol.sanitize_body(null) == "")
	assert(NetworkChatProtocol.sanitize_body(42) == "")
	assert(NetworkChatProtocol.sanitize_body(EDGE_PADDING) == "")
	assert(NetworkChatProtocol.sanitize_body("\u0001") == "")


func _validate_message_cleanup() -> void:
	assert(NetworkChatProtocol.sanitize_body("  hello  ") == "hello")
	assert(NetworkChatProtocol.sanitize_body("a\tb\nc") == "a b c")
	assert(NetworkChatProtocol.sanitize_body("word word") == "word word")
	assert(NetworkChatProtocol.sanitize_body(" !!! ") == "!!!")
	assert(
		NetworkChatProtocol.sanitize_body(
			EDGE_PADDING + "visible" + EDGE_PADDING
		) == "visible"
	)


func _validate_protocol_limits() -> void:
	var maximum_body: String = "a".repeat(
		NetworkChatProtocol.MAX_VISIBLE_CHARACTERS
	)
	assert(NetworkChatProtocol.sanitize_body(maximum_body) == maximum_body)
	assert(
		NetworkChatProtocol.sanitize_body(maximum_body + "a") == ""
	)
	var maximum_utf8_body: String = "🐟".repeat(
		NetworkChatProtocol.MAX_VISIBLE_CHARACTERS
	)
	assert(
		maximum_utf8_body.to_utf8_buffer().size()
		== NetworkChatProtocol.MAX_UTF8_BYTES
	)
	assert(
		NetworkChatProtocol.sanitize_body(maximum_utf8_body)
		== maximum_utf8_body
	)
