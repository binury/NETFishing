extends SceneTree

const NetAttachmentScene: PackedScene = preload(
	"res://player/net_attachment.tscn"
)
const FishingRodAttachmentScene: PackedScene = preload(
	"res://player/fishing_rod_attachment.tscn"
)

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var host_skeleton := Skeleton3D.new()
	host_skeleton.name = "HostSkeleton"
	host_skeleton.add_bone("rod_socket")
	host_skeleton.add_bone("rod_socket.001")
	host_skeleton.set_bone_parent(1, 0)
	host_skeleton.set_bone_rest(
		1,
		Transform3D(
			Basis(Quaternion(Vector3.UP, Vector3.RIGHT)),
			Vector3(0.0, 0.25, 0.0),
		),
	)
	root.add_child(host_skeleton)

	var attachment := NetAttachmentScene.instantiate() as BoneAttachment3D
	host_skeleton.add_child(attachment)
	await process_frame
	await process_frame

	_check(
		attachment.bone_name == "rod_socket",
		"Attachment moved off rod_socket.",
	)
	var catching_net := attachment.get_node_or_null("CatchingNet") as Node3D
	_check(catching_net != null, "CatchingNet presentation root is missing.")
	if catching_net == null:
		_finish(host_skeleton)
		return
	_check(not catching_net.visible, "Net must start hidden.")
	_check(
		catching_net.position.is_zero_approx(),
		"Net direction alignment moved its hand anchor.",
	)
	_check(
		catching_net.basis.y.is_equal_approx(Vector3.UP),
		"Net working axis no longer follows rod_socket.",
	)
	_check(
		catching_net.basis.z.is_equal_approx(Vector3.RIGHT),
		"Net rear face did not follow the socket direction guide.",
	)

	var model := catching_net.get_node_or_null("ModelMount/NetModel") as Node3D
	_check(model != null, "Imported net model is missing.")
	if model == null:
		_finish(host_skeleton)
		return
	var skeleton := model.find_child("Skeleton3D", true, false) as Skeleton3D
	_check(skeleton != null, "Imported net Skeleton3D is missing.")
	if skeleton == null:
		_finish(host_skeleton)
		return
	_check(
		skeleton.find_bone("net_root") >= 0,
		"Imported net_root bone is missing.",
	)
	_check(
		skeleton.find_bone("net_rim") >= 0,
		"Imported net_rim bone is missing.",
	)
	_check(
		skeleton.find_bone("net_mid") >= 0,
		"Imported net_mid bone is missing.",
	)
	_check(
		skeleton.find_bone("net_tip") >= 0,
		"Imported net_tip bone is missing.",
	)

	var spring := skeleton.get_node_or_null("NetSpring") as SpringBoneSimulator3D
	_check(spring != null, "Net spring simulator was not created.")
	if spring != null:
		_check(spring.get_setting_count() == 1, "Net spring settings changed.")
		_check(
			spring.get_root_bone_name(0) == &"net_mid",
			"Net spring root must remain net_mid.",
		)
		_check(
			spring.get_end_bone_name(0) == &"net_tip",
			"Net spring end must remain net_tip.",
		)
		_check(not spring.active, "Hidden net spring must be suspended.")
		catching_net.visible = true
		await process_frame
		await process_frame
		_check(spring.active, "Visible net spring must be active.")
		_check(spring.get_joint_count(0) == 2, "Net spring chain is incomplete.")
		catching_net.visible = false
		await process_frame
		_check(not spring.active, "Hidden net spring did not suspend.")

	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := child as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index: int in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface_index)
			if material is BaseMaterial3D:
				_check(
					(material as BaseMaterial3D).texture_filter
						== BaseMaterial3D.TEXTURE_FILTER_NEAREST,
					"Net material does not use nearest texture sampling.",
				)

	var rod_attachment := (
		FishingRodAttachmentScene.instantiate() as BoneAttachment3D
	)
	host_skeleton.add_child(rod_attachment)
	await process_frame
	var fishing_rod := rod_attachment.get_node("FishingRod") as Node3D
	_check(
		fishing_rod.position.is_zero_approx(),
		"Rod direction alignment moved its hand anchor.",
	)
	_check(
		fishing_rod.basis.y.is_equal_approx(Vector3.UP),
		"Rod working axis no longer follows rod_socket.",
	)
	_check(
		fishing_rod.basis.z.is_equal_approx(Vector3.RIGHT),
		"Rod rear face did not follow the socket direction guide.",
	)

	_finish(host_skeleton)


func _finish(host_skeleton: Skeleton3D) -> void:
	host_skeleton.queue_free()
	if failures.is_empty():
		print("Net attachment validation: PASS")
		quit(0)
		return
	for failure: String in failures:
		printerr("Net attachment validation: ", failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
