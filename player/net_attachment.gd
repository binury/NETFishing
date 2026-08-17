extends "res://player/tool_socket_attachment.gd"

const TextureSamplingPolicyScript := preload(
	"res://main/texture_sampling_policy.gd"
)
const SPRING_ROOT_BONE: StringName = &"net_mid"
const SPRING_END_BONE: StringName = &"net_tip"
const IMPACT_BONE: StringName = &"net_rim"

@export_range(0.0, 10.0, 0.05) var spring_stiffness: float = 1.8
@export_range(0.0, 1.0, 0.01) var spring_drag: float = 0.68
@export_range(0.0, 10.0, 0.05) var spring_gravity: float = 0.3
@export_range(0.01, 0.5, 0.01) var spring_end_length: float = 0.1

@onready var _catching_net: Node3D = %CatchingNet
@onready var _net_model: Node3D = %NetModel

var _spring: SpringBoneSimulator3D
var _spring_was_visible: bool = false
var _net_skeleton: Skeleton3D


func _ready() -> void:
	super._ready()
	TextureSamplingPolicyScript.enforce_subtree(_net_model)
	_configure_spring()
	_sync_spring_activity()


func _process(_delta: float) -> void:
	_sync_spring_activity()


func _configure_spring() -> void:
	_net_skeleton = _net_model.find_child(
		"Skeleton3D", true, false
	) as Skeleton3D
	if _net_skeleton == null:
		push_error("Imported net model is missing its Skeleton3D.")
		return
	if _net_skeleton.find_bone(SPRING_ROOT_BONE) < 0:
		push_error("Imported net model is missing bone %s." % SPRING_ROOT_BONE)
		return
	if _net_skeleton.find_bone(SPRING_END_BONE) < 0:
		push_error("Imported net model is missing bone %s." % SPRING_END_BONE)
		return
	if _net_skeleton.find_bone(IMPACT_BONE) < 0:
		push_error("Imported net model is missing bone %s." % IMPACT_BONE)
		return

	_spring = SpringBoneSimulator3D.new()
	_spring.name = "NetSpring"
	_spring.set_setting_count(1)
	_spring.set_root_bone_name(0, SPRING_ROOT_BONE)
	_spring.set_end_bone_name(0, SPRING_END_BONE)
	_spring.set_extend_end_bone(0, true)
	_spring.set_end_bone_direction(
		0, SkeletonModifier3D.BONE_DIRECTION_FROM_PARENT
	)
	_spring.set_end_bone_length(0, spring_end_length)
	_spring.set_stiffness(0, spring_stiffness)
	_spring.set_drag(0, spring_drag)
	_spring.set_gravity(0, spring_gravity)
	_spring.set_gravity_direction(0, Vector3.DOWN)
	_net_skeleton.add_child(_spring)


func get_impact_world_position() -> Vector3:
	if _net_skeleton == null:
		return _catching_net.global_position
	var impact_bone_index := _net_skeleton.find_bone(IMPACT_BONE)
	if impact_bone_index < 0:
		return _catching_net.global_position
	return _net_skeleton.global_transform * (
		_net_skeleton.get_bone_global_pose(impact_bone_index).origin
	)


func _sync_spring_activity() -> void:
	if _spring == null:
		return
	var is_visible := _catching_net.is_visible_in_tree()
	if is_visible and not _spring_was_visible:
		_spring.active = true
		_spring.reset()
	elif not is_visible:
		_spring.active = false
	_spring_was_visible = is_visible
