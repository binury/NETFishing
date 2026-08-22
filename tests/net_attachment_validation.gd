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

	var handle := catching_net.get_node_or_null("Handle") as MeshInstance3D
	var hoop := catching_net.get_node_or_null("Hoop") as MeshInstance3D
	var bag := catching_net.get_node_or_null("Bag") as MeshInstance3D
	var impact_marker := (
		catching_net.get_node_or_null("ImpactMarker") as Marker3D
	)
	_check(handle != null and handle.mesh != null, "Placeholder handle is missing.")
	_check(hoop != null and hoop.mesh != null, "Placeholder hoop is missing.")
	_check(bag != null and bag.mesh != null, "Placeholder net bag is missing.")
	_check(impact_marker != null, "Net impact marker is missing.")
	if impact_marker != null:
		_check(
			attachment.get_impact_world_position().is_equal_approx(
				impact_marker.global_position
			),
			"Net impact position moved away from its marker.",
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
