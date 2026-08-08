extends SceneTree

const ControllerFocusRecoveryType = preload(
	"res://ui/controller_focus_recovery.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stage)
	var recovery := ControllerFocusRecoveryType.new()
	stage.add_child(recovery)
	var option_list := VBoxContainer.new()
	option_list.position = Vector2(100.0, 100.0)
	stage.add_child(option_list)
	var original := _make_button("cute", "cute (show variants)")
	option_list.add_child(original)
	await process_frame

	var controller_event := InputEventJoypadButton.new()
	controller_event.button_index = JOY_BUTTON_A
	controller_event.pressed = true
	recovery._input(controller_event)
	original.grab_focus()
	await process_frame
	_expect(root.gui_get_focus_owner() == original, "original option receives focus")

	option_list.remove_child(original)
	original.queue_free()
	var replacement := _make_button("cute", "cute (hide variants)")
	option_list.add_child(replacement)
	await process_frame
	await process_frame
	_expect(
		root.gui_get_focus_owner() == replacement,
		"focus follows a rebuilt semantic option",
	)

	var explicit_target := _make_button("explicit", "explicit")
	option_list.add_child(explicit_target)
	option_list.remove_child(replacement)
	replacement.queue_free()
	explicit_target.grab_focus()
	await process_frame
	_expect(
		root.gui_get_focus_owner() == explicit_target,
		"explicit focus changes take precedence over recovery",
	)
	var leave_world_ui_event := InputEventJoypadButton.new()
	leave_world_ui_event.button_index = JOY_BUTTON_LEFT_SHOULDER
	leave_world_ui_event.pressed = true
	recovery._input(leave_world_ui_event)
	root.gui_release_focus()
	await process_frame
	await process_frame
	_expect(
		root.gui_get_focus_owner() == null,
		"LB intentionally leaving world UI is never recovered",
	)

	stage.queue_free()
	if _failures.is_empty():
		print("Controller focus recovery validation: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _make_button(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.custom_minimum_size = Vector2(120.0, 48.0)
	return button


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
