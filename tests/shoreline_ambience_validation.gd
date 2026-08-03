extends SceneTree

const ShorelineAmbienceType := preload("res://world/shoreline_ambience.gd")
const WavesStream := preload("res://audio/ambience/waves.wav")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var waves := WavesStream as AudioStreamWAV
	assert(waves != null)

	var segments: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2.ZERO, Vector2(10.0, 0.0)]),
	]
	assert(is_equal_approx(
		ShorelineAmbienceType.distance_to_segments(Vector2(5.0, 3.0), segments),
		3.0,
	))
	assert(is_equal_approx(
		ShorelineAmbienceType.distance_to_segments(Vector2(-4.0, 0.0), segments),
		4.0,
	))

	var controller := ShorelineAmbienceType.new() as ShorelineAmbience
	var runtime_audio := AudioStreamPlayer.new()
	runtime_audio.name = "WavesAudio"
	runtime_audio.unique_name_in_owner = true
	runtime_audio.stream = WavesStream
	runtime_audio.bus = &"SFX"
	controller.add_child(runtime_audio)
	runtime_audio.owner = controller
	root.add_child(controller)
	await process_frame
	assert(runtime_audio.bus == &"SFX")
	assert(controller.near_distance < controller.far_distance)
	assert(controller.near_volume_db > controller.far_volume_db)
	var runtime_waves := runtime_audio.stream as AudioStreamWAV
	assert(runtime_waves.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(runtime_waves.loop_begin == 0)
	assert(runtime_waves.loop_end == 1044956)
	controller.free()
	await process_frame

	print("Shoreline ambience validation: PASS")
	quit()
