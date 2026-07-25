class_name WaterRecoveryController
extends Node

enum RecoveryState {
	IDLE,
	BOBBING,
	FADING_OUT,
	FADING_IN,
}

@export_range(-1.0, 1.0, 0.01) var water_center_offset: float = 0.0
@export_range(0.0, 0.5, 0.005) var bob_amplitude: float = 0.08
@export_range(0.1, 10.0, 0.1) var bob_speed: float = 2.4
@export_range(0.0, 5.0, 0.05) var pre_fade_bob_duration: float = 1.0
@export_range(0.0, 1.0, 0.01) var respawn_height_offset: float = 0.08

var state: RecoveryState = RecoveryState.IDLE
var _player: Player
var _fishing_spot: FishingSpot
var _game_ui: GameUI
var _screen_fade: ScreenFade
var _water_trigger: PlayerWaterTrigger
var _safe_points: Array[SafeRespawnPoint] = []
var _initial_spawn_transform: Transform3D
var _entry_position: Vector3
var _bob_base_position: Vector3
var _bob_elapsed: float = 0.0
var _prior_movement_enabled: bool = true
var _prior_camera_input_enabled: bool = true
var _generation: int = 0


func setup(
	player: Player,
	fishing_spot: FishingSpot,
	game_ui: GameUI,
	screen_fade: ScreenFade,
	water_trigger: PlayerWaterTrigger,
	safe_points: Array[SafeRespawnPoint],
) -> void:
	_player = player
	_fishing_spot = fishing_spot
	_game_ui = game_ui
	_screen_fade = screen_fade
	_water_trigger = water_trigger
	_safe_points = safe_points
	_initial_spawn_transform = player.global_transform
	if not _water_trigger.recovery_requested.is_connected(
		_on_recovery_requested
	):
		_water_trigger.recovery_requested.connect(_on_recovery_requested)
	if not _screen_fade.transition_completed.is_connected(
		_on_fade_transition_completed
	):
		_screen_fade.transition_completed.connect(
			_on_fade_transition_completed
		)


func _process(delta: float) -> void:
	if state != RecoveryState.BOBBING or _player == null:
		return
	_bob_elapsed += delta
	var bob_offset: float = sin(_bob_elapsed * bob_speed * TAU) * bob_amplitude
	_player.global_position = _bob_base_position + Vector3.UP * bob_offset
	if _bob_elapsed >= pre_fade_bob_duration:
		state = RecoveryState.FADING_OUT
		_screen_fade.fade_to_black(_generation)


func _exit_tree() -> void:
	_generation += 1
	if _screen_fade != null and is_instance_valid(_screen_fade):
		_screen_fade.reset_immediately()
	if _player != null and is_instance_valid(_player):
		_player.set_water_recovery_active(false)
		_player.set_movement_enabled(_prior_movement_enabled)
		_player.set_camera_input_enabled(_prior_camera_input_enabled)
	state = RecoveryState.IDLE


func _on_recovery_requested(
	triggered_player: Player,
	surface_height: float,
) -> void:
	if (
		state != RecoveryState.IDLE
		or triggered_player != _player
		or not is_instance_valid(triggered_player)
	):
		return
	_generation += 1
	_entry_position = _player.global_position
	_game_ui.close_player_menu()
	_fishing_spot.begin_water_recovery()
	_prior_movement_enabled = _player.is_movement_enabled()
	_prior_camera_input_enabled = _player.is_camera_input_enabled()
	_player.set_movement_enabled(false)
	_player.set_camera_input_enabled(false)
	_player.set_water_recovery_active(true)
	_bob_base_position = _player.global_position
	_bob_base_position.y = (
		surface_height
		+ water_center_offset
		- _player.get_body_center_height()
	)
	_player.global_position = _bob_base_position
	_bob_elapsed = 0.0
	state = RecoveryState.BOBBING


func _on_fade_transition_completed(
	generation: int,
	faded_to_black: bool,
) -> void:
	if generation != _generation:
		return
	if faded_to_black and state == RecoveryState.FADING_OUT:
		_respawn_player()
		state = RecoveryState.FADING_IN
		_screen_fade.fade_from_black(_generation)
	elif not faded_to_black and state == RecoveryState.FADING_IN:
		_finish_recovery()


func _respawn_player() -> void:
	var target_transform: Transform3D = _initial_spawn_transform
	var nearest_distance: float = INF
	for point: SafeRespawnPoint in _safe_points:
		if point == null or not is_instance_valid(point) or not point.enabled:
			continue
		var distance: float = point.get_horizontal_distance_squared(
			_entry_position
		)
		if distance < nearest_distance:
			nearest_distance = distance
			target_transform = point.global_transform
	target_transform.origin.y += respawn_height_offset
	_player.global_transform = target_transform
	_player.velocity = Vector3.ZERO


func _finish_recovery() -> void:
	_player.set_water_recovery_active(false)
	_player.set_movement_enabled(_prior_movement_enabled)
	_player.set_camera_input_enabled(_prior_camera_input_enabled)
	_fishing_spot.end_water_recovery()
	state = RecoveryState.IDLE
	_bob_elapsed = 0.0
