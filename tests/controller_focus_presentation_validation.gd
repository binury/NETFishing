extends SceneTree

const FocusPresentationType = preload(
	"res://ui/controller_focus_presentation.gd"
)
const FishBatchSelectionType = preload(
	"res://ui/fish_batch_selection.gd"
)

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_validate_controller_cooler_focus()
	root.size = Vector2i(1280, 720)
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(stage)
	var presentation := FocusPresentationType.new()
	stage.add_child(presentation)
	var standard_button := Button.new()
	standard_button.text = "standard"
	standard_button.position = Vector2(80.0, 60.0)
	standard_button.custom_minimum_size = Vector2(120.0, 60.0)
	var normal_style := _button_style(Color("123f4e"))
	var old_hover_style := _button_style(Color("58c6d4"))
	var old_focus_style := _button_style(Color("238697"))
	standard_button.add_theme_stylebox_override("normal", normal_style)
	standard_button.add_theme_stylebox_override("hover", old_hover_style)
	standard_button.add_theme_stylebox_override("focus", old_focus_style)
	stage.add_child(standard_button)
	var second_button := Button.new()
	second_button.text = "second"
	second_button.position = Vector2(260.0, 60.0)
	second_button.custom_minimum_size = Vector2(120.0, 60.0)
	# Legacy opt-outs must not prevent the new universal cursor from appearing.
	second_button.set_meta(&"controller_focus_inversion_disabled", true)
	stage.add_child(second_button)
	await process_frame

	standard_button.grab_focus()
	await process_frame
	_expect(
		root.gui_get_focus_owner() == null,
		"a menu's programmatic first focus is visible before navigation input",
	)
	_expect(
		presentation.get("_neutral_focus_seed") == standard_button,
		"the neutral menu focus seed did not remember the first action",
	)
	var first_navigation := InputEventJoypadButton.new()
	first_navigation.button_index = JOY_BUTTON_DPAD_DOWN
	first_navigation.pressed = true
	presentation._input(first_navigation)
	await process_frame
	_expect(
		root.gui_get_focus_owner() == standard_button,
		"the first directional input did not activate the neutral focus seed",
	)

	var controller_event := InputEventJoypadButton.new()
	controller_event.button_index = JOY_BUTTON_A
	controller_event.pressed = true
	presentation._input(controller_event)
	await process_frame
	var focus_arrow := presentation.get("_focus_arrow") as TextureRect
	var focus_shadow := presentation.get("_focus_arrow_shadow") as TextureRect
	_expect(focus_arrow != null, "controller focus arrow was not created")
	_expect(focus_shadow != null, "controller focus shadow was not created")
	_expect(focus_arrow.visible, "controller focus arrow is not visible")
	_expect(focus_shadow.visible, "controller focus shadow is not visible")
	_expect(
		focus_arrow.texture == FocusPresentationType.FOCUS_ARROW_TEXTURE,
		"controller focus arrow uses the wrong artwork",
	)
	_expect(
		focus_shadow.texture == focus_arrow.texture,
		"controller focus shadow does not follow the cursor silhouette",
	)
	_expect(
		focus_shadow.position.is_equal_approx(
			focus_arrow.position
			+ FocusPresentationType.FOCUS_ARROW_SHADOW_OFFSET
		),
		"controller focus shadow uses the wrong offset",
	)
	_expect(
		is_equal_approx(
			focus_arrow.rotation_degrees,
			FocusPresentationType.FOCUS_ARROW_ROTATION_DEGREES,
		),
		"controller focus arrow does not point toward five o'clock",
	)
	_expect(
		standard_button.material == null,
		"controller focus still applies material inversion",
	)
	_expect(
		standard_button.get_theme_stylebox("focus") == normal_style,
		"native focus highlighting was not neutralized",
	)
	_expect(
		_arrow_marks_top_left(focus_arrow, standard_button.get_global_rect()),
		"controller focus arrow is not in the control's top-left corner",
	)
	stage.scale = Vector2.ONE * 0.5
	await process_frame
	_expect(
		focus_arrow.size.is_equal_approx(
			FocusPresentationType.FOCUS_ARROW_SIZE * 0.5
		),
		"controller focus arrow does not follow canonical UI stage scale",
	)
	_expect(
		_arrow_marks_top_left(focus_arrow, standard_button.get_global_rect()),
		"scaled controller focus arrow left its control's top-left corner",
	)
	stage.scale = Vector2.ONE
	await process_frame
	var hover_motion := InputEventMouseMotion.new()
	hover_motion.position = standard_button.get_global_rect().get_center()
	hover_motion.global_position = hover_motion.position
	root.push_input(hover_motion, true)
	await process_frame
	_expect(
		root.gui_get_hovered_control() == standard_button,
		"the pointer did not reach the hover-suppression test button",
	)
	presentation._input(first_navigation)
	presentation._input(controller_event)
	await process_frame
	_expect(
		standard_button.get_theme_stylebox("hover") == normal_style,
		"controller use leaves a stale mouse-hover highlight visible",
	)

	second_button.grab_focus()
	await process_frame
	_expect(
		focus_arrow.visible,
		"legacy inversion metadata incorrectly hides the focus arrow",
	)
	_expect(
		_arrow_marks_top_left(focus_arrow, second_button.get_global_rect()),
		"controller focus arrow did not follow the focused control",
	)
	var bubble_button := BubbleButton.new()
	bubble_button.text = "bubble"
	bubble_button.position = Vector2(440.0, 60.0)
	bubble_button.size = Vector2(120.0, 120.0)
	stage.add_child(bubble_button)
	await process_frame
	bubble_button.grab_focus()
	await process_frame
	_expect(
		_arrow_overlaps_bubble_edge(focus_arrow, bubble_button),
		"controller focus arrow does not meet the visible bubble edge",
	)

	var pointer_motion := InputEventMouseMotion.new()
	pointer_motion.position = Vector2(4.0, 4.0)
	presentation._input(pointer_motion)
	await process_frame
	_expect(
		not focus_arrow.visible,
		"mouse motion does not clear controller focus presentation",
	)
	_expect(
		not focus_shadow.visible,
		"mouse motion leaves the controller focus shadow visible",
	)
	_expect(
		root.gui_get_focus_owner() == null,
		"mouse motion leaves a stale menu action focused",
	)
	_expect(
		standard_button.get_theme_stylebox("focus") == old_focus_style,
		"native theme overrides were not restored after controller use",
	)
	_expect(
		standard_button.get_theme_stylebox("hover") == old_hover_style,
		"mouse hover styling was not restored after controller use",
	)
	var item_list := ItemList.new()
	item_list.position = Vector2(80.0, 160.0)
	item_list.size = Vector2(240.0, 150.0)
	item_list.max_columns = 1
	for index: int in 4:
		item_list.add_item("list item %d" % index)
	stage.add_child(item_list)
	await process_frame
	item_list.select(0)
	item_list.grab_focus()
	await process_frame
	presentation._input(first_navigation)
	presentation._input(controller_event)
	await process_frame
	var first_item_arrow_y: float = focus_arrow.position.y
	item_list.select(2)
	await process_frame
	_expect(
		focus_arrow.position.y > first_item_arrow_y,
		"focus arrow does not follow the selected ItemList row",
	)
	_expect(
		item_list.get_theme_stylebox("selected") is StyleBoxEmpty,
		"ItemList still draws a selected-row cursor highlight",
	)
	_expect(
		item_list.get_theme_color("font_selected_color")
		== item_list.get_theme_color("font_color"),
		"ItemList still recolors the selected-row cursor text",
	)

	var tree := Tree.new()
	tree.position = Vector2(700.0, 160.0)
	tree.size = Vector2(240.0, 150.0)
	tree.hide_root = true
	var tree_root: TreeItem = tree.create_item()
	var first_tree_item: TreeItem = tree.create_item(tree_root)
	first_tree_item.set_text(0, "first folder")
	var second_tree_item: TreeItem = tree.create_item(tree_root)
	second_tree_item.set_text(0, "second folder")
	stage.add_child(tree)
	await process_frame
	first_tree_item.select(0)
	tree.grab_focus()
	await process_frame
	var first_tree_arrow_y: float = focus_arrow.position.y
	second_tree_item.select(0)
	await process_frame
	_expect(
		focus_arrow.position.y > first_tree_arrow_y,
		"focus arrow does not follow the selected Tree row",
	)

	var popup := PopupMenu.new()
	for index: int in 5:
		popup.add_item("popup item %d" % index)
	root.add_child(popup)
	popup.popup(Rect2i(500, 300, 0, 0))
	popup.set_focused_item(0)
	for _frame: int in 2:
		await process_frame
	_expect(
		presentation.get("_focused_popup") == popup,
		"focus arrow did not enter an open PopupMenu",
	)
	_expect(
		presentation.get("_focus_layer").custom_viewport == popup,
		"focus arrow is not rendered inside the PopupMenu viewport",
	)
	_expect(
		popup.get_theme_stylebox("hover") is StyleBoxEmpty,
		"PopupMenu still draws its native focus highlight",
	)
	_expect(
		_arrow_marks_top_left(
			focus_arrow,
			presentation.call("_popup_focus_target_rect", popup) as Rect2,
		),
		"focus arrow does not mark the focused PopupMenu item",
	)
	var first_popup_arrow_y: float = focus_arrow.position.y
	popup.set_focused_item(2)
	await process_frame
	_expect(
		focus_arrow.position.y > first_popup_arrow_y,
		"focus arrow does not follow PopupMenu item navigation",
	)
	popup.hide()
	popup.queue_free()
	await process_frame
	item_list.grab_focus()
	await process_frame

	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.size = Vector2i(720, 480)
	root.add_child(dialog)
	dialog.popup_centered()
	for _frame: int in 2:
		await process_frame
	var dialog_cancel := dialog.get_cancel_button()
	dialog_cancel.grab_focus()
	for _frame: int in 2:
		await process_frame
	_expect(
		focus_arrow.visible,
		"focus arrow is hidden for an embedded dialog control",
	)
	_expect(
		presentation.get("_focus_layer").custom_viewport
		== dialog_cancel.get_viewport(),
		"focus arrow is not rendered inside the dialog viewport",
	)
	_expect(
		_arrow_marks_top_left(
			focus_arrow,
			presentation.call("_focus_target_rect", dialog_cancel) as Rect2,
		),
		"focus arrow does not follow an embedded dialog control",
	)
	dialog.hide()
	dialog.queue_free()
	await process_frame
	item_list.grab_focus()
	await process_frame

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(420.0, 160.0)
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
	for _frame: int in 2:
		await process_frame
	_expect(
		scroll.scroll_vertical > 0,
		"controller focus does not reveal an off-screen selection",
	)
	_expect(
		root.gui_get_focus_owner() == last_scroll_button,
		"scroll following does not preserve the focused control",
	)
	_expect(
		_arrow_marks_top_left(
			focus_arrow,
			last_scroll_button.get_global_rect(),
		),
		"focus arrow does not follow a scrolled control",
	)

	last_scroll_button.focus_mode = Control.FOCUS_NONE
	await process_frame
	_expect(
		not focus_arrow.visible,
		"focus arrow remains after its control becomes unfocusable",
	)
	var event_focused_button := Button.new()
	event_focused_button.text = "event focused"
	event_focused_button.position = Vector2(700.0, 360.0)
	event_focused_button.custom_minimum_size = Vector2(160.0, 50.0)
	stage.add_child(event_focused_button)
	await process_frame
	presentation._input(first_navigation)
	event_focused_button.grab_focus()
	await process_frame
	_expect(
		root.gui_get_focus_owner() == event_focused_button,
		(
			"a menu focus established by the current directional event was "
			+ "mistaken for an automatic default"
		),
	)

	presentation.set_virtual_pointer_active(true)
	await process_frame
	_expect(
		not focus_arrow.visible,
		"focus arrow competes with active virtual-pointer presentation",
	)
	presentation._input(controller_event)
	await process_frame
	_expect(
		not focus_arrow.visible,
		"controller input stole presentation from the held virtual pointer",
	)
	presentation.set_virtual_pointer_active(false)
	presentation._input(controller_event)
	await process_frame
	_expect(
		focus_arrow.visible,
		"controller focus presentation did not resume after virtual-pointer use",
	)

	stage.queue_free()
	if _failures.is_empty():
		print("Controller focus presentation validation: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _validate_controller_cooler_focus() -> void:
	var selection := FishBatchSelectionType.new()
	selection.set_visible_order([&"first", &"second"])
	selection.select_only(&"first")
	selection.focus_only(&"second")
	_expect(
		selection.get_focused_id() == &"second",
		"cooler focus does not follow controller navigation",
	)
	_expect(
		selection.get_selected_ids() == [&"first"],
		"moving cooler focus unexpectedly changes the selected catch set",
	)


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(8)
	return style


func _arrow_marks_top_left(arrow: Control, target: Rect2) -> bool:
	var arrow_pivot: Vector2 = arrow.position + arrow.size * 0.5
	var arrow_scale: Vector2 = arrow.size / FocusPresentationType.FOCUS_ARROW_SIZE
	var tip_from_pivot: Vector2 = (
		(FocusPresentationType.FOCUS_ARROW_TIP_UV - Vector2.ONE * 0.5)
		* arrow.size
	).rotated(deg_to_rad(
		FocusPresentationType.FOCUS_ARROW_ROTATION_DEGREES
	))
	var actual_tip: Vector2 = arrow_pivot + tip_from_pivot
	var expected_tip: Vector2 = (
		target.position
		+ FocusPresentationType.FOCUS_ARROW_TARGET_OVERLAP * arrow_scale
	)
	return actual_tip.distance_to(expected_tip) <= 0.5


func _arrow_overlaps_bubble_edge(
	arrow: Control,
	bubble: BubbleButton,
) -> bool:
	var arrow_pivot: Vector2 = arrow.position + arrow.size * 0.5
	var tip_from_pivot: Vector2 = (
		(FocusPresentationType.FOCUS_ARROW_TIP_UV - Vector2.ONE * 0.5)
		* arrow.size
	).rotated(deg_to_rad(
		FocusPresentationType.FOCUS_ARROW_ROTATION_DEGREES
	))
	var actual_tip: Vector2 = arrow_pivot + tip_from_pivot
	var local_tip: Vector2 = (
		bubble.get_global_transform_with_canvas().affine_inverse()
		* actual_tip
	)
	var radius: Vector2 = bubble.size * 0.5
	var normalized: Vector2 = (local_tip - radius) / radius
	return normalized.length() >= 0.75 and normalized.length() <= 1.0


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
