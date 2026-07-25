class_name FishingSpot
extends Area3D

const FishDataType = preload("res://fish/fish_data.gd")
const FishingPresentationType = preload("res://fishing/fishing_presentation.gd")
const PlayerType = preload("res://player/player.gd")

signal status_changed(status: String)
signal reel_progress_changed(progress: float, visible: bool)

enum FishingState {
	READY,
	AIMING_CAST,
	CASTING,
	WAITING_FOR_BITE,
	BITE_ACTIVE,
	REELING,
	COOLDOWN,
}

@export_category("Cast")
@export_range(0.1, 30.0, 0.05) var minimum_cast_distance: float = 0.5
@export_range(0.1, 30.0, 0.1) var maximum_cast_distance: float = 14.0
@export_range(0.1, 10.0, 0.1) var cast_charge_duration: float = 2.75
@export_flags_3d_physics var fishable_surface_mask: int = 4

@export_category("Withdrawal")
@export_range(0.1, 20.0, 0.1) var withdrawal_rate: float = 4.9
@export_range(0.1, 10.0, 0.1) var withdrawal_cancel_distance: float = 1.0

@export_category("Timing")
@export_range(0.1, 30.0, 0.1) var wait_time: float = 2.0
@export_range(0.1, 10.0, 0.1) var bite_window_duration: float = 1.5
@export_range(0.1, 10.0, 0.1) var cooldown_duration: float = 1.0
@export_range(0.01, 5.0, 0.01) var reel_gain_rate: float = 0.67
@export_range(0.01, 5.0, 0.01) var reel_decay_rate: float = 0.2
@export_range(0.0, 0.95, 0.05) var hooked_starting_progress: float = 0.25

@export_category("Catch")
@export var catchable_fish: FishDataType

@onready var _presentation: FishingPresentationType = %FishingPresentation

var state: FishingState = FishingState.READY
var _nearby_player: PlayerType
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
var _reel_progress: float = 0.0
var _reel_input_held: bool = false
var _cooldown_status: String = ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_presentation.cast_completed.connect(_on_cast_completed)


func _process(delta: float) -> void:
	if state == FishingState.READY and not Input.is_action_pressed("fish_primary"):
		_new_cast_press_armed = true

	match state:
		FishingState.AIMING_CAST:
			_update_cast_charge(delta)
			if not Input.is_action_pressed("fish_primary"):
				_confirm_cast()
		FishingState.WAITING_FOR_BITE:
			_state_time_remaining -= delta
			if _state_time_remaining <= 0.0:
				_activate_bite()
			else:
				if (
					_withdrawal_input_held
					and not Input.is_action_pressed("fish_primary")
				):
					_withdrawal_input_held = false
				if _withdrawal_input_held:
					_update_withdrawal(delta)
		FishingState.BITE_ACTIVE:
			_state_time_remaining -= delta
			if _state_time_remaining <= 0.0:
				_miss_bite()
		FishingState.REELING:
			if _reel_input_held and not Input.is_action_pressed("fish_primary"):
				_reel_input_held = false
			_update_reel_progress(delta)
		FishingState.COOLDOWN:
			_state_time_remaining -= delta
			if _state_time_remaining <= 0.0:
				_return_to_ready()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("ui_cancel")
		and _active_player != null
		and state in [
			FishingState.AIMING_CAST,
			FishingState.CASTING,
			FishingState.WAITING_FOR_BITE,
			FishingState.BITE_ACTIVE,
			FishingState.REELING,
		]
	):
		_cancel_attempt()
		get_viewport().set_input_as_handled()
		return

	if _nearby_player == null or not _nearby_player.is_local_control_enabled():
		return
	if not event.is_action("fish_primary"):
		return

	if event.is_pressed():
		match state:
			FishingState.READY:
				if not _new_cast_press_armed:
					return
				_begin_aiming(_nearby_player)
			FishingState.WAITING_FOR_BITE:
				_withdrawal_input_held = true
			FishingState.BITE_ACTIVE:
				_confirm_hook()
			FishingState.REELING:
				_reel_input_held = true
			_:
				return
		get_viewport().set_input_as_handled()
	elif state == FishingState.AIMING_CAST:
		_confirm_cast()
		get_viewport().set_input_as_handled()
	elif state == FishingState.WAITING_FOR_BITE:
		_withdrawal_input_held = false
		get_viewport().set_input_as_handled()
	elif state == FishingState.REELING:
		_reel_input_held = false
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
	_presentation.begin_aim(
		_active_player.get_fishing_rod_tip(),
		_active_player.get_fishing_rod(),
		_cast_target
	)


func _update_cast_charge(delta: float) -> void:
	if state != FishingState.AIMING_CAST:
		return

	_cast_charge = minf(_cast_charge + delta / cast_charge_duration, 1.0)
	var maximum_distance: float = maxf(minimum_cast_distance, maximum_cast_distance)
	var distance: float = lerpf(minimum_cast_distance, maximum_distance, _cast_charge)
	_cast_target = _calculate_cast_target(distance)
	_presentation.update_aim_target(_cast_target, _cast_charge)
	_presentation.update_rod_charge(_cast_charge)


func _confirm_cast() -> void:
	if state != FishingState.AIMING_CAST:
		return

	_cast_landing_is_fishable = _is_landing_fishable(_cast_target)
	state = FishingState.CASTING
	status_changed.emit("Casting...")
	_presentation.begin_cast(_cast_target)


func _on_cast_completed() -> void:
	if state != FishingState.CASTING:
		return

	if not _cast_landing_is_fishable:
		_cleanup_attempt("Can't fish there.", &"invalid")
		return

	state = FishingState.WAITING_FOR_BITE
	_state_time_remaining = wait_time
	_withdrawal_progress = 0.0
	_withdrawal_input_held = false
	_withdrawal_endpoint = Vector3(
		_cast_origin_position.x + _cast_direction.x * withdrawal_cancel_distance,
		_presentation.get_water_surface_height(),
		_cast_origin_position.z + _cast_direction.z * withdrawal_cancel_distance
	)
	status_changed.emit("Waiting for a bite...")


func _update_withdrawal(delta: float) -> void:
	if state != FishingState.WAITING_FOR_BITE:
		return

	var landing_offset: Vector3 = _cast_target - _cast_origin_position
	landing_offset.y = 0.0
	var landing_distance: float = landing_offset.length()
	var withdrawable_distance: float = landing_distance - withdrawal_cancel_distance
	if withdrawable_distance <= 0.0:
		_cancel_from_withdrawal()
		return

	_withdrawal_progress = minf(
		_withdrawal_progress + withdrawal_rate * delta / withdrawable_distance,
		1.0
	)
	var current_position: Vector3 = _cast_target.lerp(
		_withdrawal_endpoint,
		_withdrawal_progress
	)
	_presentation.show_withdrawal_position(current_position)
	if is_equal_approx(_withdrawal_progress, 1.0):
		_cancel_from_withdrawal()


func _activate_bite() -> void:
	if state != FishingState.WAITING_FOR_BITE:
		return

	state = FishingState.BITE_ACTIVE
	_state_time_remaining = bite_window_duration
	_withdrawal_input_held = false
	status_changed.emit("Bite! Left click to hook")
	_presentation.show_bite()


func _confirm_hook() -> void:
	if state != FishingState.BITE_ACTIVE or _active_player == null:
		return

	state = FishingState.REELING
	_state_time_remaining = 0.0
	_reel_progress = clampf(hooked_starting_progress, 0.0, 0.95)
	_reel_input_held = true
	status_changed.emit("Hold left click to reel")
	reel_progress_changed.emit(_reel_progress, true)
	_presentation.begin_reeling(_withdrawal_endpoint)
	_presentation.show_reel_progress(_reel_progress, _reel_input_held)


func _update_reel_progress(delta: float) -> void:
	if state != FishingState.REELING:
		return

	if _reel_input_held:
		_reel_progress = minf(_reel_progress + reel_gain_rate * delta, 1.0)
	else:
		_reel_progress = maxf(_reel_progress - reel_decay_rate * delta, 0.0)
	reel_progress_changed.emit(_reel_progress, true)
	_presentation.show_reel_progress(_reel_progress, _reel_input_held)
	if is_equal_approx(_reel_progress, 1.0):
		_resolve_catch()
	elif is_zero_approx(_reel_progress):
		_resolve_escape()


func _resolve_catch() -> void:
	if state != FishingState.REELING or _active_player == null or catchable_fish == null:
		_cancel_attempt()
		return

	_active_player.inventory.add_fish(catchable_fish)
	_cleanup_attempt("Caught %s!" % catchable_fish.display_name, &"catch")


func _resolve_escape() -> void:
	if state != FishingState.REELING:
		return

	var fish_name: String = "The fish"
	if catchable_fish != null and not catchable_fish.display_name.is_empty():
		fish_name = "The %s" % catchable_fish.display_name
	_cleanup_attempt("%s got away!" % fish_name, &"escape")


func _miss_bite() -> void:
	if state != FishingState.BITE_ACTIVE:
		return
	_cleanup_attempt("The fish got away.", &"miss")


func _cleanup_attempt(
	cooldown_message: String = "",
	visual_outcome: StringName = &"",
) -> void:
	if _active_player != null:
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
	_reel_input_held = false
	_reel_progress = 0.0
	reel_progress_changed.emit(0.0, false)
	if visual_outcome.is_empty():
		_presentation.cleanup()
	else:
		_presentation.play_outcome(visual_outcome)

	if cooldown_message.is_empty():
		state = FishingState.READY
		_cooldown_status = ""
		if _nearby_player != null:
			status_changed.emit("Left click to cast")
		else:
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
	if _nearby_player != null:
		status_changed.emit("Left click to cast")
	else:
		status_changed.emit("")


func _cancel_attempt() -> void:
	_cleanup_attempt("Fishing cancelled.", &"cancel")


func _cancel_from_withdrawal() -> void:
	if state != FishingState.WAITING_FOR_BITE:
		return
	_new_cast_press_armed = false
	_cleanup_attempt("", &"withdrawal")


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


func _is_landing_fishable(target: Vector3) -> bool:
	var query := PhysicsPointQueryParameters3D.new()
	query.position = target
	query.collision_mask = fishable_surface_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results: Array[Dictionary] = get_world_3d().direct_space_state.intersect_point(
		query,
		1
	)
	return not results.is_empty()


func _on_body_entered(body: Node3D) -> void:
	if body is not PlayerType or not body.is_local_control_enabled():
		return
	if _nearby_player != null:
		return

	_nearby_player = body
	if state == FishingState.READY:
		status_changed.emit("Left click to cast")


func _on_body_exited(body: Node3D) -> void:
	if body != _nearby_player:
		return

	_nearby_player = null
	if body == _active_player:
		_cancel_attempt()
	else:
		status_changed.emit("")
