class_name FishAvailability
extends Resource

const FishingContextType = preload("res://fishing/fishing_context.gd")

@export var allowed_location_tags: Array[StringName] = []
@export var required_event_tags: Array[StringName] = []
@export var forbidden_event_tags: Array[StringName] = []
@export var allow_day: bool = true
@export var allow_night: bool = true
@export var require_rain: bool = false
@export var forbid_rain: bool = false
@export var require_fog: bool = false
@export var forbid_fog: bool = false
@export var required_bait_tags: Array[StringName] = []
@export var preferred_bait_tags: Array[StringName] = []
@export_range(0.01, 10.0, 0.01) var preferred_bait_weight_multiplier: float = 1.25


func is_available(context: FishingContextType) -> bool:
	if (
		context == null
		or (require_rain and forbid_rain)
		or (require_fog and forbid_fog)
	):
		return false
	if context.is_day_night_transition:
		if not allow_day and not allow_night:
			return false
	elif context.is_night and not allow_night:
		return false
	elif not context.is_night and not allow_day:
		return false
	if require_rain and not context.is_raining:
		return false
	if forbid_rain and context.is_raining:
		return false
	if require_fog and not context.is_foggy:
		return false
	if forbid_fog and context.is_foggy:
		return false
	if (
		not allowed_location_tags.is_empty()
		and not _has_any_match(allowed_location_tags, context.location_tags)
	):
		return false
	for required_tag: StringName in required_event_tags:
		if required_tag not in context.active_event_tags:
			return false
	for forbidden_tag: StringName in forbidden_event_tags:
		if forbidden_tag in context.active_event_tags:
			return false
	if (
		not required_bait_tags.is_empty()
		and not _has_any_match(required_bait_tags, context.active_bait_tags)
	):
		return false
	return true


func get_bait_weight_multiplier(context: FishingContextType) -> float:
	if context == null:
		return 1.0
	if _has_any_match(preferred_bait_tags, context.active_bait_tags):
		return maxf(preferred_bait_weight_multiplier, 0.01)
	return 1.0


func _has_any_match(
	required_tags: Array[StringName],
	active_tags: Array[StringName],
) -> bool:
	for tag: StringName in required_tags:
		if tag in active_tags:
			return true
	return false
