extends SceneTree

const FishingSpotScene := preload("res://fishing/fishing_spot.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var fishing_spot := FishingSpotScene.instantiate() as FishingSpot
	root.add_child(fishing_spot)
	await process_frame

	var fight_audio := fishing_spot.get_node("%FightAudio") as AudioStreamPlayer
	var bobber_audio := fishing_spot.get_node(
		"%BobberAudio"
	) as AudioStreamPlayer
	assert(bobber_audio != null)
	assert(bobber_audio.stream != null)
	assert(bobber_audio.bus == &"SFX")
	assert(is_equal_approx(bobber_audio.volume_db, -14.0))
	var bobber_stream := bobber_audio.stream as AudioStreamWAV
	assert(bobber_stream != null)
	assert(bobber_stream.loop_mode == AudioStreamWAV.LOOP_DISABLED)
	assert(fight_audio != null)
	assert(fight_audio.stream != null)
	assert(fight_audio.bus == &"SFX")
	assert(is_equal_approx(fight_audio.volume_db, -10.0))
	var fight_stream := fight_audio.stream as AudioStreamWAV
	assert(fight_stream != null)
	assert(fight_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(fight_stream.loop_end > fight_stream.loop_begin)
	var reeling_audio := fishing_spot.get_node(
		"%ReelingAudio"
	) as AudioStreamPlayer
	assert(reeling_audio != null)
	assert(reeling_audio.stream != null)
	assert(reeling_audio.bus == &"SFX")
	assert(is_equal_approx(reeling_audio.volume_db, -10.0))
	var reeling_stream := reeling_audio.stream as AudioStreamWAV
	assert(reeling_stream != null)
	assert(reeling_stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	assert(reeling_stream.loop_end > reeling_stream.loop_begin)

	assert(fishing_spot.has_method("_start_fight_audio"))
	assert(fishing_spot.has_method("_play_bobber_audio"))
	assert(fishing_spot.has_method("_stop_fight_audio"))
	assert(fishing_spot.has_method("_start_reeling_audio"))
	assert(fishing_spot.has_method("_stop_reeling_audio"))
	fishing_spot.free()
	await process_frame
	print("Fishing audio validation: PASS")
	quit()
