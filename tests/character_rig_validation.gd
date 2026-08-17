extends SceneTree


const CHARACTER_SCENE: PackedScene = preload(
	"res://art/exported/characters/base/netfishing_base_character.glb"
)

const EXPECTED_ANIMATIONS: Array[StringName] = [
	&"casting",
	&"casting_sit",
	&"draw",
	&"fighting",
	&"fighting_sit",
	&"fishing",
	&"fishing_sit",
	&"idle",
	&"idle_show",
	&"idle_sit",
	&"idle_sit_show",
	&"idle_sneak",
	&"pocket_idle_idle",
	&"pocket_idle_show",
	&"pocket_show_idle",
	&"pocket_show_show",
	&"pocket_sit_idle_idle",
	&"pocket_sit_idle_show",
	&"pocket_sit_show_idle",
	&"pocket_sit_show_show",
	&"pocket_walking_idle_idle",
	&"pocket_walking_idle_show",
	&"pocket_walking_show_idle",
	&"pocket_walking_show_show",
	&"release",
	&"release_sit",
	&"retract",
	&"retract_sit",
	&"running",
	&"running_show",
	&"sneaking",
	&"strike",
	&"walking",
	&"walking_show",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var character := CHARACTER_SCENE.instantiate()
	root.add_child(character)
	var skeleton := _find_first(character, "Skeleton3D") as Skeleton3D
	var animation_player := _find_first(
		character,
		"AnimationPlayer",
	) as AnimationPlayer
	assert(skeleton != null)
	assert(animation_player != null)

	var socket_index := skeleton.find_bone("rod_socket")
	assert(socket_index >= 0)
	var socket_direction_index := skeleton.find_bone("rod_socket.001")
	assert(socket_direction_index >= 0)
	assert(skeleton.get_bone_parent(socket_direction_index) == socket_index)
	var animation_names := animation_player.get_animation_list()
	assert(animation_names.size() == EXPECTED_ANIMATIONS.size())
	for expected in EXPECTED_ANIMATIONS:
		assert(expected in animation_names, "Missing animation: %s" % expected)
		var animation := animation_player.get_animation(expected)
		if expected in [&"casting", &"draw", &"idle_sneak", &"sneaking", &"strike"]:
			var has_socket_track: bool = false
			for track_index in animation.get_track_count():
				has_socket_track = has_socket_track or String(
					animation.track_get_path(track_index)
				).contains("rod_socket")
			assert(
				has_socket_track,
				"Animation %s lost its authored rod socket pose." % expected,
			)

	var arms := character.find_child(
		"body_arms",
		true,
		false,
	) as MeshInstance3D
	assert(arms != null)
	var blended_arm_vertices := _validate_mesh_weights(arms)
	assert(blended_arm_vertices > 0, "body_arms has no blended joint weights.")
	var body := character.find_child(
		"body_main",
		true,
		false,
	) as MeshInstance3D
	assert(body != null)
	_validate_mesh_weights(body)

	print(
		"Character rig validation: PASS "
		+ "(animations=%d, blended arm vertices=%d)"
		% [EXPECTED_ANIMATIONS.size(), blended_arm_vertices]
	)
	character.queue_free()
	quit()


func _validate_mesh_weights(mesh_instance: MeshInstance3D) -> int:
	var blended_vertices := 0
	for surface_index in mesh_instance.mesh.get_surface_count():
		var arrays := mesh_instance.mesh.surface_get_arrays(surface_index)
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		assert(not weights.is_empty())
		assert(not vertices.is_empty())
		var components_per_vertex := weights.size() / vertices.size()
		assert(components_per_vertex == 4 or components_per_vertex == 8)
		for offset in range(0, weights.size(), components_per_vertex):
			var total := 0.0
			var influence_count := 0
			for component in range(components_per_vertex):
				var weight := weights[offset + component]
				total += weight
				if weight > 0.000001:
					influence_count += 1
			assert(absf(total - 1.0) <= 0.0001)
			assert(influence_count <= 2)
			if influence_count == 2:
				blended_vertices += 1
	return blended_vertices


func _find_first(parent: Node, class_name_to_find: String) -> Node:
	if parent.is_class(class_name_to_find):
		return parent
	for child in parent.get_children():
		var found := _find_first(child, class_name_to_find)
		if found != null:
			return found
	return null
