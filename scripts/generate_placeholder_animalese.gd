extends SceneTree

const OUTPUT_DIRECTORY := "res://sound/dialogue/animalese/placeholder"
const SAMPLE_RATE: int = 22050
const SAMPLE_SECONDS: float = 0.055
const CHARACTERS := "abcdefghijklmnopqrstuvwxyz"
const VOWELS := "aeiou"


func _initialize() -> void:
	var absolute_directory := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		absolute_directory
	)
	if directory_error != OK:
		push_error("Could not create animalese sample directory.")
		quit(1)
		return
	for character_index: int in range(CHARACTERS.length()):
		var character := CHARACTERS.substr(character_index, 1)
		_save_sample(character, character_index)
	_save_sample("fallback", CHARACTERS.length())
	quit()


func _save_sample(sample_name: String, sample_index: int) -> void:
	var stream := _build_sample(sample_name, sample_index)
	var output_path := "%s/%s" % [OUTPUT_DIRECTORY, sample_name]
	var save_error: Error = stream.save_to_wav(output_path)
	if save_error != OK:
		push_error("Could not save animalese sample: %s" % sample_name)


func _build_sample(sample_name: String, sample_index: int) -> AudioStreamWAV:
	var frame_count := roundi(SAMPLE_RATE * SAMPLE_SECONDS)
	var pcm := PackedByteArray()
	pcm.resize(frame_count * 2)
	var base_frequency := 245.0 + float(sample_index % 7) * 18.0
	var formant_one := 620.0 + float(sample_index % 5) * 85.0
	var formant_two := 1320.0 + float(sample_index % 6) * 115.0
	var is_vowel := VOWELS.contains(sample_name)
	var noise_seed := sample_index * 7919 + 104729
	for frame_index: int in range(frame_count):
		var time := float(frame_index) / SAMPLE_RATE
		var attack := minf(time / 0.004, 1.0)
		var release := minf((SAMPLE_SECONDS - time) / 0.014, 1.0)
		var envelope := maxf(minf(attack, release), 0.0)
		noise_seed = int(
			(noise_seed * 1103515245 + 12345) & 0x7fffffff
		)
		var noise := float(noise_seed % 65536) / 32767.5 - 1.0
		var voiced := (
			sin(TAU * base_frequency * time) * 0.42
			+ sin(TAU * base_frequency * 2.0 * time) * 0.16
		)
		var formants := (
			sin(TAU * formant_one * time) * 0.18
			+ sin(TAU * formant_two * time) * 0.10
		)
		var consonant_noise := noise * (0.08 if is_vowel else 0.24)
		var value := envelope * (voiced + formants + consonant_noise) * 0.72
		var signed_sample := clampi(roundi(value * 32767.0), -32768, 32767)
		var encoded_sample := signed_sample if signed_sample >= 0 else signed_sample + 65536
		pcm[frame_index * 2] = encoded_sample & 0xff
		pcm[frame_index * 2 + 1] = (encoded_sample >> 8) & 0xff
	var stream := AudioStreamWAV.new()
	stream.set("format", AudioStreamWAV.FORMAT_16_BITS)
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = pcm
	return stream
