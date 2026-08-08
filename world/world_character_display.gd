class_name WorldCharacterDisplay
extends Node3D

const CharacterCustomizationCatalogType = preload(
	"res://progression/character_customization_catalog.gd"
)
const PlayerVisualPresenterType = preload(
	"res://player/player_visual_presenter.gd"
)

@export_enum("round", "pointy") var species_id: String = "round"
@export_enum(
	"white",
	"gray",
	"charcoal",
	"brown",
	"orange",
	"yellow",
	"green",
	"teal",
) var fur_color_id: String = "white"
@export_enum(
	"none",
	"pointy_long",
	"pointy_short",
	"pointy_wide",
) var ears_id: String = "none"
@export var eyes_id: String = "simple_shine"
@export var nose_id: String = "dog_round"
@export var mouth_id: String = "three"
@export_category("Head Look")
@export var head_look_enabled: bool = false
@export_range(0.5, 10.0, 0.1, "suffix:m") var head_look_distance: float = 4.0
@export_range(0.5, 3.0, 0.05, "suffix:m") var look_target_height: float = 1.25
@export_range(0.0, 80.0, 1.0, "degrees") var head_yaw_limit: float = 50.0
@export_range(0.0, 45.0, 1.0, "degrees") var head_pitch_limit: float = 22.0
@export_range(0.05, 2.0, 0.05, "suffix:s") var head_blend_seconds: float = 0.3

var _head_look: LookAtModifier3D
var _skeleton: Skeleton3D
var _look_target: Node3D
var _look_target_proxy: Node3D
var _head_look_requested: bool = false


func _ready() -> void:
	var appearance := CharacterCustomizationCatalogType.default_snapshot()
	appearance["species"] = species_id
	appearance["fur_pattern"] = fur_color_id
	appearance["ears"] = ears_id
	appearance["eyes"] = eyes_id
	appearance["nose"] = nose_id
	appearance["mouth"] = mouth_id
	PlayerVisualPresenterType.apply_appearance(self, appearance)
	_prepare_head_look()


func _process(delta: float) -> void:
	if _head_look == null or _look_target_proxy == null:
		return
	var target_is_valid := (
		_look_target != null and is_instance_valid(_look_target)
	)
	if target_is_valid:
		_look_target_proxy.global_position = (
			_look_target.global_position + Vector3.UP * look_target_height
		)
	var target_influence := (
		1.0 if _head_look_requested and target_is_valid else 0.0
	)
	_head_look.influence = move_toward(
		_head_look.influence,
		target_influence,
		delta / maxf(head_blend_seconds, 0.001),
	)


func set_head_look_target(target: Node3D) -> void:
	_look_target = target


func set_head_look_active(active: bool) -> void:
	_head_look_requested = active


func get_head_anchor_position() -> Vector3:
	if _skeleton == null:
		return global_position + Vector3.UP * 1.8
	var head_index := _skeleton.find_bone("head")
	if head_index < 0:
		return global_position + Vector3.UP * 1.8
	var head_pose := _skeleton.get_bone_global_pose(head_index)
	return (
		(_skeleton.global_transform * head_pose).origin
		+ Vector3.UP * 0.85
	)


func _prepare_head_look() -> void:
	if not head_look_enabled:
		set_process(false)
		return
	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null or _skeleton.find_bone("head") < 0:
		push_warning("World character head-look requires a head bone.")
		set_process(false)
		return
	_look_target_proxy = Node3D.new()
	_look_target_proxy.name = "HeadLookTarget"
	add_child(_look_target_proxy)
	_head_look = LookAtModifier3D.new()
	_head_look.name = "HeadLookModifier"
	_head_look.bone_name = "head"
	_head_look.use_secondary_rotation = true
	_head_look.use_angle_limitation = true
	_head_look.symmetry_limitation = true
	_head_look.primary_limit_angle = deg_to_rad(head_yaw_limit)
	_head_look.secondary_limit_angle = deg_to_rad(head_pitch_limit)
	_head_look.primary_damp_threshold = 0.65
	_head_look.secondary_damp_threshold = 0.65
	_head_look.duration = head_blend_seconds
	_head_look.influence = 0.0
	_head_look.set("origin_from", 1)
	_head_look.set("origin_bone_name", "head")
	_skeleton.add_child(_head_look)
	_head_look.target_node = _head_look.get_path_to(_look_target_proxy)
	set_process(true)
