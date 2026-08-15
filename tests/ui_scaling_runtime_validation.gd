extends SceneTree

const UIPixelationPresenterType = preload(
	"res://ui/ui_pixelation_presenter.gd"
)
const UIReferencePresentationType = preload(
	"res://ui/ui_reference_presentation.gd"
)
const GameUIScene := preload("res://ui/game_ui.tscn")
const TARGET_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
	Vector2i(640, 480),
	Vector2i(1024, 768),
	Vector2i(1729, 973),
	Vector2i(2560, 1080),
	Vector2i(3440, 1440),
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_size: Vector2i = root.size
	var presenter := UIPixelationPresenterType.new()
	presenter.name = "UIPresentation"
	presenter.stretch = true
	var ui_viewport := SubViewport.new()
	ui_viewport.name = "UIViewport"
	var game_ui := GameUIScene.instantiate() as GameUI
	var ui_root := game_ui.get_node("UIRoot") as Control
	var canonical_stage := game_ui.get_node(
		"UIRoot/CanonicalStage"
	) as Control
	var chat_ui := game_ui.get_node("UIRoot/ChatUI") as ChatUI
	var player_menu := game_ui.get_node(
		"UIRoot/CanonicalStage/PlayerMenu"
	) as PlayerMenu
	var hotbar := game_ui.get_node(
		"UIRoot/CanonicalStage/Hotbar"
	) as HotbarUI
	assert(game_ui.get_node_or_null(
		"UIRoot/CanonicalStage/GameplayTransientHUD/EffectStatus"
	) == null)
	var screen_fade := game_ui.get_node("UIRoot/ScreenFade") as Control
	var title_screen := game_ui.get_node("UIRoot/TitleScreen") as TitleScreen
	var title_content_stage := title_screen.get_node(
		"ResponsiveTitleStage"
	) as Control
	var decorative_fish_layer := title_screen.get_node(
		"DecorativeFishLayer"
	) as Control
	var decorative_bubble_layer := title_screen.get_node(
		"DecorativeBubbleLayer"
	) as Control
	ui_viewport.add_child(game_ui)
	presenter.add_child(ui_viewport)
	root.add_child(presenter)
	await process_frame
	chat_ui.set_available(true)
	print(
		"UI viewport embedding: root=%s subviewport=%s"
		% [root.gui_embed_subwindows, ui_viewport.gui_embed_subwindows]
	)

	for target_size: Vector2i in TARGET_SIZES:
		root.size = target_size
		await process_frame
		await process_frame
		var actual_size: Vector2i = root.size
		var display_size := Vector2(actual_size)
		var expected_scale: float = UIReferencePresentationType.get_scale(
			display_size
		)
		var expected_stage_offset: Vector2 = UIReferencePresentationType.get_offset(
			display_size
		)
		assert(presenter.position.is_equal_approx(Vector2.ZERO))
		assert(ui_root.position.is_equal_approx(Vector2.ZERO))
		var expected_visible_size: Vector2 = (
			UIReferencePresentationType.get_visible_reference_size(display_size)
		)
		assert(ui_root.size.is_equal_approx(expected_visible_size))
		assert(canonical_stage.size.is_equal_approx(
			UIReferencePresentationType.REFERENCE_SIZE
		))
		assert(canonical_stage.position.is_equal_approx(
			UIReferencePresentationType.get_stage_position(display_size)
		))
		assert(chat_ui.size.is_equal_approx(expected_visible_size))
		assert(screen_fade.size.is_equal_approx(expected_visible_size))
		assert(player_menu.position.is_equal_approx(Vector2.ZERO))
		assert(player_menu.size.is_equal_approx(
			UIReferencePresentationType.REFERENCE_SIZE
		))
		assert(hotbar.position.is_equal_approx(Vector2(
			0.0,
			canonical_stage.position.y,
		)))
		assert(hotbar.size.is_equal_approx(
			UIReferencePresentationType.REFERENCE_SIZE
		))
		assert(title_screen.size.is_equal_approx(expected_visible_size))
		assert(title_content_stage.size.is_equal_approx(
			UIReferencePresentationType.REFERENCE_SIZE
		))
		assert(title_content_stage.position.is_equal_approx(
			canonical_stage.position
		))
		assert(decorative_fish_layer.size.is_equal_approx(
			expected_visible_size
		))
		assert(decorative_bubble_layer.size.is_equal_approx(
			expected_visible_size
		))
		var left_to_right_bounds: Vector2 = (
			TitleScreen.get_decorative_fish_crossing_bounds(
				expected_visible_size.x, 160.0, 1.0
			)
		)
		var right_to_left_bounds: Vector2 = (
			TitleScreen.get_decorative_fish_crossing_bounds(
				expected_visible_size.x, 160.0, -1.0
			)
		)
		assert(left_to_right_bounds.x < -160.0)
		assert(left_to_right_bounds.y > expected_visible_size.x)
		assert(right_to_left_bounds.x > expected_visible_size.x)
		assert(right_to_left_bounds.y < -160.0)
		assert(is_equal_approx(presenter.scale.x, presenter.scale.y))
		assert(is_equal_approx(ui_root.scale.x, ui_root.scale.y))
		var effective_scale: float = presenter.scale.x * ui_root.scale.x
		assert(is_equal_approx(effective_scale, expected_scale))
		assert((
			canonical_stage.position * effective_scale
		).distance_to(expected_stage_offset) <= 0.01)
		var expected_render_height: int = mini(
			roundi(UIReferencePresentationType.REFERENCE_SIZE.y * expected_scale),
			PlayerSettings.get_ui_render_height(
				PlayerSettings.DEFAULT_UI_PIXEL_SIZE,
				roundi(UIReferencePresentationType.REFERENCE_SIZE.y),
			),
		)
		var expected_render_scale: float = (
			float(expected_render_height)
			/ UIReferencePresentationType.REFERENCE_SIZE.y
		)
		var expected_viewport_size := Vector2i(
			roundi(expected_visible_size.x * expected_render_scale),
			roundi(expected_visible_size.y * expected_render_scale),
		)
		assert(presenter.get_ui_viewport_size() == expected_viewport_size)
		assert(presenter.size.is_equal_approx(Vector2(expected_viewport_size)))
		var chat_panel := chat_ui.get_node("ChatPanel") as Control
		var clock_panel := chat_ui.get_node("WorldClockPanel") as Control
		var status_effect_column := chat_ui.get_node(
			"StatusEffectColumn"
		) as Control
		var weather_icon := chat_ui.get_node("WorldWeatherIcon") as Control
		assert(chat_panel != null)
		assert(clock_panel != null)
		assert(status_effect_column != null)
		assert(weather_icon != null)
		assert(chat_panel.visible)
		assert(is_equal_approx(chat_panel.position.x, 0.0))
		assert(is_equal_approx(
			(chat_panel.position.y + chat_panel.size.y) * effective_scale,
			display_size.y - ChatUI.BOTTOM_MARGIN * effective_scale,
		))
		assert(clock_panel.position.is_equal_approx(Vector2(
			ChatUI.CLOCK_EDGE_MARGIN,
			ChatUI.CLOCK_EDGE_MARGIN,
		)))
		assert(is_equal_approx(
			status_effect_column.position.x,
			clock_panel.position.x
			+ (ChatUI.CLOCK_SIZE.x - ChatUI.STATUS_EFFECT_ICON_SIZE.x) * 0.5,
		))
		assert(is_equal_approx(
			status_effect_column.position.y,
			clock_panel.position.y
			+ ChatUI.CLOCK_SIZE.y
			+ ChatUI.STATUS_EFFECT_TOP_GAP,
		))
		assert(is_equal_approx(
			weather_icon.position.y, ChatUI.CLOCK_EDGE_MARGIN
		))
		assert(weather_icon.position.x > clock_panel.position.x)
		print(
			(
				"UI resize: requested=%s actual=%s viewport=%s container_scale=%.6f "
				+ "root_scale=%.6f effective_scale=%.6f stage_offset=%s "
				+ "chat_x=%.3f"
			)
			% [
				target_size,
				actual_size,
				presenter.get_ui_viewport_size(),
				presenter.scale.x,
				ui_root.scale.x,
				effective_scale,
				expected_stage_offset,
				chat_panel.position.x * effective_scale,
			]
		)
		if OS.has_environment("NETFISHING_UI_SCALE_CAPTURE"):
			await process_frame
			var capture: Image = root.get_texture().get_image()
			var capture_path: String = (
				"%s-requested-%dx%d-actual-%dx%d.png"
			) % [
				OS.get_environment("NETFISHING_UI_SCALE_CAPTURE"),
				target_size.x,
				target_size.y,
				actual_size.x,
				actual_size.y,
			]
			assert(capture.save_png(capture_path) == OK)

	presenter.queue_free()
	root.size = original_size
	for _frame: int in 4:
		await process_frame
	await create_timer(0.1).timeout
	print("UI scaling runtime validation: PASS")
	quit()
