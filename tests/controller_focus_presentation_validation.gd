extends SceneTree

const FocusPresentationType = preload(
	"res://ui/controller_focus_presentation.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stage)
	var presentation := FocusPresentationType.new()
	stage.add_child(presentation)
	var standard_button := Button.new()
	standard_button.text = "standard"
	standard_button.custom_minimum_size = Vector2(120.0, 60.0)
	stage.add_child(standard_button)
	var authored_selector := Button.new()
	authored_selector.text = "authored selector"
	authored_selector.position = Vector2(140.0, 0.0)
	authored_selector.custom_minimum_size = Vector2(160.0, 60.0)
	authored_selector.set_meta(&"controller_focus_inversion_disabled", true)
	stage.add_child(authored_selector)
	await process_frame

	var controller_event := InputEventJoypadButton.new()
	controller_event.button_index = JOY_BUTTON_A
	controller_event.pressed = true
	presentation._input(controller_event)
	standard_button.grab_focus()
	await process_frame
	_expect(
		standard_button.material != null,
		"ordinary controller focus receives inversion",
	)
	var pointer_motion := InputEventMouseMotion.new()
	pointer_motion.position = Vector2(4.0, 4.0)
	presentation._input(pointer_motion)
	await process_frame
	_expect(
		standard_button.material == null,
		"mouse motion clears controller focus presentation",
	)
	presentation._input(controller_event)

	authored_selector.grab_focus()
	await process_frame
	_expect(
		standard_button.material == null,
		"inversion clears when focus moves",
	)
	_expect(
		authored_selector.material == null,
		"authored selector backgrounds opt out of inversion",
	)

	standard_button.grab_focus()
	await process_frame
	standard_button.focus_mode = Control.FOCUS_NONE
	await process_frame
	_expect(
		standard_button.material == null,
		"inversion clears when a focused control is defocused",
	)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0.0, 80.0)
	scroll.size = Vector2(180.0, 90.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stage.add_child(scroll)
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 160.0
	scroll.add_child(list)
	var last_scroll_button: Button
	for index: int in 8:
		var scroll_button := Button.new()
		scroll_button.text = "scroll option %d" % index
		scroll_button.custom_minimum_size = Vector2(160.0, 40.0)
		list.add_child(scroll_button)
		last_scroll_button = scroll_button
	await process_frame
	last_scroll_button.grab_focus()
	await process_frame
	await process_frame
	_expect(
		scroll.scroll_vertical > 0,
		"controller focus scrolls an off-screen selection into view",
	)
	_expect(
		root.gui_get_focus_owner() == last_scroll_button,
		"scroll following preserves the selected controller control",
	)

	stage.queue_free()
	if _failures.is_empty():
		print("Controller focus presentation validation: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
