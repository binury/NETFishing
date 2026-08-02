class_name PlayerExperience
extends Node

signal experience_changed(total_experience: int, level: int)
signal experience_awarded(
	amount: int,
	previous_total: int,
	new_total: int,
	previous_level: int,
	new_level: int,
)

const MAX_TOTAL_EXPERIENCE: int = 1000000000000
const MAX_LEVEL: int = 100000

var _total_experience: int = 0


func get_total_experience() -> int:
	return _total_experience


func get_level() -> int:
	return level_for_total_experience(_total_experience)


func get_experience_in_level() -> int:
	return _total_experience - total_experience_for_level(get_level())


func get_experience_for_next_level() -> int:
	return experience_required_for_next_level(get_level())


func get_level_progress() -> float:
	return progress_for_total_experience(_total_experience)


func award_experience(amount: int) -> bool:
	if amount <= 0 or _total_experience >= MAX_TOTAL_EXPERIENCE:
		return false
	var previous_total: int = _total_experience
	var previous_level: int = level_for_total_experience(previous_total)
	_total_experience = mini(
		_total_experience + amount,
		MAX_TOTAL_EXPERIENCE,
	)
	var awarded_amount: int = _total_experience - previous_total
	if awarded_amount <= 0:
		return false
	var new_level: int = level_for_total_experience(_total_experience)
	experience_changed.emit(_total_experience, new_level)
	experience_awarded.emit(
		awarded_amount,
		previous_total,
		_total_experience,
		previous_level,
		new_level,
	)
	return true


func restore_total_experience(total_experience: int) -> bool:
	if total_experience < 0 or total_experience > MAX_TOTAL_EXPERIENCE:
		return false
	var changed: bool = _total_experience != total_experience
	_total_experience = total_experience
	if changed:
		experience_changed.emit(_total_experience, get_level())
	return true


func reset_to_defaults() -> void:
	restore_total_experience(0)


func to_save_data() -> Dictionary:
	return {"total_experience": _total_experience}


static func experience_required_for_next_level(level: int) -> int:
	var safe_level: int = maxi(level, 1)
	var level_index: int = safe_level - 1
	return 100 + level_index * 25 + level_index * level_index * 5


static func total_experience_for_level(level: int) -> int:
	var completed_levels: int = clampi(level - 1, 0, MAX_LEVEL - 1)
	if completed_levels == 0:
		return 0
	var linear_sum: int = floori(
		float(completed_levels) * float(completed_levels - 1) / 2.0
	)
	var square_sum: int = floori(
		float(completed_levels - 1)
		* float(completed_levels)
		* float(2 * completed_levels - 1)
		/ 6.0
	)
	return completed_levels * 100 + linear_sum * 25 + square_sum * 5


static func level_for_total_experience(total_experience: int) -> int:
	var safe_total: int = clampi(
		total_experience,
		0,
		MAX_TOTAL_EXPERIENCE,
	)
	var low: int = 1
	var high: int = MAX_LEVEL
	while low < high:
		var middle: int = low + floori(float(high - low + 1) / 2.0)
		if total_experience_for_level(middle) <= safe_total:
			low = middle
		else:
			high = middle - 1
	return low


static func progress_for_total_experience(total_experience: int) -> float:
	var level: int = level_for_total_experience(total_experience)
	var level_start: int = total_experience_for_level(level)
	var required: int = experience_required_for_next_level(level)
	if required <= 0:
		return 0.0
	return clampf(
		float(total_experience - level_start) / float(required),
		0.0,
		1.0,
	)
