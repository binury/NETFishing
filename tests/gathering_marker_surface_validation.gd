extends SceneTree

const PlayerScene: PackedScene = preload("res://player/player.tscn")
const GatheringControllerType = preload(
	"res://gathering/gathering_controller.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := PlayerScene.instantiate() as Player
	root.add_child(player)
	player.set_process(false)
	player.set_physics_process(false)

	var controller := GatheringControllerType.new()
	root.add_child(controller)
	controller.set("_player", player)

	var wall := _make_surface(
		Vector3(2.0, 2.0, 0.1),
		Vector3(0.0, 0.9, -1.5),
	)
	root.add_child(wall)
	await physics_frame
	controller.call("_update_marker_target")
	var marker := controller.get("_marker") as MeshInstance3D
	assert(marker != null)
	assert(bool(controller.get("_marker_has_surface")))
	assert(marker.global_basis.y.dot(Vector3.BACK) > 0.99)

	wall.queue_free()
	await process_frame
	var floor := _make_surface(
		Vector3(10.0, 0.2, 10.0),
		Vector3(0.0, -0.1, -1.7),
	)
	root.add_child(floor)
	await physics_frame
	controller.call("_update_marker_target")
	assert(bool(controller.get("_marker_has_surface")))
	assert(marker.global_basis.y.dot(Vector3.UP) > 0.99)
	assert(is_equal_approx(absf(marker.global_basis.determinant()), 1.0))

	floor.queue_free()
	controller.queue_free()
	player.queue_free()
	await process_frame
	print("Gathering marker surface validation: PASS")
	quit()


func _make_surface(size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body
