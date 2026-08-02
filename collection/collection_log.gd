class_name CollectionLog
extends Node

signal fish_discovered(fish_id: StringName)
signal fish_quality_discovered(fish_id: StringName, quality: int)
signal collection_changed

const FishQualityType = preload("res://fish/fish_quality.gd")

var _discovered: Dictionary[StringName, bool] = {}
var _quality_masks: Dictionary[StringName, int] = {}


func has_discovered(fish_id: StringName) -> bool:
	return not fish_id.is_empty() and _discovered.has(fish_id)


func mark_discovered(fish_id: StringName) -> void:
	if fish_id.is_empty() or has_discovered(fish_id):
		return
	_discovered[fish_id] = true
	fish_discovered.emit(fish_id)
	collection_changed.emit()


func mark_quality_discovered(fish_id: StringName, quality: int) -> void:
	if fish_id.is_empty() or not FishQualityType.is_valid(quality):
		return
	var species_was_discovered: bool = has_discovered(fish_id)
	if not species_was_discovered:
		_discovered[fish_id] = true
	var previous_mask: int = _quality_masks.get(fish_id, 0)
	var next_mask: int = previous_mask | FishQualityType.bit_for(quality)
	if species_was_discovered and next_mask == previous_mask:
		return
	_quality_masks[fish_id] = next_mask
	if not species_was_discovered:
		fish_discovered.emit(fish_id)
	if next_mask != previous_mask:
		fish_quality_discovered.emit(fish_id, quality)
	collection_changed.emit()


func get_discovered_ids() -> Array[StringName]:
	var discovered_ids: Array[StringName] = []
	for fish_id: StringName in _discovered:
		discovered_ids.append(fish_id)
	discovered_ids.sort()
	return discovered_ids


func has_discovered_quality(fish_id: StringName, quality: int) -> bool:
	return (
		not fish_id.is_empty()
		and FishQualityType.is_valid(quality)
		and (_quality_masks.get(fish_id, 0) & FishQualityType.bit_for(quality)) != 0
	)


func get_quality_mask(fish_id: StringName) -> int:
	return _quality_masks.get(fish_id, 0) if has_discovered(fish_id) else 0


func get_discovered_quality_masks() -> Dictionary[StringName, int]:
	return _quality_masks.duplicate()


func has_mastered(fish_id: StringName) -> bool:
	return get_quality_mask(fish_id) == FishQualityType.ALL_TIERS_MASK


func replace_discovered_ids(fish_ids: Array[StringName]) -> bool:
	var empty_masks: Dictionary[StringName, int] = {}
	return replace_discovery_state(fish_ids, empty_masks)


func replace_discovery_state(
	fish_ids: Array[StringName],
	quality_masks: Dictionary[StringName, int],
) -> bool:
	var replacement: Dictionary[StringName, bool] = {}
	for fish_id: StringName in fish_ids:
		if fish_id.is_empty():
			return false
		replacement[fish_id] = true
	var replacement_masks: Dictionary[StringName, int] = {}
	for fish_id: StringName in quality_masks:
		var mask: int = quality_masks[fish_id]
		if (
			fish_id.is_empty()
			or not replacement.has(fish_id)
			or mask < 0
			or (mask & ~FishQualityType.ALL_TIERS_MASK) != 0
		):
			return false
		if mask != 0:
			replacement_masks[fish_id] = mask
	_discovered = replacement
	_quality_masks = replacement_masks
	collection_changed.emit()
	return true
