extends SceneTree


func _initialize() -> void:
	var idle := NetworkPlayerAnimationProtocol.make_state(
		NetworkPlayerAnimationProtocol.LOCOMOTION_IDLE,
		true,
	)
	assert(NetworkPlayerAnimationProtocol.validate_state(idle))
	var emote := NetworkPlayerAnimationProtocol.make_state(
		NetworkPlayerAnimationProtocol.LOCOMOTION_RUNNING,
		false,
		&"wave_hello",
		17,
		1.25,
	)
	assert(NetworkPlayerAnimationProtocol.validate_state(emote))
	var future_locomotion := NetworkPlayerAnimationProtocol.make_state(
		&"swimming_fast",
		false,
	)
	assert(NetworkPlayerAnimationProtocol.validate_state(future_locomotion))
	var extra_future_field: Dictionary = emote.duplicate(true)
	extra_future_field["future_layer"] = {"id": "umbrella"}
	assert(NetworkPlayerAnimationProtocol.validate_state(extra_future_field))

	var invalid_action: Dictionary = emote.duplicate(true)
	invalid_action["action"] = {
		"id": "../unsafe",
		"sequence": 17,
		"elapsed": 1.25,
	}
	assert(not NetworkPlayerAnimationProtocol.validate_state(invalid_action))
	var invalid_sequence: Dictionary = emote.duplicate(true)
	invalid_sequence["action"] = {
		"id": "wave_hello",
		"sequence": -1,
		"elapsed": 1.25,
	}
	assert(not NetworkPlayerAnimationProtocol.validate_state(invalid_sequence))
	var invalid_elapsed: Dictionary = emote.duplicate(true)
	invalid_elapsed["action"] = {
		"id": "wave_hello",
		"sequence": 17,
		"elapsed": INF,
	}
	assert(not NetworkPlayerAnimationProtocol.validate_state(invalid_elapsed))
	print("Network player animation protocol validation: PASS")
	quit()
