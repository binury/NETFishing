class_name FishingSpot
extends Node3D

const FishDataType = preload("res://fish/fish_data.gd")
const FishCatchType = preload("res://fish/fish_catch.gd")
const FishSelectorType = preload("res://fish/fish_selector.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")
const CatchControllerType = preload("res://fishing/catch_controller.gd")
const FishingContextType = preload("res://fishing/fishing_context.gd")
const FishingPresentationType = preload("res://fishing/fishing_presentation.gd")
const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const PlayerType = preload("res://player/player.gd")
const FishableWaterRegionType = preload(
	"res://world/fishable_water_region.gd"
)

signal status_changed(status: String)
signal catch_display_changed(
	progress: float,
	chase_progress: float,
	barrier_positions: PackedFloat32Array,
	barrier_health: PackedInt32Array,
	barrier_max_health: PackedInt32Array,
	active_barrier_index: int,
	visible: bool,
)
signal showcase_changed(
	fish_name: String,
	rarity_name: String,
	weight_lb: float,
	visible: bool,
)
signal bite_activated

enum FishingState {
	READY,
	AIMING_CAST,
	CASTING,
	WAITING_FOR_BITE,
	FIGHTING,
	SHOWING_CATCH,
	COOLDOWN,
}

@export_category("Cast")
@export_range(0.1, 30.0, 0.05) var minimum_cast_distance: float = 0.5
@export_range(0.1, 30.0, 0.1) var maximum_cast_distance: float = 14.0
@export_range(0.1, 10.0, 0.1) var cast_charge_duration: float = 2.75
@export_flags_3d_physics var fishable_surface_mask: int = 4
@export_range(0.01, 1.0, 0.01) var fishable_query_radius: float = 0.08

@export_category("Target Preview")
@export_flags_3d_physics var preview_surface_mask: int = 5
@export_range(1.0, 100.0, 1.0) var preview_ray_start_height: float = 30.0
@export_range(1.0, 200.0, 1.0) var preview_ray_length: float = 60.0
@export_range(0.01, 1.0, 0.01) var preview_marker_vertical_offset: float = 0.06

@export_category("Withdrawal")
@export_range(0.1, 20.0, 0.1) var withdrawal_rate: float = 4.9
@export_range(0.1, 10.0, 0.1) var withdrawal_cancel_distance: float = 1.0

@export_category("Timing")
@export_range(0.1, 30.0, 0.1) var wait_time: float = 2.0
@export_range(0.1, 10.0, 0.1) var cooldown_duration: float = 1.0

@export_category("Selection")
@export_range(0.0, 10.0, 0.05) var undiscovered_weight_multiplier: float = 1.5
@export var use_deterministic_selection_seed: bool = false
@export var deterministic_selection_seed: int = 24680

@export_category("Context Testing")
@export var context_is_night: bool = false
@export var context_is_raining: bool = false
@export var context_event_tags: Array[StringName] = []
@export var context_bait_tags: Array[StringName] = []

@onready var _catch_controller: CatchControllerType = %CatchController
@onready var _presentation: FishingPresentationType = %FishingPresentation

var state: FishingState = FishingState.READY
var _external_input_blocked: bool = false
var _local_player: PlayerType
var _local_inventory: FishInventoryType
var _local_collection_log: CollectionLogType
var _active_player: PlayerType
var _state_time_remaining: float = 0.0
var _cast_charge: float = 0.0
var _cast_direction: Vector3 = Vector3.FORWARD
var _cast_origin_position: Vector3
var _cast_target: Vector3
var _cast_landing_is_fishable: bool = false
var _withdrawal_endpoint: Vector3
var _withdrawal_progress: float = 0.0
var _withdrawal_input_held: bool = false
var _new_cast_press_armed: bool = true
var _bobber_water_position: Vector3
var _fight_start_position: Vector3
var _cooldown_status: String = ""
var _fishable_query_shape: SphereShape3D = SphereShape3D.new()
var _fish_selector: FishSelectorType = FishSelectorType.new()
var _selected_water_region: FishableWaterRegionType
var _selection_context: FishingContextType
var _selected_fish: FishDataType
var _pending_catch: FishCatchType
var _showcase_ready: bool = false
var _put_away_press_armed: bool = false
var _showcase_restore_generation: int = 0


func _ready() -> void:
	_catch_controller.encounter_updated.connect(_on_catch_encounter_updated)
	_catch_controller.caught.connect(_on_catch_completed)
	_catch_controller.escaped.connect(_on_catch_escaped)
	_presentation.cast_completed.connect(_on_cast_completed)
	_presentation.outcome_completed.connect(_on_outcome_completed)


func setup(
	local_player: PlayerType,
	local_inventory: FishInventoryType,
	local_collection_log: CollectionLogType,
) -> void:
	_local_player = local_player
	_local_inventory = local_inventory
	_local_collection_log = local_collection_log


func can_open_player_menu() -> bool:
	return not _external_input_blocked and state in [
		FishingState.READY,
		FishingState.WAITING_FOR_BITE,
	]


func begin_water_recovery() -> void:
	_external_input_blocked = true
	if state in [
		FishingState.AIMING_CAST,
		FishingState.CASTING,
		FishingState.WAITING_FOR_BITE,
		FishingState.FIGHTING,
	]:
		_cancel_attempt()
	elif state == FishingState.SHOWING_CATCH:
		_secure_showcase_catch_for_recovery()


func end_water_recovery() -> void:
	_external_input_blocked = false


func _secure_showcase_catch_for_recovery() -> void:
	if (
		_pending_catch != null
		and _local_inventory != null
		and _local_collection_log != null
	):
		_local_inventory.add_catch(_pending_catch)
		_local_collection_log.mark_discovered(_pending_catch.fish_id)
	_pending_catch = null
	_showcase_ready = false
	_put_away_press_armed = false
	showcase_changed.emit("", "", 0.0, false)
	if _active_player != null:
		_active_player.end_catch_showcase(Callable(), true)
	_cleanup_attempt()


func _exit_tree() -> void:
	_showcase_restore_generation += 1
	if (
		state == FishingState.SHOWING_CATCH
		and _pending_catch != null
		and _local_inventory != null
		and is_instance_valid(_local_inventory)
		and _local_collection_log != null
		and is_instance_valid(_local_collection_log)
	):
		_local_inventory.add_catch(_pending_catch)
		_local_collection_log.mark_discovered(_pending_catch.fish_id)
		_pending_catch = null
	if _active_player != null and is_instance_valid(_active_player):
		_active_player.end_catch_showcase(Callable(), true)
		_active_player.set_movement_enabled(true)
	_active_player = null
	_selected_water_region = null
	_selection_context = null
	_selected_fish = null
	_showcase_ready = false
	_put_away_press_armed = false


func _process(delta: float) -> void:
	if state == FishingState.READY and not Input.is_action_pressed("fish_primary"):
		_new_cast_press_armed = true
	if (
		state == FishingState.SHOWING_CATCH
		and _showcase_ready
		and not Input.is_action_pressed("fish_primary")
	):
		_put_away_press_armed = true

	match state:
		FishingState.AIMING_CAST:
			_update_cast_charge(delta)
			if not Input.is_action_pressed("fish_primary"):
				_confirm_cast()
		FishingState.WAITING_FOR_BITE:
			_update_waiting_for_bite(delta)
		FishingState.FIGHTING:
			if not Input.is_action_pressed("fish_primary"):
				_catch_controller.set_reel_input(false)
		FishingState.COOLDOWN:
			_state_time_remaining -= delta
			if _state_time_remaining <= 0.0:
				_return_to_ready()


func _unhandled_input(event: InputEvent) -> void:
	if _external_input_blocked:
		return
	if (
		event.is_action_pressed("ui_cancel")
		and state == FishingState.SHOWING_CATCH
	):
		_put_away_catch()
		get_viewport().set_input_as_handled()
		return
	if (
		event.is_action_pressed("ui_cancel")
		and _active_player != null
		and state in [
			FishingState.AIMING_CAST,
			FishingState.CASTING,
			FishingState.WAITING_FOR_BITE,
			FishingState.FIGHTING,
		]
	):
		_cancel_attempt()
		get_viewport().set_input_as_handled()
		return

	if _local_player == null or not _local_player.is_local_control_enabled():
		return
	if not event.is_action("fish_primary"):
		return

	if event.is_pressed():
		match state:
			FishingState.READY:
				if not _new_cast_press_armed:
					return
				_begin_aiming(_local_player)
			FishingState.WAITING_FOR_BITE:
				_withdrawal_input_held = true
				_presentation.set_line_mode(
					FishingPresentationType.LineMode.TAUT
				)
			FishingState.FIGHTING:
				_catch_controller.handle_primary_pressed()
				_presentation.set_line_mode(
					FishingPresentationType.LineMode.TAUT
				)
			FishingState.SHOWING_CATCH:
				if _showcase_ready and _put_away_press_armed:
					_put_away_catch()
				else:
					return
			_:
				return
		get_viewport().set_input_as_handled()
	elif state == FishingState.AIMING_CAST:
		_confirm_cast()
		get_viewport().set_input_as_handled()
	elif state == FishingState.WAITING_FOR_BITE:
		_withdrawal_input_held = false
		_presentation.set_line_mode(FishingPresentationType.LineMode.SLACK)
		get_viewport().set_input_as_handled()
	elif state == FishingState.FIGHTING:
		_catch_controller.set_reel_input(false)
		get_viewport().set_input_as_handled()


func _begin_aiming(player: PlayerType) -> void:
	if state != FishingState.READY or _active_player != null:
		return

	_active_player = player
	_active_player.set_movement_enabled(false)
	_cast_direction = _capture_cast_direction(_active_player)
	_cast_origin_position = _active_player.get_cast_origin_position()
	_cast_charge = 0.0
	_cast_target = _calculate_cast_target(minimum_cast_distance)
	state = FishingState.AIMING_CAST
	status_changed.emit("Hold left click to aim • Release to cast")
	var target_is_fishable: bool = is_target_fishable(_cast_target)
	var preview_position: Vector3 = _resolve_preview_surface_position(_cast_target)
	_presentation.begin_aim(
		_active_player.get_fishing_rod_tip(),
		_active_player.get_fishing_rod(),
		preview_position,
		target_is_fishable
	)


func _update_cast_charge(delta: float) -> void:
	if state != FishingState.AIMING_CAST:
		return

	_cast_charge = minf(_cast_charge + delta / cast_charge_duration, 1.0)
	var maximum_distance: float = maxf(minimum_cast_distance, maximum_cast_distance)
	var distance: float = lerpf(minimum_cast_distance, maximum_distance, _cast_charge)
	_cast_target = _calculate_cast_target(distance)
	var target_is_fishable: bool = is_target_fishable(_cast_target)
	var preview_position: Vector3 = _resolve_preview_surface_position(_cast_target)
	_presentation.update_aim_target(
		preview_position,
		_cast_charge,
		target_is_fishable
	)
	_presentation.update_rod_charge(_cast_charge)


func _confirm_cast() -> void:
	if state != FishingState.AIMING_CAST:
		return

	state = FishingState.CASTING
	status_changed.emit("Casting...")
	_presentation.begin_cast(_cast_target)
	_presentation.set_line_mode(FishingPresentationType.LineMode.TAUT)


func _on_cast_completed() -> void:
	if state != FishingState.CASTING:
		return

	_selected_water_region = get_fishable_water_region(_cast_target)
	_cast_landing_is_fishable = _selected_water_region != null
	if not _cast_landing_is_fishable:
		_cleanup_attempt("Can't fish there.", &"invalid")
		return
	_selection_context = _build_fishing_context(_selected_water_region)
	_fish_selector.undiscovered_weight_multiplier = undiscovered_weight_multiplier
	_fish_selector.use_deterministic_test_seed = use_deterministic_selection_seed
	_fish_selector.deterministic_test_seed = deterministic_selection_seed
	_fish_selector.begin_roll()
	_selected_fish = _fish_selector.select_fish(
		_selected_water_region.fish_pool,
		_selection_context,
		_local_collection_log
	)
	if _selected_fish == null:
		_cleanup_attempt("Nothing is biting here.", &"invalid")
		return

	state = FishingState.WAITING_FOR_BITE
	_state_time_remaining = wait_time
	_withdrawal_progress = 0.0
	_withdrawal_input_held = false
	_bobber_water_position = _cast_target
	_withdrawal_endpoint = Vector3(
		_cast_origin_position.x + _cast_direction.x * withdrawal_cancel_distance,
		_presentation.get_water_surface_height(),
		_cast_origin_position.z + _cast_direction.z * withdrawal_cancel_distance
	)
	_presentation.set_line_mode(FishingPresentationType.LineMode.SLACK)
	status_changed.emit("Waiting for a bite...")


func _update_waiting_for_bite(delta: float) -> void:
	if (
		_withdrawal_input_held
		and not Input.is_action_pressed("fish_primary")
	):
		_withdrawal_input_held = false
		_presentation.set_line_mode(FishingPresentationType.LineMode.SLACK)

	if not _withdrawal_input_held:
		_state_time_remaining -= delta
		if _state_time_remaining <= 0.0:
			_activate_bite()
		return

	var completion_time: float = _get_withdrawal_completion_time(delta)
	if _state_time_remaining <= delta and _state_time_remaining <= completion_time:
		_update_withdrawal(maxf(_state_time_remaining, 0.0))
		if state == FishingState.WAITING_FOR_BITE:
			_activate_bite()
		return

	_update_withdrawal(delta)
	if state != FishingState.WAITING_FOR_BITE:
		return
	_state_time_remaining -= delta
	if _state_time_remaining <= 0.0:
		_activate_bite()


func _update_withdrawal(delta: float) -> void:
	if state != FishingState.WAITING_FOR_BITE:
		return

	var withdrawable_distance: float = _get_withdrawable_distance()
	if withdrawable_distance <= 0.0:
		_cancel_from_withdrawal()
		return

	var next_progress: float = minf(
		_withdrawal_progress + withdrawal_rate * delta / withdrawable_distance,
		1.0
	)
	var desired_position: Vector3 = _cast_target.lerp(
		_withdrawal_endpoint,
		next_progress
	)
	var clamped_position: Vector3 = find_last_fishable_position(
		_bobber_water_position,
		desired_position
	)
	_withdrawal_progress = next_progress
	_bobber_water_position = clamped_position
	_presentation.show_withdrawal_position(_bobber_water_position)
	if not clamped_position.is_equal_approx(desired_position):
		_resolve_withdrawal_at_shore()
		return
	if is_equal_approx(_withdrawal_progress, 1.0):
		_cancel_from_withdrawal()


func _get_withdrawal_completion_time(delta: float) -> float:
	var withdrawable_distance: float = _get_withdrawable_distance()
	if withdrawable_distance <= 0.0:
		return 0.0

	var progress_step: float = withdrawal_rate * delta / withdrawable_distance
	if progress_step <= 0.0:
		return INF
	var next_progress: float = minf(_withdrawal_progress + progress_step, 1.0)
	var desired_position: Vector3 = _cast_target.lerp(
		_withdrawal_endpoint,
		next_progress
	)
	var clamped_position: Vector3 = find_last_fishable_position(
		_bobber_water_position,
		desired_position
	)
	if not clamped_position.is_equal_approx(desired_position):
		var segment_length: float = _bobber_water_position.distance_to(
			desired_position
		)
		if segment_length <= 0.0:
			return 0.0
		return delta * (
			_bobber_water_position.distance_to(clamped_position)
			/ segment_length
		)
	if is_equal_approx(next_progress, 1.0):
		return delta * (1.0 - _withdrawal_progress) / progress_step
	return INF


func _get_withdrawable_distance() -> float:
	var landing_offset: Vector3 = _cast_target - _cast_origin_position
	landing_offset.y = 0.0
	return landing_offset.length() - withdrawal_cancel_distance


func _activate_bite() -> void:
	if state != FishingState.WAITING_FOR_BITE:
		return

	if (
		_active_player == null
		or _selected_fish == null
		or _selected_fish.catch_profile == null
	):
		_cancel_attempt()
		return

	state = FishingState.FIGHTING
	_state_time_remaining = 0.0
	_withdrawal_input_held = false
	_fight_start_position = _bobber_water_position
	bite_activated.emit()
	status_changed.emit("Fish on!")
	_presentation.set_line_mode(FishingPresentationType.LineMode.TAUT)
	_presentation.begin_reeling()
	_catch_controller.start_encounter(
		_selected_fish.catch_profile,
		_active_player.reel_speed,
		_active_player.click_power
	)
	_catch_controller.set_reel_input(
		Input.is_action_pressed("fish_primary")
	)
	_presentation.show_bite()


func _on_catch_encounter_updated(
	progress: float,
	chase_progress: float,
	barrier_positions: PackedFloat32Array,
	barrier_health: PackedInt32Array,
	barrier_max_health: PackedInt32Array,
	active_barrier_index: int,
	visible: bool,
) -> void:
	catch_display_changed.emit(
		progress,
		chase_progress,
		barrier_positions,
		barrier_health,
		barrier_max_health,
		active_barrier_index,
		visible
	)
	if state != FishingState.FIGHTING or not visible:
		return

	var desired_position: Vector3 = _fight_start_position.lerp(
		_withdrawal_endpoint,
		progress
	)
	_bobber_water_position = find_last_fishable_position(
		_fight_start_position,
		desired_position
	)
	_presentation.show_reel_position(
		_bobber_water_position,
		Input.is_action_pressed("fish_primary")
	)
	if (
		active_barrier_index >= 0
		and active_barrier_index < barrier_health.size()
		and active_barrier_index < barrier_max_health.size()
	):
		status_changed.emit(
			"Barrier: %d / %d"
			% [
				barrier_health[active_barrier_index],
				barrier_max_health[active_barrier_index],
			]
		)
	else:
		status_changed.emit("Hold left click to reel")


func _on_catch_completed() -> void:
	if (
		state != FishingState.FIGHTING
		or _active_player == null
		or _selected_fish == null
	):
		_cancel_attempt()
		return

	_pending_catch = _fish_selector.create_catch(_selected_fish)
	if _pending_catch == null or not _pending_catch.is_valid():
		_cancel_attempt()
		return
	state = FishingState.SHOWING_CATCH
	_showcase_ready = false
	_put_away_press_armed = false
	_catch_controller.reset()
	_presentation.set_line_mode(FishingPresentationType.LineMode.TAUT)
	_presentation.play_outcome(&"catch")


func _on_catch_escaped() -> void:
	if state != FishingState.FIGHTING:
		return

	var fish_name: String = "The fish"
	if _selected_fish != null and not _selected_fish.display_name.is_empty():
		fish_name = "The %s" % _selected_fish.display_name
	_cleanup_attempt("%s got away!" % fish_name, &"escape")


func _on_outcome_completed(outcome: StringName) -> void:
	if (
		outcome != &"catch"
		or state != FishingState.SHOWING_CATCH
		or _active_player == null
		or _pending_catch == null
	):
		return
	_showcase_ready = true
	_active_player.begin_catch_showcase(_pending_catch)
	showcase_changed.emit(
		_pending_catch.fish.display_name,
		_pending_catch.fish.get_rarity_name(),
		_pending_catch.weight_lb,
		true
	)
	status_changed.emit("Left click or Escape to put away")


func _put_away_catch() -> void:
	if (
		state != FishingState.SHOWING_CATCH
		or _active_player == null
		or _local_inventory == null
		or _local_collection_log == null
		or _pending_catch == null
	):
		return
	var caught_name: String = _pending_catch.fish.display_name
	_local_inventory.add_catch(_pending_catch)
	_local_collection_log.mark_discovered(_pending_catch.fish_id)
	_pending_catch = null
	_showcase_ready = false
	_put_away_press_armed = false
	showcase_changed.emit("", "", 0.0, false)
	_showcase_restore_generation += 1
	var restore_generation: int = _showcase_restore_generation
	_active_player.end_catch_showcase(
		_finish_showcase_put_away.bind(
			restore_generation,
			"Caught %s!" % caught_name
		)
	)


func _finish_showcase_put_away(
	restore_generation: int,
	cooldown_message: String,
) -> void:
	if (
		restore_generation != _showcase_restore_generation
		or state != FishingState.SHOWING_CATCH
		or _active_player == null
	):
		return
	_cleanup_attempt(cooldown_message)


func _cleanup_attempt(
	cooldown_message: String = "",
	visual_outcome: StringName = &"",
) -> void:
	_showcase_restore_generation += 1
	if _active_player != null:
		_active_player.end_catch_showcase()
		_active_player.set_movement_enabled(true)
	_active_player = null
	_state_time_remaining = 0.0
	_cast_charge = 0.0
	_cast_direction = Vector3.FORWARD
	_cast_origin_position = Vector3.ZERO
	_cast_target = Vector3.ZERO
	_cast_landing_is_fishable = false
	_withdrawal_endpoint = Vector3.ZERO
	_withdrawal_progress = 0.0
	_withdrawal_input_held = false
	_bobber_water_position = Vector3.ZERO
	_fight_start_position = Vector3.ZERO
	_selected_water_region = null
	_selection_context = null
	_selected_fish = null
	_pending_catch = null
	_showcase_ready = false
	_put_away_press_armed = false
	showcase_changed.emit("", "", 0.0, false)
	_catch_controller.reset()
	if visual_outcome.is_empty():
		_presentation.cleanup()
	else:
		if visual_outcome in [&"catch", &"invalid", &"withdrawal"]:
			_presentation.set_line_mode(
				FishingPresentationType.LineMode.TAUT
			)
		else:
			_presentation.set_line_mode(
				FishingPresentationType.LineMode.HIDDEN
			)
		_presentation.play_outcome(visual_outcome)

	if cooldown_message.is_empty():
		state = FishingState.READY
		_cooldown_status = ""
		status_changed.emit("")
	else:
		state = FishingState.COOLDOWN
		_state_time_remaining = cooldown_duration
		_cooldown_status = cooldown_message
		status_changed.emit(_cooldown_status)


func _return_to_ready() -> void:
	state = FishingState.READY
	_state_time_remaining = 0.0
	_cooldown_status = ""
	status_changed.emit("")


func _cancel_attempt() -> void:
	_cleanup_attempt("Fishing cancelled.", &"cancel")


func _cancel_from_withdrawal() -> void:
	if state != FishingState.WAITING_FOR_BITE:
		return
	_new_cast_press_armed = false
	_cleanup_attempt("", &"withdrawal")


func _resolve_withdrawal_at_shore() -> void:
	if state != FishingState.WAITING_FOR_BITE:
		return
	_cancel_from_withdrawal()


func _capture_cast_direction(player: PlayerType) -> Vector3:
	var direction: Vector3 = player.get_facing_direction()
	direction.y = 0.0
	if direction.is_zero_approx():
		direction = -player.global_basis.z
		direction.y = 0.0
	if direction.is_zero_approx():
		return Vector3.FORWARD
	return direction.normalized()


func _calculate_cast_target(distance: float) -> Vector3:
	return Vector3(
		_cast_origin_position.x + _cast_direction.x * distance,
		_presentation.get_water_surface_height(),
		_cast_origin_position.z + _cast_direction.z * distance
	)


func is_target_fishable(target: Vector3) -> bool:
	return get_fishable_water_region(target) != null


func get_fishable_water_region(
	target: Vector3,
) -> FishableWaterRegionType:
	_fishable_query_shape.radius = fishable_query_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _fishable_query_shape
	query.transform = Transform3D(
		Basis.IDENTITY,
		Vector3(target.x, _presentation.get_water_surface_height(), target.z)
	)
	query.collision_mask = fishable_surface_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(
		query,
		32
	)
	var selected_region: FishableWaterRegionType
	for result: Dictionary in results:
		var collider: Object = result.get("collider")
		var region: FishableWaterRegionType = collider as FishableWaterRegionType
		if region == null or region.fish_pool == null:
			continue
		if (
			selected_region == null
			or region.selection_priority > selected_region.selection_priority
			or (
				region.selection_priority == selected_region.selection_priority
				and region.get_instance_id() < selected_region.get_instance_id()
			)
		):
			selected_region = region
	return selected_region


func _build_fishing_context(
	region: FishableWaterRegionType,
) -> FishingContextType:
	var context := FishingContextType.new()
	context.location_tags = region.location_tags.duplicate()
	context.active_event_tags = context_event_tags.duplicate()
	context.active_bait_tags = context_bait_tags.duplicate()
	context.is_night = context_is_night
	context.is_raining = context_is_raining
	return context


func find_last_fishable_position(from: Vector3, to: Vector3) -> Vector3:
	if from.is_equal_approx(to):
		return from

	var segment_length: float = from.distance_to(to)
	var sample_spacing: float = maxf(fishable_query_radius, 0.05)
	var sample_count: int = maxi(1, ceili(segment_length / sample_spacing))
	var last_valid_fraction: float = 0.0

	for sample_index: int in range(1, sample_count + 1):
		var sample_fraction: float = float(sample_index) / float(sample_count)
		var sample_position: Vector3 = from.lerp(to, sample_fraction)
		if is_target_fishable(sample_position):
			last_valid_fraction = sample_fraction
			continue

		var invalid_fraction: float = sample_fraction
		for _iteration: int in range(10):
			var midpoint: float = (
				last_valid_fraction + invalid_fraction
			) * 0.5
			if is_target_fishable(from.lerp(to, midpoint)):
				last_valid_fraction = midpoint
			else:
				invalid_fraction = midpoint
		return from.lerp(to, last_valid_fraction)

	return to


func _resolve_preview_surface_position(target: Vector3) -> Vector3:
	var ray_start := Vector3(
		target.x,
		target.y + preview_ray_start_height,
		target.z
	)
	var ray_end := Vector3(
		target.x,
		ray_start.y - preview_ray_length,
		target.z
	)
	var query := PhysicsRayQueryParameters3D.create(
		ray_start,
		ray_end,
		preview_surface_mask
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return target

	var hit_position: Vector3 = result["position"]
	return Vector3(
		target.x,
		hit_position.y + preview_marker_vertical_offset,
		target.z
	)
