class_name Player
extends CharacterBody3D

const FishInventoryType = preload("res://inventory/fish_inventory.gd")
const CollectionLogType = preload("res://collection/collection_log.gd")
const FishCatchType = preload("res://fish/fish_catch.gd")
const FishDataType = preload("res://fish/fish_data.gd")
const FishSaleServiceType = preload("res://economy/fish_sale_service.gd")
const PlayerWalletType = preload("res://economy/player_wallet.gd")
const PlayerBagType = preload("res://inventory/player_bag.gd")
const ItemDataType = preload("res://items/item_data.gd")
const PlayerHotbarType = preload("res://inventory/player_hotbar.gd")
const PlayerFishingUpgradesType = preload(
	"res://progression/player_fishing_upgrades.gd"
)
const PlayerItemEffectsType = preload(
	"res://progression/player_item_effects.gd"
)
const PlayerCoolerCapacityType = preload(
	"res://progression/player_cooler_capacity.gd"
)
const PlayerArtUnlocksType = preload(
	"res://progression/player_art_unlocks.gd"
)
const PlayerExperienceType = preload(
	"res://progression/player_experience.gd"
)
const ControllerMappingManagerType = preload(
	"res://settings/controller_mapping_manager.gd"
)
const FishingRodAttachmentScene = preload(
	"res://player/fishing_rod_attachment.tscn"
)
const HeldItemAttachmentScene = preload(
	"res://player/held_item_attachment.tscn"
)

const CHARACTER_IDLE_ANIMATION: StringName = &"idle"
const CHARACTER_IDLE_SHOW_ANIMATION: StringName = &"idle_show"
const CHARACTER_IDLE_SIT_ANIMATION: StringName = &"idle_sit"
const CHARACTER_IDLE_SIT_SHOW_ANIMATION: StringName = &"idle_sit_show"
const CHARACTER_WALKING_ANIMATION: StringName = &"walking"
const CHARACTER_WALKING_SHOW_ANIMATION: StringName = &"walking_show"
const BASE_REEL_SPEED: float = 0.16
# The target Android handheld exposes its physical right trigger through
# Godot's left-trigger axis. Keep the role named here so the platform mapping
# remains isolated from camera behavior.
const CONTROLLER_ZOOM_TRIGGER_AXIS: JoyAxis = JOY_AXIS_TRIGGER_LEFT

var appearance_snapshot: Dictionary = (
	CharacterCustomizationCatalog.default_snapshot()
)
var active_bait_id: StringName = StringName()
signal active_bait_changed(item_id: StringName)


func equip_bait(item: ItemDataType) -> bool:
	if item == null or not item.is_bait() or bag == null:
		return false
	if not bag.owns_item(item.item_id):
		return false
	active_bait_id = item.item_id
	active_bait_changed.emit(active_bait_id)
	return true


func unequip_bait() -> void:
	if active_bait_id.is_empty():
		return
	active_bait_id = StringName()
	active_bait_changed.emit(active_bait_id)


func apply_appearance_snapshot(snapshot: Dictionary) -> void:
	if CharacterCustomizationCatalog.validate_snapshot(snapshot):
		appearance_snapshot = snapshot.duplicate(true)
		PlayerVisualPresenter.apply_appearance(_visuals, appearance_snapshot)

class ShowcaseCameraSnapshot:
	extends RefCounted

	var yaw_transform: Transform3D
	var yaw_rotation: Vector3
	var pitch_rotation: Vector3
	var spring_length: float
	var target_zoom: float
	var camera_input_enabled: bool
	var camera_dragging: bool


@export_category("Movement")
@export var walk_speed: float = 2.25
@export var sprint_speed: float = 7.2
@export var sneak_speed: float = 1.8
@export var slow_walk_speed: float = 2.9
@export_range(0.1, 20.0, 0.1) var jump_velocity: float = 4.6
@export_range(0.1, 5.0, 0.05) var upward_gravity_multiplier: float = 1.35
@export_range(0.1, 5.0, 0.05) var fall_gravity_multiplier: float = 2.35
@export_range(0.1, 3.0, 0.05) var body_center_height: float = 0.9
@export var body_rotation_speed: float = 12.0

@export_category("Control")
@export var local_control_enabled: bool = true

@export_category("Fishing Stats")
@export_range(0.01, 2.0, 0.01) var reel_speed: float = BASE_REEL_SPEED
@export_range(1, 100, 1) var click_power: int = 1

@export_category("Showcase")
@export_range(0.05, 1.0, 0.01) var showcase_turn_duration: float = 0.28
@export_range(0.05, 1.0, 0.01) var showcase_restore_duration: float = 0.24
@export_range(0.05, 1.5, 0.01) var showcase_camera_transition_duration: float = 0.42
@export_range(-180.0, 180.0, 1.0) var showcase_camera_yaw_offset: float = 180.0
@export_range(-80.0, 80.0, 1.0) var showcase_camera_pitch: float = -8.0
@export_range(1.0, 10.0, 0.1) var showcase_camera_zoom_distance: float = 3.6
@export_range(0.5, 3.0, 0.05) var showcase_camera_target_height: float = 1.45
@export_range(0.01, 1.0, 0.01) var catch_presentation_base_scale: float = 0.10

@export_category("Camera")
@export var mouse_sensitivity: float = 0.005
@export var controller_camera_speed: float = 2.5
@export_range(0.0, 1.0, 0.01) var controller_camera_deadzone: float = 0.2
@export var invert_camera_y: bool = false
@export_range(-89.0, 0.0, 0.5) var minimum_pitch_degrees: float = -65.0
@export_range(0.0, 89.0, 0.5) var maximum_pitch_degrees: float = 45.0
@export var minimum_zoom: float = 2.0
@export var maximum_zoom: float = 8.0
@export var zoom_step: float = 0.75
@export var zoom_smoothing: float = 12.0
@export_range(0.1, 12.0, 0.1) var controller_zoom_speed: float = 4.0
@export_range(0.0, 1.0, 0.01) var controller_trigger_threshold: float = 0.55

@onready var _visuals: Node3D = %Visuals
@onready var _character_rig: Node3D = get_node_or_null(
	"Visuals/CharacterRig/CharacterRig"
) as Node3D
@onready var _character_animation_player: AnimationPlayer = (
	get_node_or_null("Visuals/CharacterRig/AnimationPlayer") as AnimationPlayer
)
@onready var _camera_yaw: Node3D = %CameraYaw
@onready var _camera_pitch: Node3D = %CameraPitch
@onready var _spring_arm: SpringArm3D = %SpringArm3D
@onready var _camera: Camera3D = %Camera3D
@onready var inventory: FishInventoryType = %Inventory
@onready var collection_log: CollectionLogType = %CollectionLog
@onready var wallet: PlayerWalletType = %Wallet
@onready var fish_sale_service: FishSaleServiceType = %FishSaleService
@onready var bag: PlayerBagType = %Bag
@onready var hotbar: PlayerHotbarType = %Hotbar
@onready var fishing_upgrades: PlayerFishingUpgradesType = %FishingUpgrades
@onready var item_effects: PlayerItemEffectsType = %ItemEffects
@onready var cooler_capacity: PlayerCoolerCapacityType = %CoolerCapacity
@onready var art_unlocks: PlayerArtUnlocksType = %ArtUnlocks
@onready var experience: PlayerExperienceType = %Experience
@onready var _cast_origin: Marker3D = %CastOrigin
var _catch_display: Node3D
var _catch_sprite: Sprite3D
var _held_item_attachment: BoneAttachment3D
var _held_fish_display: Node3D
var _held_fish_attachment_offset: Vector3 = Vector3(0.0, 0.08, 0.04)
var _held_fish_sprite: Sprite3D
var _held_art_kit_sprite: Sprite3D
var _catch_attachment_offset: Vector3 = Vector3(0.0, 0.08, 0.04)

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _camera_dragging: bool = false
var _camera_input_enabled: bool = true
var _movement_enabled: bool = true
var _water_recovery_active: bool = false
var _remote_recovery_presentation_active: bool = false
var _remote_recovery_visual_origin: Vector3
var _remote_recovery_elapsed: float = 0.0
var _target_zoom: float = 5.0
var _showcase_rod_visibility: bool = true
var _remote_presentation_visible := true
var _showcase_rod_state_stored: bool = false
var _showcase_visual_rotation: Vector3
var _showcase_visual_rotation_stored: bool = false
var _showcase_turn_tween: Tween
var _showcase_restore_tween: Tween
var _showcase_camera_tween: Tween
var _showcase_camera_snapshot: ShowcaseCameraSnapshot
var _showcase_restore_generation: int = 0
var _network_peer_id: int = 0
var _network_authoritative_simulation: bool = false
var _network_interpolation_enabled: bool = false
var _network_axis: Vector2 = Vector2.ZERO
var _network_camera_yaw: float = 0.0
var _network_jump_pending: bool = false
var _network_sprint: bool = false
var _network_sneak: bool = false
var _network_slow_walk: bool = false
var _last_network_input_sequence: int = 0
var _network_target_position: Vector3
var _network_target_velocity: Vector3
var _network_target_visual_yaw: float = 0.0
var _network_snapshot_ready: bool = false
var _character_animation_name: StringName = &""
var _sitting: bool = false
var _held_fish_visible: bool = false
var _showcase_animation_active: bool = false
var _fishing_rod: Node3D
var _fishing_rod_tip: Marker3D
var _controller_mapping_manager: ControllerMappingManagerType


func _ready() -> void:
	PlayerVisualPresenter.apply_appearance(_visuals, appearance_snapshot)
	_initialize_fishing_rod()
	_target_zoom = clampf(_spring_arm.spring_length, minimum_zoom, maximum_zoom)
	_spring_arm.spring_length = _target_zoom
	_camera.current = local_control_enabled
	_initialize_held_item_attachment()


func set_controller_mapping_manager(
	mapping_manager: ControllerMappingManagerType,
) -> void:
	_controller_mapping_manager = mapping_manager


func _initialize_fishing_rod() -> void:
	var skeleton := get_node_or_null(
		"Visuals/CharacterRig/CharacterRig/Skeleton3D"
	) as Skeleton3D
	if skeleton == null:
		push_error("Player character skeleton is unavailable.")
		return
	var attachment := FishingRodAttachmentScene.instantiate() as BoneAttachment3D
	if attachment == null:
		push_error("Fishing rod attachment could not be instantiated.")
		return
	skeleton.add_child(attachment)
	_fishing_rod = attachment.get_node("FishingRod") as Node3D
	_fishing_rod_tip = attachment.get_node(
		"FishingRod/FishingRodTip"
	) as Marker3D


func _initialize_held_item_attachment() -> void:
	var skeleton := get_node_or_null(
		"Visuals/CharacterRig/CharacterRig/Skeleton3D"
	) as Skeleton3D
	if skeleton == null:
		push_error("Player character skeleton is unavailable for held items.")
		return
	var attachment := HeldItemAttachmentScene.instantiate() as BoneAttachment3D
	if attachment == null:
		push_error("Held item attachment could not be instantiated.")
		return
	skeleton.add_child(attachment)
	_held_item_attachment = attachment
	_held_fish_display = attachment.get_node("HeldFishDisplay") as Node3D
	_held_fish_attachment_offset = _held_fish_display.position
	_held_fish_sprite = attachment.get_node(
		"HeldFishDisplay/HeldFishSprite"
	) as Sprite3D
	_held_art_kit_sprite = attachment.get_node(
		"HeldArtKitDisplay/HeldArtKitSprite"
	) as Sprite3D
	_catch_display = attachment.get_node("CatchDisplay") as Node3D
	_catch_attachment_offset = _catch_display.position
	_catch_sprite = attachment.get_node("CatchDisplay/CatchSprite") as Sprite3D


func _physics_process(delta: float) -> void:
	if _network_interpolation_enabled:
		_update_network_interpolation(delta)
		return
	var jump_requested: bool = (
		_movement_enabled
		and (
			(local_control_enabled and Input.is_action_just_pressed("jump"))
			or (_network_authoritative_simulation and _network_jump_pending)
		)
	)
	if _sitting:
		if jump_requested:
			_set_sitting(false)
		else:
			velocity = Vector3.ZERO
			_network_jump_pending = false
			return
	if _water_recovery_active:
		velocity = Vector3.ZERO
		_network_jump_pending = false
		return

	if not is_on_floor():
		var gravity_multiplier: float = (
			upward_gravity_multiplier
			if velocity.y > 0.0
			else fall_gravity_multiplier
		)
		velocity.y -= _gravity * gravity_multiplier * delta
	elif jump_requested:
		velocity.y = jump_velocity
	_network_jump_pending = false

	if not _movement_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var input_vector: Vector2
	var camera_basis: Basis
	if local_control_enabled:
		input_vector = Input.get_vector(
			"move_left",
			"move_right",
			"move_forward",
			"move_backward"
		)
		camera_basis = _camera_yaw.global_basis
	elif _network_authoritative_simulation:
		input_vector = _network_axis
		camera_basis = Basis(Vector3.UP, _network_camera_yaw)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var move_direction: Vector3 = camera_basis.x * input_vector.x + camera_basis.z * input_vector.y
	move_direction.y = 0.0
	var input_strength: float = minf(input_vector.length(), 1.0)
	move_direction = move_direction.normalized()

	var speed: float = _get_network_aware_speed()
	if item_effects != null:
		speed *= item_effects.get_movement_multiplier()
	velocity.x = move_direction.x * speed * input_strength
	velocity.z = move_direction.z * speed * input_strength

	if not move_direction.is_zero_approx():
		var target_rotation: float = atan2(-move_direction.x, -move_direction.z)
		_visuals.rotation.y = lerp_angle(
			_visuals.rotation.y,
			target_rotation,
			1.0 - exp(-body_rotation_speed * delta)
		)

	move_and_slide()


func _process(delta: float) -> void:
	_update_character_animation()
	# The hand bone supplies the attachment position, but its animated wrist
	# rotation should not turn the flat fish/catch artwork edge-on. Keep each
	# display aligned with the character's facing while it follows the hand.
	if _character_rig != null and _held_item_attachment != null:
		var facing_rotation: Vector3 = _character_rig.global_rotation
		for display: Node3D in [_held_fish_display, _catch_display]:
			if display != null:
				var attachment_offset: Vector3 = (
					_held_fish_attachment_offset
					if display == _held_fish_display
					else _catch_attachment_offset
				)
				display.global_position = (
					_held_item_attachment.global_transform * attachment_offset
				)
				display.global_rotation = facing_rotation
	if _remote_recovery_presentation_active:
		_remote_recovery_elapsed += delta
		_visuals.position = (
			_remote_recovery_visual_origin
			+ Vector3.UP
			* sin(_remote_recovery_elapsed * 2.0 * TAU)
			* 0.08
		)
	if not local_control_enabled:
		return

	if (
		_camera_input_enabled
		and _camera_dragging
		and not Input.is_action_pressed("camera_drag")
	):
		_camera_dragging = false

	if _camera_input_enabled:
		var stick: Vector2 = _get_controller_camera_stick()
		if stick.length() > controller_camera_deadzone:
			if (
				_get_controller_zoom_strength()
				>= controller_trigger_threshold
			):
				var vertical_zoom_input: float = _apply_axis_deadzone(stick.y)
				_set_target_zoom(
					_target_zoom
					+ vertical_zoom_input * controller_zoom_speed * delta
				)
			else:
				var adjusted_strength: float = (
					(stick.length() - controller_camera_deadzone)
					/ (1.0 - controller_camera_deadzone)
				)
				_rotate_camera(
					stick.normalized()
						* adjusted_strength
						* controller_camera_speed
						* delta
				)

		var zoom_weight: float = 1.0 - exp(-zoom_smoothing * delta)
		_spring_arm.spring_length = lerpf(
			_spring_arm.spring_length,
			_target_zoom,
			zoom_weight
		)


func _get_controller_camera_stick() -> Vector2:
	if _controller_mapping_manager != null:
		return Vector2(
			_controller_mapping_manager.get_role_axis(
				ControllerMappingManagerType.ROLE_RIGHT_STICK_X
			),
			_controller_mapping_manager.get_role_axis(
				ControllerMappingManagerType.ROLE_RIGHT_STICK_Y
			),
		)
	return Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y),
	)


func _get_controller_zoom_strength() -> float:
	if _controller_mapping_manager != null:
		return _controller_mapping_manager.get_role_strength(
			ControllerMappingManagerType.ROLE_CAMERA_ZOOM
		)
	return Input.get_joy_axis(0, CONTROLLER_ZOOM_TRIGGER_AXIS)


func _update_character_animation() -> void:
	if _character_animation_player == null:
		return
	var horizontal_speed_squared: float = (
		velocity.x * velocity.x + velocity.z * velocity.z
	)
	var is_walking: bool = horizontal_speed_squared > 0.0025
	var requested_animation: Array[StringName] = []
	if _showcase_animation_active:
		if _sitting:
			requested_animation = [
				CHARACTER_IDLE_SIT_SHOW_ANIMATION,
				&"idle_sit_show_loop",
				CHARACTER_IDLE_SIT_ANIMATION,
				&"idle_sit_loop",
				&"idle_loop_sit",
			]
		else:
			requested_animation = [
				CHARACTER_IDLE_SHOW_ANIMATION,
				&"idle_show_loop",
				&"show",
				&"show_loop",
			]
	elif _sitting:
		if _held_fish_visible:
			requested_animation = [
				CHARACTER_IDLE_SIT_SHOW_ANIMATION,
				&"idle_sit_show_loop",
				CHARACTER_IDLE_SIT_ANIMATION,
				&"idle_sit_loop",
				&"idle_loop_sit",
			]
		else:
			requested_animation = [
				CHARACTER_IDLE_SIT_ANIMATION,
				&"idle_sit_loop",
				&"sitting",
				&"idle_loop_sit",
			]
	elif is_walking and _held_fish_visible:
		requested_animation = [
			CHARACTER_WALKING_SHOW_ANIMATION,
			&"walking_show_loop",
		]
	elif _held_fish_visible:
		requested_animation = [
			CHARACTER_IDLE_SHOW_ANIMATION,
			&"idle_show_loop",
			&"show",
			&"show_loop",
		]
	elif is_walking:
		requested_animation = [
			CHARACTER_WALKING_ANIMATION,
			&"walking_loop",
		]
	else:
		requested_animation = [CHARACTER_IDLE_ANIMATION, &"idle_loop"]
	var next_animation: StringName = &""
	for candidate: StringName in requested_animation:
		if _character_animation_player.has_animation(candidate):
			next_animation = candidate
			break
	if next_animation.is_empty():
		return
	if _character_animation_name == next_animation:
		return
	_character_animation_player.play(next_animation)
	_character_animation_name = next_animation


func toggle_sitting() -> void:
	var should_sit: bool = not _sitting
	if should_sit:
		if (
			_character_animation_player == null
			or not _has_any_character_animation([
				CHARACTER_IDLE_SIT_ANIMATION,
				&"idle_sit_loop",
				&"sitting",
				&"idle_loop_sit",
			])
		):
			return
	_set_sitting(should_sit)


func _has_any_character_animation(candidates: Array[StringName]) -> bool:
	if _character_animation_player == null:
		return false
	for candidate: StringName in candidates:
		if _character_animation_player.has_animation(candidate):
			return true
	return false


func _set_sitting(should_sit: bool) -> void:
	if _sitting == should_sit:
		return
	_sitting = should_sit
	if _sitting:
		velocity = Vector3.ZERO
	_character_animation_name = &""
	_update_character_animation()


func is_sitting() -> bool:
	return _sitting


func _unhandled_input(event: InputEvent) -> void:
	if not local_control_enabled or not _camera_input_enabled:
		return

	if event.is_action("camera_drag"):
		_camera_dragging = event.is_pressed()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _camera_dragging:
		_rotate_camera(event.relative * mouse_sensitivity)
		get_viewport().set_input_as_handled()
		return

	var mouse_zoom_in: bool = (
		event is InputEventMouseButton
		and event.shift_pressed
		and event.is_action_pressed("camera_zoom_in")
	)
	var controller_zoom_in: bool = (
		event is InputEventJoypadButton
		and event.is_action_pressed("camera_zoom_in")
	)
	var mouse_zoom_out: bool = (
		event is InputEventMouseButton
		and event.shift_pressed
		and event.is_action_pressed("camera_zoom_out")
	)
	var controller_zoom_out: bool = (
		event is InputEventJoypadButton
		and event.is_action_pressed("camera_zoom_out")
	)
	if mouse_zoom_in or controller_zoom_in:
		_set_target_zoom(_target_zoom - zoom_step)
		get_viewport().set_input_as_handled()
	elif mouse_zoom_out or controller_zoom_out:
		_set_target_zoom(_target_zoom + zoom_step)
		get_viewport().set_input_as_handled()


func _get_current_speed() -> float:
	if Input.is_action_pressed("sneak"):
		return sneak_speed
	if Input.is_action_pressed("slow_walk"):
		return slow_walk_speed
	if Input.is_action_pressed("sprint"):
		return sprint_speed
	return walk_speed


func _get_network_aware_speed() -> float:
	if local_control_enabled:
		return _get_current_speed()
	if _network_sneak:
		return sneak_speed
	if _network_slow_walk:
		return slow_walk_speed
	if _network_sprint:
		return sprint_speed
	return walk_speed


func _rotate_camera(delta_rotation: Vector2) -> void:
	_camera_yaw.rotation.y -= delta_rotation.x
	var vertical_direction: float = -1.0 if invert_camera_y else 1.0
	_camera_pitch.rotation.x = clampf(
		_camera_pitch.rotation.x - delta_rotation.y * vertical_direction,
		deg_to_rad(minimum_pitch_degrees),
		deg_to_rad(maximum_pitch_degrees)
	)


func _set_target_zoom(value: float) -> void:
	_target_zoom = clampf(value, minimum_zoom, maximum_zoom)


func _apply_axis_deadzone(value: float) -> float:
	var magnitude: float = absf(value)
	if magnitude <= controller_camera_deadzone:
		return 0.0
	return (
		signf(value)
		* (magnitude - controller_camera_deadzone)
		/ (1.0 - controller_camera_deadzone)
	)


func set_local_control(enabled: bool) -> void:
	local_control_enabled = enabled
	if is_node_ready():
		_camera.current = enabled
	if not enabled:
		_camera_dragging = false


func set_network_peer_id(peer_id: int) -> void:
	_network_peer_id = peer_id


func get_network_peer_id() -> int:
	return _network_peer_id


func configure_network_remote(authoritative_simulation: bool) -> void:
	set_local_control(false)
	_network_authoritative_simulation = authoritative_simulation
	_network_interpolation_enabled = not authoritative_simulation
	_network_snapshot_ready = false
	_camera.current = false


func capture_network_input(sequence: int) -> Dictionary:
	if not _movement_enabled or _water_recovery_active:
		return {
			"sequence": sequence,
			"axis": [0.0, 0.0],
			"camera_yaw": _camera_yaw.global_rotation.y,
			"jump": false,
			"sprint": false,
			"sneak": false,
			"slow_walk": false,
			"sitting": _sitting,
		}
	var axis: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)
	return {
		"sequence": sequence,
		"axis": [axis.x, axis.y],
		"camera_yaw": _camera_yaw.global_rotation.y,
		"jump": Input.is_action_just_pressed("jump"),
		"sprint": Input.is_action_pressed("sprint"),
		"sneak": Input.is_action_pressed("sneak"),
		"slow_walk": Input.is_action_pressed("slow_walk"),
		"sitting": _sitting,
	}


func apply_authoritative_network_input(data: Dictionary) -> void:
	var sequence: int = int(data.get("sequence", 0))
	if sequence <= _last_network_input_sequence:
		return
	var axis: Array = data.get("axis", [])
	if axis.size() != 2:
		return
	_last_network_input_sequence = sequence
	_network_axis = Vector2(float(axis[0]), float(axis[1])).limit_length(1.0)
	_network_camera_yaw = float(data.get("camera_yaw", 0.0))
	_network_jump_pending = bool(data.get("jump", false))
	_network_sprint = bool(data.get("sprint", false))
	_network_sneak = bool(data.get("sneak", false))
	_network_slow_walk = bool(data.get("slow_walk", false))
	_set_sitting(bool(data.get("sitting", false)))


func make_network_snapshot(peer_id: int) -> Dictionary:
	return {
		"peer_id": peer_id,
		"acknowledged_input": _last_network_input_sequence,
		"position": [global_position.x, global_position.y, global_position.z],
		"velocity": [velocity.x, velocity.y, velocity.z],
		"visual_yaw": _visuals.rotation.y,
		"grounded": is_on_floor(),
		"sitting": _sitting,
	}


func push_network_snapshot(snapshot: Dictionary) -> void:
	var parsed: Dictionary = _parse_network_snapshot(snapshot)
	if parsed.is_empty():
		return
	_network_target_position = parsed["position"]
	_network_target_velocity = parsed["velocity"]
	_network_target_visual_yaw = parsed["visual_yaw"]
	_set_sitting(bool(parsed["sitting"]))
	if not _network_snapshot_ready:
		global_position = _network_target_position
		velocity = _network_target_velocity
		_visuals.rotation.y = _network_target_visual_yaw
	_network_snapshot_ready = true


func apply_local_prediction_correction(snapshot: Dictionary) -> void:
	var parsed: Dictionary = _parse_network_snapshot(snapshot)
	if parsed.is_empty():
		return
	_set_sitting(bool(parsed["sitting"]))
	var authoritative_position: Vector3 = parsed["position"]
	var error_distance: float = global_position.distance_to(
		authoritative_position
	)
	if error_distance > 2.0:
		global_position = authoritative_position
	elif error_distance > 0.05:
		global_position = global_position.lerp(authoritative_position, 0.18)


func apply_network_teleport(snapshot: Dictionary) -> void:
	var parsed: Dictionary = _parse_network_snapshot(snapshot)
	if parsed.is_empty():
		return
	global_position = parsed["position"]
	velocity = parsed["velocity"]
	_visuals.rotation.y = parsed["visual_yaw"]
	_set_sitting(bool(parsed["sitting"]))
	_network_target_position = global_position
	_network_target_velocity = velocity
	_network_target_visual_yaw = _visuals.rotation.y
	_network_snapshot_ready = true


func _parse_network_snapshot(snapshot: Dictionary) -> Dictionary:
	var snapshot_position: Variant = snapshot.get("position")
	var network_velocity: Variant = snapshot.get("velocity")
	if (
		typeof(snapshot_position) != TYPE_ARRAY
		or typeof(network_velocity) != TYPE_ARRAY
		or snapshot_position.size() != 3
		or network_velocity.size() != 3
	):
		return {}
	var parsed_position := Vector3(
		float(snapshot_position[0]),
		float(snapshot_position[1]),
		float(snapshot_position[2])
	)
	var parsed_velocity := Vector3(
		float(network_velocity[0]),
		float(network_velocity[1]),
		float(network_velocity[2])
	)
	var visual_yaw: float = float(snapshot.get("visual_yaw", 0.0))
	if snapshot.has("sitting") and typeof(snapshot.get("sitting")) != TYPE_BOOL:
		return {}
	var sitting: bool = bool(snapshot.get("sitting", false))
	if (
		not parsed_position.is_finite()
		or not parsed_velocity.is_finite()
		or not is_finite(visual_yaw)
	):
		return {}
	return {
		"position": parsed_position,
		"velocity": parsed_velocity,
		"visual_yaw": visual_yaw,
		"sitting": sitting,
	}


func _update_network_interpolation(delta: float) -> void:
	if not _network_snapshot_ready:
		return
	var position_weight: float = 1.0 - exp(-12.0 * delta)
	global_position = global_position.lerp(
		_network_target_position,
		position_weight
	)
	velocity = _network_target_velocity
	_visuals.rotation.y = lerp_angle(
		_visuals.rotation.y,
		_network_target_visual_yaw,
		1.0 - exp(-14.0 * delta)
	)


func is_local_control_enabled() -> bool:
	return local_control_enabled


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled
	if not enabled:
		velocity.x = 0.0
		velocity.z = 0.0


func is_movement_enabled() -> bool:
	return _movement_enabled


func set_camera_input_enabled(enabled: bool) -> void:
	_camera_input_enabled = enabled
	if not enabled:
		_camera_dragging = false


func set_camera_active(active: bool) -> void:
	_camera.current = active


func apply_camera_settings(
	new_mouse_sensitivity: float,
	new_controller_sensitivity: float,
	invert_vertical: bool,
) -> void:
	mouse_sensitivity = clampf(new_mouse_sensitivity, 0.001, 0.012)
	controller_camera_speed = clampf(
		new_controller_sensitivity,
		0.5,
		5.0
	)
	invert_camera_y = invert_vertical


func is_camera_input_enabled() -> bool:
	return _camera_input_enabled


func set_water_recovery_active(active: bool) -> void:
	_water_recovery_active = active
	velocity = Vector3.ZERO


func is_water_recovery_active() -> bool:
	return _water_recovery_active


func set_remote_recovery_presentation(active: bool) -> void:
	if local_control_enabled or active == _remote_recovery_presentation_active:
		return
	_remote_recovery_presentation_active = active
	_remote_recovery_elapsed = 0.0
	if active:
		_remote_recovery_visual_origin = _visuals.position
	else:
		_visuals.position = _remote_recovery_visual_origin


func prepare_for_water_recovery() -> void:
	_restore_gameplay_presentation_for_recovery()


func restore_gameplay_orientation_after_recovery() -> void:
	_restore_gameplay_presentation_for_recovery()


func _restore_gameplay_presentation_for_recovery() -> void:
	# Recovery owns presentation teardown. Ending immediately kills every
	# showcase tween, invalidates its callbacks, and restores the gameplay yaw.
	end_catch_showcase(Callable(), true)
	var gameplay_rotation: Vector3 = _visuals.rotation
	gameplay_rotation.x = 0.0
	gameplay_rotation.z = 0.0
	_visuals.rotation = gameplay_rotation


func get_body_center_position() -> Vector3:
	return global_position + Vector3.UP * body_center_height


func get_chat_anchor_position() -> Vector3:
	var highest_y := -INF
	for node: Node in _visuals.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or not mesh_instance.is_visible_in_tree():
			continue
		var bounds := mesh_instance.get_aabb()
		for endpoint_index: int in range(8):
			var world_point := (
				mesh_instance.global_transform * bounds.get_endpoint(endpoint_index)
			)
			highest_y = maxf(highest_y, world_point.y)
	if not is_finite(highest_y):
		highest_y = get_body_center_position().y + body_center_height
	return Vector3(global_position.x, highest_y + 0.22, global_position.z)


func get_body_center_height() -> float:
	return body_center_height


func get_gameplay_camera() -> Camera3D:
	return _camera


func set_remote_presentation_visible(value: bool) -> void:
	if local_control_enabled:
		return
	_remote_presentation_visible = value
	_visuals.visible = value


func is_remote_presentation_visible() -> bool:
	return _remote_presentation_visible


func get_fishing_rod_tip() -> Marker3D:
	return _fishing_rod_tip


func get_fishing_rod() -> Node3D:
	return _fishing_rod


func set_active_item_is_rod(active_is_rod: bool) -> void:
	if _showcase_rod_state_stored:
		_showcase_rod_visibility = active_is_rod
	else:
		_fishing_rod.visible = active_is_rod


func set_active_art_kit(icon: Texture2D, should_show: bool) -> void:
	_held_art_kit_sprite.texture = icon if should_show else null
	_held_art_kit_sprite.visible = should_show and icon != null


func set_held_fish(
	fish: FishDataType,
	display_scale: float,
	should_show: bool,
) -> void:
	if not should_show or fish == null or fish.display_texture == null:
		_held_fish_visible = false
		_held_fish_display.visible = false
		_held_fish_display.scale = Vector3.ONE
		_held_fish_sprite.texture = null
		_update_character_animation()
		return
	_held_fish_visible = true
	_held_fish_sprite.texture = fish.display_texture
	_held_fish_display.scale = (
		Vector3.ONE
		* maxf(display_scale, 0.01)
		* catch_presentation_base_scale
	)
	_held_fish_display.visible = true
	_update_character_animation()


func get_cast_origin_position() -> Vector3:
	return _cast_origin.global_position


func begin_catch_showcase(fish_catch: FishCatchType) -> void:
	if fish_catch == null or not fish_catch.is_valid():
		return
	_showcase_animation_active = true
	_update_character_animation()
	_kill_showcase_camera_tween()
	_kill_showcase_restore_tween()
	_capture_showcase_camera_snapshot()
	if not _showcase_visual_rotation_stored:
		_showcase_visual_rotation = _visuals.rotation
		_showcase_visual_rotation_stored = true
	var showcase_camera_position: Vector3 = _begin_showcase_camera_transition()
	_turn_showcase_toward_position(showcase_camera_position)
	if not _showcase_rod_state_stored:
		_showcase_rod_visibility = _fishing_rod.visible
		_showcase_rod_state_stored = true
	_fishing_rod.visible = false
	_catch_sprite.texture = fish_catch.fish.display_texture
	_catch_display.scale = (
		Vector3.ONE
		* fish_catch.display_scale
		* catch_presentation_base_scale
	)
	_catch_display.visible = _catch_sprite.texture != null


func begin_remote_catch_showcase(fish_catch: FishCatchType) -> void:
	if local_control_enabled or fish_catch == null or not fish_catch.is_valid():
		return
	end_catch_showcase(Callable(), true)
	_showcase_animation_active = true
	_update_character_animation()
	_showcase_rod_visibility = _fishing_rod.visible
	_showcase_rod_state_stored = true
	_fishing_rod.visible = false
	_catch_sprite.texture = fish_catch.fish.display_texture
	_catch_display.scale = (
		Vector3.ONE
		* fish_catch.display_scale
		* catch_presentation_base_scale
	)
	_catch_display.visible = _catch_sprite.texture != null


func end_catch_showcase(
	restored_callback: Callable = Callable(),
	immediate: bool = false,
) -> void:
	_showcase_animation_active = false
	_update_character_animation()
	_kill_showcase_turn_tween()
	_kill_showcase_camera_tween()
	_kill_showcase_restore_tween()
	_catch_display.visible = false
	_catch_display.scale = Vector3.ONE
	_catch_sprite.texture = null
	if _showcase_rod_state_stored:
		_fishing_rod.visible = _showcase_rod_visibility
	_showcase_rod_visibility = true
	_showcase_rod_state_stored = false
	if (
		not _showcase_visual_rotation_stored
		and _showcase_camera_snapshot == null
	):
		if restored_callback.is_valid():
			restored_callback.call()
		return
	if immediate:
		_complete_showcase_restore(restored_callback)
		return

	var current_rotation: Vector3 = _visuals.rotation
	var restore_target: Vector3 = _showcase_visual_rotation
	restore_target.y = (
		current_rotation.y
		+ wrapf(
			_showcase_visual_rotation.y - current_rotation.y,
			-PI,
			PI
		)
	)
	var restore_generation: int = _showcase_restore_generation
	_showcase_restore_tween = create_tween()
	_showcase_restore_tween.set_parallel(true)
	_showcase_restore_tween.set_trans(Tween.TRANS_QUAD)
	_showcase_restore_tween.set_ease(Tween.EASE_IN_OUT)
	if _showcase_visual_rotation_stored:
		_showcase_restore_tween.tween_property(
			_visuals,
			"rotation",
			restore_target,
			maxf(showcase_restore_duration, 0.05)
		)
	if _showcase_camera_snapshot != null:
		var camera_yaw_target: Vector3 = (
			_showcase_camera_snapshot.yaw_rotation
		)
		camera_yaw_target.y = (
			_camera_yaw.rotation.y
			+ wrapf(
				camera_yaw_target.y - _camera_yaw.rotation.y,
				-PI,
				PI
			)
		)
		var camera_duration: float = maxf(
			showcase_camera_transition_duration,
			0.05
		)
		_showcase_restore_tween.tween_property(
			_camera_yaw,
			"rotation",
			camera_yaw_target,
			camera_duration
		)
		_showcase_restore_tween.tween_property(
			_camera_yaw,
			"position",
			_showcase_camera_snapshot.yaw_transform.origin,
			camera_duration
		)
		_showcase_restore_tween.tween_property(
			_camera_pitch,
			"rotation",
			_showcase_camera_snapshot.pitch_rotation,
			camera_duration
		)
		_showcase_restore_tween.tween_property(
			_spring_arm,
			"spring_length",
			_showcase_camera_snapshot.spring_length,
			camera_duration
		)
	_showcase_restore_tween.finished.connect(
		_on_showcase_restore_finished.bind(
			restore_generation,
			restored_callback
		)
	)


func _turn_showcase_toward_position(target_position: Vector3) -> void:
	_kill_showcase_turn_tween()
	var camera_direction: Vector3 = (
		target_position - _visuals.global_position
	)
	camera_direction.y = 0.0
	if camera_direction.is_zero_approx():
		return
	camera_direction = camera_direction.normalized()
	var target_world_yaw: float = atan2(
		-camera_direction.x,
		-camera_direction.z
	)
	var target_local_yaw: float = target_world_yaw - global_rotation.y
	var current_yaw: float = _visuals.rotation.y
	var shortest_target_yaw: float = (
		current_yaw
		+ wrapf(target_local_yaw - current_yaw, -PI, PI)
	)
	_showcase_turn_tween = create_tween()
	_showcase_turn_tween.set_trans(Tween.TRANS_QUAD)
	_showcase_turn_tween.set_ease(Tween.EASE_IN_OUT)
	_showcase_turn_tween.tween_property(
		_visuals,
		"rotation:y",
		shortest_target_yaw,
		maxf(showcase_turn_duration, 0.05)
	)
	_showcase_turn_tween.finished.connect(_on_showcase_turn_finished)


func _kill_showcase_turn_tween() -> void:
	if _showcase_turn_tween != null and _showcase_turn_tween.is_valid():
		_showcase_turn_tween.kill()
	_showcase_turn_tween = null


func _kill_showcase_restore_tween() -> void:
	if _showcase_restore_tween != null and _showcase_restore_tween.is_valid():
		_showcase_restore_tween.kill()
	_showcase_restore_tween = null
	_showcase_restore_generation += 1


func _kill_showcase_camera_tween() -> void:
	if _showcase_camera_tween != null and _showcase_camera_tween.is_valid():
		_showcase_camera_tween.kill()
	_showcase_camera_tween = null


func _on_showcase_turn_finished() -> void:
	_showcase_turn_tween = null


func _on_showcase_restore_finished(
	restore_generation: int,
	restored_callback: Callable,
) -> void:
	if restore_generation != _showcase_restore_generation:
		return
	_showcase_restore_tween = null
	_complete_showcase_restore(restored_callback)


func _complete_showcase_restore(
	restored_callback: Callable,
) -> void:
	if _showcase_visual_rotation_stored:
		_visuals.rotation = _showcase_visual_rotation
	_showcase_visual_rotation = Vector3.ZERO
	_showcase_visual_rotation_stored = false
	if _showcase_camera_snapshot != null:
		_camera_yaw.transform = _showcase_camera_snapshot.yaw_transform
		_camera_pitch.rotation = _showcase_camera_snapshot.pitch_rotation
		_spring_arm.spring_length = _showcase_camera_snapshot.spring_length
		_target_zoom = _showcase_camera_snapshot.target_zoom
		_camera_input_enabled = (
			_showcase_camera_snapshot.camera_input_enabled
		)
		_camera_dragging = _showcase_camera_snapshot.camera_dragging
	_showcase_camera_snapshot = null
	if restored_callback.is_valid():
		restored_callback.call()


func _capture_showcase_camera_snapshot() -> void:
	if _showcase_camera_snapshot != null:
		return
	_showcase_camera_snapshot = ShowcaseCameraSnapshot.new()
	_showcase_camera_snapshot.yaw_transform = _camera_yaw.transform
	_showcase_camera_snapshot.yaw_rotation = _camera_yaw.rotation
	_showcase_camera_snapshot.pitch_rotation = _camera_pitch.rotation
	_showcase_camera_snapshot.spring_length = _spring_arm.spring_length
	_showcase_camera_snapshot.target_zoom = _target_zoom
	_showcase_camera_snapshot.camera_input_enabled = _camera_input_enabled
	_showcase_camera_snapshot.camera_dragging = _camera_dragging
	_camera_input_enabled = false
	_camera_dragging = false


func _begin_showcase_camera_transition() -> Vector3:
	var target_world_yaw: float = (
		_visuals.global_rotation.y
		+ deg_to_rad(showcase_camera_yaw_offset)
	)
	var target_local_yaw: float = target_world_yaw - global_rotation.y
	var shortest_target_yaw: float = (
		_camera_yaw.rotation.y
		+ wrapf(
			target_local_yaw - _camera_yaw.rotation.y,
			-PI,
			PI
		)
	)
	var target_pitch: float = deg_to_rad(showcase_camera_pitch)
	var target_position: Vector3 = _camera_yaw.position
	target_position.y = showcase_camera_target_height
	var target_zoom: float = maxf(showcase_camera_zoom_distance, 0.1)
	var camera_duration: float = maxf(
		showcase_camera_transition_duration,
		0.05
	)
	_showcase_camera_tween = create_tween()
	_showcase_camera_tween.set_parallel(true)
	_showcase_camera_tween.set_trans(Tween.TRANS_QUAD)
	_showcase_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_showcase_camera_tween.tween_property(
		_camera_yaw,
		"rotation:y",
		shortest_target_yaw,
		camera_duration
	)
	_showcase_camera_tween.tween_property(
		_camera_yaw,
		"position:y",
		target_position.y,
		camera_duration
	)
	_showcase_camera_tween.tween_property(
		_camera_pitch,
		"rotation:x",
		target_pitch,
		camera_duration
	)
	_showcase_camera_tween.tween_property(
		_spring_arm,
		"spring_length",
		target_zoom,
		camera_duration
	)

	var horizontal_offset: Vector3 = (
		Basis(Vector3.UP, target_world_yaw).z * target_zoom
	)
	return global_position + target_position + horizontal_offset


func get_facing_direction() -> Vector3:
	var facing: Vector3 = -_visuals.global_basis.z
	facing.y = 0.0
	if facing.is_zero_approx():
		facing = -global_basis.z
		facing.y = 0.0
	if facing.is_zero_approx():
		return Vector3.FORWARD
	return facing.normalized()
