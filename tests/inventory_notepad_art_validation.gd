extends SceneTree

const PlayerMenuScene = preload("res://ui/player_menu.tscn")
const UIReferencePresentationType = preload(
	"res://ui/ui_reference_presentation.gd"
)
const EXPECTED_HOST_SIZE := Vector2(278.0, 484.0)
const EXPECTED_ART_SIZE := Vector2(306.28125, 580.8)
const EXPECTED_ART_POSITION := Vector2(-4.140625, -28.4)
const INVENTORY_PANEL_RECT := Rect2(54.0, 166.0, 882.0, 484.0)
const NOTEPAD_HOST_RECT := Rect2(952.0, 166.0, 278.0, 484.0)
const NOTEPAD_ART_RECT := Rect2(
	NOTEPAD_HOST_RECT.position + EXPECTED_ART_POSITION,
	EXPECTED_ART_SIZE,
)
const HOTBAR_BUBBLE_FIELD_RECT := Rect2(245.0, 608.0, 790.0, 104.0)
const TARGET_SIZES: Array[Vector2] = [
	Vector2(1280.0, 720.0),
	Vector2(1920.0, 1080.0),
	Vector2(2560.0, 1440.0),
	Vector2(3840.0, 2160.0),
	Vector2(640.0, 480.0),
	Vector2(1024.0, 768.0),
	Vector2(1729.0, 973.0),
	Vector2(2560.0, 1080.0),
	Vector2(3440.0, 1440.0),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_print_runtime_parameters()
	var presentation_stage := Control.new()
	presentation_stage.name = "CanonicalUIStage"
	_apply_stage_layout(presentation_stage, Vector2(root.size))
	root.add_child(presentation_stage)
	var player_menu := PlayerMenuScene.instantiate() as PlayerMenu
	presentation_stage.add_child(player_menu)
	await process_frame
	var notepads: Array[Node] = player_menu.find_children(
		"*", "InventoryNotepad", true, false
	)
	assert(notepads.size() == 3)
	for node: Node in notepads:
		var notepad := node as InventoryNotepad
		assert(notepad != null)
		assert(notepad.size.is_equal_approx(EXPECTED_HOST_SIZE))
		assert(notepad.mouse_filter == Control.MOUSE_FILTER_PASS)
		var art_rect: Rect2 = notepad.get_art_rect()
		assert(art_rect.size.is_equal_approx(EXPECTED_ART_SIZE))
		assert(art_rect.position.is_equal_approx(EXPECTED_ART_POSITION))
		assert(art_rect.get_center().is_equal_approx(
			EXPECTED_HOST_SIZE * 0.5
			+ InventoryNotepad.NOTEPAD_ART_OFFSET
		))
	_validate_shared_inventory_geometry(player_menu)
	_validate_inventory_layering(player_menu)
	_validate_resolution_matrix()
	await _capture_inventory_pages(player_menu)
	print("Inventory notepad artwork validation: PASS")
	presentation_stage.queue_free()
	for _frame: int in 10:
		await process_frame
	await create_timer(0.1).timeout
	quit()


func _print_runtime_parameters() -> void:
	var window: Window = root
	var screen_index: int = window.current_screen
	print(
		(
			"Runtime UI: window=%s screen=%s screen_scale=%.3f dpi=%d "
			+ "content_size=%s content_mode=%d content_aspect=%d "
			+ "content_factor=%.3f"
		)
		% [
			window.size,
			DisplayServer.screen_get_size(screen_index),
			DisplayServer.screen_get_scale(screen_index),
			DisplayServer.screen_get_dpi(screen_index),
			window.content_scale_size,
			window.content_scale_mode,
			window.content_scale_aspect,
			window.content_scale_factor,
		]
	)


func _apply_stage_layout(stage: Control, display_size: Vector2) -> void:
	stage.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stage.position = UIReferencePresentationType.get_offset(display_size)
	stage.size = UIReferencePresentationType.REFERENCE_SIZE
	stage.scale = Vector2.ONE * UIReferencePresentationType.get_scale(
		display_size
	)


func _validate_shared_inventory_geometry(player_menu: PlayerMenu) -> void:
	for node_name: StringName in [
		&"DetailConstellation",
		&"BagDetailConstellation",
		&"TackleDetailPanel",
	]:
		var host := player_menu.get_node("%%%s" % node_name) as Control
		assert(host != null)
		assert(host.position.is_equal_approx(Vector2(952.0, 166.0)))
		assert(host.size.is_equal_approx(EXPECTED_HOST_SIZE))


func _validate_inventory_layering(player_menu: PlayerMenu) -> void:
	var bag_filters := player_menu.get_node("%BagFilterTabs") as Control
	var bag_panel := player_menu.get_node("%BagOuterWall") as Control
	var sale_confirmation := player_menu.get_node("%SaleConfirmation") as Control
	var cooler_panel := player_menu.get_node("%CoolerOuterWall") as Control
	var tackle_panel := player_menu.get_node("%TackleMainPanel") as Control
	assert(bag_filters != null)
	assert(bag_panel != null)
	assert(sale_confirmation != null)
	assert(cooler_panel != null)
	assert(tackle_panel != null)
	assert(bag_filters.z_index > bag_panel.z_index)
	assert(sale_confirmation.z_index > cooler_panel.z_index)
	assert(sale_confirmation.z_index > tackle_panel.z_index)
	# The contextual Hotbar uses z=90 while the Player Menu is open.
	assert(sale_confirmation.z_index > 90)
	assert(sale_confirmation.position.is_equal_approx(Vector2(380.0, 265.0)))
	assert(sale_confirmation.size.is_equal_approx(Vector2(520.0, 190.0)))
	var confirmation_style := sale_confirmation.get_theme_stylebox(
		"panel"
	) as StyleBoxFlat
	assert(confirmation_style != null)
	assert(
		confirmation_style.bg_color.is_equal_approx(
			UtilityPageStyle.OCEAN_PANEL_DEEP
		)
	)


func _validate_resolution_matrix() -> void:
	for target_size: Vector2 in TARGET_SIZES:
		var stage_rect: Rect2 = UIReferencePresentationType.get_rect(
			target_size
		)
		var stage_scale: float = UIReferencePresentationType.get_scale(
			target_size
		)
		assert(is_equal_approx(
			stage_rect.size.x / stage_rect.size.y,
			1280.0 / 720.0,
		))
		assert(stage_rect.get_center().is_equal_approx(target_size * 0.5))
		_validate_transformed_rect(
			"Inventory panel", INVENTORY_PANEL_RECT, stage_rect, stage_scale
		)
		_validate_transformed_rect(
			"Notepad host", NOTEPAD_HOST_RECT, stage_rect, stage_scale
		)
		_validate_transformed_rect(
			"Notepad art", NOTEPAD_ART_RECT, stage_rect, stage_scale
		)
		_validate_transformed_rect(
			"Hotbar", HOTBAR_BUBBLE_FIELD_RECT, stage_rect, stage_scale
		)
		var screen_host: Rect2 = _to_screen_rect(
			NOTEPAD_HOST_RECT, stage_rect.position, stage_scale
		)
		var screen_art: Rect2 = _to_screen_rect(
			NOTEPAD_ART_RECT, stage_rect.position, stage_scale
		)
		assert(is_equal_approx(
			screen_art.size.y,
			screen_host.size.y * InventoryNotepad.NOTEPAD_CANONICAL_OVERSCAN,
		))
		assert(screen_art.get_center().is_equal_approx(
			screen_host.get_center()
			+ InventoryNotepad.NOTEPAD_ART_OFFSET * stage_scale
		))
		print(
			(
				"UI geometry: window=%s stage=%s scale=%.6f "
				+ "inventory=%s notepad=%s art=%s hotbar=%s"
			)
			% [
				target_size,
				stage_rect,
				stage_scale,
				_to_screen_rect(
					INVENTORY_PANEL_RECT,
					stage_rect.position,
					stage_scale,
				),
				screen_host,
				screen_art,
				_to_screen_rect(
					HOTBAR_BUBBLE_FIELD_RECT,
					stage_rect.position,
					stage_scale,
				),
			]
		)


func _validate_transformed_rect(
	label: String,
	canonical_rect: Rect2,
	stage_rect: Rect2,
	stage_scale: float,
) -> void:
	var screen_rect: Rect2 = _to_screen_rect(
		canonical_rect, stage_rect.position, stage_scale
	)
	assert(
		screen_rect.position.is_equal_approx(
			stage_rect.position + canonical_rect.position * stage_scale
		),
		"%s position does not use the single stage transform" % label,
	)
	assert(
		screen_rect.size.is_equal_approx(canonical_rect.size * stage_scale),
		"%s size does not use the single stage transform" % label,
	)


func _to_screen_rect(
	canonical_rect: Rect2,
	stage_offset: Vector2,
	stage_scale: float,
) -> Rect2:
	return Rect2(
		stage_offset + canonical_rect.position * stage_scale,
		canonical_rect.size * stage_scale,
	)


func _capture_inventory_pages(player_menu: PlayerMenu) -> void:
	if not OS.has_environment("NETFISHING_NOTEPAD_CAPTURE"):
		return
	player_menu.visible = true
	var sections: Array[PlayerMenu.Section] = [
		PlayerMenu.Section.COOLER,
		PlayerMenu.Section.TACKLE_BOX,
		PlayerMenu.Section.BAG,
	]
	var suffixes: Array[String] = ["cooler", "tackle", "equipment"]
	for index: int in sections.size():
		player_menu.call("_show_section_immediate", sections[index])
		await process_frame
		await process_frame
		await _save_capture(suffixes[index])
	player_menu.call("_show_section_immediate", PlayerMenu.Section.COOLER)
	var sale_confirmation := player_menu.get_node("%SaleConfirmation") as Control
	var confirmation_message := player_menu.get_node(
		"%ConfirmationMessage"
	) as Label
	assert(sale_confirmation != null)
	assert(confirmation_message != null)
	confirmation_message.text = "sell selected fish?"
	sale_confirmation.visible = true
	await process_frame
	await process_frame
	await _save_capture("sale-confirmation")
	sale_confirmation.visible = false


func _save_capture(suffix: String) -> void:
	var image: Image = root.get_texture().get_image()
	var path: String = "%s-%s.png" % [
		OS.get_environment("NETFISHING_NOTEPAD_CAPTURE"),
		suffix,
	]
	assert(image.save_png(path) == OK)
