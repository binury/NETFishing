extends SceneTree

const PlayerMenuScene = preload("res://ui/player_menu.tscn")
const HotbarScene = preload("res://ui/hotbar.tscn")
const UIReferencePresentationType = preload(
	"res://ui/ui_reference_presentation.gd"
)
const FishSaleResultType = preload("res://economy/fish_sale_result.gd")
const CurrencyPresentationType = preload(
	"res://ui/currency_presentation.gd"
)
const PelicanBuyer = preload("res://economy/buyers/pelicans.tres")
const EXPECTED_HOST_SIZE := Vector2(278.0, 484.0)
const EXPECTED_ART_SIZE := Vector2(306.28125, 580.8)
const EXPECTED_ART_POSITION := Vector2(-4.140625, -28.4)
const LEGACY_COOLER_PANEL_RECT := Rect2(54.0, 166.0, 882.0, 484.0)
const LEGACY_COOLER_NOTEPAD_RECT := Rect2(952.0, 166.0, 278.0, 484.0)
const INVENTORY_PANEL_RECT := Rect2(199.0, 166.0, 882.0, 484.0)
const NOTEPAD_HOST_RECT := Rect2(501.0, 166.0, 278.0, 484.0)
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
	_validate_first_open_inventory(player_menu)
	await _validate_inventory_grid_centering(player_menu, presentation_stage)
	_validate_utility_page_geometry(player_menu)
	await _validate_profile_content_bounds(player_menu)
	await _validate_hotbar_centering(presentation_stage)
	_validate_inventory_layering(player_menu)
	_validate_sale_confirmation_copy(player_menu)
	_validate_tackle_to_items_transition(player_menu)
	_validate_cooler_notepad_typography(player_menu)
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
		&"BagOuterWall",
		&"TackleMainPanel",
	]:
		var main_panel := player_menu.get_node("%%%s" % node_name) as Control
		assert(main_panel != null)
		assert(main_panel.position.is_equal_approx(INVENTORY_PANEL_RECT.position))
		assert(
			main_panel.size.is_equal_approx(INVENTORY_PANEL_RECT.size),
			"%s was %s, expected %s" % [
				node_name,
				main_panel.size,
				INVENTORY_PANEL_RECT.size,
			],
		)
	var cooler_panel := player_menu.get_node("%CoolerOuterWall") as Control
	var cooler_notepad := player_menu.get_node("%DetailConstellation") as Control
	assert(cooler_panel.position.is_equal_approx(
		LEGACY_COOLER_PANEL_RECT.position
	))
	assert(cooler_panel.size.is_equal_approx(LEGACY_COOLER_PANEL_RECT.size))
	assert(cooler_notepad.position.is_equal_approx(
		LEGACY_COOLER_NOTEPAD_RECT.position
	))
	assert(cooler_notepad.size.is_equal_approx(
		LEGACY_COOLER_NOTEPAD_RECT.size
	))
	for node_name: StringName in [
		&"BagDetailConstellation",
		&"TackleDetailPanel",
	]:
		var host := player_menu.get_node("%%%s" % node_name) as Control
		assert(host != null)
		assert(host.position.is_equal_approx(NOTEPAD_HOST_RECT.position))
		assert(host.size.is_equal_approx(EXPECTED_HOST_SIZE))
	assert(is_equal_approx(INVENTORY_PANEL_RECT.get_center().x, 640.0))


func _validate_first_open_inventory(player_menu: PlayerMenu) -> void:
	var legacy_slots: Array = player_menu.get("_bag_slot_nodes") as Array
	assert(legacy_slots.is_empty())
	var old_slot_nodes: Array[Node] = player_menu.find_children(
		"*", "BagStorageSlot", true, false
	)
	assert(old_slot_nodes.is_empty())


func _validate_inventory_grid_centering(
	player_menu: PlayerMenu,
	stage: Control,
) -> void:
	var grid := player_menu.get("_general_inventory_grid") as Control
	assert(grid != null)
	grid.custom_minimum_size = Vector2(782.0, 342.0)
	grid.size = grid.custom_minimum_size
	player_menu.call("_layout_general_inventory_grid")
	await process_frame
	assert(is_equal_approx(grid.position.y, 39.0))
	assert(
		is_equal_approx(
			grid.get_global_rect().get_center().x,
			stage.get_global_rect().get_center().x,
		),
		"inventory center %s did not match stage center %s" % [
			grid.get_global_rect().get_center().x,
			stage.get_global_rect().get_center().x,
		],
	)


func _validate_utility_page_geometry(player_menu: PlayerMenu) -> void:
	for page_name: StringName in [
		&"TheNetPage",
		&"MailPage",
		&"ProfilePage",
		&"PlayersPage",
	]:
		var page := player_menu.get_node("%%%s" % page_name) as Control
		assert(page != null)
		var shell := page.find_child(
			"UtilityMainBox", true, false
		) as Control
		assert(shell != null)
		assert(shell.position.is_equal_approx(UtilityPageStyle.LAPTOP_RECT.position))
		assert(shell.size.is_equal_approx(UtilityPageStyle.LAPTOP_RECT.size))
		assert(is_equal_approx(shell.get_rect().get_center().x, 640.0))


func _validate_profile_content_bounds(player_menu: PlayerMenu) -> void:
	var profile := player_menu.get_node("%ProfilePage") as ProfilePage
	assert(profile != null)
	var menu_was_visible: bool = player_menu.visible
	var profile_was_visible: bool = profile.visible
	player_menu.visible = true
	profile.visible = true
	await process_frame
	await process_frame
	var option_list := profile.get("_option_list") as Control
	var body := option_list.get_parent() as Control
	var preview := profile.get("_preview") as Control
	var shell := profile.find_child("UtilityMainBox", true, false) as Control
	var content_zone := profile.find_child(
		"ProfileContentZone", true, false
	) as Control
	var profile_layout := profile.find_child(
		"ProfileLayout", true, false
	) as Control
	var account_row := profile.find_child(
		"ProfileAccountRow", true, false
	) as Control
	var body_panel := profile.find_child(
		"ProfileBodyPanel", true, false
	) as Control
	assert(option_list != null and body != null and preview != null)
	assert(shell != null and content_zone != null and profile_layout != null)
	assert(account_row != null and body_panel != null)
	var content_frame_size := Vector2(
		UtilityPageStyle.LAPTOP_RECT.size.x - 40.0,
		UtilityPageStyle.LAPTOP_RECT.size.y - 42.0,
	)
	assert(
		content_zone.size.is_equal_approx(content_frame_size),
		(
			"profile content zone changed size: %s != %s; "
			+ "layout min=%s account min=%s body min=%s"
		) % [
			content_zone.size,
			content_frame_size,
			profile_layout.get_combined_minimum_size(),
			account_row.get_combined_minimum_size(),
			body_panel.get_combined_minimum_size(),
		],
	)
	assert(
		profile_layout.size.is_equal_approx(
			UtilityPageStyle.LAPTOP_CONTENT_SIZE
		),
		"profile layout changed size: %s != %s" % [
			profile_layout.size,
			UtilityPageStyle.LAPTOP_CONTENT_SIZE,
		],
	)
	assert(
		profile_layout.get_combined_minimum_size().x
		<= profile_layout.size.x,
		"profile layout exceeded shared content width: %s > %s" % [
			profile_layout.get_combined_minimum_size().x,
			profile_layout.size.x,
		],
	)
	var content_rect: Rect2 = profile_layout.get_global_rect()
	for section: Control in [account_row, body_panel]:
		var section_rect: Rect2 = section.get_global_rect()
		assert(section_rect.position.x >= content_rect.position.x - 0.5)
		assert(section_rect.end.x <= content_rect.end.x + 0.5)
	var category_ids: Array[String] = []
	for category_id: String in CharacterCustomizationCatalog.CATEGORY_IDS:
		category_ids.append(category_id)
	category_ids.append("voice")
	for category_id: String in category_ids:
		profile.call("_select_category", category_id)
		await process_frame
		await process_frame
		assert(
			shell.position.is_equal_approx(
				UtilityPageStyle.LAPTOP_RECT.position
			),
			"%s profile shell position changed: %s" % [
				category_id,
				shell.position,
			],
		)
		assert(
			shell.size.is_equal_approx(UtilityPageStyle.LAPTOP_RECT.size),
			"%s profile shell size changed: %s != %s" % [
				category_id,
				shell.size,
				UtilityPageStyle.LAPTOP_RECT.size,
			],
		)
		assert(
			content_zone.size.is_equal_approx(content_frame_size),
			"%s profile content zone changed size: %s != %s" % [
				category_id,
				content_zone.size,
				content_frame_size,
			],
		)
		assert(
			profile_layout.size.is_equal_approx(
				UtilityPageStyle.LAPTOP_CONTENT_SIZE
			),
			"%s profile layout changed size: %s != %s" % [
				category_id,
				profile_layout.size,
				UtilityPageStyle.LAPTOP_CONTENT_SIZE,
			],
		)
		assert(
			profile_layout.get_combined_minimum_size().x
			<= profile_layout.size.x,
			"%s profile layout exceeded shared content width: %s > %s" % [
				category_id,
				profile_layout.get_combined_minimum_size().x,
				profile_layout.size.x,
			],
		)
		var category_body_rect: Rect2 = body_panel.get_global_rect()
		assert(
			category_body_rect.end.x <= content_rect.end.x + 0.5,
			"%s body overflowed shared content: %s > %s" % [
				category_id,
				category_body_rect.end.x,
				content_rect.end.x,
			],
		)
		assert(
			category_body_rect.end.y <= content_rect.end.y + 0.5,
			"%s body overflowed shared content vertically: %s > %s" % [
				category_id,
				category_body_rect.end.y,
				content_rect.end.y,
			],
		)
		assert(
			body.get_combined_minimum_size().x <= body.size.x,
			"%s customization content overflowed its body: %s > %s" % [
				category_id,
				body.get_combined_minimum_size().x,
				body.size.x,
			],
		)
		assert(
			preview.get_global_rect().end.x
			<= content_rect.end.x + 0.5,
			"%s preview overflowed the utility content area" % category_id,
		)
	profile.call("_select_category", "fur_pattern")
	profile.call("_select_fur_section", "colors")
	await process_frame
	await process_frame
	var color_panel := profile.find_child(
		"FurColorOptionsPanel", true, false
	) as Control
	var color_scroll := profile.find_child(
		"FurColorScroll", true, false
	) as ScrollContainer
	assert(color_panel != null and color_scroll != null)
	assert(
		color_panel.get_global_rect().end.y
		<= body_panel.get_global_rect().end.y + 0.5,
		"fur color panel overflowed profile body: %s > %s" % [
			color_panel.get_global_rect().end.y,
			body_panel.get_global_rect().end.y,
		],
	)
	assert(
		profile_layout.get_combined_minimum_size().y
		<= profile_layout.size.y,
		"fur colors expanded profile layout vertically: %s > %s" % [
			profile_layout.get_combined_minimum_size().y,
			profile_layout.size.y,
		],
	)
	profile.visible = profile_was_visible
	player_menu.visible = menu_was_visible


func _validate_hotbar_centering(parent: Control) -> void:
	var hotbar := HotbarScene.instantiate() as HotbarUI
	parent.add_child(hotbar)
	await process_frame
	var presentation := hotbar.get_node(
		"%HotbarPresentationScaleRoot"
	) as Control
	var field := hotbar.get_node("%BubbleField") as Control
	hotbar.set_player_menu_context(true)
	var displayed_center_x: float = (
		presentation.position.x
		+ field.get_rect().get_center().x * presentation.scale.x
	)
	assert(is_equal_approx(displayed_center_x, 640.0))
	var displayed_top: float = (
		presentation.position.y + field.position.y * presentation.scale.y
	)
	var displayed_bottom: float = (
		displayed_top + field.size.y * presentation.scale.y
	)
	assert(displayed_top < INVENTORY_PANEL_RECT.end.y)
	assert(displayed_bottom > INVENTORY_PANEL_RECT.end.y)
	hotbar.queue_free()


func _validate_inventory_layering(player_menu: PlayerMenu) -> void:
	var bag_panel := player_menu.get_node("%BagOuterWall") as Control
	var sale_confirmation := player_menu.get_node("%SaleConfirmation") as Control
	var cooler_panel := player_menu.get_node("%CoolerOuterWall") as Control
	var tackle_panel := player_menu.get_node("%TackleMainPanel") as Control
	var inventory_tabs := player_menu.get_node("%InventorySubTabs") as Control
	var items_tab := player_menu.get_node("%ItemsSubTab") as Button
	var bait_list := player_menu.get_node("%BaitItemList") as GridContainer
	var lure_list := player_menu.get_node("%LureItemList") as GridContainer
	assert(bag_panel != null)
	assert(sale_confirmation != null)
	assert(cooler_panel != null)
	assert(tackle_panel != null)
	assert(inventory_tabs != null)
	assert(items_tab != null and not items_tab.visible)
	assert(not (player_menu.get_node("%CoolerSubTab") as Button).visible)
	assert((player_menu.get_node("%BagSubTab") as Button).text == "Inventory")
	assert(bait_list != null and bait_list.columns == 4)
	assert(lure_list != null and lure_list.columns == 4)
	assert(bait_list.get_theme_constant("h_separation") == 28)
	assert(lure_list.get_theme_constant("h_separation") == 28)
	assert(sale_confirmation.z_index > cooler_panel.z_index)
	assert(sale_confirmation.z_index > tackle_panel.z_index)
	assert(
		(player_menu.get_node("%BagDetailConstellation") as Control).z_index
		> bag_panel.z_index
	)
	assert(
		(player_menu.get_node("%BagModalBlocker") as Control).z_index
		> bag_panel.z_index
	)
	assert(
		(player_menu.get_node("%BagDetailConstellation") as Control).z_index
		> (player_menu.get_node("%BagModalBlocker") as Control).z_index
	)
	assert(
		(player_menu.get_node("%TackleDetailPanel") as Control).z_index
		> tackle_panel.z_index
	)
	# The contextual Hotbar uses z=90 while the Player Menu is open.
	assert(sale_confirmation.z_index > 90)
	assert(sale_confirmation.position.is_equal_approx(Vector2(380.0, 265.0)))
	assert(sale_confirmation.size.is_equal_approx(Vector2(520.0, 200.0)))
	var confirmation_style := sale_confirmation.get_theme_stylebox(
		"panel"
	) as StyleBoxFlat
	assert(confirmation_style != null)
	assert(
		confirmation_style.bg_color.is_equal_approx(
			UtilityPageStyle.OCEAN_PANEL_DEEP
		)
	)


func _validate_sale_confirmation_copy(player_menu: PlayerMenu) -> void:
	var preview := FishSaleResultType.new()
	preview.fish_count = 1
	preview.payout = 3
	preview.base_value = 12
	var message: String = str(player_menu.call(
		"_sale_confirmation_text",
		preview,
		PelicanBuyer,
		preview.base_value,
	))
	assert(message == (
		"[center]You can sell this fish to the pelicans now for %s, "
		+ "but the shop is willing to pay %s![/center]"
	) % [
		CurrencyPresentationType.bbcode_amount(preview.payout, 22),
		CurrencyPresentationType.bbcode_amount(preview.base_value, 22),
	])
	assert((player_menu.get_node("%ConfirmSaleButton") as Button).text == "sell now")
	assert((player_menu.get_node("%CancelSaleButton") as Button).text == "nevermind")


func _validate_tackle_to_items_transition(player_menu: PlayerMenu) -> void:
	var inventory_notepad := player_menu.get_node(
		"%BagDetailBubble"
	) as InventoryNotepad
	assert(inventory_notepad != null)
	assert(inventory_notepad.title_text == "inventory notes")
	player_menu.call(
		"_show_section_immediate", PlayerMenu.Section.TACKLE_BOX
	)
	player_menu.call("_show_inventory_tab", 0)
	player_menu.call("_cancel_page_tween")
	player_menu.call("_show_section_immediate", PlayerMenu.Section.BAG)
	player_menu.call("_update_bag_detail")
	assert(player_menu.get("_current_section") == PlayerMenu.Section.BAG)
	assert(not (player_menu.get_node("%BagDetailConstellation") as Control).visible)
	assert(
		(player_menu.get_node("%BagSpriteDetailData") as Label).text
		== "select an item for details."
	)
	player_menu.visible = true
	player_menu.call("_set_content_interactive", true)
	var no_actions: Array[BaseButton] = []
	player_menu.call(
		"_open_inventory_notepad",
		PlayerMenu.Section.BAG,
		StringName("modal-test"),
		no_actions,
	)
	assert((player_menu.get_node("%BagDetailConstellation") as Control).visible)
	assert((player_menu.get_node("%BagModalBlocker") as Control).visible)
	assert(
		(player_menu.get_node("%BagModalBlocker") as Control).mouse_filter
		== Control.MOUSE_FILTER_STOP
	)
	assert(
		(player_menu.get_node("%InventoryTab") as Button).focus_mode
		== Control.FOCUS_NONE
	)
	assert(
		(player_menu.get_node("%BagSpriteDetailData") as Label).get_theme_font(
			"font"
		) == InventoryNotepad.NOTEPAD_FONT
	)
	player_menu.call(
		"_release_controller_ownership", false, false
	)
	assert(not (player_menu.get_node("%BagModalBlocker") as Control).visible)
	player_menu.call("_set_content_interactive", false)
	player_menu.visible = false
	player_menu.call("_cancel_page_tween")


func _validate_cooler_notepad_typography(player_menu: PlayerMenu) -> void:
	var sort_choice := player_menu.get_node("%CoolerSortOption") as Control
	var sort_direction := player_menu.get_node(
		"%CoolerSortDirection"
	) as Button
	var empty_selection := player_menu.get_node(
		"%CoolerSelectionEmpty"
	) as Label
	var favorite := player_menu.get_node("%FavoriteBubble") as Button
	var sell := player_menu.get_node("%SellBubble") as Button
	assert(sort_choice != null)
	assert(sort_direction != null)
	assert(empty_selection != null)
	assert(favorite != null and sell != null)
	assert(player_menu.get_node_or_null("%SellAllBubble") == null)
	var displayed_value := sort_choice.get_node("%DisplayedValue") as Label
	assert(displayed_value != null)
	assert(displayed_value.get_theme_font_size("font_size") == 17)
	for choice_name: StringName in [
		&"CatchOrderChoice",
		&"NameChoice",
		&"RarityChoice",
	]:
		var choice := sort_choice.get_node("%%%s" % choice_name) as Button
		assert(choice != null)
		assert(choice.get_theme_font_size("font_size") == 17)
	assert(sort_direction.get_theme_font_size("font_size") == 17)
	assert(empty_selection.get_theme_font_size("font_size") == 20)
	assert(favorite.get_theme_font_size("font_size") == 19)
	assert(sell.get_theme_font_size("font_size") == 19)


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
		PlayerMenu.Section.BAG,
		PlayerMenu.Section.TACKLE_BOX,
	]
	var suffixes: Array[String] = ["inventory", "tackle"]
	for index: int in sections.size():
		player_menu.call("_show_section_immediate", sections[index])
		await process_frame
		await process_frame
		await _save_capture(suffixes[index])
	player_menu.call("_show_section_immediate", PlayerMenu.Section.BAG)
	var sale_confirmation := player_menu.get_node("%SaleConfirmation") as Control
	var confirmation_message := player_menu.get_node(
		"%ConfirmationMessage"
	) as Label
	assert(sale_confirmation != null)
	assert(confirmation_message != null)
	confirmation_message.text = (
		"You can sell this fish to the pelicans now, "
		+ "but the shop will pay more!"
	)
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
