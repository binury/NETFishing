extends SceneTree

const AnimaleseVoiceType = preload("res://ui/animalese_voice.gd")
const VoiceProfilesType = preload(
	"res://player/animalese_voice_profiles.gd"
)
const EXPECTED_CHARACTERS := "abcdefghijklmnopqrstuvwxyz0123456789"
const ROBOT_CHARACTERS := "abcdefghijklmnopqrstuvwxyz"

var _failures: Array[String] = []


func _initialize() -> void:
	_expect(
		AnimaleseVoiceType.SUPPORTED_CHARACTERS == EXPECTED_CHARACTERS,
		"animalese supports every letter and digit",
	)
	_expect(
		VoiceProfilesType.DEFAULT_SAMPLE_SET_ID == "robot",
		"robot is the default animalese voice set",
	)
	_expect(
		VoiceProfilesType.is_valid_sample_set("robot"),
		"the original tones remain available as robot",
	)
	_validate_set("robot", ROBOT_CHARACTERS, true)
	if _failures.is_empty():
		print("Animalese sample validation: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _validate_set(
	sample_set_id: String,
	characters: String,
	expects_fallback: bool,
) -> void:
	var sample_directory := VoiceProfilesType.sample_directory_for(
		sample_set_id
	)
	_expect(
		not sample_directory.is_empty(),
		"%s has a sample directory" % sample_set_id,
	)
	for character_index: int in range(characters.length()):
		var character := characters.substr(character_index, 1)
		var sample_path := "%s/%s.wav" % [sample_directory, character]
		_expect(
			ResourceLoader.exists(sample_path, "AudioStreamWAV"),
			"%s sample loads for %s" % [sample_set_id, character],
		)
	if expects_fallback:
		_expect(
			ResourceLoader.exists(
				"%s/fallback.wav" % sample_directory,
				"AudioStreamWAV",
			),
			"%s supplies a fallback for digits and symbols" % sample_set_id,
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
