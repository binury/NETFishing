extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(NetworkChatProtocol.sanitize_body(42).is_empty())
	assert(NetworkChatProtocol.sanitize_body("   a   ") == "a")
	assert(NetworkChatProtocol.sanitize_body("a b") == "a b")
	assert(NetworkChatProtocol.sanitize_body("a\tb\nc") == "a b c")
	assert(NetworkChatProtocol.sanitize_body(" !hello!? ") == "!hello!?")
	assert(NetworkChatProtocol.sanitize_body("!!!") == "!!!")

	const em_space := " " # U+2003 EM SPACE
	const zero_width_space := "​" # U+200B ZERO WIDTH SPACE
	const braille_blank := "⠀" # U+2800 BRAILLE PATTERN BLANK
	const invisible_padding := em_space + zero_width_space + braille_blank
	assert(
		NetworkChatProtocol.sanitize_body(invisible_padding + "a" + invisible_padding)
		== "a"
	)
	assert(NetworkChatProtocol.sanitize_body(invisible_padding).is_empty())
	assert(NetworkChatProtocol.sanitize_body(" \t\n" + invisible_padding).is_empty())

	assert(
		NetworkChatProtocol.sanitize_body("a".repeat(
			NetworkChatProtocol.MAX_VISIBLE_CHARACTERS
		)).length() == NetworkChatProtocol.MAX_VISIBLE_CHARACTERS
	)
	assert(
		NetworkChatProtocol.sanitize_body("a".repeat(
			NetworkChatProtocol.MAX_VISIBLE_CHARACTERS + 1
		)).is_empty()
	)

	print("Chat validation: PASS")
	quit(0)
