class_name AnimaleseVoice
extends Node

signal character_sample_played(sample_set_id: String, character: String)

const SUPPORTED_CHARACTERS := "abcdefghijklmnopqrstuvwxyz0123456789"
const DEFAULT_CHARACTERS_PER_SECOND: float = 28.0
const POLYPHONY: int = 8
const VoiceProfilesType = preload(
	"res://player/animalese_voice_profiles.gd"
)
const TypewriterRevealType = preload("res://ui/typewriter_reveal.gd")

var base_pitch: float = 1.0
var volume_db: float = -13.0

var _sample_sets: Dictionary[String, Dictionary] = {}
var _player: AudioStreamPlayer
var _playback: AudioStreamPlaybackPolyphonic


func _ready() -> void:
	_load_samples()
	var polyphonic_stream := AudioStreamPolyphonic.new()
	polyphonic_stream.polyphony = POLYPHONY
	_player = AudioStreamPlayer.new()
	_player.name = "AnimaleseAudio"
	_player.bus = &"SFX"
	_player.stream = polyphonic_stream
	add_child(_player)
	_player.play()
	_playback = (
		_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	)


func _exit_tree() -> void:
	if _player != null:
		_player.stop()
		_player.stream = null
	_playback = null


func speak_text(
	tween_owner: Node,
	text: String,
	voice_key: String,
	voice_profile_id: String = VoiceProfilesType.DEFAULT_ID,
	characters_per_second: float = -1.0,
	sample_set_id: String = VoiceProfilesType.DEFAULT_SAMPLE_SET_ID,
) -> Tween:
	var speech_tween := tween_owner.create_tween()
	var resolved_characters_per_second := (
		characters_per_second
		if characters_per_second > 0.0
		else TypewriterRevealType.get_characters_per_second()
	)
	var character_seconds := 1.0 / maxf(
		resolved_characters_per_second,
		1.0,
	)
	var voice_pitch := (
		base_pitch * VoiceProfilesType.pitch_for(voice_profile_id)
	)
	var resolved_sample_set_id := (
		VoiceProfilesType.sanitized_sample_set_id(sample_set_id)
	)
	for character_index: int in range(text.length()):
		speech_tween.tween_interval(character_seconds)
		speech_tween.tween_callback(
			_play_character.bind(
				text.substr(character_index, 1),
				character_index,
				text,
				voice_key,
				voice_pitch,
				resolved_sample_set_id,
			)
		)
	return speech_tween


func _load_samples() -> void:
	for option: Dictionary in VoiceProfilesType.SAMPLE_SET_OPTIONS:
		var sample_set_id := str(option.get("id", ""))
		var sample_directory := str(option.get("directory", ""))
		var samples: Dictionary[String, AudioStream] = {}
		for character_index: int in range(SUPPORTED_CHARACTERS.length()):
			var character := SUPPORTED_CHARACTERS.substr(character_index, 1)
			var sample := _load_sample(sample_directory, character)
			if sample != null:
				samples[character] = sample
		var fallback := _load_sample(sample_directory, "fallback")
		if fallback != null:
			samples["fallback"] = fallback
		_sample_sets[sample_set_id] = samples


func _load_sample(sample_directory: String, sample_name: String) -> AudioStream:
	var sample_path := "%s/%s.wav" % [sample_directory, sample_name]
	if not ResourceLoader.exists(sample_path, "AudioStreamWAV"):
		return null
	return load(sample_path) as AudioStream


func _play_character(
	character: String,
	character_index: int,
	full_text: String,
	voice_key: String,
	voice_pitch: float,
	sample_set_id: String,
) -> void:
	if _playback == null or character.strip_edges().is_empty():
		return
	var normalized := character.to_lower()
	if normalized in [".", ",", "!", "?", ":", ";", "-", "_"]:
		return
	var samples: Dictionary = _sample_sets.get(sample_set_id, {})
	var sample := samples.get(normalized) as AudioStream
	if sample == null:
		sample = samples.get("fallback") as AudioStream
	if sample == null:
		return
	var speaker_variation := (
		float(posmod(hash(voice_key), 1001)) / 1000.0 - 0.5
	) * 0.16
	var character_variation := (
		float(posmod(hash("%s:%d" % [voice_key, character_index]), 1001))
		/ 1000.0
		- 0.5
	) * 0.10
	var question_lift := 0.0
	var question_lift_start: int = floori(float(full_text.length()) * 0.75)
	if full_text.ends_with("?") and character_index >= question_lift_start:
		var final_progress := (
			float(character_index) / maxf(float(full_text.length() - 1), 1.0)
		)
		question_lift = lerpf(0.0, 0.14, final_progress)
	var pitch := clampf(
		voice_pitch
		+ speaker_variation
		+ character_variation
		+ question_lift,
		0.72,
		1.45,
	)
	_playback.play_stream(sample, 0.0, volume_db, pitch)
	character_sample_played.emit(sample_set_id, normalized)
