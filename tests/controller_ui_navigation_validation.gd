extends SceneTree

const ControllerFocusNavigationType = preload(
	"res://ui/controller_focus_navigation.gd"
)
const UIReferencePresentationType = preload(
	"res://ui/ui_reference_presentation.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_validate_spatial_navigation()
	_validate_controller_hierarchy_contract()
	_validate_four_by_three_centering()
	_validate_low_end_profile_contract()
	print("Controller UI navigation validation: PASS")
	quit()


func _validate_spatial_navigation() -> void:
	var host := Control.new()
	root.add_child(host)
	var center := _make_button(host, "center", Vector2(200.0, 200.0))
	var left := _make_button(host, "left", Vector2(50.0, 200.0))
	var right := _make_button(host, "right", Vector2(350.0, 200.0))
	var top := _make_button(host, "top", Vector2(200.0, 50.0))
	var bottom := _make_button(host, "bottom", Vector2(200.0, 350.0))
	var controls: Array[Control] = [center, left, right, top, bottom]
	ControllerFocusNavigationType.configure_spatial_neighbors(controls)
	assert(center.get_node(center.focus_neighbor_left) == left)
	assert(center.get_node(center.focus_neighbor_right) == right)
	assert(center.get_node(center.focus_neighbor_top) == top)
	assert(center.get_node(center.focus_neighbor_bottom) == bottom)
	host.queue_free()


func _validate_controller_hierarchy_contract() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://ui/player_menu.gd"
	)
	assert(source.contains("ROLE_POINTER_MODIFIER"))
	assert(source.contains("ROLE_CAMERA_ZOOM"))
	assert(source.contains("_handle_controller_secondary_switch"))
	assert(source.contains("ROLE_LB"))
	assert(source.contains("ROLE_RB"))
	assert(source.contains("_reserve_main_navigation_for_page_switching"))


func _validate_four_by_three_centering() -> void:
	var stage_position: Vector2 = (
		UIReferencePresentationType.get_stage_position(Vector2(640.0, 480.0))
	)
	assert(stage_position.is_equal_approx(Vector2(0.0, 120.0)))


func _validate_low_end_profile_contract() -> void:
	var launcher: String = FileAccess.get_file_as_string(
		"res://scripts/portmaster/NETfishing.sh"
	)
	assert(launcher.contains("allwinner,h616"))
	assert(launcher.contains("sun50iw9p1"))
	assert(launcher.contains("NETFISHING_LOW_END=1"))
	assert(launcher.contains("--max-fps 30"))
	assert(launcher.contains("--audio-output-latency 40"))


func _make_button(
	host: Control,
	button_name: String,
	button_position: Vector2,
) -> Button:
	var button := Button.new()
	button.name = button_name
	button.position = button_position
	button.size = Vector2(80.0, 80.0)
	button.focus_mode = Control.FOCUS_ALL
	host.add_child(button)
	return button
