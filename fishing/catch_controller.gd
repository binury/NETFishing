class_name CatchController
extends Node

const CatchDifficultyProfileType = preload(
	"res://fishing/catch_difficulty_profile.gd"
)
const FishQualityType = preload("res://fish/fish_quality.gd")

signal encounter_updated(
	progress: float,
	chase_progress: float,
	barrier_positions: PackedFloat32Array,
	barrier_health: PackedInt32Array,
	barrier_max_health: PackedInt32Array,
	active_barrier_index: int,
	visible: bool,
)
signal caught
signal escaped

enum CatchState {
	IDLE,
	REELING,
	BLOCKED_BY_BARRIER,
	CAUGHT,
	ESCAPED,
}

class Barrier:
	extends RefCounted

	var position: float
	var health: int
	var maximum_health: int
	var defeated: bool = false

	func _init(
		barrier_position: float,
		barrier_health: int,
	) -> void:
		position = barrier_position
		health = barrier_health
		maximum_health = barrier_health


# Fight movement uses one shared baseline. Species and quality difficulty comes
# from barrier placement and health, while reel upgrades affect only the
# player's progress speed.
const CHASE_START_DELAY: float = 1.0
const CHASE_START_OFFSET: float = 0.04
const CHASE_SPEED: float = 0.07

@export_category("Accessibility")
@export var auto_click_enabled: bool = false
@export_range(0.05, 2.0, 0.01) var auto_click_interval: float = 0.20

@export_category("Testing")
@export var use_deterministic_test_seed: bool = false
@export var deterministic_test_seed: int = 12345

var state: CatchState = CatchState.IDLE
var progress: float = 0.0
var chase_progress: float = 0.0
var encounter_seed: int = 0

var _barriers: Array[Barrier] = []
var _active_barrier_index: int = -1
var _reel_input_held: bool = false
var _reel_speed: float = 0.0
var _click_power: int = 1
var _fish_quality: int = FishQualityType.Tier.BORING
var _fish_rarity: int = 0
var _fish_weight_percentile: float = 0.0
var _chase_delay_remaining: float = 0.0
var _failure_epsilon: float = 0.0001
var _auto_click_accumulator: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func configure_accessibility(
	enabled: bool,
	interval: float,
) -> void:
	auto_click_enabled = enabled
	auto_click_interval = clampf(interval, 0.10, 0.50)
	_auto_click_accumulator = 0.0


func _process(delta: float) -> void:
	match state:
		CatchState.REELING:
			_update_free_reeling(delta)
		CatchState.BLOCKED_BY_BARRIER:
			_update_auto_click(delta)
		_:
			return

	if state in [CatchState.CAUGHT, CatchState.ESCAPED, CatchState.IDLE]:
		return
	if progress >= 1.0:
		_resolve_catch()
		return

	_update_chase(delta)
	if _is_chase_failure():
		_resolve_escape()
		return
	_emit_encounter_update()


func start_encounter(
	profile: CatchDifficultyProfileType,
	reel_speed: float,
	click_power: int,
	fish_quality: int = FishQualityType.Tier.BORING,
	fish_rarity: int = 0,
	fish_weight_percentile: float = 0.0,
) -> void:
	reset()
	if profile == null:
		_resolve_escape()
		return

	_reel_speed = maxf(reel_speed, 0.0)
	_click_power = maxi(click_power, 1)
	_fish_quality = (
		fish_quality
		if FishQualityType.is_valid(fish_quality)
		else FishQualityType.Tier.BORING
	)
	_fish_rarity = clampi(fish_rarity, 0, 4)
	_fish_weight_percentile = clampf(fish_weight_percentile, 0.0, 1.0)
	_chase_delay_remaining = CHASE_START_DELAY
	chase_progress = -CHASE_START_OFFSET
	_seed_encounter_rng()
	_generate_barriers(profile)
	progress = 0.0
	state = CatchState.REELING
	_emit_encounter_update()


func start_authoritative_encounter(
	profile: CatchDifficultyProfileType,
	reel_speed: float,
	click_power: int,
	encounter_seed_value: int,
	fish_quality: int = FishQualityType.Tier.BORING,
	fish_rarity: int = 0,
	fish_weight_percentile: float = 0.0,
) -> void:
	var previous_test_mode: bool = use_deterministic_test_seed
	var previous_seed: int = deterministic_test_seed
	use_deterministic_test_seed = true
	deterministic_test_seed = encounter_seed_value
	start_encounter(
		profile,
		reel_speed,
		click_power,
		fish_quality,
		fish_rarity,
		fish_weight_percentile,
	)
	use_deterministic_test_seed = previous_test_mode
	deterministic_test_seed = previous_seed


func set_reel_input(held: bool) -> void:
	_reel_input_held = held
	if not held:
		_auto_click_accumulator = 0.0


func set_effective_stats(reel_speed: float, click_power: int) -> void:
	if state == CatchState.IDLE:
		return
	_reel_speed = maxf(reel_speed, 0.0)
	_click_power = maxi(click_power, 1)


func handle_primary_pressed() -> void:
	if state not in [CatchState.REELING, CatchState.BLOCKED_BY_BARRIER]:
		return
	_reel_input_held = true
	if state == CatchState.BLOCKED_BY_BARRIER and not auto_click_enabled:
		_damage_active_barrier()


func reset() -> void:
	state = CatchState.IDLE
	progress = 0.0
	chase_progress = 0.0
	encounter_seed = 0
	_barriers.clear()
	_active_barrier_index = -1
	_reel_input_held = false
	_reel_speed = 0.0
	_click_power = 1
	_fish_quality = FishQualityType.Tier.BORING
	_chase_delay_remaining = 0.0
	_auto_click_accumulator = 0.0
	emit_signal(
		"encounter_updated",
		0.0,
		0.0,
		PackedFloat32Array(),
		PackedInt32Array(),
		PackedInt32Array(),
		-1,
		false
	)


func get_barrier_count() -> int:
	return _barriers.size()


func _update_free_reeling(delta: float) -> void:
	if not _reel_input_held:
		return

	var intended_progress: float = minf(
		progress + _reel_speed * delta,
		1.0
	)
	var next_barrier: Barrier = _get_next_undefeated_barrier()
	if next_barrier != null and intended_progress >= next_barrier.position:
		progress = next_barrier.position
		_active_barrier_index = _barriers.find(next_barrier)
		state = CatchState.BLOCKED_BY_BARRIER
		_auto_click_accumulator = 0.0
	else:
		progress = intended_progress


func _update_chase(delta: float) -> void:
	var active_delta: float = delta
	if _chase_delay_remaining > 0.0:
		var protected_time: float = minf(_chase_delay_remaining, active_delta)
		_chase_delay_remaining -= protected_time
		active_delta -= protected_time
	if active_delta <= 0.0:
		return
	chase_progress = minf(
		chase_progress + CHASE_SPEED * active_delta,
		1.0
	)


func _is_chase_failure() -> bool:
	if _chase_delay_remaining > 0.0:
		return false
	return chase_progress + _failure_epsilon >= progress


func _update_auto_click(delta: float) -> void:
	if not auto_click_enabled or not _reel_input_held:
		return
	_auto_click_accumulator += delta
	var interval: float = maxf(auto_click_interval, 0.05)
	while (
		_auto_click_accumulator >= interval
		and state == CatchState.BLOCKED_BY_BARRIER
		and _reel_input_held
	):
		_auto_click_accumulator -= interval
		_damage_active_barrier()


func _damage_active_barrier() -> void:
	if (
		state != CatchState.BLOCKED_BY_BARRIER
		or _active_barrier_index < 0
		or _active_barrier_index >= _barriers.size()
	):
		return

	var barrier: Barrier = _barriers[_active_barrier_index]
	if barrier.defeated:
		return
	barrier.health = maxi(barrier.health - _click_power, 0)
	if barrier.health == 0:
		barrier.defeated = true
		_active_barrier_index = -1
		_auto_click_accumulator = 0.0
		state = CatchState.REELING
	_emit_encounter_update()


func _get_next_undefeated_barrier() -> Barrier:
	for barrier: Barrier in _barriers:
		if not barrier.defeated and barrier.position >= progress:
			return barrier
	return null


func _seed_encounter_rng() -> void:
	if use_deterministic_test_seed:
		encounter_seed = deterministic_test_seed
		_rng.seed = deterministic_test_seed
	else:
		_rng.randomize()
		encounter_seed = _rng.seed


func _generate_barriers(profile: CatchDifficultyProfileType) -> void:
	var count_range: Vector2i = profile.get_barrier_count_range()
	var interval: Vector2 = profile.get_generation_interval()
	var spacing: float = maxf(profile.minimum_barrier_spacing, 0.01)
	var available_distance: float = maxf(interval.y - interval.x, 0.0)
	var maximum_fitting_count: int = 0
	if available_distance > 0.0:
		maximum_fitting_count = int(floor(available_distance / spacing)) + 1
	var requested_count: int = _rng.randi_range(count_range.x, count_range.y)
	var barrier_count: int = mini(requested_count, maximum_fitting_count)
	if barrier_count <= 0:
		return

	var random_offsets := PackedFloat32Array()
	for _barrier_index: int in range(barrier_count):
		random_offsets.append(_rng.randf())
	random_offsets.sort()
	var required_spacing: float = spacing * float(barrier_count - 1)
	var random_slack: float = maxf(available_distance - required_spacing, 0.0)
	for barrier_index: int in range(barrier_count):
		var position: float = (
			interval.x
			+ spacing * float(barrier_index)
			+ random_offsets[barrier_index] * random_slack
		)
		var health: int = FishQualityType.barrier_health_for_catch(
			_fish_quality,
			_fish_rarity,
			_fish_weight_percentile,
			_rng.randf_range(0.9, 1.1),
		)
		_barriers.append(Barrier.new(position, health))


func _resolve_catch() -> void:
	if state in [CatchState.CAUGHT, CatchState.ESCAPED, CatchState.IDLE]:
		return
	state = CatchState.CAUGHT
	_reel_input_held = false
	_auto_click_accumulator = 0.0
	_emit_encounter_update()
	caught.emit()


func _resolve_escape() -> void:
	if state in [CatchState.CAUGHT, CatchState.ESCAPED]:
		return
	state = CatchState.ESCAPED
	_reel_input_held = false
	_auto_click_accumulator = 0.0
	_emit_encounter_update()
	escaped.emit()


func _emit_encounter_update() -> void:
	var positions := PackedFloat32Array()
	var health := PackedInt32Array()
	var maximum_health := PackedInt32Array()
	for barrier: Barrier in _barriers:
		positions.append(barrier.position)
		health.append(barrier.health)
		maximum_health.append(barrier.maximum_health)
	encounter_updated.emit(
		progress,
		chase_progress,
		positions,
		health,
		maximum_health,
		_active_barrier_index,
		state != CatchState.IDLE
	)
