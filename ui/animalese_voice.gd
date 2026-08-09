class_name AnimaleseVoice
extends Node

const SAMPLE_DIRECTORY := "res://sound/dialogue/animalese/placeholder"
const SUPPORTED_CHARACTERS := "abcdefghijklmnopqrstuvwxyz"
const DEFAULT_CHARACTERS_PER_SECOND: float = 28.0
const POLYPHONY: int = 8
const VoiceProfilesType = preload(
	"res://player/animalese_voice_profiles.gd"
)
const TypewriterRevealType = preload("res://ui/typewriter_reveal.gd")

var base_pitch: float = 1.0
var volume_db: float = -13.0

var _samples: Dictionary[String, AudioStream] = {}
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


func speak_text(
	owner: Node,
	text: String,
	voice_key: String,
	voice_profile_id: String = VoiceProfilesType.DEFAULT_ID,
	characters_per_second: float = -1.0,
) -> Tween:
	var speech_tween := owner.create_tween()
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
	for character_index: int in range(text.length()):
		speech_tween.tween_interval(character_seconds)
		speech_tween.tween_callback(
			_play_character.bind(
				text.substr(character_index, 1),
				character_index,
				text,
				voice_key,
				voice_pitch,
			)
		)
	return speech_tween


func _load_samples() -> void:
	for character_index: int in range(SUPPORTED_CHARACTERS.length()):
		var character := SUPPORTED_CHARACTERS.substr(character_index, 1)
		_load_sample(character)
	_load_sample("fallback")


func _load_sample(sample_name: String) -> void:
	var sample_path := "%s/%s.wav" % [SAMPLE_DIRECTORY, sample_name]
	var sample := load(sample_path) as AudioStream
	if sample != null:
		_samples[sample_name] = sample


func _play_character(
	character: String,
	character_index: int,
	full_text: String,
	voice_key: String,
	voice_pitch: float,
) -> void:
	if _playback == null or character.strip_edges().is_empty():
		return
	var normalized := character.to_lower()
	if normalized in [".", ",", "!", "?", ":", ";", "-", "_"]:
		return
	var sample_name := (
		normalized if SUPPORTED_CHARACTERS.contains(normalized) else "fallback"
	)
	var sample: AudioStream = _samples.get(sample_name)
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
	if full_text.ends_with("?") and character_index >= full_text.length() * 3 / 4:
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
