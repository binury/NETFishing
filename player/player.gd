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
const NetAttachmentScene = preload("res://player/net_attachment.tscn")
const FishingRodDataType = preload("res://items/fishing_rod_data.gd")
const HeldItemAttachmentScene = preload(
	"res://player/held_item_attachment.tscn"
)
const SprintDustTrailType = preload("res://player/sprint_dust_trail.gd")
const VoiceProfilesType = preload(
	"res://player/animalese_voice_profiles.gd"
)

signal retract_visual_finished

const CHARACTER_IDLE_ANIMATION: StringName = &"idle"
const CHARACTER_IDLE_SHOW_ANIMATION: StringName = &"idle_show"
const CHARACTER_IDLE_SIT_ANIMATION: StringName = &"idle_sit"
const CHARACTER_IDLE_SIT_SHOW_ANIMATION: StringName = &"idle_sit_show"
const CHARACTER_WALKING_ANIMATION: StringName = &"walking"
const CHARACTER_WALKING_SHOW_ANIMATION: StringName = &"walking_show"
const CHARACTER_RUNNING_ANIMATION: StringName = &"running"
const CHARACTER_RUNNING_SHOW_ANIMATION: StringName = &"running_show"
const CHARACTER_CASTING_ANIMATION: StringName = &"casting"
const CHARACTER_CASTING_SIT_ANIMATION: StringName = &"casting_sit"
const CHARACTER_RELEASE_ANIMATION: StringName = &"release"
const CHARACTER_RELEASE_SIT_ANIMATION: StringName = &"release_sit"
const CHARACTER_RETRACT_ANIMATION: StringName = &"retract"
const CHARACTER_RETRACT_SIT_ANIMATION: StringName = &"retract_sit"
const CHARACTER_POCKET_IDLE_IDLE_ANIMATION: StringName = &"pocket_idle_idle"
const CHARACTER_POCKET_IDLE_SHOW_ANIMATION: StringName = &"pocket_idle_show"
const CHARACTER_POCKET_SHOW_SHOW_ANIMATION: StringName = &"pocket_show_show"
const CHARACTER_POCKET_SHOW_IDLE_ANIMATION: StringName = &"pocket_show_idle"
const CHARACTER_POCKET_SIT_IDLE_IDLE_ANIMATION: StringName = &"pocket_sit_idle_idle"
const CHARACTER_POCKET_SIT_IDLE_SHOW_ANIMATION: StringName = &"pocket_sit_idle_show"
const CHARACTER_POCKET_SIT_SHOW_SHOW_ANIMATION: StringName = &"pocket_sit_show_show"
const CHARACTER_POCKET_SIT_SHOW_IDLE_ANIMATION: StringName = &"pocket_sit_show_idle"
const CHARACTER_POCKET_WALKING_IDLE_IDLE_ANIMATION: StringName = &"pocket_walking_idle_idle"
const CHARACTER_POCKET_WALKING_IDLE_SHOW_ANIMATION: StringName = &"pocket_walking_idle_show"
const CHARACTER_POCKET_WALKING_SHOW_SHOW_ANIMATION: StringName = &"pocket_walking_show_show"
const CHARACTER_POCKET_WALKING_SHOW_IDLE_ANIMATION: StringName = &"pocket_walking_show_idle"
const CHARACTER_FISHING_ANIMATION: StringName = &"fishing"
const CHARACTER_FISHING_SIT_ANIMATION: StringName = &"fishing_sit"
const CHARACTER_FIGHTING_ANIMATION: StringName = &"fighting"
const CHARACTER_FIGHTING_SIT_ANIMATION: StringName = &"fighting_sit"
# Add future networked emote animation IDs here. The protocol accepts unknown
# safe IDs so newer clients can extend it, but Player only presents actions
# explicitly approved by this catalog.
const NETWORK_ANIMATION_ACTION_IDS: Array[StringName] = []

enum FishingVisualPhase {
	NONE,
	CASTING,
	RELEASE,
	RETRACT,
	FISHING,
}

enum PocketVisualTarget {
	NONE,
	IDLE_ITEM,
	HELD_FISH,
	ART_KIT,
	CATCH_SHOWCASE,
}

enum LocomotionState {
	IDLE,
	WALKING,
	RUNNING,
}
const FIGHTING_EYES_ID: String = "alligator_eyes"
const BLINK_EYES_ID: String = "closed"
const BLINK_INTERVAL_SECONDS := Vector2(2.8, 7.5)
const BLINK_DURATION_SECONDS: float = 0.11
const CHARACTER_CALL_MOUTH_ID: String = "open_ah"
const CHARACTER_CALL_MOUTH_DURATION_SECONDS: float = 0.16
const BASE_REEL_SPEED: float = 0.16
const LANDING_DUST_MIN_FALL_SPEED: float = 2.5
const NETWORK_EXTRAPOLATION_LIMIT_SECONDS: float = 0.25
const NETWORK_EXPECTED_SNAPSHOT_INTERVAL_SECONDS: float = 1.0 / 30.0
const NETWORK_SNAPSHOT_JITTER_LIMIT_SECONDS: float = 0.1
const NETWORK_SNAPSHOT_JITTER_WEIGHT: float = 0.15
const NETWORK_REMOTE_SMOOTHING_RATE: float = 12.0
const NETWORK_REMOTE_JITTER_SMOOTHING_RATE: float = 6.0
const NETWORK_INPUT_STALE_TIMEOUT_SECONDS: float = 0.25
const LOCAL_PREDICTION_EXTRAPOLATION_LIMIT_SECONDS: float = 0.25
const LOCAL_PREDICTION_FALLBACK_TRANSIT_RATIO: float = 0.5
const LOCAL_PREDICTION_CORRECTION_THRESHOLD: float = 0.12
const LOCAL_PREDICTION_SNAP_DISTANCE: float = 2.0
const LOCAL_PREDICTION_CORRECTION_WEIGHT: float = 0.18
# The target Android handheld exposes its physical right trigger through
# Godot's left-trigger axis. Keep the role named here so the platform mapping
# remains isolated from camera behavior.
const CONTROLLER_ZOOM_TRIGGER_AXIS: JoyAxis = JOY_AXIS_TRIGGER_LEFT

var appearance_snapshot: Dictionary = (
	CharacterCustomizationCatalog.default_snapshot()
)
var animalese_voice_id: String = VoiceProfilesType.DEFAULT_ID
var animalese_sample_set_id: String = VoiceProfilesType.DEFAULT_SAMPLE_SET_ID
var active_bait_id: StringName = StringName()
var active_lure_id: StringName = StringName()
signal active_bait_changed(item_id: StringName)
signal active_lure_changed(item_id: StringName)


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


func equip_lure(item: ItemDataType) -> bool:
	if item == null or not item.is_lure() or bag == null:
		return false
	if not bag.owns_item(item.item_id):
		return false
	active_lure_id = item.item_id
	active_lure_changed.emit(active_lure_id)
	return true


func unequip_lure() -> void:
	if active_lure_id.is_empty():
		return
	active_lure_id = StringName()
	active_lure_changed.emit(active_lure_id)


func apply_appearance_snapshot(snapshot: Dictionary) -> void:
	if CharacterCustomizationCatalog.validate_snapshot(snapshot):
		appearance_snapshot = snapshot.duplicate(true)
		_apply_presented_appearance()


func get_character_visual_scale() -> float:
	return CharacterCustomizationCatalog.character_scale(
		appearance_snapshot.get(
			CharacterCustomizationCatalog.SCALE_CATEGORY_ID,
			CharacterCustomizationCatalog.DEFAULT_CHARACTER_SCALE,
		)
	)


func set_fighting_visual(active: bool) -> void:
	if _fighting_visual_active == active:
		return
	_fighting_visual_active = active
	if active:
		_blink_visual_active = false
		_schedule_next_blink()
	_apply_presented_appearance()
	_character_animation_name = &""
	_update_character_animation()


func play_character_call_visual() -> void:
	_character_call_visual_generation += 1
	var generation: int = _character_call_visual_generation
	_character_call_mouth_active = true
	_apply_presented_appearance()
	await get_tree().create_timer(
		CHARACTER_CALL_MOUTH_DURATION_SECONDS
	).timeout
	if generation != _character_call_visual_generation:
		return
	_character_call_mouth_active = false
	_apply_presented_appearance()


func set_fishing_visual(active: bool) -> void:
	if (
		active
		and _fishing_visual_phase == FishingVisualPhase.RELEASE
		and _character_animation_name in [
			CHARACTER_RELEASE_ANIMATION,
			CHARACTER_RELEASE_SIT_ANIMATION,
		]
		and _character_animation_player != null
		and _character_animation_player.is_playing()
	):
		_fishing_after_release_pending = true
		return
	_set_fishing_visual_phase(
		FishingVisualPhase.FISHING if active else FishingVisualPhase.NONE
	)


func set_casting_visual() -> void:
	_set_fishing_visual_phase(FishingVisualPhase.CASTING)


func set_release_visual() -> void:
	_set_fishing_visual_phase(FishingVisualPhase.RELEASE)


func set_retract_visual() -> void:
	_retract_animation_completed = false
	_set_fishing_visual_phase(FishingVisualPhase.RETRACT)
	if (
		_character_animation_player == null
		or _character_animation_name not in [
			CHARACTER_RETRACT_ANIMATION,
			CHARACTER_RETRACT_SIT_ANIMATION,
		]
		or not _character_animation_player.is_playing()
	):
		_complete_retract_animation()


func _set_fishing_visual_phase(phase: FishingVisualPhase) -> void:
	if phase != FishingVisualPhase.NONE and _pocket_visual_active:
		_complete_pocket_visual()
	if _fishing_visual_phase == phase:
		return
	if (
		_fishing_visual_phase == FishingVisualPhase.RETRACT
		and phase != FishingVisualPhase.RETRACT
	):
		_complete_retract_animation()
	if phase != FishingVisualPhase.RELEASE:
		_fishing_after_release_pending = false
	_fishing_visual_phase = phase
	_fishing_visual_active = phase != FishingVisualPhase.NONE
	_character_animation_name = &""
	_update_character_animation()


func _apply_presented_appearance() -> void:
	if not is_node_ready() or _visuals == null:
		return
	var presented_appearance := appearance_snapshot
	if _blink_visual_active and not _fighting_visual_active:
		presented_appearance = appearance_snapshot.duplicate(true)
		presented_appearance["eyes"] = BLINK_EYES_ID
	if _fighting_visual_active:
		presented_appearance = appearance_snapshot.duplicate(true)
		presented_appearance["eyes"] = FIGHTING_EYES_ID
	if _character_call_mouth_active:
		if presented_appearance == appearance_snapshot:
			presented_appearance = appearance_snapshot.duplicate(true)
		presented_appearance["mouth"] = CHARACTER_CALL_MOUTH_ID
	PlayerVisualPresenter.apply_appearance(_visuals, presented_appearance)


func apply_animalese_voice_id(voice_id: String) -> void:
	animalese_voice_id = VoiceProfilesType.sanitized_id(voice_id)


func get_animalese_voice_id() -> String:
	return animalese_voice_id


func apply_animalese_sample_set_id(sample_set_id: String) -> void:
	animalese_sample_set_id = VoiceProfilesType.sanitized_sample_set_id(
		sample_set_id
	)


func get_animalese_sample_set_id() -> String:
	return animalese_sample_set_id

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
@export var sprint_speed: float = 4.5
@export var sneak_speed: float = 1.125
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
@export_range(1.0, 40.0, 0.5) var free_camera_speed: float = 10.0
@export_range(1.0, 10.0, 0.5) var free_camera_sprint_multiplier: float = 3.0

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
@onready var _player_collision_shape: CollisionShape3D = $CollisionShape3D
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
var _held_art_kit_display: Node3D
var _held_art_kit_sprite: Sprite3D
var _catch_attachment_offset: Vector3 = Vector3(0.0, 0.08, 0.04)

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _camera_dragging: bool = false
var _camera_input_enabled: bool = true
var _camera_drag_prior_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _free_camera_active: bool = false
var _free_camera_body: CharacterBody3D
var _free_camera: Camera3D
var _free_camera_yaw: float = 0.0
var _free_camera_pitch: float = 0.0
var _movement_enabled: bool = true
var _local_input_suppressors: Dictionary[StringName, bool] = {}
var _water_recovery_active: bool = false
var _remote_recovery_presentation_active: bool = false
var _remote_recovery_visual_origin: Vector3
var _remote_recovery_elapsed: float = 0.0
var _target_zoom: float = 5.0
var _showcase_rod_visibility: bool = true
var _showcase_net_visibility: bool = false
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
var _network_input_age: float = 0.0
var _network_input_stale: bool = false
var _network_jump_intent_active: bool = false
var _network_target_position: Vector3
var _network_target_velocity: Vector3
var _network_target_visual_yaw: float = 0.0
var _network_target_grounded: bool = false
var _network_target_locomotion_state: LocomotionState = LocomotionState.IDLE
var _network_target_animation_action_id: StringName = &""
var _network_target_animation_action_sequence: int = 0
var _network_target_animation_action_elapsed: float = 0.0
var _network_snapshot_ready: bool = false
var _network_snapshot_age: float = 0.0
var _network_snapshot_jitter: float = 0.0
var _local_network_jump_intent_pending: bool = false
var _local_network_jump_intent_sequence: int = -1
var _animation_action_id: StringName = &""
var _animation_action_sequence: int = 0
var _animation_action_elapsed: float = 0.0
var _presented_animation_action_id: StringName = &""
var _presented_animation_action_sequence: int = -1
var _character_animation_name: StringName = &""
var _sitting: bool = false
var _sit_after_landing: bool = false
var _sitting_intent_pending: bool = false
var _sitting_intent_sequence: int = -1
var _held_fish_visible: bool = false
var _pending_held_fish_texture: Texture2D
var _pending_held_fish_scale: Vector3 = Vector3.ONE
var _held_art_kit_visible: bool = false
var _showcase_animation_active: bool = false
var _pocket_visual_active: bool = false
var _pocket_visual_target: PocketVisualTarget = PocketVisualTarget.NONE
var _pocket_visual_animation: StringName = &""
var _pocket_visual_finished_callback: Callable
var _pocket_visual_callback_runs_on_interrupt: bool = true
var _pocket_visual_midpoint_callback: Callable
var _pocket_visual_midpoint_called: bool = false
var _pocket_visual_generation: int = 0
var _fighting_visual_active: bool = false
var _blink_visual_active: bool = false
var _blink_seconds_remaining: float = 0.0
var _blink_rng := RandomNumberGenerator.new()
var _character_call_mouth_active: bool = false
var _character_call_visual_generation: int = 0
var _fishing_visual_active: bool = false
var _fishing_visual_phase: FishingVisualPhase = FishingVisualPhase.NONE
var _fishing_after_release_pending: bool = false
var _retract_animation_completed: bool = true
var _fishing_rod: Node3D
var _catching_net: Node3D
var _fishing_rod_tip: Marker3D
var _fishing_rod_model_mount: Node3D
var _fishing_rod_fallback_visual: GeometryInstance3D
var _custom_fishing_rod_visual: Node3D
var _active_fishing_rod_id: StringName
var _active_item_is_rod: bool = false
var _active_item_is_net: bool = false
var _controller_mapping_manager: ControllerMappingManagerType
var _sprint_dust_landing_ready: bool = false
var _sprint_dust_airborne: bool = false
var _sprint_dust_fall_speed: float = 0.0

@onready var _sprint_dust: SprintDustTrailType = %SprintDust


func _ready() -> void:
	_blink_rng.randomize()
	_schedule_next_blink()
	if (
		_character_animation_player != null
		and not _character_animation_player.animation_finished.is_connected(
			_on_character_animation_finished
		)
	):
		_character_animation_player.animation_finished.connect(
			_on_character_animation_finished
		)
	if not bag.contents_changed.is_connected(_on_bag_contents_changed):
		bag.contents_changed.connect(_on_bag_contents_changed)
	_apply_presented_appearance()
	_initialize_fishing_rod()
	_initialize_catching_net()
	_target_zoom = clampf(_spring_arm.spring_length, minimum_zoom, maximum_zoom)
	_spring_arm.spring_length = _target_zoom
	_camera.current = local_control_enabled
	_initialize_held_item_attachment()


func _on_bag_contents_changed() -> void:
	if (
		not active_bait_id.is_empty()
		and bag.get_quantity(active_bait_id) <= 0
	):
		unequip_bait()
	if (
		not active_lure_id.is_empty()
		and not bag.owns_item(active_lure_id)
	):
		unequip_lure()


func set_controller_mapping_manager(
	mapping_manager: ControllerMappingManagerType,
) -> void:
	_controller_mapping_manager = mapping_manager


func begin_animation_action(
	action_id: StringName,
	elapsed_seconds: float = 0.0,
) -> bool:
	if (
		action_id.is_empty()
		or not supports_network_animation_action(action_id)
		or _character_animation_player == null
		or not _character_animation_player.has_animation(action_id)
	):
		return false
	var next_sequence: int = (
		1
		if _animation_action_sequence
		>= NetworkPlayerAnimationProtocol.MAX_ACTION_SEQUENCE
		else _animation_action_sequence + 1
	)
	var action_state: Dictionary = (
		NetworkPlayerAnimationProtocol.make_action_state(
			action_id, next_sequence, elapsed_seconds
		)
	)
	if not NetworkPlayerAnimationProtocol.validate_action_state(action_state):
		return false
	_apply_animation_action_state(action_state)
	return true


func end_animation_action() -> void:
	if _animation_action_id.is_empty():
		return
	var next_sequence: int = (
		1
		if _animation_action_sequence
		>= NetworkPlayerAnimationProtocol.MAX_ACTION_SEQUENCE
		else _animation_action_sequence + 1
	)
	_apply_animation_action_state(
		NetworkPlayerAnimationProtocol.make_action_state(
			&"", next_sequence, 0.0
		)
	)


func _apply_animation_action_state(action_state: Dictionary) -> void:
	if not NetworkPlayerAnimationProtocol.validate_action_state(action_state):
		return
	var action_id := StringName(str(action_state["id"]))
	if (
		not action_id.is_empty()
		and not supports_network_animation_action(action_id)
	):
		action_id = &""
	var action_sequence: int = int(action_state["sequence"])
	var action_changed: bool = (
		action_id != _animation_action_id
		or action_sequence != _animation_action_sequence
	)
	_animation_action_id = action_id
	_animation_action_sequence = action_sequence
	_animation_action_elapsed = float(action_state["elapsed"])
	if action_changed:
		_character_animation_name = &""
		_update_character_animation()


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
	_fishing_rod_model_mount = attachment.get_node(
		"FishingRod/ModelMount"
	) as Node3D
	_fishing_rod_fallback_visual = attachment.get_node(
		"FishingRod/FallbackRodMesh"
	) as GeometryInstance3D


func _initialize_catching_net() -> void:
	var skeleton := get_node_or_null(
		"Visuals/CharacterRig/CharacterRig/Skeleton3D"
	) as Skeleton3D
	if skeleton == null:
		push_error("Player character skeleton is unavailable for the net.")
		return
	var attachment := NetAttachmentScene.instantiate() as BoneAttachment3D
	if attachment == null:
		push_error("Catching net attachment could not be instantiated.")
		return
	skeleton.add_child(attachment)
	_catching_net = attachment.get_node("CatchingNet") as Node3D
	if _catching_net != null:
		_catching_net.visible = false


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
	_held_art_kit_display = attachment.get_node("HeldArtKitDisplay") as Node3D
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
	if _network_authoritative_simulation:
		_update_network_input_freshness(delta)
	if local_control_enabled and _free_camera_active:
		_update_free_camera_physics()
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= _gravity * fall_gravity_multiplier * delta
		move_and_slide()
		_network_jump_pending = false
		return
	var local_jump_pressed: bool = (
		local_control_enabled
		and Input.is_action_just_pressed("jump")
	)
	if (
		local_jump_pressed
		and _is_movement_input_enabled()
		and not _free_camera_active
	):
		_queue_local_network_jump_intent()
	var jump_requested: bool = (
		_is_movement_input_enabled()
		and not _free_camera_active
		and (
			local_jump_pressed
			or (_network_authoritative_simulation and _network_jump_pending)
		)
	)
	if _sit_after_landing and is_on_floor():
		_sit_after_landing = false
		_set_sitting(true, local_control_enabled)
	if _sitting:
		if jump_requested:
			_set_sitting(false, local_control_enabled)
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

	if not _is_movement_input_enabled():
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
	if not _animation_action_id.is_empty():
		_animation_action_elapsed = minf(
			_animation_action_elapsed + delta,
			NetworkPlayerAnimationProtocol.MAX_ACTION_ELAPSED_SECONDS,
		)
	_update_blink(delta)
	_update_character_animation()
	_update_sprint_dust(delta)
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
	if _free_camera_active:
		if _is_camera_input_enabled():
			_rotate_free_camera(
				_scale_controller_camera_input(
					_get_controller_camera_stick(),
					delta,
				)
			)
		return

	if _camera_dragging and not Input.is_action_pressed("camera_drag"):
		_set_camera_dragging(false)

	if _is_camera_input_enabled():
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
				_rotate_camera(
					_scale_controller_camera_input(stick, delta)
				)

		var zoom_weight: float = 1.0 - exp(-zoom_smoothing * delta)
		_spring_arm.spring_length = lerpf(
			_spring_arm.spring_length,
			_target_zoom,
			zoom_weight
		)


func _update_blink(delta: float) -> void:
	if _fighting_visual_active:
		return
	_blink_seconds_remaining -= delta
	if _blink_seconds_remaining > 0.0:
		return
	_blink_visual_active = not _blink_visual_active
	if _blink_visual_active:
		_blink_seconds_remaining = BLINK_DURATION_SECONDS
	else:
		_schedule_next_blink()
	_apply_presented_appearance()


func _schedule_next_blink() -> void:
	_blink_seconds_remaining = _blink_rng.randf_range(
		BLINK_INTERVAL_SECONDS.x,
		BLINK_INTERVAL_SECONDS.y,
	)


func _update_sprint_dust(delta: float) -> void:
	if _sprint_dust == null:
		return
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var grounded: bool = _get_presented_grounded()
	if _water_recovery_active:
		_sprint_dust_airborne = false
		_sprint_dust_fall_speed = 0.0
	elif not _sprint_dust_landing_ready:
		# Establish a real ground contact before arming landing effects. This
		# prevents the player's initial placement from looking like a fall.
		_sprint_dust_landing_ready = grounded
	elif not grounded:
		_sprint_dust_airborne = true
		_sprint_dust_fall_speed = maxf(
			_sprint_dust_fall_speed,
			maxf(-velocity.y, 0.0),
		)
	elif _sprint_dust_airborne:
		if _sprint_dust_fall_speed >= LANDING_DUST_MIN_FALL_SPEED:
			var landing_facing: Vector3 = horizontal_velocity.normalized()
			if landing_facing.is_zero_approx() and _visuals != null:
				landing_facing = -_visuals.global_basis.z
			_sprint_dust.emit_landing_burst(
				global_position,
				landing_facing,
			)
		_sprint_dust_airborne = false
		_sprint_dust_fall_speed = 0.0
	var should_emit: bool = (
		grounded
		and not _sitting
		and not _water_recovery_active
		and _get_presented_locomotion_state() == LocomotionState.RUNNING
	)
	_sprint_dust.update_trail(
		delta,
		global_position,
		horizontal_velocity,
		should_emit,
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


func _scale_controller_camera_input(
	stick: Vector2,
	delta: float,
) -> Vector2:
	var strength: float = stick.length()
	if strength <= controller_camera_deadzone:
		return Vector2.ZERO
	var adjusted_strength: float = (
		(strength - controller_camera_deadzone)
		/ (1.0 - controller_camera_deadzone)
	)
	return (
		stick.normalized()
		* adjusted_strength
		* controller_camera_speed
		* delta
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
	var locomotion_state: LocomotionState = (
		_get_presented_locomotion_state()
	)
	var is_walking: bool = locomotion_state != LocomotionState.IDLE
	var is_running: bool = locomotion_state == LocomotionState.RUNNING
	var animation_action: Dictionary = _get_presented_animation_action()
	var animation_action_id := StringName(str(animation_action.get("id", "")))
	var animation_action_available: bool = (
		not animation_action_id.is_empty()
		and supports_network_animation_action(animation_action_id)
		and _character_animation_player.has_animation(animation_action_id)
	)
	var held_show_item_visible: bool = (
		_held_fish_visible or _held_art_kit_visible
	)
	var requested_animation: Array[StringName] = []
	if _pocket_visual_active:
		requested_animation = [_pocket_visual_animation]
	elif _showcase_animation_active:
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
	elif _fighting_visual_active:
		if _sitting:
			requested_animation = [
				CHARACTER_FIGHTING_SIT_ANIMATION,
				CHARACTER_IDLE_SIT_ANIMATION,
				&"idle_sit_loop",
			]
		else:
			requested_animation = [
				CHARACTER_FIGHTING_ANIMATION,
				CHARACTER_IDLE_ANIMATION,
			]
	elif _fishing_visual_active:
		if _sitting:
			match _fishing_visual_phase:
				FishingVisualPhase.CASTING:
					requested_animation = [
						CHARACTER_CASTING_SIT_ANIMATION,
						CHARACTER_FISHING_SIT_ANIMATION,
						CHARACTER_IDLE_SIT_ANIMATION,
					]
				FishingVisualPhase.RELEASE:
					requested_animation = [
						CHARACTER_RELEASE_SIT_ANIMATION,
						CHARACTER_FISHING_SIT_ANIMATION,
						CHARACTER_IDLE_SIT_ANIMATION,
					]
				FishingVisualPhase.RETRACT:
					requested_animation = [
						CHARACTER_RETRACT_SIT_ANIMATION,
						CHARACTER_RETRACT_ANIMATION,
						CHARACTER_FISHING_SIT_ANIMATION,
						CHARACTER_IDLE_SIT_ANIMATION,
					]
				_:
					requested_animation = [
						CHARACTER_FISHING_SIT_ANIMATION,
						CHARACTER_IDLE_SIT_ANIMATION,
						&"idle_sit_loop",
					]
		else:
			match _fishing_visual_phase:
				FishingVisualPhase.CASTING:
					requested_animation = [
						CHARACTER_CASTING_ANIMATION,
						CHARACTER_FISHING_ANIMATION,
						CHARACTER_IDLE_ANIMATION,
					]
				FishingVisualPhase.RELEASE:
					requested_animation = [
						CHARACTER_RELEASE_ANIMATION,
						CHARACTER_FISHING_ANIMATION,
						CHARACTER_IDLE_ANIMATION,
					]
				FishingVisualPhase.RETRACT:
					requested_animation = [
						CHARACTER_RETRACT_ANIMATION,
						CHARACTER_FISHING_ANIMATION,
						CHARACTER_IDLE_ANIMATION,
					]
				_:
					requested_animation = [
						CHARACTER_FISHING_ANIMATION,
						CHARACTER_IDLE_ANIMATION,
					]
	elif animation_action_available:
		requested_animation = [animation_action_id]
	elif _sitting:
		if held_show_item_visible:
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
	elif is_running and held_show_item_visible:
		requested_animation = [
			CHARACTER_RUNNING_SHOW_ANIMATION,
			&"running_show_loop",
			CHARACTER_WALKING_SHOW_ANIMATION,
			&"walking_show_loop",
		]
	elif is_running:
		requested_animation = [
			CHARACTER_RUNNING_ANIMATION,
			&"running_loop",
			CHARACTER_WALKING_ANIMATION,
			&"walking_loop",
		]
	elif is_walking and held_show_item_visible:
		requested_animation = [
			CHARACTER_WALKING_SHOW_ANIMATION,
			&"walking_show_loop",
		]
	elif held_show_item_visible:
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
	var action_selected: bool = (
		animation_action_available and next_animation == animation_action_id
	)
	var action_sequence: int = int(animation_action.get("sequence", 0))
	var action_changed: bool = (
		action_selected
		and (
			animation_action_id != _presented_animation_action_id
			or action_sequence != _presented_animation_action_sequence
		)
	)
	if not action_selected:
		_presented_animation_action_id = &""
		_presented_animation_action_sequence = -1
	if _character_animation_name == next_animation and not action_changed:
		return
	_character_animation_player.play(next_animation)
	_character_animation_name = next_animation
	if action_selected:
		_presented_animation_action_id = animation_action_id
		_presented_animation_action_sequence = action_sequence
		var elapsed: float = float(animation_action.get("elapsed", 0.0))
		var animation: Animation = _character_animation_player.get_animation(
			next_animation
		)
		if elapsed > 0.0 and animation != null and animation.length > 0.0:
			_character_animation_player.seek(
				fposmod(elapsed, animation.length), true
			)


func _on_character_animation_finished(animation_name: StringName) -> void:
	if (
		local_control_enabled
		and not _animation_action_id.is_empty()
		and animation_name == _animation_action_id
	):
		end_animation_action()
		return
	if animation_name in [
		CHARACTER_POCKET_IDLE_IDLE_ANIMATION,
		CHARACTER_POCKET_IDLE_SHOW_ANIMATION,
		CHARACTER_POCKET_SHOW_SHOW_ANIMATION,
		CHARACTER_POCKET_SHOW_IDLE_ANIMATION,
		CHARACTER_POCKET_SIT_IDLE_IDLE_ANIMATION,
		CHARACTER_POCKET_SIT_IDLE_SHOW_ANIMATION,
		CHARACTER_POCKET_SIT_SHOW_SHOW_ANIMATION,
		CHARACTER_POCKET_SIT_SHOW_IDLE_ANIMATION,
		CHARACTER_POCKET_WALKING_IDLE_IDLE_ANIMATION,
		CHARACTER_POCKET_WALKING_IDLE_SHOW_ANIMATION,
		CHARACTER_POCKET_WALKING_SHOW_SHOW_ANIMATION,
		CHARACTER_POCKET_WALKING_SHOW_IDLE_ANIMATION,
	]:
		if _pocket_visual_active:
			_complete_pocket_visual()
		return
	if animation_name in [
		CHARACTER_RETRACT_ANIMATION,
		CHARACTER_RETRACT_SIT_ANIMATION,
	]:
		_complete_retract_animation()
		return
	if (
		not _fishing_after_release_pending
		or animation_name not in [
			CHARACTER_RELEASE_ANIMATION,
			CHARACTER_RELEASE_SIT_ANIMATION,
		]
	):
		return
	_fishing_after_release_pending = false
	_set_fishing_visual_phase(FishingVisualPhase.FISHING)


func is_retract_visual_complete() -> bool:
	return _retract_animation_completed


func _complete_retract_animation() -> void:
	if _retract_animation_completed:
		return
	_retract_animation_completed = true
	retract_visual_finished.emit()


func toggle_sitting() -> void:
	if _sit_after_landing:
		_sit_after_landing = false
		return
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
		if not is_on_floor():
			_sit_after_landing = true
			return
	_set_sitting(should_sit, local_control_enabled)


func _has_any_character_animation(candidates: Array[StringName]) -> bool:
	if _character_animation_player == null:
		return false
	for candidate: StringName in candidates:
		if _character_animation_player.has_animation(candidate):
			return true
	return false


func _set_sitting(
	should_sit: bool,
	is_local_intent: bool = false,
) -> void:
	if _sitting == should_sit:
		return
	_sitting = should_sit
	if is_local_intent:
		_sitting_intent_pending = true
		_sitting_intent_sequence = -1
	if _sitting:
		velocity = Vector3.ZERO
	_character_animation_name = &""
	_update_character_animation()


func is_sitting() -> bool:
	return _sitting


func _unhandled_input(event: InputEvent) -> void:
	if not local_control_enabled or not _is_camera_input_enabled():
		return
	if event.is_action_pressed("toggle_free_camera"):
		toggle_free_camera()
		get_viewport().set_input_as_handled()
		return

	if event.is_action("camera_drag"):
		_set_camera_dragging(event.is_pressed())
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and _camera_dragging:
		if _free_camera_active:
			_rotate_free_camera(event.relative * mouse_sensitivity)
		else:
			_rotate_camera(event.relative * mouse_sensitivity)
		get_viewport().set_input_as_handled()
		return
	if _free_camera_active:
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


func _set_camera_dragging(active: bool) -> void:
	if _camera_dragging == active:
		return
	_camera_dragging = active
	if active:
		_camera_drag_prior_mouse_mode = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = _camera_drag_prior_mouse_mode


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


func _set_free_camera_active(active: bool) -> void:
	if _free_camera_active == active:
		return
	if active:
		var camera_transform: Transform3D = _camera.global_transform
		var duplicated_camera := _camera.duplicate() as Camera3D
		if duplicated_camera == null:
			return
		var camera_body := CharacterBody3D.new()
		camera_body.name = "FreeCameraBody"
		camera_body.collision_layer = 0
		camera_body.collision_mask = collision_mask
		camera_body.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		add_child(camera_body)
		camera_body.top_level = true
		camera_body.global_position = camera_transform.origin
		var camera_collision := CollisionShape3D.new()
		camera_collision.name = "FreeCameraCollision"
		camera_collision.shape = _player_collision_shape.shape
		camera_body.add_child(camera_collision)
		duplicated_camera.name = "FreeCamera"
		duplicated_camera.unique_name_in_owner = false
		camera_body.add_child(duplicated_camera)
		duplicated_camera.transform = Transform3D(
			camera_transform.basis,
			Vector3.ZERO,
		)
		_free_camera_body = camera_body
		_free_camera = duplicated_camera
		var camera_rotation: Vector3 = _free_camera.global_rotation
		_free_camera_yaw = camera_rotation.y
		_free_camera_pitch = camera_rotation.x
		_camera.current = false
		_free_camera.current = true
		_free_camera_active = true
		return
	_free_camera_active = false
	_set_camera_dragging(false)
	if _free_camera != null:
		_free_camera.current = false
		_free_camera = null
	if _free_camera_body != null:
		_free_camera_body.queue_free()
		_free_camera_body = null
	_camera.current = local_control_enabled


func toggle_free_camera() -> void:
	if not local_control_enabled:
		return
	_set_free_camera_active(not _free_camera_active)


func is_free_camera_active() -> bool:
	return _free_camera_active


func _update_free_camera_physics() -> void:
	if _free_camera == null or _free_camera_body == null:
		_set_free_camera_active(false)
		return
	var input_vector: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward",
	)
	var vertical_input: float = (
		Input.get_action_strength("jump")
		- Input.get_action_strength("sneak")
	)
	var yaw_basis := Basis(Vector3.UP, _free_camera_yaw)
	var movement: Vector3 = (
		yaw_basis.x * input_vector.x
		+ yaw_basis.z * input_vector.y
		+ Vector3.UP * vertical_input
	)
	if movement.length_squared() > 1.0:
		movement = movement.normalized()
	var movement_speed: float = free_camera_speed
	if Input.is_action_pressed("sprint"):
		movement_speed *= free_camera_sprint_multiplier
	_free_camera_body.velocity = movement * movement_speed
	_free_camera_body.move_and_slide()


func _rotate_free_camera(delta_rotation: Vector2) -> void:
	if _free_camera == null:
		return
	_free_camera_yaw -= delta_rotation.x
	var vertical_direction: float = -1.0 if invert_camera_y else 1.0
	_free_camera_pitch = clampf(
		_free_camera_pitch - delta_rotation.y * vertical_direction,
		deg_to_rad(-90.0),
		deg_to_rad(90.0),
	)
	_free_camera.global_rotation = Vector3(
		_free_camera_pitch,
		_free_camera_yaw,
		0.0,
	)


func get_active_gameplay_camera() -> Camera3D:
	if _free_camera_active and _free_camera != null:
		return _free_camera
	return _camera


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
	if not enabled and _free_camera_active:
		_set_free_camera_active(false)
	local_control_enabled = enabled
	if is_node_ready():
		_camera.current = enabled
	if not enabled:
		_set_camera_dragging(false)
		_clear_local_network_jump_intent()


func set_network_peer_id(peer_id: int) -> void:
	_network_peer_id = peer_id


func get_network_peer_id() -> int:
	return _network_peer_id


func configure_network_remote(authoritative_simulation: bool) -> void:
	set_local_control(false)
	_network_authoritative_simulation = authoritative_simulation
	_network_interpolation_enabled = not authoritative_simulation
	_network_axis = Vector2.ZERO
	_network_jump_pending = false
	_network_sprint = false
	_network_sneak = false
	_network_slow_walk = false
	_network_input_age = 0.0
	_network_input_stale = false
	_network_jump_intent_active = false
	_network_snapshot_ready = false
	_network_snapshot_age = 0.0
	_network_snapshot_jitter = 0.0
	_network_target_grounded = false
	_network_target_locomotion_state = LocomotionState.IDLE
	_network_target_animation_action_id = &""
	_network_target_animation_action_sequence = 0
	_network_target_animation_action_elapsed = 0.0
	_camera.current = false


func reset_network_movement_state() -> void:
	_clear_local_network_jump_intent()
	_network_axis = Vector2.ZERO
	_network_jump_pending = false
	_network_sprint = false
	_network_sneak = false
	_network_slow_walk = false
	_network_input_age = 0.0
	_network_input_stale = false
	_network_jump_intent_active = false
	_last_network_input_sequence = 0


func capture_network_input(sequence: int) -> Dictionary:
	if _sitting_intent_pending and _sitting_intent_sequence < 0:
		_sitting_intent_sequence = sequence
	if (
		local_control_enabled
		and _is_movement_input_enabled()
		and not _free_camera_active
		and Input.is_action_just_pressed("jump")
	):
		_queue_local_network_jump_intent()
	if (
		not _is_movement_input_enabled()
		or _water_recovery_active
		or _free_camera_active
	):
		_clear_local_network_jump_intent()
		return {
			"sequence": sequence,
			"axis": [0.0, 0.0],
			"camera_yaw": _camera_yaw.global_rotation.y,
			"jump": false,
			"sprint": false,
			"sneak": false,
			"slow_walk": false,
			"sitting": _sitting,
			"casting": (
				_fishing_visual_phase == FishingVisualPhase.CASTING
			),
			"animation_action": _make_animation_action_state(),
		}
	var axis: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward"
	)
	if (
		_local_network_jump_intent_pending
		and _local_network_jump_intent_sequence < 0
	):
		_local_network_jump_intent_sequence = sequence
	return {
		"sequence": sequence,
		"axis": [axis.x, axis.y],
		"camera_yaw": _camera_yaw.global_rotation.y,
		"jump": _local_network_jump_intent_pending,
		"sprint": Input.is_action_pressed("sprint"),
		"sneak": Input.is_action_pressed("sneak"),
		"slow_walk": Input.is_action_pressed("slow_walk"),
		"sitting": _sitting,
		"casting": _fishing_visual_phase == FishingVisualPhase.CASTING,
		"animation_action": _make_animation_action_state(),
	}


func apply_authoritative_network_input(data: Dictionary) -> void:
	var sequence: int = int(data.get("sequence", 0))
	if sequence <= _last_network_input_sequence:
		return
	var axis: Array = data.get("axis", [])
	if axis.size() != 2:
		return
	_last_network_input_sequence = sequence
	_network_input_age = 0.0
	_network_input_stale = false
	_network_axis = Vector2(float(axis[0]), float(axis[1])).limit_length(1.0)
	_network_camera_yaw = float(data.get("camera_yaw", 0.0))
	var jump_intent_active: bool = bool(data.get("jump", false))
	if jump_intent_active and not _network_jump_intent_active:
		_network_jump_pending = true
	_network_jump_intent_active = jump_intent_active
	_network_sprint = bool(data.get("sprint", false))
	_network_sneak = bool(data.get("sneak", false))
	_network_slow_walk = bool(data.get("slow_walk", false))
	_apply_animation_action_state(data.get("animation_action", {}))
	_apply_network_casting(bool(data.get("casting", false)))
	var sitting_requested: bool = bool(data.get("sitting", false))
	if sitting_requested and not is_on_floor():
		_sit_after_landing = true
		_set_sitting(false)
	else:
		_sit_after_landing = false
		_set_sitting(sitting_requested)


func make_network_snapshot(peer_id: int) -> Dictionary:
	return {
		"peer_id": peer_id,
		"acknowledged_input": _last_network_input_sequence,
		"position": [global_position.x, global_position.y, global_position.z],
		"velocity": [velocity.x, velocity.y, velocity.z],
		"visual_yaw": _visuals.rotation.y,
		"animation_state": NetworkPlayerAnimationProtocol.make_state(
			_get_authoritative_locomotion_id(),
			is_on_floor(),
			_animation_action_id,
			_animation_action_sequence,
			_animation_action_elapsed,
		),
		"sitting": _sitting,
		"casting": _fishing_visual_phase == FishingVisualPhase.CASTING,
	}


func push_network_snapshot(
	snapshot: Dictionary,
	estimated_transit_seconds: float = -1.0,
) -> void:
	var parsed: Dictionary = _parse_network_snapshot(snapshot)
	if parsed.is_empty():
		return
	if _network_snapshot_ready:
		var arrival_error: float = absf(
			_network_snapshot_age
			- NETWORK_EXPECTED_SNAPSHOT_INTERVAL_SECONDS
		)
		_network_snapshot_jitter = lerpf(
			_network_snapshot_jitter,
			minf(arrival_error, NETWORK_SNAPSHOT_JITTER_LIMIT_SECONDS),
			NETWORK_SNAPSHOT_JITTER_WEIGHT,
		)
	var transit_seconds: float = (
		clampf(
			estimated_transit_seconds,
			0.0,
			NETWORK_EXTRAPOLATION_LIMIT_SECONDS,
		)
		if is_finite(estimated_transit_seconds)
		and estimated_transit_seconds >= 0.0
		else 0.0
	)
	_network_target_position = (
		(parsed["position"] as Vector3)
		+ (parsed["velocity"] as Vector3) * transit_seconds
	)
	_network_target_velocity = parsed["velocity"]
	_network_target_visual_yaw = parsed["visual_yaw"]
	_apply_network_target_animation_state(parsed["animation_state"])
	_network_snapshot_age = 0.0
	_apply_network_casting(bool(parsed["casting"]))
	_set_sitting(bool(parsed["sitting"]))
	if not _network_snapshot_ready:
		global_position = _network_target_position
		velocity = _network_target_velocity
		_visuals.rotation.y = _network_target_visual_yaw
	_network_snapshot_ready = true


func apply_local_prediction_correction(
	snapshot: Dictionary,
	latest_input_sequence: int = 0,
	input_interval_seconds: float = 0.0,
	estimated_transit_seconds: float = -1.0,
) -> void:
	var parsed: Dictionary = _parse_network_snapshot(snapshot)
	if parsed.is_empty():
		return
	var acknowledged_input: int = parsed["acknowledged_input"]
	var sitting_intent_acknowledged: bool = (
		_sitting_intent_pending
		and _sitting_intent_sequence >= 0
		and acknowledged_input >= _sitting_intent_sequence
	)
	if sitting_intent_acknowledged:
		_sitting_intent_pending = false
		_sitting_intent_sequence = -1
	if (
		_local_network_jump_intent_pending
		and _local_network_jump_intent_sequence >= 0
		and acknowledged_input >= _local_network_jump_intent_sequence
	):
		_clear_local_network_jump_intent()
	if not _sitting_intent_pending:
		_set_sitting(bool(parsed["sitting"]))
	var authoritative_position: Vector3 = parsed["position"]
	var transit_seconds: float = resolve_local_prediction_transit_seconds(
		acknowledged_input,
		latest_input_sequence,
		input_interval_seconds,
		estimated_transit_seconds,
	)
	if transit_seconds > 0.0:
		authoritative_position += (
			(parsed["velocity"] as Vector3) * transit_seconds
		)
	var error_distance: float = global_position.distance_to(
		authoritative_position
	)
	if error_distance > LOCAL_PREDICTION_SNAP_DISTANCE:
		global_position = authoritative_position
	elif error_distance > LOCAL_PREDICTION_CORRECTION_THRESHOLD:
		global_position = global_position.lerp(
			authoritative_position,
			LOCAL_PREDICTION_CORRECTION_WEIGHT,
		)


static func resolve_local_prediction_transit_seconds(
	acknowledged_input: int,
	latest_input_sequence: int,
	input_interval_seconds: float,
	estimated_transit_seconds: float,
) -> float:
	if is_finite(estimated_transit_seconds) and estimated_transit_seconds >= 0.0:
		return minf(
			estimated_transit_seconds,
			LOCAL_PREDICTION_EXTRAPOLATION_LIMIT_SECONDS,
		)
	if (
		acknowledged_input <= 0
		or latest_input_sequence <= acknowledged_input
		or input_interval_seconds <= 0.0
	):
		return 0.0
	# The input gap spans approximately the full round trip: from the input
	# acknowledged by the host to the newest input at snapshot receipt. Only
	# half of that interval lies between the host snapshot and the client now.
	var sequence_gap: int = latest_input_sequence - acknowledged_input
	return minf(
		float(sequence_gap)
		* input_interval_seconds
		* LOCAL_PREDICTION_FALLBACK_TRANSIT_RATIO,
		LOCAL_PREDICTION_EXTRAPOLATION_LIMIT_SECONDS,
	)


func apply_network_teleport(snapshot: Dictionary) -> void:
	var parsed: Dictionary = _parse_network_snapshot(snapshot)
	if parsed.is_empty():
		return
	global_position = parsed["position"]
	velocity = parsed["velocity"]
	_visuals.rotation.y = parsed["visual_yaw"]
	_apply_network_casting(bool(parsed["casting"]))
	_set_sitting(bool(parsed["sitting"]))
	_network_target_position = global_position
	_network_target_velocity = velocity
	_network_target_visual_yaw = _visuals.rotation.y
	_apply_network_target_animation_state(parsed["animation_state"])
	_network_snapshot_age = 0.0
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
	var animation_state_value: Variant = snapshot.get("animation_state")
	if not NetworkPlayerAnimationProtocol.validate_state(animation_state_value):
		return {}
	var animation_state: Dictionary = (
		animation_state_value as Dictionary
	).duplicate(true)
	if (
		snapshot.has("acknowledged_input")
		and (
			typeof(snapshot.get("acknowledged_input")) != TYPE_INT
			or int(snapshot.get("acknowledged_input")) < 0
		)
	):
		return {}
	var acknowledged_input: int = int(
		snapshot.get("acknowledged_input", 0)
	)
	if snapshot.has("sitting") and typeof(snapshot.get("sitting")) != TYPE_BOOL:
		return {}
	var sitting: bool = bool(snapshot.get("sitting", false))
	if snapshot.has("casting") and typeof(snapshot.get("casting")) != TYPE_BOOL:
		return {}
	var casting: bool = bool(snapshot.get("casting", false))
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
		"animation_state": animation_state,
		"acknowledged_input": acknowledged_input,
		"sitting": sitting,
		"casting": casting,
	}


func _make_animation_action_state() -> Dictionary:
	return NetworkPlayerAnimationProtocol.make_action_state(
		_animation_action_id,
		_animation_action_sequence,
		_animation_action_elapsed,
	)


func _apply_network_target_animation_state(state: Dictionary) -> void:
	if not NetworkPlayerAnimationProtocol.validate_state(state):
		return
	_network_target_grounded = bool(state["grounded"])
	_network_target_locomotion_state = _locomotion_state_from_id(
		StringName(str(state["locomotion_id"]))
	)
	var action: Dictionary = state["action"]
	_network_target_animation_action_id = StringName(str(action["id"]))
	_network_target_animation_action_sequence = int(action["sequence"])
	_network_target_animation_action_elapsed = float(action["elapsed"])


func _get_authoritative_locomotion_state() -> LocomotionState:
	if (
		_network_authoritative_simulation
		and _is_movement_input_enabled()
		and not _water_recovery_active
		and not _sitting
		and _network_axis.length_squared() > 0.0025
	):
		return (
			LocomotionState.RUNNING
			if _network_sprint
			else LocomotionState.WALKING
		)
	return _locomotion_state_from_velocity()


func _get_authoritative_locomotion_id() -> StringName:
	return _locomotion_id_from_state(_get_authoritative_locomotion_state())


func _get_presented_locomotion_state() -> LocomotionState:
	if _network_interpolation_enabled and _network_snapshot_ready:
		return _network_target_locomotion_state
	return _locomotion_state_from_velocity()


func _get_presented_animation_action() -> Dictionary:
	if _network_interpolation_enabled and _network_snapshot_ready:
		return NetworkPlayerAnimationProtocol.make_action_state(
			_network_target_animation_action_id,
			_network_target_animation_action_sequence,
			minf(
				_network_target_animation_action_elapsed + _network_snapshot_age,
				NetworkPlayerAnimationProtocol.MAX_ACTION_ELAPSED_SECONDS,
			),
		)
	return _make_animation_action_state()


func _locomotion_id_from_state(state: LocomotionState) -> StringName:
	match state:
		LocomotionState.WALKING:
			return NetworkPlayerAnimationProtocol.LOCOMOTION_WALKING
		LocomotionState.RUNNING:
			return NetworkPlayerAnimationProtocol.LOCOMOTION_RUNNING
		_:
			return NetworkPlayerAnimationProtocol.LOCOMOTION_IDLE


func _locomotion_state_from_id(state_id: StringName) -> LocomotionState:
	match state_id:
		NetworkPlayerAnimationProtocol.LOCOMOTION_WALKING:
			return LocomotionState.WALKING
		NetworkPlayerAnimationProtocol.LOCOMOTION_RUNNING:
			return LocomotionState.RUNNING
		_:
			return LocomotionState.IDLE


static func supports_network_animation_action(action_id: StringName) -> bool:
	return action_id in NETWORK_ANIMATION_ACTION_IDS


func _locomotion_state_from_velocity() -> LocomotionState:
	var horizontal_speed_squared: float = (
		velocity.x * velocity.x + velocity.z * velocity.z
	)
	if horizontal_speed_squared <= 0.0025:
		return LocomotionState.IDLE
	var fastest_non_sprint_speed := maxf(
		walk_speed,
		maxf(sneak_speed, slow_walk_speed)
	)
	var running_threshold := fastest_non_sprint_speed + 0.5
	if horizontal_speed_squared > running_threshold * running_threshold:
		return LocomotionState.RUNNING
	return LocomotionState.WALKING


func _get_presented_grounded() -> bool:
	if _network_interpolation_enabled and _network_snapshot_ready:
		return _network_target_grounded
	return is_on_floor()


func _apply_network_casting(casting: bool) -> void:
	if casting:
		if _fishing_visual_phase == FishingVisualPhase.NONE:
			set_casting_visual()
	elif _fishing_visual_phase == FishingVisualPhase.CASTING:
		set_fishing_visual(false)


func _update_network_interpolation(delta: float) -> void:
	if not _network_snapshot_ready:
		return
	var previous_snapshot_age: float = _network_snapshot_age
	_network_snapshot_age = minf(
		_network_snapshot_age + delta,
		NETWORK_EXTRAPOLATION_LIMIT_SECONDS,
	)
	var extrapolation_delta: float = (
		_network_snapshot_age - previous_snapshot_age
	)
	var predicted_position: Vector3 = (
		_network_target_position
		+ _network_target_velocity * _network_snapshot_age
	)
	var projected_position: Vector3 = (
		global_position + _network_target_velocity * extrapolation_delta
	)
	if projected_position.distance_to(predicted_position) > 2.0:
		global_position = predicted_position
	else:
		var jitter_ratio: float = clampf(
			_network_snapshot_jitter
			/ NETWORK_SNAPSHOT_JITTER_LIMIT_SECONDS,
			0.0,
			1.0,
		)
		var smoothing_rate: float = lerpf(
			NETWORK_REMOTE_SMOOTHING_RATE,
			NETWORK_REMOTE_JITTER_SMOOTHING_RATE,
			jitter_ratio,
		)
		global_position = projected_position.lerp(
			predicted_position,
			1.0 - exp(-smoothing_rate * delta)
		)
	velocity = _network_target_velocity
	_visuals.rotation.y = lerp_angle(
		_visuals.rotation.y,
		_network_target_visual_yaw,
		1.0 - exp(-14.0 * delta)
	)


func _update_network_input_freshness(delta: float) -> void:
	_network_input_age = minf(
		_network_input_age + delta,
		NETWORK_INPUT_STALE_TIMEOUT_SECONDS + 1.0,
	)
	if (
		_network_input_stale
		or _network_input_age <= NETWORK_INPUT_STALE_TIMEOUT_SECONDS
	):
		return
	_network_input_stale = true
	_network_axis = Vector2.ZERO
	_network_jump_pending = false
	_network_sprint = false
	_network_sneak = false
	_network_slow_walk = false


func _queue_local_network_jump_intent() -> void:
	if _local_network_jump_intent_pending:
		return
	_local_network_jump_intent_pending = true
	_local_network_jump_intent_sequence = -1


func _clear_local_network_jump_intent() -> void:
	_local_network_jump_intent_pending = false
	_local_network_jump_intent_sequence = -1


func is_local_control_enabled() -> bool:
	return local_control_enabled


func is_sneaking() -> bool:
	if local_control_enabled:
		return (
			_is_movement_input_enabled()
			and Input.is_action_pressed("sneak")
		)
	return _network_sneak


func is_moving_horizontally() -> bool:
	return Vector2(velocity.x, velocity.z).length_squared() > 0.01


func set_movement_enabled(enabled: bool) -> void:
	_movement_enabled = enabled
	if not enabled:
		velocity.x = 0.0
		velocity.z = 0.0


func is_movement_enabled() -> bool:
	return _movement_enabled


func set_local_input_suppressed(owner: StringName, suppressed: bool) -> void:
	if owner.is_empty():
		return
	if suppressed:
		_local_input_suppressors[owner] = true
		velocity.x = 0.0
		velocity.z = 0.0
		_set_camera_dragging(false)
	else:
		_local_input_suppressors.erase(owner)


func _is_movement_input_enabled() -> bool:
	return _movement_enabled and _local_input_suppressors.is_empty()


func _is_camera_input_enabled() -> bool:
	return _camera_input_enabled and _local_input_suppressors.is_empty()


func set_camera_input_enabled(enabled: bool) -> void:
	_camera_input_enabled = enabled
	if not enabled:
		_set_camera_dragging(false)


func set_camera_active(active: bool) -> void:
	if _free_camera_active and _free_camera != null:
		_free_camera.current = active
	else:
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


func set_active_fishing_rod(
	rod: FishingRodDataType,
	animate_transition: bool = false,
) -> void:
	_apply_fishing_rod_model(rod)
	set_active_item_is_rod(rod != null and rod.is_available(), animate_transition)


func set_active_catching_net(should_show: bool) -> void:
	_active_item_is_net = should_show
	if _catching_net == null:
		return
	if _showcase_rod_state_stored:
		_showcase_net_visibility = should_show
		return
	_catching_net.visible = (
		should_show and not _has_held_show_item() and not _showcase_animation_active
	)


func _apply_fishing_rod_model(rod: FishingRodDataType) -> void:
	var next_id: StringName = rod.item_id if rod != null else StringName()
	if next_id == _active_fishing_rod_id:
		return
	_active_fishing_rod_id = next_id
	if _custom_fishing_rod_visual != null:
		_custom_fishing_rod_visual.hide()
		_custom_fishing_rod_visual.queue_free()
		_custom_fishing_rod_visual = null
	if _fishing_rod_fallback_visual == null or _fishing_rod_tip == null:
		return
	_fishing_rod_fallback_visual.show()
	_fishing_rod_tip.position = Vector3(0.0, 1.1, 0.0)
	if rod == null:
		return
	_fishing_rod_tip.position = rod.rod_tip_position
	if rod.rod_model_scene == null or _fishing_rod_model_mount == null:
		return
	var instance := rod.rod_model_scene.instantiate() as Node3D
	if instance == null:
		push_warning(
			"Rod %s model root is not Node3D; using fallback."
			% rod.item_id
		)
		return
	_custom_fishing_rod_visual = instance
	_fishing_rod_model_mount.add_child(instance)
	instance.transform = rod.rod_model_transform
	_fishing_rod_fallback_visual.hide()


func set_active_item_is_rod(
	active_is_rod: bool,
	animate_transition: bool = false,
) -> void:
	_active_item_is_rod = active_is_rod
	if _showcase_rod_state_stored:
		_showcase_rod_visibility = active_is_rod
		return
	var visibility_changed: bool = _fishing_rod.visible != active_is_rod
	if not animate_transition or not visibility_changed:
		_fishing_rod.visible = active_is_rod
		return
	if _has_held_show_item() or _showcase_animation_active:
		if not active_is_rod:
			_fishing_rod.visible = false
		return
	if active_is_rod:
		_fishing_rod.visible = false
	_begin_pocket_visual(
		PocketVisualTarget.IDLE_ITEM,
		false,
		false,
		_apply_active_rod_visibility,
	)


func _apply_active_rod_visibility() -> void:
	if _showcase_rod_state_stored:
		_showcase_rod_visibility = _active_item_is_rod
		return
	_fishing_rod.visible = _active_item_is_rod
	if _catching_net != null:
		_catching_net.visible = (
			_active_item_is_net
			and not _has_held_show_item()
			and not _showcase_animation_active
		)


func set_active_art_kit(icon: Texture2D, should_show: bool) -> void:
	var new_visible: bool = should_show and icon != null
	if not new_visible:
		if _held_art_kit_visible:
			_begin_pocket_visual(
				PocketVisualTarget.ART_KIT,
				true,
				_held_fish_visible,
				_clear_active_art_kit,
				true,
				_apply_pending_held_fish,
			)
		else:
			_clear_active_art_kit()
		return
	var previous_show_pose: bool = _has_held_show_item()
	var item_changed: bool = (
		not _held_art_kit_visible
		or _held_art_kit_sprite.texture != icon
	)
	_held_art_kit_visible = true
	_held_art_kit_sprite.texture = icon
	_held_art_kit_sprite.visible = true
	if not previous_show_pose:
		_held_art_kit_display.visible = false
	_fishing_rod.visible = false
	if _catching_net != null:
		_catching_net.visible = false
	if item_changed:
		_begin_pocket_visual(
			PocketVisualTarget.ART_KIT,
			previous_show_pose,
			true,
			Callable(),
			false,
			_apply_active_art_kit_visual,
		)
	else:
		_apply_active_art_kit_visual()
		_update_character_animation()


func set_held_fish(
	fish: FishDataType,
	display_scale: float,
	should_show: bool,
	animate_put_away: bool = false,
) -> void:
	if not should_show or fish == null or fish.display_texture == null:
		if animate_put_away and _held_fish_visible:
			_begin_pocket_visual(
				PocketVisualTarget.HELD_FISH,
				true,
				_held_art_kit_visible,
				_clear_held_fish,
			)
		else:
			if _pocket_visual_target == PocketVisualTarget.HELD_FISH:
				_cancel_pocket_visual()
			_clear_held_fish()
		return
	var previous_show_pose: bool = _has_held_show_item()
	var item_changed: bool = (
		not _held_fish_visible
		or _held_fish_sprite.texture != fish.display_texture
	)
	_held_fish_visible = true
	_pending_held_fish_texture = fish.display_texture
	_pending_held_fish_scale = (
		Vector3.ONE
		* maxf(display_scale, 0.01)
		* catch_presentation_base_scale
	)
	if not previous_show_pose:
		_held_fish_display.visible = false
	_fishing_rod.visible = false
	if _catching_net != null:
		_catching_net.visible = false
	if item_changed:
		_begin_pocket_visual(
			PocketVisualTarget.HELD_FISH,
			previous_show_pose,
			true,
			Callable(),
			false,
			_apply_pending_held_fish,
		)
	else:
		_apply_pending_held_fish()
		_update_character_animation()


func _has_held_show_item() -> bool:
	return _held_fish_visible or _held_art_kit_visible


func _clear_held_fish() -> void:
	var was_visible: bool = _held_fish_visible
	_held_fish_visible = false
	_pending_held_fish_texture = null
	_pending_held_fish_scale = Vector3.ONE
	_held_fish_display.visible = false
	_held_fish_display.scale = Vector3.ONE
	_held_fish_sprite.texture = null
	if was_visible:
		_apply_active_rod_visibility()
	_update_character_animation()


func _apply_pending_held_fish() -> void:
	if not _held_fish_visible or _pending_held_fish_texture == null:
		return
	_held_fish_sprite.texture = _pending_held_fish_texture
	_held_fish_display.scale = _pending_held_fish_scale
	_held_fish_display.visible = true


func _clear_active_art_kit() -> void:
	var was_visible: bool = _held_art_kit_visible
	_held_art_kit_visible = false
	_held_art_kit_display.visible = false
	_held_art_kit_sprite.texture = null
	_held_art_kit_sprite.visible = false
	if was_visible:
		_apply_active_rod_visibility()
		if _held_fish_visible:
			_apply_pending_held_fish()
	_update_character_animation()


func _apply_active_art_kit_visual() -> void:
	if not _held_art_kit_visible or _held_art_kit_sprite.texture == null:
		return
	_held_art_kit_display.visible = true


func _begin_pocket_visual(
	target: PocketVisualTarget,
	starts_in_show_pose: bool,
	ends_in_show_pose: bool,
	finished_callback: Callable,
	callback_runs_on_interrupt: bool = true,
	midpoint_callback: Callable = Callable(),
) -> void:
	var animation_name: StringName
	if _sitting:
		if starts_in_show_pose:
			animation_name = (
				CHARACTER_POCKET_SIT_SHOW_SHOW_ANIMATION
				if ends_in_show_pose
				else CHARACTER_POCKET_SIT_SHOW_IDLE_ANIMATION
			)
		else:
			animation_name = (
				CHARACTER_POCKET_SIT_IDLE_SHOW_ANIMATION
				if ends_in_show_pose
				else CHARACTER_POCKET_SIT_IDLE_IDLE_ANIMATION
			)
	elif _is_moving_for_pocket_visual():
		if starts_in_show_pose:
			animation_name = (
				CHARACTER_POCKET_WALKING_SHOW_SHOW_ANIMATION
				if ends_in_show_pose
				else CHARACTER_POCKET_WALKING_SHOW_IDLE_ANIMATION
			)
		else:
			animation_name = (
				CHARACTER_POCKET_WALKING_IDLE_SHOW_ANIMATION
				if ends_in_show_pose
				else CHARACTER_POCKET_WALKING_IDLE_IDLE_ANIMATION
			)
	elif starts_in_show_pose:
		animation_name = (
			CHARACTER_POCKET_SHOW_SHOW_ANIMATION
			if ends_in_show_pose
			else CHARACTER_POCKET_SHOW_IDLE_ANIMATION
		)
	else:
		animation_name = (
			CHARACTER_POCKET_IDLE_SHOW_ANIMATION
			if ends_in_show_pose
			else CHARACTER_POCKET_IDLE_IDLE_ANIMATION
		)
	if _pocket_visual_active:
		if (
			_pocket_visual_target == target
			and _pocket_visual_animation == animation_name
		):
			return
		if _pocket_visual_callback_runs_on_interrupt:
			_complete_pocket_visual()
		else:
			_cancel_pocket_visual()
	if (
		animation_name.is_empty()
		or _character_animation_player == null
		or not _character_animation_player.has_animation(animation_name)
	):
		if midpoint_callback.is_valid():
			midpoint_callback.call()
		if finished_callback.is_valid():
			finished_callback.call()
		_update_character_animation()
		return
	_pocket_visual_active = true
	_pocket_visual_target = target
	_pocket_visual_animation = animation_name
	_pocket_visual_finished_callback = finished_callback
	_pocket_visual_callback_runs_on_interrupt = callback_runs_on_interrupt
	_pocket_visual_midpoint_callback = midpoint_callback
	_pocket_visual_midpoint_called = false
	_pocket_visual_generation += 1
	var midpoint_generation: int = _pocket_visual_generation
	_update_character_animation()
	_schedule_pocket_visual_midpoint(midpoint_generation, animation_name)


func _is_moving_for_pocket_visual() -> bool:
	var horizontal_velocity := Vector2(velocity.x, velocity.z)
	return horizontal_velocity.length_squared() > 0.0025


func _schedule_pocket_visual_midpoint(
	generation: int,
	animation_name: StringName,
) -> void:
	if not _pocket_visual_midpoint_callback.is_valid():
		return
	var animation: Animation = _character_animation_player.get_animation(
		animation_name
	)
	var midpoint_seconds: float = maxf(animation.length * 0.5, 0.0)
	if midpoint_seconds > 0.0:
		await get_tree().create_timer(midpoint_seconds, false).timeout
	if (
		generation != _pocket_visual_generation
		or not _pocket_visual_active
		or _pocket_visual_animation != animation_name
	):
		return
	_apply_pocket_visual_midpoint()


func _apply_pocket_visual_midpoint() -> void:
	if _pocket_visual_midpoint_called:
		return
	_pocket_visual_midpoint_called = true
	var midpoint_callback: Callable = _pocket_visual_midpoint_callback
	_pocket_visual_midpoint_callback = Callable()
	if midpoint_callback.is_valid():
		midpoint_callback.call()


func _complete_pocket_visual() -> void:
	if not _pocket_visual_active:
		return
	var finished_callback: Callable = _pocket_visual_finished_callback
	_pocket_visual_active = false
	_pocket_visual_target = PocketVisualTarget.NONE
	_pocket_visual_animation = &""
	_pocket_visual_finished_callback = Callable()
	_pocket_visual_callback_runs_on_interrupt = true
	_pocket_visual_midpoint_callback = Callable()
	_pocket_visual_midpoint_called = false
	_pocket_visual_generation += 1
	if finished_callback.is_valid():
		finished_callback.call()
	_update_character_animation()


func _cancel_pocket_visual() -> void:
	_pocket_visual_active = false
	_pocket_visual_target = PocketVisualTarget.NONE
	_pocket_visual_animation = &""
	_pocket_visual_finished_callback = Callable()
	_pocket_visual_callback_runs_on_interrupt = true
	_pocket_visual_midpoint_callback = Callable()
	_pocket_visual_midpoint_called = false
	_pocket_visual_generation += 1


func get_cast_origin_position() -> Vector3:
	return _cast_origin.global_position


func begin_catch_showcase(fish_catch: FishCatchType) -> void:
	if fish_catch == null or not fish_catch.is_valid():
		return
	if _pocket_visual_target == PocketVisualTarget.CATCH_SHOWCASE:
		_cancel_pocket_visual()
	_showcase_animation_active = true
	set_fishing_visual(false)
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
		_showcase_net_visibility = (
			_catching_net.visible if _catching_net != null else false
		)
		_showcase_rod_state_stored = true
	_fishing_rod.visible = false
	if _catching_net != null:
		_catching_net.visible = false
	_catch_sprite.texture = fish_catch.fish.display_texture
	_catch_display.scale = (
		Vector3.ONE
		* fish_catch.display_scale
		* catch_presentation_base_scale
	)
	_catch_display.visible = _catch_sprite.texture != null
	_update_character_animation()


func begin_remote_catch_showcase(fish_catch: FishCatchType) -> void:
	if local_control_enabled or fish_catch == null or not fish_catch.is_valid():
		return
	end_catch_showcase(Callable(), true)
	_showcase_animation_active = true
	set_fishing_visual(false)
	_showcase_rod_visibility = _fishing_rod.visible
	_showcase_net_visibility = (
		_catching_net.visible if _catching_net != null else false
	)
	_showcase_rod_state_stored = true
	_fishing_rod.visible = false
	if _catching_net != null:
		_catching_net.visible = false
	_catch_sprite.texture = fish_catch.fish.display_texture
	_catch_display.scale = (
		Vector3.ONE
		* fish_catch.display_scale
		* catch_presentation_base_scale
	)
	_catch_display.visible = _catch_sprite.texture != null
	_update_character_animation()


func end_catch_showcase(
	restored_callback: Callable = Callable(),
	immediate: bool = false,
	pocket_completed: bool = false,
) -> void:
	if immediate and _pocket_visual_target == PocketVisualTarget.CATCH_SHOWCASE:
		_cancel_pocket_visual()
	elif (
		not pocket_completed
		and _showcase_animation_active
		and _catch_display.visible
	):
		_begin_pocket_visual(
			PocketVisualTarget.CATCH_SHOWCASE,
			true,
			false,
			end_catch_showcase.bind(restored_callback, false, true),
		)
		return
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
		if _catching_net != null:
			_catching_net.visible = _showcase_net_visibility
	_showcase_rod_visibility = true
	_showcase_net_visibility = false
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
		_set_camera_dragging(
			_showcase_camera_snapshot.camera_dragging
			and Input.is_action_pressed("camera_drag")
		)
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
	_set_camera_dragging(false)


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
