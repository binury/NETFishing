extends SceneTree

const MainScene: PackedScene = preload("res://main/main.tscn")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	## Regular whitespace should be stripped
	assert(NetworkChatProtocol.sanitize_body("   a") == "a", "Leading space not trimmed")
	assert(NetworkChatProtocol.sanitize_body("b   ") == "b", "Trailing space not trimmed")
	assert(NetworkChatProtocol.sanitize_body("a b") == "a b", "Innocent whitespace culled")

	## Some examples of Unicode whitespace that should be stripped
	const em_space := " " # U+2003 EM SPACE
	assert(NetworkChatProtocol.sanitize_body(em_space + "a") == "a")
	const braille_space := "⠀" # U+2800 BRAILLE PATTERN BLANK
	assert(NetworkChatProtocol.sanitize_body(braille_space + "a") == "a")

	print("Chat validation: PASS")
	quit(0)
