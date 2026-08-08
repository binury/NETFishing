class_name TypewriterReveal
extends RefCounted

const DEFAULT_CHARACTERS_PER_SECOND: float = 28.0
const MIN_CHARACTERS_PER_SECOND: float = 12.0
const MAX_CHARACTERS_PER_SECOND: float = 60.0

static var _characters_per_second: float = DEFAULT_CHARACTERS_PER_SECOND


static func set_characters_per_second(value: float) -> void:
	_characters_per_second = clampf(
		value,
		MIN_CHARACTERS_PER_SECOND,
		MAX_CHARACTERS_PER_SECOND,
	)


static func get_characters_per_second() -> float:
	return _characters_per_second


static func start(
	label: Label,
	characters_per_second: float = -1.0,
) -> float:
	if label == null:
		return 0.0
	var character_count: int = label.get_total_character_count()
	if character_count <= 0:
		label.visible_characters = -1
		return 0.0
	label.visible_characters = 0
	var resolved_characters_per_second := (
		characters_per_second
		if characters_per_second > 0.0
		else _characters_per_second
	)
	var duration := float(character_count) / resolved_characters_per_second
	var reveal_tween := label.create_tween()
	reveal_tween.tween_property(
		label,
		"visible_characters",
		character_count,
		duration,
	).from(0).set_trans(Tween.TRANS_LINEAR)
	return duration
