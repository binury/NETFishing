class_name ToolSocketAttachment
extends BoneAttachment3D

@export var direction_guide_bone: StringName = &"rod_socket.001"
@export_node_path("Node3D") var aligned_mount_path: NodePath


func _ready() -> void:
	_align_mount_to_direction_guide()


func _align_mount_to_direction_guide() -> void:
	var skeleton := get_parent() as Skeleton3D
	var mount := get_node_or_null(aligned_mount_path) as Node3D
	if skeleton == null or mount == null:
		push_error("Tool socket alignment requires a Skeleton3D parent and mount.")
		return
	var socket_index := skeleton.find_bone(bone_name)
	var guide_index := skeleton.find_bone(direction_guide_bone)
	if socket_index < 0 or guide_index < 0:
		push_error(
			"Tool socket alignment is missing %s or %s."
			% [bone_name, direction_guide_bone]
		)
		return
	if skeleton.get_bone_parent(guide_index) != socket_index:
		push_error(
			"Tool direction guide %s must be a child of %s."
			% [direction_guide_bone, bone_name]
		)
		return
	var socket_rest := skeleton.get_bone_global_rest(socket_index)
	var guide_rest := skeleton.get_bone_global_rest(guide_index)
	var guide_in_socket := socket_rest.affine_inverse() * guide_rest
	var rear_direction := guide_in_socket.basis.y.normalized()
	# rod_socket already aims local +Y from the hand toward the working end.
	# Its child guide is perpendicular to that axis and identifies which face
	# of the held tool points rearward. Projecting it onto the roll plane keeps
	# imperfect authored guides from changing the tool's lengthwise direction.
	rear_direction -= Vector3.UP * rear_direction.dot(Vector3.UP)
	if rear_direction.is_zero_approx():
		push_error("Tool direction guide has no usable direction.")
		return
	rear_direction = rear_direction.normalized()
	var rear_roll := Vector3.BACK.signed_angle_to(
		rear_direction,
		Vector3.UP,
	)
	var mount_transform := mount.transform
	mount_transform.basis = (
		Basis(Vector3.UP, rear_roll).orthonormalized()
		* mount_transform.basis
	)
	# The guide starts at the socket tip, but the held tool must remain anchored
	# at the socket origin in the hand. Only its authored direction is applied.
	mount_transform.origin = mount.transform.origin
	mount.transform = mount_transform
