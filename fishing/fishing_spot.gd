class_name FishingSpot
extends Area3D

const FishDataType = preload("res://fish/fish_data.gd")
const PlayerType = preload("res://player/player.gd")

signal status_changed(status: String)
signal reel_progress_changed(progress: float, visible: bool)

enum FishingState {
	READY,
	WAITING_FOR_BITE,
	BITE_ACTIVE,
	REELING,
	COOLDOWN,
}

@export_category("Timing")
@export_range(0.1, 30.0, 0.1) var wait_time: float = 2.0
@export_range(0.1, 10.0, 0.1) var bite_window_duration: float = 1.5
@export_range(0.1, 10.0, 0.1) var cooldown_duration: float = 1.0
@export_range(0.01, 5.0, 0.01) var reel_gain_rate: float = 0.67
@export_range(0.01, 5.0, 0.01) var reel_decay_rate: float = 0.2
@export_range(0.0, 0.95, 0.05) var hooked_starting_progress: float = 0.25

@export_category("Catch")
@export var catchable_fish: FishDataType

var state: FishingState = FishingState.READY
var _nearby_player: PlayerType
var _active_player: PlayerType
var _state_time_remaining: float = 0.0
var _reel_progress: float = 0.0
var _reel_input_held: bool = false
var _cooldown_status: String = ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	match state:
		FishingState.WAITING_FOR_BITE:
			_state_time_remaining -= delta
			if _state_time_remaining <= 0.0:
				_activate_bite()
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
	if _nearby_player == null or not _nearby_player.is_local_control_enabled():
		return
	if not event.is_action("fish_primary"):
		return

	if event.is_pressed():
		match state:
			FishingState.READY:
				_begin_fishing(_nearby_player)
			FishingState.BITE_ACTIVE:
				_confirm_hook()
			FishingState.REELING:
				_reel_input_held = true
			_:
				return
		get_viewport().set_input_as_handled()
	elif state == FishingState.REELING:
		_reel_input_held = false
		get_viewport().set_input_as_handled()


func _begin_fishing(player: PlayerType) -> void:
	if state != FishingState.READY or _active_player != null:
		return

	_active_player = player
	_active_player.set_movement_enabled(false)
	state = FishingState.WAITING_FOR_BITE
	_state_time_remaining = wait_time
	status_changed.emit("Waiting for a bite...")


func _activate_bite() -> void:
	if state != FishingState.WAITING_FOR_BITE:
		return

	state = FishingState.BITE_ACTIVE
	_state_time_remaining = bite_window_duration
	status_changed.emit("Bite! Left click to hook")


func _confirm_hook() -> void:
	if state != FishingState.BITE_ACTIVE or _active_player == null:
		return

	state = FishingState.REELING
	_state_time_remaining = 0.0
	_reel_progress = clampf(hooked_starting_progress, 0.0, 0.95)
	_reel_input_held = true
	status_changed.emit("Hold left click to reel")
	reel_progress_changed.emit(_reel_progress, true)


func _update_reel_progress(delta: float) -> void:
	if state != FishingState.REELING:
		return

	if _reel_input_held:
		_reel_progress = minf(_reel_progress + reel_gain_rate * delta, 1.0)
	else:
		_reel_progress = maxf(_reel_progress - reel_decay_rate * delta, 0.0)
	reel_progress_changed.emit(_reel_progress, true)
	if is_equal_approx(_reel_progress, 1.0):
		_resolve_catch()
	elif is_zero_approx(_reel_progress):
		_resolve_escape()


func _resolve_catch() -> void:
	if state != FishingState.REELING or _active_player == null or catchable_fish == null:
		_cancel_attempt()
		return

	_active_player.inventory.add_fish(catchable_fish)
	_cleanup_attempt("Caught %s!" % catchable_fish.display_name)


func _resolve_escape() -> void:
	if state != FishingState.REELING:
		return

	var fish_name: String = "The fish"
	if catchable_fish != null and not catchable_fish.display_name.is_empty():
		fish_name = "The %s" % catchable_fish.display_name
	_cleanup_attempt("%s got away!" % fish_name)


func _miss_bite() -> void:
	if state != FishingState.BITE_ACTIVE:
		return
	_cleanup_attempt("The fish got away.")


func _cleanup_attempt(cooldown_message: String = "") -> void:
	if _active_player != null:
		_active_player.set_movement_enabled(true)
	_active_player = null
	_reel_input_held = false
	_reel_progress = 0.0
	reel_progress_changed.emit(0.0, false)

	if cooldown_message.is_empty():
		state = FishingState.READY
		_state_time_remaining = 0.0
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
	_cleanup_attempt()


func _cancel_attempt() -> void:
	_cleanup_attempt()


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
