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
	_validate_strict_directional_navigation()
	_validate_disabled_control_exclusion()
	_validate_traversal_cycle()
	_validate_controller_hierarchy_contract()
	_validate_player_page_zone_contracts()
	_validate_shop_navigation_contract()
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


func _validate_strict_directional_navigation() -> void:
	var host := Control.new()
	root.add_child(host)
	var origin := _make_button(host, "origin", Vector2(200.0, 200.0))
	var mostly_below := _make_button(
		host, "mostly_below", Vector2(250.0, 400.0)
	)
	var controls: Array[Control] = [origin, mostly_below]
	ControllerFocusNavigationType.configure_spatial_neighbors(controls)
	assert(origin.get_node(origin.focus_neighbor_right) == origin)
	assert(origin.get_node(origin.focus_neighbor_top) == origin)
	assert(origin.get_node(origin.focus_neighbor_bottom) == mostly_below)
	host.queue_free()


func _validate_disabled_control_exclusion() -> void:
	var host := Control.new()
	root.add_child(host)
	var left := _make_button(host, "left", Vector2(50.0, 100.0))
	var disabled := _make_button(host, "disabled", Vector2(200.0, 100.0))
	var right := _make_button(host, "right", Vector2(350.0, 100.0))
	disabled.disabled = true
	disabled.focus_next = disabled.get_path_to(right)
	ControllerFocusNavigationType.configure_spatial_neighbors(
		[left, disabled, right]
	)
	assert(left.get_node(left.focus_neighbor_right) == right)
	assert(right.get_node(right.focus_neighbor_left) == left)
	assert(disabled.focus_next.is_empty())
	host.queue_free()


func _validate_traversal_cycle() -> void:
	var host := Control.new()
	root.add_child(host)
	var first := _make_button(host, "first", Vector2(50.0, 50.0))
	var second := _make_button(host, "second", Vector2(200.0, 50.0))
	var third := _make_button(host, "third", Vector2(50.0, 150.0))
	var controls: Array[Control] = [third, first, second]
	ControllerFocusNavigationType.configure_spatial_neighbors(controls)
	assert(first.get_node(first.focus_next) == second)
	assert(second.get_node(second.focus_next) == third)
	assert(third.get_node(third.focus_next) == first)
	assert(first.get_node(first.focus_previous) == third)
	host.queue_free()


func _validate_controller_hierarchy_contract() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://ui/player_menu.gd"
	)
	assert(source.contains("ROLE_LB"))
	assert(source.contains("ROLE_RB"))
	assert(not source.contains("_handle_controller_secondary_switch"))
	assert(source.contains("ControllerOwnership.INVENTORY_TABS"))
	assert(source.contains("ControllerOwnership.SORT_FILTER"))
	assert(source.contains("_reset_controller_zone_for_section"))
	assert(source.contains("preserve_tab_zone"))
	assert(source.contains("active_tab.call_deferred(\"grab_focus\")"))
	assert(source.contains("CONTROLLER_PICKUP_HOLD_SECONDS"))
	assert(source.contains("_reserve_main_navigation_for_page_switching"))
	assert(source.contains("configure_spatial_neighbors(candidates)"))


func _validate_player_page_zone_contracts() -> void:
	for path: String in [
		"res://ui/logbook_page.gd",
		"res://ui/the_net_page.gd",
		"res://ui/mail_page.gd",
		"res://ui/profile_page.gd",
		"res://ui/players_page.gd",
	]:
		var source: String = FileAccess.get_file_as_string(path)
		assert(source.contains("func reset_controller_zone()"))
		assert(source.contains("func handle_controller_input(event: InputEvent)"))
	var profile_source: String = FileAccess.get_file_as_string(
		"res://ui/profile_page.gd"
	)
	assert(profile_source.contains("ControllerZone.COLOR_PICKER"))
	assert(profile_source.contains("_adjust_controller_color_gamut"))
	assert(profile_source.contains("_customize_button.text = \"customize\""))
	assert(profile_source.contains("_enter_controller_customization"))
	assert(not profile_source.contains(
		"if event.is_action_pressed(\"ui_down\"):\n"
		+ "\t\t\t_controller_zone = ControllerZone.CATEGORIES"
	))
	assert(profile_source.contains(
		"_reset_view_button.focus_mode = Control.FOCUS_NONE"
	))
	var preview_source: String = FileAccess.get_file_as_string(
		"res://ui/profile_preview.gd"
	)
	assert(preview_source.contains("focus_mode = Control.FOCUS_NONE"))
	assert(not preview_source.contains("grab_focus()"))
	var mail_source: String = FileAccess.get_file_as_string(
		"res://ui/mail_page.gd"
	)
	assert(mail_source.contains("_configure_compose_controller_navigation"))
	assert(mail_source.contains("_set_compose_neighbors"))
	var net_source: String = FileAccess.get_file_as_string(
		"res://ui/the_net_page.gd"
	)
	assert(net_source.contains("ROLE_RIGHT_STICK_Y"))


func _validate_shop_navigation_contract() -> void:
	var source: String = FileAccess.get_file_as_string(
		"res://ui/fishing_shop.gd"
	)
	assert(source.contains("ROLE_LB"))
	assert(source.contains("ROLE_RB"))
	assert(source.contains("_configure_controller_focus"))


func _validate_four_by_three_centering() -> void:
	var stage_position: Vector2 = (
		UIReferencePresentationType.get_stage_position(Vector2(640.0, 480.0))
	)
	assert(stage_position.is_equal_approx(Vector2(0.0, 120.0)))


func _validate_low_end_profile_contract() -> void:
	var launcher: String = FileAccess.get_file_as_string(
		"res://scripts/portmaster/NETfishing.sh"
	)
	assert(launcher.contains("NETFISHING_PERFORMANCE_PROFILE:-"))
	assert(launcher.contains("$CONFDIR/performance_profile"))
	assert(launcher.contains("normal)"))
	assert(launcher.contains("light|\"\")"))
	assert(launcher.contains("NETFISHING_PERFORMANCE_PROFILE=normal"))
	assert(launcher.contains("NETFISHING_PERFORMANCE_PROFILE=light"))
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
